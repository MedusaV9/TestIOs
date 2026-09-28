import Foundation

/// Der letzte Affe — survival. Everyone starts alive; a wrong or missing
/// answer knocks you out (mercy: if every survivor is wrong, nobody falls).
/// Each survived question banks 0.2 F, the last one standing gets 1 F (several
/// survivors of the final question split it). Knocked-out monkeys tip the
/// winner once (right tip +0.3 F) and cheer. Ends early at ≤ 1 survivor.
public enum LetzterAffe: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var questions: [Question]
        public var gesamt: Int
        public var index: Int
        public var core: ChoiceCore?
        /// F × modifiers of the running question (the survival bank).
        public var wert: Int
        /// F of the section (last-standing bonus, tip reward).
        public var bonusWert: Int
        /// "frage" | "mini" | "fertig"
        public var phase: String
        public var revealUntil: Millis?
        /// Roster at the start of the round (late joiners watch).
        public var teilnehmer: [PlayerId]
        public var alive: [PlayerId]
        public var out: [SurvivalOut]
        public var banked: [PlayerId: Int]
        /// Knocked out / survived by the last resolved question.
        public var lastOut: [PlayerId]
        public var lastSurvivors: [PlayerId]
        public var gnade: Bool
        public var tipps: [PlayerId: PlayerId]
        public var cheers: [PlayerId: Int]
        public var sieger: [PlayerId]
        public var bonus: [PlayerId: Int]
        public var tippGewinn: [PlayerId: Int]
        public var gespielt: Int
        public var verbraucht: Int
        public var letzteFrage: String?
        public var letzteRichtig: String?
    }

    public static let meta = MinigameMeta(
        id: "letzter-affe", name: "Der letzte Affe", emoji: "🪂",
        kurz: "Survival: Falsch oder zu langsam heißt raus — wer als Letzter steht, kassiert den Bonus.",
        erklaerung: "Alle Affen starten im Spiel. Die Fragen kommen Schlag auf Schlag — wer falsch oder gar nicht antwortet, fliegt raus. Gnade: Liegen ALLE Übrigen falsch, fliegt keiner. Jede überlebte Frage bringt 0,2× Fragenwert aufs Konto. Wer als Letzter übrig bleibt, bekommt 1× Fragenwert Bonus — überleben mehrere die letzte Frage, teilen sie ihn. Wer raus ist, tippt einmal auf den Sieger (richtig: +0,3×) und feuert an.",
        regeln: ["Falsch oder keine Antwort: raus!",
                 "Gnade: liegen alle Übrigen falsch, fliegt keiner",
                 "Jede überlebte Frage: +0,2× Fragenwert",
                 "Der letzte Affe bekommt 1× Fragenwert Bonus (mehrere teilen)",
                 "Raus? Tippe einmal auf den Sieger (+0,3×) und feuere an"],
        gewinn: "Pro überlebter Frage 0,2× Fragenwert · Letzter Affe +1× (geteilt) · richtiger Tipp +0,3×",
        contentKind: .choiceLike, roundBased: true, streak: false, jokerAktionen: [], isMc: true, musik: "duel_showdown", v2: true
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        var qs = questions.filter { $0.typ.isChoiceLike && !$0.choiceOptions.isEmpty && $0.correctIndex != nil }
        if qs.isEmpty { qs = [Question.fallback(0)] }
        var s = State(questions: qs, gesamt: NeueFormate.schritte(ctx, verfuegbar: qs.count), index: 0, core: nil, wert: 0,
                      bonusWert: NeueFormate.sectionWert(ctx: ctx), phase: "frage", revealUntil: nil, teilnehmer: ctx.players, alive: ctx.players,
                      out: [], banked: [:], lastOut: [], lastSurvivors: [], gnade: false, tipps: [:], cheers: [:], sieger: [], bonus: [:],
                      tippGewinn: [:], gespielt: 0, verbraucht: 0, letzteFrage: nil, letzteRichtig: nil)
        start(&s, index: 0, ctx: ctx)
        return s
    }

    static func start(_ s: inout State, index: Int, ctx: MinigameContext) {
        let q = s.questions[index % s.questions.count]
        let qctx = NeueFormate.frageKontext(ctx, nummer: index + 1, gesamt: s.gesamt)
        s.index = index
        s.core = ChoiceCore(question: q, ctx: qctx, timerMs: qctx.timerMs(for: q))
        s.wert = NeueFormate.wert(q.schw, ctx: ctx)
        s.phase = "frage"
        s.revealUntil = nil
        s.verbraucht = max(s.verbraucht, index + 1)
    }

    /// Survivors still in the room, in seat order.
    static func lebend(_ s: State, ctx: MinigameContext) -> [PlayerId] {
        let alive = Set(s.alive)
        return ctx.players.filter { alive.contains($0) }
    }

    /// One question's verdict — pure: who survives, who falls, mercy.
    public static func urteil(alive: [PlayerId], correct: (PlayerId) -> Bool?) -> (survivors: [PlayerId], out: [PlayerId], gnade: Bool) {
        let right = alive.filter { correct($0) == true }
        if right.isEmpty { return (alive, [], true) }
        return (right, alive.filter { correct($0) != true }, false)
    }

    static func resolve(_ s: inout State, ctx: MinigameContext) {
        guard let core = s.core else { return }
        let before = lebend(s, ctx: ctx)
        let u = urteil(alive: before) { core.isCorrect($0) }
        for p in u.survivors { s.banked[p, default: 0] += NeueFormate.betrag(s.wert, NeueFormate.Anteil.ueberlebt) }
        for p in u.out { s.out.append(SurvivalOut(player: p, atQuestion: s.index + 1)) }
        s.alive = u.survivors
        s.lastOut = u.out
        s.lastSurvivors = u.survivors
        s.gnade = u.gnade
        s.gespielt += 1
        s.letzteFrage = core.question.displayText
        s.letzteRichtig = core.options.indices.contains(core.correctIndex) ? core.options[core.correctIndex] : nil
    }

    /// Round end: the survivors split the bonus, right tips pay.
    static func finish(_ s: inout State, ctx: MinigameContext) {
        s.phase = "fertig"
        s.revealUntil = nil
        s.sieger = lebend(s, ctx: ctx)
        s.bonus = [:]
        if !s.sieger.isEmpty {
            let share = Economy.roundTo10(NeueFormate.betrag(s.bonusWert, NeueFormate.Anteil.letzterBonus) / s.sieger.count)
            for p in s.sieger { s.bonus[p] = max(10, share) }
        }
        s.tippGewinn = [:]
        let winners = Set(s.sieger)
        for p in ctx.players {
            if let t = s.tipps[p], winners.contains(t) { s.tippGewinn[p] = NeueFormate.betrag(s.bonusWert, NeueFormate.Anteil.tippRichtig) }
        }
    }

    static func vorbei(_ s: State, ctx: MinigameContext) -> Bool {
        if s.index + 1 >= s.gesamt { return true }
        return s.teilnehmer.count >= 2 && lebend(s, ctx: ctx).count <= 1
    }

    static func frageFertig(_ s: State, ctx: MinigameContext) -> Bool {
        guard let core = s.core else { return true }
        if core.finishedAt != nil || ctx.now > core.deadline + ChoiceCore.graceMs { return true }
        return NeueFormate.alleDrin(NeueFormate.aktive(lebend(s, ctx: ctx), ctx: ctx)) { core.hasAnswered($0) }
    }

    /// Knocked out, no tip yet and a race still worth tipping on.
    static func darfTippen(_ s: State, _ p: PlayerId, ctx: MinigameContext) -> Bool {
        s.phase != "fertig" && s.tipps[p] == nil && s.out.contains { $0.player == p } && lebend(s, ctx: ctx).count >= 2
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        switch action {
        case .choose(let i):
            guard state.phase == "frage", state.alive.contains(player), var core = state.core else { return }
            if core.answer(player, index: i, now: ctx.now) { state.core = core }
        case .pickPlayer(let id):
            guard darfTippen(state, player, ctx: ctx), lebend(state, ctx: ctx).contains(id) else { return }
            state.tipps[player] = id
        case .cheer:
            guard !state.alive.contains(player), state.phase != "fertig" else { return }
            state.cheers[player, default: 0] += 1
        default:
            break
        }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        switch action {
        case .timerExtend(let ms):
            if state.phase == "frage" { state.core?.extend(ms: ms) }
        case .timerShift(let ms):
            state.core?.shift(ms: ms)
            if let r = state.revealUntil { state.revealUntil = r + ms }
        case .forceFinish:
            // "Auflösen" never knocks anybody out: the running question is annulled, the survivors split the bonus.
            if state.phase != "fertig" { finish(&state, ctx: ctx) }
        case .skipQuestion:
            guard state.phase != "fertig" else { return }
            if vorbei(state, ctx: ctx) { finish(&state, ctx: ctx) } else { start(&state, index: state.index + 1, ctx: ctx) }
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
                state.revealUntil = ctx.now + ctx.ms(NeueFormate.Reveal.letzterAffe)
            }
        case "mini":
            guard let r = state.revealUntil, ctx.now >= r else { return }
            if vorbei(state, ctx: ctx) { finish(&state, ctx: ctx) } else { start(&state, index: state.index + 1, ctx: ctx) }
        default:
            break
        }
    }

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.phase == "fertig" }

    static func total(_ s: State, _ p: PlayerId) -> Int { (s.banked[p] ?? 0) + (s.bonus[p] ?? 0) + (s.tippGewinn[p] ?? 0) }

    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] {
        var s: [PlayerId: Int] = [:]
        for p in ctx.players { s[p] = total(state, p) }
        return s
    }

    static func rausBei(_ s: State, _ p: PlayerId) -> Int? { s.out.first { $0.player == p }?.atQuestion }

    static func detail(_ s: State, _ p: PlayerId, ctx: MinigameContext) -> String {
        var parts: [String] = []
        if s.sieger.contains(p) {
            parts.append(s.sieger.count == 1 ? "🏆 Letzter Affe · \(s.gespielt) Fragen überlebt" : "🪂 Bis zum Schluss überlebt · Bonus geteilt (\(s.sieger.count))")
        } else if let q = rausBei(s, p) {
            parts.append("💀 Raus in Frage \(q)")
        } else if !s.teilnehmer.contains(p) {
            parts.append("Zuschauer (später dazugekommen)")
        }
        if let t = s.tipps[p] { parts.append("Tipp \(ctx.name(t)) " + ((s.tippGewinn[p] ?? 0) > 0 ? "✅" : "❌")) }
        return parts.joined(separator: " · ")
    }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        var out: [PlayerId: Outcome] = [:]
        for p in ctx.players {
            let correct: Bool?
            if state.sieger.contains(p) { correct = true }
            else if rausBei(state, p) != nil { correct = total(state, p) > 0 ? nil : false }
            else { correct = nil }
            out[p] = Outcome(correct: correct, countsForStreak: false, detail: detail(state, p, ctx: ctx))
        }
        return out
    }

    static func extra(_ s: State, phase: String, ctx: MinigameContext) -> StageExtra {
        let alive = lebend(s, ctx: ctx)
        let answered = s.core.map { c in alive.filter { c.hasAnswered($0) }.count } ?? 0
        let reveal = phase != "frage"
        return .survival(nummer: s.index + 1, gesamt: s.gesamt, phase: phase, alive: alive, out: s.out, banked: s.banked,
                         lastOut: reveal ? s.lastOut : [], gnade: reveal && s.gnade, answered: phase == "frage" ? answered : 0,
                         frage: reveal ? s.letzteFrage : nil, richtig: reveal ? s.letzteRichtig : nil, sieger: phase == "fertig" ? s.sieger : [],
                         bonus: NeueFormate.betrag(s.bonusWert, NeueFormate.Anteil.letzterBonus), tippAnzahl: s.tipps.count,
                         tipps: phase == "fertig" ? s.tipps : [:], cheers: s.cheers.values.reduce(0, +))
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        let phase = revealed ? "fertig" : state.phase
        if phase == "frage", let core = state.core {
            let wall = core.wall(ctx: NeueFormate.frageKontext(ctx, nummer: state.index + 1, gesamt: state.gesamt), revealed: false)
            return MinigameStageOutput(wall: wall, extra: extra(state, phase: phase, ctx: ctx), title: meta.name, audio: AudioCue(music: meta.musik))
        }
        let title = phase == "mini" ? "🪂 Frage \(state.index + 1) von \(state.gesamt)" : "🪂 Der letzte Affe"
        return MinigameStageOutput(wall: nil, extra: extra(state, phase: phase, ctx: ctx), title: title, audio: AudioCue(music: meta.musik))
    }

    static func zuschauerPrompt(_ s: State, _ p: PlayerId, ctx: MinigameContext) -> PlayerPrompt {
        let alive = lebend(s, ctx: ctx)
        if darfTippen(s, p, ctx: ctx) {
            let refs = alive.map { id -> PlayerRef in
                var r = PlayerRef(Player(id: id, name: ctx.name(id), avatar: Avatar(), joinOrder: 0), platz: 0)
                r.balance = ctx.balances[id] ?? 0
                return r
            }
            let tip = Money.format(NeueFormate.betrag(s.bonusWert, NeueFormate.Anteil.tippRichtig))
            return .pickPlayer(title: "🎯 Wer wird der letzte Affe?", subtitle: "Du bist raus — ein Tipp, richtig = +\(tip)", candidates: refs, chosen: nil, deadline: nil)
        }
        let who = alive.map { ctx.name($0) }.joined(separator: ", ")
        let sub: String
        if let t = s.tipps[p] { sub = "Dein Tipp: \(ctx.name(t)) · noch im Spiel: \(who)" }
        else if !s.teilnehmer.contains(p) { sub = "Du bist mitten in der Runde dazugekommen · noch im Spiel: \(who)" }
        else { sub = "Noch im Spiel: \(who)" }
        return .cheer(title: "🥁 Anfeuern!", subtitle: sub, taps: s.cheers[p] ?? 0)
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed {
            let title: String
            if state.sieger.contains(player) { title = state.sieger.count == 1 ? "🏆 DER LETZTE AFFE!" : "🪂 Überlebt!" }
            else if let q = rausBei(state, player) { title = "💀 Raus in Frage \(q)" }
            else { title = "Zugeschaut" }
            return .reveal(title: title, correct: outcomes(state, ctx: ctx)[player]?.correct ?? nil, delta: total(state, player),
                           detail: detail(state, player, ctx: ctx), streak: 0, speedBonus: nil)
        }
        switch state.phase {
        case "frage":
            guard state.alive.contains(player), let core = state.core else { return zuschauerPrompt(state, player, ctx: ctx) }
            let n = lebend(state, ctx: ctx).count
            return core.prompt(for: player, ctx: NeueFormate.frageKontext(ctx, nummer: state.index + 1, gesamt: state.gesamt), revealed: false,
                               hint: "🪂 Frage \(state.index + 1)/\(state.gesamt) · noch \(n) im Spiel — falsch = raus!")
        case "mini":
            let bank = Money.format(state.banked[player] ?? 0)
            if state.lastSurvivors.contains(player) {
                let left = state.alive.count
                let rest = left == 1 && state.teilnehmer.count >= 2 ? "Du bist der letzte Affe!" : "Noch \(left) im Spiel"
                return .reveal(title: state.gnade ? "😅 Gnade — alle falsch, keiner fliegt!" : "✅ Überlebt!", correct: state.gnade ? nil : true,
                               delta: NeueFormate.betrag(state.wert, NeueFormate.Anteil.ueberlebt), detail: "\(rest) · gesichert: \(bank)", streak: 0, speedBonus: nil)
            }
            if state.lastOut.contains(player) {
                let loesung = state.letzteRichtig.map { "Richtig war: \($0) · " } ?? ""
                return .reveal(title: "💀 Raus!", correct: false, delta: 0, detail: "\(loesung)gesichert: \(bank)", streak: 0, speedBonus: nil)
            }
            return zuschauerPrompt(state, player, ctx: ctx)
        default:
            return .idle(title: "🪂 Auswertung …", subtitle: "Gleich steht der letzte Affe fest")
        }
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        if state.phase == "fertig" {
            var answers: [PlayerId: String] = [:]
            for p in ctx.players { answers[p] = "\(detail(state, p, ctx: ctx)) · \(Money.formatDelta(total(state, p)))" }
            let names = state.sieger.map { ctx.name($0) }.joined(separator: ", ")
            return (NeueFormate.gmRunde("letzter-affe-runde", "🪂 Der letzte Affe — Sieger: \(names.isEmpty ? "keiner" : names)", ctx: ctx), answers)
        }
        guard let core = state.core else { return (nil, [:]) }
        var g = core.gmInfo(ctx: ctx)
        for o in state.out {
            let tip = state.tipps[o.player].map { " · Tipp: \(ctx.name($0))" } ?? ""
            g.answers[o.player] = "💀 raus in Frage \(o.atQuestion)\(tip)"
        }
        return g
    }

    public static func questionsUsed(_ state: State) -> Int { max(1, state.verbraucht) }
}
