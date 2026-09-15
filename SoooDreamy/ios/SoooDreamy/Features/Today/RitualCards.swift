import SwiftUI
import Combine

// MARK: - Morning / good-night check-in

struct CheckinCard: View {
    @Environment(AppState.self) private var appState

    @State private var today: CheckinDay?
    @State private var streak = 0
    @State private var busyKind: String?
    @State private var successCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(L10n.t("checkin.title"), systemImage: "sunrise.fill")
                    .font(.headline)
                Spacer()
                if streak > 0 {
                    StreakBadge(streak: streak, style: .capsule)
                }
            }
            HStack(spacing: 10) {
                checkinButton(kind: "morning", systemImage: "sun.max.fill", titleKey: "checkin.morning", tint: .orange)
                checkinButton(kind: "night", systemImage: "moon.fill", titleKey: "checkin.night", tint: .indigo)
            }
            if let hint = partnerHint {
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .cardSurface()
        .sensoryFeedback(.success, trigger: successCount)
        .task(id: appState.couple?.id) { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent, event.type == .checkin,
                  let payload = event.decode(CheckinEventPayload.self) else { return }
            if payload.day.dateKey == SharedDates.todayKey() { today = payload.day }
            streak = payload.streak
        }
    }

    private var partnerHint: String? {
        guard let partnerId = appState.partner?.id, let today else { return nil }
        if today.checkedIn(partnerId, kind: "night") { return L10n.t("checkin.partner.night", ["name": appState.partnerName]) }
        if today.checkedIn(partnerId, kind: "morning") { return L10n.t("checkin.partner.morning", ["name": appState.partnerName]) }
        return L10n.t("checkin.partner.none", ["name": appState.partnerName])
    }

    private func checkinButton(kind: String, systemImage: String, titleKey: String, tint: Color) -> some View {
        let done = today?.checkedIn(appState.memberId, kind: kind) ?? false
        return Button {
            send(kind: kind)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: done ? "checkmark.circle.fill" : systemImage)
                    .foregroundStyle(done ? Color.green : tint)
                Text(L10n.t(done ? "\(titleKey).done" : titleKey))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if busyKind == kind { ProgressView().controlSize(.mini) }
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(done ? Color.green : tint)
        .disabled(done || busyKind != nil)
    }

    private func reload() async {
        guard let api = appState.api else { return }
        if let response = try? await api.checkins(limit: 1) {
            streak = response.streak
            today = response.days.first { $0.dateKey == SharedDates.todayKey() }
        }
    }

    private func send(kind: String) {
        guard let api = appState.api, busyKind == nil else { return }
        busyKind = kind
        Task {
            do {
                let response = try await api.checkin(kind: kind)
                today = response.day
                streak = response.streak
                successCount += 1
                SoundEngine.shared.play(kind == "morning" ? .sparkle : .chime)
            } catch {
                appState.handleAPIError(error)
            }
            busyKind = nil
        }
    }
}

// MARK: - Hug queue

/// Queue a hug while the partner sleeps; they open it like a present.
struct HugQueueCard: View {
    @Environment(AppState.self) private var appState
    @State private var hugs: [Hug] = []
    @State private var showSheet = false

    private var pendingForMe: [Hug] {
        hugs.filter { $0.to == appState.memberId && $0.openedAt == nil }
    }

    var body: some View {
        Button {
            showSheet = true
        } label: {
            HStack(spacing: 14) {
                IconTile(systemImage: "gift.fill", tint: .pink, size: 40)
                    .overlay(alignment: .topTrailing) {
                        if !pendingForMe.isEmpty {
                            Text("\(pendingForMe.count)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(Color.red, in: Circle())
                                .offset(x: 8, y: -8)
                        }
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("hug.card.title"))
                        .font(.headline)
                    Text(pendingForMe.isEmpty
                         ? L10n.t("hug.card.teaser")
                         : L10n.t("hug.card.pending", ["n": String(pendingForMe.count)]))
                        .font(.footnote)
                        .foregroundStyle(pendingForMe.isEmpty ? Color.secondary : Color.accentColor)
                        .lineLimit(2)
                }
                Spacer()
                DisclosureChevron()
            }
            .multilineTextAlignment(.leading)
            .cardSurface(padding: 14)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) {
            HugQueueSheet(hugs: $hugs)
        }
        .task(id: appState.couple?.id) { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent,
                  event.type == .hugQueued || event.type == .hugOpened,
                  let hug = event.decode(HugResponse.self)?.hug else { return }
            upsert(hug)
        }
    }

    private func reload() async {
        guard let api = appState.api else { return }
        if let loaded = try? await api.hugs() { hugs = loaded }
    }

    private func upsert(_ hug: Hug) {
        if let idx = hugs.firstIndex(where: { $0.id == hug.id }) {
            hugs[idx] = hug
        } else {
            hugs.insert(hug, at: 0)
        }
    }
}

struct HugQueueSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Binding var hugs: [Hug]

    @State private var note = ""
    @State private var sending = false
    @State private var openingId: String?
    @State private var burst = false

    private var pendingForMe: [Hug] { hugs.filter { $0.to == appState.memberId && $0.openedAt == nil } }
    private var queuedByMe: [Hug] { hugs.filter { $0.from == appState.memberId && $0.openedAt == nil } }
    private var history: [Hug] { Array(hugs.filter { $0.openedAt != nil }.prefix(10)) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField(L10n.t("hug.compose.placeholder"), text: $note, axis: .vertical)
                        .lineLimit(1...3)
                    Button {
                        queue()
                    } label: {
                        HStack {
                            Label(L10n.t("hug.compose.send"), systemImage: "gift")
                            if sending { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(sending || appState.partner == nil)
                } footer: {
                    Text(L10n.t("hug.compose.body", ["name": appState.partnerName]))
                }

                if !pendingForMe.isEmpty {
                    Section(L10n.t("hug.pending.title", ["n": String(pendingForMe.count)])) {
                        ForEach(pendingForMe) { hug in
                            HStack(spacing: 12) {
                                Text("🎁").font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.t("hug.pending.from", ["name": appState.partnerName]))
                                        .font(.subheadline.weight(.medium))
                                    Text(L10n.relativeShort(hug.createdAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(L10n.t("hug.pending.open")) { open(hug) }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    .disabled(openingId != nil)
                            }
                        }
                    }
                }

                if !queuedByMe.isEmpty {
                    Section {
                        ForEach(queuedByMe) { hug in
                            HStack(spacing: 10) {
                                Text(hug.emoji)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(hug.note ?? L10n.t("hug.queued.plain"))
                                        .lineLimit(2)
                                    Text(L10n.relativeShort(hug.createdAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "hourglass")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    } header: {
                        Text(L10n.t("hug.queued.title", ["name": appState.partnerName]))
                    } footer: {
                        Text(L10n.t("hug.queued.hint", ["name": appState.partnerName]))
                    }
                }

                if !history.isEmpty {
                    Section(L10n.t("hug.history.title")) {
                        ForEach(history) { hug in
                            HStack(spacing: 10) {
                                Image(systemName: hug.from == appState.memberId ? "arrow.up.right" : "arrow.down.left")
                                    .foregroundStyle(.secondary)
                                Text(hug.note ?? L10n.t("hug.queued.plain"))
                                    .lineLimit(1)
                                Spacer()
                                if let openedAt = hug.openedAt {
                                    Text(L10n.relativeShort(openedAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .overlay {
                if burst {
                    FloatingHeartsView(emojis: ["🫂", "💞", "💗", "✨"], count: 24)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle(L10n.t("hug.card.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.done")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sensoryFeedback(.success, trigger: burst) { _, new in new }
    }

    private func queue() {
        guard let api = appState.api, !sending else { return }
        sending = true
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                let hug = try await api.queueHug(note: text.isEmpty ? nil : text, emoji: nil)
                hugs.insert(hug, at: 0)
                note = ""
                SoundEngine.shared.play(.pop)
                appState.notify(L10n.t("hug.compose.sentToast", ["name": appState.partnerName]), style: .love)
            } catch {
                appState.handleAPIError(error)
            }
            sending = false
        }
    }

    private func open(_ hug: Hug) {
        guard let api = appState.api, openingId == nil else { return }
        openingId = hug.id
        Task {
            do {
                let opened = try await api.openHug(id: hug.id)
                if let idx = hugs.firstIndex(where: { $0.id == opened.id }) { hugs[idx] = opened }
                burst = true
                SoundEngine.shared.play(.tada)
                Haptics.shared.play(.hug)
                if let note = opened.note, !note.isEmpty {
                    appState.notify("💌 " + note, style: .love)
                }
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                burst = false
            } catch {
                appState.handleAPIError(error)
            }
            openingId = nil
        }
    }
}

// MARK: - Audio check-in teaser

struct DaymemoCard: View {
    @Environment(AppState.self) private var appState
    @State private var today: DaymemoDay?
    @State private var streak = 0

    var body: some View {
        NavigationLink {
            DaymemoView()
        } label: {
            HStack(spacing: 14) {
                IconTile(systemImage: "mic.fill", tint: .purple, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(L10n.t("daymemo.title"))
                            .font(.headline)
                        if streak > 0 {
                            StreakBadge(streak: streak)
                        }
                    }
                    Text(statusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                DisclosureChevron()
            }
            .multilineTextAlignment(.leading)
            .cardSurface(padding: 14)
        }
        .buttonStyle(.plain)
        .task(id: appState.couple?.id) { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent, event.type == .daymemo,
                  let day = event.decode(DaymemoDay.self) else { return }
            if day.dateKey == SharedDates.todayKey() { today = day }
            streak = day.streak
        }
    }

    private var statusText: String {
        let name = appState.partnerName
        guard let today else { return L10n.t("daymemo.card.hint", ["name": name]) }
        if today.bothRecorded { return L10n.t("daymemo.card.ready") }
        if today.mine != nil { return L10n.t("daymemo.card.waiting", ["name": name]) }
        if today.partnerRecorded { return L10n.t("daymemo.card.partnerFirst", ["name": name]) }
        return L10n.t("daymemo.card.hint", ["name": name])
    }

    private func reload() async {
        guard let api = appState.api else { return }
        if let response = try? await api.daymemos(limit: 1) {
            streak = response.streak
            today = response.days.first { $0.dateKey == SharedDates.todayKey() }
        }
    }
}

// MARK: - Week plan banner ("Heute: Filmabend 🍿")

struct WeekplanBanner: View {
    @Environment(AppState.self) private var appState
    @State private var todaySlots: [WeekplanSlot] = []

    var body: some View {
        Group {
            if !todaySlots.isEmpty {
                NavigationLink {
                    WeekplanView()
                } label: {
                    HStack(spacing: 14) {
                        IconTile(systemImage: "calendar", tint: .red, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(todaySlots.prefix(2)) { slot in
                                Text(L10n.t("weekplan.today.banner", ["title": slotLine(slot)]))
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        DisclosureChevron()
                    }
                    .cardSurface(padding: 14)
                }
                .buttonStyle(.plain)
            }
        }
        .task(id: appState.couple?.id) { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent else { return }
            switch event.type {
            case .weekplanSlotAdded, .weekplanSlotUpdated, .weekplanSlotDeleted:
                Task { await reload() }
            default:
                break
            }
        }
    }

    private func slotLine(_ slot: WeekplanSlot) -> String {
        var line = "\(slot.emoji ?? "💜") \(slot.title)"
        if let time = slot.time { line += " · \(time)" }
        return line
    }

    private func reload() async {
        guard let api = appState.api else { return }
        if let plan = try? await api.weekplan(days: 1), let today = plan.days.first {
            todaySlots = today.slots.sorted { ($0.time ?? "99") < ($1.time ?? "99") }
        }
    }
}

// MARK: - Energy light sheet

struct EnergySheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var busy = false

    private var myLevel: EnergyLevel? {
        appState.me?.energy.flatMap { EnergyLevel(rawValue: $0.level) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(EnergyLevel.allCases) { level in
                        Button {
                            set(level)
                        } label: {
                            HStack(spacing: 12) {
                                Text(level.emoji).font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.t(level.titleKey))
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text(L10n.t(level.hintKey))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if myLevel == level {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .disabled(busy)
                    }
                } header: {
                    Text(L10n.t("energy.mine"))
                } footer: {
                    Text(L10n.t("energy.sheet.footer", ["name": appState.partnerName]))
                }

                Section {
                    TextField(L10n.t("energy.noteField"), text: $note)
                }

                if myLevel != nil {
                    Section {
                        Button(L10n.t("energy.clear"), role: .destructive) { clear() }
                            .disabled(busy)
                    }
                }

                if let partner = appState.partner {
                    Section(L10n.t("energy.partnerLabel", ["name": partner.name])) {
                        if let energy = partner.energy, let level = EnergyLevel(rawValue: energy.level) {
                            HStack(spacing: 12) {
                                Text(level.emoji).font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.t(level.titleKey)).font(.body.weight(.medium))
                                    Text(energy.note?.isEmpty == false ? (energy.note ?? "") : L10n.t(level.hintKey))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(L10n.relativeShort(energy.setAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text(L10n.t("energy.partnerUnset", ["name": partner.name]))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(L10n.t("energy.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.done")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { note = appState.me?.energy?.note ?? "" }
    }

    private func set(_ level: EnergyLevel) {
        guard let api = appState.api, !busy else { return }
        busy = true
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                let energy = try await api.setEnergy(level: level, note: text.isEmpty ? nil : text)
                appState.applyEnergy(memberId: appState.memberId ?? "", energy: energy)
                appState.notify(L10n.t("energy.setToast", ["name": appState.partnerName]), style: .success)
                dismiss()
            } catch {
                appState.handleAPIError(error)
            }
            busy = false
        }
    }

    private func clear() {
        guard let api = appState.api, !busy else { return }
        busy = true
        Task {
            do {
                try await api.clearEnergy()
                appState.applyEnergy(memberId: appState.memberId ?? "", energy: nil)
                dismiss()
            } catch {
                appState.handleAPIError(error)
            }
            busy = false
        }
    }
}
