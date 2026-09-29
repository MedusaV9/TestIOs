import Foundation

/// 🪢 Tauziehen — two teams, one rope. The teams are drafted from the current
/// ranking (snake order 1-2-2-1 …, so both teams get the same mix of leaders and
/// chasers; team sizes differ by at most one). Every right answer to a choice
/// question pulls the rope one step toward its team, the fastest right answer of a
/// question pulls double. A smaller team's pulls weigh more (per-member strength),
/// so 3 against 4 is fair. After the last question the team on whose side the knot
/// is wins: every member gets 1,0 F × questions/4, the member with the most pulls
/// +0,5 F as MVP. Knot in the middle = draw: everybody 0,4 F × questions/4.
public enum Tauziehen: MinigamePlugin {
    /// One pull of a resolved question.
    public struct Zug: Codable, Equatable, Sendable {
        public var player: PlayerId
        /// "a" | "b"
        public var team: String
        /// 1 = right answer, 2 = fastest right answer.
        public var zug: Int
        public var ms: Int?
    }

    public struct TeamInfo: Codable, Equatable, Sendable {
        public var id: String
        public var name: String
        public var emoji: String
        public var farbe: String
        public var mitglieder: [PlayerId]
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
        public var teamA: [PlayerId]
        public var teamB: [PlayerId]
        /// Raw pulls per team (right answers, the fastest counts double).
        public var zugA: Int
        public var zugB: Int
        /// Knot display position before the last question (−1 … 1, negative = team A's side).
        public var knotenVorher: Double
        /// Pull points per player (MVP), fast pulls, answer time of right answers (MVP tiebreak).
        public var zuege: [PlayerId: Int]
        public var doppel: [PlayerId: Int]
        public var richtigMs: [PlayerId: Int]
        public var richtig: [PlayerId: Int]
        public var beantwortet: [PlayerId: Int]
        public var letzteZuege: [Zug]
        /// Σ F of the questions played — the team payout base.
        public var rundenWert: Int
        public var gespielt: Int
        public var verbraucht: Int
        /// "a" | "b" | "remis" once the round is over.
        public var sieger: String?
        public var mvp: PlayerId?
        public var auszahlung: [PlayerId: Int]
        public var letzteFrage: String?
        public var letzteRichtig: String?
    }

    /// Stage widget payload (stage/extras-neu2.js, `f == "tauziehen"`).
    struct View: Codable {
        var f = "tauziehen"
        var phase: String
        var nummer: Int
        var gesamt: Int
        var teams: [TeamInfo]
        var zugA: Int
        var zugB: Int
        /// Knot position −1 … 1 (negative = team A / left) and before the last question.
        var knoten: Double
        var knotenVorher: Double
        var zuege: [String: Int]
        var letzte: [Zug]
        var frage: String?
        var richtig: String?
        var sieger: String?
        var mvp: String?
        var auszahlung: [String: Int]
        var answered: Int
        /// What a win / the MVP / a draw pays right now (per member).
        var siegWert: Int
        var mvpWert: Int
        var remisWert: Int
    }

    static let teamInfo = [("a", "Bananen-Bande", "🍌", "gelb"), ("b", "Kokos-Clan", "🥥", "lila")]
    private static let sieg = Welle2.f(Welle2.Anteil.zugSieg)
    private static let mvpK = Welle2.f(Welle2.Anteil.zugMvp)
    private static let remis = Welle2.f(Welle2.Anteil.zugRemis)
    private static let basis = Int(Welle2.Anteil.zugFragenBasis)

    public static let meta = MinigameMeta(
        id: "tauziehen", name: "Tauziehen", emoji: "🪢",
        kurz: "Zwei Teams, ein Seil: jede richtige Antwort zieht den Knoten zu deinem Team — der Schnellste zieht doppelt.",
        erklaerung: "Die Show teilt euch nach dem Punktestand in zwei faire Teams: 🍌 Bananen-Bande gegen 🥥 Kokos-Clan. Jede richtige Antwort zieht das Seil einen Ruck zu deinem Team, die schnellste richtige Antwort einer Frage zieht doppelt. Nach der letzten Frage gewinnt das Team, auf dessen Seite der Knoten liegt: jedes Mitglied bekommt \(sieg) Fragenwert pro \(basis) Fragen, wer im Siegerteam am meisten gezogen hat, zusätzlich \(mvpK) Fragenwert als MVP. Liegt der Knoten genau in der Mitte, bekommt jeder \(remis) Fragenwert pro \(basis) Fragen.",
        regeln: ["Zwei faire Teams nach dem Punktestand: 🍌 Bananen-Bande gegen 🥥 Kokos-Clan",
                 "Jede richtige Antwort zieht das Seil zu deinem Team",
                 "Die schnellste richtige Antwort zieht doppelt",
                 "Am Ende gewinnt das Team, auf dessen Seite der Knoten liegt",
                 "Sieg: jedes Mitglied \(sieg) Fragenwert pro \(basis) Fragen · MVP +\(mvpK) · Unentschieden: jeder \(remis) pro \(basis) Fragen"],
        gewinn: "Siegerteam je \(sieg) Fragenwert pro \(basis) Fragen · MVP +\(mvpK) · Unentschieden je \(remis) pro \(basis) Fragen",
        minPlayers: 4, maxPlayers: 12,
        contentKind: .fragen([.choice, .emoji, .wahrFalsch]), roundBased: true, streak: false, jokerAktionen: [], isMc: true, musik: "duel_showdown", v2: true
    )

    // MARK: Rules (pure)

    /// Snake draft over the ranking (balance desc, ties in seat order; connected players first):
    /// 1st → A, 2nd → B, 3rd → B, 4th → A, 5th → A …
    public static func teams(_ ctx: MinigameContext) -> (a: [PlayerId], b: [PlayerId]) {
        let seat = Dictionary(uniqueKeysWithValues: ctx.players.enumerated().map { ($0.element, $0.offset) })
        let ranked = ctx.players.sorted { x, y in
            let cx = ctx.connected.contains(x), cy = ctx.connected.contains(y)
            if cx != cy { return cx }
            let bx = ctx.balances[x] ?? 0, by = ctx.balances[y] ?? 0
            return bx != by ? bx > by : (seat[x] ?? 0) < (seat[y] ?? 0)
        }
        var a: [PlayerId] = [], b: [PlayerId] = []
        for (i, p) in ranked.enumerated() { if i % 4 == 0 || i % 4 == 3 { a.append(p) } else { b.append(p) } }
        return (a, b)
    }

    /// Who wins: per-member strength (pulls ÷ team size), compared exactly by cross-multiplying.
    public static func sieger(zugA: Int, zugB: Int, groesseA: Int, groesseB: Int) -> String {
        let a = zugA * max(1, groesseB), b = zugB * max(1, groesseA)
        return a > b ? "a" : (b > a ? "b" : "remis")
    }

    /// Knot position for the stage (−1 … 1, negative = team A): per-member pull difference over a
    /// display span that grows with the round length.
    public static func knoten(zugA: Int, zugB: Int, groesseA: Int, groesseB: Int, gesamt: Int) -> Double {
        let d = Double(zugB) / Double(max(1, groesseB)) - Double(zugA) / Double(max(1, groesseA))
        let span = max(2.0, Double(gesamt) / 2)
        return min(1, max(-1, d / span))
    }

    /// Pulls of one question: every right answer 1, the fastest right one 2 (equal times: seat order).
    public static func zuege(richtigNachZeit: [PlayerId], team: (PlayerId) -> String?, ms: (PlayerId) -> Int?) -> [Zug] {
        var out: [Zug] = []
        for p in richtigNachZeit {
            guard let t = team(p) else { continue }
            // The first team member in time order is the fastest right answer.
            out.append(Zug(player: p, team: t, zug: out.isEmpty ? Welle2.Anteil.zugSchnellster : Welle2.Anteil.zugNormal, ms: ms(p)))
        }
        return out
    }

    /// Payouts at the end: winners × `zugSieg`, the winning team's MVP + `zugMvp`, draw: everybody × `zugRemis`.
    public static func auszahlung(sieger: String, teamA: [PlayerId], teamB: [PlayerId], rundenWert: Int, gespielt: Int, mvp: PlayerId?) -> [PlayerId: Int] {
        var out: [PlayerId: Int] = [:]
        guard gespielt > 0, rundenWert > 0 else { return out }
        let basis = Welle2.Anteil.zugFragenBasis
        switch sieger {
        case "remis":
            let v = NeueFormate.betrag(rundenWert, Welle2.Anteil.zugRemis / basis)
            for p in teamA + teamB { out[p] = v }
        default:
            let v = NeueFormate.betrag(rundenWert, Welle2.Anteil.zugSieg / basis)
            for p in sieger == "a" ? teamA : teamB { out[p] = v }
            if let m = mvp, out[m] != nil { out[m, default: 0] += NeueFormate.betrag(rundenWert / gespielt, Welle2.Anteil.zugMvp) }
        }
        return out
    }

    /// MVP of the winning team: most pull points, then more fast pulls, then the lower total
    /// answer time of right answers, then seat order. Nobody pulled → no MVP.
    static func mvp(_ s: State, team: [PlayerId]) -> PlayerId? {
        let cands = team.filter { (s.zuege[$0] ?? 0) > 0 }
        return cands.enumerated().min { x, y in
            let a = x.element, b = y.element
            if (s.zuege[a] ?? 0) != (s.zuege[b] ?? 0) { return (s.zuege[a] ?? 0) > (s.zuege[b] ?? 0) }
            if (s.doppel[a] ?? 0) != (s.doppel[b] ?? 0) { return (s.doppel[a] ?? 0) > (s.doppel[b] ?? 0) }
            if (s.richtigMs[a] ?? 0) != (s.richtigMs[b] ?? 0) { return (s.richtigMs[a] ?? 0) < (s.richtigMs[b] ?? 0) }
            return x.offset < y.offset
        }?.element
    }

    static func team(_ s: State, _ p: PlayerId) -> String? {
        s.teamA.contains(p) ? "a" : (s.teamB.contains(p) ? "b" : nil)
    }

    // MARK: Flow

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        var qs = questions.filter { $0.typ.isChoiceLike && $0.choiceOptions.count >= 2 && $0.correctIndex != nil && $0.typ != .bildPixel }
        if qs.isEmpty { qs = [Question.fallback(0)] }
        let t = teams(ctx)
        var s = State(questions: qs, gesamt: NeueFormate.schritte(ctx, verfuegbar: qs.count), index: 0, core: nil, wert: 0, phase: "frage",
                      revealUntil: nil, teamA: t.a, teamB: t.b, zugA: 0, zugB: 0, knotenVorher: 0, zuege: [:], doppel: [:], richtigMs: [:],
                      richtig: [:], beantwortet: [:], letzteZuege: [], rundenWert: 0, gespielt: 0, verbraucht: 0, sieger: nil, mvp: nil,
                      auszahlung: [:], letzteFrage: nil, letzteRichtig: nil)
        start(&s, index: 0, ctx: ctx)
        return s
    }

    static func start(_ s: inout State, index: Int, ctx: MinigameContext) {
        let q = s.questions[index % s.questions.count]
        s.index = index
        s.core = ChoiceCore(question: q, ctx: NeueFormate.frageKontext(ctx, nummer: index + 1, gesamt: s.gesamt))
        s.wert = NeueFormate.wert(q.schw, ctx: ctx)
        s.phase = "frage"
        s.revealUntil = nil
        s.verbraucht = max(s.verbraucht, index + 1)
    }

    static func knoten(_ s: State) -> Double {
        knoten(zugA: s.zugA, zugB: s.zugB, groesseA: s.teamA.count, groesseB: s.teamB.count, gesamt: s.gesamt)
    }

    static func resolve(_ s: inout State, ctx: MinigameContext) {
        guard let core = s.core else { return }
        s.knotenVorher = knoten(s)
        let order = core.correctByTime(ctx.players).filter { core.hasAnswered($0) }
        let pulls = zuege(richtigNachZeit: order, team: { team(s, $0) }, ms: { core.answeredAfterMs($0) })
        for p in ctx.players where core.hasAnswered(p) && team(s, p) != nil { s.beantwortet[p, default: 0] += 1 }
        for z in pulls {
            if z.team == "a" { s.zugA += z.zug } else { s.zugB += z.zug }
            s.zuege[z.player, default: 0] += z.zug
            s.richtig[z.player, default: 0] += 1
            s.richtigMs[z.player, default: 0] += z.ms ?? 0
            if z.zug == Welle2.Anteil.zugSchnellster { s.doppel[z.player, default: 0] += 1 }
        }
        s.letzteZuege = pulls
        s.rundenWert += s.wert
        s.gespielt += 1
        s.letzteFrage = core.question.displayText
        s.letzteRichtig = core.options.indices.contains(core.correctIndex) ? core.options[core.correctIndex] : nil
    }

    /// Close the round: winner, MVP, payouts.
    static func abschluss(_ s: inout State) {
        s.phase = "fertig"
        s.revealUntil = nil
        let w = sieger(zugA: s.zugA, zugB: s.zugB, groesseA: s.teamA.count, groesseB: s.teamB.count)
        s.sieger = s.gespielt > 0 ? w : "remis"
        s.mvp = w == "a" ? mvp(s, team: s.teamA) : (w == "b" ? mvp(s, team: s.teamB) : nil)
        s.auszahlung = auszahlung(sieger: s.sieger ?? "remis", teamA: s.teamA, teamB: s.teamB, rundenWert: s.rundenWert, gespielt: s.gespielt, mvp: s.mvp)
    }

    /// The round as it would end now (the engine may book early: GM "Notausgang mit Punkten").
    static func endstand(_ s: State) -> State {
        guard s.sieger == nil else { return s }
        var c = s
        abschluss(&c)
        return c
    }

    static func weiter(_ s: inout State, ctx: MinigameContext) {
        if s.index + 1 < s.gesamt { start(&s, index: s.index + 1, ctx: ctx) } else { abschluss(&s) }
    }

    static func frageFertig(_ s: State, ctx: MinigameContext) -> Bool {
        guard let core = s.core else { return true }
        if core.finishedAt != nil || ctx.now > core.deadline + ChoiceCore.graceMs { return true }
        // Everybody who pulls (team members still in the room) has answered.
        return NeueFormate.alleDrin(NeueFormate.aktive(s.teamA + s.teamB, ctx: ctx)) { core.hasAnswered($0) }
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        guard state.phase == "frage", team(state, player) != nil, case .choose(let i) = action, var core = state.core else { return }
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
            if state.phase != "fertig" { abschluss(&state) }
        case .skipQuestion:
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
                state.revealUntil = ctx.now + ctx.ms(Welle2.Reveal.zug)
            }
        case "mini":
            if let r = state.revealUntil, ctx.now >= r { weiter(&state, ctx: ctx) }
        default:
            break
        }
    }

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.phase == "fertig" }

    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] {
        let e = endstand(state)
        var s: [PlayerId: Int] = [:]
        for p in ctx.players { s[p] = e.auszahlung[p] ?? 0 }
        return s
    }

    static func teamName(_ id: String?) -> String {
        guard let t = teamInfo.first(where: { $0.0 == id }) else { return "Zuschauer" }
        return "\(t.2) \(t.1)"
    }

    static func detail(_ s: State, _ p: PlayerId) -> String {
        guard let t = team(s, p) else { return "Zuschauer in dieser Runde" }
        var parts = ["\(teamName(t)) · \(s.zuege[p] ?? 0) Züge"]
        if let d = s.doppel[p], d > 0 { parts.append("\(d)× schnellster") }
        if s.mvp == p { parts.append("🏅 MVP") }
        return parts.joined(separator: " · ")
    }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        let e = endstand(state)
        var out: [PlayerId: Outcome] = [:]
        for p in ctx.players {
            let pts = e.auszahlung[p] ?? 0
            let played = (e.beantwortet[p] ?? 0) > 0
            out[p] = Outcome(correct: pts > 0 ? true : (played ? false : nil), countsForStreak: false, detail: detail(e, p))
        }
        return out
    }

    static func teamViews(_ s: State) -> [TeamInfo] {
        [TeamInfo(id: "a", name: teamInfo[0].1, emoji: teamInfo[0].2, farbe: teamInfo[0].3, mitglieder: s.teamA),
         TeamInfo(id: "b", name: teamInfo[1].1, emoji: teamInfo[1].2, farbe: teamInfo[1].3, mitglieder: s.teamB)]
    }

    /// Payout per member if the round ended with `gespielt` questions of average value (for the widget).
    static func werte(_ s: State) -> (sieg: Int, mvp: Int, remis: Int) {
        let n = max(1, s.gespielt)
        let schnitt = s.gespielt > 0 ? s.rundenWert / n : s.wert
        let total = schnitt * max(s.gesamt, s.gespielt)
        let b = Welle2.Anteil.zugFragenBasis
        return (NeueFormate.betrag(total, Welle2.Anteil.zugSieg / b), NeueFormate.betrag(schnitt, Welle2.Anteil.zugMvp), NeueFormate.betrag(total, Welle2.Anteil.zugRemis / b))
    }

    static func view(_ s: State, phase: String, ctx: MinigameContext) -> View {
        let asking = phase == "frage"
        let answered = asking ? (s.core.map { c in (s.teamA + s.teamB).filter { c.hasAnswered($0) }.count } ?? 0) : 0
        let w = werte(s)
        let end = phase == "fertig"
        return View(phase: phase, nummer: s.index + 1, gesamt: s.gesamt, teams: teamViews(s), zugA: s.zugA, zugB: s.zugB,
                    knoten: knoten(s), knotenVorher: phase == "mini" ? s.knotenVorher : knoten(s), zuege: Welle2.map(s.zuege, ctx.players),
                    letzte: phase == "mini" ? s.letzteZuege : [], frage: phase == "mini" ? s.letzteFrage : nil,
                    richtig: phase == "mini" ? s.letzteRichtig : nil, sieger: end ? s.sieger : nil, mvp: end ? s.mvp : nil,
                    auszahlung: end ? Welle2.map(s.auszahlung, ctx.players) : [:], answered: answered,
                    siegWert: w.sieg, mvpWert: w.mvp, remisWert: w.remis)
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        // The booking reveal shows the final rope even if the engine ended the round from outside.
        let s = revealed ? endstand(state) : state
        let phase = revealed ? "fertig" : s.phase
        let extra = Welle2.karte("🪢 Tauziehen", view(s, phase: phase, ctx: ctx))
        if phase == "frage", let core = s.core {
            var wall = core.wall(ctx: NeueFormate.frageKontext(ctx, nummer: s.index + 1, gesamt: s.gesamt), revealed: false)
            wall.wert = werte(s).sieg
            return MinigameStageOutput(wall: wall, extra: extra, title: meta.name, audio: AudioCue(music: meta.musik))
        }
        let title = phase == "mini" ? "🪢 Frage \(s.index + 1) von \(s.gesamt)" : "🪢 Tauziehen"
        return MinigameStageOutput(wall: nil, extra: extra, title: title, audio: AudioCue(music: meta.musik))
    }

    static func stand(_ s: State) -> String {
        let k = knoten(s)
        if abs(k) < 1e-9 { return "Der Knoten hängt genau in der Mitte" }
        return "Der Knoten liegt bei \(teamName(k < 0 ? "a" : "b"))"
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        let t = team(state, player)
        if revealed {
            let s = endstand(state)
            let pts = s.auszahlung[player] ?? 0
            guard t != nil else { return .reveal(title: "🪢 Tauziehen vorbei", correct: nil, delta: 0, detail: "Du hast diesmal zugeschaut", streak: 0, speedBonus: nil) }
            let title: String
            switch s.sieger {
            case "remis": title = "🪢 Unentschieden!"
            case let w? where w == t: title = s.mvp == player ? "🏅 MVP — ihr habt gewonnen!" : "🪢 Gewonnen — gut gezogen!"
            default: title = "🪢 Verloren — das andere Team war stärker"
            }
            return .reveal(title: title, correct: outcomes(s, ctx: ctx)[player]?.correct ?? nil, delta: pts, detail: detail(s, player), streak: 0, speedBonus: nil)
        }
        switch state.phase {
        case "frage":
            guard let core = state.core else { return .idle(title: "🪢 Gleich geht's weiter …", subtitle: nil) }
            guard let t else { return .idle(title: "🪢 Tauziehen läuft", subtitle: "Du bist in dieser Runde Zuschauer — feuer die Teams an!") }
            let seite = t == "a" ? "⬅️" : "➡️"
            let hint = "🪢 Du ziehst für \(teamName(t)) \(seite) · \(stand(state)) · schnellster Richtiger zieht doppelt"
            return core.prompt(for: player, ctx: NeueFormate.frageKontext(ctx, nummer: state.index + 1, gesamt: state.gesamt), revealed: false, hint: hint)
        case "mini":
            let loesung = state.letzteRichtig.map { "Richtig: \($0)" }
            guard t != nil else { return .idle(title: "🪢 \(stand(state))", subtitle: loesung) }
            if let z = state.letzteZuege.first(where: { $0.player == player }) {
                let title = z.zug == Welle2.Anteil.zugSchnellster ? "⚡ Doppelzug — du warst am schnellsten!" : "💪 Richtig — du ziehst mit!"
                return .reveal(title: title, correct: true, delta: 0, detail: [stand(state), "\(state.zuege[player] ?? 0) Züge bisher", "Kasse am Rundenende"].joined(separator: " · "), streak: 0, speedBonus: nil)
            }
            let answered = state.core?.hasAnswered(player) == true
            return .reveal(title: answered ? "❌ Daneben — kein Zug" : "⏰ Keine Antwort — kein Zug", correct: answered ? false : nil, delta: 0,
                           detail: [loesung, stand(state)].compactMap { $0 }.joined(separator: " · "), streak: 0, speedBonus: nil)
        default:
            return .idle(title: "🪢 Auswertung …", subtitle: stand(state))
        }
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        if state.phase == "fertig" {
            let e = endstand(state)
            var answers: [PlayerId: String] = [:]
            for p in ctx.players { answers[p] = "\(detail(e, p)) · \(Money.formatDelta(e.auszahlung[p] ?? 0))" }
            let res = e.sieger == "remis" ? "Unentschieden" : "Sieg \(teamName(e.sieger))"
            return (NeueFormate.gmRunde("tauziehen-runde", "🪢 Tauziehen — \(res) (\(e.zugA):\(e.zugB) Züge)", ctx: ctx), answers)
        }
        guard let core = state.core else { return (nil, [:]) }
        var g = core.gmInfo(ctx: ctx)
        for (p, a) in g.answers { g.answers[p] = "\(team(state, p) == "a" ? "🍌" : team(state, p) == "b" ? "🥥" : "👀") " + a }
        if state.phase == "mini" {
            for z in state.letzteZuege { g.answers[z.player] = "+\(z.zug) Zug · " + (g.answers[z.player] ?? "") }
        }
        return g
    }

    public static func questionsUsed(_ state: State) -> Int { max(1, state.verbraucht) }
}
