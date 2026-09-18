import Foundation

/// The show server the iPad runs: static web client, media, profile REST API
/// and the WebSocket room protocol. Everything touching the hub happens on
/// one serial queue.
public final class ShowServer: @unchecked Sendable {
    public struct Roots {
        public var web: URL
        public var fonts: URL
        public var content: URL
        public var audio: URL?
        public init(web: URL, fonts: URL, content: URL, audio: URL? = nil) {
            self.web = web
            self.fonts = fonts
            self.content = content
            self.audio = audio
        }
    }

    public let http: HTTPServer
    public let hub: RoomHub
    public let queue = DispatchQueue(label: "mm.show")
    public var meta: MetaStore
    public var onMetaChanged: ((MetaStore) -> Void)?
    public var onStageChanged: ((StageView) -> Void)?
    public var clock: () -> Millis = { Int(Date().timeIntervalSince1970 * 1000) }
    /// Extra routes (dev server: stage console without an iPad).
    public var extraRoutes: ((HTTPServer.Request) -> HTTPServer.Response?)?
    /// Edition label shown on the join page ("" = classic, "League Edition" …).
    public var edition: String = ""
    let roots: Roots
    private var timer: DispatchSourceTimer?
    private var lastStageSeq = -1
    /// Übungsmodus (solo practice on the phone): per-device recent questions + stats, in memory.
    struct PracticeStats: Codable { var gespielt = 0; var richtig = 0; var serie = 0; var beste = 0 }
    private var practiceUsed: [String: [String]] = [:]
    private var practiceStats: [String: PracticeStats] = [:]
    private var practiceOpen: [String: (question: Question, order: [Int])] = [:]

    public init(port: UInt16, hub: RoomHub, meta: MetaStore, roots: Roots) {
        http = HTTPServer(port: port)
        self.hub = hub
        self.meta = meta
        self.roots = roots
        hub.profileHook = ProfileHook(
            login: { [weak self] id, pin, device in
                guard let self = self else { return .failure("Server weg") }
                let now = self.clock()
                switch self.meta.login(id, pin: pin, deviceToken: device, now: now) {
                case .success(let p): self.onMetaChanged?(self.meta); return .success(ProfileHook.ProfileInfo(id: p.id, name: p.name, avatar: p.wireAvatar))
                case .failure(.pinRequired): return .failure("Dieses Profil ist mit einer PIN geschützt.")
                case .failure(.pinWrong): return .failure("Falsche PIN.")
                case .failure(.unknown): return .failure("Profil nicht gefunden.")
                }
            },
            matchEnded: { [weak self] profileId, player, at, winner, matchId in
                guard let self = self else { return }
                if let event = self.meta.bookMatch(profileId, player: player, at: at, winner: winner, matchId: matchId, now: self.clock()) {
                    self.onMetaChanged?(self.meta)
                    self.pushProfileEvent(event, playerId: player.id)
                }
            })
        http.handler = { [weak self] req in self?.route(req) ?? .notFound() }
        http.onWebSocketOpen = { _, _ in }
        http.onWebSocketMessage = { [weak self] id, text in self?.queue.async { self?.wsMessage(id, text) } }
        http.onWebSocketClose = { [weak self] id in self?.queue.async { guard let self = self else { return }; self.deliver(self.hub.connectionClosed(id, now: self.clock())) } }
    }

    public func start() throws {
        try http.start()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: .milliseconds(250))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    public func stop() {
        timer?.cancel()
        timer = nil
        http.stop()
    }

    public var port: UInt16 { http.port }

    // MARK: Hub access

    func tick() {
        let now = clock()
        deliver(hub.tick(now: now))
        if hub.state.seq != lastStageSeq || now % 1000 < 250 {
            lastStageSeq = hub.state.seq
            onStageChanged?(hub.stageView(now: now))
        }
    }

    func wsMessage(_ id: String, _ text: String) {
        guard let msg = Wire.decode(ClientMessage.self, Data(text.utf8)) else {
            http.send(id, text: String(data: Wire.encode(ServerMessage.error(code: "bad-message", message: "Nachricht nicht verstanden")), encoding: .utf8) ?? "")
            return
        }
        deliver(hub.handle(id, msg, now: clock()))
    }

    func deliver(_ out: [RoomHub.Outgoing]) {
        for o in out {
            if let s = String(data: Wire.encode(o.message), encoding: .utf8) { http.send(o.connection, text: s) }
        }
    }

    func pushProfileEvent(_ event: ProfileEvent, playerId: PlayerId) {
        for (conn, token) in hub.connections where hub.sessions[token]?.playerId == playerId {
            http.send(conn, text: String(data: Wire.encode(ServerMessage.profileEvent(event)), encoding: .utf8) ?? "")
        }
    }

    /// Stage-side entry points (called from the UI thread; hop onto the queue).
    public func stageCommand(_ cmd: GmCommand) {
        queue.async { [self] in deliver(hub.stageCommand(cmd, now: clock())); onStageChanged?(hub.stageView(now: clock())) }
    }

    public func stagePlayerAction(_ pid: PlayerId, _ action: PlayerAction) {
        queue.async { [self] in deliver(hub.stagePlayerAction(pid, action, now: clock())); onStageChanged?(hub.stageView(now: clock())) }
    }

    public func withHub<T>(_ body: (RoomHub) -> T) -> T {
        queue.sync { body(hub) }
    }

    // MARK: Routing

    func route(_ req: HTTPServer.Request) -> HTTPServer.Response {
        let path = req.path
        if let extra = extraRoutes?(req) { return extra }
        if path == "/" || path.hasPrefix("/j/") || path == "/player" || path == "/player.html" { return file(roots.web.appendingPathComponent("player.html")) }
        if path == "/gm" || path == "/gm.html" { return file(roots.web.appendingPathComponent("gm.html")) }
        if path == "/uebung" || path == "/uebung.html" { return file(roots.web.appendingPathComponent("uebung.html")) }
        if path == "/healthz" { return .text("ok") }
        if path.hasPrefix("/api/") { return queue.sync { api(req) } }
        if path.hasPrefix("/fonts/") { return file(roots.fonts.appendingPathComponent(String(path.dropFirst("/fonts/".count)))) }
        if path.hasPrefix("/media/pixel/") { return file(roots.content.appendingPathComponent("pixel/" + String(path.dropFirst("/media/pixel/".count)))) }
        if path.hasPrefix("/media/audio/"), let audio = roots.audio { return file(audio.appendingPathComponent(String(path.dropFirst("/media/audio/".count)))) }
        if path.hasPrefix("/apple-app-site-association") || path == "/.well-known/apple-app-site-association" { return aasa() }
        let rel = String(path.dropFirst())
        guard !rel.contains("..") else { return .notFound() }
        return file(roots.web.appendingPathComponent(rel))
    }

    func file(_ url: URL) -> HTTPServer.Response {
        guard let data = try? Data(contentsOf: url) else { return .notFound() }
        return HTTPServer.Response(contentType: HTTPServer.mimeType(for: url.path), body: data)
    }

    /// Associated-domains file for universal links into the installed app
    /// (served for completeness; needs an HTTPS domain registered by Apple).
    func aasa() -> HTTPServer.Response {
        let json = """
        {"applinks":{"apps":[],"details":[{"appIDs":["TEAMID.de.monkeymoney.app"],"components":[{"/":"/j/*"},{"/":"/gm"}]}]}}
        """
        return .json(Data(json.utf8))
    }

    // MARK: Profile REST API (used by the join page and the iPad UI)

    struct ProfileSummary: Codable {
        var id: String; var name: String; var avatar: String; var level: Int; var atAktuell: Int; var atGesamt: Int; var hasPin: Bool
        init(_ p: Profile) { id = p.id; name = p.name; avatar = p.wireAvatar.wire; level = p.level; atAktuell = p.atAktuell; atGesamt = p.atGesamt; hasPin = p.pin != nil }
    }

    func api(_ req: HTTPServer.Request) -> HTTPServer.Response {
        let now = clock()
        let enc = Wire.encoder
        switch (req.method, req.path) {
        case ("GET", "/api/profiles"):
            let device = req.query["device"] ?? ""
            let list = meta.profiles(forDevice: device).map(ProfileSummary.init)
            return .json((try? enc.encode(list)) ?? Data("[]".utf8))
        case ("GET", "/api/profiles/find"):
            let name = (req.query["name"] ?? "").lowercased()
            guard let p = meta.profiles.first(where: { $0.name.lowercased() == name }) else { return .text("not found", status: 404) }
            switch meta.login(p.id, pin: req.query["pin"].flatMap { $0.isEmpty ? nil : $0 }, deviceToken: req.query["device"], now: now) {
            case .success(let prof):
                onMetaChanged?(meta)
                return .json((try? enc.encode(ProfileSummary(prof))) ?? Data())
            case .failure: return .text("pin", status: 401)
            }
        case ("POST", "/api/profiles"):
            struct Body: Decodable { var name: String; var avatar: String?; var pin: String?; var device: String? }
            guard let body = Wire.decode(Body.self, req.body), !body.name.trimmingCharacters(in: .whitespaces).isEmpty else { return .text("bad request", status: 400) }
            var rng = SeededRandom(seed: UInt32(truncatingIfNeeded: now))
            let p = meta.create(name: body.name, avatar: Avatar(wire: body.avatar ?? ""), pin: body.pin, deviceToken: body.device, now: now, rng: &rng)
            onMetaChanged?(meta)
            return .json((try? enc.encode(ProfileSummary(p))) ?? Data())
        case ("GET", "/api/shop"):
            return .json((try? enc.encode(Shop.items)) ?? Data())
        case ("GET", "/api/boards"):
            return .json((try? enc.encode(meta.boards())) ?? Data())
        case ("GET", "/api/room"):
            struct Info: Codable { var code: String; var phase: String; var players: Int; var joinURL: String; var edition: String }
            return .json((try? enc.encode(Info(code: hub.state.roomCode, phase: hub.state.phase.rawValue, players: hub.state.players.count, joinURL: hub.joinURL, edition: edition))) ?? Data())
        case ("GET", "/api/kategorien"):
            return .json((try? enc.encode(hub.engine.catalog.categories)) ?? Data("[]".utf8))
        case ("GET", "/api/uebung/frage"):
            return practiceQuestion(req)
        case ("POST", "/api/uebung/antwort"):
            return practiceAnswer(req)
        default:
            break
        }
        // /api/profiles/:id/(update|kaufe|ruestung|karte)
        let parts = req.path.split(separator: "/").map(String.init)
        if parts.count == 4, parts[0] == "api", parts[1] == "profiles" {
            let id = parts[2]
            guard let p = meta.profile(id) else { return .text("not found", status: 404) }
            switch (req.method, parts[3]) {
            case ("GET", "karte"):
                return .json((try? enc.encode(p)) ?? Data())
            case ("POST", "update"):
                struct Body: Decodable { var name: String?; var avatar: String?; var pin: String?; var device: String?; var newPin: String? }
                guard let body = Wire.decode(Body.self, req.body) else { return .text("bad request", status: 400) }
                if case .failure = meta.login(id, pin: body.pin, deviceToken: body.device, now: now) { return .text("pin", status: 401) }
                meta.update(id, name: body.name, avatar: body.avatar.map { Avatar(wire: $0) }, pin: body.newPin.map { $0.isEmpty ? nil : $0 })
                onMetaChanged?(meta)
                return .json((try? enc.encode(ProfileSummary(meta.profile(id)!))) ?? Data())
            case ("POST", "kaufe"):
                struct Body: Decodable { var item: String; var pin: String?; var device: String? }
                guard let body = Wire.decode(Body.self, req.body) else { return .text("bad request", status: 400) }
                if case .failure = meta.login(id, pin: body.pin, deviceToken: body.device, now: now) { return .text("pin", status: 401) }
                switch meta.buy(id, item: body.item) {
                case .success(let prof): onMetaChanged?(meta); return .json((try? enc.encode(prof)) ?? Data())
                case .failure(let e): return .text("\(e)", status: 400)
                }
            case ("POST", "ruestung"):
                struct Body: Decodable { var slot: String; var item: String? }
                guard let body = Wire.decode(Body.self, req.body) else { return .text("bad request", status: 400) }
                meta.equip(id, item: body.item, slot: body.slot)
                onMetaChanged?(meta)
                return .json((try? enc.encode(meta.profile(id)!)) ?? Data())
            default: break
            }
        }
        return .notFound()
    }

    // MARK: Übungsmodus

    struct PracticeQuestionOut: Codable {
        var id: String; var kat: String; var katName: String; var katEmoji: String; var schw: String; var wert: Int
        var text: String; var options: [String]; var typ: String; var stats: PracticeStats
    }

    func practiceQuestion(_ req: HTTPServer.Request) -> HTTPServer.Response {
        let device = req.query["device"] ?? "anon"
        let catalog = hub.engine.catalog
        var opts = PickOptions(anzahl: 1, used: Set(practiceUsed[device] ?? []), typen: [.choice, .wahrFalsch, .emoji],
                               kidSafeOnly: req.query["familie"] == "1", allowAdult: false, mix: .ausgewogen)
        if let k = req.query["kat"], !k.isEmpty { opts.kategorien = [k] }
        if let s = req.query["schw"], let d = Difficulty(rawValue: s) { opts.schwierigkeiten = [d] }
        var rng = SeededRandom(seed: UInt32(truncatingIfNeeded: clock() ^ Int(device.hashValue & 0xFFFF)))
        var picked = catalog.pick(opts, rng: &rng).first
        if picked == nil { practiceUsed[device] = []; opts.used = []; picked = catalog.pick(opts, rng: &rng).first }
        guard let q = picked, let correct = q.correctIndex else { return .text("keine Frage", status: 404) }
        var recent = practiceUsed[device] ?? []
        recent.append(q.id)
        if recent.count > 400 { recent.removeFirst(recent.count - 400) }
        practiceUsed[device] = recent
        // Shuffle the options for choice questions (never for Wahr/Falsch).
        let base = q.choiceOptions
        let order = q.typ == .wahrFalsch ? Array(base.indices) : rng.shuffled(Array(base.indices))
        practiceOpen[device] = (q, order)
        _ = correct
        let out = PracticeQuestionOut(id: q.id, kat: q.kat, katName: catalog.categoryName(q.kat), katEmoji: catalog.categoryEmoji(q.kat), schw: q.schw.rawValue, wert: q.value,
                                      text: q.displayText, options: order.map { base[$0] }, typ: q.typ.rawValue, stats: practiceStats[device] ?? PracticeStats())
        return .json((try? Wire.encoder.encode(out)) ?? Data())
    }

    func practiceAnswer(_ req: HTTPServer.Request) -> HTTPServer.Response {
        struct Body: Decodable { var id: String; var index: Int?; var device: String? }
        struct Out: Codable { var correct: Bool; var correctIndex: Int; var erkl: String; var tipps: [String]; var stats: PracticeStats }
        guard let body = Wire.decode(Body.self, req.body) else { return .text("bad request", status: 400) }
        let device = body.device ?? "anon"
        guard let open = practiceOpen[device], open.question.id == body.id, let correct = open.question.correctIndex,
              let shownCorrect = open.order.firstIndex(of: correct) else { return .text("keine offene Frage", status: 409) }
        practiceOpen[device] = nil
        var stats = practiceStats[device] ?? PracticeStats()
        let ok = body.index == shownCorrect
        stats.gespielt += 1
        if ok { stats.richtig += 1; stats.serie += 1; stats.beste = max(stats.beste, stats.serie) } else { stats.serie = 0 }
        practiceStats[device] = stats
        let out = Out(correct: ok, correctIndex: shownCorrect, erkl: open.question.erkl, tipps: open.question.tipps, stats: stats)
        return .json((try? Wire.encoder.encode(out)) ?? Data())
    }
}
