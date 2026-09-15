import SwiftUI
import Combine

/// Medium date in the app language (ritual rows, magazine, goals).
func ritualDateString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: L10n.isGerman ? "de_DE" : "en_US")
    formatter.dateStyle = .medium
    return formatter.string(from: date)
}

/// Time capsules: letters sealed until a chosen date. The server withholds
/// the content until the recipient opens the capsule.
struct CapsulesView: View {
    @Environment(AppState.self) private var appState

    @State private var capsules: [TimeCapsule] = []
    @State private var loading = true
    @State private var showCompose = false
    @State private var ceremonyCapsule: TimeCapsule?
    @State private var deleteTarget: TimeCapsule?

    private var sealed: [TimeCapsule] { capsules.filter { $0.openedAt == nil }.sorted { $0.unlockAt < $1.unlockAt } }
    private var opened: [TimeCapsule] { capsules.filter { $0.openedAt != nil }.sorted { ($0.openedAt ?? .distantPast) > ($1.openedAt ?? .distantPast) } }

    var body: some View {
        List {
            if loading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if capsules.isEmpty {
                ContentUnavailableView {
                    Label(L10n.t("capsules.empty.title"), systemImage: "hourglass")
                } description: {
                    Text(L10n.t("capsules.empty.subtitle", ["name": appState.partnerName]))
                } actions: {
                    Button(L10n.t("capsules.new")) { showCompose = true }
                        .buttonStyle(.glassProminent)
                        .disabled(appState.partner == nil)
                }
                .listRowBackground(Color.clear)
            } else {
                if !sealed.isEmpty {
                    Section(L10n.t("capsules.sectionSealed")) {
                        ForEach(sealed) { capsule in row(capsule) }
                    }
                }
                if !opened.isEmpty {
                    Section(L10n.t("capsules.sectionOpened")) {
                        ForEach(opened) { capsule in row(capsule) }
                    }
                }
            }
        }
        .navigationTitle(L10n.t("capsules.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCompose = true
                } label: {
                    Label(L10n.t("capsules.new"), systemImage: "plus")
                }
                .disabled(appState.partner == nil)
            }
        }
        .sheet(isPresented: $showCompose) {
            CapsuleComposeSheet { capsule in apply(capsule) }
        }
        .sheet(item: $ceremonyCapsule) { capsule in
            CapsuleCeremonyView(capsule: capsule)
        }
        .confirmationDialog(L10n.t("capsules.deleteConfirm"), isPresented: Binding(
            get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }), titleVisibility: .visible) {
            Button(L10n.t("common.delete"), role: .destructive) {
                if let target = deleteTarget { delete(target) }
            }
        }
        .task(id: appState.couple?.id) { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent else { return }
            switch event.type {
            case .capsuleSealed, .capsuleOpened:
                if let capsule = event.decode(CapsuleEventPayload.self)?.capsule { apply(capsule) }
            case .capsuleDeleted:
                if let payload = event.decode(IdPayload.self) { capsules.removeAll { $0.id == payload.id } }
            default:
                break
            }
        }
    }

    private func row(_ capsule: TimeCapsule) -> some View {
        let isForMe = capsule.forMember == appState.memberId
        let canDelete = capsule.createdBy == appState.memberId && capsule.openedAt == nil
        return HStack(alignment: .top, spacing: 12) {
            Text(capsule.emoji ?? "💌")
                .font(.title2)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(capsule.title ?? L10n.t("capsules.title"))
                    .font(.body.weight(.medium))
                Text(isForMe ? L10n.t("capsules.from", ["name": appState.partnerName])
                             : L10n.t("capsules.forPartner", ["name": appState.partnerName]))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                statusLine(capsule)
            }
            Spacer(minLength: 0)
            if isForMe, capsule.openedAt == nil, capsule.unlocked {
                Button(L10n.t("capsules.open")) { open(capsule) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            } else if capsule.openedAt == nil {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if canDelete {
                Button(role: .destructive) {
                    deleteTarget = capsule
                } label: {
                    Label(L10n.t("common.delete"), systemImage: "trash")
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if capsule.openedAt != nil { ceremonyCapsule = capsule }
        }
    }

    @ViewBuilder
    private func statusLine(_ capsule: TimeCapsule) -> some View {
        if let openedAt = capsule.openedAt {
            Label(L10n.t("capsules.openedAt", ["date": ritualDateString(openedAt)]), systemImage: "envelope.open")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.green)
        } else if capsule.unlocked {
            Label(L10n.t("capsules.readyToOpen"), systemImage: "sparkles")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.orange)
        } else {
            Label(L10n.t("capsules.sealedUntil", ["date": ritualDateString(capsule.unlockAt)]), systemImage: "hourglass")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func apply(_ capsule: TimeCapsule) {
        if let idx = capsules.firstIndex(where: { $0.id == capsule.id }) {
            capsules[idx] = capsule
        } else {
            capsules.insert(capsule, at: 0)
        }
    }

    private func reload() async {
        guard let api = appState.api else { loading = false; return }
        if let list = try? await api.capsules() { capsules = list }
        loading = false
    }

    private func open(_ capsule: TimeCapsule) {
        guard let api = appState.api else { return }
        Task {
            do {
                let openedCapsule = try await api.openCapsule(id: capsule.id)
                apply(openedCapsule)
                ceremonyCapsule = openedCapsule
                Delight.celebrate(.medium, theme: .hearts)
            } catch {
                appState.handleAPIError(error)
            }
        }
    }

    private func delete(_ capsule: TimeCapsule) {
        guard let api = appState.api else { return }
        Task {
            do {
                try await api.deleteCapsule(id: capsule.id)
                capsules.removeAll { $0.id == capsule.id }
            } catch {
                appState.handleAPIError(error)
            }
        }
    }
}

// MARK: - Compose

private struct CapsuleComposeSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let onSealed: (TimeCapsule) -> Void

    @State private var title = ""
    @State private var text = ""
    @State private var emoji = "💌"
    @State private var unlockAt = Date().addingTimeInterval(7 * 86400)
    @State private var galleryPhotos: [Photo] = []
    @State private var photoId: String?
    @State private var sealing = false

    private static let emojis = ["💌", "🎁", "🌙", "💍", "🎂", "✈️", "🏠", "🌸", "🎄", "🥂", "💫", "🕯️"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.t("capsules.compose.titleField"), text: $title)
                    TextField(L10n.t("capsules.compose.textField"), text: $text, axis: .vertical)
                        .lineLimit(4...12)
                    EmojiPickerGrid(emojis: Self.emojis, selection: $emoji, columns: 6)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }
                Section {
                    DatePicker(L10n.t("capsules.compose.unlockAt"), selection: $unlockAt,
                               in: Date().addingTimeInterval(3600)..., displayedComponents: [.date, .hourAndMinute])
                } footer: {
                    Text(L10n.t("capsules.compose.footer", ["name": appState.partnerName]))
                }
                if !galleryPhotos.isEmpty {
                    Section(L10n.t("capsules.compose.photo")) {
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                Button {
                                    photoId = nil
                                } label: {
                                    Text(L10n.t("capsules.compose.photoNone"))
                                        .font(.caption.weight(.medium))
                                        .frame(width: 72, height: 72)
                                        .background(Color.tertiaryCardBackground, in: RoundedRectangle(cornerRadius: 12))
                                        .overlay {
                                            if photoId == nil {
                                                RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor, lineWidth: 2)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                                ForEach(galleryPhotos.prefix(30)) { photo in
                                    Button {
                                        photoId = photo.id
                                    } label: {
                                        RemotePhoto(api: appState.api, path: photo.thumbUrl ?? photo.url)
                                            .frame(width: 72, height: 72)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay {
                                                if photoId == photo.id {
                                                    RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor, lineWidth: 2)
                                                }
                                            }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    }
                }
            }
            .navigationTitle(L10n.t("capsules.compose.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        seal()
                    } label: {
                        if sealing { ProgressView() } else { Text(L10n.t("capsules.seal")) }
                    }
                    .disabled(sealing || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .interactiveDismissDisabled(sealing)
        .task {
            if let photos = try? await appState.api?.photos() { galleryPhotos = photos }
        }
    }

    private func seal() {
        guard let api = appState.api, !sealing else { return }
        sealing = true
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                let capsule = try await api.sealCapsule(title: trimmedTitle.isEmpty ? nil : trimmedTitle,
                                                        emoji: emoji,
                                                        text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                                                        photoId: photoId, unlockAt: unlockAt)
                SoundEngine.shared.play(.letterSeal)
                appState.notify(L10n.t("capsules.sealedToast"), style: .love)
                onSealed(capsule)
                dismiss()
            } catch {
                sealing = false
                appState.handleAPIError(error)
            }
        }
    }
}

// MARK: - Opening ceremony / reader

private struct CapsuleCeremonyView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let capsule: TimeCapsule
    @State private var revealed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text(capsule.emoji ?? "💌")
                        .font(.system(size: 64))
                        .scaleEffect(revealed ? 1 : 0.7)
                        .accessibilityHidden(true)
                    if revealed {
                        VStack(alignment: .leading, spacing: 16) {
                            if let title = capsule.title, !title.isEmpty {
                                Text(title).font(.title2.weight(.bold))
                            }
                            Text(capsule.text ?? "")
                                .font(.body)
                                .fontDesign(.serif)
                                .lineSpacing(5)
                                .textSelection(.enabled)
                            if let photoId = capsule.photoId {
                                RemotePhoto(api: appState.api, path: "/api/photos/\(photoId)/raw", contentMode: .fit)
                                    .frame(maxHeight: 320)
                                    .clipShape(RoundedRectangle(cornerRadius: Brand.tileRadius, style: .continuous))
                            }
                            Divider()
                            Text(capsule.createdBy == appState.memberId
                                 ? L10n.t("capsules.forPartner", ["name": appState.partnerName])
                                 : L10n.t("capsules.from", ["name": appState.partnerName]))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(L10n.t("capsules.sealedOn", ["date": ritualDateString(capsule.createdAt)]))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        Text(L10n.t("capsules.ceremony.title"))
                            .font(.title2.weight(.bold))
                        Text(L10n.t("capsules.ceremony.hint", ["date": ritualDateString(capsule.createdAt)]))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button(L10n.t("capsules.open")) {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { revealed = true }
                            SoundEngine.shared.play(.tada)
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                    }
                }
                .padding(24)
            }
            .navigationTitle(capsule.title ?? L10n.t("capsules.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.done")) { dismiss() }
                }
            }
        }
        .sensoryFeedback(.success, trigger: revealed) { _, new in new }
        .onAppear {
            // Already-opened capsules read straight away.
            if capsule.openedAt != nil, capsule.text != nil, capsule.createdBy == appState.memberId {
                revealed = true
            }
        }
    }
}
