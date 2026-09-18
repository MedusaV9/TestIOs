import Foundation

/// Vier Lianen — the anchor format: everyone answers the same MC question,
/// base value + speed bonus, streak counts. Also the fallback for any
/// unavailable playlist wish.
public enum VierLianen: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var core: ChoiceCore
    }

    public static let meta = MinigameMeta(
        id: "vier-lianen", name: "Vier Lianen", emoji: "🌿",
        kurz: "Alle antworten gleichzeitig — schnell UND richtig bringt den Speed-Bonus.",
        erklaerung: "Vier Lianen hängen von der Decke. Nur eine hält! Alle antworten gleichzeitig auf dieselbe Frage. Richtig = Grundwert der Frage, wer in den ersten Sekunden richtig liegt, kassiert bis zu +50 % Speed-Bonus. Drei richtige in Folge zünden die Streak-Lunte (×1,5), fünf sogar ×2.",
        musik: "question_bed_easy"
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        State(core: ChoiceCore(question: FormatHelpers.first(questions, kind: meta.contentKind), ctx: ctx))
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        if case .choose(let i) = action { _ = state.core.answer(player, index: i, now: ctx.now) }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        state.core.applyGm(action, ctx: &ctx)
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {}

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.core.finished(now: ctx.now, ctx: ctx) }

    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] { state.core.standardScores(ctx: ctx, speed: true) }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] { state.core.standardOutcomes(ctx: ctx, speed: true) }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        MinigameStageOutput(wall: state.core.wall(ctx: ctx, revealed: revealed), extra: .none, title: meta.name)
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        state.core.prompt(for: player, ctx: ctx, revealed: revealed)
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        state.core.gmInfo(ctx: ctx)
    }
}

/// Bananen-Basics — the opener. Same mechanics as Vier Lianen, loss-free
/// (a wrong answer never costs anything), the onboarding round.
public enum BananenBasics: MinigamePlugin {
    public typealias State = VierLianen.State

    public static let meta = MinigameMeta(
        id: "bananen-basics", name: "Bananen-Basics", emoji: "🍌",
        kurz: "Warm-up: 4 Farb-Buttons, alle antworten gleichzeitig, falsch kostet nichts.",
        erklaerung: "Das Warm-up der Show. Vier bunte Lianen — 🍌 Gelb, 🥥 Braun, 🐒 Rot, 🌴 Grün — eine hält. Alle antworten gleichzeitig; falsch kostet NICHTS, richtig bringt den Fragenwert plus Speed-Bonus. Wer eingerastet ist, kann nicht mehr wechseln — außer mit dem Rückgaberecht-Joker.",
        musik: "question_bed_easy"
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        VierLianen.initState(questions: questions, songs: songs, ctx: &ctx)
    }
    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        VierLianen.reduce(&state, action: action, from: player, ctx: &ctx)
    }
    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) { VierLianen.gm(&state, action: action, ctx: &ctx) }
    public static func tick(_ state: inout State, ctx: inout MinigameContext) {}
    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { VierLianen.isFinished(state, ctx: ctx) }
    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] { VierLianen.scores(state, ctx: ctx) }
    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] { VierLianen.outcomes(state, ctx: ctx) }
    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        MinigameStageOutput(wall: state.core.wall(ctx: ctx, revealed: revealed), extra: .none, title: meta.name)
    }
    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        VierLianen.prompt(state, player: player, revealed: revealed, ctx: ctx)
    }
    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        VierLianen.gmInfo(state, ctx: ctx)
    }
}

/// Kokosnuss-Uhr — a money sack shrinks in 50-MM ticks; answering freezes YOUR
/// sack. Right = frozen amount, wrong = 0. Replaces the speed bonus.
public enum KokosnussUhr: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var core: ChoiceCore
        public var startSack: Int
        public var ticks: Int
        public var frozen: [PlayerId: Int]
    }

    public static let meta = MinigameMeta(
        id: "kokosnuss-uhr", name: "Kokosnuss-Uhr", emoji: "🥥",
        kurz: "Der Geldsack schrumpft in 50er-Ticks — deine Antwort friert DEINEN Sack ein.",
        erklaerung: "Über der Frage hängt ein prall gefüllter Geldsack, der Tick für Tick um 50 MM schrumpft. Sobald du antwortest, friert DEIN Sack ein: richtig = eingefrorener Betrag, falsch = nichts. Zu lange grübeln kostet also Geld — zu schnell raten auch.",
        musik: "question_bed_easy"
    )

    static func startAmount(_ d: Difficulty) -> Int {
        switch d {
        case .easy: return 200
        case .medium: return 400
        case .hard: return 750
        case .ultrahard: return 1500
        }
    }

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        let q = FormatHelpers.first(questions, kind: meta.contentKind)
        let core = ChoiceCore(question: q, ctx: ctx)
        let start = startAmount(q.schw)
        return State(core: core, startSack: start, ticks: start / 50, frozen: [:])
    }

    static func currentAmount(_ s: State, now: Millis) -> Int {
        let elapsed = max(0, now - s.core.startedAt)
        let tickMs = max(1, s.core.timerMs / max(1, s.ticks))
        let gone = elapsed / tickMs
        return max(0, s.startSack - gone * 50)
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        if case .choose(let i) = action {
            let amount = currentAmount(state, now: ctx.now)
            if state.core.answer(player, index: i, now: ctx.now) {
                state.frozen[player] = amount
            }
        }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) { state.core.applyGm(action, ctx: &ctx) }
    public static func tick(_ state: inout State, ctx: inout MinigameContext) {}
    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.core.finished(now: ctx.now, ctx: ctx) }

    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] {
        var s: [PlayerId: Int] = [:]
        for p in ctx.players {
            let correct = state.core.isCorrect(p) == true
            var win = correct ? (state.frozen[p] ?? 0) : 0
            if correct, state.core.answers[p]?.secondTry == true { win /= 2 }
            s[p] = win
        }
        return s
    }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] { state.core.standardOutcomes(ctx: ctx, speed: false) }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        MinigameStageOutput(wall: state.core.wall(ctx: ctx, revealed: revealed),
                            extra: .sack(current: revealed ? 0 : currentAmount(state, now: ctx.now), start: state.startSack, frozen: state.frozen),
                            title: meta.name)
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed { return state.core.prompt(for: player, ctx: ctx, revealed: true, delta: scores(state, ctx: ctx)[player]) }
        let amount = state.frozen[player] ?? currentAmount(state, now: ctx.now)
        return state.core.prompt(for: player, ctx: ctx, revealed: false, hint: "🥥 Sack: \(Money.format(amount))")
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) { state.core.gmInfo(ctx: ctx) }
}
