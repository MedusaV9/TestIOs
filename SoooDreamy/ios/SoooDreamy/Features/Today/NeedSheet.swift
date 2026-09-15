import SwiftUI
import Combine

/// "Ich brauche gerade …" — one-tap, shame-free signal to the partner.
struct NeedSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selected: NeedType?
    @State private var note = ""
    @State private var sending = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(L10n.t("needs.sheet.subtitle", ["name": appState.partnerName]))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(NeedType.allCases) { type in
                            Button {
                                withAnimation(.snappy) { selected = type }
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: type.systemImage)
                                        .font(.title2)
                                        .foregroundStyle(selected == type ? Color.white : Color.accentColor)
                                    Text(L10n.t(type.titleKey))
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(selected == type ? Color.white : Color.primary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity, minHeight: 92)
                                .padding(8)
                                .background(
                                    selected == type ? Color.accentColor : Color.cardBackground,
                                    in: RoundedRectangle(cornerRadius: Brand.tileRadius, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selected == type ? .isSelected : [])
                        }
                    }

                    TextField(L10n.t("needs.noteField"), text: $note, axis: .vertical)
                        .lineLimit(1...3)
                        .padding(12)
                        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Brand.tileRadius, style: .continuous))
                }
                .padding(Brand.screenInset)
            }
            .groupedScreenBackground()
            .navigationTitle(L10n.t("needs.button.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
            }
            .safeAreaBar(edge: .bottom) {
                Button {
                    send()
                } label: {
                    HStack {
                        if sending { ProgressView().tint(.white) }
                        Text(L10n.t("needs.sendTo", ["name": appState.partnerName]))
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(selected == nil || sending || appState.partner == nil)
                .padding(.horizontal, Brand.screenInset)
                .padding(.bottom, 8)
            }
        }
        .presentationDetents([.large])
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func send() {
        guard let api = appState.api, let type = selected, !sending else { return }
        sending = true
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                _ = try await api.sendNeed(type: type, note: text.isEmpty ? nil : text)
                SoundEngine.shared.play(.pop)
                appState.notify(L10n.t("needs.sentToast", ["name": appState.partnerName]), style: .love)
                dismiss()
            } catch {
                appState.handleAPIError(error)
            }
            sending = false
        }
    }
}

extension NeedType {
    var systemImage: String {
        switch self {
        case .space: return "leaf.fill"
        case .comfort: return "hands.and.sparkles.fill"
        case .distraction: return "gamecontroller.fill"
        case .closeness: return "heart.fill"
        case .listen: return "ear.fill"
        case .love: return "sun.max.fill"
        case .presence: return "person.2.fill"
        }
    }
}

/// The partner's open need signal — shown at the top of Today's rituals
/// until acknowledged.
struct PartnerNeedBanner: View {
    @Environment(AppState.self) private var appState
    @State private var openNeed: NeedSignal?
    @State private var busy = false

    var body: some View {
        Group {
            if let need = openNeed, let type = need.needType {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        IconTile(systemImage: type.systemImage, tint: .accentColor, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t("needs.partnerNeeds", ["name": appState.partnerName]))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(L10n.t(type.titleKey))
                                .font(.headline)
                        }
                        Spacer()
                        Text(L10n.relativeShort(need.createdAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let note = need.note, !note.isEmpty {
                        Text("„\(note)“")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        acknowledge(need)
                    } label: {
                        Label(L10n.t("needs.ack"), systemImage: "heart.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(busy)
                }
                .cardSurface()
                .overlay {
                    RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1)
                }
            }
        }
        .task(id: appState.couple?.id) { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent,
                  event.type == .need || event.type == .needAcked,
                  let payload = event.decode(NeedEventPayload.self) else { return }
            apply(payload.need)
        }
    }

    private func apply(_ need: NeedSignal) {
        guard need.forMember == appState.memberId else { return }
        withAnimation(.snappy) {
            if need.ackAt == nil {
                openNeed = need
            } else if openNeed?.id == need.id {
                openNeed = nil
            }
        }
    }

    private func reload() async {
        guard let api = appState.api, let me = appState.memberId else { return }
        if let needs = try? await api.needs(limit: 10) {
            openNeed = needs.first { $0.forMember == me && $0.ackAt == nil }
        }
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
