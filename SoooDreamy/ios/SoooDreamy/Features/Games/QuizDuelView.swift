import SwiftUI
import Combine

/// Liebes-Quiz-Duell — buzzer trivia on two phones.
///
/// Both partners see the SAME question (seeded deck) and race: the answer
/// that reaches the server first AND is correct scores 2 points, a later
/// correct answer still gets 1, wrong answers get nothing. Scoring reduces
/// over the moves in server-arrival order (`QuizDuel.scores`,
/// Content/CoupleGamesLogic.swift, pinned by the Linux logic tests).
///
/// Move protocol: `{"kind": "answer", "round": r, "option": 0…2}`.
struct QuizDuelView: View {
    @Environment(AppState.self) private var appState

    let engine: GameEngine

    @State private var sending = false
    @State private var setupRounds = 10
    @State private var didSendEnd = false
    @State private var celebrate = false

    private static let roundOptions = [6, 10, 14]
    private var info: GameInfo? { GameCatalog.info(.quizduel) }
    private var accent: Color { info?.tint ?? .orange }

    var body: some View {
        ScrollView {
            content
                .padding(Brand.screenInset)
        }
        .groupedScreenBackground()
        .overlay {
            if celebrate {
                FloatingHeartsView(emojis: ["⚡️", "🏆", "💖", "✨", "🎉"], count: 22)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .navigationTitle(L10n.t("games.card.quizduel.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            if let event = note.object as? ServerEvent {
                engine.handle(event)
            }
        }
        .task {
            engine.onError = { [weak appState] error in
                appState?.handleAPIError(error)
            }
            if engine.session == nil {
                await engine.resume(api: appState.api)
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

    // MARK: Derived state

    private var session: GameSession? {
        guard let current = engine.session, current.kind == .quizduel else { return nil }
        return current
    }

    private var totalRounds: Int { engine.payloadInt("rounds", default: QuizDuel.defaultRounds) }

    private var memberIds: [String] {
        (appState.couple?.members.map(\.id) ?? []).sorted()
    }

    private var deck: [DuelQuestion] {
        QuizDuel.deck(seed: engine.seed, rounds: totalRounds)
    }

    /// Answers in server-arrival order — the buzzer ranking.
    private var answers: [(memberId: String, round: Int, option: Int)] {
        engine.moves(kind: "answer").compactMap { move in
            guard let round = move.data["round"]?.intValue,
                  let option = move.data["option"]?.intValue else { return nil }
            return (move.memberId, round, option)
        }
    }

    private var currentRound: Int {
        guard session != nil else { return 0 }
        let all = answers
        for round in 0..<min(totalRounds, deck.count)
        where !QuizDuel.bothAnswered(answers: all, round: round, members: memberIds) {
            return round
        }
        return min(totalRounds, deck.count)
    }

    private var finished: Bool {
        guard session != nil, !deck.isEmpty else { return false }
        return currentRound >= min(totalRounds, deck.count)
    }

    private var scores: [String: Int] {
        QuizDuel.scores(answers: answers, deck: deck)
    }

    private func score(for memberId: String) -> Int { scores[memberId] ?? 0 }
    private var myScore: Int { score(for: appState.memberId ?? "") }
    private var partnerScore: Int { score(for: appState.partner?.id ?? "") }

    private func myAnswer(round: Int) -> Int? {
        guard let myId = appState.memberId else { return nil }
        return answers.first { $0.memberId == myId && $0.round == round }?.option
    }

    private func name(of memberId: String) -> String {
        if memberId == appState.memberId {
            return appState.me?.name ?? L10n.t("common.you")
        }
        return appState.partnerName
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
            } else if session.state == "active" {
                playScreen
            } else {
                setupScreen
            }
        } else {
            setupScreen
        }
    }

    // MARK: Setup

    @ViewBuilder
    private var setupScreen: some View {
        if let info {
            GameStartCard(info: info, rules: L10n.t("games.duel.setup.body"),
                          starting: engine.busy, onStart: { startGame(rounds: setupRounds) }) {
                Picker(L10n.t("games.duel.setup.rounds"), selection: $setupRounds) {
                    ForEach(Self.roundOptions, id: \.self) { option in
                        Text("\(option)").tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .sensoryFeedback(.selection, trigger: setupRounds)
            }
        }
    }

    private func startGame(rounds: Int) {
        guard !engine.busy else { return }
        Task {
            resetLocalState()
            let payload = GameEngine.makePayload(options: ["rounds": rounds])
            if await engine.create(api: appState.api, type: .quizduel, payload: payload) {
                SoundEngine.shared.play(.pop)
                Haptics.shared.tap()
            }
        }
    }

    private func resetLocalState() {
        sending = false
        didSendEnd = false
        celebrate = false
    }

    // MARK: Play

    private var playScreen: some View {
        VStack(spacing: 14) {
            GameScoreStrip(myScore: myScore, partnerScore: partnerScore)
            GameHeaderBar(title: L10n.t("games.round", ["n": String(min(currentRound + 1, totalRounds)),
                                                       "total": String(totalRounds)]),
                          progress: Double(currentRound) / Double(max(totalRounds, 1)),
                          tint: accent)
            lastRoundBanner
            roundCard
        }
    }

    /// Recap of the previous round: who buzzed the 2 points, the correct
    /// answer, and my own verdict.
    @ViewBuilder
    private var lastRoundBanner: some View {
        if currentRound > 0, deck.indices.contains(currentRound - 1) {
            let round = currentRound - 1
            let question = deck[round]
            VStack(spacing: 8) {
                GamePhaseLabel(text: recapLine(round: round, question: question),
                               systemImage: recapWasCorrect(round: round) ? "bolt.fill" : "bolt.slash",
                               tint: recapWasCorrect(round: round) ? .green : .secondary)
                Text(L10n.t("games.duel.reveal.answer") + ": "
                     + question.options[question.correct].resolved(L10n.lang))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func recapWasCorrect(round: Int) -> Bool {
        guard let mine = myAnswer(round: round), deck.indices.contains(round) else { return false }
        return mine == deck[round].correct
    }

    private func recapLine(round: Int, question: DuelQuestion) -> String {
        // First correct answer in arrival order took the 2 points.
        let winner = answers.first { $0.round == round && $0.option == question.correct }
        guard let winner else { return L10n.t("games.duel.nobody") }
        let second = answers.first {
            $0.round == round && $0.option == question.correct && $0.memberId != winner.memberId
        }
        var line = L10n.t("games.duel.fast", ["name": name(of: winner.memberId)])
        if let second {
            line += " · " + L10n.t("games.duel.slow", ["name": name(of: second.memberId)])
        }
        return line
    }

    @ViewBuilder
    private var roundCard: some View {
        let round = currentRound
        if round < totalRounds, deck.indices.contains(round) {
            let question = deck[round]
            let mine = myAnswer(round: round)
            GamePromptCard {
                Text(question.text.resolved(L10n.lang))
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 10) {
                    ForEach(question.options.indices, id: \.self) { index in
                        GameChoiceButton(title: question.options[index].resolved(L10n.lang),
                                         selected: mine == index,
                                         disabled: sending || mine != nil,
                                         tint: accent) {
                            submitAnswer(round: round, option: index)
                        }
                    }
                }
                if mine != nil {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(L10n.t("games.duel.answered", ["name": appState.partnerName]))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: Actions

    private func submitAnswer(round: Int, option: Int) {
        guard !sending, myAnswer(round: round) == nil else { return }
        sending = true
        Haptics.shared.tap()
        Task {
            let data = JSONValue.object([
                "kind": .string("answer"),
                "round": .number(Double(round)),
                "option": .number(Double(option))
            ])
            if await engine.sendMove(api: appState.api, data: data) {
                SoundEngine.shared.play(.click)
            }
            sending = false
        }
    }

    private func handleRoundAdvance(from old: Int, to new: Int) {
        guard new > old, old < totalRounds else { return }
        if recapWasCorrect(round: old) {
            SoundEngine.shared.play(.sparkle)
            Haptics.shared.success()
        } else {
            SoundEngine.shared.play(.pop)
        }
    }

    private func handleFinish() {
        guard session != nil else { return }
        if !celebrate {
            celebrate = true
            SoundEngine.shared.play(myScore >= partnerScore ? .win : .lose)
            Haptics.shared.success()
        }
        guard let current = session, current.state == "active", !didSendEnd else { return }
        didSendEnd = true
        Task {
            await engine.end(api: appState.api, result: resultJSON)
        }
    }

    private var resultJSON: JSONValue {
        var result: [String: JSONValue] = [:]
        for id in memberIds {
            result[id] = .number(Double(score(for: id)))
        }
        return .object(["scores": .object(result)])
    }

    // MARK: End screen

    private var endScreen: some View {
        GameResultCard(title: L10n.t("games.quiz.end.title"), emoji: "⚡️") {
            GameFinalScore(myScore: myScore, partnerScore: partnerScore)
            Text(endVerdictLine)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                startGame(rounds: totalRounds)
            } label: {
                Text(L10n.t("games.rematch"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(engine.busy)
        }
    }

    private var endVerdictLine: String {
        guard let myId = appState.memberId, let partnerId = appState.partner?.id else { return "" }
        let mine = score(for: myId)
        let theirs = score(for: partnerId)
        if mine == theirs {
            return L10n.t("games.duel.end.tie")
        }
        let winner = mine > theirs ? name(of: myId) : name(of: partnerId)
        return L10n.t("games.duel.end.winner", ["name": winner])
    }
}
