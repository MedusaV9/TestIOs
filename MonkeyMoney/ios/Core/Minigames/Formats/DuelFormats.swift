import Foundation

/// Shared sequencing for round-based formats that run a series of MC
/// questions with a short internal reveal between them.
public struct SeriesCore: Codable, Equatable, Sendable {
    public var questions: [Question]
    public var index: Int
    public var core: ChoiceCore?
    public var revealUntil: Millis?
    public var finished: Bool
    public var maxQuestions: Int
    /// Questions the Show-Master dropped (skip / swap) — they never count.
    public var skipped: Int?

    public init(questions: [Question], maxQuestions: Int, ctx: inout MinigameContext, timerMs: Int) {
        // No placeholder question: an empty stack simply ends the series (nothing to rate).
        self.questions = questions
        index = 0
        core = nil
        revealUntil = nil
        finished = false
        skipped = nil
        self.maxQuestions = min(maxQuestions, questions.count)
        start(ctx: &ctx, timerMs: timerMs)
    }

    public var current: Question? { core?.question }
    /// Number of the running question within the series (dropped ones don't count).
    public var questionNumber: Int { index - (skipped ?? 0) }
    /// Length of the series as shown ("Frage 3/7").
    public var total: Int { maxQuestions - (skipped ?? 0) }

    public mutating func start(ctx: inout MinigameContext, timerMs: Int) {
        guard index < maxQuestions, index < questions.count else { finished = true; revealUntil = nil; return }
        var qctx = ctx
        qctx.mods = QuestionMods()
        core = ChoiceCore(question: questions[index], ctx: qctx, timerMs: timerMs)
        index += 1
        revealUntil = nil
    }

    /// GM skip / swap: the running question is dropped unrated and the next one
    /// starts at once; a spare from the round's reserve keeps the series length.
    /// During an internal reveal it just cuts the reveal short.
    public mutating func skip(ctx: inout MinigameContext, timerMs: Int) {
        guard !finished else { return }
        if revealUntil == nil {
            skipped = (skipped ?? 0) + 1
            if questions.count > maxQuestions { maxQuestions += 1 }
        }
        start(ctx: &ctx, timerMs: timerMs)
    }

    public mutating func extend(ms: Int) { if revealUntil == nil { core?.extend(ms: ms) } }

    /// Resolve the running question now (GM "Weiter"): answers given so far count.
    /// Returns true when there was an open question to rate.
    public mutating func closeRunning(now: Millis) -> Bool {
        guard !finished, revealUntil == nil, core != nil, core?.finishedAt == nil else { return false }
        core?.finishedAt = now
        return true
    }

    /// Call from tick: returns true exactly once when the current question just finished.
    public mutating func advance(ctx: inout MinigameContext, revealMs: Int, timerMs: Int) -> Bool {
        guard !finished, let c = core else { return false }
        if let r = revealUntil {
            if ctx.now >= r { start(ctx: &ctx, timerMs: timerMs) }
            return false
        }
        if c.finished(now: ctx.now, ctx: ctx) {
            revealUntil = ctx.now + ctx.ms(revealMs)
            return true
        }
        return false
    }

    public var inReveal: Bool { revealUntil != nil }
    public mutating func shift(ms: Int) { core?.shift(ms: ms); if let r = revealUntil { revealUntil = r + ms } }
}

/// Duell am Lianensteg — 1v1 best-of-5 with spectator bets (50 MM).
public enum LianenstegDuell: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var series: SeriesCore
        public var a: PlayerId
        public var b: PlayerId
        public var scoreA: Int
        public var scoreB: Int
        public var bets: [PlayerId: PlayerId]
        public var phase: String // wetten | duell | fertig
        public var betUntil: Millis
        public var lastPoint: PlayerId?
    }

    static let timerMs = 12_000

    public static let meta = MinigameMeta(
        id: "lianensteg-duell", name: "Duell am Lianensteg", emoji: "⚔️",
        kurz: "1v1 Best-of-5 auf dem Hängesteg — die Zuschauer wetten 50 MM auf den Sieger.",
        erklaerung: "Zwei Affen treffen sich auf dem wackligen Lianensteg: Best-of-5, wer eine Frage zuerst richtig beantwortet, holt den Punkt. Alle anderen wetten vorher 50 MM auf ihren Favoriten. Der Sieger bekommt 300 MM aus der Bank plus 100 MM vom Verlierer, die richtigen Wetter teilen sich den Wett-Topf.",
        regeln: ["Zwei Affen duellieren sich auf dem Steg: Best-of-5",
                 "Wer eine Frage zuerst richtig beantwortet, holt den Punkt",
                 "Alle anderen wetten vorher 50 MM auf den Sieger",
                 "Sieger: 300 MM + 100 MM vom Verlierer · richtige Wetter teilen den Topf",
                 "Unentschieden: kein Sieger, alle Wetten zurück"],
        gewinn: "Sieger +300 MM (+100 vom Verlierer) · Wette: 50 MM Einsatz",
        contentKind: .choiceLike, roundBased: true, streak: false, jokerAktionen: [], isMc: true, musik: "duel_showdown", v2: true
    )

    static func pickDuelists(ctx: inout MinigameContext) -> (PlayerId, PlayerId) {
        let ranked = ctx.players.filter { ctx.connected.contains($0) }.sorted { (ctx.balances[$0] ?? 0) > (ctx.balances[$1] ?? 0) }
        guard ranked.count >= 2 else { return (ctx.players[0], ctx.players.count > 1 ? ctx.players[1] : ctx.players[0]) }
        // Two neighbours in the standings make the tightest duel.
        let i = ctx.rng.below(ranked.count - 1)
        return (ranked[i], ranked[i + 1])
    }

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        let (a, b) = pickDuelists(ctx: &ctx)
        let series = SeriesCore(questions: FormatHelpers.fitting(questions, kind: meta.contentKind), maxQuestions: 7, ctx: &ctx, timerMs: ctx.answerWindow(timerMs))
        var s = State(series: series, a: a, b: b, scoreA: 0, scoreB: 0, bets: [:], phase: ctx.players.count > 2 ? "wetten" : "duell", betUntil: ctx.now + ctx.answerWindow(10_000), lastPoint: nil)
        if s.phase == "wetten" { s.series.core?.startedAt = 0 }
        if s.series.finished { s.phase = "fertig" }
        return s
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        switch (state.phase, action) {
        case ("wetten", .pickPlayer(let p)):
            guard player != state.a, player != state.b, p == state.a || p == state.b else { return }
            state.bets[player] = p
        case ("duell", .choose(let i)):
            guard player == state.a || player == state.b, !state.series.inReveal, var c = state.series.core else { return }
            if c.answer(player, index: i, now: ctx.now) { state.series.core = c }
        default: break
        }
    }

    static func startDuel(_ state: inout State, ctx: MinigameContext) {
        state.phase = "duell"
        let timer = state.series.core?.timerMs ?? ctx.answerWindow(timerMs)
        state.series.core?.startedAt = ctx.now
        state.series.core?.deadline = ctx.now + timer
    }

    /// Point for the faster correct duelist of the question that just closed.
    static func ratePoint(_ state: inout State) {
        guard let c = state.series.core else { return }
        let w = c.correctByTime([state.a, state.b]).first
        if let w = w { if w == state.a { state.scoreA += 1 } else { state.scoreB += 1 } }
        state.lastPoint = w
        if state.scoreA >= 3 || state.scoreB >= 3 { state.series.finished = true }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        switch action {
        case .forceFinish:
            // "Weiter": the running question still counts, then the duel ends.
            if state.phase == "duell", state.series.closeRunning(now: ctx.now) { ratePoint(&state) }
            state.phase = "fertig"
            state.series.finished = true
        case .skipQuestion:
            if state.phase == "wetten" { startDuel(&state, ctx: ctx); return }
            guard state.phase == "duell" else { return }
            state.series.skip(ctx: &ctx, timerMs: ctx.answerWindow(timerMs))
            if state.series.finished { state.phase = "fertig" }
        case .timerShift(let ms): state.series.shift(ms: ms); state.betUntil += ms
        case .timerExtend(let ms): if state.phase == "wetten" { state.betUntil += ms } else { state.series.extend(ms: ms) }
        case .removeOption(nil): if state.phase == "duell", !state.series.inReveal { state.series.core?.hintStep(rng: &ctx.rng) }
        default: break
        }
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {
        switch state.phase {
        case "wetten":
            let spectators = ctx.players.filter { $0 != state.a && $0 != state.b && ctx.connected.contains($0) }
            if ctx.now >= state.betUntil || spectators.allSatisfy({ state.bets[$0] != nil }) { startDuel(&state, ctx: ctx) }
        case "duell":
            var dctx = ctx
            dctx.players = [state.a, state.b]
            if state.series.advance(ctx: &dctx, revealMs: 2500, timerMs: ctx.answerWindow(timerMs)) { ratePoint(&state) }
            ctx.rng = dctx.rng
            if state.series.finished, state.series.revealUntil.map({ ctx.now >= $0 }) ?? true { state.phase = "fertig" }
        default: break
        }
    }

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.phase == "fertig" }

    static func winner(_ s: State) -> PlayerId? { s.scoreA == s.scoreB ? nil : (s.scoreA > s.scoreB ? s.a : s.b) }

    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] {
        var s: [PlayerId: Int] = [:]
        for p in ctx.players { s[p] = 0 }
        guard let w = winner(state) else { return s }
        let l = w == state.a ? state.b : state.a
        s[w] = 300 + 100
        s[l] = -100
        let bettors = FormatHelpers.inOrder(state.bets.keys, ctx.players)
        let right = bettors.filter { state.bets[$0] == w }
        let pot = bettors.count * 50
        for p in bettors { s[p, default: 0] -= 50 }
        if !right.isEmpty { let share = Economy.roundTo10(pot / right.count); for p in right { s[p, default: 0] += share } }
        return s
    }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        var out: [PlayerId: Outcome] = [:]
        let w = winner(state)
        for p in ctx.players {
            if p == state.a || p == state.b { out[p] = Outcome(correct: w == nil ? nil : w == p, countsForStreak: false, detail: "\(state.scoreA):\(state.scoreB)") }
            else { out[p] = Outcome(correct: w == nil ? nil : state.bets[p].map { $0 == w }, countsForStreak: false, detail: state.bets[p].map { "Wette auf \(ctx.name($0))" }) }
        }
        return out
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        var qctx = ctx
        qctx.players = [state.a, state.b]
        qctx.fragenNummer = state.series.questionNumber
        qctx.fragenGesamt = state.series.total
        let wall = state.phase == "duell" && !revealed ? state.series.core?.wall(ctx: qctx, revealed: state.series.inReveal) : nil
        let label: String
        if state.phase == "wetten" { label = "Wetten, bitte! \(ctx.name(state.a)) oder \(ctx.name(state.b))?" }
        else if revealed || state.phase == "fertig" { label = winner(state).map { "\(ctx.name($0)) gewinnt das Duell!" } ?? "Unentschieden — Wetten zurück" }
        else if state.series.inReveal { label = state.lastPoint.map { "Punkt für \(ctx.name($0))!" } ?? "Kein Punkt — beide daneben" }
        else { label = "Best-of-5 · Frage \(state.series.questionNumber) · wer zuerst richtig liegt" }
        return MinigameStageOutput(wall: wall, extra: .duel(a: state.a, b: state.b, scoreA: state.scoreA, scoreB: state.scoreB, maxScore: 3, bets: state.bets, phase: revealed ? "fertig" : state.phase, label: label),
                                   title: "\(meta.name) · \(state.scoreA):\(state.scoreB)")
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        let score = "\(ctx.name(state.a)) \(state.scoreA):\(state.scoreB) \(ctx.name(state.b))"
        if revealed {
            let s = scores(state, ctx: ctx)[player] ?? 0
            let title = winner(state) == nil ? "Unentschieden" : (s > 0 ? "Gewonnen!" : (s < 0 ? "Verloren" : "±0"))
            return .reveal(title: title, correct: winner(state) == nil ? nil : s > 0, delta: s, detail: score, streak: 0, speedBonus: nil)
        }
        let duelist = player == state.a || player == state.b
        if state.phase == "wetten" {
            if duelist { return .idle(title: "⚔️ Du stehst auf dem Steg!", subtitle: "Gegner: \(ctx.name(player == state.a ? state.b : state.a)) — die anderen wetten gerade auf euch. Gleich geht's los!") }
            let refs = [state.a, state.b].map { PlayerRef(Player(id: $0, name: ctx.name($0), avatar: Avatar(), joinOrder: 0), platz: 0) }
            return .pickPlayer(title: "Wer gewinnt das Duell?", subtitle: state.bets[player] == nil ? "Wette: 50 MM — richtige Wetter teilen den Topf" : "Wette steht — warte auf die anderen …",
                               candidates: refs, chosen: state.bets[player], deadline: ctx.visible(state.betUntil))
        }
        guard let c = state.series.core, state.phase == "duell" else { return .idle(title: "⚔️ Duell vorbei", subtitle: score) }
        if duelist {
            if state.series.inReveal {
                let title = state.lastPoint == player ? "PUNKT!" : (state.lastPoint == nil ? "Kein Punkt" : "Punkt für \(ctx.name(state.lastPoint!))")
                return .reveal(title: title, correct: c.isCorrect(player), delta: 0, detail: "\(score) · Richtig war: \(c.options[c.correctIndex])", streak: 0, speedBonus: nil)
            }
            if c.hasAnswered(player) { return .idle(title: "🔒 Eingeloggt!", subtitle: "\(score) — der schnellere Richtige holt den Punkt") }
            return c.prompt(for: player, ctx: ctx, revealed: false, hint: "⚔️ \(state.scoreA):\(state.scoreB) · schneller richtig = Punkt")
        }
        return .cheer(title: "⚔️ \(score)", subtitle: state.bets[player].map { "Deine Wette: \(ctx.name($0)) — anfeuern!" } ?? "Feuere die beiden an!", taps: 0)
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        var g: (question: GmQuestionInfo?, answers: [PlayerId: String]) = state.series.core?.gmInfo(ctx: ctx) ?? (nil, [:])
        for (p, v) in state.bets { g.answers[p] = "Wette auf \(ctx.name(v))" }
        return g
    }
    public static func questionsUsed(_ state: State) -> Int { max(1, state.series.index) }
}

/// Bananen-Boxkampf — 1v1, 3 HP each, correct + faster lands a hit, K.O. ends early.
public enum BananenBoxkampf: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var series: SeriesCore
        public var a: PlayerId
        public var b: PlayerId
        public var hpA: Int
        public var hpB: Int
        public var lastHit: PlayerId?
    }

    static let timerMs = 10_000

    public static let meta = MinigameMeta(
        id: "bananen-boxkampf", name: "Bananen-Boxkampf", emoji: "🥊",
        kurz: "1v1 im Ring: richtig und schneller = Treffer, drei Treffer = K.O.",
        erklaerung: "Ring frei! Zwei Affen boxen: Pro Frage landet der schnellere Richtige einen Treffer. Jeder hat 3 Herzen — wer zuerst dreimal getroffen wird, geht K.O. Acht Runden, sonst Punktsieg nach Herzen. Sieg zahlt 400 MM.",
        regeln: ["Ring frei: 1 gegen 1, jeder hat 3 Herzen",
                 "Pro Frage landet der schnellere Richtige einen Treffer",
                 "Drei Treffer = K.O.",
                 "Nach 8 Runden entscheiden die Herzen — Gleichstand: kein Sieger"],
        gewinn: "Sieg +400 MM",
        contentKind: .choiceLike, roundBased: true, streak: false, jokerAktionen: [], isMc: true, musik: "duel_showdown", v2: true
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        let (a, b) = LianenstegDuell.pickDuelists(ctx: &ctx)
        return State(series: SeriesCore(questions: FormatHelpers.fitting(questions, kind: meta.contentKind), maxQuestions: 8, ctx: &ctx, timerMs: ctx.answerWindow(timerMs)), a: a, b: b, hpA: 3, hpB: 3, lastHit: nil)
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        guard case .choose(let i) = action, player == state.a || player == state.b, !state.series.inReveal, var c = state.series.core else { return }
        if c.answer(player, index: i, now: ctx.now) { state.series.core = c }
    }

    static func rateHit(_ state: inout State) {
        guard let c = state.series.core else { return }
        let w = c.correctByTime([state.a, state.b]).first
        if let w = w { if w == state.a { state.hpB -= 1 } else { state.hpA -= 1 } }
        state.lastHit = w
        if state.hpA <= 0 || state.hpB <= 0 { state.series.finished = true }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        switch action {
        case .forceFinish:
            if state.series.closeRunning(now: ctx.now) { rateHit(&state) }
            state.series.finished = true
            state.series.revealUntil = nil
        case .skipQuestion: state.series.skip(ctx: &ctx, timerMs: ctx.answerWindow(timerMs))
        case .timerShift(let ms): state.series.shift(ms: ms)
        case .timerExtend(let ms): state.series.extend(ms: ms)
        case .removeOption(nil): if !state.series.inReveal { state.series.core?.hintStep(rng: &ctx.rng) }
        default: break
        }
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {
        var dctx = ctx
        dctx.players = [state.a, state.b]
        if state.series.advance(ctx: &dctx, revealMs: 2000, timerMs: ctx.answerWindow(timerMs)) { rateHit(&state) }
        ctx.rng = dctx.rng
    }

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool {
        state.series.finished && (state.series.revealUntil.map { ctx.now >= $0 } ?? true)
    }

    static func winner(_ s: State) -> PlayerId? { s.hpA == s.hpB ? nil : (s.hpA > s.hpB ? s.a : s.b) }

    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] {
        var s: [PlayerId: Int] = [:]
        for p in ctx.players { s[p] = 0 }
        if let w = winner(state) { s[w] = 400 }
        return s
    }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        var out: [PlayerId: Outcome] = [:]
        for p in ctx.players { out[p] = Outcome(correct: p == state.a || p == state.b ? winner(state).map { $0 == p } : nil, countsForStreak: false, detail: "❤️ \(state.hpA) : \(state.hpB)") }
        return out
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        var qctx = ctx
        qctx.players = [state.a, state.b]
        qctx.fragenNummer = state.series.questionNumber
        qctx.fragenGesamt = state.series.total
        let wall = revealed ? nil : state.series.core?.wall(ctx: qctx, revealed: state.series.inReveal)
        let label: String
        if revealed { label = winner(state).map { "\(ctx.name($0)) gewinnt!" } ?? "Unentschieden" }
        else if state.series.inReveal { label = state.lastHit.map { "💥 Treffer von \(ctx.name($0))!" } ?? "Beide daneben — kein Treffer" }
        else { label = "Runde \(state.series.questionNumber)/\(state.series.total) · der schnellere Richtige trifft" }
        return MinigameStageOutput(wall: wall, extra: .duel(a: state.a, b: state.b, scoreA: state.hpA, scoreB: state.hpB, maxScore: 3, bets: [:], phase: revealed ? "fertig" : "duell", label: label), title: meta.name)
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        let hearts = "\(ctx.name(state.a)) ❤️\(state.hpA) : ❤️\(state.hpB) \(ctx.name(state.b))"
        let boxer = player == state.a || player == state.b
        if revealed {
            let s = scores(state, ctx: ctx)[player] ?? 0
            let title = s > 0 ? (min(state.hpA, state.hpB) <= 0 ? "K.O.-SIEG!" : "PUNKTSIEG!") : (boxer ? (winner(state) == nil ? "Unentschieden" : "Ausgeboxt") : "Zuschauer")
            return .reveal(title: title, correct: s > 0 ? true : nil, delta: s, detail: hearts, streak: 0, speedBonus: nil)
        }
        guard let c = state.series.core else { return .idle(title: "🥊 Boxkampf", subtitle: hearts) }
        if boxer {
            if state.series.inReveal { return .reveal(title: state.lastHit == player ? "TREFFER!" : (state.lastHit == nil ? "Beide daneben" : "Getroffen!"), correct: c.isCorrect(player), delta: 0, detail: "\(hearts) · Richtig war: \(c.options[c.correctIndex])", streak: 0, speedBonus: nil) }
            if c.hasAnswered(player) { return .idle(title: "🔒 Eingeloggt!", subtitle: "\(hearts) — der schnellere Richtige landet den Treffer") }
            return c.prompt(for: player, ctx: ctx, revealed: false, hint: "🥊 ❤️ \(player == state.a ? state.hpA : state.hpB) · schneller richtig = Treffer")
        }
        return .cheer(title: "🥊 \(hearts)", subtitle: "Anfeuern!", taps: 0)
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) { state.series.core?.gmInfo(ctx: ctx) ?? (nil, [:]) }
    public static func questionsUsed(_ state: State) -> Int { max(1, state.series.index) }
}

/// Konter-Quiz — the friendly 1v1: right pays from the bank, wrong gifts the partner.
public enum KonterQuiz: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var series: SeriesCore
        public var pairs: [[PlayerId]]
        public var earned: [PlayerId: Int]
    }

    static let timerMs = 10_000

    public static let meta = MinigameMeta(
        id: "konter-quiz", name: "Konter-Quiz", emoji: "🔁",
        kurz: "Paare: richtig zahlt die Bank, falsch schenkt dem Partner die Konter-Gutschrift.",
        erklaerung: "Das freundliche Duell: Alle spielen paarweise gegeneinander. Acht kurze Fragen — richtig zahlt die Bank den Fragenwert, falsch schenkt deinem Partner eine Konter-Gutschrift in gleicher Höhe. Wer nicht antwortet, verschenkt nichts, gewinnt aber auch nichts.",
        regeln: ["Ihr spielt paarweise gegeneinander — 8 kurze Fragen",
                 "Richtig: die Bank zahlt den Fragenwert",
                 "Falsch: dein Partner bekommt eine Konter-Gutschrift",
                 "Keine Antwort: nichts gewonnen, nichts verschenkt"],
        gewinn: "Richtig +Fragenwert · Falsch: Fragenwert an den Partner",
        contentKind: .choiceLike, roundBased: true, streak: false, jokerAktionen: [], isMc: true, musik: "question_bed_easy", v2: true
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        let shuffled = ctx.rng.shuffled(ctx.players)
        var pairs: [[PlayerId]] = []
        var i = 0
        while i < shuffled.count { pairs.append(Array(shuffled[i..<min(shuffled.count, i + 2)])); i += 2 }
        if pairs.count > 1, pairs.last?.count == 1 { let solo = pairs.removeLast()[0]; pairs[pairs.count - 1].append(solo) }
        return State(series: SeriesCore(questions: FormatHelpers.fitting(questions, kind: meta.contentKind), maxQuestions: 8, ctx: &ctx, timerMs: ctx.answerWindow(timerMs)), pairs: pairs, earned: [:])
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        guard case .choose(let i) = action, !state.series.inReveal, var c = state.series.core else { return }
        if c.answer(player, index: i, now: ctx.now) { state.series.core = c }
    }

    static func partner(_ s: State, _ p: PlayerId) -> PlayerId? {
        s.pairs.first { $0.contains(p) }?.first { $0 != p }
    }

    static func rate(_ state: inout State, ctx: MinigameContext) {
        guard let c = state.series.core else { return }
        let w = c.question.value
        for p in ctx.players {
            switch c.isCorrect(p) {
            case .some(true): state.earned[p, default: 0] += w
            case .some(false): if let q = partner(state, p) { state.earned[q, default: 0] += w }
            case .none: break
            }
        }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        switch action {
        case .forceFinish:
            if state.series.closeRunning(now: ctx.now) { rate(&state, ctx: ctx) }
            state.series.finished = true
            state.series.revealUntil = nil
        case .skipQuestion: state.series.skip(ctx: &ctx, timerMs: ctx.answerWindow(timerMs))
        case .timerShift(let ms): state.series.shift(ms: ms)
        case .timerExtend(let ms): state.series.extend(ms: ms)
        case .removeOption(nil): if !state.series.inReveal { state.series.core?.hintStep(rng: &ctx.rng) }
        default: break
        }
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {
        if state.series.advance(ctx: &ctx, revealMs: 2500, timerMs: ctx.answerWindow(timerMs)) { rate(&state, ctx: ctx) }
    }

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.series.finished && (state.series.revealUntil.map { ctx.now >= $0 } ?? true) }
    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] { Dictionary(uniqueKeysWithValues: ctx.players.map { ($0, state.earned[$0] ?? 0) }) }
    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        Dictionary(uniqueKeysWithValues: ctx.players.map { ($0, Outcome(correct: (state.earned[$0] ?? 0) > 0, countsForStreak: false)) })
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        var qctx = ctx
        qctx.fragenNummer = state.series.questionNumber
        qctx.fragenGesamt = state.series.total
        let wall = revealed ? nil : state.series.core?.wall(ctx: qctx, revealed: state.series.inReveal)
        return MinigameStageOutput(wall: wall, extra: .telegram(pairs: state.pairs, letters: [], solved: [], wort: nil),
                                   title: "\(meta.name) · Frage \(state.series.questionNumber)/\(state.series.total)")
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        let bilanz = "Bilanz \(Money.format(state.earned[player] ?? 0))"
        if revealed { let s = state.earned[player] ?? 0; return .reveal(title: "Konter-Bilanz", correct: s > 0, delta: s, detail: partner(state, player).map { "Partner: \(ctx.name($0))" }, streak: 0, speedBonus: nil) }
        guard let c = state.series.core else { return .idle(title: "🔁 Konter-Quiz", subtitle: bilanz) }
        if state.series.inReveal {
            var card = c.prompt(for: player, ctx: ctx, revealed: true, delta: c.isCorrect(player) == true ? c.question.value : 0)
            if case .reveal(let t, let ok, let d, let detail, _, _) = card, c.isCorrect(player) == false, let q = partner(state, player) {
                card = .reveal(title: t, correct: ok, delta: d, detail: [detail, "Konter-Gutschrift an \(ctx.name(q))"].compactMap { $0 }.joined(separator: " · "), streak: 0, speedBonus: nil)
            }
            return card
        }
        if c.hasAnswered(player) { return .idle(title: "🔒 Eingeloggt!", subtitle: "Gleich kommt die Auflösung · \(bilanz)") }
        return c.prompt(for: player, ctx: ctx, revealed: false, hint: partner(state, player).map { "🔁 Partner: \(ctx.name($0)) · \(bilanz)" } ?? "🔁 \(bilanz)")
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) { state.series.core?.gmInfo(ctx: ctx) ?? (nil, [:]) }
    public static func questionsUsed(_ state: State) -> Int { max(1, state.series.index) }
}

/// Einer gegen alle — the leader alone against the crowd majority.
public enum EinerGegenAlle: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var series: SeriesCore
        public var solist: PlayerId
        public var solistPoints: Int
        public var crowdPoints: Int
        public var earned: [PlayerId: Int]
        public var lastSolist: Bool?
        public var lastCrowd: Int
    }

    static let timerMs = 12_000

    public static let meta = MinigameMeta(
        id: "einer-gegen-alle", name: "Einer gegen alle", emoji: "👑",
        kurz: "Der Führende allein gegen die Mehrheit der Menge — Rollenumkehr!",
        erklaerung: "Der Führende steigt auf den Thron und spielt allein gegen alle anderen. Sechs Fragen: Liegt der Solist richtig und die Mehrheit falsch, kassiert er den vollen Fragenwert. Liegt die Mehrheit richtig, bekommt jeder Richtige der Menge den halben Fragenwert — und der Solist geht leer aus.",
        regeln: ["Der Führende spielt allein gegen alle anderen — 6 Fragen",
                 "Solist richtig + Mehrheit falsch: voller Fragenwert für den Solisten",
                 "Mehrheit richtig: jeder Richtige der Menge bekommt die Hälfte",
                 "Der Solist geht dann leer aus"],
        gewinn: "Solist: voller Fragenwert · Menge: ½ Fragenwert pro Richtigem",
        contentKind: .choiceLike, roundBased: true, streak: false, jokerAktionen: [], isMc: true, musik: "question_bed_hard", v2: true
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        // The leader among the connected players (ties: seat order).
        let seated = ctx.players.filter { ctx.connected.contains($0) }
        let pool = seated.isEmpty ? ctx.players : seated
        let top = pool.map { ctx.balances[$0] ?? 0 }.max() ?? 0
        let solist = pool.first { (ctx.balances[$0] ?? 0) == top } ?? ctx.players[0]
        return State(series: SeriesCore(questions: FormatHelpers.fitting(questions, kind: meta.contentKind), maxQuestions: 6, ctx: &ctx, timerMs: ctx.answerWindow(timerMs)), solist: solist, solistPoints: 0, crowdPoints: 0, earned: [:], lastSolist: nil, lastCrowd: 0)
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        guard case .choose(let i) = action, !state.series.inReveal, var c = state.series.core else { return }
        if c.answer(player, index: i, now: ctx.now) { state.series.core = c }
    }

    /// One beat: the crowd = everyone else at the table (or who answered anyway).
    static func outcome(_ state: State, _ c: ChoiceCore, ctx: MinigameContext) -> (crowdRight: [PlayerId], majority: Bool, solistWins: Bool) {
        let crowd = ctx.players.filter { $0 != state.solist && (ctx.connected.contains($0) || c.answers[$0] != nil) }
        let crowdRight = crowd.filter { c.isCorrect($0) == true }
        let majority = !crowd.isEmpty && crowdRight.count * 2 > crowd.count
        return (crowdRight, majority, c.isCorrect(state.solist) == true && !majority)
    }

    static func rate(_ state: inout State, ctx: MinigameContext) {
        guard let c = state.series.core else { return }
        let beat = outcome(state, c, ctx: ctx)
        state.lastSolist = c.isCorrect(state.solist) == true
        state.lastCrowd = beat.crowdRight.count
        let w = c.question.value
        if beat.solistWins { state.solistPoints += 1; state.earned[state.solist, default: 0] += w }
        else if beat.majority { state.crowdPoints += 1; for p in beat.crowdRight { state.earned[p, default: 0] += w / 2 } }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        switch action {
        case .forceFinish:
            if state.series.closeRunning(now: ctx.now) { rate(&state, ctx: ctx) }
            state.series.finished = true
            state.series.revealUntil = nil
        case .skipQuestion: state.series.skip(ctx: &ctx, timerMs: ctx.answerWindow(timerMs))
        case .timerShift(let ms): state.series.shift(ms: ms)
        case .timerExtend(let ms): state.series.extend(ms: ms)
        case .removeOption(nil): if !state.series.inReveal { state.series.core?.hintStep(rng: &ctx.rng) }
        default: break
        }
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {
        if state.series.advance(ctx: &ctx, revealMs: 2500, timerMs: ctx.answerWindow(timerMs)) { rate(&state, ctx: ctx) }
    }

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.series.finished && (state.series.revealUntil.map { ctx.now >= $0 } ?? true) }
    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] { Dictionary(uniqueKeysWithValues: ctx.players.map { ($0, state.earned[$0] ?? 0) }) }
    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        Dictionary(uniqueKeysWithValues: ctx.players.map { ($0, Outcome(correct: (state.earned[$0] ?? 0) > 0, countsForStreak: false, detail: $0 == state.solist ? "👑 Solist" : nil)) })
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        var qctx = ctx
        qctx.fragenNummer = state.series.questionNumber
        qctx.fragenGesamt = state.series.total
        let wall = revealed ? nil : state.series.core?.wall(ctx: qctx, revealed: state.series.inReveal)
        var crowd: [PlayerId: Int] = [:]
        for p in ctx.players where p != state.solist { crowd[p] = state.earned[p] ?? 0 }
        return MinigameStageOutput(wall: wall, extra: .oneVsAll(solist: state.solist, solistCorrect: state.series.inReveal ? state.lastSolist : nil, crowd: crowd, crowdCorrect: state.lastCrowd, frage: state.series.questionNumber),
                                   title: "\(meta.name) · \(ctx.name(state.solist)) \(state.solistPoints):\(state.crowdPoints) Menge")
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        let score = "👑 \(state.solistPoints):\(state.crowdPoints) 🐒"
        if revealed { let s = state.earned[player] ?? 0; return .reveal(title: player == state.solist ? "👑 Solist: \(state.solistPoints) Punkte" : "Menge: \(state.crowdPoints) Punkte", correct: s > 0, delta: s, detail: score, streak: 0, speedBonus: nil) }
        guard let c = state.series.core else { return .idle(title: meta.name, subtitle: score) }
        if state.series.inReveal {
            let beat = outcome(state, c, ctx: ctx)
            let s = player == state.solist ? (beat.solistWins ? c.question.value : 0) : (beat.majority && c.isCorrect(player) == true ? c.question.value / 2 : 0)
            var card = c.prompt(for: player, ctx: ctx, revealed: true, delta: s)
            if case .reveal(let t, let ok, let d, let detail, _, _) = card { card = .reveal(title: t, correct: ok, delta: d, detail: [detail, score].compactMap { $0 }.joined(separator: " · "), streak: 0, speedBonus: nil) }
            return card
        }
        if c.hasAnswered(player) { return .idle(title: "🔒 Eingeloggt!", subtitle: "\(score) — gleich zeigt sich, wer recht hat") }
        return c.prompt(for: player, ctx: ctx, revealed: false, hint: player == state.solist ? "👑 Du gegen alle! \(score)" : "🐒 Die Menge gegen \(ctx.name(state.solist)) · \(score)")
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) { state.series.core?.gmInfo(ctx: ctx) ?? (nil, [:]) }
    public static func questionsUsed(_ state: State) -> Int { max(1, state.series.index) }
}

/// Bananen-Tortenschlacht — elimination: every wrong answer is a pie in the
/// face, three pies and you are out. The cleanest monkey standing wins.
public enum BananenTortenschlacht: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var series: SeriesCore
        public var dirt: [PlayerId: Int]
        public var out: [PlayerId]
        public var lastHits: [PlayerId]
        /// Question number each monkey went out on (same question = same place).
        public var outRound: [PlayerId: Int]?
    }

    static let timerMs = 10_000

    public static let meta = MinigameMeta(
        id: "bananen-tortenschlacht", name: "Bananen-Tortenschlacht", emoji: "🥧",
        kurz: "Jede falsche Antwort ist eine Torte ins Gesicht — drei Torten und du bist raus.",
        erklaerung: "Der Rauswurf-Beat: Acht Fragen, jede falsche oder fehlende Antwort ist eine Sahnetorte ins Gesicht. Drei Torten = raus aus der Runde. Wer als Letzter (oder Sauberster) übrig bleibt, gewinnt 500 MM, Platz zwei 250.",
        regeln: ["8 Fragen — jede falsche oder fehlende Antwort ist eine Torte",
                 "Drei Torten im Gesicht = raus",
                 "Wer sauber bleibt, bleibt drin",
                 "Der Letzte (oder Sauberste) gewinnt — Gleichstand teilt sich den Platz"],
        gewinn: "Sieger +500 MM · Platz 2 +250 MM",
        minPlayers: 3, contentKind: .choiceLike, roundBased: true, streak: false, jokerAktionen: [], isMc: true, musik: "bomb_pass", v2: true
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        State(series: SeriesCore(questions: FormatHelpers.fitting(questions, kind: meta.contentKind), maxQuestions: 8, ctx: &ctx, timerMs: ctx.answerWindow(timerMs)), dirt: [:], out: [], lastHits: [], outRound: [:])
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        guard case .choose(let i) = action, !state.out.contains(player), !state.series.inReveal, var c = state.series.core else { return }
        if c.answer(player, index: i, now: ctx.now) { state.series.core = c }
    }

    static func rate(_ state: inout State, alive: [PlayerId], ctx: MinigameContext) {
        guard let c = state.series.core else { return }
        state.lastHits = []
        // Wrong OR missing answer = pie — also for a monkey who left the table
        // (otherwise disconnecting would keep you clean and win the round).
        for p in alive where c.isCorrect(p) != true {
            state.dirt[p, default: 0] += 1
            state.lastHits.append(p)
            if state.dirt[p]! >= 3 {
                state.out.append(p)
                state.outRound = state.outRound ?? [:]
                state.outRound?[p] = state.series.questionNumber
            }
        }
        if ctx.players.filter({ !state.out.contains($0) }).count <= 1 { state.series.finished = true }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        switch action {
        case .forceFinish:
            if state.series.closeRunning(now: ctx.now) { rate(&state, alive: ctx.players.filter { !state.out.contains($0) }, ctx: ctx) }
            state.series.finished = true
            state.series.revealUntil = nil
        case .skipQuestion: state.series.skip(ctx: &ctx, timerMs: ctx.answerWindow(timerMs))
        case .timerShift(let ms): state.series.shift(ms: ms)
        case .timerExtend(let ms): state.series.extend(ms: ms)
        case .removeOption(nil): if !state.series.inReveal { state.series.core?.hintStep(rng: &ctx.rng) }
        default: break
        }
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {
        var actx = ctx
        actx.players = ctx.players.filter { !state.out.contains($0) }
        if state.series.advance(ctx: &actx, revealMs: 2500, timerMs: ctx.answerWindow(timerMs)) { rate(&state, alive: actx.players, ctx: ctx) }
        ctx.rng = actx.rng
    }

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.series.finished && (state.series.revealUntil.map { ctx.now >= $0 } ?? true) }

    /// Place per player: survivors first (fewer pies better), then the later out
    /// the better. Equal records share a place (no seat-order luck).
    static func places(_ s: State, ctx: MinigameContext) -> [PlayerId: Int] {
        func key(_ p: PlayerId) -> (Int, Int) {
            if let o = s.out.firstIndex(of: p) { return (1, -(s.outRound?[p] ?? o)) }
            return (0, s.dirt[p] ?? 0)
        }
        let sorted = ctx.players.sorted { key($0) < key($1) }
        var out: [PlayerId: Int] = [:]
        for (i, p) in sorted.enumerated() {
            if i > 0, key(sorted[i - 1]) == key(p) { out[p] = out[sorted[i - 1]] } else { out[p] = i + 1 }
        }
        return out
    }

    static func ranking(_ s: State, ctx: MinigameContext) -> [PlayerId] {
        let pl = places(s, ctx: ctx)
        return ctx.players.sorted { (pl[$0] ?? 99) < (pl[$1] ?? 99) }
    }

    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] {
        var s: [PlayerId: Int] = [:]
        for (p, place) in places(state, ctx: ctx) { s[p] = place == 1 ? 500 : (place == 2 ? 250 : 0) }
        return s
    }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        Dictionary(uniqueKeysWithValues: ctx.players.map { ($0, Outcome(correct: !state.out.contains($0), countsForStreak: false, detail: "🥧 \(state.dirt[$0] ?? 0)/3")) })
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        var qctx = ctx
        qctx.players = ctx.players.filter { !state.out.contains($0) }
        qctx.fragenNummer = state.series.questionNumber
        qctx.fragenGesamt = state.series.total
        let wall = revealed ? nil : state.series.core?.wall(ctx: qctx, revealed: state.series.inReveal)
        let alive = ctx.players.count - state.out.count
        return MinigameStageOutput(wall: wall, extra: .pies(dirt: state.dirt, out: state.out, maxDirt: 3), title: "\(meta.name) · noch \(alive) sauber")
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        let pies = "🥧 \(state.dirt[player] ?? 0)/3"
        if revealed {
            let s = scores(state, ctx: ctx)[player] ?? 0
            let place = places(state, ctx: ctx)[player] ?? 0
            return .reveal(title: s > 0 ? (place == 1 ? "Sauber geblieben!" : "Platz 2 — fast sauber!") : "Voll Sahne", correct: !state.out.contains(player), delta: s, detail: "\(pies) · Platz \(place)", streak: 0, speedBonus: nil)
        }
        if state.out.contains(player) { return .cheer(title: "🥧 Du bist raus!", subtitle: "Feuere die Sauberen an — noch \(ctx.players.count - state.out.count) im Rennen", taps: 0) }
        guard let c = state.series.core else { return .idle(title: meta.name, subtitle: pies) }
        if state.series.inReveal { return .reveal(title: state.lastHits.contains(player) ? "🥧 TORTE!" : "Ausgewichen!", correct: !state.lastHits.contains(player), delta: 0, detail: "\(pies) · Richtig war: \(c.options[c.correctIndex])", streak: 0, speedBonus: nil) }
        if c.hasAnswered(player) { return .idle(title: "🔒 Eingeloggt!", subtitle: "\(pies) — gleich fliegen die Torten") }
        return c.prompt(for: player, ctx: ctx, revealed: false, hint: "\(pies) Torten · falsch oder zu langsam = Torte")
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) { state.series.core?.gmInfo(ctx: ctx) ?? (nil, [:]) }
    public static func questionsUsed(_ state: State) -> Int { max(1, state.series.index) }
}

/// Risiko-Leiter — 8 questions easy → ultrahard; before each step decide:
/// climb on (risk the unbanked) or bank. Wrong = unbanked money is gone.
public enum RisikoLeiter: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var series: SeriesCore
        public var unbanked: [PlayerId: Int]
        public var banked: [PlayerId: Int]
        public var stopped: [PlayerId]
        public var decisions: [PlayerId: String]
        public var deciding: Bool
        public var decideUntil: Millis
        public var lastResults: [PlayerId: Bool]
    }

    public static let ladder = [100, 200, 300, 500, 750, 1000, 1500, 2000]
    static let timerMs = 15_000

    public static let meta = MinigameMeta(
        id: "risiko-leiter", name: "Risiko-Leiter", emoji: "🪜",
        kurz: "8 Stufen von leicht bis ULTRAHARD — weiterklettern oder sichern?",
        erklaerung: "Die Leiter beginnt leicht und endet ULTRAHARD. Jede richtige Stufe legt Geld auf deinen ungesicherten Stapel. Vor jeder Stufe entscheidest du: weiterklettern oder SICHERN? Wer sichert, steigt aus und behält alles. Wer weiterklettert und falsch liegt, verliert den ungesicherten Stapel.",
        regeln: ["8 Stufen von leicht bis ULTRAHARD",
                 "Jede richtige Stufe legt Geld auf deinen ungesicherten Stapel",
                 "Vor jeder Stufe: weiterklettern oder SICHERN?",
                 "Falsch beim Klettern: der ungesicherte Stapel ist weg"],
        gewinn: "Gesichert = deins · ungesichert = Risiko",
        contentKind: .choiceLike, roundBased: true, streak: false, jokerAktionen: [], isMc: true, musik: "question_bed_hard", v2: true
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        let fit = FormatHelpers.fitting(questions, kind: meta.contentKind)
        // Climb from easy to hard: the first 8 sorted by tier, the rest stay spares for GM swaps.
        let sorted = Array(fit.prefix(8)).sorted { $0.schw < $1.schw } + fit.dropFirst(8)
        var s = State(series: SeriesCore(questions: sorted, maxQuestions: 8, ctx: &ctx, timerMs: ctx.answerWindow(timerMs)), unbanked: [:], banked: [:], stopped: [], decisions: [:], deciding: false, decideUntil: 0, lastResults: [:])
        s.series.core?.startedAt = ctx.now
        return s
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        guard !state.stopped.contains(player) else { return }
        if state.deciding, case .binary(let d) = action, d == "weiter" || d == "sichern" { state.decisions[player] = d; return }
        guard !state.deciding, case .choose(let i) = action, !state.series.inReveal, var c = state.series.core else { return }
        if c.answer(player, index: i, now: ctx.now) { state.series.core = c }
    }

    static func stepValue(_ state: State) -> Int { ladder[min(ladder.count, max(1, state.series.questionNumber)) - 1] }

    /// Rate the question that just closed: right climbs, wrong falls. A climber
    /// who left the table without answering banks instead of falling.
    static func rate(_ state: inout State, ctx: MinigameContext) {
        guard let c = state.series.core else { return }
        let value = stepValue(state)
        state.lastResults = [:]
        for p in ctx.players where !state.stopped.contains(p) {
            if c.isCorrect(p) == nil, !ctx.connected.contains(p) {
                state.banked[p, default: 0] += state.unbanked[p] ?? 0
                state.unbanked[p] = 0
                state.stopped.append(p)
                continue
            }
            let ok = c.isCorrect(p) == true
            state.lastResults[p] = ok
            if ok { state.unbanked[p, default: 0] += value } else { state.unbanked[p] = 0; state.stopped.append(p) }
        }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        switch action {
        case .forceFinish:
            if !state.deciding, state.series.closeRunning(now: ctx.now) { rate(&state, ctx: ctx) }
            finishLadder(&state, ctx: ctx)
            state.series.revealUntil = nil
        case .skipQuestion:
            if state.deciding { state.decideUntil = ctx.now; return }
            var actx = ctx
            actx.players = ctx.players.filter { !state.stopped.contains($0) }
            state.series.skip(ctx: &actx, timerMs: ctx.answerWindow(timerMs))
            ctx.rng = actx.rng
            if state.series.finished { finishLadder(&state, ctx: ctx) }
        case .timerShift(let ms): state.series.shift(ms: ms); state.decideUntil += ms
        case .timerExtend(let ms): if state.deciding { state.decideUntil += ms } else { state.series.extend(ms: ms) }
        case .removeOption(nil): if !state.deciding, !state.series.inReveal { state.series.core?.hintStep(rng: &ctx.rng) }
        default: break
        }
    }

    static func finishLadder(_ state: inout State, ctx: MinigameContext) {
        for p in ctx.players where !state.stopped.contains(p) {
            state.banked[p, default: 0] += state.unbanked[p] ?? 0
            state.unbanked[p] = 0
        }
        state.series.finished = true
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {
        guard !state.series.finished else { return }
        let alive = ctx.players.filter { !state.stopped.contains($0) }
        if alive.isEmpty { finishLadder(&state, ctx: ctx); return }
        if state.deciding {
            let active = alive.filter { ctx.connected.contains($0) }
            if ctx.now >= state.decideUntil || active.allSatisfy({ state.decisions[$0] != nil }) {
                for p in alive where (state.decisions[p] ?? "weiter") == "sichern" || !ctx.connected.contains(p) {
                    state.banked[p, default: 0] += state.unbanked[p] ?? 0
                    state.unbanked[p] = 0
                    state.stopped.append(p)
                }
                state.decisions = [:]
                state.deciding = false
                if ctx.players.allSatisfy({ state.stopped.contains($0) }) { finishLadder(&state, ctx: ctx); return }
                state.series.start(ctx: &ctx, timerMs: ctx.answerWindow(timerMs))
                if state.series.finished { finishLadder(&state, ctx: ctx) }
            }
            return
        }
        guard let c = state.series.core else { finishLadder(&state, ctx: ctx); return }
        if let r = state.series.revealUntil {
            // Reveal over: either the ladder is done or the climbers decide.
            if ctx.now >= r {
                if state.series.index >= state.series.maxQuestions || state.series.index >= state.series.questions.count { finishLadder(&state, ctx: ctx); return }
                state.deciding = true
                state.decideUntil = ctx.now + ctx.answerWindow(8000)
            }
            return
        }
        var actx = ctx
        actx.players = alive
        if c.finished(now: ctx.now, ctx: actx) {
            rate(&state, ctx: ctx)
            state.series.revealUntil = ctx.now + ctx.ms(2500)
        }
    }

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.series.finished && (state.series.revealUntil.map { ctx.now >= $0 } ?? true) }
    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] { Dictionary(uniqueKeysWithValues: ctx.players.map { ($0, (state.banked[$0] ?? 0) + (state.unbanked[$0] ?? 0)) }) }
    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        Dictionary(uniqueKeysWithValues: ctx.players.map { ($0, Outcome(correct: (state.banked[$0] ?? 0) > 0, countsForStreak: false, detail: "gesichert \(Money.format(state.banked[$0] ?? 0))")) })
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        var qctx = ctx
        qctx.players = ctx.players.filter { !state.stopped.contains($0) || state.lastResults[$0] != nil }
        qctx.fragenNummer = state.series.questionNumber
        qctx.fragenGesamt = state.series.total
        let wall = revealed || state.deciding ? nil : state.series.core?.wall(ctx: qctx, revealed: state.series.inReveal)
        var positions: [PlayerId: Int] = [:]
        for p in ctx.players { positions[p] = state.stopped.contains(p) ? -1 : state.series.questionNumber }
        let climbing = ctx.players.filter { !state.stopped.contains($0) }.count
        let title = state.deciding ? "Weiterklettern oder sichern? Nächste Stufe: \(Money.format(ladder[min(ladder.count - 1, state.series.questionNumber)]))"
            : "\(meta.name) · Stufe \(state.series.questionNumber)/\(state.series.total) · \(climbing) klettern"
        return MinigameStageOutput(wall: wall, extra: .steps(labels: ladder.map { Money.format($0) }, current: state.series.questionNumber, positions: positions, banked: state.banked.merging(state.unbanked) { $0 + $1 }),
                                   title: title)
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed { let s = scores(state, ctx: ctx)[player] ?? 0; return .reveal(title: s > 0 ? "Sicher gelandet" : "Abgerutscht", correct: s > 0, delta: s, detail: "Gesichert: \(Money.format(s))", streak: 0, speedBonus: nil) }
        if state.stopped.contains(player) {
            let climbing = ctx.players.filter { !state.stopped.contains($0) }.count
            return .idle(title: (state.banked[player] ?? 0) > 0 ? "🔒 Gesichert: \(Money.format(state.banked[player] ?? 0))" : "🪜 Abgerutscht", subtitle: "Noch \(climbing) klettern weiter — die Runde endet, wenn alle unten sind")
        }
        if state.deciding {
            let next = Money.format(ladder[min(ladder.count - 1, state.series.questionNumber)])
            return .binary(title: "Ungesichert: \(Money.format(state.unbanked[player] ?? 0))",
                           subtitle: state.decisions[player] == nil ? "Nächste Stufe: \(next) — falsch = alles Ungesicherte weg" : "Entschieden — warte auf die anderen …",
                           a: "weiter", b: "sichern", chosen: state.decisions[player], deadline: ctx.visible(state.decideUntil))
        }
        guard let c = state.series.core else { return .idle(title: meta.name, subtitle: nil) }
        if state.series.inReveal { return .reveal(title: state.lastResults[player] == true ? "Stufe geschafft!" : "Abgerutscht!", correct: state.lastResults[player], delta: 0, detail: "Ungesichert: \(Money.format(state.unbanked[player] ?? 0)) · Richtig war: \(c.options[c.correctIndex])", streak: 0, speedBonus: nil) }
        if c.hasAnswered(player) { return .idle(title: "🔒 Eingeloggt!", subtitle: "Stufe \(state.series.questionNumber): \(Money.format(stepValue(state))) wenn's stimmt") }
        return c.prompt(for: player, ctx: ctx, revealed: false, hint: "🪜 Stufe \(state.series.questionNumber)/\(state.series.total) (+\(Money.format(stepValue(state)))) · ungesichert \(Money.format(state.unbanked[player] ?? 0))")
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        var g: (question: GmQuestionInfo?, answers: [PlayerId: String]) = state.series.core?.gmInfo(ctx: ctx) ?? (nil, [:])
        for (p, d) in state.decisions { g.answers[p] = d == "sichern" ? "🔒 sichert" : "🪜 klettert weiter" }
        return g
    }
    public static func questionsUsed(_ state: State) -> Int { max(1, state.series.index) }
}

/// Der Goldene Affe — four questions for the crown: the fastest correct answer
/// of each question is a buzzer win; the most buzzer wins take the golden bonus.
public enum GoldenerAffe: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var series: SeriesCore
        public var earned: [PlayerId: Int]
        public var buzzWins: [PlayerId: Int]
        public var buzzOrder: [PlayerId]
        public var lockedOut: [PlayerId]
        public var crowned: PlayerId?
        /// Summed answer time of the buzzer wins (tie-break: faster crown).
        public var buzzMs: [PlayerId: Int]?
    }

    static let timerMs = 15_000

    public static let meta = MinigameMeta(
        id: "goldener-affe", name: "Der Goldene Affe", emoji: "🏆",
        kurz: "Vier Fragen um die Krone: wer die meisten Buzzer-Duelle gewinnt, wird zum Goldenen Affen.",
        erklaerung: "Der Goldene Affe wartet auf dem Podest. Vier Fragen — jede richtige Antwort zahlt den Fragenwert. Wer eine Frage als Schnellster richtig beantwortet, holt einen Buzzer-Sieg. Die meisten Buzzer-Siege krönen den Goldenen Affen: 500 MM Gold obendrauf.",
        regeln: ["Vier Fragen um die Krone — jede richtige Antwort zahlt den Fragenwert",
                 "Wer als Schnellster richtig liegt, holt einen Buzzer-Sieg",
                 "Die meisten Buzzer-Siege krönen den Goldenen Affen (+500 MM)",
                 "Gleichstand: mehr Geld, dann die schnelleren Siege"],
        gewinn: "Pro richtiger Antwort Fragenwert · Krone +500 MM",
        contentKind: .choiceLike, roundBased: true, streak: false, jokerAktionen: [], isMc: true, musik: "jackpot_drama", v2: true
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        State(series: SeriesCore(questions: FormatHelpers.fitting(questions, kind: meta.contentKind), maxQuestions: 4, ctx: &ctx, timerMs: ctx.answerWindow(timerMs)), earned: [:], buzzWins: [:], buzzOrder: [], lockedOut: [], crowned: nil, buzzMs: [:])
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        guard case .choose(let i) = action, !state.series.inReveal, var c = state.series.core else { return }
        if c.answer(player, index: i, now: ctx.now) { state.series.core = c }
    }

    static func rate(_ state: inout State, ctx: MinigameContext) {
        guard let c = state.series.core else { return }
        let correct = c.correctByTime(ctx.players)
        for p in correct { state.earned[p, default: 0] += c.question.value }
        if let f = correct.first {
            state.buzzWins[f, default: 0] += 1
            state.buzzMs = state.buzzMs ?? [:]
            state.buzzMs?[f, default: 0] += c.answeredAfterMs(f) ?? 0
        }
        state.buzzOrder = correct
    }

    static func crown(_ state: inout State, ctx: MinigameContext) {
        guard state.series.finished, state.crowned == nil else { return }
        // Most buzzer wins, then more money, then the faster wins, then seat order.
        let best = ctx.players.filter { (state.buzzWins[$0] ?? 0) > 0 }.min { a, b in
            let wa = state.buzzWins[a] ?? 0, wb = state.buzzWins[b] ?? 0
            if wa != wb { return wa > wb }
            let ea = state.earned[a] ?? 0, eb = state.earned[b] ?? 0
            if ea != eb { return ea > eb }
            return (state.buzzMs?[a] ?? 0) < (state.buzzMs?[b] ?? 0)
        }
        if let c = best { state.crowned = c; state.earned[c, default: 0] += 500 }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        switch action {
        case .forceFinish:
            if state.series.closeRunning(now: ctx.now) { rate(&state, ctx: ctx) }
            state.series.finished = true
            state.series.revealUntil = nil
            crown(&state, ctx: ctx)
        case .skipQuestion: state.series.skip(ctx: &ctx, timerMs: ctx.answerWindow(timerMs)); crown(&state, ctx: ctx)
        case .timerShift(let ms): state.series.shift(ms: ms)
        case .timerExtend(let ms): state.series.extend(ms: ms)
        case .removeOption(nil): if !state.series.inReveal { state.series.core?.hintStep(rng: &ctx.rng) }
        default: break
        }
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {
        if state.series.advance(ctx: &ctx, revealMs: 2500, timerMs: ctx.answerWindow(timerMs)) { rate(&state, ctx: ctx) }
        crown(&state, ctx: ctx)
    }

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.series.finished && (state.series.revealUntil.map { ctx.now >= $0 } ?? true) }
    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] { Dictionary(uniqueKeysWithValues: ctx.players.map { ($0, state.earned[$0] ?? 0) }) }
    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        Dictionary(uniqueKeysWithValues: ctx.players.map { ($0, Outcome(correct: (state.earned[$0] ?? 0) > 0, countsForStreak: false, detail: $0 == state.crowned ? "🏆 Goldener Affe" : "\(state.buzzWins[$0] ?? 0) Buzzer-Siege")) })
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        var qctx = ctx
        qctx.fragenNummer = state.series.questionNumber
        qctx.fragenGesamt = state.series.total
        let wall = revealed ? nil : state.series.core?.wall(ctx: qctx, revealed: state.series.inReveal)
        let leader = ctx.players.filter { (state.buzzWins[$0] ?? 0) > 0 }.max { (state.buzzWins[$0] ?? 0) < (state.buzzWins[$1] ?? 0) }
        let stufe = state.crowned.map { "🏆 \(ctx.name($0))" } ?? leader.map { "👑 \(ctx.name($0)): \(state.buzzWins[$0] ?? 0) Siege" }
        return MinigameStageOutput(wall: wall, extra: .buzzers(armed: !state.series.inReveal, order: state.buzzOrder, lockedOut: state.lockedOut, stufe: stufe, wert: state.series.core?.question.value ?? 0),
                                   title: "\(meta.name) · Frage \(state.series.questionNumber)/\(state.series.total)")
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        let wins = "🏆 Buzzer-Siege: \(state.buzzWins[player] ?? 0)"
        if revealed { let s = state.earned[player] ?? 0; return .reveal(title: state.crowned == player ? "🏆 DER GOLDENE AFFE!" : "Bilanz", correct: s > 0, delta: s, detail: "\(state.buzzWins[player] ?? 0) Buzzer-Siege", streak: 0, speedBonus: nil) }
        guard let c = state.series.core else { return .idle(title: meta.name, subtitle: wins) }
        if state.series.inReveal {
            var card = c.prompt(for: player, ctx: ctx, revealed: true, delta: c.isCorrect(player) == true ? c.question.value : 0)
            if case .reveal(_, let ok, let d, let detail, _, _) = card, state.buzzOrder.first == player {
                card = .reveal(title: "⚡ BUZZER-SIEG!", correct: ok, delta: d, detail: [detail, wins].compactMap { $0 }.joined(separator: " · "), streak: 0, speedBonus: nil)
            }
            return card
        }
        if c.hasAnswered(player) { return .idle(title: "🔒 Eingeloggt!", subtitle: "Der schnellste Richtige holt den Buzzer-Sieg · \(wins)") }
        return c.prompt(for: player, ctx: ctx, revealed: false, hint: "\(wins) · schnell UND richtig!")
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) { state.series.core?.gmInfo(ctx: ctx) ?? (nil, [:]) }
    public static func questionsUsed(_ state: State) -> Int { max(1, state.series.index) }
}
