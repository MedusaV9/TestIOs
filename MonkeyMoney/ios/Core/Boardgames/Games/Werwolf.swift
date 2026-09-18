import Foundation

/// Werwölfe vom Bananenhain — 5–12 players, phones only. Roles: Werwolf,
/// Dorfaffe, Seherin, Hexe. Server-timed night/day cycles, ghosts see all,
/// role-filtered prompts (the stage never sees a secret).
public enum Werwolf: BoardgamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var roles: [String: String]
        public var alive: [String]
        public var dead: [String]
        public var phase: String // rollen | nacht-wolf | nacht-seherin | nacht-hexe | morgen | tag | lynch | ende
        public var deadline: Millis
        public var day: Int
        public var wolfVotes: [String: String]
        public var lynchVotes: [String: String]
        public var ready: [String]
        public var victim: String?
        public var healed: Bool
        public var poisoned: String?
        public var heilTrank: Bool
        public var giftTrank: Bool
        public var seherLog: [String]
        public var seherPick: String?
        public var lastLynched: String?
        public var lastDied: [String]
        public var winner: String?
        public var narration: String
        public var notruheBis: Millis?
        public var hexeGiftModus: Bool
    }

    public static let meta = BoardgameMeta(
        id: "werwolf", name: "Werwölfe vom Bananenhain", emoji: "🐺", untertitel: "Social Deduction · 5–12 Affen",
        minSpieler: 5, maxSpieler: 12, phonesOnly: true, gemischteSitze: false,
        howto: ["Jeder bekommt geheim eine Rolle aufs Handy: Werwolf, Dorfaffe, Seherin oder Hexe.",
                "Nachts reißen die Wölfe einen Affen, die Seherin blickt in eine Seele, die Hexe hat einen Heil- und einen Gifttrank.",
                "Am Tag diskutiert das Dorf und lyncht per Mehrheit einen Verdächtigen. Das Dorf gewinnt, wenn alle Wölfe tot sind — die Wölfe, wenn sie das Dorf überrennen."],
        varianten: [], halbePayout: false
    )

    static func wolfCount(_ n: Int) -> Int { n >= 11 ? 3 : (n >= 8 ? 2 : 1) }

    public static func initState(ctx: inout BoardgameContext) -> State {
        var roles: [String: String] = [:]
        let order = ctx.rng.shuffled(ctx.sitze)
        let wolves = wolfCount(order.count)
        for (i, s) in order.enumerated() {
            if i < wolves { roles[s] = "werwolf" } else if i == wolves { roles[s] = "seherin" } else if i == wolves + 1 { roles[s] = "hexe" } else { roles[s] = "dorfaffe" }
        }
        return State(roles: roles, alive: ctx.sitze, dead: [], phase: "rollen", deadline: ctx.now + ctx.ms(14_000), day: 0, wolfVotes: [:], lynchVotes: [:], ready: [],
                     victim: nil, healed: false, poisoned: nil, heilTrank: true, giftTrank: true, seherLog: [], seherPick: nil, lastLynched: nil, lastDied: [], winner: nil,
                     narration: "Die Rollen werden verteilt … schaut heimlich auf euer Handy!", notruheBis: nil, hexeGiftModus: false)
    }

    static func aliveWith(_ s: State, role: String) -> [String] { s.alive.filter { s.roles[$0] == role } }

    public static func reduce(_ state: inout State, action: PlayerAction, from sitz: String, ctx: inout BoardgameContext) {
        guard state.alive.contains(sitz) else { return }
        let role = state.roles[sitz] ?? "dorfaffe"
        switch (state.phase, action) {
        case ("nacht-wolf", .pickPlayer(let v)):
            guard role == "werwolf", state.alive.contains(v), state.roles[v] != "werwolf" else { return }
            state.wolfVotes[sitz] = v
        case ("nacht-seherin", .pickPlayer(let v)):
            guard role == "seherin", state.alive.contains(v), state.seherPick == nil else { return }
            state.seherPick = v
            state.seherLog.append("\(ctx.name(v)) ist \(roleName(state.roles[v] ?? ""))")
        case ("nacht-hexe", .button(let b)):
            guard role == "hexe" else { return }
            if b == "heilen", state.heilTrank, state.victim != nil { state.healed = true; state.heilTrank = false }
            if b == "gift", state.giftTrank { state.hexeGiftModus = true }
            if b == "zurueck" { state.hexeGiftModus = false }
            if b == "nichts" { state.ready.append(sitz) }
        case ("nacht-hexe", .pickPlayer(let v)):
            guard role == "hexe", state.hexeGiftModus, state.giftTrank, state.alive.contains(v) else { return }
            state.poisoned = v
            state.giftTrank = false
            state.hexeGiftModus = false
            state.ready.append(sitz)
        case ("tag", .confirm):
            if !state.ready.contains(sitz) { state.ready.append(sitz) }
        case ("lynch", .pickPlayer(let v)):
            guard state.alive.contains(v) else { return }
            state.lynchVotes[sitz] = v
        default: break
        }
    }

    static func roleName(_ r: String) -> String {
        switch r {
        case "werwolf": return "ein Werwolf 🐺"
        case "seherin": return "die Seherin 🔮"
        case "hexe": return "die Hexe 🧪"
        default: return "ein Dorfaffe 🐒"
        }
    }

    public static func tick(_ state: inout State, ctx: inout BoardgameContext) {
        guard state.winner == nil else { return }
        let done: Bool
        switch state.phase {
        case "rollen":
            done = ctx.now >= state.deadline
        case "nacht-wolf":
            let wolves = aliveWith(state, role: "werwolf").filter { ctx.connected.contains($0) }
            done = ctx.now >= state.deadline || (!wolves.isEmpty && wolves.allSatisfy { state.wolfVotes[$0] != nil }) || wolves.isEmpty && ctx.now >= min(state.deadline, state.notruheBis ?? state.deadline)
        case "nacht-seherin":
            let seer = aliveWith(state, role: "seherin").filter { ctx.connected.contains($0) }
            done = ctx.now >= state.deadline || (seer.isEmpty ? true : state.seherPick != nil && ctx.now >= state.deadline - ctx.ms(30_000) + ctx.ms(6000))
        case "nacht-hexe":
            let hexe = aliveWith(state, role: "hexe").filter { ctx.connected.contains($0) }
            done = ctx.now >= state.deadline || hexe.isEmpty || (!state.heilTrank && !state.giftTrank) || hexe.allSatisfy { state.ready.contains($0) } || state.poisoned != nil
        case "morgen", "abend":
            done = ctx.now >= state.deadline
        case "tag":
            let active = state.alive.filter { ctx.connected.contains($0) }
            done = ctx.now >= state.deadline || (!active.isEmpty && active.allSatisfy { state.ready.contains($0) })
        case "lynch":
            let active = state.alive.filter { ctx.connected.contains($0) }
            done = ctx.now >= state.deadline || (!active.isEmpty && active.allSatisfy { state.lynchVotes[$0] != nil })
        default:
            done = false
        }
        // Emergency sleep: nobody who could act is connected ⇒ 8-s window.
        if !done, ["nacht-wolf", "nacht-seherin", "nacht-hexe", "tag", "lynch"].contains(state.phase) {
            let actors: [String]
            switch state.phase {
            case "nacht-wolf": actors = aliveWith(state, role: "werwolf")
            case "nacht-seherin": actors = aliveWith(state, role: "seherin")
            case "nacht-hexe": actors = aliveWith(state, role: "hexe")
            default: actors = state.alive
            }
            if actors.filter({ ctx.connected.contains($0) }).isEmpty {
                if state.notruheBis == nil { state.notruheBis = ctx.now + 8000; state.deadline = min(state.deadline, state.notruheBis!) }
            } else { state.notruheBis = nil }
        }
        if done { advance(&state, ctx: &ctx) }
    }

    static func advance(_ s: inout State, ctx: inout BoardgameContext) {
        s.notruheBis = nil
        switch s.phase {
        case "rollen", "abend":
            s.day += 1
            s.phase = "nacht-wolf"
            s.wolfVotes = [:]
            s.victim = nil
            s.healed = false
            s.poisoned = nil
            s.seherPick = nil
            s.ready = []
            s.hexeGiftModus = false
            s.deadline = ctx.now + ctx.ms(40_000)
            s.narration = "🌙 Nacht \(s.day): Die Wölfe erwachen und wählen ihr Opfer …"
        case "nacht-wolf":
            var counts: [String: Int] = [:]
            for v in s.wolfVotes.values { counts[v, default: 0] += 1 }
            s.victim = counts.max { a, b in a.value != b.value ? a.value < b.value : ctx.rng.next() < 0.5 }?.key
            if aliveWith(s, role: "seherin").isEmpty {
                enterHexe(&s, ctx: &ctx)
            } else {
                s.phase = "nacht-seherin"
                s.deadline = ctx.now + ctx.ms(30_000)
                s.narration = "🔮 Die Seherin blickt heimlich in eine Seele …"
            }
        case "nacht-seherin":
            enterHexe(&s, ctx: &ctx)
        case "nacht-hexe":
            var died: [String] = []
            if let v = s.victim, !s.healed { died.append(v) }
            if let p = s.poisoned, !died.contains(p) { died.append(p) }
            for d in died { s.alive.removeAll { $0 == d }; s.dead.append(d) }
            s.lastDied = died
            s.phase = "morgen"
            s.deadline = ctx.now + ctx.ms(9000)
            s.narration = died.isEmpty ? "☀️ Morgengrauen — alle Affen leben!" : "☀️ Morgengrauen — \(died.map { ctx.name($0) }.joined(separator: " und ")) wurde\(died.count > 1 ? "n" : "") gefunden …"
            if let w = winner(s) { finish(&s, w, ctx: ctx) }
        case "morgen":
            s.phase = "tag"
            s.ready = []
            s.deadline = ctx.now + ctx.ms(60_000)
            s.narration = "☕ Tag \(s.day): Diskutiert! Wer ist verdächtig? (Bereit-Knopf verkürzt)"
        case "tag":
            s.phase = "lynch"
            s.lynchVotes = [:]
            s.deadline = ctx.now + ctx.ms(30_000)
            s.narration = "⚖️ Das Dorf stimmt ab: Wer wird gelyncht?"
        case "lynch":
            var counts: [String: Int] = [:]
            for v in s.lynchVotes.values { counts[v, default: 0] += 1 }
            let sorted = counts.sorted { $0.value > $1.value }
            if let top = sorted.first, sorted.count == 1 || top.value > sorted[1].value {
                s.alive.removeAll { $0 == top.key }
                s.dead.append(top.key)
                s.lastLynched = top.key
                s.narration = "⚖️ Das Dorf lyncht \(ctx.name(top.key)) — \(roleName(s.roles[top.key] ?? ""))!"
            } else {
                s.lastLynched = nil
                s.narration = "⚖️ Patt — niemand wird gelyncht."
            }
            if let w = winner(s) { finish(&s, w, ctx: ctx); return }
            s.phase = "abend"
            s.deadline = ctx.now + ctx.ms(6000)
        default: break
        }
    }

    static func enterHexe(_ s: inout State, ctx: inout BoardgameContext) {
        s.phase = "nacht-hexe"
        s.deadline = ctx.now + ctx.ms(25_000)
        s.narration = "🧪 Heiltrank oder Gifttrank? Die Hexe wägt ab …"
        if aliveWith(s, role: "hexe").isEmpty || (!s.heilTrank && !s.giftTrank) { advance(&s, ctx: &ctx) }
    }

    static func winner(_ s: State) -> String? {
        let wolves = aliveWith(s, role: "werwolf").count
        let village = s.alive.count - wolves
        if wolves == 0 { return "dorf" }
        if wolves >= village { return "woelfe" }
        return nil
    }

    static func finish(_ s: inout State, _ w: String, ctx: BoardgameContext) {
        s.winner = w
        s.phase = "ende"
        s.narration = w == "dorf" ? "🎉 Der Bananenhain siegt — alle Wölfe sind entlarvt!" : "🐺 Die Wölfe haben den Hain überrannt!"
    }

    public static func isFinished(_ state: State) -> Bool { state.winner != nil }

    public static func results(_ state: State, ctx: BoardgameContext) -> [(sitz: String, platz: Int, detail: String)] {
        guard let w = state.winner else { return [] }
        return ctx.sitze.map { s in
            let isWolf = state.roles[s] == "werwolf"
            let won = (w == "woelfe") == isWolf
            let survived = state.alive.contains(s)
            return (s, won ? (survived ? 1 : 2) : 3, "\(roleName(state.roles[s] ?? ""))\(survived ? " · überlebt" : "")")
        }
    }

    public static func scene(_ state: State, ctx: BoardgameContext) -> BoardgameScene {
        .werwolf(phase: state.phase, alive: state.alive, dead: state.dead, text: state.narration, dayNumber: state.day, deadline: state.deadline,
                 lastLynched: state.lastLynched, revealRoles: state.winner != nil ? state.roles : nil)
    }

    public static func prompt(_ state: State, sitz: String, ctx: BoardgameContext) -> PlayerPrompt {
        let role = state.roles[sitz] ?? "dorfaffe"
        let roleTitle = "Du bist \(roleName(role))"
        if state.winner != nil { return .idle(title: state.narration, subtitle: roleTitle) }
        if !state.alive.contains(sitz) {
            let secrets = state.alive.map { "\(ctx.name($0)): \(roleName(state.roles[$0] ?? ""))" }.joined(separator: "\n")
            return .idle(title: "👻 Du bist tot — psst!", subtitle: "Geister sehen alles:\n" + secrets)
        }
        func refs(_ ids: [String]) -> [PlayerRef] { ids.map { PlayerRef(Player(id: $0, name: ctx.name($0), avatar: Avatar(), joinOrder: 0), platz: 0) } }
        switch state.phase {
        case "rollen":
            var extra = ""
            if role == "werwolf" { extra = "Dein Rudel: " + aliveWith(state, role: "werwolf").filter { $0 != sitz }.map { ctx.name($0) }.joined(separator: ", ") }
            return .idle(title: roleTitle, subtitle: extra.isEmpty ? "Verrate es niemandem!" : extra)
        case "nacht-wolf":
            if role == "werwolf" { return .pickPlayer(title: "🐺 Wen reißt das Rudel?", subtitle: "Dein Rudel: " + aliveWith(state, role: "werwolf").filter { $0 != sitz }.map { ctx.name($0) }.joined(separator: ", "), candidates: refs(state.alive.filter { state.roles[$0] != "werwolf" }), chosen: state.wolfVotes[sitz], deadline: state.deadline) }
            return .idle(title: "🌙 Nacht", subtitle: "Augen zu … \(roleTitle)")
        case "nacht-seherin":
            if role == "seherin" {
                if let p = state.seherPick { return .idle(title: "🔮 \(ctx.name(p)) ist \(roleName(state.roles[p] ?? ""))", subtitle: state.seherLog.joined(separator: "\n")) }
                return .pickPlayer(title: "🔮 In wessen Seele blickst du?", subtitle: state.seherLog.isEmpty ? nil : state.seherLog.joined(separator: "\n"), candidates: refs(state.alive.filter { $0 != sitz }), chosen: nil, deadline: state.deadline)
            }
            return .idle(title: "🌙 Nacht", subtitle: "Augen zu … \(roleTitle)")
        case "nacht-hexe":
            if role == "hexe" {
                let lines = [state.victim.map { "Opfer der Nacht: \(ctx.name($0))" } ?? "Die Wölfe haben niemanden gerissen.", "Heiltrank: \(state.heilTrank ? "✅" : "❌") · Gifttrank: \(state.giftTrank ? "✅" : "❌")"]
                if state.hexeGiftModus {
                    return .pickPlayer(title: "🧪 Wen vergiftest du?", subtitle: "Knopf „zurück“ gibt es nicht — wähle weise", candidates: refs(state.alive.filter { $0 != sitz }), chosen: state.poisoned, deadline: state.deadline)
                }
                var buttons: [ActionButton] = []
                if state.heilTrank, state.victim != nil, !state.healed { buttons.append(ActionButton(id: "heilen", label: "💚 Heiltrank für \(ctx.name(state.victim!))", style: "primary")) }
                if state.giftTrank { buttons.append(ActionButton(id: "gift", label: "☠️ Gifttrank einsetzen", style: "danger")) }
                buttons.append(ActionButton(id: "nichts", label: "Nichts tun", style: "secondary"))
                return .actions(title: "🧪 Die Hexe", lines: lines + (state.healed ? ["💚 Geheilt!"] : []), buttons: buttons, deadline: state.deadline)
            }
            return .idle(title: "🌙 Nacht", subtitle: "Augen zu … \(roleTitle)")
        case "morgen", "abend":
            return .idle(title: state.narration, subtitle: roleTitle)
        case "tag":
            return .confirm(title: "☕ Diskussion", subtitle: state.lastDied.isEmpty ? "Alle leben." : "Tot: \(state.lastDied.map { ctx.name($0) }.joined(separator: ", "))", button: "Bereit zum Abstimmen", done: state.ready.contains(sitz), deadline: state.deadline)
        case "lynch":
            return .pickPlayer(title: "⚖️ Wer wird gelyncht?", subtitle: roleTitle, candidates: refs(state.alive.filter { $0 != sitz }), chosen: state.lynchVotes[sitz], deadline: state.deadline)
        default:
            return .idle(title: state.narration, subtitle: roleTitle)
        }
    }

    public static func shift(_ state: inout State, ms: Int) { state.deadline += ms }
}


