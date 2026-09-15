import SwiftUI
import Observation

// MARK: - Seal tokens

/// "Öffnen wenn …" seals for love letters. A seal is stored in
/// `Message.openWhen` as a token ("sad", "night", …) or "custom:<text>".
enum LetterSeal {
    static let customPrefix = "custom:"
    static let presetTokens = ["sad", "missme", "happy", "badday", "night", "anniversary"]

    static func isCustom(_ token: String) -> Bool {
        token.hasPrefix(customPrefix)
    }

    static func customText(_ token: String) -> String? {
        guard token.hasPrefix(customPrefix) else { return nil }
        let text = String(token.dropFirst(customPrefix.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    static func emoji(for token: String) -> String {
        switch token {
        case "sad": return "😢"
        case "missme": return "🥺"
        case "happy": return "🥳"
        case "badday": return "🌧️"
        case "night": return "🌙"
        case "anniversary": return "💍"
        default: return "💌"
        }
    }

    /// Short label for the compose chips.
    static func chipLabel(for token: String) -> String {
        if let custom = customText(token) { return custom }
        if presetTokens.contains(token) { return L10n.t("chat.seal.\(token)") }
        return L10n.t("chat.sealLine.generic")
    }

    /// Warm full sentence shown on the sealed envelope / seal chip.
    static func sentence(for token: String) -> String {
        if let custom = customText(token) {
            return L10n.t("chat.sealLine.custom", ["text": custom])
        }
        if presetTokens.contains(token) { return L10n.t("chat.sealLine.\(token)") }
        return L10n.t("chat.sealLine.generic")
    }
}

// MARK: - Opened letters persistence

/// Remembers which sealed letters were opened on this device,
/// per couple (UserDefaults key "sooodreamy.openedLetters.<coupleId>").
@MainActor
@Observable
final class OpenedLettersStore {
    static let shared = OpenedLettersStore()

    /// Bumped on every change so SwiftUI re-reads `isOpened`.
    private(set) var version = 0
    @ObservationIgnored private var cache: [String: Set<String>] = [:]

    private init() {}

    func isOpened(_ messageId: String, coupleId: String?) -> Bool {
        _ = version
        guard let coupleId else { return false }
        return openedIds(coupleId).contains(messageId)
    }

    func markOpened(_ messageId: String, coupleId: String?) {
        guard let coupleId else { return }
        var ids = openedIds(coupleId)
        guard !ids.contains(messageId) else { return }
        ids.insert(messageId)
        cache[coupleId] = ids
        UserDefaults.standard.set(Array(ids).sorted(), forKey: storageKey(coupleId))
        version += 1
    }

    private func storageKey(_ coupleId: String) -> String {
        "sooodreamy.openedLetters.\(coupleId)"
    }

    private func openedIds(_ coupleId: String) -> Set<String> {
        if let cached = cache[coupleId] { return cached }
        let stored = Set(UserDefaults.standard.stringArray(forKey: storageKey(coupleId)) ?? [])
        cache[coupleId] = stored
        return stored
    }
}

// MARK: - Sealed envelope card

/// Closed-envelope look for a received, not-yet-opened sealed letter.
// MARK: - Sealed envelope card

/// Closed envelope for a received, not-yet-opened sealed letter.
struct SealedLetterCard: View {
    let message: Message
    let unsealing: Bool
    let onOpen: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.bounce, value: unsealing)
                .accessibilityHidden(true)
            Text(L10n.t("chat.sealedTitle"))
                .font(.headline)
            if let token = message.openWhen {
                Label(LetterSeal.sentence(for: token), systemImage: "lock.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                onOpen()
            } label: {
                Label(L10n.t("chat.sealedOpen"), systemImage: "envelope.open")
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.glassProminent)
            .disabled(unsealing)
        }
        .frame(maxWidth: 280)
        .padding(18)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
        }
        .scaleEffect(unsealing ? 1.05 : 1)
        .rotation3DEffect(.degrees(unsealing ? 360 : 0), axis: (x: 0, y: 1, z: 0))
        .animation(.easeInOut(duration: 0.65), value: unsealing)
    }
}

// MARK: - Reader

/// Full-screen reading view for a letter (serif body, seal line, meta).
struct LetterReaderView: View {
    @Environment(\.dismiss) private var dismiss
    let message: Message
    let senderName: String

    private var titleText: String {
        if let title = message.title, !title.isEmpty { return title }
        return L10n.t("chat.letterUntitled")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let token = message.openWhen {
                        Label(LetterSeal.sentence(for: token), systemImage: "lock.open")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.accentColor)
                    }
                    Text(message.text ?? "")
                        .font(.body)
                        .fontDesign(.serif)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Divider()
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("chat.readerFrom", ["name": senderName]))
                            .font(.subheadline.weight(.medium))
                        Text(message.createdAt.formatted(date: .long, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(Brand.screenInset)
            }
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("chat.readerClose")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: [message.title, message.text].compactMap { $0 }.joined(separator: "\n\n"))
                }
            }
        }
    }
}

// MARK: - Composer

/// Love-letter composer: title, long text, optional "Öffnen wenn …" seal.
struct LetterComposeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private enum SealChoice: Hashable {
        case none
        case preset(String)
        case custom
    }

    @State private var title = ""
    @State private var text = ""
    @State private var sealChoice: SealChoice = .none
    @State private var customSeal = ""
    @State private var sending = false
    @FocusState private var textFocused: Bool
    let onSent: (Message) -> Void

    /// Pre-filled when forwarding an existing letter (the seal is not copied).
    init(initialTitle: String = "", initialText: String = "", onSent: @escaping (Message) -> Void) {
        _title = State(initialValue: initialTitle)
        _text = State(initialValue: initialText)
        self.onSent = onSent
    }

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var openWhenToken: String? {
        switch sealChoice {
        case .none:
            return nil
        case .preset(let token):
            return token
        case .custom:
            let custom = customSeal.trimmingCharacters(in: .whitespacesAndNewlines)
            return custom.isEmpty ? nil : LetterSeal.customPrefix + custom
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.t("chat.letterTitlePlaceholder"), text: $title)
                        .font(.headline)
                    TextField(L10n.t("chat.letterPlaceholder"), text: $text, axis: .vertical)
                        .lineLimit(6...16)
                        .fontDesign(.serif)
                        .focused($textFocused)
                }

                Section {
                    Picker(L10n.t("chat.sealPickerTitle"), selection: $sealChoice) {
                        Text(L10n.t("chat.sealNone")).tag(SealChoice.none)
                        ForEach(LetterSeal.presetTokens, id: \.self) { token in
                            Text("\(LetterSeal.emoji(for: token)) \(LetterSeal.chipLabel(for: token))")
                                .tag(SealChoice.preset(token))
                        }
                        Text(L10n.t("chat.sealCustom")).tag(SealChoice.custom)
                    }
                    .pickerStyle(.navigationLink)
                    if sealChoice == .custom {
                        TextField(L10n.t("chat.sealCustomPlaceholder"), text: $customSeal)
                    }
                } header: {
                    Text(L10n.t("chat.sealPickerTitle"))
                } footer: {
                    if let token = openWhenToken {
                        Text(LetterSeal.sentence(for: token))
                    } else {
                        Text(L10n.t("chat.sealHint", ["name": appState.partnerName]))
                    }
                }
            }
            .navigationTitle(L10n.t("chat.letterTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("chat.cancel")) { dismiss() }
                        .disabled(sending)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        send()
                    } label: {
                        if sending {
                            ProgressView()
                        } else {
                            Text(L10n.t("chat.letterSend"))
                        }
                    }
                    .disabled(sending || trimmedText.isEmpty)
                }
            }
        }
        .interactiveDismissDisabled(sending)
        .onAppear { if text.isEmpty { textFocused = true } }
    }

    private func send() {
        guard let api = appState.api, !sending, !trimmedText.isEmpty else { return }
        sending = true
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                let message = try await api.sendMessage(type: .letter, text: trimmedText,
                                                        title: trimmedTitle.isEmpty ? nil : trimmedTitle,
                                                        openWhen: openWhenToken)
                SoundEngine.shared.play(.letterSeal)
                appState.notify(L10n.t("chat.letterSent"), style: .love)
                onSent(message)
                dismiss()
            } catch {
                sending = false
                appState.handleAPIError(error)
            }
        }
    }
}
