import Foundation

/// Typed scene for the board game stage (Spiele-Abend track).
public indirect enum BoardgameScene: Codable, Equatable, Sendable {
    case towers(towers: [TowerView], stufe: Int, risiko: Int, chosen: [PlayerId], collapsedTower: Int?, banked: [PlayerId: Int], soloBonus: PlayerId?)
    case werwolf(phase: String, alive: [PlayerId], dead: [PlayerId], text: String, dayNumber: Int, deadline: Millis?, lastLynched: PlayerId?, revealRoles: [PlayerId: String]?)
    case uno(topCard: UnoCard, direction: Int, hands: [String: Int], current: String, drawPile: Int, color: String, lastEvent: String?, deadline: Millis?)
    case madn(tokens: [MadnToken], current: String, dice: Int?, seq: Int, message: String?, kurz: Bool, deadline: Millis?)
    case bananopoly(fields: [BananopolyField], positions: [String: Int], cash: [String: Int], current: String, dice: [Int]?, event: String?, round: Int, deadline: Millis?, owners: [Int: String], stands: [Int])
    case siedler(view: SiedlerStageView)
}

public struct TowerView: Codable, Equatable, Sendable {
    public var index: Int
    public var height: Int
    public var climbers: [PlayerId]
    public var collapsed: Bool
    public var loot: Int
}

public struct UnoCard: Codable, Equatable, Sendable, Hashable {
    public var farbe: String // rot | gelb | gruen | blau | schwarz
    public var wert: String  // 0-9 | skip | reverse | draw2 | wild | wild4
}

public struct MadnToken: Codable, Equatable, Sendable {
    public var sitz: String
    public var index: Int
    public var pos: Int // -1 = house, 0..39 ring, 100+ target lane
}

public struct BananopolyField: Codable, Equatable, Sendable {
    public var index: Int
    public var name: String
    public var typ: String
    public var preis: Int
    public var paar: Int?
}

public struct SiedlerStageView: Codable, Equatable, Sendable {
    public var hexes: [SiedlerHex]
    public var buildings: [SiedlerBuilding]
    public var roads: [SiedlerRoad]
    public var robber: Int
    public var current: String
    public var dice: [Int]?
    public var points: [String: Int]
    public var handSizes: [String: Int]
    public var longestRoad: String?
    public var event: String?
    public var phase: String
    public var deadline: Millis?
    public var offer: String?
}

public struct SiedlerHex: Codable, Equatable, Sendable {
    public var q: Int
    public var r: Int
    public var rohstoff: String
    public var zahl: Int?
}

public struct SiedlerBuilding: Codable, Equatable, Sendable {
    public var corner: String
    public var sitz: String
    public var stufe: Int
}

public struct SiedlerRoad: Codable, Equatable, Sendable {
    public var edge: String
    public var sitz: String
}

public struct BoardgameMeta: Sendable {
    public var id: String
    public var name: String
    public var emoji: String
    public var untertitel: String
    public var minSpieler: Int
    public var maxSpieler: Int
    public var phonesOnly: Bool
    public var gemischteSitze: Bool
    public var howto: [String]
    public var varianten: [String]
    public var halbePayout: Bool
}

/// Shared context for board games (same injection rules as minigames).
public struct BoardgameContext: Sendable {
    public var now: Millis
    public var rng: SeededRandom
    public var settings: MatchSettings
    public var sitze: [String]
    public var names: [String: String]
    public var connected: Set<String>
    public var lokale: Set<String>
    public var optionen: [String: JSONValue]

    public func name(_ s: String) -> String { names[s] ?? s }
    public func ms(_ base: Int) -> Int { settings.ms(base) }
}

public protocol BoardgamePlugin {
    associatedtype State: Codable & Equatable & Sendable
    static var meta: BoardgameMeta { get }
    static func initState(ctx: inout BoardgameContext) -> State
    static func reduce(_ state: inout State, action: PlayerAction, from sitz: String, ctx: inout BoardgameContext)
    static func tick(_ state: inout State, ctx: inout BoardgameContext)
    static func onDisconnect(_ state: inout State, sitz: String, ctx: inout BoardgameContext)
    static func isFinished(_ state: State) -> Bool
    /// Results (place, detail) per seat — MM is assigned by the engine ladder.
    static func results(_ state: State, ctx: BoardgameContext) -> [(sitz: String, platz: Int, detail: String)]
    static func scene(_ state: State, ctx: BoardgameContext) -> BoardgameScene
    static func prompt(_ state: State, sitz: String, ctx: BoardgameContext) -> PlayerPrompt
    /// Seat whose turn it is (for pass-and-play prompts on the iPad).
    static func currentSeat(_ state: State) -> String?
    static func shift(_ state: inout State, ms: Int)
}

public extension BoardgamePlugin {
    static func onDisconnect(_ state: inout State, sitz: String, ctx: inout BoardgameContext) {}
    static func currentSeat(_ state: State) -> String? { nil }
    static func shift(_ state: inout State, ms: Int) {}
}

public struct AnyBoardgame: Sendable {
    public let meta: BoardgameMeta
    public let initBox: @Sendable (inout BoardgameContext) -> Data
    public let reduce: @Sendable (inout Data, PlayerAction, String, inout BoardgameContext) -> Void
    public let tick: @Sendable (inout Data, inout BoardgameContext) -> Void
    public let onDisconnect: @Sendable (inout Data, String, inout BoardgameContext) -> Void
    public let isFinished: @Sendable (Data) -> Bool
    public let results: @Sendable (Data, BoardgameContext) -> [(sitz: String, platz: Int, detail: String)]
    public let scene: @Sendable (Data, BoardgameContext) -> BoardgameScene?
    public let prompt: @Sendable (Data, String, BoardgameContext) -> PlayerPrompt
    public let currentSeat: @Sendable (Data) -> String?
    public let shift: @Sendable (inout Data, Int) -> Void

    public init<P: BoardgamePlugin>(_ plugin: P.Type) {
        meta = P.meta
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let dec = JSONDecoder()
        func load(_ d: Data) -> P.State? { try? dec.decode(P.State.self, from: d) }
        func save(_ s: P.State) -> Data { (try? enc.encode(s)) ?? Data() }
        initBox = { ctx in save(P.initState(ctx: &ctx)) }
        reduce = { d, a, sitz, ctx in guard var s = load(d) else { return }; P.reduce(&s, action: a, from: sitz, ctx: &ctx); d = save(s) }
        tick = { d, ctx in guard var s = load(d) else { return }; P.tick(&s, ctx: &ctx); d = save(s) }
        onDisconnect = { d, sitz, ctx in guard var s = load(d) else { return }; P.onDisconnect(&s, sitz: sitz, ctx: &ctx); d = save(s) }
        isFinished = { d in load(d).map { P.isFinished($0) } ?? true }
        results = { d, ctx in load(d).map { P.results($0, ctx: ctx) } ?? [] }
        scene = { d, ctx in load(d).map { P.scene($0, ctx: ctx) } }
        prompt = { d, sitz, ctx in load(d).map { P.prompt($0, sitz: sitz, ctx: ctx) } ?? .idle(title: "…", subtitle: nil) }
        currentSeat = { d in load(d).flatMap { P.currentSeat($0) } }
        shift = { d, ms in guard var s = load(d) else { return }; P.shift(&s, ms: ms); d = save(s) }
    }
}

public enum BoardgameRegistry {
    public static let all: [AnyBoardgame] = [
        AnyBoardgame(Werwolf.self),
        AnyBoardgame(Uno.self),
        AnyBoardgame(Madn.self),
        AnyBoardgame(Bananopoly.self),
        AnyBoardgame(Affenturm.self),
        AnyBoardgame(Siedler.self),
    ]
    public static func plugin(_ id: String) -> AnyBoardgame? { all.first { $0.meta.id == id } }
}

/// Engine glue for the Spiele-Abend track: howto → spiel → ergebnis inside
/// the room, one MM booking per game, AT hook via the room layer.
public enum Boardgames {
    static let howtoMs = 15_000

    public static func cards(_ s: EngineState) -> [BoardgameCard] {
        BoardgameRegistry.all.map { p in
            let n = s.players.count
            let startbar = n >= p.meta.minSpieler && n <= p.meta.maxSpieler
            let hint = n < p.meta.minSpieler ? "Mindestens \(p.meta.minSpieler) Spieler" : (n > p.meta.maxSpieler ? "Höchstens \(p.meta.maxSpieler) Spieler" : (p.meta.phonesOnly ? "Nur mit Handys" : "Handys + iPad-Sitze möglich"))
            return BoardgameCard(id: p.meta.id, name: p.meta.name, emoji: p.meta.emoji, untertitel: p.meta.untertitel, minSpieler: p.meta.minSpieler, maxSpieler: p.meta.maxSpieler,
                                 phonesOnly: p.meta.phonesOnly, howto: p.meta.howto, startbar: startbar, hinweis: hint, varianten: p.meta.varianten)
        }
    }

    static func context(_ s: EngineState, box: BoardgameBox, now: Millis) -> BoardgameContext {
        var names: [String: String] = [:]
        var connected: Set<String> = []
        for p in s.players { names[p.id] = p.name; if p.connected { connected.insert(p.id) } }
        for (i, l) in box.lokaleSitze.enumerated() { names["lokal_\(i)"] = l; connected.insert("lokal_\(i)") }
        return BoardgameContext(now: now, rng: s.rng, settings: s.settings, sitze: box.sitze, names: names, connected: connected,
                                lokale: Set(box.sitze.filter { $0.hasPrefix("lokal_") }), optionen: box.optionen)
    }

    public static func start(_ s: inout EngineState, id: String, optionen: [String: JSONValue], catalog: ContentCatalog, now: Millis) {
        guard s.phase == .lobby || s.phase == .brettspiel, s.settings.spielModus == .spieleabend, let plugin = BoardgameRegistry.plugin(id) else { return }
        let lokale = (optionen["lokaleSitze"]?.arrayValue ?? []).compactMap { $0.stringValue }.filter { !$0.isEmpty }
        var sitze = s.connectedPlayers.map { $0.id }
        if plugin.meta.gemischteSitze { for i in lokale.indices { sitze.append("lokal_\(i)") } }
        guard sitze.count >= plugin.meta.minSpieler, sitze.count <= plugin.meta.maxSpieler else { return }
        var box = BoardgameBox(id: id, data: Data(), subphase: "howto", howtoEndsAt: now + s.settings.ms(howtoMs), sitze: sitze, lokaleSitze: plugin.meta.gemischteSitze ? lokale : [],
                               ergebnis: nil, startedAt: now, optionen: optionen)
        var ctx = context(s, box: box, now: now)
        box.data = plugin.initBox(&ctx)
        s.rng = ctx.rng
        s.boardgame = box
        s.phase = .brettspiel
        s.phaseStartedAt = now
        s.phaseEndsAt = box.howtoEndsAt
        s.abend.beginnAt = s.abend.beginnAt ?? now
        s.addLog("brettspiel", "\(plugin.meta.name) gestartet (\(sitze.count) Sitze)", at: now)
        s.addMoment("brettspiel", "\(plugin.meta.emoji) \(plugin.meta.name) — Erklärkarte", at: now)
    }

    public static func abort(_ s: inout EngineState, now: Millis) {
        guard s.phase == .brettspiel else { return }
        s.boardgame = nil
        s.phase = .lobby
        s.phaseEndsAt = nil
        s.addMoment("brettspiel", "✕ Spiel abgebrochen — zurück zur Spiele-Lobby", at: now)
    }

    public static func next(_ s: inout EngineState, catalog: ContentCatalog, now: Millis) {
        guard var box = s.boardgame else { return }
        switch box.subphase {
        case "howto":
            box.subphase = "spiel"
            box.howtoEndsAt = nil
            s.boardgame = box
            s.phaseEndsAt = nil
        case "ergebnis":
            // Rematch with the same options.
            let id = box.id
            let opts = box.optionen
            s.boardgame = nil
            s.phase = .lobby
            start(&s, id: id, optionen: opts, catalog: catalog, now: now)
        default:
            break
        }
    }

    public static func advanceLabel(_ s: EngineState) -> String? {
        guard let box = s.boardgame else { return nil }
        switch box.subphase {
        case "howto": return "Los geht's"
        case "ergebnis": return "Rematch!"
        default: return nil
        }
    }

    static func withPlugin(_ s: inout EngineState, now: Millis, _ body: (AnyBoardgame, inout BoardgameBox, inout BoardgameContext) -> Void) {
        guard var box = s.boardgame, let plugin = BoardgameRegistry.plugin(box.id) else { return }
        var ctx = context(s, box: box, now: now)
        body(plugin, &box, &ctx)
        s.rng = ctx.rng
        s.boardgame = box
    }

    public static func playerAction(_ s: inout EngineState, _ id: PlayerId, _ action: PlayerAction, catalog: ContentCatalog, now: Millis) {
        guard let box = s.boardgame, box.subphase == "spiel", box.sitze.contains(id) else { return }
        withPlugin(&s, now: now) { plugin, box, ctx in plugin.reduce(&box.data, action, id, &ctx) }
        finishIfDone(&s, now: now)
    }

    public static func localAction(_ s: inout EngineState, sitz: String, _ action: PlayerAction, catalog: ContentCatalog, now: Millis) {
        guard let box = s.boardgame, box.subphase == "spiel", box.sitze.contains(sitz), sitz.hasPrefix("lokal_") else { return }
        withPlugin(&s, now: now) { plugin, box, ctx in plugin.reduce(&box.data, action, sitz, &ctx) }
        finishIfDone(&s, now: now)
    }

    public static func shift(_ s: inout EngineState, ms: Int, now: Millis) {
        withPlugin(&s, now: now) { plugin, box, _ in plugin.shift(&box.data, ms) }
    }

    static func finishIfDone(_ s: inout EngineState, now: Millis) {
        guard var box = s.boardgame, box.subphase == "spiel", let plugin = BoardgameRegistry.plugin(box.id), plugin.isFinished(box.data) else { return }
        let ctx = context(s, box: box, now: now)
        let res = plugin.results(box.data, ctx)
        var out: [BoardgameResult] = []
        for r in res {
            let lokal = r.sitz.hasPrefix("lokal_")
            let mm = lokal ? 0 : Economy.boardgamePayout(place: r.platz, half: plugin.meta.halbePayout)
            if let i = s.index(of: r.sitz) {
                s.players[i].balance += mm
                let at = Economy.allTimeForBoardgame(mm: mm)
                s.abend.proKopf[r.sitz, default: 0] += at
                s.abend.atGesamt += at
            }
            out.append(BoardgameResult(sitz: r.sitz, name: ctx.name(r.sitz), platz: r.platz, mm: mm, detail: r.detail, lokal: lokal))
        }
        box.ergebnis = out.sorted { $0.platz < $1.platz }
        box.subphase = "ergebnis"
        s.boardgame = box
        s.abend.spiele += 1
        s.addLog("brettspiel", "\(plugin.meta.name) beendet", at: now)
        if let w = out.first(where: { $0.platz == 1 }) { s.addMoment("brettspiel", "🏆 \(w.name) gewinnt \(plugin.meta.name)!", at: now) }
    }

    public static func stageView(_ s: EngineState, catalog: ContentCatalog, now: Millis) -> BoardgameStageView {
        guard let box = s.boardgame, let plugin = BoardgameRegistry.plugin(box.id) else {
            return BoardgameStageView(id: "", name: "", subphase: "howto", howto: [], howtoEndsAt: nil, view: .null, ergebnis: nil, aktuellerSpieler: nil, lokalerPrompt: nil)
        }
        let ctx = context(s, box: box, now: now)
        let scene = plugin.scene(box.data, ctx)
        let encoded = scene.flatMap { try? JSONEncoder().encode($0) }.flatMap { try? JSONDecoder().decode(JSONValue.self, from: $0) } ?? .null
        let current = plugin.currentSeat(box.data)
        var lokalerPrompt: String? = nil
        if let c = current, c.hasPrefix("lokal_"), box.subphase == "spiel" { lokalerPrompt = "📲 Gib das iPad an \(ctx.name(c))!" }
        return BoardgameStageView(id: box.id, name: plugin.meta.name, subphase: box.subphase, howto: plugin.meta.howto, howtoEndsAt: box.howtoEndsAt, view: encoded,
                                  ergebnis: box.ergebnis, aktuellerSpieler: current.map { ctx.name($0) }, lokalerPrompt: lokalerPrompt)
    }

    /// Typed scene for the native stage (avoids the JSON round trip).
    public static func scene(_ s: EngineState, now: Millis) -> BoardgameScene? {
        guard let box = s.boardgame, let plugin = BoardgameRegistry.plugin(box.id) else { return nil }
        return plugin.scene(box.data, context(s, box: box, now: now))
    }

    /// Prompt for a local (pass-and-play) seat rendered on the iPad.
    public static func localPrompt(_ s: EngineState, sitz: String, now: Millis) -> PlayerPrompt? {
        guard let box = s.boardgame, box.subphase == "spiel", let plugin = BoardgameRegistry.plugin(box.id) else { return nil }
        return plugin.prompt(box.data, sitz, context(s, box: box, now: now))
    }

    public static func playerPrompt(_ s: EngineState, _ id: PlayerId, catalog: ContentCatalog, now: Millis) -> PlayerPrompt {
        guard let box = s.boardgame, let plugin = BoardgameRegistry.plugin(box.id) else { return .idle(title: "Spiele-Abend", subtitle: nil) }
        switch box.subphase {
        case "howto": return .explain(title: "\(plugin.meta.emoji) \(plugin.meta.name)", text: plugin.meta.howto.joined(separator: "\n"), ready: false, streik: false, deadline: box.howtoEndsAt)
        case "ergebnis":
            let mine = box.ergebnis?.first { $0.sitz == id }
            return .reveal(title: mine.map { "Platz \($0.platz)" } ?? "Ergebnis", correct: mine.map { $0.platz == 1 }, delta: mine?.mm ?? 0, detail: mine?.detail, streak: 0, speedBonus: nil)
        default:
            guard box.sitze.contains(id) else { return .idle(title: "👀 Zuschauer", subtitle: "Beim nächsten Spiel bist du dabei") }
            return plugin.prompt(box.data, id, context(s, box: box, now: now))
        }
    }

    public static func lobbyPrompt(_ s: EngineState, _ id: PlayerId) -> PlayerPrompt {
        .idle(title: "🎲 Spiele-Abend", subtitle: "Der Bildschirm wählt das nächste Spiel")
    }
}

extension Engine {
    func tickBoardgame(_ s: inout EngineState, now: Millis) {
        guard var box = s.boardgame else { s.phase = .lobby; return }
        switch box.subphase {
        case "howto":
            if let end = box.howtoEndsAt, now >= end { box.subphase = "spiel"; box.howtoEndsAt = nil; s.boardgame = box; s.phaseEndsAt = nil }
        case "spiel":
            Boardgames.withPlugin(&s, now: now) { plugin, box, ctx in plugin.tick(&box.data, &ctx) }
            Boardgames.finishIfDone(&s, now: now)
        default:
            break
        }
    }
}
