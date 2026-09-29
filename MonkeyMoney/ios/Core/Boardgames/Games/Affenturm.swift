import Foundation

/// Affenturm — the house creation: 5 towers × 8 steps. On every step all
/// climbers choose simultaneously & secretly: 🍌 climb on (collect the step
/// bananas) or 🪂 bail out (bank the loot). Collapse chance = min(50, 4·step
/// + 2·climbers) % — collective risk. Solo bonus ×2 if exactly one stays up.
public enum Affenturm: BoardgamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var tower: Int
        public var stufe: Int
        public var climbers: [String]
        public var loot: [String: Int]
        public var banked: [String: Int]
        public var choices: [String: String]
        public var deadline: Millis
        public var collapsed: Bool
        public var collapsedTower: Int?
        public var revealUntil: Millis?
        public var soloBonus: String?
        public var finished: Bool
        public var towersDone: [Int]
    }

    public static let meta = BoardgameMeta(
        id: "affenturm", name: "Affenturm", emoji: "🗼", untertitel: "Gier, Risiko und Table-Talk — die Eigenkreation",
        minSpieler: 2, maxSpieler: 8, phonesOnly: true, gemischteSitze: false,
        howto: ["Fünf Türme, jeder bis zu 8 Stufen hoch. Auf jeder Stufe wählen ALLE Kletterer gleichzeitig und geheim: 🍌 weiterklettern oder 🪂 abspringen.",
                "Weiterklettern sackt die Stufen-Bananen ein — aber der Turm wackelt: je höher und je mehr Affen oben, desto eher stürzt er ein. Wer drin ist, verliert die Beute des Turms.",
                "Abspringen bankt die Beute sicher. Bleibt GENAU EINER oben und der Turm hält, gibt es den Solo-Bonus ×2!"],
        varianten: [], halbePayout: true
    )

    static let stepLoot = [10, 20, 30, 40, 50, 60, 80, 100]
    static let towers = 5
    static let chooseMs = 12_000

    public static func initState(ctx: inout BoardgameContext) -> State {
        State(tower: 0, stufe: 0, climbers: ctx.sitze, loot: [:], banked: [:], choices: [:], deadline: ctx.now + ctx.ms(chooseMs), collapsed: false, collapsedTower: nil,
              revealUntil: nil, soloBonus: nil, finished: false, towersDone: [])
    }

    static func risk(stufe: Int, climbers: Int) -> Int { min(50, 4 * (stufe + 1) + 2 * climbers) }

    public static func reduce(_ state: inout State, action: PlayerAction, from sitz: String, ctx: inout BoardgameContext) {
        guard state.revealUntil == nil, state.climbers.contains(sitz), case .binary(let c) = action, c == "weiter" || c == "runter" else { return }
        state.choices[sitz] = c
    }

    public static func tick(_ state: inout State, ctx: inout BoardgameContext) {
        guard !state.finished else { return }
        if let r = state.revealUntil {
            if ctx.now >= r { nextStep(&state, ctx: &ctx) }
            return
        }
        let active = state.climbers.filter { ctx.connected.contains($0) }
        if ctx.now >= state.deadline || (!active.isEmpty && active.allSatisfy { state.choices[$0] != nil }) {
            resolve(&state, ctx: &ctx)
        }
    }

    static func resolve(_ s: inout State, ctx: inout BoardgameContext) {
        // AFK/disconnect default: bail out (sleepers never lose).
        var staying: [String] = []
        for c in s.climbers {
            let choice = s.choices[c] ?? "runter"
            if choice == "weiter" && ctx.connected.contains(c) {
                staying.append(c)
                s.loot[c, default: 0] += stepLoot[min(s.stufe, stepLoot.count - 1)]
            } else {
                s.banked[c, default: 0] += s.loot[c] ?? 0
                s.loot[c] = 0
            }
        }
        s.climbers = staying
        s.soloBonus = nil
        if !staying.isEmpty {
            let r = risk(stufe: s.stufe, climbers: staying.count)
            if ctx.rng.chance(Double(r) / 100) {
                s.collapsed = true
                s.collapsedTower = s.tower
                for c in staying { s.loot[c] = 0 }
                s.climbers = []
            } else if staying.count == 1 {
                let solo = staying[0]
                s.loot[solo, default: 0] *= 2
                s.soloBonus = solo
            }
        }
        s.revealUntil = ctx.now + ctx.ms(3500)
    }

    static func nextStep(_ s: inout State, ctx: inout BoardgameContext) {
        s.revealUntil = nil
        s.choices = [:]
        let top = s.stufe + 1 >= stepLoot.count
        if s.collapsed || s.climbers.isEmpty || top {
            // Top of the tower: forced banking.
            if top && !s.collapsed { for c in s.climbers { s.banked[c, default: 0] += s.loot[c] ?? 0; s.loot[c] = 0 } }
            s.towersDone.append(s.tower)
            s.tower += 1
            s.stufe = 0
            s.collapsed = false
            s.collapsedTower = nil
            s.climbers = ctx.sitze
            s.loot = [:]
            if s.tower >= towers { s.finished = true; return }
        } else {
            s.stufe += 1
        }
        s.deadline = ctx.now + ctx.ms(chooseMs)
    }

    public static func isFinished(_ state: State) -> Bool { state.finished }

    public static func results(_ state: State, ctx: BoardgameContext) -> [(sitz: String, platz: Int, detail: String)] {
        let sorted = ctx.sitze.sorted { (state.banked[$0] ?? 0) > (state.banked[$1] ?? 0) }
        var out: [(String, Int, String)] = []
        var place = 0
        var last: Int?
        for (i, s) in sorted.enumerated() {
            let b = state.banked[s] ?? 0
            if b != last { place = i + 1; last = b }
            out.append((s, place, "\(b) Bananen gesichert"))
        }
        return out
    }

    public static func scene(_ state: State, ctx: BoardgameContext) -> BoardgameScene {
        let towers = (0..<Self.towers).map { i in
            TowerView(index: i, height: i == state.tower ? state.stufe + 1 : (state.towersDone.contains(i) ? stepLoot.count : 0), climbers: i == state.tower ? state.climbers : [],
                      collapsed: state.collapsedTower == i, loot: i == state.tower ? state.loot.values.reduce(0, +) : 0)
        }
        return .towers(towers: towers, stufe: state.stufe, risiko: risk(stufe: state.stufe, climbers: max(1, state.climbers.count)), chosen: Array(state.choices.keys),
                       collapsedTower: state.collapsedTower, banked: state.banked, soloBonus: state.soloBonus)
    }

    public static func prompt(_ state: State, sitz: String, ctx: BoardgameContext) -> PlayerPrompt {
        if state.finished { return .idle(title: "Alle Türme bestiegen", subtitle: nil) }
        if state.revealUntil != nil {
            if state.collapsed { return .idle(title: state.loot[sitz] == 0 && state.choices[sitz] == "weiter" ? "💥 EINGESTÜRZT!" : "💥 Der Turm ist eingestürzt", subtitle: "Gesichert: \(state.banked[sitz] ?? 0)") }
            return .idle(title: state.soloBonus == sitz ? "⭐ SOLO-BONUS ×2!" : (state.climbers.contains(sitz) ? "Der Turm hält!" : "Sicher gelandet"), subtitle: "Beute \(state.loot[sitz] ?? 0) · Bank \(state.banked[sitz] ?? 0)")
        }
        guard state.climbers.contains(sitz) else { return .idle(title: "🪂 Du bist unten", subtitle: "Gesichert: \(state.banked[sitz] ?? 0) · Turm \(state.tower + 1)/5") }
        return .binary(title: "Turm \(state.tower + 1) · Stufe \(state.stufe + 1)/8 · Risiko \(risk(stufe: state.stufe, climbers: state.climbers.count)) %",
                       subtitle: "Beute \(state.loot[sitz] ?? 0) 🍌 · Bank \(state.banked[sitz] ?? 0)", a: "weiter", b: "runter", chosen: state.choices[sitz], deadline: state.deadline)
    }

    public static func shift(_ state: inout State, ms: Int) {
        state.deadline += ms
        if let r = state.revealUntil { state.revealUntil = r + ms }
    }
}
