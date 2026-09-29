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
        regeln: ["10 Gratis-Chips auf die 4 Antwort-Türen verteilen",
                 "Chips auf der richtigen Tür kommen doppelt zurück",
                 "Alle anderen Chips verfallen",
                 "Alles auf eine Tür und richtig? Mut-Bonus obendrauf"],
        gewinn: "Pro Chip auf der richtigen Tür: 1/5 Fragenwert · All-in richtig: +25 % Mut-Bonus",
        contentKind: .choiceLike, streak: false, jokerAktionen: [], isMc: false, musik: "market_trade", v2: true
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        State(core: ChoiceCore(question: FormatHelpers.first(questions, kind: meta.contentKind), ctx: ctx, timerMs: ctx.answerWindow(25_000)), placed: [:], locked: [:])
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
            if onCorrect == chips { win = Int(Double(win) * 1.25) }
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
        wall.answered = FormatHelpers.inOrder(state.locked.keys, ctx.players)
        return MinigameStageOutput(wall: wall, extra: .chips(perOption: per, quotes: nil, placedBy: revealed ? state.placed : [:]), title: meta.name)
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed {
            let s = scores(state, ctx: ctx)[player] ?? 0
            return .reveal(title: s > 0 ? "Gute Anlage!" : "Fehlinvestition", correct: s > 0, delta: s, detail: "Richtig war: \(state.core.options[state.core.correctIndex])", streak: 0, speedBonus: nil)
        }
        let placed = state.placed[player] ?? Array(repeating: 0, count: state.core.options.count)
        return .chips(question: state.core.question.displayText, options: state.core.options(for: player), total: chips, placed: placed,
                      locked: state.locked[player] != nil, deadline: ctx.visible(state.core.deadline))
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        var g = state.core.gmInfo(ctx: ctx)
        for (p, c) in state.placed {
            let right = c.indices.contains(state.core.correctIndex) ? c[state.core.correctIndex] : 0
            g.answers[p] = c.map(String.init).joined(separator: "/") + " · \(right) richtig" + (state.locked[p] == nil ? " (nicht eingeloggt)" : "")
        }
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
        /// Last buy/switch — the market closes a few seconds after everyone is invested.
        public var lastTradeAt: Millis?
    }

    /// Once everyone holds a position the market closes this long after the last trade.
    static let closeMs = 5000

    public static let meta = MinigameMeta(
        id: "bananen-boerse", name: "Bananen-Börse", emoji: "📈",
        kurz: "Investiere in eine Antwort — je mehr Affen dieselbe kaufen, desto schlechter die Quote.",
        erklaerung: "Live-Börse: Jeder investiert einen festen Einsatz (den halben Fragenwert) in eine Antwort-Aktie. Die Quote sinkt, je mehr Affen dieselbe Antwort kaufen (Herdentrieb!). Richtig = Kursgewinn Einsatz × (Quote − 1), falsch = Einsatz weg. Einmal umschichten ist erlaubt — kostet aber 25 % vom Kursgewinn. Sobald alle investiert sind, schließt der Markt fünf Sekunden nach dem letzten Kauf.",
        regeln: ["Investiere einen festen Einsatz in eine Antwort-Aktie",
                 "Je mehr Affen dieselbe kaufen, desto schlechter die Quote",
                 "Richtig: Kursgewinn = Einsatz × (Quote − 1) · falsch: Einsatz weg",
                 "Einmal umschichten erlaubt — kostet 25 % vom Kursgewinn",
                 "Sind alle investiert, schließt der Markt 5 s nach dem letzten Kauf"],
        gewinn: "Richtig: +Einsatz × (Quote − 1) · Falsch: −Einsatz (½ Fragenwert)",
        contentKind: .choiceLike, streak: false, jokerAktionen: [], isMc: true, musik: "bank_round", v2: true
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        let q = FormatHelpers.first(questions, kind: meta.contentKind)
        return State(core: ChoiceCore(question: q, ctx: ctx, timerMs: ctx.answerWindow(20_000)), positions: [:], switched: [], stake: q.value / 2, lastTradeAt: nil)
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        guard case .choose(let i) = action, i >= 0, i < state.core.options.count, ctx.now <= state.core.deadline, state.core.finishedAt == nil else { return }
        if state.core.globalRemoved.contains(i) || (state.core.removed[player] ?? []).contains(i) { return }
        if let cur = state.positions[player] {
            guard cur != i, !state.switched.contains(player) else { return }
            state.switched.append(player)
        }
        state.positions[player] = i
        state.core.answers[player] = ChoiceCore.Answer(index: i, at: ctx.now, secondTry: false, wrongFirst: nil)
        state.lastTradeAt = ctx.now
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        state.core.applyGm(action, ctx: &ctx)
        if case .timerShift(let ms) = action, let t = state.lastTradeAt { state.lastTradeAt = t + ms }
    }
    public static func tick(_ state: inout State, ctx: inout MinigameContext) {}

    /// Market close: when everyone at the table is invested, 5 s after the last
    /// trade (fixes the timer-off hang and the dead wait until the deadline).
    static func closesAt(_ state: State, ctx: MinigameContext) -> Millis? {
        let active = ctx.players.filter { ctx.connected.contains($0) }
        guard !active.isEmpty, active.allSatisfy({ state.positions[$0] != nil }), let t = state.lastTradeAt else { return nil }
        return min(state.core.deadline, t + ctx.ms(closeMs))
    }

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool {
        if state.core.finishedAt != nil || ctx.now > state.core.deadline + ChoiceCore.graceMs { return true }
        return closesAt(state, ctx: ctx).map { ctx.now >= $0 } ?? false
    }

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
            if pos == state.core.correctIndex {
                // Switching costs 25 % of the gain (the spread) — it never lowers the risk.
                let gain = Double(state.stake) * (q[pos] - 1) * (state.switched.contains(p) ? 0.75 : 1)
                s[p] = Economy.roundTo10(Int(gain))
            } else {
                s[p] = -state.stake
            }
        }
        return s
    }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        var out = state.core.standardOutcomes(ctx: ctx, speed: false)
        let q = quotes(state, ctx: ctx)
        for p in ctx.players {
            out[p]?.countsForStreak = false
            if let pos = state.positions[p] { out[p]?.detail = "Quote \(FormatHelpers.decimal(q[pos]))" }
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
        for i in opts.indices { opts[i].text += "  ·  ×" + FormatHelpers.decimal(q[opts[i].id]) }
        var hint = "💵 Einsatz \(Money.format(state.stake))" + (state.positions[player] != nil && !state.switched.contains(player) ? " · 1× umschichten möglich (−25 % vom Gewinn)" : "")
        if let close = closesAt(state, ctx: ctx) { hint += " · Markt schließt in \(max(0, (close - ctx.now + 999) / 1000)) s" }
        return .choice(question: state.core.question.displayText, options: opts, chosen: state.switched.contains(player) ? state.positions[player] : nil,
                       deadline: ctx.visible(closesAt(state, ctx: ctx) ?? state.core.deadline), secondTry: false, hint: hint)
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        var g = state.core.gmInfo(ctx: ctx)
        let q = quotes(state, ctx: ctx)
        for (p, pos) in state.positions where q.indices.contains(pos) {
            g.answers[p] = (g.answers[p] ?? "") + " · ×\(FormatHelpers.decimal(q[pos]))" + (state.switched.contains(p) ? " (umgeschichtet)" : "")
        }
        return g
    }
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
        /// When each bid came in (equal bids: the earlier one wins).
        public var bidAt: [PlayerId: Millis]?
        /// The winner left the table before answering — the lot is void, nobody pays.
        public var verfallen: Bool?
    }

    public static let meta = MinigameMeta(
        id: "affen-auktion", name: "Affen-Auktion", emoji: "🔨",
        kurz: "Biete verdeckt um das exklusive Antwortrecht — richtig verdoppelt, falsch zahlt an alle.",
        erklaerung: "Zum Ersten, zum Zweiten … Nur Kategorie und Schwierigkeit sind bekannt. Jeder bietet verdeckt (25er-Schritte bis 1.000 MM) um das EXKLUSIVE Antwortrecht. Das höchste Gebot gewinnt und antwortet allein: richtig = Gebot als Gewinn, falsch = das Gebot wird an alle anderen verteilt.",
        regeln: ["Nur Kategorie und Schwierigkeit sind bekannt",
                 "Alle bieten VERDECKT um das alleinige Antwortrecht",
                 "Das höchste Gebot gewinnt und antwortet allein — bei Gleichstand das frühere",
                 "Richtig: Gebot als Gewinn · falsch oder zu langsam: Gebot geht an alle anderen"],
        gewinn: "Richtig +Gebot · Falsch: Gebot wird an die anderen verteilt",
        contentKind: .choiceLike, streak: false, jokerAktionen: [], isMc: true, musik: "market_trade", v2: true
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        var core = ChoiceCore(question: FormatHelpers.first(questions, kind: meta.contentKind), ctx: ctx)
        core.startedAt = 0
        return State(core: core, phase: "bieten", bids: [:], bidUntil: ctx.now + ctx.answerWindow(20_000), winner: nil, winningBid: 0, bidAt: [:], verfallen: nil)
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        switch (state.phase, action) {
        case ("bieten", .wager(let w)):
            guard state.bids[player] == nil else { return }
            let cap = min(1000, max(100, (ctx.balances[player] ?? 0) + 500))
            state.bids[player] = max(0, min(cap, w / 25 * 25))
            state.bidAt = state.bidAt ?? [:]
            state.bidAt?[player] = ctx.now
        case ("frage", .choose(let i)):
            guard player == state.winner else { return }
            _ = state.core.answer(player, index: i, now: ctx.now)
        default: break
        }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        switch action {
        case .forceFinish:
            if state.phase == "frage" { state.core.applyGm(action, ctx: &ctx) }
            state.phase = "fertig"
        case .timerShift(let ms):
            state.bidUntil += ms
            if state.phase == "frage" { state.core.applyGm(action, ctx: &ctx) }
        case .timerExtend(let ms):
            if state.phase == "bieten" { state.bidUntil += ms } else if state.phase == "frage" { state.core.applyGm(action, ctx: &ctx) }
        case .skipQuestion:
            // Bidding: close the auction now. Question: the lot is void (nobody pays).
            if state.phase == "bieten" { state.bidUntil = ctx.now } else if state.phase == "frage" { state.verfallen = true; state.phase = "fertig" }
        default:
            if state.phase == "frage" { state.core.applyGm(action, ctx: &ctx) }
        }
    }

    /// Highest bid wins; equal bids: the earlier bid, then seat order. Bidders who
    /// left the room are ignored (a kicked bidder used to crash the auction).
    static func bestBid(_ state: State, ctx: MinigameContext) -> (PlayerId, Int)? {
        let seat = Dictionary(uniqueKeysWithValues: ctx.players.enumerated().map { ($0.element, $0.offset) })
        let valid = state.bids.filter { $0.value > 0 && seat[$0.key] != nil }
        return valid.min { a, b in
            if a.value != b.value { return a.value > b.value }
            let ta = state.bidAt?[a.key] ?? 0, tb = state.bidAt?[b.key] ?? 0
            return ta != tb ? ta < tb : seat[a.key]! < seat[b.key]!
        }.map { ($0.key, $0.value) }
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {
        switch state.phase {
        case "bieten":
            let active = ctx.players.filter { ctx.connected.contains($0) }
            if ctx.now >= state.bidUntil || (!active.isEmpty && active.allSatisfy { state.bids[$0] != nil }) {
                guard let w = bestBid(state, ctx: ctx) else { state.phase = "fertig"; return }
                state.winner = w.0
                state.winningBid = w.1
                state.core.startedAt = ctx.now
                state.core.deadline = ctx.now + state.core.timerMs
                state.phase = "frage"
            }
        case "frage":
            guard let w = state.winner else { state.phase = "fertig"; return }
            if !ctx.connected.contains(w), state.core.answers[w] == nil {
                // The winner is gone (timer off would wait an hour): the lot is void.
                state.verfallen = true
                state.phase = "fertig"
            } else if state.core.answers[w] != nil || ctx.now > state.core.deadline + ChoiceCore.graceMs || state.core.finishedAt != nil {
                state.phase = "fertig"
            }
        default: break
        }
    }

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.phase == "fertig" }

    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] {
        var s: [PlayerId: Int] = [:]
        for p in ctx.players { s[p] = 0 }
        guard let w = state.winner, state.verfallen != true, ctx.players.contains(w) else { return s }
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
        return MinigameStageOutput(wall: wall, extra: .auction(bids: bidsShown, leader: state.winner, endsAt: state.phase == "bieten" ? ctx.visible(state.bidUntil) : nil, phase: revealed ? "fertig" : state.phase),
                                   title: "\(meta.name) · \(ctx.catalog.categoryName(state.core.question.kat)) · \(state.core.question.schw.label)")
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed {
            let s = scores(state, ctx: ctx)[player] ?? 0
            let title = state.verfallen == true ? "Zuschlag verfallen — niemand zahlt" : (player == state.winner ? (s > 0 ? "ZUSCHLAG & RICHTIG!" : "Teurer Fehler …") : (s > 0 ? "Anteil kassiert" : "Kein Zuschlag"))
            return .reveal(title: title, correct: s > 0, delta: s,
                           detail: "Richtig war: \(state.core.options[state.core.correctIndex])", streak: 0, speedBonus: nil)
        }
        switch state.phase {
        case "bieten":
            let cap = min(1000, max(100, (ctx.balances[player] ?? 0) + 500))
            let open = ctx.players.filter { ctx.connected.contains($0) && state.bids[$0] == nil }.count
            let sub = state.bids[player] == nil ? "Verdeckt bieten — 0 = passen · richtig = +Gebot, falsch = Gebot an alle"
                : (open == 0 ? "Gebot abgegeben — gleich fällt der Hammer!" : "Gebot abgegeben — noch \(open) am Bieten")
            return .wager(title: "Gebot: \(ctx.catalog.categoryName(state.core.question.kat)) · \(state.core.question.schw.label)", subtitle: sub, min: 0, max: cap, step: 25,
                          current: state.bids[player], locked: state.bids[player] != nil, deadline: ctx.visible(state.bidUntil))
        case "frage":
            if player == state.winner { return state.core.prompt(for: player, ctx: ctx, revealed: false, hint: "🔨 Dein Zuschlag: \(Money.format(state.winningBid))") }
            let share = Economy.roundTo10(state.winningBid / max(1, ctx.players.count - 1))
            return .idle(title: "🔨 \(ctx.name(state.winner ?? "")) hat den Zuschlag (\(Money.format(state.winningBid)))", subtitle: "Liegt \(ctx.name(state.winner ?? "")) falsch, bekommst du \(Money.format(share)) — Daumen drücken!")
        default: return .idle(title: "Auflösung …", subtitle: nil)
        }
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        var g = state.core.gmInfo(ctx: ctx)
        for (p, b) in state.bids { g.answers[p] = [g.answers[p], "Gebot \(Money.format(b))" + (p == state.winner ? " 🔨" : "")].compactMap { $0 }.joined(separator: " · ") }
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
        regeln: ["Erfinde zu einer obskuren Frage eine glaubwürdige Lüge",
                 "Alle Lügen werden mit der Wahrheit gemischt",
                 "Wer die Wahrheit findet: halber Fragenwert",
                 "Wer auf DEINE Lüge fällt, zahlt dir den halben Fragenwert"],
        gewinn: "Wahrheit: +½ Fragenwert · Reingefallen: −½ an den Lügner · pro Opfer deiner Lüge +½",
        minPlayers: 3, contentKind: .fragen([.choice]), streak: false, jokerAktionen: [], isMc: false, musik: "estimate_think", v2: true
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        let q = FormatHelpers.first(questions, kind: meta.contentKind)
        let truth = q.correctIndex.flatMap { i in (q.antworten ?? []).indices.contains(i) ? q.antworten![i] : nil } ?? "?"
        return State(question: q, truth: truth, phase: "luegen", lies: [:], entries: [], authors: [:], truthIndex: 0, votes: [:], phaseUntil: ctx.now + ctx.answerWindow(40_000), startedAt: ctx.now)
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
        // Seat order before the seeded shuffle — dictionary order would make the board differ per process.
        var entries: [(String, PlayerId?)] = FormatHelpers.inOrder(state.lies.keys, ctx.players).map { (state.lies[$0]!, $0) }
        entries.append((state.truth, nil))
        entries = ctx.rng.shuffled(entries)
        state.entries = entries.map { $0.0 }
        state.authors = [:]
        for (i, e) in entries.enumerated() {
            if let a = e.1 { state.authors[i] = a } else { state.truthIndex = i }
        }
        state.phase = "raten"
        state.phaseUntil = ctx.now + ctx.answerWindow(20_000)
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
                                answered: FormatHelpers.inOrder(state.phase == "luegen" ? Array(state.lies.keys) : Array(state.votes.keys), ctx.players),
                                deadline: state.phase == "fertig" ? nil : ctx.visible(state.phaseUntil),
                                timerMs: state.phase == "luegen" ? ctx.answerWindow(40_000) : ctx.answerWindow(20_000), revealed: revealed, correctIndex: nil, answersByPlayer: [:], erklaerung: revealed ? state.question.erkl : nil,
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
            if state.lies[player] != nil {
                let open = ctx.players.filter { ctx.connected.contains($0) && state.lies[$0] == nil }.count
                return .text(question: state.question.text + "\n✅ Lüge abgegeben — " + (open == 0 ? "gleich wird geraten!" : "noch \(open) am Flunkern, dann wird geraten"),
                             placeholder: "Deine glaubwürdige Lüge …", maxLength: 40, submitted: state.lies[player], deadline: ctx.visible(state.phaseUntil))
            }
            return .text(question: state.question.text, placeholder: "Deine glaubwürdige Lüge …", maxLength: 40, submitted: state.lies[player], deadline: ctx.visible(state.phaseUntil))
        case "raten":
            let opts = state.entries.enumerated().map { ChoiceOption(id: $0.offset, text: $0.element, removed: state.authors[$0.offset] == player) }
            return .choice(question: "Was ist die Wahrheit?", options: opts, chosen: state.votes[player], deadline: ctx.visible(state.phaseUntil), secondTry: false,
                           hint: state.votes[player] == nil ? "Deine eigene Lüge ist gesperrt. Wahrheit = +½ Fragenwert, eine Lüge kostet dich ½." : "Gewählt — gleich wird enthüllt, wer wen reingelegt hat")
        default: return .idle(title: "Auflösung …", subtitle: nil)
        }
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        let info = GmQuestionInfo(id: state.question.id, text: state.question.text, kategorie: ctx.catalog.categoryPath(state.question), schwierigkeit: state.question.schw,
                                  korrekt: state.truth, erklaerung: state.question.erkl, tipps: state.question.tipps, typ: .choice)
        var answers: [PlayerId: String] = [:]
        for p in ctx.players {
            var parts: [String] = []
            if let l = state.lies[p] { parts.append("Lüge: „\(l)“") }
            if let v = state.votes[p], state.entries.indices.contains(v) { parts.append("tippt „\(state.entries[v])“" + (v == state.truthIndex ? " ✅" : " ❌")) }
            if !parts.isEmpty { answers[p] = parts.joined(separator: " · ") }
        }
        return (info, answers)
    }
}
