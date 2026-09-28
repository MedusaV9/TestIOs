import Foundation

/// Kokos-Kopf — memory. The stage shows a sequence of distinct jungle symbols
/// one at a time (4, then 5, 6, 7 …); the phones get the same symbols shuffled
/// and sort them back. Fully right = 0.5 F, otherwise 0.08 F per right
/// position; the fastest fully right player gets +0.2 F.
public enum KokosKopf: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var schritt: Int
        public var gesamt: Int
        /// "zeigen" | "eingeben" | "aufloesung" | "fertig"
        public var phase: String
        /// Symbol indices in the order shown.
        public var sequenz: [Int]
        /// The same symbols shuffled — the phone list starts in this order.
        public var startOrder: [Int]
        public var zeigenAb: Millis
        public var symbolMs: Int
        public var zeigenBis: Millis
        public var startedAt: Millis
        public var deadline: Millis
        public var timerMs: Int
        public var revealUntil: Millis?
        public var wert: Int
        public var orders: [PlayerId: [Int]]
        public var lockedAt: [PlayerId: Millis]
        public var punkte: [PlayerId: Int]
        public var perfektAnzahl: [PlayerId: Int]
        public var positionen: [PlayerId: Int]
        public var beantwortet: [PlayerId: Int]
        public var lastPoints: [PlayerId: Int]
        public var lastRichtige: [PlayerId: Int]
        public var lastPerfekt: [PlayerId]
        public var lastSchnellster: [PlayerId]
        public var gespielt: Int
    }

    public static let meta = MinigameMeta(
        id: "kokos-kopf", name: "Kokos-Kopf", emoji: "🧠",
        kurz: "Merk dir die Dschungel-Symbole in ihrer Reihenfolge — und sortiere sie auf dem Handy zurück.",
        erklaerung: "Gedächtnis-Training im Dschungel: Auf der Bühne erscheinen Symbole nacheinander — Banane, Kokosnuss, Affe … erst vier, dann fünf, sechs, sieben. Danach bekommst du dieselben Symbole durcheinander aufs Handy und bringst sie in die richtige Reihenfolge. Alles richtig: 0,5× Fragenwert, sonst 0,08× pro richtiger Position. Wer als Schnellster alles richtig hat, bekommt +0,2× obendrauf.",
        regeln: ["Symbole erscheinen nacheinander auf der Bühne — gut merken!",
                 "Jede Runde ein Symbol mehr: 4, 5, 6, 7 …",
                 "Auf dem Handy die Symbole in die richtige Reihenfolge bringen",
                 "Alles richtig: 0,5× Fragenwert · sonst 0,08× pro richtiger Position",
                 "Schnellster mit allem richtig: +0,2× obendrauf"],
        gewinn: "Alles richtig 0,5× Fragenwert · pro richtiger Position 0,08× · Schnellster Perfekter +0,2×",
        contentKind: .none, roundBased: true, streak: false, jokerAktionen: [], isMc: false, musik: "pixel_retro", v2: true
    )

    /// The jungle symbols (distinct inside one sequence).
    public static let symbole: [(emoji: String, name: String)] = [
        ("🍌", "Banane"), ("🥥", "Kokosnuss"), ("🐒", "Affe"), ("🌴", "Palme"), ("🦜", "Papagei"), ("🐍", "Schlange"),
        ("🍍", "Ananas"), ("🦩", "Flamingo"), ("🐸", "Frosch"), ("🌺", "Blüte"), ("🍉", "Melone"), ("🦥", "Faultier"),
        ("🐘", "Elefant"), ("🦒", "Giraffe"), ("🐯", "Tiger"), ("🍇", "Trauben"), ("🦋", "Schmetterling"), ("🐊", "Krokodil"),
        ("🍄", "Pilz"), ("🦎", "Gecko"),
    ]

    static let startLaenge = 4
    static let maxLaenge = 9
    static let vorlaufMs = 1500
    static let symbolBasisMs = 900
    static let nachlaufMs = 500

    public static func laenge(schritt: Int) -> Int { min(maxLaenge, startLaenge + max(0, schritt)) }

    static func text(_ i: Int) -> String { "\(symbole[i].emoji) \(symbole[i].name)" }

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        var s = State(schritt: 0, gesamt: NeueFormate.schritte(ctx), phase: "zeigen", sequenz: [], startOrder: [], zeigenAb: ctx.now, symbolMs: 0,
                      zeigenBis: ctx.now, startedAt: ctx.now, deadline: ctx.now, timerMs: 0, revealUntil: nil, wert: NeueFormate.sectionWert(ctx: ctx),
                      orders: [:], lockedAt: [:], punkte: [:], perfektAnzahl: [:], positionen: [:], beantwortet: [:], lastPoints: [:],
                      lastRichtige: [:], lastPerfekt: [], lastSchnellster: [], gespielt: 0)
        start(&s, schritt: 0, ctx: &ctx)
        return s
    }

    static func start(_ s: inout State, schritt: Int, ctx: inout MinigameContext) {
        let n = laenge(schritt: schritt)
        s.schritt = schritt
        s.phase = "zeigen"
        s.sequenz = Array(ctx.rng.shuffled(Array(symbole.indices)).prefix(n))
        var order = ctx.rng.shuffled(s.sequenz)
        if order == s.sequenz { order.reverse() }
        s.startOrder = order
        s.symbolMs = ctx.ms(symbolBasisMs)
        s.zeigenAb = ctx.now + ctx.ms(vorlaufMs)
        s.zeigenBis = s.zeigenAb + n * s.symbolMs + ctx.ms(nachlaufMs)
        s.revealUntil = nil
        s.orders = [:]
        s.lockedAt = [:]
        s.lastPoints = [:]
        s.lastRichtige = [:]
        s.lastPerfekt = []
        s.lastSchnellster = []
    }

    static func eingeben(_ s: inout State, ctx: MinigameContext) {
        s.phase = "eingeben"
        s.timerMs = NeueFormate.fenster(12_000 + 2000 * s.sequenz.count, ctx: ctx)
        s.startedAt = ctx.now
        s.deadline = ctx.now + s.timerMs
    }

    /// Index of the symbol on screen right now (nil before the first / after the last).
    public static func zeigeIndex(_ s: State, now: Millis) -> Int? {
        guard s.phase == "zeigen", now >= s.zeigenAb, s.symbolMs > 0 else { return nil }
        let k = (now - s.zeigenAb) / s.symbolMs
        return k < s.sequenz.count ? k : nil
    }

    /// Right positions of one order against the sequence.
    public static func richtige(_ order: [Int], _ sequenz: [Int]) -> Int {
        zip(order, sequenz).filter { $0 == $1 }.count
    }

    /// One step's verdict — pure. Unconfirmed but sorted lists count (no speed bonus).
    public static func bewerte(_ eingaben: [(player: PlayerId, order: [Int]?, lockedAt: Millis?)], sequenz: [Int], wert: Int)
        -> (punkte: [PlayerId: Int], richtige: [PlayerId: Int], perfekt: [PlayerId], schnellster: [PlayerId]) {
        var punkte: [PlayerId: Int] = [:]
        var treffer: [PlayerId: Int] = [:]
        var perfekt: [PlayerId] = []
        for e in eingaben {
            guard let o = e.order, o.count == sequenz.count else { continue }
            let n = richtige(o, sequenz)
            treffer[e.player] = n
            if n == sequenz.count {
                perfekt.append(e.player)
                punkte[e.player] = NeueFormate.betrag(wert, NeueFormate.Anteil.kokosPerfekt)
            } else {
                punkte[e.player] = NeueFormate.betrag(wert, NeueFormate.Anteil.kokosPosition * Double(n))
            }
        }
        let zeiten = eingaben.filter { perfekt.contains($0.player) }.compactMap { e in e.lockedAt.map { (e.player, $0) } }
        var schnellster: [PlayerId] = []
        if let best = zeiten.map({ $0.1 }).min() {
            schnellster = zeiten.filter { $0.1 == best }.map { $0.0 }
            for p in schnellster { punkte[p, default: 0] += NeueFormate.betrag(wert, NeueFormate.Anteil.kokosSchnellster) }
        }
        return (punkte, treffer, perfekt, schnellster)
    }

    static func resolve(_ s: inout State, ctx: MinigameContext) {
        let eingaben = ctx.players.map { p in (player: p, order: s.orders[p], lockedAt: s.lockedAt[p]) }
        let b = bewerte(eingaben, sequenz: s.sequenz, wert: s.wert)
        for p in ctx.players where s.orders[p] != nil {
            s.beantwortet[p, default: 0] += 1
            s.punkte[p, default: 0] += b.punkte[p] ?? 0
            s.positionen[p, default: 0] += b.richtige[p] ?? 0
        }
        for p in b.perfekt { s.perfektAnzahl[p, default: 0] += 1 }
        s.lastPoints = b.punkte
        s.lastRichtige = b.richtige
        s.lastPerfekt = b.perfekt
        s.lastSchnellster = b.schnellster
        s.gespielt += 1
    }

    static func weiter(_ s: inout State, ctx: inout MinigameContext) {
        if s.schritt + 1 < s.gesamt { start(&s, schritt: s.schritt + 1, ctx: &ctx) } else { s.phase = "fertig"; s.revealUntil = nil }
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        guard state.phase == "eingeben", state.lockedAt[player] == nil, ctx.now <= state.deadline + ChoiceCore.graceMs else { return }
        switch action {
        case .order(let o):
            guard o.count == state.sequenz.count, Set(o) == Set(state.sequenz) else { return }
            state.orders[player] = o
        case .confirm, .button:
            if state.orders[player] == nil { state.orders[player] = state.startOrder }
            state.lockedAt[player] = ctx.now
        default:
            break
        }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        switch action {
        case .timerExtend(let ms):
            if state.phase == "eingeben" { state.deadline += ms; state.timerMs += ms }
        case .timerShift(let ms):
            state.zeigenAb += ms
            state.zeigenBis += ms
            state.startedAt += ms
            state.deadline += ms
            for (p, t) in state.lockedAt { state.lockedAt[p] = t + ms }
            if let r = state.revealUntil { state.revealUntil = r + ms }
        case .forceFinish:
            if state.phase == "eingeben", !state.orders.isEmpty { resolve(&state, ctx: ctx) }
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
        case "zeigen":
            if ctx.now >= state.zeigenBis { eingeben(&state, ctx: ctx) }
        case "eingeben":
            let done = ctx.now > state.deadline + ChoiceCore.graceMs || NeueFormate.alleDrin(NeueFormate.aktive(ctx: ctx)) { state.lockedAt[$0] != nil }
            if done {
                resolve(&state, ctx: ctx)
                state.phase = "aufloesung"
                state.revealUntil = ctx.now + ctx.ms(NeueFormate.Reveal.kokos)
            }
        case "aufloesung":
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
        var parts = ["\(s.perfektAnzahl[p] ?? 0)/\(s.gespielt) perfekt"]
        if let n = s.positionen[p], n > 0 { parts.append("\(n) richtige Positionen") }
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

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        let phase = revealed ? "fertig" : state.phase
        let emojis = state.sequenz.map { symbole[$0].emoji }
        let namen = state.sequenz.map { symbole[$0].name }
        let idx = zeigeIndex(state, now: ctx.now)
        let shown: [String]
        switch phase {
        case "zeigen": shown = idx.map { Array(emojis.prefix($0 + 1)) } ?? (ctx.now >= state.zeigenAb ? emojis : [])
        case "eingeben": shown = []
        default: shown = emojis
        }
        let full = phase != "eingeben"
        let extra = StageExtra.memory(schritt: state.schritt + 1, gesamt: state.gesamt, phase: phase, laenge: state.sequenz.count,
                                      zeigenAb: phase == "zeigen" ? state.zeigenAb : nil, symbolMs: state.symbolMs, zeigeIndex: phase == "zeigen" ? idx : nil,
                                      gezeigt: shown, sequenz: full ? emojis : nil, namen: full ? namen : nil,
                                      answered: ctx.players.filter { state.lockedAt[$0] != nil },
                                      deadline: phase == "eingeben" ? ctx.visible(state.deadline) : nil, timerMs: state.timerMs,
                                      richtige: phase == "aufloesung" || phase == "fertig" ? state.lastRichtige : [:],
                                      perfekt: phase == "aufloesung" || phase == "fertig" ? state.lastPerfekt : [],
                                      schnellster: phase == "aufloesung" || phase == "fertig" ? state.lastSchnellster.first : nil,
                                      points: phase == "aufloesung" ? state.lastPoints : [:], totals: state.punkte)
        let title: String
        switch phase {
        case "zeigen": title = "🧠 Schritt \(state.schritt + 1)/\(state.gesamt) · Gut aufpassen!"
        case "eingeben": title = "🧠 Schritt \(state.schritt + 1)/\(state.gesamt) · Jetzt sortieren!"
        case "aufloesung": title = "🧠 Schritt \(state.schritt + 1)/\(state.gesamt) · Auflösung"
        default: title = "🧠 Kokos-Kopf"
        }
        return MinigameStageOutput(wall: nil, extra: extra, title: title, audio: AudioCue(music: meta.musik))
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        let n = state.sequenz.count
        if revealed {
            let pts = state.punkte[player] ?? 0
            let perf = state.perfektAnzahl[player] ?? 0
            let title = pts == 0 ? ((state.beantwortet[player] ?? 0) > 0 ? "Kokosnuss-Hirn …" : "Nicht mitgespielt") : (perf == state.gespielt ? "🧠 KOKOS-GENIE!" : "🧠 Gut gemerkt!")
            return .reveal(title: title, correct: outcomes(state, ctx: ctx)[player]?.correct ?? nil, delta: pts, detail: detail(state, player), streak: 0, speedBonus: nil)
        }
        switch state.phase {
        case "zeigen":
            return .idle(title: "👀 Merk dir die Reihenfolge!", subtitle: "Schritt \(state.schritt + 1)/\(state.gesamt) · \(n) Symbole — schau auf den Bildschirm")
        case "eingeben":
            let items = state.startOrder.map { OrderItem(id: $0, text: text($0)) }
            return .order(question: "🧠 Schritt \(state.schritt + 1)/\(state.gesamt): In welcher Reihenfolge kamen die \(n) Symbole?", items: items,
                          order: state.orders[player] ?? state.startOrder, locked: state.lockedAt[player] != nil, deadline: ctx.visible(state.deadline))
        case "aufloesung":
            let loesung = state.sequenz.map { symbole[$0].emoji }.joined(separator: " → ")
            guard let r = state.lastRichtige[player] else {
                return .reveal(title: "⏰ Nichts eingeloggt", correct: nil, delta: 0, detail: "Richtig: \(loesung)", streak: 0, speedBonus: nil)
            }
            let pts = state.lastPoints[player] ?? 0
            if state.lastPerfekt.contains(player) {
                let fast = state.lastSchnellster.contains(player) ? " · ⚡ Schnellster +\(NeueFormate.faktor(NeueFormate.Anteil.kokosSchnellster))" : ""
                return .reveal(title: "🧠 PERFEKT!", correct: true, delta: pts, detail: "Alle \(n) richtig\(fast)", streak: 0, speedBonus: nil)
            }
            return .reveal(title: "\(r)/\(n) richtig", correct: r > 0 ? nil : false, delta: pts, detail: "Richtig: \(loesung)", streak: 0, speedBonus: nil)
        default:
            return .idle(title: "🧠 Auswertung …", subtitle: nil)
        }
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        if state.phase == "fertig" {
            var answers: [PlayerId: String] = [:]
            for p in ctx.players { answers[p] = "\(detail(state, p)) · \(Money.formatDelta(state.punkte[p] ?? 0))" }
            return (NeueFormate.gmRunde("kokos-kopf-runde", "🧠 Kokos-Kopf — \(state.gespielt) Schritte", ctx: ctx, typ: .sortier), answers)
        }
        let info = GmQuestionInfo(id: "kokos_\(state.schritt + 1)", text: "🧠 Schritt \(state.schritt + 1)/\(state.gesamt): \(state.sequenz.count) Symbole merken",
                                  kategorie: "Kokos-Kopf", schwierigkeit: ctx.section.schwierigkeiten.max() ?? .medium,
                                  korrekt: state.sequenz.map { symbole[$0].emoji }.joined(separator: " → "),
                                  erklaerung: state.sequenz.map { symbole[$0].name }.joined(separator: " → "), tipps: [], typ: .sortier)
        var answers: [PlayerId: String] = [:]
        for (p, o) in state.orders {
            let lock = state.lockedAt[p].map { " (\(String(format: "%.1f", Double(max(0, $0 - state.startedAt)) / 1000)) s)" } ?? " (sortiert noch)"
            answers[p] = "\(richtige(o, state.sequenz))/\(state.sequenz.count) · " + o.map { symbole[$0].emoji }.joined(separator: " ") + lock
        }
        return (info, answers)
    }

    /// No catalogue questions are consumed.
    public static func questionsUsed(_ state: State) -> Int { 0 }
}
