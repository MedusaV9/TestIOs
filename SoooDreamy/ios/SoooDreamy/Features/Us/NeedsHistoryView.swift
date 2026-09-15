import SwiftUI
import Combine

/// History of need signals in both directions; open ones from the partner
/// can be acknowledged inline, a new signal goes through the sheet.
struct NeedsHistoryView: View {
    @Environment(AppState.self) private var appState
    @State private var needs: [NeedSignal] = []
    @State private var loading = true
    @State private var busy = false
    @State private var showSheet = false

    var body: some View {
        List {
            if loading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if needs.isEmpty {
                ContentUnavailableView(L10n.t("needs.empty.title"), systemImage: "hand.raised",
                                       description: Text(L10n.t("needs.empty.subtitle")))
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(needs) { need in
                        row(need)
                    }
                } footer: {
                    Text(L10n.t("needs.subtitle"))
                }
            }
        }
        .navigationTitle(L10n.t("needs.history"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSheet = true
                } label: {
                    Label(L10n.t("needs.send"), systemImage: "plus")
                }
                .disabled(appState.partner == nil)
            }
        }
        .sheet(isPresented: $showSheet) { NeedSheet() }
        .task(id: appState.couple?.id) { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent,
                  event.type == .need || event.type == .needAcked,
                  let payload = event.decode(NeedEventPayload.self) else { return }
            apply(payload.need)
        }
    }

    private func row(_ need: NeedSignal) -> some View {
        let mine = need.senderId == appState.memberId
        let type = need.needType
        return HStack(alignment: .top, spacing: 12) {
            IconTile(systemImage: type?.systemImage ?? "hand.raised.fill",
                     tint: mine ? .secondary : .accentColor, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(type.map { L10n.t($0.titleKey) } ?? need.type)
                        .font(.body.weight(.medium))
                    Text(mine ? L10n.t("haptic.fromYou") : L10n.t("haptic.fromPartner", ["name": appState.partnerName]))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let note = need.note, !note.isEmpty {
                    Text("„\(note)“")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text(L10n.relativeShort(need.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if need.ackAt != nil {
                        Label(L10n.t("needs.acked"), systemImage: "heart.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.green)
                    }
                }
                if let ackNote = need.ackNote, !ackNote.isEmpty {
                    Text("↳ „\(ackNote)“")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if !mine, need.ackAt == nil {
                Button(L10n.t("needs.ack")) { acknowledge(need) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(busy)
            }
        }
        .padding(.vertical, 4)
    }

    private func apply(_ need: NeedSignal) {
        if let idx = needs.firstIndex(where: { $0.id == need.id }) {
            needs[idx] = need
        } else {
            needs.insert(need, at: 0)
        }
    }

    private func reload() async {
        guard let api = appState.api else { loading = false; return }
        if let list = try? await api.needs(limit: 50) { needs = list }
        loading = false
    }

    private func acknowledge(_ need: NeedSignal) {
        guard let api = appState.api, !busy else { return }
        busy = true
        Task {
            do {
                let updated = try await api.ackNeed(id: need.id)
                apply(updated)
                SoundEngine.shared.play(.sparkle)
            } catch {
                appState.handleAPIError(error)
            }
            busy = false
        }
    }
}
