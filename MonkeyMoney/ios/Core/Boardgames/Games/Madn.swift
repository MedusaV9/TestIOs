import Foundation

/// Affen ärgern sich nicht (MADN) — 2–4, mixed seats. Classic box rules:
/// 6 to start (3 tries only when nothing else could move), every 6 grants an
/// extra roll, capturing on ALL ring fields, exact landing in the target lane,
/// first to bring all tokens home wins (short variant: 2 tokens).
public enum Madn: BoardgamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var sitze: [String]
        public var tokens: [MadnToken] // pos: -1 house, 0..39 ring (absolute), 100+lane index
        public var current: Int
        public var dice: Int?
        public var tries: Int
        public var seq: Int
        public var message: String?
        public var winner: String?
        public var kurz: Bool
        public var turnDeadline: Millis
        public var extraRoll: Bool
        public var finished: [String]
    }

    public static let meta = BoardgameMeta(
        id: "madn", name: "Affen ärgern sich nicht", emoji: "🎲", untertitel: "Der Würfel-Klassiker · 2–4 Affen",
        minSpieler: 2, maxSpieler: 4, phonesOnly: false, gemischteSitze: true,
        howto: ["Würfle eine 6, um einen Affen aus dem Haus zu holen. Jede 6 schenkt einen Extra-Wurf — steht kein Affe draußen, hast du drei Versuche.",
                "Zieh deine Affen um das Kreuz. Landest du auf einem fremden Affen, schlägst du ihn zurück ins Haus — auch auf Startfeldern!",
                "Ins Ziel kommst du nur mit exakter Zahl. Wer zuerst alle Affen im Ziel hat, gewinnt. Kurze Partie: 2 Affen, Klassisch: 4."],
        varianten: ["kurz", "klassisch"], halbePayout: false
    )

    static let ring = 40
    static let turnMs = 30_000

    static func start(of seat: Int) -> Int { seat * 10 }
    static func entry(of seat: Int) -> Int { (seat * 10 + 39) % ring } // last ring field before the lane

    public static func initState(ctx: inout BoardgameContext) -> State {
        let kurz = ctx.optionen["variante"]?.stringValue != "klassisch"
        var tokens: [MadnToken] = []
        for (si, s) in ctx.sitze.enumerated() { for t in 0..<(kurz ? 2 : 4) { tokens.append(MadnToken(sitz: s, index: si * 10 + t, pos: -1)) } }
        return State(sitze: ctx.sitze, tokens: tokens, current: 0, dice: nil, tries: 0, seq: 0, message: "\(ctx.name(ctx.sitze[0])) beginnt — würfeln!", winner: nil, kurz: kurz,
                     turnDeadline: ctx.now + ctx.ms(turnMs), extraRoll: false, finished: [])
    }

    static func seatIndex(_ s: State, _ sitz: String) -> Int { s.sitze.firstIndex(of: sitz) ?? 0 }
    static func seatOf(_ s: State) -> String { s.sitze[s.current % s.sitze.count] }

    /// Ring distance travelled by a token of `seat` (0 = its start field).
    static func travelled(_ pos: Int, seat: Int) -> Int { ((pos - start(of: seat)) % ring + ring) % ring }

    static func target(_ s: State, token: MadnToken, dice: Int) -> Int? {
        let seat = seatIndex(s, token.sitz)
        if token.pos == -1 { return dice == 6 ? start(of: seat) : nil }
        if token.pos >= 100 {
            let lane = token.pos - 100 + dice
            return lane < 4 ? 100 + lane : nil
        }
        let t = travelled(token.pos, seat: seat) + dice
        if t <= 39 { return (start(of: seat) + t) % ring }
        let lane = t - 40
        return lane < 4 ? 100 + lane : nil
    }

    static func legalMoves(_ s: State, sitz: String, dice: Int) -> [(Int, Int)] {
        var out: [(Int, Int)] = []
        for (i, tok) in s.tokens.enumerated() where tok.sitz == sitz {
            guard let t = target(s, token: tok, dice: dice) else { continue }
            // Own token blocks; in the lane no jumping over own tokens.
            if s.tokens.contains(where: { $0.sitz == sitz && $0.pos == t }) { continue }
            if t >= 100, tok.pos >= 100 { if s.tokens.contains(where: { $0.sitz == sitz && $0.pos > tok.pos && $0.pos < t }) { continue } }
            if t >= 100, tok.pos < 100 { if s.tokens.contains(where: { $0.sitz == sitz && $0.pos >= 100 && $0.pos < t }) { continue } }
            out.append((i, t))
        }
        return out
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from sitz: String, ctx: inout BoardgameContext) {
        guard state.winner == nil, seatOf(state) == sitz else { return }
        switch action {
        case .button(let b) where b == "wuerfeln" && state.dice == nil:
            roll(&state, ctx: &ctx)
        case .choose(let tokenIndex):
            guard let d = state.dice else { return }
            let moves = legalMoves(state, sitz: sitz, dice: d)
            guard let m = moves.first(where: { $0.0 == tokenIndex }) else { return }
            move(&state, tokenIndex: m.0, to: m.1, ctx: &ctx)
        default: break
        }
    }

    static func roll(_ s: inout State, ctx: inout BoardgameContext) {
        let d = ctx.rng.int(in: 1...6)
        s.dice = d
        s.seq += 1
        let sitz = seatOf(s)
        let moves = legalMoves(s, sitz: sitz, dice: d)
        if moves.isEmpty {
            let hasOut = s.tokens.contains { $0.sitz == sitz && $0.pos != -1 && $0.pos < 100 }
            s.tries += 1
            if !hasOut, s.tries < 3, d != 6 {
                s.message = "\(ctx.name(sitz)) würfelt \(d) — Versuch \(s.tries)/3"
                s.dice = nil
                return
            }
            s.message = "\(ctx.name(sitz)) würfelt \(d) — kein Zug möglich"
            s.dice = nil
            s.tries = 0
            if d == 6 { s.extraRoll = true; s.message! += " (Extra-Wurf)"; s.turnDeadline = ctx.now + ctx.ms(turnMs); return }
            nextSeat(&s, ctx: ctx)
        } else if moves.count == 1 {
            s.message = "\(ctx.name(sitz)) würfelt \(d)"
            move(&s, tokenIndex: moves[0].0, to: moves[0].1, ctx: &ctx)
        } else {
            s.message = "\(ctx.name(sitz)) würfelt \(d) — Affe wählen"
        }
    }

    static func move(_ s: inout State, tokenIndex: Int, to t: Int, ctx: inout BoardgameContext) {
        let sitz = seatOf(s)
        if t < 100, let victim = s.tokens.firstIndex(where: { $0.pos == t && $0.sitz != sitz }) {
            s.tokens[victim].pos = -1
            s.message = "💥 \(ctx.name(sitz)) schlägt \(ctx.name(s.tokens[victim].sitz))!"
        }
        s.tokens[tokenIndex].pos = t
        s.seq += 1
        let mine = s.tokens.filter { $0.sitz == sitz }
        if mine.allSatisfy({ $0.pos >= 100 }) {
            s.finished.append(sitz)
            s.winner = sitz
            s.message = "🏆 \(ctx.name(sitz)) hat alle Affen im Ziel!"
            return
        }
        let six = s.dice == 6
        s.dice = nil
        s.tries = 0
        if six { s.extraRoll = true; s.turnDeadline = ctx.now + ctx.ms(turnMs); s.message = (s.message ?? "") + " · Extra-Wurf!" } else { nextSeat(&s, ctx: ctx) }
    }

    static func nextSeat(_ s: inout State, ctx: BoardgameContext) {
        s.current = (s.current + 1) % s.sitze.count
        s.extraRoll = false
        s.tries = 0
        s.dice = nil
        s.turnDeadline = ctx.now + ctx.ms(turnMs)
    }

    public static func tick(_ state: inout State, ctx: inout BoardgameContext) {
        guard state.winner == nil else { return }
        let sitz = seatOf(state)
        guard !sitz.hasPrefix("lokal_") else { return }
        if ctx.now >= state.turnDeadline || !ctx.connected.contains(sitz) {
            // AFK auto move: capture > lane > start > frontmost.
            if state.dice == nil { roll(&state, ctx: &ctx) }
            if let d = state.dice {
                let moves = legalMoves(state, sitz: sitz, dice: d)
                if let best = moves.max(by: { a, b in score(state, a, sitz) < score(state, b, sitz) }) { move(&state, tokenIndex: best.0, to: best.1, ctx: &ctx) }
            }
            state.turnDeadline = ctx.now + ctx.ms(turnMs)
        }
    }

    static func score(_ s: State, _ m: (Int, Int), _ sitz: String) -> Int {
        if m.1 < 100, s.tokens.contains(where: { $0.pos == m.1 && $0.sitz != sitz }) { return 100 }
        if m.1 >= 100 { return 50 }
        if s.tokens[m.0].pos == -1 { return 40 }
        return travelled(m.1, seat: seatIndex(s, sitz))
    }

    public static func isFinished(_ state: State) -> Bool { state.winner != nil }

    public static func results(_ state: State, ctx: BoardgameContext) -> [(sitz: String, platz: Int, detail: String)] {
        let n = state.kurz ? 2 : 4
        func progress(_ sitz: String) -> Int {
            state.tokens.filter { $0.sitz == sitz }.reduce(0) { acc, t in acc + (t.pos >= 100 ? 50 : (t.pos == -1 ? 0 : travelled(t.pos, seat: seatIndex(state, sitz)))) }
        }
        let sorted = state.sitze.sorted { a, b in
            if a == state.winner { return true }
            if b == state.winner { return false }
            return progress(a) > progress(b)
        }
        return sorted.enumerated().map { (i, s) in (s, i + 1, "\(state.tokens.filter { $0.sitz == s && $0.pos >= 100 }.count)/\(n) Affen im Ziel") }
    }

    public static func scene(_ state: State, ctx: BoardgameContext) -> BoardgameScene {
        .madn(tokens: state.tokens, current: seatOf(state), dice: state.dice, seq: state.seq, message: state.message, kurz: state.kurz, deadline: state.turnDeadline)
    }

    public static func prompt(_ state: State, sitz: String, ctx: BoardgameContext) -> PlayerPrompt {
        if let w = state.winner { return .idle(title: w == sitz ? "🏆 Gewonnen!" : "\(ctx.name(w)) gewinnt", subtitle: nil) }
        guard seatOf(state) == sitz else { return .idle(title: "\(ctx.name(seatOf(state))) ist dran", subtitle: state.message) }
        if let d = state.dice {
            let moves = legalMoves(state, sitz: sitz, dice: d)
            let opts = state.tokens.enumerated().filter { $0.element.sitz == sitz }.map { (i, t) in
                ChoiceOption(id: i, text: t.pos == -1 ? "🏠 Affe im Haus" : (t.pos >= 100 ? "🎯 Zielfeld \(t.pos - 99)" : "Feld \(travelled(t.pos, seat: seatIndex(state, sitz)))"), removed: !moves.contains { $0.0 == i })
            }
            return .choice(question: "🎲 \(d) gewürfelt — welchen Affen ziehst du?", options: opts, chosen: nil, deadline: state.turnDeadline, secondTry: false, hint: nil)
        }
        return .actions(title: "Du bist dran!", lines: [state.message ?? ""], buttons: [ActionButton(id: "wuerfeln", label: "🎲 Würfeln")], deadline: state.turnDeadline)
    }

    public static func currentSeat(_ state: State) -> String? { seatOf(state) }
    public static func shift(_ state: inout State, ms: Int) { state.turnDeadline += ms }
}
