import Foundation

/// Siedler vom Bananenhain — party variant of the settlers classic: 19-hex
/// island, 5 monkey resources, snake-draft setup, bank 3:1, one structured
/// player offer per turn, longest path ≥5 = +2, win at 7 points, the Miesaffe
/// (robber) on the 7.
public enum Siedler: BoardgamePlugin {
    public struct Hex: Codable, Equatable, Sendable { var q: Int; var r: Int; var res: String; var zahl: Int? }

    public struct State: Codable, Equatable, Sendable {
        public var sitze: [String]
        public var hexes: [Hex]
        public var buildings: [String: (String, Int)]
        public var roads: [String: String]
        public var hands: [String: [String: Int]]
        public var robber: Int
        public var current: Int
        public var phase: String // setup | wuerfeln | abwerfen | raeuber | aktionen | fertig
        public var setupOrder: [Int]
        public var setupStep: Int
        public var setupNeedsRoad: String?
        public var dice: [Int]?
        public var event: String?
        public var longestRoad: String?
        public var winner: String?
        public var turnDeadline: Millis
        public var discardNeeded: [String: Int]
        public var offer: Offer?
        public var offerUsed: Bool
        public var buildMode: String?

        enum CodingKeys: String, CodingKey { case sitze, hexes, buildingsFlat, roads, hands, robber, current, phase, setupOrder, setupStep, setupNeedsRoad, dice, event, longestRoad, winner, turnDeadline, discardNeeded, offer, offerUsed, buildMode }

        public init(sitze: [String], hexes: [Hex], robber: Int, now: Millis) {
            self.sitze = sitze
            self.hexes = hexes
            buildings = [:]
            roads = [:]
            hands = Dictionary(uniqueKeysWithValues: sitze.map { ($0, [:]) })
            self.robber = robber
            current = 0
            phase = "setup"
            setupOrder = Array(sitze.indices) + Array(sitze.indices).reversed()
            setupStep = 0
            setupNeedsRoad = nil
            dice = nil
            event = "Aufbau: \(sitze.first ?? "") setzt die erste Hütte"
            longestRoad = nil
            winner = nil
            turnDeadline = now + 30_000
            discardNeeded = [:]
            offer = nil
            offerUsed = false
            buildMode = nil
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            sitze = try c.decode([String].self, forKey: .sitze)
            hexes = try c.decode([Hex].self, forKey: .hexes)
            let flat = try c.decode([String: [String]].self, forKey: .buildingsFlat)
            buildings = flat.compactMapValues { $0.count == 2 ? ($0[0], Int($0[1]) ?? 1) : nil }
            roads = try c.decode([String: String].self, forKey: .roads)
            hands = try c.decode([String: [String: Int]].self, forKey: .hands)
            robber = try c.decode(Int.self, forKey: .robber)
            current = try c.decode(Int.self, forKey: .current)
            phase = try c.decode(String.self, forKey: .phase)
            setupOrder = try c.decode([Int].self, forKey: .setupOrder)
            setupStep = try c.decode(Int.self, forKey: .setupStep)
            setupNeedsRoad = try c.decodeIfPresent(String.self, forKey: .setupNeedsRoad)
            dice = try c.decodeIfPresent([Int].self, forKey: .dice)
            event = try c.decodeIfPresent(String.self, forKey: .event)
            longestRoad = try c.decodeIfPresent(String.self, forKey: .longestRoad)
            winner = try c.decodeIfPresent(String.self, forKey: .winner)
            turnDeadline = try c.decode(Millis.self, forKey: .turnDeadline)
            discardNeeded = try c.decode([String: Int].self, forKey: .discardNeeded)
            offer = try c.decodeIfPresent(Offer.self, forKey: .offer)
            offerUsed = try c.decode(Bool.self, forKey: .offerUsed)
            buildMode = try c.decodeIfPresent(String.self, forKey: .buildMode)
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(sitze, forKey: .sitze)
            try c.encode(hexes, forKey: .hexes)
            try c.encode(buildings.mapValues { [$0.0, String($0.1)] }, forKey: .buildingsFlat)
            try c.encode(roads, forKey: .roads)
            try c.encode(hands, forKey: .hands)
            try c.encode(robber, forKey: .robber)
            try c.encode(current, forKey: .current)
            try c.encode(phase, forKey: .phase)
            try c.encode(setupOrder, forKey: .setupOrder)
            try c.encode(setupStep, forKey: .setupStep)
            try c.encodeIfPresent(setupNeedsRoad, forKey: .setupNeedsRoad)
            try c.encodeIfPresent(dice, forKey: .dice)
            try c.encodeIfPresent(event, forKey: .event)
            try c.encodeIfPresent(longestRoad, forKey: .longestRoad)
            try c.encodeIfPresent(winner, forKey: .winner)
            try c.encode(turnDeadline, forKey: .turnDeadline)
            try c.encode(discardNeeded, forKey: .discardNeeded)
            try c.encodeIfPresent(offer, forKey: .offer)
            try c.encode(offerUsed, forKey: .offerUsed)
            try c.encodeIfPresent(buildMode, forKey: .buildMode)
        }

        public static func == (a: State, b: State) -> Bool {
            a.sitze == b.sitze && a.buildings.mapValues { "\($0.0):\($0.1)" } == b.buildings.mapValues { "\($0.0):\($0.1)" } && a.roads == b.roads && a.hands == b.hands &&
            a.robber == b.robber && a.current == b.current && a.phase == b.phase && a.setupStep == b.setupStep && a.dice == b.dice && a.winner == b.winner && a.offer == b.offer
        }
    }

    public struct Offer: Codable, Equatable, Sendable {
        public var from: String
        public var give: String
        public var want: String
        public var until: Millis
    }

    public static let meta = BoardgameMeta(
        id: "siedler", name: "Siedler vom Bananenhain", emoji: "🏝️", untertitel: "Aufbau-Strategie · 3–4 Affen",
        minSpieler: 3, maxSpieler: 4, phonesOnly: false, gemischteSitze: true,
        howto: ["Setzt im Aufbau je 2 Hütten und 2 Pfade auf die Insel. Jede Runde wird gewürfelt — alle Hütten an Feldern mit dieser Zahl ernten Rohstoffe.",
                "Baue Pfade (🪵+🪨), Hütten (🍌🪵🪨🥥) und Baumhäuser (🪨🪨🥥🥥🥥). Bank tauscht 3:1, ein Spieler-Angebot pro Zug erlaubt.",
                "Bei der 7 kommt der Miesaffe: über 7 Karten? Die Hälfte weg! Hütte 1 Punkt, Baumhaus 2, längster Pfad (≥5) +2. Wer 7 Punkte hat, gewinnt."],
        varianten: [], halbePayout: false
    )

    static let resources = ["banane", "holz", "stein", "kokos", "blatt"]
    static let emoji: [String: String] = ["banane": "🍌", "holz": "🪵", "stein": "🪨", "kokos": "🥥", "blatt": "🍃", "duerr": "🏜️"]
    static let turnMs = 45_000
    static let costHut: [String: Int] = ["banane": 1, "holz": 1, "stein": 1, "kokos": 1]
    static let costTree: [String: Int] = ["stein": 2, "kokos": 3]
    static let costRoad: [String: Int] = ["holz": 1, "stein": 1]

    // MARK: Geometry (pointy-top axial hexes, radius 2)

    static let axials: [(Int, Int)] = {
        var out: [(Int, Int)] = []
        for q in -2...2 { for r in -2...2 where abs(q + r) <= 2 { out.append((q, r)) } }
        return out
    }()

    static func center(_ q: Int, _ r: Int) -> (Double, Double) { (sqrt(3) * (Double(q) + Double(r) / 2), 1.5 * Double(r)) }

    static func cornerKey(_ x: Double, _ y: Double) -> String { String(format: "%.2f,%.2f", x, y) }

    static func corners(_ q: Int, _ r: Int) -> [String] {
        let c = center(q, r)
        return (0..<6).map { i in
            let a = Double.pi / 180 * (60 * Double(i) - 30)
            return cornerKey(c.0 + cos(a), c.1 + sin(a))
        }
    }

    static func edgeKey(_ a: String, _ b: String) -> String { [a, b].sorted().joined(separator: "|") }

    static func edges(_ q: Int, _ r: Int) -> [String] {
        let c = corners(q, r)
        return (0..<6).map { edgeKey(c[$0], c[($0 + 1) % 6]) }
    }

    static func hexesAt(corner: String, _ s: State) -> [Int] { s.hexes.indices.filter { corners(s.hexes[$0].q, s.hexes[$0].r).contains(corner) } }

    static func adjacentCorners(_ corner: String, _ s: State) -> Set<String> {
        var out: Set<String> = []
        for h in s.hexes {
            let c = corners(h.q, h.r)
            if let i = c.firstIndex(of: corner) { out.insert(c[(i + 1) % 6]); out.insert(c[(i + 5) % 6]) }
        }
        return out
    }

    static func allCorners(_ s: State) -> Set<String> { Set(s.hexes.flatMap { corners($0.q, $0.r) }) }
    static func allEdges(_ s: State) -> Set<String> { Set(s.hexes.flatMap { edges($0.q, $0.r) }) }
    static func cornersOf(edge: String) -> [String] { edge.split(separator: "|").map(String.init) }

    // MARK: Setup

    public static func initState(ctx: inout BoardgameContext) -> State {
        var res = ["banane", "banane", "banane", "banane", "holz", "holz", "holz", "holz", "stein", "stein", "stein", "kokos", "kokos", "kokos", "kokos", "blatt", "blatt", "blatt", "duerr"]
        var numbers = [2, 3, 3, 4, 4, 5, 5, 6, 6, 8, 8, 9, 9, 10, 10, 11, 11, 12]
        var hexes: [Hex] = []
        var attempts = 0
        repeat {
            res = ctx.rng.shuffled(res)
            numbers = ctx.rng.shuffled(numbers)
            hexes = []
            var ni = 0
            for (q, r) in axials {
                let rs = res[hexes.count]
                hexes.append(Hex(q: q, r: r, res: rs, zahl: rs == "duerr" ? nil : numbers[ni]))
                if rs != "duerr" { ni += 1 }
            }
            attempts += 1
        } while !redNumbersApart(hexes) && attempts < 300
        let robber = hexes.firstIndex { $0.res == "duerr" } ?? 0
        return State(sitze: ctx.sitze, hexes: hexes, robber: robber, now: ctx.now + ctx.ms(30_000) - 30_000)
    }

    /// 6 and 8 must never be neighbours.
    static func redNumbersApart(_ hexes: [Hex]) -> Bool {
        let red = hexes.filter { $0.zahl == 6 || $0.zahl == 8 }
        for a in red { for b in red where a != b {
            let dq = a.q - b.q, dr = a.r - b.r
            if max(abs(dq), abs(dr), abs(dq + dr)) == 1 { return false }
        } }
        return true
    }

    static func seatOf(_ s: State) -> String {
        if s.phase == "setup" { return s.sitze[s.setupOrder[min(s.setupStep, s.setupOrder.count - 1)]] }
        return s.sitze[s.current % s.sitze.count]
    }

    static func legalHutCorners(_ s: State, sitz: String, setup: Bool) -> [String] {
        allCorners(s).filter { c in
            if s.buildings[c] != nil { return false }
            if adjacentCorners(c, s).contains(where: { s.buildings[$0] != nil }) { return false }
            if setup { return true }
            return cornersOf(edge: "").isEmpty && s.roads.contains { $0.value == sitz && cornersOf(edge: $0.key).contains(c) }
        }
    }

    static func legalRoadEdges(_ s: State, sitz: String, from corner: String?) -> [String] {
        allEdges(s).filter { e in
            if s.roads[e] != nil { return false }
            let cs = cornersOf(edge: e)
            if let c = corner { return cs.contains(c) }
            return cs.contains { c in s.buildings[c]?.0 == sitz || s.roads.contains { $0.value == sitz && cornersOf(edge: $0.key).contains(c) } }
        }
    }

    static func handCount(_ s: State, _ sitz: String) -> Int { (s.hands[sitz] ?? [:]).values.reduce(0, +) }

    static func canAfford(_ s: State, _ sitz: String, _ cost: [String: Int]) -> Bool {
        cost.allSatisfy { (s.hands[sitz]?[$0.key] ?? 0) >= $0.value }
    }

    static func pay(_ s: inout State, _ sitz: String, _ cost: [String: Int]) { for (k, v) in cost { s.hands[sitz, default: [:]][k, default: 0] -= v } }

    static func points(_ s: State, _ sitz: String) -> Int {
        var p = s.buildings.values.filter { $0.0 == sitz }.reduce(0) { $0 + $1.1 }
        if s.longestRoad == sitz { p += 2 }
        return p
    }

    /// Longest connected own path (DFS over own edges, foreign buildings cut).
    static func longestPath(_ s: State, _ sitz: String) -> Int {
        let own = s.roads.filter { $0.value == sitz }.map { cornersOf(edge: $0.key) }
        var best = 0
        func dfs(_ at: String, _ used: Set<Int>, _ len: Int) {
            best = max(best, len)
            for (i, e) in own.enumerated() where !used.contains(i) && e.contains(at) {
                let next = e[0] == at ? e[1] : e[0]
                if let b = s.buildings[next], b.0 != sitz { best = max(best, len + 1); continue }
                dfs(next, used.union([i]), len + 1)
            }
        }
        for e in own { dfs(e[0], [], 0); dfs(e[1], [], 0) }
        return best
    }

    static func updateLongest(_ s: inout State) {
        let lens = s.sitze.map { ($0, longestPath(s, $0)) }
        guard let top = lens.max(by: { $0.1 < $1.1 }), top.1 >= 5 else { return }
        if lens.filter({ $0.1 == top.1 }).count == 1 || s.longestRoad == nil { if s.longestRoad != top.0, lens.first(where: { $0.0 == s.longestRoad })?.1 ?? 0 < top.1 { s.longestRoad = top.0 } }
    }

    static func checkWin(_ s: inout State, ctx: BoardgameContext) {
        for sitz in s.sitze where points(s, sitz) >= 7 { s.winner = sitz; s.phase = "fertig"; s.event = "🏆 \(ctx.name(sitz)) erreicht 7 Punkte!" }
    }

    // MARK: Turn flow

    public static func reduce(_ state: inout State, action: PlayerAction, from sitz: String, ctx: inout BoardgameContext) {
        guard state.winner == nil else { return }
        // Offers can be accepted by anyone.
        if case .button(let b) = action, b == "annehmen", let o = state.offer, o.from != sitz, (state.hands[sitz]?[o.want] ?? 0) >= 1 {
            state.hands[sitz, default: [:]][o.want, default: 0] -= 1
            state.hands[sitz, default: [:]][o.give, default: 0] += 1
            state.hands[o.from, default: [:]][o.give, default: 0] -= 1
            state.hands[o.from, default: [:]][o.want, default: 0] += 1
            state.event = "🤝 \(ctx.name(sitz)) nimmt das Angebot von \(ctx.name(o.from)) an"
            state.offer = nil
            return
        }
        if state.phase == "abwerfen" {
            if case .chips(let counts) = action, let need = state.discardNeeded[sitz], counts.count == resources.count, counts.reduce(0, +) == need {
                for (i, r) in resources.enumerated() where (state.hands[sitz]?[r] ?? 0) >= counts[i] { state.hands[sitz, default: [:]][r, default: 0] -= counts[i] }
                state.discardNeeded[sitz] = nil
                if state.discardNeeded.isEmpty { state.phase = "raeuber"; state.turnDeadline = ctx.now + ctx.ms(20_000) }
            }
            return
        }
        guard seatOf(state) == sitz else { return }
        switch state.phase {
        case "setup":
            if let from = state.setupNeedsRoad {
                if case .button(let e) = action, legalRoadEdges(state, sitz: sitz, from: from).contains(e) {
                    state.roads[e] = sitz
                    state.setupNeedsRoad = nil
                    state.setupStep += 1
                    if state.setupStep >= state.setupOrder.count { state.phase = "wuerfeln"; state.current = 0; state.event = "Aufbau fertig — \(ctx.name(state.sitze[0])) würfelt!" }
                    else { state.event = "\(ctx.name(seatOf(state))) setzt eine Hütte" }
                    state.turnDeadline = ctx.now + ctx.ms(30_000)
                }
            } else if case .button(let c) = action, legalHutCorners(state, sitz: sitz, setup: true).contains(c) {
                state.buildings[c] = (sitz, 1)
                if state.setupStep >= state.sitze.count { // second hut harvests
                    for hi in hexesAt(corner: c, state) where state.hexes[hi].res != "duerr" { state.hands[sitz, default: [:]][state.hexes[hi].res, default: 0] += 1 }
                }
                state.setupNeedsRoad = c
                state.event = "\(ctx.name(sitz)) baut eine Hütte — jetzt der Pfad"
            }
        case "wuerfeln":
            if case .button(let b) = action, b == "wuerfeln" { roll(&state, ctx: &ctx) }
        case "raeuber":
            if case .button(let b) = action, let hi = Int(b), hi != state.robber, state.hexes.indices.contains(hi) {
                state.robber = hi
                let victims = Set(corners(state.hexes[hi].q, state.hexes[hi].r).compactMap { state.buildings[$0]?.0 }).filter { $0 != sitz && handCount(state, $0) > 0 }
                if let v = ctx.rng.pick(Array(victims)), let stolen = ctx.rng.pick((state.hands[v] ?? [:]).filter { $0.value > 0 }.map { $0.key }) {
                    state.hands[v, default: [:]][stolen, default: 0] -= 1
                    state.hands[sitz, default: [:]][stolen, default: 0] += 1
                    state.event = "🐒 Miesaffe: \(ctx.name(sitz)) klaut \(emoji[stolen] ?? "") von \(ctx.name(v))"
                } else { state.event = "🐒 Der Miesaffe zieht um" }
                state.phase = "aktionen"
                state.turnDeadline = ctx.now + ctx.ms(turnMs)
            }
        case "aktionen":
            handleAction(&state, action, sitz, ctx: &ctx)
        default: break
        }
    }

    static func handleAction(_ s: inout State, _ action: PlayerAction, _ sitz: String, ctx: inout BoardgameContext) {
        guard case .button(let b) = action else { return }
        if let mode = s.buildMode {
            switch mode {
            case "pfad":
                if legalRoadEdges(s, sitz: sitz, from: nil).contains(b), canAfford(s, sitz, costRoad) { pay(&s, sitz, costRoad); s.roads[b] = sitz; updateLongest(&s); s.event = "\(ctx.name(sitz)) baut einen Pfad" }
            case "huette":
                if legalHutCorners(s, sitz: sitz, setup: false).contains(b), canAfford(s, sitz, costHut) { pay(&s, sitz, costHut); s.buildings[b] = (sitz, 1); updateLongest(&s); s.event = "\(ctx.name(sitz)) baut eine Hütte" }
            case "baumhaus":
                if s.buildings[b]?.0 == sitz, s.buildings[b]?.1 == 1, canAfford(s, sitz, costTree) { pay(&s, sitz, costTree); s.buildings[b] = (sitz, 2); s.event = "\(ctx.name(sitz)) baut ein Baumhaus" }
            case "bank":
                let parts = b.split(separator: ">").map(String.init)
                if parts.count == 2, resources.contains(parts[0]), resources.contains(parts[1]), (s.hands[sitz]?[parts[0]] ?? 0) >= 3 {
                    s.hands[sitz, default: [:]][parts[0], default: 0] -= 3
                    s.hands[sitz, default: [:]][parts[1], default: 0] += 1
                    s.event = "🏦 \(ctx.name(sitz)) tauscht 3 \(emoji[parts[0]] ?? "") gegen 1 \(emoji[parts[1]] ?? "")"
                }
            case "angebot":
                let parts = b.split(separator: ">").map(String.init)
                if parts.count == 2, resources.contains(parts[0]), resources.contains(parts[1]), (s.hands[sitz]?[parts[0]] ?? 0) >= 1, !s.offerUsed {
                    s.offer = Offer(from: sitz, give: parts[0], want: parts[1], until: ctx.now + ctx.ms(20_000))
                    s.offerUsed = true
                    s.event = "🤝 \(ctx.name(sitz)) bietet \(emoji[parts[0]] ?? "") gegen \(emoji[parts[1]] ?? "") — wer zuerst annimmt!"
                }
            default: break
            }
            s.buildMode = nil
            checkWin(&s, ctx: ctx)
            return
        }
        switch b {
        case "pfad", "huette", "baumhaus", "bank", "angebot": s.buildMode = b
        case "abbrechen": s.buildMode = nil
        case "ende": endTurn(&s, ctx: ctx)
        default: break
        }
    }

    static func roll(_ s: inout State, ctx: inout BoardgameContext) {
        let d1 = ctx.rng.int(in: 1...6), d2 = ctx.rng.int(in: 1...6)
        s.dice = [d1, d2]
        let sum = d1 + d2
        if sum == 7 {
            s.event = "🎲 7! Der Miesaffe kommt"
            for sitz in s.sitze where handCount(s, sitz) > 7 {
                if sitz.hasPrefix("lokal_") { autoDiscard(&s, sitz) } else { s.discardNeeded[sitz] = handCount(s, sitz) / 2 }
            }
            s.phase = s.discardNeeded.isEmpty ? "raeuber" : "abwerfen"
            s.turnDeadline = ctx.now + ctx.ms(20_000)
            return
        }
        var harvest: [String] = []
        for (hi, h) in s.hexes.enumerated() where h.zahl == sum && hi != s.robber && h.res != "duerr" {
            for c in corners(h.q, h.r) { if let b = s.buildings[c] { s.hands[b.0, default: [:]][h.res, default: 0] += b.1; harvest.append("\(ctx.name(b.0)) +\(b.1)\(emoji[h.res] ?? "")") } }
        }
        s.event = "🎲 \(sum): " + (harvest.isEmpty ? "keine Ernte" : harvest.joined(separator: ", "))
        s.phase = "aktionen"
        s.turnDeadline = ctx.now + ctx.ms(turnMs)
    }

    static func autoDiscard(_ s: inout State, _ sitz: String) {
        var need = handCount(s, sitz) / 2
        while need > 0, let biggest = (s.hands[sitz] ?? [:]).max(by: { $0.value < $1.value }), biggest.value > 0 {
            s.hands[sitz, default: [:]][biggest.key, default: 0] -= 1
            need -= 1
        }
    }

    static func endTurn(_ s: inout State, ctx: BoardgameContext) {
        s.current = (s.current + 1) % s.sitze.count
        s.phase = "wuerfeln"
        s.dice = nil
        s.offer = nil
        s.offerUsed = false
        s.buildMode = nil
        s.turnDeadline = ctx.now + ctx.ms(turnMs)
        checkWin(&s, ctx: ctx)
    }

    public static func tick(_ state: inout State, ctx: inout BoardgameContext) {
        guard state.winner == nil else { return }
        if let o = state.offer, ctx.now >= o.until { state.offer = nil }
        if state.phase == "abwerfen", ctx.now >= state.turnDeadline {
            for sitz in state.discardNeeded.keys { autoDiscard(&state, sitz) }
            state.discardNeeded = [:]
            state.phase = "raeuber"
            state.turnDeadline = ctx.now + ctx.ms(20_000)
        }
        let sitz = seatOf(state)
        guard !sitz.hasPrefix("lokal_") || state.phase == "abwerfen" else { return }
        if ctx.now >= state.turnDeadline || !ctx.connected.contains(sitz) {
            autoTurn(&state, sitz, ctx: &ctx)
        }
    }

    static func autoTurn(_ s: inout State, _ sitz: String, ctx: inout BoardgameContext) {
        switch s.phase {
        case "setup":
            if let from = s.setupNeedsRoad, let e = legalRoadEdges(s, sitz: sitz, from: from).first { reduce(&s, action: .button(e), from: sitz, ctx: &ctx) }
            else if let c = bestSetupCorners(s).first { reduce(&s, action: .button(c), from: sitz, ctx: &ctx) }
        case "wuerfeln": roll(&s, ctx: &ctx)
        case "raeuber":
            if let hi = ctx.rng.pick(Array(s.hexes.indices.filter { $0 != s.robber && s.hexes[$0].res != "duerr" })) { reduce(&s, action: .button(String(hi)), from: sitz, ctx: &ctx) }
        case "aktionen": endTurn(&s, ctx: ctx)
        default: break
        }
        s.turnDeadline = ctx.now + ctx.ms(turnMs)
    }

    /// Top yield corners (pips) — also the "Empfohlen" badges for the setup.
    static func bestSetupCorners(_ s: State) -> [String] {
        let pips: [Int: Int] = [2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 8: 5, 9: 4, 10: 3, 11: 2, 12: 1]
        let legal = legalHutCorners(s, sitz: "", setup: true)
        return legal.sorted { a, b in
            let ya = hexesAt(corner: a, s).reduce(0) { $0 + (s.hexes[$1].zahl.flatMap { pips[$0] } ?? 0) }
            let yb = hexesAt(corner: b, s).reduce(0) { $0 + (s.hexes[$1].zahl.flatMap { pips[$0] } ?? 0) }
            return ya > yb
        }
    }

    public static func isFinished(_ state: State) -> Bool { state.winner != nil }

    public static func results(_ state: State, ctx: BoardgameContext) -> [(sitz: String, platz: Int, detail: String)] {
        let sorted = state.sitze.sorted { a, b in points(state, a) != points(state, b) ? points(state, a) > points(state, b) : handCount(state, a) > handCount(state, b) }
        return sorted.enumerated().map { (i, s) in
            let huts = state.buildings.values.filter { $0.0 == s && $0.1 == 1 }.count
            let trees = state.buildings.values.filter { $0.0 == s && $0.1 == 2 }.count
            return (s, i + 1, "\(points(state, s)) Punkte · \(huts) Hütten · \(trees) Baumhäuser\(state.longestRoad == s ? " · längster Pfad" : "")")
        }
    }

    public static func scene(_ state: State, ctx: BoardgameContext) -> BoardgameScene {
        let view = SiedlerStageView(
            hexes: state.hexes.map { SiedlerHex(q: $0.q, r: $0.r, rohstoff: $0.res, zahl: $0.zahl) },
            buildings: state.buildings.map { SiedlerBuilding(corner: $0.key, sitz: $0.value.0, stufe: $0.value.1) },
            roads: state.roads.map { SiedlerRoad(edge: $0.key, sitz: $0.value) },
            robber: state.robber, current: seatOf(state), dice: state.dice,
            points: Dictionary(uniqueKeysWithValues: state.sitze.map { ($0, points(state, $0)) }),
            handSizes: Dictionary(uniqueKeysWithValues: state.sitze.map { ($0, handCount(state, $0)) }),
            longestRoad: state.longestRoad, event: state.event, phase: state.phase, deadline: state.turnDeadline,
            offer: state.offer.map { "\(ctx.name($0.from)) bietet \(emoji[$0.give] ?? "") gegen \(emoji[$0.want] ?? "")" })
        return .siedler(view: view)
    }

    static func handLine(_ s: State, _ sitz: String) -> String {
        resources.map { "\(emoji[$0] ?? "")\(s.hands[sitz]?[$0] ?? 0)" }.joined(separator: "  ")
    }

    public static func prompt(_ state: State, sitz: String, ctx: BoardgameContext) -> PlayerPrompt {
        let hand = handLine(state, sitz)
        let pts = "⭐ \(points(state, sitz)) Punkte"
        if let w = state.winner { return .idle(title: w == sitz ? "🏆 Du hast den Hain besiedelt!" : "\(ctx.name(w)) gewinnt", subtitle: pts) }
        if let o = state.offer, o.from != sitz {
            let ok = (state.hands[sitz]?[o.want] ?? 0) >= 1
            return .actions(title: "🤝 Angebot von \(ctx.name(o.from))", lines: ["Gibt \(emoji[o.give] ?? "") · will \(emoji[o.want] ?? "")", hand], buttons: [ActionButton(id: "annehmen", label: "Annehmen", enabled: ok)], deadline: o.until)
        }
        if state.phase == "abwerfen", let need = state.discardNeeded[sitz] {
            let opts = resources.map { ChoiceOption(id: resources.firstIndex(of: $0)!, text: "\(emoji[$0] ?? "") \($0) (\(state.hands[sitz]?[$0] ?? 0))") }
            return .chips(question: "🐒 Miesaffe! Wirf \(need) Karten ab", options: opts, total: need, placed: Array(repeating: 0, count: resources.count), locked: false, deadline: state.turnDeadline)
        }
        guard seatOf(state) == sitz else { return .actions(title: "\(ctx.name(seatOf(state))) ist dran", lines: [state.event ?? "", hand, pts], buttons: [], deadline: nil) }
        switch state.phase {
        case "setup":
            if let from = state.setupNeedsRoad {
                let edges = legalRoadEdges(state, sitz: sitz, from: from)
                return .actions(title: "Pfad an deine Hütte", lines: ["Wähle eine Richtung"], buttons: edges.enumerated().map { ActionButton(id: $0.element, label: "Pfad \($0.offset + 1)") }, deadline: state.turnDeadline)
            }
            let best = bestSetupCorners(state)
            return .actions(title: "Hütte setzen", lines: ["Empfohlen = beste Ernte-Ecken"], buttons: best.prefix(8).enumerated().map { ActionButton(id: $0.element, label: "\($0.offset < 3 ? "⭐ " : "")Ecke \($0.offset + 1)") }, deadline: state.turnDeadline)
        case "wuerfeln":
            return .actions(title: "Du bist dran!", lines: [hand, pts], buttons: [ActionButton(id: "wuerfeln", label: "🎲 Würfeln")], deadline: state.turnDeadline)
        case "raeuber":
            let targets = state.hexes.indices.filter { $0 != state.robber && state.hexes[$0].res != "duerr" }
            return .actions(title: "🐒 Miesaffe versetzen", lines: ["Wähle ein Feld"], buttons: targets.map { ActionButton(id: String($0), label: "\(emoji[state.hexes[$0].res] ?? "") \(state.hexes[$0].zahl ?? 0)") }, deadline: state.turnDeadline)
        case "aktionen":
            if let mode = state.buildMode {
                var buttons: [ActionButton] = []
                switch mode {
                case "pfad": buttons = legalRoadEdges(state, sitz: sitz, from: nil).prefix(10).enumerated().map { ActionButton(id: $0.element, label: "Pfad \($0.offset + 1)") }
                case "huette": buttons = legalHutCorners(state, sitz: sitz, setup: false).prefix(10).enumerated().map { ActionButton(id: $0.element, label: "Ecke \($0.offset + 1)") }
                case "baumhaus": buttons = state.buildings.filter { $0.value.0 == sitz && $0.value.1 == 1 }.keys.enumerated().map { ActionButton(id: $0.element, label: "Hütte \($0.offset + 1)") }
                case "bank": for g in resources where (state.hands[sitz]?[g] ?? 0) >= 3 { for w in resources where w != g { buttons.append(ActionButton(id: "\(g)>\(w)", label: "3\(emoji[g] ?? "") → 1\(emoji[w] ?? "")")) } }
                case "angebot": for g in resources where (state.hands[sitz]?[g] ?? 0) >= 1 { for w in resources where w != g { buttons.append(ActionButton(id: "\(g)>\(w)", label: "\(emoji[g] ?? "") gegen \(emoji[w] ?? "")")) } }
                default: break
                }
                buttons.append(ActionButton(id: "abbrechen", label: "Abbrechen", style: "secondary"))
                return .actions(title: "Bauen: \(mode)", lines: [hand], buttons: buttons, deadline: state.turnDeadline)
            }
            return .actions(title: "Aktionen", lines: [state.event ?? "", hand, pts], buttons: [
                ActionButton(id: "pfad", label: "🛤️ Pfad (🪵🪨)", enabled: canAfford(state, sitz, costRoad)),
                ActionButton(id: "huette", label: "🏠 Hütte (🍌🪵🪨🥥)", enabled: canAfford(state, sitz, costHut)),
                ActionButton(id: "baumhaus", label: "🌳 Baumhaus (🪨🪨🥥🥥🥥)", enabled: canAfford(state, sitz, costTree)),
                ActionButton(id: "bank", label: "🏦 Bank 3:1", style: "secondary", enabled: resources.contains { (state.hands[sitz]?[$0] ?? 0) >= 3 }),
                ActionButton(id: "angebot", label: "🤝 Angebot", style: "secondary", enabled: !state.offerUsed && handCount(state, sitz) > 0),
                ActionButton(id: "ende", label: "Zug beenden", style: "secondary"),
            ], deadline: state.turnDeadline)
        default:
            return .idle(title: state.event ?? "", subtitle: hand)
        }
    }

    public static func currentSeat(_ state: State) -> String? { seatOf(state) }
    public static func shift(_ state: inout State, ms: Int) { state.turnDeadline += ms }
}
