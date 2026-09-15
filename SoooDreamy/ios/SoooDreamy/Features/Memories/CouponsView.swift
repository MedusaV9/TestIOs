import SwiftUI
import Combine

/// Love coupons — little vouchers the partners gift each other.
/// Wallet-style: "for you" passes on top, the ones you created below;
/// redeem via confirmation, delete via swipe, create in a Form sheet.
struct CouponsView: View {
    @Environment(AppState.self) private var appState

    @State private var coupons: [Coupon] = []
    @State private var loading = true
    @State private var showCreate = false
    @State private var redeemTarget: Coupon?
    @State private var deleteTarget: Coupon?
    @State private var celebrationDate: Date?
    @State private var celebrationTask: Task<Void, Never>?
    /// Coupon ids with a "gift again" POST in flight (prevents double taps).
    @State private var regifting: Set<String> = []

    var body: some View {
        List {
            if appState.partner == nil {
                ContentUnavailableView {
                    Label(L10n.t("memories.coupons.noPartner.title"), systemImage: "ticket")
                } description: {
                    Text(L10n.t("memories.coupons.noPartner.subtitle"))
                }
                .listRowBackground(Color.clear)
            } else if loading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    if forMe.isEmpty {
                        Text(L10n.t("memories.coupons.emptyForYou"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(forMe) { coupon in
                            TimelineView(.everyMinute) { timeline in
                                voucherRow(coupon, now: timeline.date)
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }
                    }
                } header: {
                    Text(L10n.t("memories.coupons.forYou"))
                }

                Section {
                    if byMe.isEmpty {
                        Text(L10n.t("memories.coupons.emptyFromYou"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(byMe) { coupon in
                            createdRow(coupon)
                        }
                    }
                } header: {
                    Text(L10n.t("memories.coupons.fromYou"))
                }
            }
        }
        .navigationTitle(L10n.t("memories.coupons.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if appState.partner != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreate = true
                    } label: {
                        Label(L10n.t("memories.coupons.create"), systemImage: "plus")
                    }
                }
            }
        }
        .overlay {
            if let started = celebrationDate {
                FloatingHeartsView(emojis: ["🎟️", "💖", "✨", "🎉", "💜"], count: 20, startedAt: started)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .refreshable { await loadCoupons() }
        .task { await loadCoupons() }
        .sheet(isPresented: $showCreate) {
            CouponCreateSheet { coupon in insert(coupon) }
        }
        .confirmationDialog(L10n.t("memories.coupons.redeemConfirm"),
                            isPresented: Binding(get: { redeemTarget != nil },
                                                 set: { if !$0 { redeemTarget = nil } }),
                            titleVisibility: .visible) {
            Button(L10n.t("memories.coupons.redeem")) {
                if let coupon = redeemTarget { redeem(coupon) }
            }
        }
        .confirmationDialog(L10n.t("memories.coupons.deleteConfirm"),
                            isPresented: Binding(get: { deleteTarget != nil },
                                                 set: { if !$0 { deleteTarget = nil } }),
                            titleVisibility: .visible) {
            Button(L10n.t("common.delete"), role: .destructive) {
                if let coupon = deleteTarget { delete(coupon) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent else { return }
            handleServerEvent(event)
        }
    }

    // MARK: Derived lists

    /// Coupons made for me — redeemable first, then expired, then redeemed;
    /// newest first within each group.
    private var forMe: [Coupon] {
        func rank(_ coupon: Coupon) -> Int {
            if coupon.redeemedAt != nil { return 2 }
            return coupon.isExpired() ? 1 : 0
        }
        return coupons
            .filter { $0.forMember == appState.memberId }
            .sorted { lhs, rhs in
                let lhsRank = rank(lhs)
                let rhsRank = rank(rhs)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.createdAt > rhs.createdAt
            }
    }

    /// Coupons I created for my partner, newest first.
    private var byMe: [Coupon] {
        coupons
            .filter { $0.createdBy == appState.memberId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: Voucher (for me)

    /// A pass-like card: tinted while redeemable, greyed once redeemed or
    /// expired. The minute clock flips it the moment the expiry passes.
    private func voucherRow(_ coupon: Coupon, now: Date) -> some View {
        let expired = coupon.isExpired(at: now)
        let inactive = coupon.redeemedAt != nil || expired
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Text(coupon.emoji)
                    .font(.system(size: 40))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(coupon.title)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    if let note = coupon.note, !note.isEmpty {
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(fromInfo(coupon))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            if let redeemedAt = coupon.redeemedAt {
                Label(L10n.t("memories.coupons.redeemedAt",
                             ["date": redeemedAt.formatted(date: .abbreviated, time: .omitted)]),
                      systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.green)
            } else if expired, let expiresAt = coupon.expiresAt {
                Label(L10n.t("memories.coupons.expiredAt",
                             ["date": expiresAt.formatted(date: .abbreviated, time: .omitted)]),
                      systemImage: "hourglass.bottomhalf.filled")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.red)
            } else {
                HStack {
                    if let expiresAt = coupon.expiresAt {
                        Label(expiryCountdown(expiresAt, now: now), systemImage: "hourglass")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.orange)
                    }
                    Spacer()
                    Button(L10n.t("memories.coupons.redeem")) {
                        redeemTarget = coupon
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(inactive ? AnyShapeStyle(Color.cardBackground)
                             : AnyShapeStyle(Color.accentColor.opacity(0.14)),
                    in: RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous)
                .strokeBorder(inactive ? Color.secondary.opacity(0.25) : Color.accentColor.opacity(0.5),
                              style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
        }
        .saturation(inactive ? 0.4 : 1)
        .opacity(inactive ? 0.8 : 1)
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    /// Short "time left" label: minutes under an hour, hours under two days,
    /// then days (rounded up).
    private func expiryCountdown(_ expiresAt: Date, now: Date) -> String {
        let remaining = expiresAt.timeIntervalSince(now)
        let minutes = max(Int(remaining / 60), 1)
        if minutes < 60 { return L10n.t("memories.coupons.expiresInMinutes", ["n": String(minutes)]) }
        let hours = minutes / 60
        if hours < 48 { return L10n.t("memories.coupons.expiresInHours", ["n": String(hours)]) }
        let days = Int((remaining / 86_400).rounded(.up))
        return L10n.t("memories.coupons.expiresInDays", ["n": String(days)])
    }

    private func fromInfo(_ coupon: Coupon) -> String {
        let name = appState.couple?.members.first { $0.id == coupon.createdBy }?.name ?? appState.partnerName
        let date = coupon.createdAt.formatted(date: .abbreviated, time: .omitted)
        return L10n.t("memories.coupons.from", ["name": name]) + " · " + date
    }

    // MARK: Created row (by me)

    private func createdRow(_ coupon: Coupon) -> some View {
        HStack(spacing: 12) {
            Text(coupon.emoji)
                .font(.title2)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(coupon.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Text(forInfo(coupon))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if coupon.redeemedAt == nil, !coupon.isExpired(), let expiresAt = coupon.expiresAt {
                    Text(expiryCountdown(expiresAt, now: Date()))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.orange)
                }
            }
            Spacer()
            statusText(coupon)
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if coupon.redeemedAt == nil {
                Button(role: .destructive) {
                    deleteTarget = coupon
                } label: {
                    Label(L10n.t("common.delete"), systemImage: "trash")
                }
            }
            if coupon.redeemedAt != nil || coupon.isExpired() {
                Button {
                    giftAgain(coupon)
                } label: {
                    Label(L10n.t("coupon.giftAgain"), systemImage: "arrow.counterclockwise")
                }
                .tint(.accentColor)
                .disabled(regifting.contains(coupon.id))
            }
        }
        .contextMenu {
            if coupon.redeemedAt != nil || coupon.isExpired() {
                Button {
                    giftAgain(coupon)
                } label: {
                    Label(L10n.t("coupon.giftAgain"), systemImage: "arrow.counterclockwise")
                }
                .disabled(regifting.contains(coupon.id))
            }
            if coupon.redeemedAt == nil {
                Button(role: .destructive) {
                    deleteTarget = coupon
                } label: {
                    Label(L10n.t("common.delete"), systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private func statusText(_ coupon: Coupon) -> some View {
        Group {
            if coupon.redeemedAt != nil {
                Label(L10n.t("memories.coupons.statusRedeemed"), systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Color.green)
            } else if coupon.isExpired() {
                Label(L10n.t("memories.coupons.statusExpired"), systemImage: "hourglass.bottomhalf.filled")
                    .foregroundStyle(Color.red)
            } else {
                Label(L10n.t("memories.coupons.statusOpen"), systemImage: "ticket")
                    .foregroundStyle(Color.orange)
            }
        }
        .font(.caption.weight(.medium))
        .labelStyle(.titleAndIcon)
    }

    private func forInfo(_ coupon: Coupon) -> String {
        let date = coupon.createdAt.formatted(date: .abbreviated, time: .omitted)
        return L10n.t("memories.coupons.forName", ["name": appState.partnerName]) + " · " + date
    }

    // MARK: Actions

    private func loadCoupons() async {
        guard let api = appState.api else { return }
        do {
            coupons = try await api.coupons()
            // Fresh list in hand — (re-)arm the "expiring soon" reminders.
            await CouponReminder.sync(coupons: coupons, myMemberId: appState.memberId)
        } catch {
            appState.handleAPIError(error)
        }
        loading = false
    }

    /// Re-gift a redeemed/expired coupon: POST a fresh one with the same
    /// title/emoji/note (deliberately without the old, already-past expiry).
    private func giftAgain(_ coupon: Coupon) {
        guard let api = appState.api, !regifting.contains(coupon.id) else { return }
        regifting.insert(coupon.id)
        Task {
            do {
                let fresh = try await api.createCoupon(title: coupon.title, emoji: coupon.emoji, note: coupon.note)
                insert(fresh)
                SoundEngine.shared.play(.chime)
                Haptics.shared.success()
                appState.notify(L10n.t("memories.coupons.created"), style: .love)
            } catch {
                appState.handleAPIError(error)
            }
            regifting.remove(coupon.id)
        }
    }

    private func redeem(_ coupon: Coupon) {
        guard let api = appState.api else { return }
        Task {
            do {
                let updated = try await api.redeemCoupon(id: coupon.id)
                apply(updated)
                SoundEngine.shared.play(.tada)
                Haptics.shared.success()
                celebrate()
            } catch {
                // Server v1.6: redeem answers 409 `expired` past `expiresAt`
                // (clock skew can let a locally-fresh coupon expire server-side).
                if case APIError.http(let status, let code, _) = error, status == 409, code == "expired" {
                    appState.notify(L10n.t("memories.coupons.expiredToast"), style: .error)
                    await loadCoupons()
                } else {
                    appState.handleAPIError(error)
                }
            }
        }
    }

    private func delete(_ coupon: Coupon) {
        guard let api = appState.api else { return }
        withAnimation(.snappy) { coupons.removeAll { $0.id == coupon.id } }
        syncExpiryReminders()
        Task {
            do {
                try await api.deleteCoupon(id: coupon.id)
            } catch {
                insert(coupon)
                appState.handleAPIError(error)
            }
        }
    }

    private func celebrate() {
        celebrationDate = Date()
        celebrationTask?.cancel()
        celebrationTask = Task {
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            if !Task.isCancelled { celebrationDate = nil }
        }
    }

    // MARK: Realtime

    private func insert(_ coupon: Coupon) {
        guard !coupons.contains(where: { $0.id == coupon.id }) else { return }
        withAnimation(.snappy) { coupons.append(coupon) }
        syncExpiryReminders()
    }

    private func apply(_ coupon: Coupon) {
        withAnimation(.snappy) {
            if let idx = coupons.firstIndex(where: { $0.id == coupon.id }) {
                coupons[idx] = coupon
            } else {
                coupons.append(coupon)
            }
        }
        syncExpiryReminders()
    }

    /// The local list changed (new/redeemed/deleted coupon) — re-arm the
    /// "expiring soon" reminders to match.
    private func syncExpiryReminders() {
        let list = coupons
        let me = appState.memberId
        Task { await CouponReminder.sync(coupons: list, myMemberId: me) }
    }

    private func handleServerEvent(_ event: ServerEvent) {
        switch event.type {
        case .couponAdded:
            if let coupon = event.decode(CouponResponse.self)?.coupon { insert(coupon) }
        case .couponRedeemed:
            if let coupon = event.decode(CouponResponse.self)?.coupon { apply(coupon) }
        case .couponDeleted:
            if let id = event.decode(IdPayload.self)?.id {
                withAnimation(.snappy) { coupons.removeAll { $0.id == id } }
                syncExpiryReminders()
            }
        default:
            break
        }
    }
}

// MARK: - Create sheet

private struct CouponCreateSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let onCreated: (Coupon) -> Void

    @State private var title = ""
    @State private var note = ""
    @State private var emoji = "🎟️"
    @State private var hasExpiry = false
    @State private var expiryDate = Date().addingTimeInterval(7 * 86_400)
    @State private var saving = false

    private static let emojis = [
        "🎟️", "💆", "🍳", "🎬", "🧖", "🍕",
        "🌹", "📽️", "🛁", "💃", "🚗", "🧺",
        "🌟", "🍝", "🎮", "😴", "🧽", "🚶"
    ]

    /// Preset ideas — bundled content (like ContentPack), not L10n keys.
    private struct CouponPreset: Identifiable {
        let id: Int
        let emoji: String
        let title: LText
    }

    private static let presets: [CouponPreset] = [
        CouponPreset(id: 1, emoji: "💆", title: LText(de: "1× Massage", en: "1× massage")),
        CouponPreset(id: 2, emoji: "🍳", title: LText(de: "Frühstück ans Bett", en: "Breakfast in bed")),
        CouponPreset(id: 3, emoji: "🎬", title: LText(de: "Filmabend — du wählst", en: "Movie night — you pick")),
        CouponPreset(id: 4, emoji: "🧽", title: LText(de: "1× Abwasch übernehmen", en: "1× doing the dishes")),
        CouponPreset(id: 5, emoji: "🧺", title: LText(de: "Picknick-Date", en: "Picnic date")),
        CouponPreset(id: 6, emoji: "🚶", title: LText(de: "Langer Spaziergang", en: "A long walk together")),
        CouponPreset(id: 7, emoji: "🌟", title: LText(de: "1× Wunsch frei", en: "One free wish")),
        CouponPreset(id: 8, emoji: "🍝", title: LText(de: "Selbstgekochtes Dinner", en: "Home-cooked dinner")),
        CouponPreset(id: 9, emoji: "🎮", title: LText(de: "Gaming-Abend zusammen", en: "Gaming night together")),
        CouponPreset(id: 10, emoji: "😴", title: LText(de: "Ausschlafen — ich übernehme alles", en: "Sleep in — I'll handle everything"))
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.t("memories.coupons.ideas")) {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(Self.presets) { preset in
                                Button {
                                    title = preset.title.resolved(L10n.lang)
                                    emoji = preset.emoji
                                } label: {
                                    Text("\(preset.emoji) \(preset.title.resolved(L10n.lang))")
                                        .font(.subheadline)
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .scrollIndicators(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }

                Section {
                    TextField(L10n.t("memories.coupons.titleField"), text: $title)
                        .submitLabel(.done)
                    TextField(L10n.t("memories.coupons.noteField"), text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section(L10n.t("memories.events.emoji")) {
                    EmojiPickerGrid(emojis: Self.emojis, selection: $emoji)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }

                Section {
                    Toggle(L10n.t("memories.coupons.expiryToggle"), isOn: $hasExpiry.animation(.snappy))
                    if hasExpiry {
                        DatePicker(L10n.t("memories.coupons.expiryPicker"),
                                   selection: $expiryDate,
                                   in: Date()...,
                                   displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle(L10n.t("memories.coupons.createTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        create()
                    } label: {
                        if saving { ProgressView() } else { Text(L10n.t("memories.coupons.create")) }
                    }
                    .disabled(saving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func create() {
        guard let api = appState.api, !saving else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        saving = true
        Task {
            do {
                let coupon = try await api.createCoupon(title: trimmedTitle,
                                                        emoji: emoji,
                                                        note: trimmedNote.isEmpty ? nil : trimmedNote,
                                                        expiresAt: hasExpiry ? expiryDate : nil)
                onCreated(coupon)
                SoundEngine.shared.play(.chime)
                Haptics.shared.success()
                appState.notify(L10n.t("memories.coupons.created"), style: .love)
                dismiss()
            } catch {
                appState.handleAPIError(error)
            }
            saving = false
        }
    }
}
