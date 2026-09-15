import SwiftUI
import Observation

// MARK: - Pinned messages persistence (v1.5.3)

/// One locally pinned chat message. The preview is snapshotted at pin time
/// so the banner can render even when the message is outside the currently
/// loaded chat window (older pages are fetched lazily).
struct PinnedMessageEntry: Codable, Equatable, Identifiable {
    let id: String          // message id
    let kind: String        // MessageKind rawValue
    let preview: String     // trimmed text/title snapshot ("" when none)
    let pinnedAt: Date
}

/// Remembers which chat messages were pinned on this device, per couple
/// (UserDefaults key "sooodreamy.pinnedMessages.<coupleId>"), newest pin
/// last. Deliberately local-only: a pin is a personal bookmark — the
/// partner's device stays untouched and no server support is needed.
@MainActor
@Observable
final class PinnedMessagesStore {
    static let shared = PinnedMessagesStore()

    /// Keep the list small — it's a bookmark ribbon, not an archive.
    private static let cap = 30

    /// Bumped on every change so SwiftUI re-reads the accessors.
    private(set) var version = 0
    @ObservationIgnored private var cache: [String: [PinnedMessageEntry]] = [:]

    private init() {}

    func isPinned(_ messageId: String, coupleId: String?) -> Bool {
        _ = version
        guard let coupleId else { return false }
        return entries(coupleId: coupleId).contains { $0.id == messageId }
    }

    /// All pins in pin order (oldest first, newest pin last).
    func entries(coupleId: String?) -> [PinnedMessageEntry] {
        _ = version
        guard let coupleId else { return [] }
        if let cached = cache[coupleId] { return cached }
        let key = storageKey(coupleId)
        let stored: [PinnedMessageEntry]
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([PinnedMessageEntry].self, from: data) {
            stored = decoded
        } else {
            stored = []
        }
        cache[coupleId] = stored
        return stored
    }

    /// Pin ⇄ unpin. Pinning past the cap drops the oldest pin.
    func toggle(_ message: Message, coupleId: String?) {
        guard let coupleId else { return }
        var list = entries(coupleId: coupleId)
        if let idx = list.firstIndex(where: { $0.id == message.id }) {
            list.remove(at: idx)
        } else {
            let preview = (message.title?.isEmpty == false ? message.title : message.text) ?? ""
            list.append(PinnedMessageEntry(id: message.id,
                                           kind: message.type.rawValue,
                                           preview: preview.trimmingCharacters(in: .whitespacesAndNewlines),
                                           pinnedAt: Date()))
            if list.count > Self.cap {
                list.removeFirst(list.count - Self.cap)
            }
        }
        persist(list, coupleId: coupleId)
    }

    /// Remove one pin by message id (used by the banner's unpin button).
    func unpin(_ messageId: String, coupleId: String?) {
        guard let coupleId else { return }
        var list = entries(coupleId: coupleId)
        list.removeAll { $0.id == messageId }
        persist(list, coupleId: coupleId)
    }

    private func persist(_ list: [PinnedMessageEntry], coupleId: String) {
        cache[coupleId] = list
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: storageKey(coupleId))
        }
        version += 1
    }

    private func storageKey(_ coupleId: String) -> String {
        "sooodreamy.pinnedMessages.\(coupleId)"
    }
}

// MARK: - Pin/unpin context-menu row

/// Only server-confirmed messages can be pinned (temp ids don't survive).
struct ChatPinButton: View {
    @Environment(AppState.self) private var appState
    let message: Message

    var body: some View {
        if !message.id.hasPrefix("local-") {
            let pinned = PinnedMessagesStore.shared.isPinned(message.id, coupleId: appState.couple?.id)
            Button {
                let wasPinned = pinned
                PinnedMessagesStore.shared.toggle(message, coupleId: appState.couple?.id)
                appState.notify(L10n.t(wasPinned ? "chat.unpinnedToast" : "chat.pinnedToast"), style: .info)
            } label: {
                Label(L10n.t(pinned ? "chat.unpin" : "chat.pin"), systemImage: pinned ? "pin.slash" : "pin")
            }
        }
    }
}

// MARK: - Pinned banner

/// Compact glass banner under the navigation bar with the newest pin;
/// tap jumps to the message, the pin button removes it.
struct ChatPinnedBanner: View {
    @Environment(AppState.self) private var appState
    let messages: [Message]
    let onJump: (String) -> Void

    private var newest: PinnedMessageEntry? {
        PinnedMessagesStore.shared.entries(coupleId: appState.couple?.id).last
    }

    private var pinCount: Int {
        PinnedMessagesStore.shared.entries(coupleId: appState.couple?.id).count
    }

    var body: some View {
        if let entry = newest {
            HStack(spacing: 10) {
                Image(systemName: "pin.fill")
                    .font(.footnote)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(L10n.t("chat.pinnedBadge"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                        if pinCount > 1 {
                            Text(L10n.t("chat.pinnedMore", ["n": String(pinCount - 1)]))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(displayText(entry))
                        .font(.footnote)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button {
                    PinnedMessagesStore.shared.unpin(entry.id, coupleId: appState.couple?.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(L10n.t("chat.unpin"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .contentShape(Rectangle())
            .onTapGesture { onJump(entry.id) }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(L10n.t("chat.pinnedJumpA11y"))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func displayText(_ entry: PinnedMessageEntry) -> String {
        switch MessageKind(rawValue: entry.kind) {
        case .voice:
            return "🎤 " + L10n.t("chat.voiceMessage")
        case .photo:
            return entry.preview.isEmpty ? "📸 " + L10n.t("chat.photoMessage") : "📸 " + entry.preview
        case .letter:
            return entry.preview.isEmpty ? "💌 " + L10n.t("chat.letterBadge") : "💌 " + entry.preview
        default:
            return entry.preview
        }
    }
}
