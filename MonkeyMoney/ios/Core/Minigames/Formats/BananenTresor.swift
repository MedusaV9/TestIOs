import Foundation

/// Bananen-Tresor — the estimate round, the great equaliser. Fixed payouts
/// by closeness: 400/250/150, everyone else 50; exact hit 1.000 (hard 2.000).
public enum BananenTresor: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var question: Question
        public var spec: EstimateSpec
        public var startedAt: Millis
        public var deadline: Millis
        public var timerMs: Int
        public var guesses: [PlayerId: Double]
        public var moved: [PlayerId: Double]
        public var finishedAt: Millis?
        public var hard: Bool
    }

    public static let meta = MinigameMeta(
        id: "bananen-tresor", name: "Bananen-Tresor", emoji: "🔐",
        kurz: "Schätzfrage: wer am nächsten dran ist, knackt den Tresor — Volltreffer = 1.000 MM.",
        erklaerung: "Der große Gleichmacher: eine Schätzfrage mit Zahl. Schiebe den Regler, tippe deinen Wert und logge ein. Platz 1 = 400 MM, Platz 2 = 250, Platz 3 = 150 — alle anderen bekommen 50 MM, schätzen lohnt sich also immer. Ein exakter Volltreffer knackt den Tresor: 1.000 MM und die „Nagel auf den Kopf“-Fanfare!",
        contentKind: .fragen([.schaetz]), streak: false, jokerAktionen: [], isMc: false, musik: "estimate_think"
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        let q = FormatHelpers.first(questions, kind: meta.contentKind)
        let spec = q.schaetz ?? EstimateSpec(richtwert: 42, einheit: "", toleranz: 10, min: 0, max: 100, skala: "linear")
        let hard = ctx.section.slot == .risiko || ctx.settings.modus == .marathon && ctx.section.rundenNummer > 5
        let t = Int(Double(ctx.answerWindow(20_000)) * ctx.mods.timerFaktor)
        return State(question: q, spec: spec, startedAt: ctx.now, deadline: ctx.now + t, timerMs: t, guesses: [:], moved: [:], finishedAt: nil, hard: hard)
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        guard state.guesses[player] == nil, ctx.now <= state.deadline + ChoiceCore.graceMs else { return }
        switch action {
        case .number(let v):
            state.guesses[player] = min(state.spec.max, max(state.spec.min, v))
        case .button(let b) where b == "move":
            break
        default: break
        }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        switch action {
        case .timerExtend(let ms): state.deadline += ms; state.timerMs += ms
        case .timerShift(let ms): state.deadline += ms; state.startedAt += ms
        case .forceFinish, .skipQuestion: state.finishedAt = ctx.now
        default: break
        }
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {}

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool {
        if state.finishedAt != nil { return true }
        if ctx.now > state.deadline + ChoiceCore.graceMs { return true }
        let active = ctx.players.filter { ctx.connected.contains($0) }
        return !active.isEmpty && active.allSatisfy { state.guesses[$0] != nil }
    }

    static func ranking(_ state: State, ctx: MinigameContext) -> [(PlayerId, Double, Int)] {
        // (player, distance, place) — equal distance shares the better place.
        let entries = state.guesses.map { ($0.key, abs($0.value - state.spec.richtwert)) }.sorted { $0.1 < $1.1 }
        var out: [(PlayerId, Double, Int)] = []
        var place = 0
        var lastDist: Double?
        for (i, e) in entries.enumerated() {
            if let l = lastDist, abs(l - e.1) < 1e-9 { out.append((e.0, e.1, place)) } else { place = i + 1; lastDist = e.1; out.append((e.0, e.1, place)) }
        }
        return out
    }

    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] {
        var s: [PlayerId: Int] = [:]
        let ladder = state.hard ? [800, 500, 300] : [400, 250, 150]
        let rest = state.hard ? 100 : 50
        let bullseye = state.hard ? 2000 : 1000
        for (p, dist, place) in ranking(state, ctx: ctx) {
            if dist < 1e-9 { s[p] = bullseye; continue }
            s[p] = place - 1 < ladder.count ? ladder[place - 1] : rest
        }
        for p in ctx.players where s[p] == nil { s[p] = 0 }
        return s
    }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        var out: [PlayerId: Outcome] = [:]
        let r = ranking(state, ctx: ctx)
        for p in ctx.players {
            if let e = r.first(where: { $0.0 == p }) {
                out[p] = Outcome(correct: e.2 == 1, countsForStreak: false, detail: e.1 < 1e-9 ? "Volltreffer!" : "Platz \(e.2)")
            } else {
                out[p] = Outcome(correct: nil, countsForStreak: false)
            }
        }
        return out
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        let kat = ctx.catalog.categories.first { $0.id == state.question.kat }
        let wall = QuestionWall(text: state.question.text, kategorie: state.question.kat, kategorieName: kat?.name ?? "", kategorieEmoji: kat?.emoji ?? "❓",
                                schwierigkeit: state.question.schw, wert: state.hard ? 800 : 400, options: nil,
                                answered: Array(state.guesses.keys), deadline: revealed ? nil : ctx.visible(state.deadline), timerMs: state.timerMs,
                                revealed: revealed, correctIndex: nil, answersByPlayer: [:], erklaerung: revealed ? state.question.erkl : nil,
                                nummer: ctx.fragenNummer, gesamt: ctx.fragenGesamt)
        let r = ranking(state, ctx: ctx)
        let guesses = revealed ? state.guesses.map { g in Guess(playerId: g.key, value: g.value, distanz: abs(g.value - state.spec.richtwert), platz: r.first { $0.0 == g.key }?.2) } : []
        return MinigameStageOutput(wall: wall,
                                   extra: .numberLine(min: state.spec.min, max: state.spec.max, unit: state.spec.einheit, guesses: guesses,
                                                      truth: revealed ? state.spec.richtwert : nil, log: state.spec.skala == "log"),
                                   title: meta.name)
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed {
            let s = scores(state, ctx: ctx)[player] ?? 0
            let detail = "Richtig: \(format(state.spec.richtwert)) \(state.spec.einheit)" + (state.guesses[player].map { " · dein Tipp: \(format($0))" } ?? "")
            return .reveal(title: s >= 1000 ? "NAGEL AUF DEN KOPF!" : (s >= 150 ? "Gut geschätzt!" : "Trostpreis"), correct: s >= 150, delta: s, detail: detail, streak: 0, speedBonus: nil)
        }
        let range = state.spec.max - state.spec.min
        let step = range > 1000 ? 10.0 : (range > 100 ? 1.0 : (range > 10 ? 0.5 : 0.1))
        return .number(question: state.question.text, min: state.spec.min, max: state.spec.max, step: step, log: state.spec.skala == "log",
                       unit: state.spec.einheit, current: state.guesses[player], locked: state.guesses[player] != nil, deadline: ctx.visible(state.deadline))
    }

    static func format(_ v: Double) -> String {
        v == v.rounded() ? Money.formatNumber(Int(v)) : String(format: "%.1f", v)
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        let info = GmQuestionInfo(id: state.question.id, text: state.question.text, kategorie: ctx.catalog.categoryName(state.question.kat),
                                  schwierigkeit: state.question.schw, korrekt: "\(format(state.spec.richtwert)) \(state.spec.einheit)",
                                  erklaerung: state.question.erkl, tipps: state.question.tipps, typ: .schaetz)
        return (info, state.guesses.mapValues { format($0) })
    }
}

/// Affenleiter — sort 4 items. Per correctly placed item value/4; all correct
/// +50 % perfect bonus and only then the speed bonus + streak.
public enum Affenleiter: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var question: Question
        public var items: [String]
        public var correct: [Int]
        public var startOrders: [PlayerId: [Int]]
        public var orders: [PlayerId: [Int]]
        public var lockedAt: [PlayerId: Millis]
        public var startedAt: Millis
        public var deadline: Millis
        public var timerMs: Int
        public var finishedAt: Millis?
        public var werte: [String]
    }

    public static let meta = MinigameMeta(
        id: "affenleiter", name: "Affenleiter", emoji: "🪜",
        kurz: "Vier Dinge in die richtige Reihenfolge — jede richtige Sprosse zahlt, alles richtig gibt den Perfekt-Bonus.",
        erklaerung: "Vier Begriffe, eine Ordnung: größer, älter, teurer, früher. Sortiere die Karten per Tippen oder Ziehen und logge ein. Jede richtig platzierte Sprosse bringt ein Viertel des Fragenwerts; die komplett richtige Leiter gibt +50 % Perfekt-Bonus, den Speed-Bonus und zählt für die Streak.",
        contentKind: .fragen([.sortier]), jokerAktionen: [], isMc: false, musik: "question_bed_easy"
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        let q = FormatHelpers.first(questions, kind: meta.contentKind)
        let items = q.elemente ?? ["A", "B", "C", "D"]
        let correct = q.reihenfolge ?? Array(items.indices)
        var starts: [PlayerId: [Int]] = [:]
        for p in ctx.players {
            var order = ctx.rng.shuffled(Array(items.indices))
            if order == correct { order.reverse() }
            starts[p] = order
        }
        let t = Int(Double(ctx.answerWindow(30_000)) * ctx.mods.timerFaktor)
        return State(question: q, items: items, correct: correct, startOrders: starts, orders: starts, lockedAt: [:],
                     startedAt: ctx.now, deadline: ctx.now + t, timerMs: t, finishedAt: nil, werte: q.werte ?? [])
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        guard state.lockedAt[player] == nil, ctx.now <= state.deadline + ChoiceCore.graceMs else { return }
        switch action {
        case .order(let o):
            guard Set(o) == Set(state.items.indices), o.count == state.items.count else { return }
            state.orders[player] = o
        case .confirm, .button:
            if state.orders[player] != nil { state.lockedAt[player] = ctx.now }
        default: break
        }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        switch action {
        case .timerExtend(let ms): state.deadline += ms; state.timerMs += ms
        case .timerShift(let ms): state.deadline += ms; state.startedAt += ms
        case .forceFinish, .skipQuestion: state.finishedAt = ctx.now
        default: break
        }
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {}

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool {
        if state.finishedAt != nil || ctx.now > state.deadline + ChoiceCore.graceMs { return true }
        let active = ctx.players.filter { ctx.connected.contains($0) }
        return !active.isEmpty && active.allSatisfy { state.lockedAt[$0] != nil }
    }

    static func correctCount(_ s: State, _ p: PlayerId) -> Int {
        guard let o = s.orders[p], o.count == s.correct.count else { return 0 }
        return zip(o, s.correct).filter { $0 == $1 }.count
    }

    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] {
        var s: [PlayerId: Int] = [:]
        let wert = Int(Double(state.question.value) * ctx.mods.wertFaktor)
        for p in ctx.players {
            // Unmoved & unlocked = no rating; moved = current state counts.
            guard state.orders[p] != nil, state.lockedAt[p] != nil || state.orders[p] != state.startOrders[p] else { s[p] = 0; continue }
            let n = correctCount(state, p)
            var win = n * (wert / 4)
            if n == state.correct.count {
                win = Int(Double(win) * 1.5)
                let after = max(0, (state.lockedAt[p] ?? state.deadline) - state.startedAt)
                win += Money.speedBonus(value: wert, answeredAfterMs: after, timerMs: state.timerMs)
            }
            s[p] = Economy.roundTo10(win)
        }
        return s
    }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        var out: [PlayerId: Outcome] = [:]
        for p in ctx.players {
            let n = correctCount(state, p)
            let perfect = n == state.correct.count
            let rated = state.lockedAt[p] != nil || state.orders[p] != state.startOrders[p]
            out[p] = Outcome(correct: rated ? perfect : nil, answeredAfterMs: state.lockedAt[p].map { $0 - state.startedAt },
                             timerMs: state.timerMs, countsForStreak: perfect, detail: "\(n)/\(state.correct.count) Sprossen")
        }
        return out
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        let kat = ctx.catalog.categories.first { $0.id == state.question.kat }
        let wall = QuestionWall(text: state.question.text, kategorie: state.question.kat, kategorieName: kat?.name ?? "", kategorieEmoji: kat?.emoji ?? "❓",
                                schwierigkeit: state.question.schw, wert: state.question.value, options: nil, answered: Array(state.lockedAt.keys),
                                deadline: revealed ? nil : ctx.visible(state.deadline), timerMs: state.timerMs, revealed: revealed, correctIndex: nil,
                                answersByPlayer: [:], erklaerung: revealed ? state.question.erkl : nil, nummer: ctx.fragenNummer, gesamt: ctx.fragenGesamt)
        return MinigameStageOutput(wall: wall,
                                   extra: .ladder(items: state.items, correctOrder: state.correct, revealedSteps: revealed ? state.correct.count : 0,
                                                  playerOrders: revealed ? state.orders : [:], werte: state.werte),
                                   title: meta.name)
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed {
            let n = correctCount(state, player)
            let s = scores(state, ctx: ctx)[player] ?? 0
            let richtig = state.correct.map { state.items[$0] }.joined(separator: " → ")
            return .reveal(title: n == state.correct.count ? "PERFEKTE LEITER!" : "\(n)/\(state.correct.count) richtig", correct: n == state.correct.count,
                           delta: s, detail: richtig, streak: 0, speedBonus: nil)
        }
        let order = state.orders[player] ?? state.startOrders[player] ?? Array(state.items.indices)
        return .order(question: state.question.text, items: state.items.enumerated().map { OrderItem(id: $0.offset, text: $0.element) },
                      order: order, locked: state.lockedAt[player] != nil, deadline: ctx.visible(state.deadline))
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        let info = GmQuestionInfo(id: state.question.id, text: state.question.text, kategorie: ctx.catalog.categoryName(state.question.kat),
                                  schwierigkeit: state.question.schw, korrekt: state.correct.map { state.items[$0] }.joined(separator: " → "),
                                  erklaerung: state.question.erkl, tipps: state.question.tipps, typ: .sortier)
        var answers: [PlayerId: String] = [:]
        for (p, order) in state.orders where state.lockedAt[p] != nil {
            answers[p] = "\(correctCount(state, p))/\(state.correct.count) · " + order.map { state.items[$0] }.joined(separator: " → ")
        }
        return (info, answers)
    }
}
