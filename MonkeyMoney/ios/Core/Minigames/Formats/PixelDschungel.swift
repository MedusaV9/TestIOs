import Foundation

/// Pixel-Dschungel — an image sharpens in 8 steps of 3 s while the jackpot
/// ladder shrinks. Answer any time; wrong = 0 and locked for the question.
public enum PixelDschungel: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var core: ChoiceCore
        public var levelAt: [PlayerId: Int]
        public var startJackpot: Int
        public var stepDown: Int
        public var stepMs: Int
        public var maxLevel: Int
    }

    public static let meta = MinigameMeta(
        id: "pixel-dschungel", name: "Pixel-Dschungel", emoji: "🖼️",
        kurz: "Ein Bild wird in 8 Stufen scharf — je früher du richtig liegst, desto mehr bleibt im Jackpot.",
        erklaerung: "Ein Bild startet extrem verpixelt und wird alle drei Sekunden schärfer. Über dem Bild schrumpft der Fragen-Jackpot Stufe für Stufe (von 1,5× Fragenwert bis auf ein Viertel). Antworte jederzeit — richtig bringt den Jackpot-Stand deiner Stufe, falsch heißt Null und Sperre für den Rest der Frage. Wer geantwortet hat, sieht nichts mehr: Augen zu!",
        regeln: ["Ein Bild startet verpixelt und wird alle 3 s schärfer",
                 "Über dem Bild schrumpft der Jackpot Stufe für Stufe",
                 "Antworte, wann du willst — richtig = aktueller Jackpot",
                 "Falsch = 0 und gesperrt. Wer geantwortet hat: Augen zu!"],
        gewinn: "Start: 1,5× Fragenwert · am Ende: ¼ Fragenwert",
        contentKind: .fragen([.bildPixel, .choice, .emoji]), streak: false, jokerAktionen: ["fiftyFifty", "removeOne"], musik: "pixel_retro"
    )

    static let levels = 8

    /// Jackpot ladder anchored to the question value: 1.5 F down to a 0.25 F floor.
    static func ladder(_ d: Difficulty) -> (start: Int, floor: Int, step: Int) {
        Economy.pixelLadder(value: Money.value(d), steps: levels)
    }

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        let pool = questions.filter { $0.typ == .bildPixel }
        let q = pool.first ?? FormatHelpers.first(questions, kind: meta.contentKind)
        let stepMs = Int(Double(ctx.ms(3000)) * ctx.mods.timerFaktor)
        let core = ChoiceCore(question: q, ctx: ctx, timerMs: stepMs * levels + ctx.answerWindow(4000))
        let l = ladder(q.schw)
        return State(core: core, levelAt: [:], startJackpot: l.start, stepDown: l.step, stepMs: stepMs, maxLevel: levels)
    }

    public static func level(_ s: State, now: Millis) -> Int {
        min(s.maxLevel, max(0, (now - s.core.startedAt) / max(1, s.stepMs)))
    }

    public static func jackpot(_ s: State, level: Int) -> Int {
        let floor = max(10, s.startJackpot - s.maxLevel * s.stepDown)
        return max(floor, s.startJackpot - level * s.stepDown)
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        if case .choose(let i) = action {
            let lvl = level(state, now: ctx.now)
            if state.core.answer(player, index: i, now: ctx.now) { state.levelAt[player] = lvl }
        }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) { state.core.applyGm(action, ctx: &ctx) }
    public static func tick(_ state: inout State, ctx: inout MinigameContext) {}
    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.core.finished(now: ctx.now, ctx: ctx) }

    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] {
        var s: [PlayerId: Int] = [:]
        for p in ctx.players {
            s[p] = state.core.isCorrect(p) == true ? jackpot(state, level: state.levelAt[p] ?? state.maxLevel) : 0
        }
        return s
    }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] { state.core.standardOutcomes(ctx: ctx, speed: false) }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        var wall = state.core.wall(ctx: ctx, revealed: revealed)
        let lvl = revealed ? state.maxLevel : level(state, now: ctx.now)
        wall.pixelLevel = lvl
        wall.image = state.core.question.bild
        return MinigameStageOutput(wall: wall,
                                   extra: .pixel(image: state.core.question.bild ?? "", level: lvl, maxLevel: state.maxLevel,
                                                 jackpot: jackpot(state, level: lvl), locked: Array(state.core.answers.keys)),
                                   title: meta.name)
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed { return state.core.prompt(for: player, ctx: ctx, revealed: true, delta: scores(state, ctx: ctx)[player]) }
        if state.core.hasAnswered(player) {
            return .idle(title: "Augen zu! 🙈", subtitle: "Du hast geantwortet — die Auflösung kommt gleich.")
        }
        let lvl = level(state, now: ctx.now)
        return state.core.prompt(for: player, ctx: ctx, revealed: false, hint: "💰 Jackpot jetzt: \(Money.format(jackpot(state, level: lvl)))")
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) { state.core.gmInfo(ctx: ctx) }
}

/// Affenbank — the signature round: rapid-fire MC in a 10-s beat. Majority
/// right doubles the chain pot (0.2 F → 3.2 F, medium: 50 → 800); BANK!
/// secures the pot personally and resets the chain. A split vote holds the
/// pot, a wrong majority burns it; at the closing gong an open pot goes to
/// everyone who had the last question right. Quick: 1 run, otherwise 2.
public enum Affenbank: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var questions: [Question]
        public var qIndex: Int
        public var core: ChoiceCore?
        public var pot: Int
        public var chainStep: Int
        public var banked: [PlayerId: Int]
        public var durchgang: Int
        public var durchgaenge: Int
        public var durchgangEndsAt: Millis
        public var lastBanker: PlayerId?
        /// "waechst" | "haelt" | "verbrennt" after a beat, nil while answering.
        public var verdict: String?
        public var revealUntil: Millis?
        public var finished: Bool
        public var bankWindow: [PlayerId: Millis]
        public var correctCounts: [PlayerId: Int]
        public var answersTotal: [PlayerId: Int]
        public var usedQuestions: Int
        public var chain: [Int]
        public var gongFor: [PlayerId]
    }

    static let beatMs = 10_000
    static let revealMs = 2500

    public static let meta = MinigameMeta(
        id: "affenbank", name: "Affenbank", emoji: "🏦",
        kurz: "Schnellfeuer-Kette: Mehrheit richtig verdoppelt den Pott — BANK! sichert ihn dir persönlich.",
        erklaerung: "Die Signatur-Runde. Schnellfeuer-Fragen im 10-Sekunden-Takt an alle. Antwortet die Mehrheit richtig, verdoppelt sich der Pott: 50 → 100 → 200 → 400 → 800 MM. Jeder hat jederzeit den roten BANK!-Knopf: wer drückt, schreibt sich den aktuellen Pott gut — und die Kette startet für alle wieder bei 50. Steht es unentschieden, hält der Pott; falsche Mehrheit = der ungesicherte Pott verbrennt. Beim Schluss-Gong geht ein offener Pott an alle, die die letzte Frage richtig hatten.",
        regeln: ["Schnellfeuer-Fragen im 10-Sekunden-Takt an alle",
                 "Mehrheit richtig: der Pott verdoppelt sich (50 → 800)",
                 "BANK! sichert dir den Pott — die Kette startet neu bei 50",
                 "Unentschieden: Pott hält · Mehrheit falsch: Pott verbrennt",
                 "Schluss-Gong: offener Pott für alle, die die letzte Frage richtig hatten"],
        gewinn: "Gesichert = deins · nicht gesichert = weg (außer beim Schluss-Gong)",
        contentKind: .choiceLike, roundBased: true, streak: false, jokerAktionen: [], isMc: true, musik: "bank_round"
    )

    /// Quick Cash gets one compact run, the long shows two.
    static func runs(_ ctx: MinigameContext) -> (count: Int, ms: Int) {
        ctx.settings.modus == .quick ? (1, 60_000) : (2, 60_000)
    }

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        let r = runs(ctx)
        let value = Money.value(ctx.section.schwierigkeiten.max() ?? .medium)
        var s = State(questions: FormatHelpers.fitting(questions, kind: meta.contentKind), qIndex: 0, core: nil, pot: 0, chainStep: 0,
                      banked: [:], durchgang: 1, durchgaenge: r.count, durchgangEndsAt: ctx.now + ctx.ms(r.ms), lastBanker: nil, verdict: nil,
                      revealUntil: nil, finished: false, bankWindow: [:], correctCounts: [:], answersTotal: [:], usedQuestions: 0,
                      chain: Economy.bankChain(value: value), gongFor: [])
        nextQuestion(&s, ctx: &ctx)
        return s
    }

    static func nextQuestion(_ s: inout State, ctx: inout MinigameContext) {
        guard !s.questions.isEmpty else { s.finished = true; return }
        let q = s.questions[s.qIndex % s.questions.count]
        s.qIndex += 1
        s.usedQuestions = min(s.questions.count, max(s.usedQuestions, s.qIndex))
        var mods = ctx.mods
        mods.insiderId = nil
        var qctx = ctx
        qctx.mods = mods
        s.core = ChoiceCore(question: q, ctx: qctx, timerMs: ctx.ms(beatMs))
        s.revealUntil = nil
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        switch action {
        case .choose(let i):
            guard state.revealUntil == nil, var core = state.core else { return }
            if core.answer(player, index: i, now: ctx.now) { state.core = core }
        case .bank:
            guard state.pot > 0, state.bankWindow[player] == nil else { return }
            state.banked[player, default: 0] += state.pot
            state.bankWindow[player] = ctx.now
            state.lastBanker = player
            // Everyone pressing within the same 1-s window secures the same pot; reset happens on the beat.
        default: break
        }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        switch action {
        case .forceFinish, .skipQuestion: state.finished = true
        case .timerShift(let ms):
            state.durchgangEndsAt += ms
            state.core?.shift(ms: ms)
            if let r = state.revealUntil { state.revealUntil = r + ms }
        default: break
        }
    }

    /// Verdict of a beat: 2 players — both right grows, one right holds, none burns;
    /// 3+ players — majority grows, an exact split holds, a minority burns.
    static func verdict(correct: Int, active: Int) -> String {
        if active <= 0 { return "haelt" }
        if active <= 2 {
            if correct == active { return "waechst" }
            return correct > 0 ? "haelt" : "verbrennt"
        }
        if correct * 2 > active { return "waechst" }
        return correct * 2 == active ? "haelt" : "verbrennt"
    }

    /// Closing gong: an open pot goes to everyone who had the final question right.
    static func gong(_ state: inout State, core: ChoiceCore?, ctx: MinigameContext) {
        state.gongFor = []
        guard state.pot > 0, let core = core else { return }
        for p in ctx.players where ctx.connected.contains(p) && core.isCorrect(p) == true {
            state.banked[p, default: 0] += state.pot
            state.gongFor.append(p)
        }
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {
        guard !state.finished else { return }
        // Bank window reset: pot resets 1 s after the first BANK! of a window.
        if let firstBank = state.bankWindow.values.min(), ctx.now >= firstBank + 1000 {
            state.pot = 0
            state.chainStep = 0
            state.bankWindow = [:]
        }
        if let r = state.revealUntil {
            if ctx.now >= r {
                if ctx.now >= state.durchgangEndsAt {
                    gong(&state, core: state.core, ctx: ctx)
                    if state.durchgang >= state.durchgaenge { state.finished = true; return }
                    state.durchgang += 1
                    state.durchgangEndsAt = ctx.now + ctx.ms(runs(ctx).ms)
                    state.pot = 0
                    state.chainStep = 0
                }
                nextQuestion(&state, ctx: &ctx)
            }
            return
        }
        guard let core = state.core else { state.finished = true; return }
        if core.finished(now: ctx.now, ctx: ctx) {
            let active = ctx.players.filter { ctx.connected.contains($0) }
            let correct = active.filter { core.isCorrect($0) == true }.count
            for p in active {
                state.answersTotal[p, default: 0] += 1
                if core.isCorrect(p) == true { state.correctCounts[p, default: 0] += 1 }
            }
            let v = verdict(correct: correct, active: active.count)
            state.verdict = v
            switch v {
            case "waechst":
                state.chainStep = min(state.chain.count - 1, state.pot == 0 ? 0 : state.chainStep + 1)
                state.pot = state.chain[state.chainStep]
            case "verbrennt":
                state.pot = 0
                state.chainStep = 0
            default:
                break
            }
            state.revealUntil = ctx.now + ctx.ms(revealMs)
        }
    }

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.finished }

    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] {
        var s: [PlayerId: Int] = [:]
        for p in ctx.players { s[p] = state.banked[p] ?? 0 }
        return s
    }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        var out: [PlayerId: Outcome] = [:]
        for p in ctx.players {
            let c = state.correctCounts[p] ?? 0
            let t = state.answersTotal[p] ?? 0
            out[p] = Outcome(correct: (state.banked[p] ?? 0) > 0, countsForStreak: false, detail: "\(c)/\(t) richtig · gesichert \(Money.format(state.banked[p] ?? 0))")
        }
        return out
    }

    /// Is the running beat the last one of this run? (BANK now or never.)
    static func lastBeat(_ state: State, ctx: MinigameContext) -> Bool {
        state.revealUntil == nil && (state.core?.deadline ?? 0) + ctx.ms(revealMs) >= state.durchgangEndsAt
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        var qctx = ctx
        qctx.fragenNummer = state.qIndex
        qctx.fragenGesamt = 0
        let wall = revealed ? nil : state.core?.wall(ctx: qctx, revealed: state.revealUntil != nil)
        let title = state.durchgaenge > 1 ? "Affenbank · Durchgang \(state.durchgang)/\(state.durchgaenge)" : "Affenbank"
        return MinigameStageOutput(wall: wall,
                                   extra: .bankPot(pot: state.pot, chain: state.chain, chainStep: state.chainStep, banked: state.banked, lastBanker: state.lastBanker,
                                                   verdict: state.revealUntil != nil ? state.verdict : nil, durchgang: state.durchgang, durchgaenge: state.durchgaenge,
                                                   runEndsAt: state.durchgangEndsAt, letzteFrage: lastBeat(state, ctx: ctx), gongFor: state.gongFor),
                                   title: title, audio: AudioCue(music: meta.musik))
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed {
            let b = state.banked[player] ?? 0
            let c = state.correctCounts[player] ?? 0
            let detail = "\(c) richtige \(c == 1 ? "Antwort" : "Antworten")" + (state.gongFor.contains(player) ? " · Schluss-Gong gesichert" : "")
            return .reveal(title: b > 0 ? "GESICHERT!" : "Nichts gesichert", correct: b > 0 ? true : nil, delta: b, detail: detail, streak: 0, speedBonus: nil)
        }
        guard let core = state.core else { return .idle(title: "Affenbank", subtitle: nil) }
        let chosen = core.answers[player]?.index
        if state.revealUntil != nil {
            let c = core.isCorrect(player)
            let own = c == true ? "✅ Richtig! " : (c == false ? "❌ Falsch. " : "⏰ Zu langsam. ")
            let group: String
            switch state.verdict {
            case "waechst": group = "Mehrheit richtig — der Pott wächst!"
            case "haelt": group = "Unentschieden — der Pott hält."
            default: group = "Mehrheit falsch — der Pott verbrennt."
            }
            return .bank(question: own + group, options: core.options(for: player), chosen: chosen, pot: state.pot, banked: state.banked[player] ?? 0, deadline: state.revealUntil)
        }
        let prefix = lastBeat(state, ctx: ctx) && state.pot > 0 ? "⏳ LETZTE FRAGE — BANK jetzt oder nie!\n" : ""
        return .bank(question: prefix + core.question.displayText, options: core.options(for: player), chosen: chosen, pot: state.pot,
                     banked: state.banked[player] ?? 0, deadline: core.deadline)
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        state.core?.gmInfo(ctx: ctx) ?? (nil, [:])
    }

    public static func questionsUsed(_ state: State) -> Int { max(1, state.usedQuestions) }
}

/// Stinkbanane — pass the bomb. Only the holder sees the question; right =
/// the banana moves on (+100), wrong/slow = keep it. Explosion (45–75 s):
/// −500 MM into the jackpot jar and mud splatter until match end. 2 runs.
public enum Stinkbanane: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var questions: [Question]
        public var qIndex: Int
        public var core: ChoiceCore?
        public var holder: PlayerId
        public var order: [PlayerId]
        public var fuseEndsAt: Millis
        public var fuseStartedAt: Millis
        public var durchgang: Int
        public var passes: [PlayerId: Int]
        public var exploded: [PlayerId]
        public var cooldownUntil: Millis?
        public var revealUntil: Millis?
        public var lastCorrect: Bool?
        public var finished: Bool
        public var explodedAt: Millis?
        public var cheers: [PlayerId: Int]
        public var usedQuestions: Int
    }

    static let questionMs = 8000
    static let cooldownMs = 2500
    /// The banana visibly flies to the next monkey — also paces a hot round.
    static let flyMs = 1800
    static let passWin = 100
    static let explosionPenalty = 500

    public static let meta = MinigameMeta(
        id: "stinkbanane", name: "Stinkbanane", emoji: "💣",
        kurz: "Nur der Halter sieht die Frage — richtig gibt die Banane weiter (+100), platzt sie, zahlst du 500 ins Glas.",
        erklaerung: "Eine tickende Stinkbanane startet bei einem Zufallsaffen. Nur wer sie hält, sieht die Frage: richtig = +100 MM und die Banane wandert weiter; falsch oder zu langsam = festhalten, neue Frage. Der Zünder ist geheim (45–75 s). Platzt sie, zahlt der Halter 500 MM ins Jackpot-Glas und trägt Matsch bis zum Ende. Alle anderen: ANFEUERN!",
        regeln: ["Die Stinkbanane tickt — nur wer sie hält, sieht die Frage",
                 "Richtig: +100 MM und die Banane wandert weiter",
                 "Falsch oder zu langsam: festhalten, neue Frage",
                 "Platzt sie (geheim, 45–75 s): −500 MM ins Jackpot-Glas + Matsch",
                 "Alle anderen: 🥁 ANFEUERN!"],
        gewinn: "Pro Weitergabe +100 MM · Explosion −500 MM ins Glas",
        contentKind: .choiceLike, roundBased: true, streak: false, strafenInsGlas: true, jokerAktionen: [], isMc: true, musik: "bomb_pass"
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        let order = ctx.players
        let start = ctx.rng.pick(order.filter { ctx.connected.contains($0) }) ?? order.first ?? ""
        var s = State(questions: FormatHelpers.fitting(questions, kind: meta.contentKind), qIndex: 0, core: nil, holder: start, order: order,
                      fuseEndsAt: 0, fuseStartedAt: ctx.now, durchgang: 1, passes: [:], exploded: [], cooldownUntil: nil, revealUntil: nil,
                      lastCorrect: nil, finished: false, explodedAt: nil, cheers: [:], usedQuestions: 0)
        armFuse(&s, ctx: &ctx)
        nextQuestion(&s, ctx: &ctx)
        return s
    }

    static func armFuse(_ s: inout State, ctx: inout MinigameContext) {
        let secs = ctx.rng.int(in: 45...75)
        s.fuseStartedAt = ctx.now
        s.fuseEndsAt = ctx.now + ctx.ms(secs * 1000)
    }

    static func nextQuestion(_ s: inout State, ctx: inout MinigameContext) {
        guard !s.questions.isEmpty else { s.finished = true; return }
        let q = s.questions[s.qIndex % s.questions.count]
        s.qIndex += 1
        s.usedQuestions = min(s.questions.count, max(s.usedQuestions, s.qIndex))
        var qctx = ctx
        qctx.mods = QuestionMods()
        s.core = ChoiceCore(question: q, ctx: qctx, timerMs: ctx.ms(questionMs))
        s.revealUntil = nil
    }

    static func nextHolder(_ s: State, ctx: MinigameContext) -> PlayerId {
        guard let i = s.order.firstIndex(of: s.holder) else { return s.holder }
        for step in 1...max(1, s.order.count) {
            let cand = s.order[(i + step) % s.order.count]
            if ctx.connected.contains(cand) { return cand }
        }
        return s.holder
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        switch action {
        case .choose(let i):
            guard player == state.holder, state.revealUntil == nil, state.cooldownUntil == nil, state.explodedAt == nil, var core = state.core else { return }
            if core.answer(player, index: i, now: ctx.now) {
                state.core = core
                let correct = core.isCorrect(player) == true
                state.lastCorrect = correct
                if correct {
                    state.passes[player, default: 0] += 1
                    state.holder = nextHolder(state, ctx: ctx)
                    state.revealUntil = ctx.now + flyMs
                } else {
                    state.cooldownUntil = ctx.now + ctx.ms(cooldownMs)
                }
            }
        case .cheer:
            if player != state.holder { state.cheers[player, default: 0] += 1 }
        default: break
        }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        switch action {
        case .forceFinish, .skipQuestion: state.finished = true
        case .timerShift(let ms):
            state.fuseEndsAt += ms
            state.core?.shift(ms: ms)
            if let c = state.cooldownUntil { state.cooldownUntil = c + ms }
            if let r = state.revealUntil { state.revealUntil = r + ms }
        default: break
        }
    }

    public static func onDisconnect(_ state: inout State, player: PlayerId, ctx: inout MinigameContext) {
        if player == state.holder && state.explodedAt == nil {
            state.holder = nextHolder(state, ctx: ctx)
            nextQuestion(&state, ctx: &ctx)
        }
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {
        guard !state.finished else { return }
        if let at = state.explodedAt {
            if ctx.now >= at + ctx.ms(4000) {
                if state.durchgang >= 2 { state.finished = true; return }
                state.durchgang = 2
                state.explodedAt = nil
                state.holder = ctx.rng.pick(state.order.filter { ctx.connected.contains($0) && $0 != state.holder }) ?? state.holder
                armFuse(&state, ctx: &ctx)
                nextQuestion(&state, ctx: &ctx)
            }
            return
        }
        if ctx.now >= state.fuseEndsAt {
            // BOOM
            state.exploded.append(state.holder)
            state.explodedAt = ctx.now
            state.cooldownUntil = nil
            state.revealUntil = nil
            return
        }
        if let c = state.cooldownUntil {
            if ctx.now >= c { state.cooldownUntil = nil; nextQuestion(&state, ctx: &ctx) }
            return
        }
        if let r = state.revealUntil {
            if ctx.now >= r { nextQuestion(&state, ctx: &ctx) }
            return
        }
        if let core = state.core, ctx.now > core.deadline {
            state.lastCorrect = false
            state.cooldownUntil = ctx.now + ctx.ms(cooldownMs)
        }
    }

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.finished }

    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] {
        var s: [PlayerId: Int] = [:]
        for p in ctx.players {
            s[p] = (state.passes[p] ?? 0) * passWin - state.exploded.filter { $0 == p }.count * explosionPenalty
        }
        return s
    }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        var out: [PlayerId: Outcome] = [:]
        for p in ctx.players {
            let boom = state.exploded.contains(p)
            out[p] = Outcome(correct: boom ? false : ((state.passes[p] ?? 0) > 0 ? true : nil), countsForStreak: false,
                             detail: boom ? "💥 Explodiert" : "\(state.passes[p] ?? 0) Weitergaben")
        }
        return out
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        let total = max(1, state.fuseEndsAt - state.fuseStartedAt)
        let tension = min(1, max(0, Double(ctx.now - state.fuseStartedAt) / Double(total)))
        var wall: QuestionWall? = nil
        if !revealed, let core = state.core, state.explodedAt == nil {
            var w = core.wall(ctx: ctx, revealed: state.revealUntil != nil || state.cooldownUntil != nil)
            w.options = nil // only the holder sees the options on the phone
            wall = w
        }
        return MinigameStageOutput(wall: wall,
                                   extra: .bomb(holder: state.holder, tension: revealed ? 1 : tension, passes: state.passes.values.reduce(0, +),
                                                exploded: state.explodedAt != nil ? state.holder : nil, durchgang: state.durchgang),
                                   title: "Stinkbanane · Durchgang \(state.durchgang)/2", audio: AudioCue(music: meta.musik))
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed {
            let s = scores(state, ctx: ctx)[player] ?? 0
            let passes = state.passes[player] ?? 0
            let boom = state.exploded.contains(player)
            let title = boom ? "💥 MATSCH!" : (passes == 0 ? "Nie dran gewesen" : "\(passes)× weitergegeben")
            let detail = boom ? "\(passes)× weitergegeben (+\(Money.format(passes * passWin))) · Explosion −\(Money.format(explosionPenalty)) ins Glas" : (passes > 0 ? "\(passes) × +\(Money.format(passWin))" : nil)
            return .reveal(title: title, correct: boom ? false : (passes > 0 ? true : nil), delta: s, detail: detail, streak: 0, speedBonus: nil)
        }
        if state.explodedAt != nil {
            return .idle(title: state.holder == player ? "💥 BOOM! Du hattest sie …" : "💥 \(ctx.name(state.holder)) ist matschig!", subtitle: "−\(Money.format(explosionPenalty)) ins Jackpot-Glas")
        }
        guard player == state.holder, let core = state.core else {
            return .cheer(title: "🥁 ANFEUERN!", subtitle: "\(ctx.name(state.holder)) hält die Stinkbanane — trommeln!", taps: state.cheers[player] ?? 0)
        }
        if let c = state.cooldownUntil {
            return .confirm(title: "❌ Falsch — festhalten!", subtitle: "Die Banane bleibt bei dir. Neue Frage gleich …", button: "Festhalten …", done: true, deadline: c)
        }
        if state.revealUntil != nil {
            return .idle(title: "✅ Richtig! Weitergegeben!", subtitle: "+\(Money.format(passWin)) — die Banane fliegt zu \(ctx.name(state.holder))")
        }
        return core.prompt(for: player, ctx: ctx, revealed: false, hint: "💣 Du hältst die Stinkbanane! Richtig = weitergeben")
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        let g = state.core?.gmInfo(ctx: ctx) ?? (nil, [:])
        var answers = g.1
        answers["_halter"] = ctx.name(state.holder) + " · Zünder in \(max(0, (state.fuseEndsAt - ctx.now) / 1000)) s"
        return (g.0, answers)
    }

    public static func questionsUsed(_ state: State) -> Int { max(1, state.usedQuestions) }
}
