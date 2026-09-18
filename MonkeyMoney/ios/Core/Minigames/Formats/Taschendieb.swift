import Foundation

/// Taschendieb-Affe — fastest correct answer wins the right to steal
/// (300/500 MM, capped at 25 % of the victim, never the same victim 3× in a row).
public enum Taschendieb: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var core: ChoiceCore
        public var phase: String // frage | opferwahl | cutscene | fertig
        public var thief: PlayerId?
        public var victim: PlayerId?
        public var amount: Int
        public var chooseUntil: Millis?
        public var cutsceneUntil: Millis?
        public var fotofinish: PlayerId?
        public var blocked: Bool
    }

    public static let meta = MinigameMeta(
        id: "taschendieb", name: "Taschendieb-Affe", emoji: "🦝",
        kurz: "Die schnellste richtige Antwort darf klauen — 300/500 MM vom Opfer deiner Wahl.",
        erklaerung: "Alle antworten — aber nur die SCHNELLSTE richtige Antwort gewinnt das Klau-Recht: geheime Opferwahl auf dem Handy, dann flitzt der Dieb-Affe mit Maske los. 300 MM (mittel) bzw. 500 MM (schwer), gedeckelt auf ein Viertel des Opfer-Kontos. Alle anderen Richtigen bekommen den halben Fragenwert aus der Bank. Der Bananentresor-Joker blockt den Klau.",
        contentKind: .choiceLike, streak: false, jokerAktionen: ["fiftyFifty", "removeOne"], isMc: true, musik: "steal_sneak"
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        State(core: ChoiceCore(question: FormatHelpers.first(questions, kind: meta.contentKind), ctx: ctx), phase: "frage", thief: nil,
              victim: nil, amount: 0, chooseUntil: nil, cutsceneUntil: nil, fotofinish: nil, blocked: false)
    }

    static func stealBase(_ d: Difficulty) -> Int { d >= .hard ? 500 : 300 }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        switch (state.phase, action) {
        case ("frage", .choose(let i)):
            _ = state.core.answer(player, index: i, now: ctx.now)
        case ("opferwahl", .pickPlayer(let v)):
            guard player == state.thief, v != player, ctx.players.contains(v) else { return }
            pickVictim(&state, v, ctx: &ctx)
        default: break
        }
    }

    static func candidates(_ state: State, ctx: MinigameContext) -> [PlayerId] {
        ctx.players.filter { $0 != state.thief && ctx.connected.contains($0) }
    }

    static func pickVictim(_ state: inout State, _ v: PlayerId, ctx: inout MinigameContext) {
        state.victim = v
        let base = stealBase(state.core.question.schw)
        let cap = max(0, (ctx.balances[v] ?? 0) / 4)
        state.blocked = ctx.klauSchutz.contains(v)
        state.amount = state.blocked ? 0 : Economy.roundTo50(min(base, cap))
        state.phase = "cutscene"
        state.cutsceneUntil = ctx.now + ctx.ms(6000)
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        if state.phase == "frage" { state.core.applyGm(action, ctx: &ctx) }
        if case .forceFinish = action { state.phase = "fertig" }
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {
        switch state.phase {
        case "frage":
            guard state.core.finished(now: ctx.now, ctx: ctx) else { return }
            // Fastest correct answer wins the steal.
            let correct = state.core.answers.filter { $0.value.index == state.core.correctIndex }.sorted { $0.value.at < $1.value.at }
            guard let first = correct.first else { state.phase = "fertig"; return }
            state.thief = first.key
            if correct.count > 1, correct[1].value.at - first.value.at < 50 { state.fotofinish = correct[1].key }
            let cands = candidates(state, ctx: ctx)
            if cands.count == 1 {
                pickVictim(&state, cands[0], ctx: &ctx)
            } else if cands.isEmpty {
                state.phase = "fertig"
            } else {
                state.phase = "opferwahl"
                state.chooseUntil = ctx.now + ctx.answerWindow(8000)
            }
        case "opferwahl":
            if let u = state.chooseUntil, ctx.now >= u {
                // Timeout: richest connected candidate.
                let cands = candidates(state, ctx: ctx)
                if let richest = cands.max(by: { (ctx.balances[$0] ?? 0) < (ctx.balances[$1] ?? 0) }) {
                    pickVictim(&state, richest, ctx: &ctx)
                } else { state.phase = "fertig" }
            }
        case "cutscene":
            if let u = state.cutsceneUntil, ctx.now >= u { state.phase = "fertig" }
        default: break
        }
    }

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.phase == "fertig" }

    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] {
        var s: [PlayerId: Int] = [:]
        let half = state.core.question.value / 2
        for p in ctx.players {
            if state.core.isCorrect(p) == true && p != state.thief { s[p] = half } else { s[p] = 0 }
        }
        if let f = state.fotofinish { s[f] = state.core.question.value }
        if let t = state.thief, let v = state.victim, state.amount > 0 {
            s[t, default: 0] += state.amount
            s[v, default: 0] -= state.amount
        }
        return s
    }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        var out = state.core.standardOutcomes(ctx: ctx, speed: false)
        for p in ctx.players { out[p]?.countsForStreak = false }
        if let t = state.thief { out[t]?.detail = "🦝 Dieb" }
        if let v = state.victim { out[v]?.detail = state.blocked ? "🛡️ Tresor hat geblockt" : "Bestohlen: −\(Money.format(state.amount))" }
        return out
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        let showReveal = revealed || state.phase != "frage"
        return MinigameStageOutput(wall: state.core.wall(ctx: ctx, revealed: showReveal),
                                   extra: .steal(thief: state.thief, victim: state.victim, betrag: state.amount, phase: revealed ? "fertig" : state.phase,
                                                 candidates: candidates(state, ctx: ctx)),
                                   title: meta.name, audio: state.phase == "cutscene" ? AudioCue(music: nil, sfx: ["klau"]) : nil)
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed {
            let s = scores(state, ctx: ctx)[player] ?? 0
            let title = player == state.thief ? "🦝 Du hast geklaut!" : (player == state.victim ? (state.blocked ? "🛡️ Geblockt!" : "Beklaut!") : (state.core.isCorrect(player) == true ? "Richtig!" : "Falsch"))
            return .reveal(title: title, correct: state.core.isCorrect(player), delta: s, detail: "Richtig war: \(state.core.options[state.core.correctIndex])", streak: 0, speedBonus: nil)
        }
        switch state.phase {
        case "frage": return state.core.prompt(for: player, ctx: ctx, revealed: false)
        case "opferwahl":
            if player == state.thief {
                let refs = candidates(state, ctx: ctx).map { id in PlayerRef(Player(id: id, name: ctx.name(id), avatar: Avatar(), joinOrder: 0), platz: 0) }
                var withBalance = refs
                for i in withBalance.indices { withBalance[i].balance = ctx.balances[withBalance[i].id] ?? 0 }
                return .pickPlayer(title: "Bei wem klaust du?", subtitle: "\(Money.format(stealBase(state.core.question.schw))) (max. 25 % des Kontos)", candidates: withBalance, chosen: nil, deadline: ctx.visible(state.chooseUntil))
            }
            return .idle(title: "🦝 \(ctx.name(state.thief ?? "")) wählt ein Opfer …", subtitle: "Festhalten!")
        default:
            return .idle(title: state.victim == player ? "😱 Du wirst beklaut!" : "🦝 Klau-Cutscene", subtitle: state.victim.map { "\(ctx.name(state.thief ?? "")) klaut bei \(ctx.name($0))" })
        }
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) { state.core.gmInfo(ctx: ctx) }
}

/// Alles oder Banane — high stakes: only category + difficulty are teased,
/// secret bets (100–1.000, ≤50 % of balance), bets revealed BEFORE the question.
public enum AllesOderBanane: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var core: ChoiceCore
        public var phase: String // setzen | reveal | frage | fertig
        public var bets: [PlayerId: Int]
        public var caps: [PlayerId: Int]
        public var credit: [PlayerId]
        public var betUntil: Millis
        public var revealUntil: Millis?
        public var revealedCount: Int
    }

    public static let meta = MinigameMeta(
        id: "alles-oder-banane", name: "Alles oder Banane", emoji: "🎰",
        kurz: "Nur Kategorie + Schwierigkeit sind bekannt — setz geheim, dann wird aufgedeckt und gefragt.",
        erklaerung: "Die Risiko-Runde. Du erfährst nur Kategorie und Schwierigkeit — dann setzt jeder GEHEIM 100 bis 1.000 MM (höchstens die Hälfte des Kontos). Erst werden alle Einsätze mit Trommelwirbel aufgedeckt, DANN kommt die Frage. Richtig = Einsatz verdoppelt, falsch = Einsatz weg. Wer pleite ist, bekommt 100 MM Kredit der Affenbank.",
        contentKind: .choiceLike, streak: false, jokerAktionen: ["fiftyFifty"], isMc: true, musik: "jackpot_drama"
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        let q = FormatHelpers.first(questions, kind: meta.contentKind)
        var caps: [PlayerId: Int] = [:]
        var credit: [PlayerId] = []
        for p in ctx.players {
            let bal = ctx.balances[p] ?? 0
            if bal < 100 { caps[p] = 100; credit.append(p) } else {
                let cap = ctx.settings.allInErlaubt ? bal : bal / 2
                caps[p] = max(100, min(1000, cap / 50 * 50))
            }
        }
        var core = ChoiceCore(question: q, ctx: ctx, timerMs: Int(Double(ctx.answerWindow(20_000)) * ctx.mods.timerFaktor))
        core.startedAt = 0 // set when the question phase starts
        return State(core: core, phase: "setzen", bets: [:], caps: caps, credit: credit, betUntil: ctx.now + ctx.answerWindow(12_000), revealUntil: nil, revealedCount: 0)
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        switch (state.phase, action) {
        case ("setzen", .wager(let w)):
            guard state.bets[player] == nil else { return }
            let cap = state.caps[player] ?? 100
            state.bets[player] = max(100, min(cap, w / 50 * 50))
        case ("frage", .choose(let i)):
            _ = state.core.answer(player, index: i, now: ctx.now)
        default: break
        }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        if state.phase == "frage" { state.core.applyGm(action, ctx: &ctx) }
        if case .forceFinish = action { state.phase = "fertig" }
    }

    static func startQuestion(_ state: inout State, ctx: inout MinigameContext) {
        state.core.startedAt = ctx.now
        state.core.deadline = ctx.now + state.core.timerMs
        state.phase = "frage"
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {
        switch state.phase {
        case "setzen":
            let active = ctx.players.filter { ctx.connected.contains($0) }
            let all = active.allSatisfy { state.bets[$0] != nil }
            if ctx.now >= state.betUntil || (all && !active.isEmpty) {
                for p in ctx.players where state.bets[p] == nil { state.bets[p] = 100 }
                state.phase = "reveal"
                state.revealUntil = ctx.now + ctx.ms(6000)
            }
        case "reveal":
            if let r = state.revealUntil {
                let total = ctx.ms(6000)
                let elapsed = total - (r - ctx.now)
                state.revealedCount = min(ctx.players.count, max(0, Int(Double(elapsed) / Double(max(1, total)) * Double(ctx.players.count + 1))))
                if ctx.now >= r { state.revealedCount = ctx.players.count; startQuestion(&state, ctx: &ctx) }
            }
        case "frage":
            if state.core.finished(now: ctx.now, ctx: ctx) { state.phase = "fertig" }
        default: break
        }
    }

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.phase == "fertig" }

    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] {
        var s: [PlayerId: Int] = [:]
        for p in ctx.players {
            let bet = state.bets[p] ?? 100
            switch state.core.isCorrect(p) {
            case .some(true): s[p] = bet
            case .some(false): s[p] = state.credit.contains(p) ? 0 : -bet
            case .none: s[p] = ctx.connected.contains(p) ? (state.credit.contains(p) ? 0 : -bet) : 0
            }
        }
        return s
    }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        var out = state.core.standardOutcomes(ctx: ctx, speed: false)
        for p in ctx.players {
            out[p]?.countsForStreak = false
            out[p]?.detail = "Einsatz \(Money.format(state.bets[p] ?? 0))"
        }
        return out
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        let kat = ctx.catalog.categories.first { $0.id == state.core.question.kat }
        let teaser = "Gleich: \(kat?.name ?? "?") · \(state.core.question.schw.label.uppercased())"
        var wall: QuestionWall? = nil
        if state.phase == "frage" || state.phase == "fertig" || revealed {
            wall = state.core.wall(ctx: ctx, revealed: revealed || state.phase == "fertig")
        }
        let ordered = ctx.players.enumerated().map { (i, p) in
            Bet(playerId: p, betrag: state.bets[p] ?? 0, revealed: state.phase != "setzen" && (state.phase != "reveal" || i < state.revealedCount))
        }
        return MinigameStageOutput(wall: wall, extra: .bets(bets: ordered, teaser: teaser, phase: revealed ? "fertig" : state.phase), title: meta.name,
                                   audio: state.phase == "reveal" ? AudioCue(music: nil, sfx: ["trommelwirbel"]) : nil)
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed {
            let s = scores(state, ctx: ctx)[player] ?? 0
            return .reveal(title: s > 0 ? "EINSATZ VERDOPPELT!" : (s < 0 ? "Einsatz weg!" : "±0"), correct: state.core.isCorrect(player), delta: s,
                           detail: "Richtig war: \(state.core.options[state.core.correctIndex])", streak: 0, speedBonus: nil)
        }
        let kat = ctx.catalog.categoryName(state.core.question.kat)
        switch state.phase {
        case "setzen":
            let cap = state.caps[player] ?? 100
            return .wager(title: "Gleich: \(kat) · \(state.core.question.schw.label)", subtitle: state.credit.contains(player) ? "Kredit der Affenbank: 100 MM gratis" : "Max. \(Money.format(cap))",
                          min: 100, max: cap, step: 50, current: state.bets[player], locked: state.bets[player] != nil, deadline: ctx.visible(state.betUntil))
        case "reveal":
            return .idle(title: "Einsätze werden aufgedeckt …", subtitle: "Dein Einsatz: \(Money.format(state.bets[player] ?? 100))")
        default:
            return state.core.prompt(for: player, ctx: ctx, revealed: false, hint: "🎰 Einsatz: \(Money.format(state.bets[player] ?? 100))")
        }
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        var g = state.core.gmInfo(ctx: ctx)
        for (p, b) in state.bets { g.answers[p] = (g.answers[p] ?? "—") + " · Einsatz \(b)" }
        return g
    }
}

/// Lianen-Finale — every monkey hangs on a liana over the crocodile river.
/// Q questions, right +W, wrong −W/2, no speed/streak/jokers (formula §3.5).
public enum LianenFinale: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var core: ChoiceCore
    }

    public static let meta = MinigameMeta(
        id: "lianen-finale", name: "Lianen-Finale", emoji: "🐊",
        kurz: "Jede Frage ist W_final wert: richtig hoch, falsch runter — das Krokodil wartet.",
        erklaerung: "Das große Finale über dem Krokodil-Fluss. Deine Liane ist so lang wie dein Kontostand. Jede Frage ist heute W_final wert: richtig = Ruck nach oben, falsch = die Hälfte runter, keine Antwort = nichts. Keine Joker, keine Streaks, kein Speed-Bonus — die Formel hält: der Letzte kann noch gewinnen, wenn er perfekt spielt.",
        contentKind: .choiceLike, streak: false, jokerAktionen: [], isMc: true, musik: "finale_showdown"
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        var qctx = ctx
        qctx.mods.timerFaktor = 1
        var core = ChoiceCore(question: FormatHelpers.first(questions, kind: meta.contentKind), ctx: qctx, timerMs: ctx.answerWindow(12_000))
        core.insiderId = nil
        core.blackout = false
        return State(core: core)
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        if case .choose(let i) = action { _ = state.core.answer(player, index: i, now: ctx.now) }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        switch action {
        case .timerExtend, .timerShift, .forceFinish, .skipQuestion: state.core.applyGm(action, ctx: &ctx)
        default: break
        }
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {}
    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.core.finished(now: ctx.now, ctx: ctx) }

    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] {
        var s: [PlayerId: Int] = [:]
        for p in ctx.players { s[p] = Economy.finaleDelta(correct: state.core.isCorrect(p), w: ctx.wFinal) }
        return s
    }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        var out = state.core.standardOutcomes(ctx: ctx, speed: false)
        for p in ctx.players { out[p]?.countsForStreak = false }
        return out
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        var wall = state.core.wall(ctx: ctx, revealed: revealed)
        wall.wert = ctx.wFinal
        let maxBal = max(1, ctx.balances.values.max() ?? 1)
        var lengths: [PlayerId: Double] = [:]
        for p in ctx.players { lengths[p] = max(0.25, Double(max(0, ctx.balances[p] ?? 0)) / Double(maxBal)) }
        return MinigameStageOutput(wall: wall, extra: .lianen(lengths: lengths, w: ctx.wFinal, deltas: revealed ? scores(state, ctx: ctx) : [:]), title: meta.name)
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed { return state.core.prompt(for: player, ctx: ctx, revealed: true, delta: scores(state, ctx: ctx)[player]) }
        return state.core.prompt(for: player, ctx: ctx, revealed: false, hint: "🐊 Jede Frage: ±\(Money.format(ctx.wFinal))")
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) { state.core.gmInfo(ctx: ctx) }
}
