import Foundation

/// Affenschaukel — higher or lower? Estimate questions with an anchor value
/// X = true value × a random factor from [0.45, 0.8] ∪ [1.25, 2.2] (log-scale
/// questions: [0.2, 0.6] ∪ [1.6, 5], years: an offset in whole years), always
/// outside the question's tolerance zone and inside its input range. Right =
/// 0.4 F, in-round streak 2 in a row ×1.5, 3+ ×2.
public enum Affenschaukel: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var questions: [Question]
        public var gesamt: Int
        public var index: Int
        /// "frage" | "mini" | "fertig"
        public var phase: String
        public var startedAt: Millis
        public var deadline: Millis
        public var timerMs: Int
        public var finishedAt: Millis?
        public var revealUntil: Millis?
        public var anker: Double
        public var ankerText: String
        public var jahr: Bool
        /// Correct swing: "hoeher" | "tiefer".
        public var richtung: String
        public var wert: Int
        public var votes: [PlayerId: String]
        public var votedAt: [PlayerId: Millis]
        public var serie: [PlayerId: Int]
        public var besteSerie: [PlayerId: Int]
        public var punkte: [PlayerId: Int]
        public var richtig: [PlayerId: Int]
        public var beantwortet: [PlayerId: Int]
        /// Points of the last resolved question.
        public var lastPoints: [PlayerId: Int]
        public var gespielt: Int
        public var verbraucht: Int
    }

    public static let meta = MinigameMeta(
        id: "affenschaukel", name: "Affenschaukel", emoji: "↕️",
        kurz: "Höher oder tiefer? Schätzfragen mit Anker-Wert — schaukel in die richtige Richtung.",
        erklaerung: "Zu jeder Schätzfrage zeigt die Bühne einen Anker-Wert. Liegt die richtige Antwort HÖHER oder TIEFER? Tippe ⬆️ oder ⬇️ auf dem Handy. Richtig bringt 0,4× Fragenwert — und wer mehrmals in Folge richtig schaukelt, bekommt mehr: zwei in Folge ×1,5, ab drei ×2. Nach jeder Frage schaukelt die Wahrheit auf der Skala an ihren Platz.",
        regeln: ["Schätzfrage + Anker-Wert auf der Bühne",
                 "Liegt die Wahrheit HÖHER ⬆️ oder TIEFER ⬇️ als der Anker?",
                 "Richtig: 0,4× Fragenwert",
                 "Serie in der Runde: 2 in Folge ×1,5 · ab 3 in Folge ×2",
                 "Falsch oder keine Antwort: 0 und die Serie reißt"],
        gewinn: "Richtig 0,4× Fragenwert · 2er-Serie ×1,5 · ab 3er-Serie ×2",
        contentKind: .fragen([.schaetz]), roundBased: true, streak: false, jokerAktionen: [], isMc: false, musik: "estimate_think", v2: true
    )

    public static let hoeher = "⬆️ Höher"
    public static let tiefer = "⬇️ Tiefer"
    static let fensterMs = 10_000

    static let fallback = Question(id: "schaukel_fallback", kat: "kurioses_mixed", schw: .easy, typ: .schaetz,
                                   text: "Wie viele Tasten hat ein klassisches Klavier?", erkl: "52 weiße und 36 schwarze Tasten.",
                                   schaetz: EstimateSpec(richtwert: 88, einheit: "Tasten", toleranz: 5, min: 20, max: 200, skala: "linear"))

    static func spec(_ q: Question) -> EstimateSpec { q.schaetz ?? fallback.schaetz! }

    // MARK: Anchor

    /// Calendar-year question? (integral values around 1000–2100, "Jahr" in unit or text)
    public static func istJahr(_ spec: EstimateSpec, text: String = "") -> Bool {
        let integral = [spec.richtwert, spec.min, spec.max].allSatisfy { $0 == $0.rounded() }
        guard integral, (1000...2100).contains(spec.richtwert) else { return false }
        return spec.einheit == "Jahr" || text.lowercased().contains("jahr") || (spec.einheit.isEmpty && spec.min >= 1000)
    }

    /// Half width of the tolerance zone around the truth. The bank stores years as an
    /// absolute number (1–5), everything else as a percentage; small absolute values
    /// (e.g. "Minute 20 ± 1") are honoured as well — whichever is wider.
    public static func toleranz(_ spec: EstimateSpec, jahr: Bool) -> Double {
        let tol = max(0, spec.toleranz)
        if jahr { return max(1, min(5, tol)) }
        let r = abs(spec.richtwert)
        if r == 0 { return max(tol <= (spec.max - spec.min) * 0.2 ? tol : 0, (spec.max - spec.min) * 0.02) }
        let pct = r * min(tol, 60) / 100
        let absolut = tol < 0.5 * r ? tol : 0
        return max(pct, absolut)
    }

    /// The anchor X for a question — never inside the tolerance zone, inside [min, max]
    /// whenever the bands allow it, rounded nicely (years stay whole years).
    public static func anker(_ spec: EstimateSpec, text: String = "", rng: inout SeededRandom) -> Double {
        let r = spec.richtwert
        let jahr = istJahr(spec, text: text)
        let log = spec.skala == "log" && r > 0
        let ganz = [r, spec.min, spec.max].allSatisfy { $0 == $0.rounded() }
        let t = toleranz(spec, jahr: jahr)
        let zoneLo = r - t, zoneHi = r + t
        var bands: [(Double, Double)] = []
        if jahr {
            let span = max(1, spec.max - spec.min)
            let dMin = max(t + 1, 3, (span * 0.08).rounded())
            let dMax = max(dMin + 4, (span * 0.35).rounded())
            bands = [(r - dMax, r - dMin), (r + dMin, r + dMax)]
        } else if r == 0 {
            let span = max(1, spec.max - spec.min)
            let d0 = max(t * 1.2, span * 0.1), d1 = max(d0 * 2, span * 0.4)
            bands = [(r - d1, r - d0), (r + d0, r + d1)]
        } else {
            let (lo, hi) = log ? ((0.2, 0.6), (1.6, 5.0)) : ((0.45, 0.8), (1.25, 2.2))
            let a = (r * lo.0, r * lo.1), b = (r * hi.0, r * hi.1)
            bands = [(min(a.0, a.1), max(a.0, a.1)), (min(b.0, b.1), max(b.0, b.1))]
        }
        // Cut the zone out (bands never straddle the truth) and, if possible, stay in the input range.
        func clip(_ b: (Double, Double), bounded: Bool) -> (Double, Double)? {
            var lo = b.0, hi = b.1
            if bounded { lo = max(lo, spec.min); hi = min(hi, spec.max) }
            if b.1 <= r { hi = min(hi, zoneLo) } else { lo = max(lo, zoneHi) }
            return lo < hi ? (lo, hi) : nil
        }
        var bounded = true
        var cands = bands.compactMap { clip($0, bounded: true) }
        if cands.isEmpty { bounded = false; cands = bands.compactMap { clip($0, bounded: false) } }
        func valid(_ v: Double, below: Bool) -> Bool {
            guard v.isFinite, v < zoneLo || v > zoneHi else { return false }
            if below != (v < r) { return false }
            if bounded && (v < spec.min || v > spec.max) { return false }
            if log && v <= 0 { return false }
            return true
        }
        guard !cands.isEmpty else {
            let v = r + max(t * 1.5, abs(r) * 0.5, 1)
            return jahr || ganz ? v.rounded(.up) : v
        }
        let band = cands.count == 1 ? cands[0] : cands[rng.below(cands.count)]
        let below = band.1 <= r
        let u = rng.next()
        let raw = log && band.0 > 0 ? exp(Foundation.log(band.0) + u * (Foundation.log(band.1) - Foundation.log(band.0))) : band.0 + u * (band.1 - band.0)
        for stellen in [2, 3, 4] {
            let v = schoen(raw, ganz: ganz, jahr: jahr, stellen: stellen)
            if valid(v, below: below) { return v }
        }
        // Rounding pushed it into the zone: take the band edge farthest from the truth.
        let edge = below ? band.0 : band.1
        for stellen in [2, 3, 4] {
            let v = schoen(edge, ganz: ganz, jahr: jahr, stellen: stellen)
            if valid(v, below: below) { return v }
        }
        if jahr || ganz { return below ? edge.rounded(.down) : edge.rounded(.up) }
        return edge
    }

    /// Round to `stellen` significant digits (years and whole-number questions stay integral).
    public static func schoen(_ v: Double, ganz: Bool, jahr: Bool, stellen: Int) -> Double {
        if jahr { return v.rounded() }
        guard v != 0, v.isFinite else { return v }
        let mag = floor(log10(abs(v)))
        let step = pow(10, mag - Double(stellen - 1))
        var n = (v / step).rounded() * step
        if ganz { n = n.rounded() }
        return Double(String(format: "%.12g", n)) ?? n
    }

    /// German number text: "1.200", "0,035", "1995" (years without grouping).
    public static func zahl(_ v: Double, jahr: Bool) -> String {
        if jahr { return String(Int(v.rounded())) }
        if v == v.rounded(), abs(v) < 1e15 { return Money.formatNumber(Int(v)) }
        let a = abs(v)
        let decimals = a >= 100 ? 0 : (a >= 10 ? 1 : (a >= 1 ? 2 : (a >= 0.01 ? 3 : 5)))
        var s = String(format: "%.\(decimals)f", a)
        if s.contains(".") { while s.hasSuffix("0") { s.removeLast() }; if s.hasSuffix(".") { s.removeLast() } }
        let parts = s.split(separator: ".", maxSplits: 1).map(String.init)
        let whole = Money.formatNumber(Int(parts[0]) ?? 0)
        return (v < 0 ? "−" : "") + whole + (parts.count > 1 ? "," + parts[1] : "")
    }

    // MARK: Flow

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        var qs = questions.filter { $0.typ == .schaetz && $0.schaetz != nil }
        if qs.isEmpty { qs = [fallback] }
        var s = State(questions: qs, gesamt: NeueFormate.schritte(ctx, verfuegbar: qs.count), index: 0, phase: "frage", startedAt: ctx.now,
                      deadline: ctx.now, timerMs: 0, finishedAt: nil, revealUntil: nil, anker: 0, ankerText: "", jahr: false, richtung: "hoeher",
                      wert: 0, votes: [:], votedAt: [:], serie: [:], besteSerie: [:], punkte: [:], richtig: [:], beantwortet: [:],
                      lastPoints: [:], gespielt: 0, verbraucht: 0)
        start(&s, index: 0, ctx: &ctx)
        return s
    }

    static func start(_ s: inout State, index: Int, ctx: inout MinigameContext) {
        let q = s.questions[index % s.questions.count]
        let sp = spec(q)
        s.index = index
        s.phase = "frage"
        s.jahr = istJahr(sp, text: q.text)
        s.anker = anker(sp, text: q.text, rng: &ctx.rng)
        s.ankerText = zahl(s.anker, jahr: s.jahr)
        s.richtung = sp.richtwert > s.anker ? "hoeher" : "tiefer"
        s.wert = NeueFormate.wert(q.schw, ctx: ctx)
        s.timerMs = NeueFormate.fenster(fensterMs, ctx: ctx)
        s.startedAt = ctx.now
        s.deadline = ctx.now + s.timerMs
        s.finishedAt = nil
        s.revealUntil = nil
        s.votes = [:]
        s.votedAt = [:]
        s.lastPoints = [:]
        s.verbraucht = max(s.verbraucht, index + 1)
    }

    /// Points for a right swing after `serie` right ones in a row (this one included).
    public static func punkte(wert: Int, serie: Int) -> Int {
        let mult = serie >= 3 ? NeueFormate.Anteil.schaukelSerie3 : (serie == 2 ? NeueFormate.Anteil.schaukelSerie2 : 1.0)
        return NeueFormate.betrag(wert, NeueFormate.Anteil.schaukel * mult)
    }

    static func resolve(_ s: inout State, ctx: MinigameContext) {
        s.lastPoints = [:]
        for p in ctx.players {
            guard let v = s.votes[p] else { s.serie[p] = 0; continue }
            s.beantwortet[p, default: 0] += 1
            if v == s.richtung {
                let n = (s.serie[p] ?? 0) + 1
                s.serie[p] = n
                s.besteSerie[p] = max(s.besteSerie[p] ?? 0, n)
                let pts = punkte(wert: s.wert, serie: n)
                s.punkte[p, default: 0] += pts
                s.richtig[p, default: 0] += 1
                s.lastPoints[p] = pts
            } else {
                s.serie[p] = 0
            }
        }
        s.gespielt += 1
    }

    static func weiter(_ s: inout State, ctx: inout MinigameContext) {
        if s.index + 1 < s.gesamt { start(&s, index: s.index + 1, ctx: &ctx) } else { s.phase = "fertig"; s.revealUntil = nil }
    }

    static func richtungAus(_ label: String) -> String? {
        let l = label.lowercased()
        if l == "hoeher" || l.contains("höher") || l.contains("hoeher") || l.contains("⬆") { return "hoeher" }
        if l == "tiefer" || l.contains("tiefer") || l.contains("⬇") { return "tiefer" }
        return nil
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        guard state.phase == "frage", state.votes[player] == nil, ctx.now <= state.deadline + ChoiceCore.graceMs else { return }
        let label: String
        switch action {
        case .binary(let l), .vote(let l), .button(let l): label = l
        case .choose(let i): label = i == 0 ? "hoeher" : "tiefer"
        default: return
        }
        guard let r = richtungAus(label) else { return }
        state.votes[player] = r
        state.votedAt[player] = ctx.now
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        switch action {
        case .timerExtend(let ms):
            if state.phase == "frage" { state.deadline += ms; state.timerMs += ms }
        case .timerShift(let ms):
            state.deadline += ms
            state.startedAt += ms
            for (p, t) in state.votedAt { state.votedAt[p] = t + ms }
            if let r = state.revealUntil { state.revealUntil = r + ms }
        case .forceFinish:
            if state.phase == "frage", !state.votes.isEmpty { resolve(&state, ctx: ctx) }
            state.phase = "fertig"
            state.revealUntil = nil
        case .skipQuestion:
            if state.phase != "fertig" { weiter(&state, ctx: &ctx) }
        default:
            break
        }
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {
        switch state.phase {
        case "frage":
            let done = ctx.now > state.deadline + ChoiceCore.graceMs || NeueFormate.alleDrin(NeueFormate.aktive(ctx: ctx)) { state.votes[$0] != nil }
            if done {
                resolve(&state, ctx: ctx)
                state.phase = "mini"
                state.revealUntil = ctx.now + ctx.ms(NeueFormate.Reveal.schaukel)
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
        var parts = ["\(s.richtig[p] ?? 0)/\(s.gespielt) richtig geschaukelt"]
        if let b = s.besteSerie[p], b >= 2 { parts.append("beste Serie \(b)") }
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

    /// Display scale around anchor and truth (log scale in log space).
    static func skala(_ s: State, truth: Double, log: Bool) -> (Double, Double) {
        let a = s.anker, w = truth
        if log && a > 0 && w > 0 {
            let la = Foundation.log(a), lw = Foundation.log(w), d = max(abs(la - lw), 0.05)
            return (exp(min(la, lw) - d * 0.45), exp(max(la, lw) + d * 0.45))
        }
        let d = max(abs(a - w), 1e-9)
        return (min(a, w) - d * 0.45, max(a, w) + d * 0.45)
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        let phase = revealed ? "fertig" : state.phase
        let q = state.questions[state.index % state.questions.count]
        let sp = spec(q)
        let open = phase != "frage"
        let log = sp.skala == "log" && sp.richtwert > 0 && state.anker > 0
        let sc = skala(state, truth: sp.richtwert, log: log)
        let up = ctx.players.filter { state.votes[$0] == "hoeher" }, down = ctx.players.filter { state.votes[$0] == "tiefer" }
        let extra = StageExtra.schaukel(nummer: state.index + 1, gesamt: state.gesamt, phase: phase, anchor: state.anker, anchorText: state.ankerText,
                                        unit: sp.einheit, truth: open ? sp.richtwert : nil, truthText: open ? zahl(sp.richtwert, jahr: state.jahr) : nil,
                                        richtung: open ? state.richtung : nil, votes: open ? SchaukelVotes(up: up, down: down) : nil,
                                        answered: phase == "frage" ? ctx.players.filter { state.votes[$0] != nil }.count : 0, log: log,
                                        lo: sc.0, hi: sc.1, frage: open ? q.text : nil, serien: state.serie,
                                        points: open ? state.lastPoints : [:], totals: state.punkte)
        if phase == "frage" {
            let kat = ctx.catalog.categories.first { $0.id == q.kat }
            let wall = QuestionWall(text: q.text, kategorie: q.kat, kategorieName: kat?.name ?? ctx.catalog.categoryName(q.kat), kategorieEmoji: kat?.emoji ?? "❓",
                                    schwierigkeit: q.schw, wert: NeueFormate.betrag(state.wert, NeueFormate.Anteil.schaukel), options: nil,
                                    answered: ctx.players.filter { state.votes[$0] != nil }, deadline: ctx.visible(state.deadline), timerMs: state.timerMs,
                                    revealed: false, correctIndex: nil, answersByPlayer: [:], nummer: state.index + 1, gesamt: state.gesamt)
            return MinigameStageOutput(wall: wall, extra: extra, title: meta.name, audio: AudioCue(music: meta.musik))
        }
        let title = phase == "mini" ? "↕️ Frage \(state.index + 1) von \(state.gesamt)" : "↕️ Affenschaukel"
        return MinigameStageOutput(wall: nil, extra: extra, title: title, audio: AudioCue(music: meta.musik))
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        let q = state.questions[state.index % state.questions.count]
        let sp = spec(q)
        let einheit = sp.einheit.isEmpty ? "" : " \(sp.einheit)"
        if revealed {
            let pts = state.punkte[player] ?? 0
            let n = state.richtig[player] ?? 0
            let title = pts == 0 ? ((state.beantwortet[player] ?? 0) > 0 ? "Abgestürzt!" : "Nicht geschaukelt") : (n == state.gespielt ? "↕️ PERFEKT GESCHAUKELT!" : "↕️ Gut geschaukelt!")
            return .reveal(title: title, correct: outcomes(state, ctx: ctx)[player]?.correct ?? nil, delta: pts, detail: detail(state, player), streak: 0, speedBonus: nil)
        }
        switch state.phase {
        case "frage":
            let chosen = state.votes[player].map { $0 == "hoeher" ? hoeher : tiefer }
            let serie = state.serie[player] ?? 0
            let next = punkte(wert: state.wert, serie: serie + 1)
            let bonus = serie >= 1 ? " · 🔥 Serie \(serie) — richtig = +\(Money.format(next))" : " · richtig = +\(Money.format(next))"
            return .binary(title: "Höher oder tiefer als \(state.ankerText)\(einheit)?", subtitle: "Frage \(state.index + 1)/\(state.gesamt): \(q.text)\(bonus)",
                           a: hoeher, b: tiefer, chosen: chosen, deadline: ctx.visible(state.deadline))
        case "mini":
            let wahr = "Wahr: \(zahl(sp.richtwert, jahr: state.jahr))\(einheit) · Anker \(state.ankerText)\(einheit)"
            guard let v = state.votes[player] else {
                return .reveal(title: "⏰ Nicht geschaukelt", correct: nil, delta: 0, detail: wahr, streak: 0, speedBonus: nil)
            }
            if v == state.richtung {
                let s = state.serie[player] ?? 1
                let serie = s >= 2 ? " · 🔥 \(s)er-Serie ×\(NeueFormate.faktor(s >= 3 ? NeueFormate.Anteil.schaukelSerie3 : NeueFormate.Anteil.schaukelSerie2).dropLast())" : ""
                return .reveal(title: state.richtung == "hoeher" ? "⬆️ Richtig — höher!" : "⬇️ Richtig — tiefer!", correct: true, delta: state.lastPoints[player] ?? 0,
                               detail: wahr + serie, streak: 0, speedBonus: nil)
            }
            return .reveal(title: "❌ Falsch geschaukelt", correct: false, delta: 0, detail: wahr, streak: 0, speedBonus: nil)
        default:
            return .idle(title: "↕️ Auswertung …", subtitle: nil)
        }
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        if state.phase == "fertig" {
            var answers: [PlayerId: String] = [:]
            for p in ctx.players { answers[p] = "\(detail(state, p)) · \(Money.formatDelta(state.punkte[p] ?? 0))" }
            return (NeueFormate.gmRunde("affenschaukel-runde", "↕️ Affenschaukel — \(state.gespielt) Fragen geschaukelt", ctx: ctx, typ: .schaetz), answers)
        }
        let q = state.questions[state.index % state.questions.count]
        let sp = spec(q)
        let einheit = sp.einheit.isEmpty ? "" : " \(sp.einheit)"
        let korrekt = (state.richtung == "hoeher" ? hoeher : tiefer) + " (wahr: \(zahl(sp.richtwert, jahr: state.jahr))\(einheit), Anker \(state.ankerText)\(einheit))"
        let info = GmQuestionInfo(id: q.id, text: "\(q.text) — höher oder tiefer als \(state.ankerText)\(einheit)?", kategorie: ctx.catalog.categoryPath(q),
                                  schwierigkeit: q.schw, korrekt: korrekt, erklaerung: q.erkl, tipps: q.tipps, typ: .schaetz)
        var answers: [PlayerId: String] = [:]
        for (p, v) in state.votes {
            let secs = Double(max(0, (state.votedAt[p] ?? state.startedAt) - state.startedAt)) / 1000
            answers[p] = "\(v == "hoeher" ? hoeher : tiefer) (\(String(format: "%.1f", secs)) s) \(v == state.richtung ? "✅" : "❌")"
        }
        return (info, answers)
    }

    public static func questionsUsed(_ state: State) -> Int { max(1, state.verbraucht) }
}
