import Foundation

/// 🪜 Tipp-Treppe — choice questions with three hints. The question starts WITHOUT
/// a hint; every ~4 s (tempo-scaled: a quarter of the question clock) the next hint
/// opens on the stage. Everybody may lock in at any step — the earlier, the more a
/// right answer pays: before any hint 2 F, after hint 1 1,4 F, after hint 2 0,9 F,
/// after hint 3 0,5 F (`Welle2.Anteil.treppe`). Wrong or no answer: 0.
/// Questions without three written tips get generated hints (strike a wrong option,
/// then the first letter), so the staircase always has three steps.
public enum TippTreppe: MinigamePlugin {
    /// One player's line of a resolved question.
    public struct Eintrag: Codable, Equatable, Sendable {
        public var player: PlayerId
        /// Hint step the answer was locked at (0 = no hint yet; nil = no answer).
        public var stufe: Int?
        public var correct: Bool?
        public var points: Int
        public var ms: Int?
    }

    public struct State: Codable, Equatable, Sendable {
        public var questions: [Question]
        public var gesamt: Int
        public var index: Int
        public var core: ChoiceCore?
        /// F × value modifiers of the running question.
        public var wert: Int
        /// "frage" | "mini" | "fertig"
        public var phase: String
        public var revealUntil: Millis?
        /// Interval between two hints of the running question.
        public var stufeMs: Int
        /// The three hints of the running question (bank tips first, generated ones fill up).
        public var tipps: [String]
        /// Option a generated hint strikes when it opens (nil = a text hint).
        public var streichen: [Int?]
        /// Hints open on the wall (0…3) — advanced by `tick`, so stage and phones agree.
        public var offen: Int
        /// Step each player locked in at (= the hints they had seen).
        public var stufeBei: [PlayerId: Int]
        /// Lines of the last resolved question (mini-reveal).
        public var ergebnis: [Eintrag]
        public var punkte: [PlayerId: Int]
        public var richtig: [PlayerId: Int]
        public var beantwortet: [PlayerId: Int]
        /// Right answers without any hint.
        public var ohneTipp: [PlayerId: Int]
        public var gespielt: Int
        public var verbraucht: Int
        public var letzteFrage: String?
        public var letzteRichtig: String?
        public var letzteTipps: [String]
    }

    /// Stage widget payload (stage/extras-neu2.js, `f == "tipp-treppe"`).
    struct View: Codable {
        var f = "tipp-treppe"
        var phase: String
        var nummer: Int
        var gesamt: Int
        /// Hints open (0…3).
        var stufe: Int
        /// MM a right answer pays per step (0…3) for this question.
        var werte: [Int]
        var faktoren: [String]
        /// Hints to show (open ones while asking, all three in the mini-reveal).
        var tipps: [String]
        /// When the next hint opens (only while asking and a step is left).
        var naechsteAt: Millis?
        var stufeMs: Int
        /// Who locked in at which step (no right/wrong while asking).
        var locked: [String: Int]
        var ergebnis: [Eintrag]
        var frage: String?
        var richtig: String?
        var totals: [String: Int]
        var ohneTipp: [String: Int]
        var richtige: [String: Int]
        var answered: Int
        var gespielt: Int
    }

    static let stufen = 3
    private static let k = Welle2.Anteil.treppe.map(Welle2.f)

    public static let meta = MinigameMeta(
        id: "tipp-treppe", name: "Tipp-Treppe", emoji: "🪜",
        kurz: "Die Frage startet ohne Tipp — alle paar Sekunden kommt der nächste. Wer früh richtig liegt, kassiert mehr.",
        erklaerung: "Jede Frage beginnt OHNE Hinweis. Alle paar Sekunden erscheint auf der Bühne der nächste von drei Tipps — und mit jedem Tipp rutscht der Wert eine Stufe die Treppe hinunter. Du darfst jederzeit einloggen: richtig vor dem ersten Tipp bringt \(k[0]) Fragenwert, mit einem Tipp \(k[1]), mit zwei Tipps \(k[2]), mit allen drei nur noch \(k[3]). Falsch bringt nichts, kostet aber auch nichts.",
        regeln: ["Jede Frage startet OHNE Tipp",
                 "Alle paar Sekunden kommt der nächste von 3 Tipps",
                 "Einloggen geht jederzeit — früher = mehr Geld",
                 "Richtig ohne Tipp: \(k[0]) · mit 1 Tipp: \(k[1]) · mit 2 Tipps: \(k[2]) · mit 3 Tipps: \(k[3]) Fragenwert",
                 "Falsch oder keine Antwort: 0 — kein Abzug"],
        gewinn: "Richtig ohne Tipp: \(k[0]) · mit 1 Tipp: \(k[1]) · mit 2 Tipps: \(k[2]) · mit 3 Tipps: \(k[3]) Fragenwert",
        minPlayers: 2, maxPlayers: 12,
        contentKind: .fragen([.choice, .emoji]), roundBased: true, streak: false, jokerAktionen: [], isMc: true, musik: "estimate_think", v2: true
    )

    /// MM a right answer locked at `stufe` pays.
    public static func punkte(wert: Int, stufe: Int) -> Int {
        let a = Welle2.Anteil.treppe
        return NeueFormate.betrag(wert, a[min(max(0, stufe), a.count - 1)])
    }

    /// Question clock and hint interval: 4 intervals of ~4 s (tempo, fixed time per question —
    /// never shorter —, wheel factor). Timer off: hints keep coming every ~4 s, the question
    /// waits until everybody locked in.
    static func uhr(_ ctx: MinigameContext) -> (timer: Int, stufe: Int) {
        if ctx.timerAus {
            return (MinigameContext.unlimitedMs, max(1500, Int(Double(ctx.ms(Welle2.treppeStufeMs)) * ctx.mods.timerFaktor)))
        }
        let t = NeueFormate.fenster(Welle2.treppeStufeMs * (stufen + 1), ctx: ctx)
        return (t, max(750, t / (stufen + 1)))
    }

    /// The three hints of a question: its own tips first; missing ones strike a wrong
    /// option (while more than two stay open), the last resort names the first letter / length.
    public static func hinweise(_ q: Question, options: [String], correct: Int, rng: inout SeededRandom) -> (texte: [String], streichen: [Int?]) {
        var texte: [String] = []
        var streichen: [Int?] = []
        for t in q.tipps where texte.count < stufen && !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            texte.append(t)
            streichen.append(nil)
        }
        guard texte.count < stufen else { return (texte, streichen) }
        var wrong = rng.shuffled(options.indices.filter { $0 != correct })
        var open = options.count
        let answer = options.indices.contains(correct) ? options[correct] : ""
        var letter = false
        while texte.count < stufen {
            if open > 2, !wrong.isEmpty {
                let w = wrong.removeFirst()
                open -= 1
                texte.append("🚫 »\(options[w])« ist es nicht")
                streichen.append(w)
            } else if !letter, let c = answer.first {
                letter = true
                texte.append("🔤 Die Antwort beginnt mit »\(String(c).uppercased())«")
                streichen.append(nil)
            } else {
                texte.append("📏 Die Antwort hat \(answer.count) Zeichen")
                streichen.append(nil)
            }
        }
        return (texte, streichen)
    }

    // MARK: Flow

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        var qs = questions.filter { $0.typ.isChoiceLike && $0.choiceOptions.count >= 2 && $0.correctIndex != nil }
        // Questions with three written tips first (stable: draw order within each group).
        qs = qs.filter { $0.tipps.count >= stufen } + qs.filter { $0.tipps.count < stufen }
        if qs.isEmpty { qs = [Question.fallback(0)] }
        var s = State(questions: qs, gesamt: NeueFormate.schritte(ctx, verfuegbar: qs.count), index: 0, core: nil, wert: 0, phase: "frage",
                      revealUntil: nil, stufeMs: Welle2.treppeStufeMs, tipps: [], streichen: [], offen: 0, stufeBei: [:], ergebnis: [],
                      punkte: [:], richtig: [:], beantwortet: [:], ohneTipp: [:], gespielt: 0, verbraucht: 0,
                      letzteFrage: nil, letzteRichtig: nil, letzteTipps: [])
        start(&s, index: 0, ctx: &ctx)
        return s
    }

    static func start(_ s: inout State, index: Int, ctx: inout MinigameContext) {
        let q = s.questions[index % s.questions.count]
        let u = uhr(ctx)
        let core = ChoiceCore(question: q, ctx: NeueFormate.frageKontext(ctx, nummer: index + 1, gesamt: s.gesamt), timerMs: u.timer)
        let h = hinweise(q, options: core.options, correct: core.correctIndex, rng: &ctx.rng)
        s.index = index
        s.core = core
        s.wert = NeueFormate.wert(q.schw, ctx: ctx)
        s.stufeMs = u.stufe
        s.tipps = h.texte
        s.streichen = h.streichen
        s.offen = 0
        s.stufeBei = [:]
        s.phase = "frage"
        s.revealUntil = nil
        s.verbraucht = max(s.verbraucht, index + 1)
    }

    /// Hint steps that should be open at `now` (0…3).
    static func sollStufe(_ s: State, now: Millis) -> Int {
        guard let core = s.core else { return stufen }
        return min(stufen, max(0, (now - core.startedAt) / max(1, s.stufeMs)))
    }

    /// Open the hints that are due; a generated strike hint removes its option for everybody.
    static func oeffne(_ s: inout State, bis soll: Int) {
        guard var core = s.core else { return }
        while s.offen < min(soll, stufen) {
            s.offen += 1
            let i = s.offen - 1
            if s.streichen.indices.contains(i), let w = s.streichen[i], !core.globalRemoved.contains(w),
               core.options.indices.filter({ !core.globalRemoved.contains($0) }).count > 2 {
                core.globalRemoved.append(w)
            }
        }
        s.core = core
    }

    static func resolve(_ s: inout State, ctx: MinigameContext) {
        guard let core = s.core else { return }
        var lines: [Eintrag] = []
        for p in ctx.players {
            guard let ok = core.isCorrect(p), core.hasAnswered(p) else {
                lines.append(Eintrag(player: p, stufe: nil, correct: nil, points: 0, ms: nil))
                continue
            }
            let st = min(stufen, max(0, s.stufeBei[p] ?? s.offen))
            s.beantwortet[p, default: 0] += 1
            var pts = 0
            if ok {
                pts = punkte(wert: s.wert, stufe: st)
                s.punkte[p, default: 0] += pts
                s.richtig[p, default: 0] += 1
                if st == 0 { s.ohneTipp[p, default: 0] += 1 }
            }
            lines.append(Eintrag(player: p, stufe: st, correct: ok, points: pts, ms: core.answeredAfterMs(p)))
        }
        s.ergebnis = lines
        s.gespielt += 1
        s.letzteFrage = core.question.displayText
        s.letzteRichtig = core.options.indices.contains(core.correctIndex) ? core.options[core.correctIndex] : nil
        s.letzteTipps = s.tipps
    }

    static func weiter(_ s: inout State, ctx: inout MinigameContext) {
        if s.index + 1 < s.gesamt { start(&s, index: s.index + 1, ctx: &ctx) } else { s.phase = "fertig"; s.revealUntil = nil }
    }

    static func frageFertig(_ s: State, ctx: MinigameContext) -> Bool {
        guard let core = s.core else { return true }
        if core.finishedAt != nil || ctx.now > core.deadline + ChoiceCore.graceMs { return true }
        return NeueFormate.alleDrin(NeueFormate.aktive(ctx: ctx)) { core.hasAnswered($0) }
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        guard state.phase == "frage", case .choose(let i) = action, var core = state.core else { return }
        if core.answer(player, index: i, now: ctx.now) {
            state.core = core
            state.stufeBei[player] = state.offen
        }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        switch action {
        case .timerExtend(let ms):
            if state.phase == "frage" { state.core?.extend(ms: ms) }
        case .timerShift(let ms):
            // Pause / clock shift: the hint schedule hangs on the question start and moves along.
            state.core?.shift(ms: ms)
            if let r = state.revealUntil { state.revealUntil = r + ms }
        case .forceFinish:
            if state.phase == "frage", let core = state.core, !core.answers.isEmpty { resolve(&state, ctx: ctx) }
            state.phase = "fertig"
            state.revealUntil = nil
        case .skipQuestion:
            if state.phase != "fertig" { weiter(&state, ctx: &ctx) }
        case .removeOption(let p):
            guard state.phase == "frage", var core = state.core else { return }
            if let p = p {
                core.applyGm(.removeOption(player: p), ctx: &ctx)
            } else if core.options.indices.filter({ !core.globalRemoved.contains($0) }).count > 2 {
                // Tipp-Kanone: strike one wrong option for everybody (the staircase keeps its own hints).
                core.removeWrong(for: nil, count: 1, rng: &ctx.rng)
            }
            state.core = core
        default:
            break
        }
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {
        switch state.phase {
        case "frage":
            oeffne(&state, bis: sollStufe(state, now: ctx.now))
            if frageFertig(state, ctx: ctx) {
                resolve(&state, ctx: ctx)
                state.phase = "mini"
                state.revealUntil = ctx.now + ctx.ms(Welle2.Reveal.treppe)
            }
        case "mini":
            if let r = state.revealUntil, ctx.now >= r { weiter(&state, ctx: &ctx) }
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
        var parts = ["\(s.richtig[p] ?? 0)/\(s.gespielt) richtig"]
        if let n = s.ohneTipp[p], n > 0 { parts.append("\(n)× ohne Tipp") }
        return parts.joined(separator: " · ")
    }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        var out: [PlayerId: Outcome] = [:]
        for p in ctx.players {
            let pts = state.punkte[p] ?? 0
            out[p] = Outcome(correct: pts > 0 ? true : ((state.beantwortet[p] ?? 0) > 0 ? false : nil), countsForStreak: false, detail: detail(state, p))
        }
        return out
    }

    static func view(_ s: State, phase: String, ctx: MinigameContext) -> View {
        let asking = phase == "frage"
        let offen = asking ? s.offen : stufen
        var locked: [String: Int] = [:]
        if asking, let core = s.core { for p in ctx.players where core.hasAnswered(p) { locked[p] = s.stufeBei[p] ?? s.offen } }
        let next: Millis? = asking && s.offen < stufen ? s.core.map { $0.startedAt + (s.offen + 1) * s.stufeMs } : nil
        return View(phase: phase, nummer: s.index + 1, gesamt: s.gesamt, stufe: offen,
                    werte: (0...stufen).map { punkte(wert: s.wert, stufe: $0) }, faktoren: k,
                    tipps: asking ? Array(s.tipps.prefix(s.offen)) : (phase == "mini" ? s.letzteTipps : []),
                    naechsteAt: next, stufeMs: s.stufeMs, locked: locked, ergebnis: phase == "mini" ? s.ergebnis : [],
                    frage: phase == "mini" ? s.letzteFrage : nil, richtig: phase == "mini" ? s.letzteRichtig : nil,
                    totals: Welle2.map(s.punkte, ctx.players), ohneTipp: Welle2.map(s.ohneTipp, ctx.players),
                    richtige: Welle2.map(s.richtig, ctx.players), answered: locked.count, gespielt: s.gespielt)
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        let phase = revealed ? "fertig" : state.phase
        let extra = Welle2.karte("🪜 Tipp-Treppe", view(state, phase: phase, ctx: ctx))
        if phase == "frage", let core = state.core {
            var wall = core.wall(ctx: NeueFormate.frageKontext(ctx, nummer: state.index + 1, gesamt: state.gesamt), revealed: false)
            // The value drops with every hint; the hints themselves stand on the staircase next to the card.
            wall.wert = punkte(wert: state.wert, stufe: state.offen)
            wall.tipp = nil
            return MinigameStageOutput(wall: wall, extra: extra, title: meta.name, audio: AudioCue(music: meta.musik))
        }
        let title = phase == "mini" ? "🪜 Frage \(state.index + 1) von \(state.gesamt)" : "🪜 Tipp-Treppe"
        return MinigameStageOutput(wall: nil, extra: extra, title: title, audio: AudioCue(music: meta.musik))
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed {
            let pts = state.punkte[player] ?? 0
            let title = pts == 0 ? ((state.beantwortet[player] ?? 0) > 0 ? "Die Treppe runtergefallen" : "Keine Antwort") : ((state.ohneTipp[player] ?? 0) > 0 ? "🪜 Ganz oben auf der Treppe!" : "🪜 Gut geklettert!")
            return .reveal(title: title, correct: outcomes(state, ctx: ctx)[player]?.correct ?? nil, delta: pts, detail: detail(state, player), streak: 0, speedBonus: nil)
        }
        switch state.phase {
        case "frage":
            guard let core = state.core else { return .idle(title: "🪜 Gleich geht's weiter …", subtitle: nil) }
            var parts: [String] = []
            if let st = state.stufeBei[player], core.hasAnswered(player) {
                parts.append("🔒 Eingeloggt auf Stufe \(st) — richtig = +\(Money.format(punkte(wert: state.wert, stufe: st)))")
            } else {
                let jetzt = "🪜 Jetzt richtig: +\(Money.format(punkte(wert: state.wert, stufe: state.offen))) (\(k[state.offen]))"
                parts.append(state.offen < stufen ? jetzt + ", nach dem nächsten Tipp nur \(k[state.offen + 1])" : jetzt + " — letzte Stufe")
            }
            for (i, t) in state.tipps.prefix(state.offen).enumerated() { parts.append("Tipp \(i + 1): \(t)") }
            return core.prompt(for: player, ctx: NeueFormate.frageKontext(ctx, nummer: state.index + 1, gesamt: state.gesamt), revealed: false,
                               hint: parts.joined(separator: " · "))
        case "mini":
            let bisher = "Runde bisher: \(Money.formatDelta(state.punkte[player] ?? 0))"
            let loesung = state.letzteRichtig.map { "Richtig: \($0)" }
            guard let e = state.ergebnis.first(where: { $0.player == player }), let st = e.stufe else {
                return .reveal(title: "⏰ Nicht eingeloggt", correct: nil, delta: 0, detail: [loesung, bisher].compactMap { $0 }.joined(separator: " · "), streak: 0, speedBonus: nil)
            }
            if e.correct == true {
                let wo = st == 0 ? "ohne Tipp" : "nach Tipp \(st)"
                return .reveal(title: "✅ Richtig \(wo) — \(k[st])", correct: true, delta: e.points, detail: bisher, streak: 0, speedBonus: nil)
            }
            return .reveal(title: "❌ Daneben", correct: false, delta: 0, detail: [loesung, bisher].compactMap { $0 }.joined(separator: " · "), streak: 0, speedBonus: nil)
        default:
            return .idle(title: "🪜 Auswertung …", subtitle: "Gleich kommt das Rundenergebnis")
        }
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        if state.phase == "fertig" {
            var answers: [PlayerId: String] = [:]
            for p in ctx.players { answers[p] = "\(detail(state, p)) · \(Money.formatDelta(state.punkte[p] ?? 0))" }
            return (NeueFormate.gmRunde("tipp-treppe-runde", "🪜 Tipp-Treppe — \(state.gespielt) Fragen gespielt", ctx: ctx), answers)
        }
        guard let core = state.core else { return (nil, [:]) }
        var g = core.gmInfo(ctx: ctx)
        for (p, a) in g.answers {
            let st = state.stufeBei[p] ?? state.offen
            g.answers[p] = "Stufe \(st) (\(k[min(st, stufen)])) · " + a
        }
        if state.phase == "mini" {
            for e in state.ergebnis where e.points > 0 { g.answers[e.player] = "+\(e.points) · " + (g.answers[e.player] ?? "") }
        }
        return g
    }

    public static func questionsUsed(_ state: State) -> Int { max(1, state.verbraucht) }
}
