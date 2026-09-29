import Foundation

/// ✅ Faktencheck — a rapid series of wahr/falsch facts with a short clock. A right
/// fact pays 0,6 F × the player's in-round streak multiplier (1st right ×1, 2nd in a
/// row ×1,5, 3rd ×2, from the 4th ×3 = cap). A wrong fact resets the streak and costs
/// 0,2 F — never more than the player still has (a balance never drops below 0
/// through a fact); no answer resets the streak and costs nothing.
public enum Faktencheck: MinigamePlugin {
    /// One player's line of a resolved fact.
    public struct Eintrag: Codable, Equatable, Sendable {
        public var player: PlayerId
        /// true = right, false = wrong, nil = no answer.
        public var correct: Bool?
        /// Signed: the win (streak multiplier included) or the cost.
        public var points: Int
        /// Streak after this fact.
        public var serie: Int
        public var ms: Int?
    }

    public struct State: Codable, Equatable, Sendable {
        public var questions: [Question]
        public var gesamt: Int
        public var index: Int
        public var core: ChoiceCore?
        public var wert: Int
        /// "frage" | "mini" | "fertig"
        public var phase: String
        public var revealUntil: Millis?
        public var serie: [PlayerId: Int]
        public var besteSerie: [PlayerId: Int]
        /// Net round result (wins − costs).
        public var punkte: [PlayerId: Int]
        public var gewinn: [PlayerId: Int]
        public var kosten: [PlayerId: Int]
        public var richtig: [PlayerId: Int]
        public var falsch: [PlayerId: Int]
        public var beantwortet: [PlayerId: Int]
        public var ergebnis: [Eintrag]
        public var gespielt: Int
        public var verbraucht: Int
        public var letzteFrage: String?
        public var letzteWahr: Bool?
        public var letzteErkl: String?
    }

    /// Stage widget payload (stage/extras-neu2.js, `f == "faktencheck"`).
    struct View: Codable {
        var f = "faktencheck"
        var phase: String
        var nummer: Int
        var gesamt: Int
        var wert: Int
        /// Full cost of a wrong fact (0,2 F) — before the "never below 0" cap.
        var strafe: Int
        /// The fact (mini-reveal: the one just resolved).
        var fakt: String?
        /// The truth — only after the fact closed.
        var wahr: Bool?
        var erkl: String?
        var serien: [String: Int]
        var besteSerie: [String: Int]
        /// Multiplier labels by streak length ("1×" … "3×").
        var stufen: [String]
        var ergebnis: [Eintrag]
        var totals: [String: Int]
        var answered: Int
        var gespielt: Int
    }

    private static let basis = Welle2.f(Welle2.Anteil.faktBasis)
    private static let serien = Welle2.Anteil.faktSerie.map(Welle2.f)
    private static let kosten = Welle2.f(Welle2.Anteil.faktFalsch)

    public static let meta = MinigameMeta(
        id: "faktencheck", name: "Faktencheck", emoji: "✅",
        kurz: "Wahr oder falsch? Eine schnelle Serie von Fakten — wer eine Serie hinlegt, kassiert immer mehr.",
        erklaerung: "Schlag auf Schlag kommen Behauptungen auf die Bühne, der Timer ist kurz. Wahr oder falsch? Jeder richtige Faktencheck bringt \(basis) Fragenwert — und deine Serie zählt: der zweite richtige in Folge ×\(serien[1].dropLast()), der dritte ×\(serien[2].dropLast()), ab dem vierten ×\(serien[3].dropLast()). Ein falscher Check kostet \(kosten) Fragenwert (nie unter 0) und die Serie reißt. Keine Antwort kostet nichts, aber die Serie ist weg.",
        regeln: ["Behauptung auf der Bühne: WAHR oder FALSCH?",
                 "Kurzer Timer — Schlag auf Schlag",
                 "Richtig: \(basis) Fragenwert × deine Serie",
                 "Serie: 2. richtig in Folge ×\(serien[1].dropLast()) · 3. ×\(serien[2].dropLast()) · ab dem 4. ×\(serien[3].dropLast())",
                 "Falsch: −\(kosten) Fragenwert (nie unter 0), Serie weg · keine Antwort: Serie weg, kein Abzug"],
        gewinn: "Richtig \(basis) Fragenwert × Serie (\(serien.joined(separator: " → "))) · falsch −\(kosten)",
        minPlayers: 2, maxPlayers: 12,
        contentKind: .fragen([.wahrFalsch]), roundBased: true, streak: false, jokerAktionen: [], isMc: true, musik: "bomb_pass", v2: true
    )

    /// Streak multiplier for the `serie`-th right fact in a row (1-based, capped).
    public static func faktor(serie: Int) -> Double {
        let a = Welle2.Anteil.faktSerie
        return a[min(max(1, serie), a.count) - 1]
    }

    /// Win of a right fact that makes the streak `serie` long.
    public static func gewinn(wert: Int, serie: Int) -> Int {
        NeueFormate.betrag(wert, Welle2.Anteil.faktBasis * faktor(serie: serie))
    }

    /// Cost of a wrong fact: 0,2 F, but never more than the player still has
    /// (`guthaben` = balance at round start + the round's result so far).
    public static func strafe(wert: Int, guthaben: Int) -> Int {
        min(NeueFormate.betrag(wert, Welle2.Anteil.faktFalsch), max(0, guthaben))
    }

    // MARK: Flow

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        var qs = questions.filter { $0.typ == .wahrFalsch && $0.korrektBool != nil }
        if qs.isEmpty { qs = questions.filter { $0.typ.isChoiceLike && $0.choiceOptions.count >= 2 && $0.correctIndex != nil } }
        if qs.isEmpty { qs = [Question.fallback(0)] }
        var s = State(questions: qs, gesamt: NeueFormate.schritte(ctx, verfuegbar: qs.count), index: 0, core: nil, wert: 0, phase: "frage",
                      revealUntil: nil, serie: [:], besteSerie: [:], punkte: [:], gewinn: [:], kosten: [:], richtig: [:], falsch: [:],
                      beantwortet: [:], ergebnis: [], gespielt: 0, verbraucht: 0, letzteFrage: nil, letzteWahr: nil, letzteErkl: nil)
        start(&s, index: 0, ctx: ctx)
        return s
    }

    static func start(_ s: inout State, index: Int, ctx: MinigameContext) {
        let q = s.questions[index % s.questions.count]
        s.index = index
        s.core = ChoiceCore(question: q, ctx: NeueFormate.frageKontext(ctx, nummer: index + 1, gesamt: s.gesamt), timerMs: Welle2.blitzTimer(Welle2.faktTimerMs, ctx: ctx))
        s.wert = NeueFormate.wert(q.schw, ctx: ctx)
        s.phase = "frage"
        s.revealUntil = nil
        s.verbraucht = max(s.verbraucht, index + 1)
    }

    static func resolve(_ s: inout State, ctx: MinigameContext) {
        guard let core = s.core else { return }
        var lines: [Eintrag] = []
        for p in ctx.players {
            guard core.hasAnswered(p), let ok = core.isCorrect(p) else {
                // No answer: the streak is gone, nothing is charged.
                s.serie[p] = 0
                lines.append(Eintrag(player: p, correct: nil, points: 0, serie: 0, ms: nil))
                continue
            }
            s.beantwortet[p, default: 0] += 1
            if ok {
                let n = (s.serie[p] ?? 0) + 1
                s.serie[p] = n
                s.besteSerie[p] = max(s.besteSerie[p] ?? 0, n)
                let pts = gewinn(wert: s.wert, serie: n)
                s.punkte[p, default: 0] += pts
                s.gewinn[p, default: 0] += pts
                s.richtig[p, default: 0] += 1
                lines.append(Eintrag(player: p, correct: true, points: pts, serie: n, ms: core.answeredAfterMs(p)))
            } else {
                s.serie[p] = 0
                let cost = strafe(wert: s.wert, guthaben: (ctx.balances[p] ?? 0) + (s.punkte[p] ?? 0))
                s.punkte[p, default: 0] -= cost
                s.kosten[p, default: 0] += cost
                s.falsch[p, default: 0] += 1
                lines.append(Eintrag(player: p, correct: false, points: -cost, serie: 0, ms: core.answeredAfterMs(p)))
            }
        }
        s.ergebnis = lines
        s.gespielt += 1
        s.letzteFrage = core.question.displayText
        s.letzteWahr = core.question.typ == .wahrFalsch ? core.question.korrektBool : nil
        s.letzteErkl = core.question.erkl.isEmpty ? nil : core.question.erkl
        if s.letzteWahr == nil { s.letzteWahr = core.correctIndex == 0 }
    }

    static func weiter(_ s: inout State, ctx: MinigameContext) {
        if s.index + 1 < s.gesamt { start(&s, index: s.index + 1, ctx: ctx) } else { s.phase = "fertig"; s.revealUntil = nil }
    }

    static func frageFertig(_ s: State, ctx: MinigameContext) -> Bool {
        guard let core = s.core else { return true }
        if core.finishedAt != nil || ctx.now > core.deadline + ChoiceCore.graceMs { return true }
        return NeueFormate.alleDrin(NeueFormate.aktive(ctx: ctx)) { core.hasAnswered($0) }
    }

    /// "wahr"/"falsch" labels (binary / vote / button clients) map onto the two options.
    static func index(_ label: String) -> Int? {
        let l = label.lowercased()
        if l.contains("wahr") || l.contains("✅") || l == "true" { return 0 }
        if l.contains("falsch") || l.contains("❌") || l == "false" { return 1 }
        return nil
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        guard state.phase == "frage", var core = state.core else { return }
        let i: Int
        switch action {
        case .choose(let x): i = x
        case .binary(let l), .vote(let l), .button(let l):
            guard let x = index(l) else { return }
            i = x
        default: return
        }
        if core.answer(player, index: i, now: ctx.now) { state.core = core }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        switch action {
        case .timerExtend(let ms):
            if state.phase == "frage" { state.core?.extend(ms: ms) }
        case .timerShift(let ms):
            state.core?.shift(ms: ms)
            if let r = state.revealUntil { state.revealUntil = r + ms }
        case .forceFinish:
            if state.phase == "frage", let core = state.core, !core.answers.isEmpty { resolve(&state, ctx: ctx) }
            state.phase = "fertig"
            state.revealUntil = nil
        case .skipQuestion:
            // Annul the running fact (nothing booked, streaks stay) or cut the stamp short.
            if state.phase != "fertig" { weiter(&state, ctx: ctx) }
        default:
            // Two options only: no strike tools.
            break
        }
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {
        switch state.phase {
        case "frage":
            if frageFertig(state, ctx: ctx) {
                resolve(&state, ctx: ctx)
                state.phase = "mini"
                state.revealUntil = ctx.now + ctx.ms(Welle2.Reveal.fakt)
            }
        case "mini":
            if let r = state.revealUntil, ctx.now >= r { weiter(&state, ctx: ctx) }
        default:
            break
        }
    }

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.phase == "fertig" }

    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] {
        var s: [PlayerId: Int] = [:]
        for p in ctx.players { s[p] = state.punkte[p] ?? 0 }
        return s
    }

    static func detail(_ s: State, _ p: PlayerId) -> String {
        var parts = ["\(s.richtig[p] ?? 0)/\(s.gespielt) Fakten richtig"]
        if let b = s.besteSerie[p], b >= 2 { parts.append("beste Serie \(b)") }
        if let c = s.kosten[p], c > 0 { parts.append("Abzug −\(Money.formatNumber(c))") }
        return parts.joined(separator: " · ")
    }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        var out: [PlayerId: Outcome] = [:]
        for p in ctx.players {
            let pts = state.punkte[p] ?? 0
            let answered = (state.beantwortet[p] ?? 0) > 0
            out[p] = Outcome(correct: pts > 0 ? true : (answered ? false : nil), countsForStreak: false, detail: detail(state, p))
        }
        return out
    }

    static func view(_ s: State, phase: String, ctx: MinigameContext) -> View {
        let open = phase != "frage"
        let answered = phase == "frage" ? (s.core.map { c in ctx.players.filter { c.hasAnswered($0) }.count } ?? 0) : 0
        return View(phase: phase, nummer: s.index + 1, gesamt: s.gesamt, wert: gewinn(wert: s.wert, serie: 1),
                    strafe: NeueFormate.betrag(s.wert, Welle2.Anteil.faktFalsch),
                    fakt: open ? s.letzteFrage : s.core?.question.displayText, wahr: open && phase == "mini" ? s.letzteWahr : nil,
                    erkl: phase == "mini" ? s.letzteErkl : nil, serien: Welle2.map(s.serie, ctx.players), besteSerie: Welle2.map(s.besteSerie, ctx.players),
                    stufen: serien, ergebnis: phase == "mini" ? s.ergebnis : [], totals: Welle2.map(s.punkte, ctx.players),
                    answered: answered, gespielt: s.gespielt)
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        let phase = revealed ? "fertig" : state.phase
        let extra = Welle2.karte("✅ Faktencheck", view(state, phase: phase, ctx: ctx))
        if phase == "frage", let core = state.core {
            var wall = core.wall(ctx: NeueFormate.frageKontext(ctx, nummer: state.index + 1, gesamt: state.gesamt), revealed: false)
            wall.wert = gewinn(wert: state.wert, serie: 1)
            return MinigameStageOutput(wall: wall, extra: extra, title: meta.name, audio: AudioCue(music: meta.musik))
        }
        let title = phase == "mini" ? "✅ Fakt \(state.index + 1) von \(state.gesamt)" : "✅ Faktencheck"
        return MinigameStageOutput(wall: nil, extra: extra, title: title, audio: AudioCue(music: meta.musik))
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed {
            let pts = state.punkte[player] ?? 0
            let best = state.besteSerie[player] ?? 0
            let title = pts > 0 ? (best >= Welle2.Anteil.faktSerie.count ? "✅ FAKTEN-PROFI!" : "✅ Gut gecheckt!") : ((state.beantwortet[player] ?? 0) > 0 ? "Fake News erwischt dich" : "Keine Antwort")
            return .reveal(title: title, correct: outcomes(state, ctx: ctx)[player]?.correct ?? nil, delta: pts, detail: detail(state, player), streak: 0, speedBonus: nil)
        }
        switch state.phase {
        case "frage":
            guard let core = state.core else { return .idle(title: "✅ Gleich kommt der nächste Fakt …", subtitle: nil) }
            let n = state.serie[player] ?? 0
            let next = gewinn(wert: state.wert, serie: n + 1)
            let serie = n >= 1 ? "🔥 Serie \(n) — richtig = +\(Money.format(next)) (×\(serien[min(n, serien.count - 1)].dropLast()))" : "Richtig = +\(Money.format(next))"
            let cost = strafe(wert: state.wert, guthaben: (ctx.balances[player] ?? 0) + (state.punkte[player] ?? 0))
            let hint = "✅ Fakt \(state.index + 1)/\(state.gesamt) · \(serie)" + (cost > 0 ? " · falsch −\(Money.formatNumber(cost))" : "")
            return core.prompt(for: player, ctx: NeueFormate.frageKontext(ctx, nummer: state.index + 1, gesamt: state.gesamt), revealed: false, hint: hint)
        case "mini":
            let wahr = state.letzteWahr.map { $0 ? "Das war WAHR" : "Das war FALSCH" }
            let bisher = "Runde bisher: \(Money.formatDelta(state.punkte[player] ?? 0))"
            guard let e = state.ergebnis.first(where: { $0.player == player }), let ok = e.correct else {
                return .reveal(title: "⏰ Zu langsam — Serie weg", correct: nil, delta: 0, detail: [wahr, bisher].compactMap { $0 }.joined(separator: " · "), streak: 0, speedBonus: nil)
            }
            if ok {
                let flame = e.serie >= 2 ? " · 🔥 \(e.serie)er-Serie ×\(Welle2.f(faktor(serie: e.serie)).dropLast())" : ""
                return .reveal(title: "✅ Richtig gecheckt!", correct: true, delta: e.points, detail: [wahr, bisher].compactMap { $0 }.joined(separator: " · ") + flame, streak: 0, speedBonus: nil)
            }
            return .reveal(title: "❌ Falsch — Serie gerissen", correct: false, delta: e.points, detail: [wahr, bisher].compactMap { $0 }.joined(separator: " · "), streak: 0, speedBonus: nil)
        default:
            return .idle(title: "✅ Auswertung …", subtitle: "Gleich kommt das Rundenergebnis")
        }
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        if state.phase == "fertig" {
            var answers: [PlayerId: String] = [:]
            for p in ctx.players { answers[p] = "\(detail(state, p)) · \(Money.formatDelta(state.punkte[p] ?? 0))" }
            return (NeueFormate.gmRunde("faktencheck-runde", "✅ Faktencheck — \(state.gespielt) Fakten geprüft", ctx: ctx, typ: .wahrFalsch), answers)
        }
        guard let core = state.core else { return (nil, [:]) }
        var g = core.gmInfo(ctx: ctx)
        for (p, a) in g.answers { g.answers[p] = "🔥\(state.serie[p] ?? 0) · " + a }
        if state.phase == "mini" {
            for e in state.ergebnis where e.points != 0 { g.answers[e.player] = "\(Money.formatDelta(e.points)) · " + (g.answers[e.player] ?? "") }
        }
        return g
    }

    public static func questionsUsed(_ state: State) -> Int { max(1, state.verbraucht) }
}
