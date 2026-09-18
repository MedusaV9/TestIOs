import Foundation

/// Monkey Market — distribute 10 chips on the 4 answer doors. Chips on the
/// correct door pay ×2 chip value; "everything on one door" adds a courage bonus.
public enum MonkeyMarket: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var core: ChoiceCore
        public var placed: [PlayerId: [Int]]
        public var locked: [PlayerId: Millis]
    }

    public static let chips = 10

    public static let meta = MinigameMeta(
        id: "monkey-market", name: "Monkey Market", emoji: "🏪",
        kurz: "10 Chips auf 4 Antwort-Türen verteilen — die richtige Tür zahlt doppelt.",
        erklaerung: "Handel am Markt: Du bekommst 10 Gratis-Chips und verteilst sie auf die vier Antwort-Türen. Chips auf der richtigen Tür kommen doppelt zurück, alle anderen verfallen. Wer ALLES auf eine Tür setzt und richtig liegt, bekommt den Mut-Bonus obendrauf.",
        contentKind: .choiceLike, streak: false, jokerAktionen: [], isMc: false, musik: "market_trade", v2: true
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        State(core: ChoiceCore(question: FormatHelpers.first(questions, kind: meta.contentKind), ctx: ctx, timerMs: ctx.ms(25_000)), placed: [:], locked: [:])
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        guard state.locked[player] == nil, ctx.now <= state.core.deadline + ChoiceCore.graceMs else { return }
        switch action {
        case .chips(let c):
            guard c.count == state.core.options.count, c.allSatisfy({ $0 >= 0 }), c.reduce(0, +) == chips else { return }
            state.placed[player] = c
        case .confirm, .button:
            if state.placed[player] != nil { state.locked[player] = ctx.now }
        default: break
        }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) { state.core.applyGm(action, ctx: &ctx) }
    public static func tick(_ state: inout State, ctx: inout MinigameContext) {}

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool {
        if state.core.finishedAt != nil || ctx.now > state.core.deadline + ChoiceCore.graceMs { return true }
        let active = ctx.players.filter { ctx.connected.contains($0) }
        return !active.isEmpty && active.allSatisfy { state.locked[$0] != nil }
    }

    static func chipValue(_ q: Question) -> Int { max(10, q.value / chips) }

    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] {
        var s: [PlayerId: Int] = [:]
        let cv = chipValue(state.core.question)
        for p in ctx.players {
            guard let c = state.placed[p] else { s[p] = 0; continue }
            let onCorrect = c[state.core.correctIndex]
            var win = onCorrect * cv * 2
            if onCorrect == chips { win = Int(Double(win) * (state.core.question.schw == .ultrahard ? 1.25 : 1.25)) }
            s[p] = Economy.roundTo10(win)
        }
        return s
    }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        var out: [PlayerId: Outcome] = [:]
        for p in ctx.players {
            guard let c = state.placed[p] else { out[p] = Outcome(correct: nil, countsForStreak: false); continue }
            out[p] = Outcome(correct: c[state.core.correctIndex] > 0, countsForStreak: false, detail: "\(c[state.core.correctIndex])/\(chips) Chips richtig")
        }
        return out
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        var per = Array(repeating: 0, count: state.core.options.count)
        for c in state.placed.values where revealed { for (i, n) in c.enumerated() where i < per.count { per[i] += n } }
        var wall = state.core.wall(ctx: ctx, revealed: revealed)
        wall.answered = Array(state.locked.keys)
        return MinigameStageOutput(wall: wall, extra: .chips(perOption: per, quotes: nil, placedBy: revealed ? state.placed : [:]), title: meta.name)
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed {
            let s = scores(state, ctx: ctx)[player] ?? 0
            return .reveal(title: s > 0 ? "Gute Anlage!" : "Fehlinvestition", correct: s > 0, delta: s, detail: "Richtig war: \(state.core.options[state.core.correctIndex])", streak: 0, speedBonus: nil)
        }
        let placed = state.placed[player] ?? Array(repeating: 0, count: state.core.options.count)
        return .chips(question: state.core.question.displayText, options: state.core.options(for: player), total: chips, placed: placed,
                      locked: state.locked[player] != nil, deadline: state.core.deadline)
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        var g = state.core.gmInfo(ctx: ctx)
        for (p, c) in state.placed { g.answers[p] = c.map(String.init).joined(separator: "/") }
        return g
    }
}

/// Bananen-Börse — invest a fixed stake (W/2) in an option; the quote sinks
/// with herd behaviour (3.0 − 1.5 × share, min 1.2). One switch allowed.
public enum BananenBoerse: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var core: ChoiceCore
        public var positions: [PlayerId: Int]
        public var switched: [PlayerId]
        public var stake: Int
    }

    public static let meta = MinigameMeta(
        id: "bananen-boerse", name: "Bananen-Börse", emoji: "📈",
        kurz: "Investiere in eine Antwort — je mehr Affen dieselbe kaufen, desto schlechter die Quote.",
        erklaerung: "Live-Börse: Jeder investiert einen festen Einsatz in eine Antwort-Aktie. Die Quote sinkt, je mehr Affen dieselbe Antwort kaufen (Herdentrieb!). Richtig = Einsatz × Quote, falsch = Einsatz weg. Einmal umschichten ist erlaubt — kostet aber 25 % Spread.",
        contentKind: .choiceLike, streak: false, jokerAktionen: [], isMc: true, musik: "bank_round", v2: true
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        let q = FormatHelpers.first(questions, kind: meta.contentKind)
        return State(core: ChoiceCore(question: q, ctx: ctx, timerMs: ctx.ms(20_000)), positions: [:], switched: [], stake: q.value / 2)
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        guard case .choose(let i) = action, i >= 0, i < state.core.options.count, ctx.now <= state.core.deadline else { return }
        if let cur = state.positions[player] {
            guard cur != i, !state.switched.contains(player) else { return }
            state.switched.append(player)
        }
        state.positions[player] = i
        state.core.answers[player] = ChoiceCore.Answer(index: i, at: ctx.now, secondTry: false, wrongFirst: nil)
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) { state.core.applyGm(action, ctx: &ctx) }
    public static func tick(_ state: inout State, ctx: inout MinigameContext) {}
    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.core.finishedAt != nil || ctx.now > state.core.deadline + ChoiceCore.graceMs }

    static func quotes(_ state: State, ctx: MinigameContext) -> [Double] {
        let n = max(1, state.positions.count)
        return state.core.options.indices.map { i in
            let share = Double(state.positions.values.filter { $0 == i }.count) / Double(n)
            return max(1.2, 3.0 - 1.5 * share)
        }
    }

    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] {
        var s: [PlayerId: Int] = [:]
        let q = quotes(state, ctx: ctx)
        for p in ctx.players {
            guard let pos = state.positions[p] else { s[p] = 0; continue }
            let stake = state.switched.contains(p) ? Int(Double(state.stake) * 0.75) : state.stake
            s[p] = pos == state.core.correctIndex ? Economy.roundTo10(Int(Double(stake) * q[pos]) - state.stake + stake) - (stake - state.stake) : -stake
            if pos == state.core.correctIndex { s[p] = Economy.roundTo10(Int(Double(stake) * (q[pos] - 1))) }
        }
        return s
    }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        var out = state.core.standardOutcomes(ctx: ctx, speed: false)
        let q = quotes(state, ctx: ctx)
        for p in ctx.players {
            out[p]?.countsForStreak = false
            if let pos = state.positions[p] { out[p]?.detail = String(format: "Quote %.2f", q[pos]) }
        }
        return out
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        var per = Array(repeating: 0, count: state.core.options.count)
        for pos in state.positions.values { per[pos] += 1 }
        return MinigameStageOutput(wall: state.core.wall(ctx: ctx, revealed: revealed),
                                   extra: .chips(perOption: per, quotes: quotes(state, ctx: ctx), placedBy: revealed ? state.positions.mapValues { [$0] } : [:]),
                                   title: meta.name)
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed {
            let s = scores(state, ctx: ctx)[player] ?? 0
            return .reveal(title: s > 0 ? "KURSGEWINN!" : "Crash", correct: s > 0, delta: s, detail: "Richtig war: \(state.core.options[state.core.correctIndex])", streak: 0, speedBonus: nil)
        }
        let q = quotes(state, ctx: ctx)
        var opts = state.core.options(for: player)
        for i in opts.indices { opts[i].text += String(format: "  ·  ×%.2f", q[opts[i].id]) }
        let hint = "💵 Einsatz \(Money.format(state.stake))" + (state.positions[player] != nil && !state.switched.contains(player) ? " · 1× umschichten möglich" : "")
        return .choice(question: state.core.question.displayText, options: opts, chosen: state.switched.contains(player) ? state.positions[player] : nil, deadline: state.core.deadline, secondTry: false, hint: hint)
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) { state.core.gmInfo(ctx: ctx) }
}

/// Affen-Auktion — 20 s blind auction for the exclusive right to answer.
/// Right = +bid, wrong = the bid is distributed to all others.
public enum AffenAuktion: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var core: ChoiceCore
        public var phase: String // bieten | frage | fertig
        public var bids: [PlayerId: Int]
        public var bidUntil: Millis
        public var winner: PlayerId?
        public var winningBid: Int
    }

    public static let meta = MinigameMeta(
        id: "affen-auktion", name: "Affen-Auktion", emoji: "🔨",
        kurz: "Biete verdeckt um das exklusive Antwortrecht — richtig verdoppelt, falsch zahlt an alle.",
        erklaerung: "Zum Ersten, zum Zweiten … Nur Kategorie und Schwierigkeit sind bekannt. Jeder bietet verdeckt (25er-Schritte bis 1.000 MM) um das EXKLUSIVE Antwortrecht. Das höchste Gebot gewinnt und antwortet allein: richtig = Gebot als Gewinn, falsch = das Gebot wird an alle anderen verteilt.",
        contentKind: .choiceLike, streak: false, jokerAktionen: [], isMc: true, musik: "market_trade", v2: true
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        var core = ChoiceCore(question: FormatHelpers.first(questions, kind: meta.contentKind), ctx: ctx)
        core.startedAt = 0
        return State(core: core, phase: "bieten", bids: [:], bidUntil: ctx.now + ctx.ms(20_000), winner: nil, winningBid: 0)
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        switch (state.phase, action) {
        case ("bieten", .wager(let w)):
            guard state.bids[player] == nil else { return }
            let cap = min(1000, max(100, (ctx.balances[player] ?? 0) + 500))
            state.bids[player] = max(0, min(cap, w / 25 * 25))
        case ("frage", .choose(let i)):
            guard player == state.winner else { return }
            _ = state.core.answer(player, index: i, now: ctx.now)
        default: break
        }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        if state.phase == "frage" { state.core.applyGm(action, ctx: &ctx) }
        if case .forceFinish = action { state.phase = "fertig" }
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {
        switch state.phase {
        case "bieten":
            let active = ctx.players.filter { ctx.connected.contains($0) }
            if ctx.now >= state.bidUntil || (!active.isEmpty && active.allSatisfy { state.bids[$0] != nil }) {
                let best = state.bids.filter { $0.value > 0 }.max { a, b in a.value < b.value || (a.value == b.value && ctx.players.firstIndex(of: a.key)! > ctx.players.firstIndex(of: b.key)!) }
                guard let w = best else { state.phase = "fertig"; return }
                state.winner = w.key
                state.winningBid = w.value
                state.core.startedAt = ctx.now
                state.core.deadline = ctx.now + state.core.timerMs
                state.phase = "frage"
            }
        case "frage":
            if let w = state.winner, state.core.answers[w] != nil || ctx.now > state.core.deadline + ChoiceCore.graceMs || state.core.finishedAt != nil {
                state.phase = "fertig"
            }
        default: break
        }
    }

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.phase == "fertig" }

    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] {
        var s: [PlayerId: Int] = [:]
        for p in ctx.players { s[p] = 0 }
        guard let w = state.winner else { return s }
        if state.core.isCorrect(w) == true {
            s[w] = state.winningBid
        } else {
            s[w] = -state.winningBid
            let others = ctx.players.filter { $0 != w }
            if !others.isEmpty {
                let share = Economy.roundTo10(state.winningBid / others.count)
                for o in others { s[o] = share }
            }
        }
        return s
    }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        var out: [PlayerId: Outcome] = [:]
        for p in ctx.players {
            out[p] = Outcome(correct: p == state.winner ? state.core.isCorrect(p) : nil, countsForStreak: false,
                             detail: "Gebot \(Money.format(state.bids[p] ?? 0))")
        }
        return out
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        let wall = state.phase == "bieten" ? nil : state.core.wall(ctx: ctx, revealed: revealed || state.phase == "fertig")
        let bidsShown = state.phase == "bieten" ? [:] : state.bids
        return MinigameStageOutput(wall: wall, extra: .auction(bids: bidsShown, leader: state.winner, endsAt: state.phase == "bieten" ? state.bidUntil : nil, phase: revealed ? "fertig" : state.phase),
                                   title: "\(meta.name) · \(ctx.catalog.categoryName(state.core.question.kat)) · \(state.core.question.schw.label)")
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed {
            let s = scores(state, ctx: ctx)[player] ?? 0
            return .reveal(title: player == state.winner ? (s > 0 ? "ZUSCHLAG & RICHTIG!" : "Teurer Fehler …") : (s > 0 ? "Anteil kassiert" : "Kein Zuschlag"), correct: s > 0, delta: s,
                           detail: "Richtig war: \(state.core.options[state.core.correctIndex])", streak: 0, speedBonus: nil)
        }
        switch state.phase {
        case "bieten":
            let cap = min(1000, max(100, (ctx.balances[player] ?? 0) + 500))
            return .wager(title: "Gebot: \(ctx.catalog.categoryName(state.core.question.kat)) · \(state.core.question.schw.label)", subtitle: "Verdeckt bieten — 0 = passen", min: 0, max: cap, step: 25,
                          current: state.bids[player], locked: state.bids[player] != nil, deadline: state.bidUntil)
        case "frage":
            if player == state.winner { return state.core.prompt(for: player, ctx: ctx, revealed: false, hint: "🔨 Dein Zuschlag: \(Money.format(state.winningBid))") }
            return .idle(title: "🔨 \(ctx.name(state.winner ?? "")) hat den Zuschlag", subtitle: "\(Money.format(state.winningBid)) — falsch wird an alle verteilt!")
        default: return .idle(title: "Auflösung …", subtitle: nil)
        }
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        var g = state.core.gmInfo(ctx: ctx)
        for (p, b) in state.bids { g.answers[p] = (g.answers[p] ?? "") + " Gebot \(b)" }
        return g
    }
}

/// Bananen-Bluff — invent a lie; whoever falls for YOUR lie pays YOU.
public enum BananenBluff: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var question: Question
        public var truth: String
        public var phase: String // luegen | raten | fertig
        public var lies: [PlayerId: String]
        public var entries: [String]
        public var authors: [Int: PlayerId]
        public var truthIndex: Int
        public var votes: [PlayerId: Int]
        public var phaseUntil: Millis
        public var startedAt: Millis
    }

    public static let meta = MinigameMeta(
        id: "bananen-bluff", name: "Bananen-Bluff", emoji: "🤥",
        kurz: "Erfinde eine glaubwürdige Lüge — wer darauf hereinfällt, zahlt dir.",
        erklaerung: "Fibbage im Dschungel: Zu einer obskuren Frage erfindet jeder eine falsche, aber glaubwürdige Antwort. Dann werden alle Lügen zusammen mit der Wahrheit gemischt. Wer die Wahrheit findet, kassiert den halben Fragenwert; wer auf DEINE Lüge fällt, zahlt dir den halben Fragenwert. Lügen ist Diebstahl!",
        minPlayers: 3, contentKind: .fragen([.choice]), streak: false, jokerAktionen: [], isMc: false, musik: "estimate_think", v2: true
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        let q = FormatHelpers.first(questions, kind: meta.contentKind)
        let truth = q.correctIndex.flatMap { i in (q.antworten ?? []).indices.contains(i) ? q.antworten![i] : nil } ?? "?"
        return State(question: q, truth: truth, phase: "luegen", lies: [:], entries: [], authors: [:], truthIndex: 0, votes: [:], phaseUntil: ctx.now + ctx.ms(40_000), startedAt: ctx.now)
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        switch (state.phase, action) {
        case ("luegen", .text(let t)):
            let clean = t.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty, clean.lowercased() != state.truth.lowercased() else { return }
            state.lies[player] = String(clean.prefix(40))
        case ("raten", .choose(let i)):
            guard state.votes[player] == nil, i >= 0, i < state.entries.count, state.authors[i] != player else { return }
            state.votes[player] = i
        default: break
        }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        switch action {
        case .forceFinish, .skipQuestion: state.phase = "fertig"
        case .timerExtend(let ms), .timerShift(let ms): state.phaseUntil += ms
        default: break
        }
    }

    static func startVoting(_ state: inout State, ctx: inout MinigameContext) {
        var entries: [(String, PlayerId?)] = state.lies.map { ($0.value, $0.key) }
        entries.append((state.truth, nil))
        entries = ctx.rng.shuffled(entries)
        state.entries = entries.map { $0.0 }
        state.authors = [:]
        for (i, e) in entries.enumerated() {
            if let a = e.1 { state.authors[i] = a } else { state.truthIndex = i }
        }
        state.phase = "raten"
        state.phaseUntil = ctx.now + ctx.ms(20_000)
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {
        let active = ctx.players.filter { ctx.connected.contains($0) }
        switch state.phase {
        case "luegen":
            if ctx.now >= state.phaseUntil || (!active.isEmpty && active.allSatisfy { state.lies[$0] != nil }) { startVoting(&state, ctx: &ctx) }
        case "raten":
            if ctx.now >= state.phaseUntil || (!active.isEmpty && active.allSatisfy { state.votes[$0] != nil }) { state.phase = "fertig" }
        default: break
        }
    }

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.phase == "fertig" }

    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] {
        var s: [PlayerId: Int] = [:]
        let half = state.question.value / 2
        for p in ctx.players { s[p] = 0 }
        for (voter, idx) in state.votes {
            if idx == state.truthIndex { s[voter, default: 0] += half }
            else if let author = state.authors[idx] { s[author, default: 0] += half; s[voter, default: 0] -= half }
        }
        return s
    }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        var out: [PlayerId: Outcome] = [:]
        for p in ctx.players {
            let fooled = state.votes.values.filter { state.authors[$0] == p }.count
            out[p] = Outcome(correct: state.votes[p].map { $0 == state.truthIndex }, countsForStreak: false, detail: "\(fooled) getäuscht")
        }
        return out
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        let kat = ctx.catalog.categories.first { $0.id == state.question.kat }
        let wall = QuestionWall(text: state.question.text, kategorie: state.question.kat, kategorieName: kat?.name ?? "", kategorieEmoji: kat?.emoji ?? "❓",
                                schwierigkeit: state.question.schw, wert: state.question.value / 2, options: nil,
                                answered: state.phase == "luegen" ? Array(state.lies.keys) : Array(state.votes.keys), deadline: state.phase == "fertig" ? nil : state.phaseUntil,
                                timerMs: 40_000, revealed: revealed, correctIndex: nil, answersByPlayer: [:], erklaerung: revealed ? state.question.erkl : nil,
                                nummer: ctx.fragenNummer, gesamt: ctx.fragenGesamt)
        let entries = state.entries.enumerated().map { (i, text) in ChoiceOption(id: i, text: text, count: revealed ? state.votes.values.filter { v in v == i }.count : nil) }
        return MinigameStageOutput(wall: wall, extra: .bluff(entries: entries, authors: revealed ? state.authors : nil, votes: revealed ? state.votes : [:], phase: revealed ? "fertig" : state.phase,
                                                             truthIndex: revealed ? state.truthIndex : nil), title: meta.name)
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed {
            let s = scores(state, ctx: ctx)[player] ?? 0
            return .reveal(title: state.votes[player] == state.truthIndex ? "Wahrheit gefunden!" : "Reingefallen!", correct: state.votes[player] == state.truthIndex, delta: s,
                           detail: "Wahrheit: \(state.truth)", streak: 0, speedBonus: nil)
        }
        switch state.phase {
        case "luegen":
            return .text(question: state.question.text, placeholder: "Deine glaubwürdige Lüge …", maxLength: 40, submitted: state.lies[player], deadline: state.phaseUntil)
        case "raten":
            let opts = state.entries.enumerated().map { ChoiceOption(id: $0.offset, text: $0.element, removed: state.authors[$0.offset] == player) }
            return .choice(question: "Was ist die Wahrheit?", options: opts, chosen: state.votes[player], deadline: state.phaseUntil, secondTry: false, hint: "Deine eigene Lüge ist gesperrt.")
        default: return .idle(title: "Auflösung …", subtitle: nil)
        }
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        let info = GmQuestionInfo(id: state.question.id, text: state.question.text, kategorie: ctx.catalog.categoryName(state.question.kat), schwierigkeit: state.question.schw,
                                  korrekt: state.truth, erklaerung: state.question.erkl, tipps: state.question.tipps, typ: .choice)
        return (info, state.lies)
    }
}
