import Foundation

/// The whole host side of the show in one Foundation-only object — the iPad
/// app and the Linux dev server run exactly this. It keeps one HTTP server
/// alive for the app's lifetime and swaps rooms underneath it: main menu
/// (no room), lobby, match, back to the menu. The stage UI is a web page
/// (`/stage`) that drives the host through `/api/host/*` (loopback only on the
/// iPad) and the regular WebSocket as the `screen` role.
public final class ShowHost: @unchecked Sendable {
    public struct Config {
        public var storage: URL
        public var roots: ShowServer.Roots
        public var catalog: ContentCatalog
        public var edition: String
        public var editionQuestionSet: String
        /// Allow `/api/host/*` from other devices (dev server only).
        public var openHostAPI: Bool
        public var ports: ClosedRange<UInt16>
        public init(storage: URL, roots: ShowServer.Roots, catalog: ContentCatalog, edition: String = "", editionQuestionSet: String = QuestionSets.alleId,
                    openHostAPI: Bool = false, ports: ClosedRange<UInt16> = 8080...8086) {
            self.storage = storage
            self.roots = roots
            self.catalog = catalog
            self.edition = edition
            self.editionQuestionSet = editionQuestionSet
            self.openHostAPI = openHostAPI
            self.ports = ports
        }
    }

    public struct SaveSlot: Codable, Identifiable, Sendable {
        public var id: Int
        public var savedAt: Millis
        public var state: EngineState
        public var label: String
    }

    public let config: Config
    public private(set) var server: ShowServer!
    public let engine: Engine
    /// A room is open (lobby or match). Otherwise the stage shows the main menu.
    public private(set) var showActive = false
    public var lanIP: String = HTTPServer.lanIPv4() ?? "127.0.0.1"
    /// Extra routes layered on top (dev console).
    public var extraRoutes: ((HTTPServer.Request) -> HTTPServer.Response?)?
    public var onStage: ((StageView) -> Void)?
    private var lastPhase: Phase?
    private var botTimer: DispatchSourceTimer?
    private var clock: () -> Millis { { Int(Date().timeIntervalSince1970 * 1000) } }

    public init(config: Config) {
        self.config = config
        engine = Engine(catalog: config.catalog)
        try? FileManager.default.createDirectory(at: config.storage, withIntermediateDirectories: true)
    }

    public var port: UInt16 { server?.port ?? 0 }
    public var baseURL: String { "http://\(lanIP):\(port)" }
    public var localStageURL: String { "http://127.0.0.1:\(port)/stage" }

    // MARK: Lifecycle

    /// Bind the first free port of the range and serve the menu.
    public func start() throws {
        var lastError: Error?
        for p in config.ports {
            let srv = ShowServer(port: p, hub: makeIdleHub(port: p), meta: loadMeta(), roots: config.roots)
            srv.edition = config.edition
            do {
                try srv.start()
                server = srv
                lastError = nil
                break
            } catch {
                srv.http.stop()
                lastError = error
            }
        }
        if let e = lastError { throw e }
        guard let srv = server else { throw NSError(domain: "ShowHost", code: 1, userInfo: [NSLocalizedDescriptionKey: "Kein freier Port"]) }
        srv.onMetaChanged = { [weak self] m in self?.persistMeta(m) }
        srv.onStageChanged = { [weak self] v in self?.stageChanged(v) }
        srv.extraRoutes = { [weak self] req in self?.route(req) }
        startBotBrain()
    }

    public func stop() {
        botTimer?.cancel()
        botTimer = nil
        server?.stop()
    }

    private func makeIdleHub(port: UInt16) -> RoomHub {
        var settings = defaultSettings(.klassik)
        settings.gmLos = true
        let state = EngineState(matchId: "idle", roomCode: "----", seed: 1, settings: settings, now: clock(), gmPin: "----")
        return RoomHub(engine: engine, state: state, joinBaseURL: "http://\(lanIP):\(port)")
    }

    public func defaultSettings(_ modus: Modus) -> MatchSettings {
        var s = MatchSettings(modus: modus)
        s.applyQuestionSet(config.editionQuestionSet)
        return s
    }

    // MARK: Shows (all on the server queue)

    /// Open a fresh lobby.
    public func startShow(settings: MatchSettings) {
        server.queue.sync { openRoom(nil, settings: settings) }
    }

    private func openRoom(_ restoring: EngineState?, settings: MatchSettings) {
        let now = clock()
        lanIP = HTTPServer.lanIPv4() ?? lanIP
        var rng = SeededRandom(seed: UInt32(truncatingIfNeeded: now))
        var state = restoring ?? EngineState(matchId: "m-\(now)", roomCode: RoomHub.makeRoomCode(rng: &rng), seed: rng.state, settings: settings, now: now, gmPin: RoomHub.makeGmPin(rng: &rng))
        if restoring != nil {
            // Loaded match: code & PIN stay, humans rejoin by reconnecting.
            for i in state.players.indices { state.players[i].connected = state.players[i].isBot }
            if state.phase != .lobby, !state.paused { state.paused = true; state.pausedAt = now; state.pauseText = "💾 Spiel geladen — weiter mit ▶" }
        }
        let hub = RoomHub(engine: engine, state: state, joinBaseURL: "http://\(lanIP):\(port)")
        engine.reduce(&hub.state, .screenPresence(true), now: now)
        server.replaceHubOnQueue(hub)
        showActive = true
        lastPhase = hub.state.phase
    }

    /// Back to the main menu (autosave keeps an unfinished match).
    public func closeShow() {
        server.queue.sync { closeOnQueue() }
    }

    private func closeOnQueue() {
        if showActive, ![.lobby, .ende].contains(server.hub.state.phase) { writeSlot(0) }
        server.replaceHubOnQueue(makeIdleHub(port: port))
        showActive = false
        lastPhase = nil
    }

    private func stageChanged(_ view: StageView) {
        onStage?(view)
        guard showActive else { return }
        if view.phase != lastPhase {
            lastPhase = view.phase
            if [.zwischenstand, .rad, .siegerehrung, .brettspiel, .halbzeit].contains(view.phase) { writeSlot(0) }
            if view.phase == .ende { deleteSlot(0) }
        }
    }

    // MARK: Persistence

    private var metaURL: URL { config.storage.appendingPathComponent("meta.json") }
    private func slotURL(_ n: Int) -> URL { config.storage.appendingPathComponent(n == 0 ? "autosave.json" : "slot-\(n).json") }

    private func loadMeta() -> MetaStore {
        guard let d = try? Data(contentsOf: metaURL), let m = try? JSONDecoder().decode(MetaStore.self, from: d) else { return MetaStore() }
        return m
    }

    private func persistMeta(_ m: MetaStore) {
        if let d = try? JSONEncoder().encode(m) { try? d.write(to: metaURL, options: .atomic) }
    }

    public func readSlot(_ n: Int) -> SaveSlot? {
        guard let d = try? Data(contentsOf: slotURL(n)) else { return nil }
        return try? JSONDecoder().decode(SaveSlot.self, from: d)
    }

    private func writeSlot(_ n: Int) {
        let state = server.hub.state
        let runde = state.phase == .lobby ? "Lobby" : "Runde \(state.currentSection?.rundenNummer ?? 0)"
        let label = "\(state.settings.modus.title) · \(state.players.count) Spieler · \(runde)"
        let slot = SaveSlot(id: n, savedAt: clock(), state: state, label: label)
        if let d = try? JSONEncoder().encode(slot) { try? d.write(to: slotURL(n), options: .atomic) }
    }

    private func deleteSlot(_ n: Int) { try? FileManager.default.removeItem(at: slotURL(n)) }

    // MARK: Host API

    struct SlotSummary: Codable {
        struct P: Codable { var name: String; var avatar: String; var balance: Int }
        var id: Int; var savedAt: Millis; var label: String; var phase: String; var players: [P]
        init(_ s: SaveSlot) {
            id = s.id; savedAt = s.savedAt; label = s.label; phase = s.state.phase.rawValue
            players = s.state.ranking.map { P(name: $0.name, avatar: $0.avatar.wire, balance: $0.balance) }
        }
    }

    struct ModeInfo: Codable { var id: String; var title: String; var subtitle: String }
    struct RuleInfo: Codable { var id: String; var name: String; var emoji: String; var description: String }
    struct OptionInfo: Codable { var id: String; var label: String }

    struct HostState: Codable {
        var active: Bool
        var edition: String
        var questionCount: Int
        var categoryCount: Int
        var profileCount: Int
        var autosave: SlotSummary?
        var slots: [SlotSummary?]
        var roomCode: String?
        var joinURL: String?
        var gmURL: String?
        var gmPin: String?
        var baseURL: String
        var bots: Int
        var settings: MatchSettings?
        var modes: [ModeInfo]
        var tempos: [OptionInfo]
        var mixes: [OptionInfo]
        var specialRules: [RuleInfo]
        var questionSets: [QuestionSetInfo]
        var categories: [CategoryInfo]
        var defaults: [String: MatchSettings]
    }

    func hostState() -> HostState {
        let hub = server.hub
        var auto = readSlot(0)
        if let a = auto, a.state.phase == .ende || a.state.phase == .lobby { auto = nil }
        let pool = defaultSettings(.klassik).kategorienPool
        let cat = config.catalog
        return HostState(
            active: showActive, edition: config.edition, questionCount: cat.questions.count, categoryCount: cat.categories.count,
            profileCount: server.meta.profiles.count, autosave: auto.map(SlotSummary.init), slots: (1...3).map { readSlot($0).map(SlotSummary.init) },
            roomCode: showActive ? hub.state.roomCode : nil, joinURL: showActive ? hub.joinURL : nil, gmURL: showActive ? hub.gmURL : nil,
            gmPin: showActive ? hub.state.gmPin : nil, baseURL: baseURL, bots: hub.state.players.filter { $0.isBot }.count, settings: showActive ? hub.state.settings : nil,
            modes: Modus.allCases.map { ModeInfo(id: $0.rawValue, title: $0.title, subtitle: $0.subtitle) },
            tempos: Tempo.allCases.map { OptionInfo(id: $0.rawValue, label: $0.label) },
            mixes: FragenMix.allCases.map { OptionInfo(id: $0.rawValue, label: $0.label) },
            specialRules: SpecialRule.allCases.map { RuleInfo(id: $0.rawValue, name: $0.name, emoji: $0.emoji, description: $0.description) },
            questionSets: cat.questionSetInfos(activePool: pool, kidSafe: false), categories: cat.categoryInfos(activePool: pool, kidSafe: false),
            defaults: Dictionary(uniqueKeysWithValues: Modus.allCases.map { ($0.rawValue, defaultSettings($0)) }))
    }

    func route(_ req: HTTPServer.Request) -> HTTPServer.Response? {
        if let r = extraRoutes?(req) { return r }
        guard req.path.hasPrefix("/api/host/") else { return nil }
        guard config.openHostAPI || req.isLoopback else { return .text("Nur die Bühne darf das.", status: 403) }
        return server.queue.sync { hostAPI(req) }
    }

    private func ok() -> HTTPServer.Response { .json(Wire.encode(hostState())) }

    private func hostAPI(_ req: HTTPServer.Request) -> HTTPServer.Response {
        struct StartBody: Decodable { var modus: String?; var spielModus: String?; var patch: [String: JSONValue]? }
        struct SlotBody: Decodable { var slot: Int }
        struct BotBody: Decodable { var add: Int?; var remove: Bool? }
        switch (req.method, req.path) {
        case ("GET", "/api/host/state"):
            return ok()
        case ("POST", "/api/host/start"):
            let body = Wire.decode(StartBody.self, req.body)
            var s = defaultSettings(Modus(rawValue: body?.modus ?? "") ?? .klassik)
            if let sm = body?.spielModus, let v = SpielModus(rawValue: sm) { s.spielModus = v }
            if let p = body?.patch { s.apply(patch: p) }
            openRoom(nil, settings: s)
            return ok()
        case ("POST", "/api/host/load"):
            guard let b = Wire.decode(SlotBody.self, req.body), let slot = readSlot(b.slot) else { return .text("Kein Spielstand", status: 404) }
            openRoom(slot.state, settings: slot.state.settings)
            return ok()
        case ("POST", "/api/host/save"):
            guard showActive, let b = Wire.decode(SlotBody.self, req.body), (1...3).contains(b.slot) else { return .text("Keine Show", status: 409) }
            writeSlot(b.slot)
            return ok()
        case ("POST", "/api/host/delete"):
            guard let b = Wire.decode(SlotBody.self, req.body) else { return .text("bad request", status: 400) }
            deleteSlot(b.slot)
            return ok()
        case ("POST", "/api/host/close"):
            closeOnQueue()
            return ok()
        case ("POST", "/api/host/bots"):
            guard showActive else { return .text("Keine Show", status: 409) }
            let b = Wire.decode(BotBody.self, req.body)
            if b?.remove == true { removeBots() } else { for _ in 0..<max(1, min(8, b?.add ?? 1)) { addBot() } }
            server.deliver(server.hub.broadcast(now: clock(), force: true))
            return ok()
        default:
            return .notFound()
        }
    }

    // MARK: Bots (ordinary players with a headless brain)

    static let personas: [(String, String, String, Double)] = [
        ("Kokos", "gitti-giro", "gruen", 0.85), ("Splitter", "kiki-krawall", "rot", 0.6), ("Banana Joe", "schnarch-schorsch", "gelb", 0.55),
        ("Prof. Pavian", "baron-von-bananenstein", "lila", 0.75), ("Chaos-Kalle", "kahuna-kalle", "tuerkis", 0.5), ("Glitzer-Gabi", "glitzer-gina", "pink", 0.65),
        ("Astro-Anton", "astro-astrid", "blau", 0.7), ("DJ Dosenbier", "dj-trommelfell", "orange", 0.45),
    ]

    /// Seat `n` bots in the open room.
    public func addBots(_ n: Int) {
        server.queue.sync {
            guard showActive else { return }
            for _ in 0..<n { addBot() }
            server.deliver(server.hub.broadcast(now: clock(), force: true))
        }
    }

    private func addBot() {
        let hub = server.hub
        let taken = Set(hub.state.players.map(\.id))
        guard let n = (0..<Self.personas.count).first(where: { !taken.contains("bot_\($0)") }) else { return }
        let cap = hub.state.settings.spielModus == .spieleabend ? Engine.maxPlayersSpieleabend : Engine.maxPlayers
        guard hub.state.players.count < cap else { return }
        let p = Self.personas[n]
        engine.reduce(&hub.state, .join(playerId: "bot_\(n)", name: "\(p.0) 🤖", avatar: Avatar(affe: p.1, farbe: p.2), profileId: nil, isBot: true), now: clock())
    }

    private func removeBots() {
        let hub = server.hub
        for b in hub.state.players.filter(\.isBot) { engine.reduce(&hub.state, .leave(b.id), now: clock()) }
    }

    private func startBotBrain() {
        let t = DispatchSource.makeTimerSource(queue: server.queue)
        t.schedule(deadline: .now() + 1, repeating: .milliseconds(500))
        t.setEventHandler { [weak self] in self?.botTick() }
        t.resume()
        botTimer = t
    }

    private func botTick() {
        guard showActive else { return }
        let hub = server.hub
        let now = clock()
        let bots = hub.state.players.filter(\.isBot)
        guard !bots.isEmpty, !hub.state.paused else { return }
        var rng = SeededRandom(seed: UInt32(truncatingIfNeeded: now))
        for bot in bots {
            let n = Int(bot.id.dropFirst(4)) ?? 0
            let skill = Self.personas[n % Self.personas.count].3
            guard let v = engine.playerView(hub.state, player: bot.id, now: now) else { continue }
            let elapsed = now - (hub.state.minigame?.startedAt ?? hub.state.phaseStartedAt)
            let pixel = hub.state.minigame?.id == "pixel-dschungel"
            guard elapsed > (pixel ? 9000 : 2500) + n * 1300 else { continue }
            var actions: [PlayerAction] = []
            switch v.prompt {
            case .choice(_, let opts, let chosen, _, _, _):
                guard chosen == nil else { continue }
                let open = opts.filter { !$0.removed }
                var pick = rng.pick(open)?.id
                if rng.chance(skill), let c = correctOption(hub.state, open, now: now) { pick = c }
                if let p = pick { actions = [.choose(p)] }
            case .multiChoice(_, let opts, let chosen, let required, let locked, _):
                guard !locked, chosen.isEmpty else { continue }
                let ids = rng.shuffled(opts.filter { !$0.removed }.map(\.id)).prefix(max(1, required))
                actions = [.multiChoose(Array(ids))]
            case .bank(_, let opts, let chosen, let pot, _, _):
                if pot >= 400, rng.chance(0.3) { actions.append(.bank) }
                if chosen == nil {
                    let open = opts.filter { !$0.removed }
                    if let p = rng.chance(skill) ? correctOption(hub.state, open, now: now) : rng.pick(open)?.id { actions.append(.choose(p)) }
                }
            case .number(_, let lo, let hi, _, _, _, let cur, let locked, _):
                if cur == nil, !locked { actions = [.number(lo + (hi - lo) * rng.next())] }
            case .wager(_, _, let lo, let hi, let step, let cur, let locked, _):
                if cur == nil, !locked { actions = [.wager(lo + step * rng.below(max(1, (hi - lo) / max(1, step) + 1)))] }
            case .vote(_, let opts, let chosen, _):
                if chosen == nil, let o = rng.pick(opts) { actions = [.vote(o.id)] }
            case .explain(_, _, _, _, let ready, _, _):
                if !ready { actions = [.ready("bereit")] }
            case .order(_, let items, _, let locked, _):
                if !locked { actions = [.order(rng.shuffled(items.map(\.id))), .confirm] }
            case .pickPlayer(_, _, let cands, let chosen, _):
                if chosen == nil, let c = rng.pick(cands) { actions = [.pickPlayer(c.id)] }
            case .binary(_, _, let a, let b, let chosen, _):
                if chosen == nil { actions = [.binary(rng.chance(0.5) ? a : b)] }
            case .confirm(_, _, _, let done, _):
                if !done { actions = [.confirm] }
            case .chips(_, let opts, let total, _, let locked, _):
                if !locked {
                    var placed = Array(repeating: 0, count: opts.count)
                    for _ in 0..<total { placed[rng.below(max(1, opts.count))] += 1 }
                    actions = [.chips(placed), .confirm]
                }
            case .text(_, _, _, let submitted, _):
                if submitted == nil { actions = [.text(["Banane", "Kokosnuss", "Dschungel", "Mango", "Liane"][rng.below(5)])] }
            case .buzzer(_, let armed, let pressed, _, _):
                if armed, !pressed, rng.chance(0.15) { actions = [.buzz(at: now)] }
            case .tapFrenzy(_, let count, _, let active):
                if active { actions = [.taps(count + 2 + rng.below(4))] }
            case .feedback(_, let done):
                if !done { actions = [.feedback(["🍌", "👍", "Alles"])] }
            case .actions(_, _, let buttons, _):
                if let b = buttons.first(where: \.enabled), rng.chance(0.6) { actions = [.button(b.id)] }
            case .cards(_, let cards, let buttons, _, _):
                if let c = cards.first(where: { !$0.removed }) { actions = [.choose(c.id)] }
                else if let b = buttons.first(where: { $0.enabled && $0.id != "banane" }) { actions = [.button(b.id)] }
            default:
                break
            }
            for a in actions { engine.reduce(&hub.state, .player(bot.id, a), now: now) }
        }
    }

    private func correctOption(_ s: EngineState, _ open: [ChoiceOption], now: Millis) -> Int? {
        guard let box = s.minigame, let plugin = MinigameRegistry.plugin(box.id) else { return nil }
        let info = plugin.gmInfo(box.data, engine.context(s, now: now))
        guard let k = info.question?.korrekt else { return nil }
        return open.first { $0.text == k || $0.text.hasPrefix(k) }?.id
    }
}
