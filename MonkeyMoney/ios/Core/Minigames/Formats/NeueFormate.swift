import Foundation

// MARK: - Neue Formate: shared plumbing
//
// Five round-based formats (Affenzahn, Der letzte Affe, Affenschaukel,
// Herdentrieb, Kokos-Kopf). Each runs several internal steps with a short
// mini-reveal in between and books once at the end of the round. They share
// the payout table (everything × F = question value), the answer clock rules
// (tempo, fixed time per question, timer off, wheel timer factor) and a few
// helpers. Decisions never depend on Dictionary/Set order: players are always
// walked in `ctx.players` order, randomness only comes from `ctx.rng`.

public enum NeueFormate {
    /// Payout multipliers relative to F (100 / 250 / 500 / 1.000) — the single
    /// place to tune the five formats. See `NeueFormateTests` for the balance gate.
    public enum Anteil {
        // ⚡ Affenzahn: speed podium per question.
        public static let affenzahn: [Double] = [2.0, 1.25, 0.75]
        public static let affenzahnRest = 0.5
        // 🪂 Der letzte Affe.
        public static let ueberlebt = 1.5
        public static let letzterBonus = 3.0
        public static let tippRichtig = 1.0
        // ↕️ Affenschaukel.
        public static let schaukel = 0.8
        public static let schaukelSerie2 = 1.5
        public static let schaukelSerie3 = 2.0
        // 🐑 Herdentrieb.
        public static let herde = 1.3
        public static let herdeGleichstand = 0.65
        // 🧠 Kokos-Kopf.
        public static let kokosPerfekt = 1.0
        public static let kokosPosition = 0.15
        public static let kokosSchnellster = 0.4
    }

    /// Mini-reveal lengths (base ms, scaled by tempo).
    enum Reveal {
        static let affenzahn = 2500
        static let letzterAffe = 3000
        static let schaukel = 3500
        static let herde = 3500
        static let kokos = 4000
    }

    /// k × F, rounded to tens (never below 10 MM for a positive share).
    public static func betrag(_ f: Int, _ k: Double) -> Int {
        guard k > 0, f > 0 else { return 0 }
        return max(10, Economy.roundTo10(Int((Double(f) * k).rounded())))
    }

    /// F of a difficulty with the round's value modifiers (Notariat +25 %, GM hint −25 %).
    static func wert(_ d: Difficulty, ctx: MinigameContext) -> Int {
        max(10, Economy.roundTo10(Int((Double(Money.value(d)) * ctx.mods.wertFaktor).rounded())))
    }

    /// F of the section (formats without questions, round bonuses): the section's top tier, default medium.
    static func sectionWert(ctx: MinigameContext) -> Int {
        wert(ctx.section.schwierigkeiten.max() ?? .medium, ctx: ctx)
    }

    /// How many steps a round plays: the section's question count (at least one).
    static func schritte(_ ctx: MinigameContext, verfuegbar: Int? = nil) -> Int {
        let wanted = max(1, ctx.section.fragen)
        guard let v = verfuegbar else { return wanted }
        return max(1, min(wanted, v))
    }

    /// Connected players among `ids` that are still in the room — in `ctx.players` order.
    static func aktive(_ ids: [PlayerId]? = nil, ctx: MinigameContext) -> [PlayerId] {
        let pool = ids.map { Set($0) }
        return ctx.players.filter { ctx.connected.contains($0) && (pool?.contains($0) ?? true) }
    }

    /// Everyone who can answer has answered (an empty table never counts as "all in" —
    /// then the clock or the Show-Master decides).
    static func alleDrin(_ active: [PlayerId], _ answered: (PlayerId) -> Bool) -> Bool {
        !active.isEmpty && active.allSatisfy(answered)
    }

    /// Answer window for inputs: tempo, fixed time per question (never shorter), timer off, wheel factor.
    static func fenster(_ base: Int, ctx: MinigameContext) -> Int {
        if ctx.timerAus { return MinigameContext.unlimitedMs }
        return max(3000, Int(Double(ctx.answerWindow(base)) * ctx.mods.timerFaktor))
    }

    /// Question context for an internal step (question number n/N on the wall, no insider head start).
    static func frageKontext(_ ctx: MinigameContext, nummer: Int, gesamt: Int) -> MinigameContext {
        var q = ctx
        q.fragenNummer = nummer
        q.fragenGesamt = gesamt
        q.mods.insiderId = nil
        return q
    }

    /// "0,8×" — multipliers the German way.
    public static func faktor(_ k: Double) -> String {
        let s = k == k.rounded() ? String(Int(k)) : String(format: "%.2f", k).replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
        return s.replacingOccurrences(of: ".", with: ",") + "×"
    }

    /// "1,2 s"
    static func sekunden(_ ms: Int) -> String {
        String(format: "%.1f", Double(ms) / 1000).replacingOccurrences(of: ".", with: ",") + " s"
    }

    /// Deterministic 32-bit FNV-1a hash (Swift's `hashValue` is randomised per process).
    static func fnv(_ s: String) -> UInt32 {
        var h: UInt32 = 2_166_136_261
        for b in s.utf8 { h = (h ^ UInt32(b)) &* 16_777_619 }
        return h
    }

    /// Players ordered by a score (desc), ties in `ctx.players` order.
    static func rangfolge(_ values: [PlayerId: Int], ctx: MinigameContext) -> [PlayerId] {
        let order = Dictionary(uniqueKeysWithValues: ctx.players.enumerated().map { ($0.element, $0.offset) })
        return ctx.players.sorted { a, b in
            let va = values[a] ?? 0, vb = values[b] ?? 0
            return va != vb ? va > vb : (order[a] ?? 0) < (order[b] ?? 0)
        }
    }

    /// The round summary line for the Show-Master cockpit (the reveal banner stays empty: "—").
    static func gmRunde(_ id: String, _ text: String, ctx: MinigameContext, typ: QuestionType = .choice) -> GmQuestionInfo {
        GmQuestionInfo(id: id, text: text, kategorie: "Rundenergebnis", schwierigkeit: ctx.section.schwierigkeiten.max() ?? .medium,
                       korrekt: "—", erklaerung: "", tipps: [], typ: typ)
    }
}

// MARK: - ⚡ Affenzahn

/// Affenzahn — "mit einem Affenzahn": a blitz round of short-timer choice
/// questions where only speed counts. Per question the fastest correct answer
/// gets 0.8 F, the second 0.5 F, the third 0.3 F, every other correct one
/// 0.1 F. A 2.5-s speed podium follows every question.
public enum Affenzahn: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var questions: [Question]
        public var gesamt: Int
        /// 0-based index of the question on the wall.
        public var index: Int
        public var core: ChoiceCore?
        /// F × value modifiers of the current question.
        public var wert: Int
        /// "frage" | "mini" | "fertig"
        public var phase: String
        public var revealUntil: Millis?
        /// Ranking of the last resolved question (for the podium).
        public var ranking: [SpeedEntry]
        public var punkte: [PlayerId: Int]
        public var richtig: [PlayerId: Int]
        public var beantwortet: [PlayerId: Int]
        public var siege: [PlayerId: Int]
        public var bestMs: [PlayerId: Int]
        /// Questions resolved (scored) / shown on the wall.
        public var gespielt: Int
        public var verbraucht: Int
        public var letzteFrage: String?
        public var letzteRichtig: String?
    }

    private static let z = NeueFormate.Anteil.affenzahn.map(NeueFormate.faktor)
    private static let zr = NeueFormate.faktor(NeueFormate.Anteil.affenzahnRest)

    public static let meta = MinigameMeta(
        id: "affenzahn", name: "Affenzahn", emoji: "⚡",
        kurz: "Blitzrunde mit Mini-Timer: nur Tempo zählt — wer am schnellsten richtig liegt, kassiert am meisten.",
        erklaerung: "Mit einem Affenzahn durch die Fragen! Blitzfragen mit ganz kurzem Timer, alle antworten gleichzeitig. Pro Frage zählt nur die Geschwindigkeit: der schnellste Richtige bekommt \(z[0]) Fragenwert, der zweite \(z[1]), der dritte \(z[2]), alle weiteren Richtigen \(zr). Falsch oder zu langsam bringt nichts, kostet aber auch nichts. Nach jeder Frage zeigt das Speed-Podium für einen Wimpernschlag die Top 3.",
        regeln: ["Blitzfragen mit Mini-Timer — alle antworten gleichzeitig",
                 "Nur Tempo zählt: der schnellste Richtige gewinnt am meisten",
                 "Nach jeder Frage: kurz das Speed-Podium mit den Top 3",
                 "Falsch oder zu langsam: 0 — aber kein Abzug"],
        gewinn: "Pro Frage: schnellster Richtiger \(z[0]) · 2. \(z[1]) · 3. \(z[2]) Fragenwert · jeder weitere Richtige \(zr)",
        contentKind: .choiceLike, roundBased: true, streak: false, jokerAktionen: [], isMc: true, musik: "bomb_pass", v2: true
    )

    static let timerBasisMs = 6000

    /// Blitz timer: 6 s × tempo × wheel factor; a fixed time per question from the
    /// Show-Master wins (their explicit choice); timer off = until everyone answered.
    static func timer(_ ctx: MinigameContext) -> Int {
        if ctx.timerAus { return MinigameContext.unlimitedMs }
        if let fixed = ctx.settings.fragenZeit { return max(3000, Int(Double(fixed * 1000) * ctx.mods.timerFaktor)) }
        return max(3000, Int(Double(ctx.ms(timerBasisMs)) * ctx.mods.timerFaktor))
    }

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        var qs = questions.filter { $0.typ.isChoiceLike && !$0.choiceOptions.isEmpty && $0.correctIndex != nil }
        if qs.isEmpty { qs = [Question.fallback(0)] }
        var s = State(questions: qs, gesamt: NeueFormate.schritte(ctx, verfuegbar: qs.count), index: 0, core: nil, wert: 0, phase: "frage",
                      revealUntil: nil, ranking: [], punkte: [:], richtig: [:], beantwortet: [:], siege: [:], bestMs: [:],
                      gespielt: 0, verbraucht: 0, letzteFrage: nil, letzteRichtig: nil)
        start(&s, index: 0, ctx: ctx)
        return s
    }

    static func start(_ s: inout State, index: Int, ctx: MinigameContext) {
        let q = s.questions[index % s.questions.count]
        s.index = index
        s.core = ChoiceCore(question: q, ctx: NeueFormate.frageKontext(ctx, nummer: index + 1, gesamt: s.gesamt), timerMs: timer(ctx))
        s.wert = NeueFormate.wert(q.schw, ctx: ctx)
        s.phase = "frage"
        s.revealUntil = nil
        s.verbraucht = max(s.verbraucht, index + 1)
    }

    /// The speed ranking of one question — pure, so the rules are testable on their own.
    /// Correct answers are ranked by time; equal times share the better place.
    public static func rangliste(_ antworten: [(player: PlayerId, ms: Int?, correct: Bool?)], wert: Int) -> [SpeedEntry] {
        let richtige = antworten.enumerated().filter { $0.element.correct == true }
            .sorted { a, b in (a.element.ms ?? Int.max, a.offset) < (b.element.ms ?? Int.max, b.offset) }
        var out: [SpeedEntry] = []
        for (_, a) in richtige {
            let ms = a.ms ?? Int.max
            let platz = 1 + richtige.filter { ($0.element.ms ?? Int.max) < ms }.count
            let k = platz <= NeueFormate.Anteil.affenzahn.count ? NeueFormate.Anteil.affenzahn[platz - 1] : NeueFormate.Anteil.affenzahnRest
            out.append(SpeedEntry(player: a.player, ms: a.ms, correct: true, points: NeueFormate.betrag(wert, k), platz: platz))
        }
        let falsche = antworten.filter { $0.correct == false }.sorted { ($0.ms ?? Int.max) < ($1.ms ?? Int.max) }
        out += falsche.map { SpeedEntry(player: $0.player, ms: $0.ms, correct: false, points: 0, platz: nil) }
        out += antworten.filter { $0.correct == nil }.map { SpeedEntry(player: $0.player, ms: nil, correct: nil, points: 0, platz: nil) }
        return out
    }

    static func resolve(_ s: inout State, ctx: MinigameContext) {
        guard let core = s.core else { return }
        let antworten = ctx.players.map { p in (player: p, ms: core.answeredAfterMs(p), correct: core.isCorrect(p)) }
        let r = rangliste(antworten, wert: s.wert)
        for e in r {
            if e.correct != nil { s.beantwortet[e.player, default: 0] += 1 }
            guard e.correct == true else { continue }
            s.punkte[e.player, default: 0] += e.points
            s.richtig[e.player, default: 0] += 1
            if e.platz == 1 { s.siege[e.player, default: 0] += 1 }
            if let ms = e.ms { s.bestMs[e.player] = min(s.bestMs[e.player] ?? Int.max, ms) }
        }
        s.ranking = r
        s.gespielt += 1
        s.letzteFrage = core.question.displayText
        s.letzteRichtig = core.options.indices.contains(core.correctIndex) ? core.options[core.correctIndex] : nil
    }

    static func weiter(_ s: inout State, ctx: MinigameContext) {
        if s.index + 1 < s.gesamt { start(&s, index: s.index + 1, ctx: ctx) } else { s.phase = "fertig"; s.revealUntil = nil }
    }

    static func frageFertig(_ s: State, ctx: MinigameContext) -> Bool {
        guard let core = s.core else { return true }
        if core.finishedAt != nil || ctx.now > core.deadline + ChoiceCore.graceMs { return true }
        return NeueFormate.alleDrin(NeueFormate.aktive(ctx: ctx)) { core.hasAnswered($0) }
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        guard state.phase == "frage", case .choose(let i) = action, var core = state.core else { return }
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
            // "Auflösen": the running question counts with the answers given so far.
            if state.phase == "frage", let core = state.core, !core.answers.isEmpty { resolve(&state, ctx: ctx) }
            state.phase = "fertig"
            state.revealUntil = nil
        case .skipQuestion:
            // Annul the running question (nothing booked) or cut the podium short.
            if state.phase != "fertig" { weiter(&state, ctx: ctx) }
        case .removeOption(let p):
            if state.phase == "frage" { state.core?.applyGm(.removeOption(player: p), ctx: &ctx) }
        default:
            break
        }
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {
        switch state.phase {
        case "frage":
            if frageFertig(state, ctx: ctx) {
                resolve(&state, ctx: ctx)
                state.phase = "mini"
                state.revealUntil = ctx.now + ctx.ms(NeueFormate.Reveal.affenzahn)
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

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        var out: [PlayerId: Outcome] = [:]
        for p in ctx.players {
            let pts = state.punkte[p] ?? 0
            let answered = state.beantwortet[p] ?? 0
            let correct: Bool? = pts > 0 ? true : (answered > 0 ? false : nil)
            out[p] = Outcome(correct: correct, answeredAfterMs: pts > 0 ? state.bestMs[p] : nil, timerMs: state.core?.timerMs, countsForStreak: false,
                             detail: detail(state, p))
        }
        return out
    }

    static func detail(_ s: State, _ p: PlayerId) -> String {
        var parts = ["\(s.richtig[p] ?? 0)/\(s.gespielt) richtig"]
        if let w = s.siege[p], w > 0 { parts.append("\(w)× Platz 1") }
        if let b = s.bestMs[p] { parts.append("schnellste Antwort \(NeueFormate.sekunden(b))") }
        return parts.joined(separator: " · ")
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        let phase = revealed ? "fertig" : state.phase
        let answered = state.core.map { c in ctx.players.filter { c.hasAnswered($0) }.count } ?? 0
        let showRanking = phase != "frage"
        let extra = StageExtra.speed(nummer: state.index + 1, gesamt: state.gesamt, phase: phase, answered: phase == "frage" ? answered : 0,
                                     wert: state.wert, frage: showRanking ? state.letzteFrage : nil, richtig: showRanking ? state.letzteRichtig : nil,
                                     ranking: showRanking ? state.ranking : [], totals: state.punkte, siege: state.siege, bestMs: state.bestMs)
        if phase == "frage", let core = state.core {
            let wall = core.wall(ctx: NeueFormate.frageKontext(ctx, nummer: state.index + 1, gesamt: state.gesamt), revealed: false)
            return MinigameStageOutput(wall: wall, extra: extra, title: meta.name, audio: AudioCue(music: meta.musik))
        }
        let title = phase == "mini" ? "⚡ Frage \(state.index + 1) von \(state.gesamt)" : "⚡ Affenzahn"
        return MinigameStageOutput(wall: nil, extra: extra, title: title, audio: AudioCue(music: meta.musik))
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed {
            let pts = state.punkte[player] ?? 0
            let w = state.siege[player] ?? 0
            let title = pts == 0 ? ((state.beantwortet[player] ?? 0) > 0 ? "Diesmal zu langsam" : "Keine Antwort") : (w > 0 ? "⚡ AFFENZAHN!" : "Flinke Pfoten!")
            let o = outcomes(state, ctx: ctx)[player]
            return .reveal(title: title, correct: o?.correct ?? nil, delta: pts, detail: detail(state, player), streak: 0, speedBonus: nil)
        }
        switch state.phase {
        case "frage":
            guard let core = state.core else { return .idle(title: "⚡ Gleich geht's weiter …", subtitle: nil) }
            return core.prompt(for: player, ctx: NeueFormate.frageKontext(ctx, nummer: state.index + 1, gesamt: state.gesamt), revealed: false,
                               hint: "⚡ Blitzfrage \(state.index + 1)/\(state.gesamt) — nur Tempo zählt!")
        case "mini":
            let e = state.ranking.first { $0.player == player }
            let bisher = "Runde bisher: \(Money.formatDelta(state.punkte[player] ?? 0))"
            let loesung = state.letzteRichtig.map { "Richtig: \($0)" }
            if let e = e, e.correct == true, let platz = e.platz {
                let k = platz <= NeueFormate.Anteil.affenzahn.count ? NeueFormate.Anteil.affenzahn[platz - 1] : NeueFormate.Anteil.affenzahnRest
                let time = e.ms.map { NeueFormate.sekunden($0) }
                return .reveal(title: "⚡ Platz \(platz) — +\(NeueFormate.faktor(k))", correct: true, delta: e.points,
                               detail: [time, bisher].compactMap { $0 }.joined(separator: " · "), streak: 0, speedBonus: nil)
            }
            if e?.correct == false {
                return .reveal(title: "❌ Daneben", correct: false, delta: 0, detail: [loesung, bisher].compactMap { $0 }.joined(separator: " · "), streak: 0, speedBonus: nil)
            }
            return .reveal(title: "⏰ Zu langsam", correct: nil, delta: 0, detail: [loesung, bisher].compactMap { $0 }.joined(separator: " · "), streak: 0, speedBonus: nil)
        default:
            return .idle(title: "⚡ Auswertung …", subtitle: "Gleich kommt das Rundenergebnis")
        }
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        if state.phase == "fertig" {
            var answers: [PlayerId: String] = [:]
            for p in ctx.players { answers[p] = "\(detail(state, p)) · \(Money.formatDelta(state.punkte[p] ?? 0))" }
            return (NeueFormate.gmRunde("affenzahn-runde", "⚡ Affenzahn — \(state.gespielt) Blitzfragen gespielt", ctx: ctx), answers)
        }
        guard let core = state.core else { return (nil, [:]) }
        var g = core.gmInfo(ctx: ctx)
        if state.phase == "mini" {
            for e in state.ranking where e.points > 0 { g.answers[e.player] = "Platz \(e.platz ?? 0) +\(e.points) · " + (g.answers[e.player] ?? "") }
        }
        return g
    }

    public static func questionsUsed(_ state: State) -> Int { max(1, state.verbraucht) }
}
