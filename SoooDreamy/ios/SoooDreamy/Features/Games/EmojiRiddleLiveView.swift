import SwiftUI

// MARK: - Emoji-Rätsel live (realtime two-phone mode)
//
// Same riddles as the pass-and-play mode, but each partner plays on their
// own phone via the game-session relay (like the couple quiz):
// both see the same seeded deck, type a guess, and once both guesses are
// in the answer is revealed and each player honestly scores their own
// guess ("honor system").
//
// Move protocol:
// - `{"kind": "guess", "round": r, "value": "<free text>"}` (both members)
// - `{"kind": "claim", "round": r, "value": "right" | "wrong"}` (both members,
//   each judging their OWN guess)
//
// Create payload options (ints only, see GameEngine.makePayload):
// - "rounds": requested round count
// - "cats":   category bitmask over `EmojiRiddleLive.categories`
//             (bit i set = category i in play; 0 = all categories)

/// Reducer helpers over payload + moves, shared by the mode switch in
/// `EmojiRiddleView` and the live gameplay below. The pure deck derivation
/// lives in `EmojiRiddleDeck` (Content/ContentModels.swift) so the Linux
/// logic tests can cover it.
@MainActor
enum EmojiRiddleLive {
    /// Canonical category order — the "cats" bitmask indexes into this.
    static let categories = EmojiRiddleDeck.categories

    static func categoryMask(for selected: Set<String>) -> Int {
        EmojiRiddleDeck.categoryMask(for: selected)
    }

    /// Deterministic deck both clients derive from the create payload.
    static func deck(engine: GameEngine) -> [EmojiRiddle] {
        EmojiRiddleDeck.deck(seed: engine.seed,
                             mask: engine.payloadInt("cats", default: 0),
                             rounds: engine.payloadInt("rounds", default: 10))
    }

    /// Effective round count — never larger than the deck (small category
    /// pools may not fill the requested rounds).
    static func totalRounds(engine: GameEngine) -> Int {
        min(engine.payloadInt("rounds", default: 10), deck(engine: engine).count)
    }

    static func guess(engine: GameEngine, round: Int, by memberId: String) -> String? {
        engine.move(kind: "guess", round: round, by: memberId)?.data["value"]?.stringValue
    }

    static func claim(engine: GameEngine, round: Int, by memberId: String) -> String? {
        engine.move(kind: "claim", round: round, by: memberId)?.data["value"]?.stringValue
    }

    /// A round is done once BOTH members judged their own guess.
    static func roundComplete(engine: GameEngine, round: Int, memberIds: [String]) -> Bool {
        guard memberIds.count == 2 else { return false }
        return memberIds.allSatisfy { claim(engine: engine, round: round, by: $0) != nil }
    }

    /// First round without both claims; equals totalRounds when done.
    static func currentRound(engine: GameEngine, memberIds: [String]) -> Int {
        let total = totalRounds(engine: engine)
        for round in 0..<total where !roundComplete(engine: engine, round: round, memberIds: memberIds) {
            return round
        }
        return total
    }

    static func finished(engine: GameEngine, memberIds: [String]) -> Bool {
        let total = totalRounds(engine: engine)
        return total > 0 && currentRound(engine: engine, memberIds: memberIds) >= total
    }

    static func score(engine: GameEngine, memberId: String) -> Int {
        var total = 0
        for round in 0..<totalRounds(engine: engine)
        where claim(engine: engine, round: round, by: memberId) == "right" {
            total += 1
        }
        return total
    }
}

/// Gameplay content for a live emoji-riddle session. The hosting
/// `EmojiRiddleView` owns navigation title, event forwarding and the mode
/// switch — this view only renders the session.
struct EmojiRiddleLiveView: View {
    @Environment(AppState.self) private var appState

    let engine: GameEngine

    @State private var guessText = ""
    @State private var sending = false
    @State private var didSendEnd = false
    @State private var celebrate = false
    @State private var sharing = false
    @State private var shared = false

    private var accent: Color { GameCatalog.info(.emojiriddle)?.tint ?? .orange }

    var body: some View {
        ScrollView {
            content
                .padding(Brand.screenInset)
        }
        .scrollDismissesKeyboard(.interactively)
        .groupedScreenBackground()
        .overlay {
            if celebrate {
                FloatingHeartsView(emojis: ["🧩", "🎉", "💖", "✨", "🏆"], count: 20)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: engine.session?.id) { _, _ in
            resetLocalState()
        }
        .onChange(of: currentRound) { old, new in
            handleRoundAdvance(from: old, to: new)
        }
        .onChange(of: finished) { _, isDone in
            if isDone { handleFinish() }
        }
        .onAppear {
            if finished { handleFinish() }
        }
    }

    // MARK: Derived state (pure reducer over payload + moves)

    private var session: GameSession? {
        guard let current = engine.session, current.kind == .emojiriddle else { return nil }
        return current
    }

    private var sortedMemberIds: [String] {
        (appState.couple?.members.map(\.id) ?? []).sorted()
    }

    private var deck: [EmojiRiddle] { EmojiRiddleLive.deck(engine: engine) }

    private var totalRounds: Int { EmojiRiddleLive.totalRounds(engine: engine) }

    private var currentRound: Int {
        guard session != nil else { return 0 }
        return EmojiRiddleLive.currentRound(engine: engine, memberIds: sortedMemberIds)
    }

    private var finished: Bool {
        session != nil && EmojiRiddleLive.finished(engine: engine, memberIds: sortedMemberIds)
    }

    private var myScore: Int {
        appState.memberId.map { EmojiRiddleLive.score(engine: engine, memberId: $0) } ?? 0
    }

    private var partnerScore: Int {
        appState.partner.map { EmojiRiddleLive.score(engine: engine, memberId: $0.id) } ?? 0
    }

    // MARK: Content switch

    @ViewBuilder
    private var content: some View {
        if appState.partner == nil {
            GameNeedsPartnerView()
        } else if let session {
            if session.state == "lobby" {
                GameLobbyView(engine: engine, accent: accent)
            } else if finished {
                endScreen
            } else {
                playScreen
            }
        }
    }

    // MARK: Play

    private var playScreen: some View {
        VStack(spacing: 14) {
            GameScoreStrip(myScore: myScore, partnerScore: partnerScore)
            GameHeaderBar(title: L10n.t("games.round", ["n": String(min(currentRound + 1, totalRounds)),
                                                       "total": String(totalRounds)]),
                          progress: Double(currentRound) / Double(max(totalRounds, 1)),
                          tint: accent)
            roundCard
        }
    }

    @ViewBuilder
    private var roundCard: some View {
        let round = currentRound
        if round < totalRounds, round < deck.count {
            let riddle = deck[round]
            GamePromptCard(eyebrow: (EmojiRiddleView.categoryEmoji[riddle.category] ?? "") + " "
                           + L10n.t("games.emoji.cat.\(riddle.category)")) {
                Text(riddle.emojis)
                    .font(.system(size: 50))
                    .lineSpacing(8)
                    .minimumScaleFactor(0.6)
                phaseContent(round: round, riddle: riddle)
            }
        }
    }

    @ViewBuilder
    private func phaseContent(round: Int, riddle: EmojiRiddle) -> some View {
        let myId = appState.memberId ?? ""
        let partnerId = appState.partner?.id ?? ""
        let myGuess = EmojiRiddleLive.guess(engine: engine, round: round, by: myId)
        let partnerGuess = EmojiRiddleLive.guess(engine: engine, round: round, by: partnerId)
        if myGuess == nil {
            guessInput(round: round)
        } else if partnerGuess == nil {
            VStack(spacing: 10) {
                GameAnswerBubble(label: L10n.t("games.emoji.live.guessed"), text: myGuess ?? "", tint: .purple)
                GameWaitingHint()
            }
        } else {
            revealSection(round: round, riddle: riddle, myGuess: myGuess ?? "", partnerGuess: partnerGuess ?? "")
        }
    }

    private func guessInput(round: Int) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                TextField(L10n.t("games.emoji.live.guessPlaceholder"), text: $guessText, axis: .vertical)
                    .lineLimit(1...3)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.tertiaryCardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .submitLabel(.send)
                    .onSubmit { submitGuess(round: round) }
                Button {
                    submitGuess(round: round)
                } label: {
                    if sending {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.body.weight(.bold))
                    }
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .disabled(sending || guessText.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel(L10n.t("common.send"))
            }
            Text(L10n.t("games.emoji.live.guessHint"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func revealSection(round: Int, riddle: EmojiRiddle, myGuess: String, partnerGuess: String) -> some View {
        let myId = appState.memberId ?? ""
        let myClaim = EmojiRiddleLive.claim(engine: engine, round: round, by: myId)
        VStack(spacing: 12) {
            GameAnswerBubble(label: L10n.t("games.emoji.live.answerLabel"),
                             text: riddle.answer.resolved(L10n.lang), tint: .orange)
            GameAnswerBubble(label: L10n.t("games.emoji.live.myGuess"), text: myGuess, tint: .purple)
            GameAnswerBubble(label: L10n.t("games.emoji.live.partnerGuess", ["name": appState.partnerName]),
                             text: partnerGuess, tint: .blue)
            if myClaim == nil {
                claimButtons(round: round)
            } else {
                VStack(spacing: 6) {
                    ProgressView()
                    Text(L10n.t("games.emoji.live.waitClaim", ["name": appState.partnerName]))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func claimButtons(round: Int) -> some View {
        VStack(spacing: 10) {
            Text(L10n.t("games.emoji.live.claimQuestion"))
                .font(.subheadline.weight(.medium))
            HStack(spacing: 10) {
                Button {
                    submitClaim(round: round, value: "right")
                } label: {
                    Label(L10n.t("games.emoji.live.claimYes"), systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                Button {
                    submitClaim(round: round, value: "wrong")
                } label: {
                    Label(L10n.t("games.emoji.live.claimNo"), systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .controlSize(.large)
            .disabled(sending)
            Text(L10n.t("games.emoji.live.honor"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Actions

    private func submitGuess(round: Int) {
        let text = guessText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !sending else { return }
        sending = true
        Task {
            let data = GameEngine.moveData(kind: "guess", round: round, value: text)
            if await engine.sendMove(api: appState.api, data: data) {
                guessText = ""
                SoundEngine.shared.play(.pop)
                Haptics.shared.tap()
            }
            sending = false
        }
    }

    private func submitClaim(round: Int, value: String) {
        guard !sending else { return }
        sending = true
        Task {
            let data = GameEngine.moveData(kind: "claim", round: round, value: value)
            if await engine.sendMove(api: appState.api, data: data) {
                if value == "right" {
                    SoundEngine.shared.play(.sparkle)
                    Haptics.shared.success()
                } else {
                    Haptics.shared.tap()
                }
            }
            sending = false
        }
    }

    private func resetLocalState() {
        guessText = ""
        sending = false
        didSendEnd = false
        celebrate = false
        sharing = false
        shared = false
    }

    private func handleRoundAdvance(from old: Int, to new: Int) {
        guard new > old, old < totalRounds, new < totalRounds else { return }
        SoundEngine.shared.play(.whoosh)
    }

    private func handleFinish() {
        guard session != nil else { return }
        if !celebrate {
            celebrate = true
            SoundEngine.shared.play(.tada)
            Haptics.shared.success()
        }
        guard let current = session, current.state == "active", !didSendEnd else { return }
        didSendEnd = true
        Task {
            await engine.end(api: appState.api, result: resultJSON)
        }
    }

    /// Same shape as the quiz result, so the scoreboard can reuse its path.
    private var resultJSON: JSONValue {
        var scores: [String: JSONValue] = [:]
        for id in sortedMemberIds {
            scores[id] = .number(Double(EmojiRiddleLive.score(engine: engine, memberId: id)))
        }
        return .object(["scores": .object(scores)])
    }

    // MARK: End screen

    private var isTie: Bool { myScore == partnerScore }

    private var endTitle: String {
        if isTie { return L10n.t("games.emoji.tie") }
        let winner = myScore > partnerScore ? (appState.me?.name ?? L10n.t("common.you")) : appState.partnerName
        return L10n.t("games.emoji.winner", ["name": winner])
    }

    private var endScreen: some View {
        GameResultCard(title: endTitle, subtitle: L10n.t("games.emoji.finalScore"), emoji: isTie ? "💞" : "🏆") {
            GameFinalScore(myScore: myScore, partnerScore: partnerScore)
            if appState.api != nil {
                GameShareButton(sharing: sharing, shared: shared) { shareToChat() }
            }
            Button {
                rematch()
            } label: {
                Text(L10n.t("games.emoji.rematch"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(engine.busy)
        }
    }

    // MARK: Share to chat

    /// Posts the final score into the couple chat.
    private var shareText: String {
        let header = L10n.t("games.share.header", ["game": "🧩 " + L10n.t("games.emoji.title")])
        let myName = appState.me?.name ?? L10n.t("common.you")
        let scoreLine = "\(myName) \(myScore) : \(partnerScore) \(appState.partnerName)"
        return header + "\n" + scoreLine + "\n" + endTitle
    }

    private func shareToChat() {
        guard let api = appState.api, !sharing, !shared else { return }
        sharing = true
        let text = shareText
        Task {
            do {
                try await api.sendMessage(type: .text, text: text)
                shared = true
                SoundEngine.shared.play(.pop)
                Haptics.shared.success()
                appState.notify(L10n.t("games.sharedToChat"), style: .success)
            } catch {
                appState.handleAPIError(error)
            }
            sharing = false
        }
    }

    private func rematch() {
        guard !engine.busy else { return }
        let rounds = engine.payloadInt("rounds", default: 10)
        let cats = engine.payloadInt("cats", default: 0)
        Task {
            resetLocalState()
            let payload = GameEngine.makePayload(options: ["rounds": rounds, "cats": cats])
            if await engine.create(api: appState.api, type: .emojiriddle, payload: payload) {
                SoundEngine.shared.play(.pop)
                Haptics.shared.tap()
            }
        }
    }
}
