import Foundation

/// Transport-agnostic room server: owns the engine state, sessions and
/// connections, turns client messages into engine actions and produces the
/// role-filtered views to send. The iPad app wraps it with a WebSocket
/// listener (Network.framework); tests drive it directly.
public final class RoomHub: @unchecked Sendable {
    public struct Session: Codable, Equatable, Sendable {
        public var token: String
        public var role: Role
        public var playerId: PlayerId?
        public var profileId: String?
        public var lastSeen: Millis
    }

    public struct Outgoing: Equatable, Sendable {
        public var connection: String
        public var message: ServerMessage
    }

    public var state: EngineState
    public let engine: Engine
    public private(set) var sessions: [String: Session] = [:]
    /// connection id → session token
    public private(set) var connections: [String: String] = [:]
    public var joinBaseURL: String
    public var lastBroadcastSeq = -1
    public var onStateChanged: ((EngineState) -> Void)?
    public var profileHook: ProfileHook?
    private var lastPhase: Phase
    private var matchBookedId: String?

    public init(engine: Engine, state: EngineState, joinBaseURL: String) {
        self.engine = engine
        self.state = state
        self.joinBaseURL = joinBaseURL
        lastPhase = state.phase
    }

    // MARK: URLs

    public var joinURL: String { "\(joinBaseURL)/j/\(state.roomCode)" }
    public var gmURL: String { "\(joinBaseURL)/gm?code=\(state.roomCode)" }

    public static func makeRoomCode(rng: inout SeededRandom) -> String {
        let letters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ")
        return String((0..<4).map { _ in letters[rng.below(letters.count)] })
    }

    public static func makeGmPin(rng: inout SeededRandom) -> String {
        String(format: "%04d", rng.below(10_000))
    }

    static func makeToken(rng: inout SeededRandom) -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        return String((0..<24).map { _ in chars[rng.below(chars.count)] })
    }

    // MARK: Connections

    public func connectionClosed(_ connection: String, now: Millis) -> [Outgoing] {
        guard let token = connections.removeValue(forKey: connection) else { return [] }
        guard let session = sessions[token] else { return [] }
        if session.role == .gm, !connections.values.contains(where: { sessions[$0]?.role == .gm }) {
            engine.reduce(&state, .gmPresence(false), now: now)
        }
        if let pid = session.playerId, !connections.values.contains(where: { sessions[$0]?.playerId == pid }) {
            engine.reduce(&state, .disconnect(pid), now: now)
        }
        return broadcast(now: now, force: true)
    }

    /// Handle one incoming frame; returns messages to send.
    public func handle(_ connection: String, _ message: ClientMessage, now: Millis) -> [Outgoing] {
        switch message {
        case .hello(let code, let role, let token, let name, let avatarWire, let gmPin, let profileId, let profilePin, let deviceToken):
            return hello(connection, code: code, role: role, token: token, name: name, avatarWire: avatarWire, gmPin: gmPin, profileId: profileId, profilePin: profilePin, deviceToken: deviceToken, now: now)
        case .action(let action, _):
            guard let session = session(for: connection), let pid = session.playerId else {
                return [Outgoing(connection: connection, message: .error(code: "no-session", message: "Bitte erst beitreten."))]
            }
            engine.reduce(&state, .player(pid, action), now: now)
            sessions[session.token]?.lastSeen = now
            return broadcast(now: now, force: true)
        case .gm(let cmd):
            guard let session = session(for: connection) else { return [Outgoing(connection: connection, message: .error(code: "no-session", message: "Bitte erst beitreten."))] }
            guard allowed(cmd, for: session) else { return [Outgoing(connection: connection, message: .error(code: "forbidden", message: "Dafür braucht es den Show-Master."))] }
            engine.reduce(&state, .gm(cmd), now: now)
            return broadcast(now: now, force: true)
        case .ping(let t0):
            if let s = session(for: connection) { sessions[s.token]?.lastSeen = now }
            return [Outgoing(connection: connection, message: .pong(t0: t0, serverTime: now))]
        case .sync:
            guard let session = session(for: connection), let msg = view(for: session, now: now) else { return [] }
            return [Outgoing(connection: connection, message: msg)]
        case .leave:
            guard let session = session(for: connection), let pid = session.playerId else { return [] }
            engine.reduce(&state, .leave(pid), now: now)
            sessions[session.token] = nil
            connections[connection] = nil
            return broadcast(now: now, force: true)
        }
    }

    func session(for connection: String) -> Session? {
        connections[connection].flatMap { sessions[$0] }
    }

    /// Authorisation matrix: GM everything; stage (screen) only in gmLos rooms
    /// (start/next/settings in the lobby); players nothing.
    func allowed(_ cmd: GmCommand, for session: Session) -> Bool {
        switch session.role {
        case .gm: return true
        case .screen:
            switch cmd {
            case .flowNext, .flowSkipOpening, .resume, .revanche, .boardgameStart, .boardgameAbort, .boardgameLocal, .pause, .kick, .teamsShuffle, .settingsSet, .botAdd, .botRemove, .lookSet:
                return true
            default: return false
            }
        default: return false
        }
    }

    func hello(_ connection: String, code: String, role: Role, token: String?, name: String?, avatarWire: String?, gmPin: String?, profileId: String?, profilePin: String?, deviceToken: String?, now: Millis) -> [Outgoing] {
        guard code.uppercased() == state.roomCode || role == .screen else {
            return [Outgoing(connection: connection, message: .error(code: "room", message: "Raum \(code.uppercased()) gibt es nicht."))]
        }
        // Reconnect with a known session token.
        if let t = token, var s = sessions[t] {
            s.lastSeen = now
            sessions[t] = s
            connections[connection] = t
            if let pid = s.playerId {
                if state.player(pid) != nil {
                    engine.reduce(&state, .connect(pid), now: now)
                } else {
                    // Player was removed (kicked/left) — re-join with the same id.
                    engine.reduce(&state, .join(playerId: pid, name: name ?? "Affe", avatar: Avatar(wire: avatarWire ?? ""), profileId: s.profileId, isBot: false), now: now)
                }
            }
            if s.role == .gm { engine.reduce(&state, .gmPresence(true), now: now) }
            var out = [Outgoing(connection: connection, message: .welcome(playerId: s.playerId, sessionToken: t, role: s.role, serverTime: now))]
            out += broadcast(now: now, force: true)
            return out
        }
        switch role {
        case .player:
            let cap = state.settings.spielModus == .spieleabend ? Engine.maxPlayersSpieleabend : Engine.maxPlayers
            guard state.players.count < cap else {
                return [Outgoing(connection: connection, message: .error(code: "full", message: "Der Raum ist voll (\(cap) Spieler)."))]
            }
            var avatar = Avatar(wire: avatarWire ?? "")
            var playerName = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            var boundProfile: String? = nil
            if let pid = profileId, let hook = profileHook {
                switch hook.login(pid, profilePin, deviceToken) {
                case .success(let profile):
                    playerName = profile.name
                    avatar = profile.avatar
                    boundProfile = profile.id
                case .failure(let msg):
                    return [Outgoing(connection: connection, message: .error(code: "profile", message: msg))]
                }
            }
            if playerName.isEmpty { playerName = "Gast-Gibbon #\(state.players.count + 1)" }
            // Unique display names.
            var candidate = playerName
            var n = 2
            while state.players.contains(where: { $0.name.lowercased() == candidate.lowercased() }) { candidate = "\(playerName) \(n)"; n += 1 }
            let pid = "p_" + RoomHub.makeToken(rng: &state.rng).prefix(8)
            let t = RoomHub.makeToken(rng: &state.rng)
            sessions[t] = Session(token: t, role: .player, playerId: pid, profileId: boundProfile, lastSeen: now)
            connections[connection] = t
            engine.reduce(&state, .join(playerId: pid, name: candidate, avatar: avatar, profileId: boundProfile, isBot: false), now: now)
            var out = [Outgoing(connection: connection, message: .welcome(playerId: pid, sessionToken: t, role: .player, serverTime: now))]
            out += broadcast(now: now, force: true)
            return out
        case .gm:
            guard gmPin == state.gmPin else {
                return [Outgoing(connection: connection, message: .error(code: "pin", message: "Falsche Show-Master-PIN."))]
            }
            let t = RoomHub.makeToken(rng: &state.rng)
            sessions[t] = Session(token: t, role: .gm, playerId: nil, profileId: nil, lastSeen: now)
            connections[connection] = t
            engine.reduce(&state, .gmPresence(true), now: now)
            var out = [Outgoing(connection: connection, message: .welcome(playerId: nil, sessionToken: t, role: .gm, serverTime: now))]
            out += broadcast(now: now, force: true)
            return out
        case .screen, .spectator:
            let t = RoomHub.makeToken(rng: &state.rng)
            sessions[t] = Session(token: t, role: role, playerId: nil, profileId: nil, lastSeen: now)
            connections[connection] = t
            return [Outgoing(connection: connection, message: .welcome(playerId: nil, sessionToken: t, role: role, serverTime: now)),
                    Outgoing(connection: connection, message: .stage(engine.stageView(state, now: now, joinURL: joinURL, gmURL: gmURL)))]
        }
    }

    // MARK: Tick & broadcast

    public func tick(now: Millis) -> [Outgoing] {
        engine.tick(&state, now: now)
        // Expire sessions whose players stayed away longer than the grace period only from the lobby.
        return broadcast(now: now, force: false)
    }

    func view(for session: Session, now: Millis) -> ServerMessage? {
        switch session.role {
        case .player:
            guard let pid = session.playerId, let v = engine.playerView(state, player: pid, now: now) else { return nil }
            return .player(v)
        case .gm:
            return .gm(engine.gmView(state, now: now, joinURL: joinURL, gmURL: gmURL))
        case .screen, .spectator:
            return .stage(engine.stageView(state, now: now, joinURL: joinURL, gmURL: gmURL))
        }
    }

    /// Send fresh views to every connection. Deadlines live in the views, so
    /// clients animate timers locally; we only push on state changes (seq)
    /// or every second as a heartbeat.
    public func broadcast(now: Millis, force: Bool) -> [Outgoing] {
        let changed = state.seq != lastBroadcastSeq || state.phase != lastPhase
        let heartbeat = now % 1000 < 250
        guard force || changed || heartbeat else { return [] }
        lastBroadcastSeq = state.seq
        if state.phase != lastPhase {
            lastPhase = state.phase
            onStateChanged?(state)
            hookMatchEnd(now: now)
        }
        var out: [Outgoing] = []
        for (conn, token) in connections {
            guard let s = sessions[token], let msg = view(for: s, now: now) else { continue }
            out.append(Outgoing(connection: conn, message: msg))
        }
        return out
    }

    /// Book AT for bound profiles once per match when the ceremony starts.
    func hookMatchEnd(now: Millis) {
        guard state.phase == .siegerehrung, matchBookedId != state.matchId, let hook = profileHook else { return }
        matchBookedId = state.matchId
        let ranking = state.ranking
        for (i, p) in ranking.enumerated() {
            guard let profileId = p.profileId else { continue }
            let at = Economy.allTimeFor(finalBalance: p.balance, isWinner: i == 0)
            hook.matchEnded(profileId, p, at, i == 0, state.matchId)
        }
    }

    /// Stage-side helpers (the iPad reads views directly, no socket needed).
    public func stageView(now: Millis) -> StageView { engine.stageView(state, now: now, joinURL: joinURL, gmURL: gmURL) }
    public func gmView(now: Millis) -> GmView { engine.gmView(state, now: now, joinURL: joinURL, gmURL: gmURL) }

    public func stageCommand(_ cmd: GmCommand, now: Millis) -> [Outgoing] {
        engine.reduce(&state, .gm(cmd), now: now)
        return broadcast(now: now, force: true)
    }

    public func stagePlayerAction(_ pid: PlayerId, _ action: PlayerAction, now: Millis) -> [Outgoing] {
        engine.reduce(&state, .player(pid, action), now: now)
        return broadcast(now: now, force: true)
    }

    /// Replace the state (save/load) and rebind existing sessions by player id.
    public func load(_ newState: EngineState, now: Millis) -> [Outgoing] {
        state = newState
        for (t, s) in sessions where s.playerId != nil && state.player(s.playerId!) == nil { sessions[t] = nil }
        connections = connections.filter { sessions[$0.value] != nil }
        return broadcast(now: now, force: true)
    }
}

/// Profile integration point (implemented by the iPad's ProfileStore).
public struct ProfileHook: Sendable {
    public struct ProfileInfo: Sendable {
        public var id: String
        public var name: String
        public var avatar: Avatar
        public init(id: String, name: String, avatar: Avatar) {
            self.id = id
            self.name = name
            self.avatar = avatar
        }
    }
    public enum LoginResult: Sendable { case success(ProfileInfo), failure(String) }

    public var login: @Sendable (_ profileId: String, _ pin: String?, _ deviceToken: String?) -> LoginResult
    public var matchEnded: @Sendable (_ profileId: String, _ player: Player, _ at: Int, _ winner: Bool, _ matchId: String) -> Void

    public init(login: @escaping @Sendable (String, String?, String?) -> LoginResult, matchEnded: @escaping @Sendable (String, Player, Int, Bool, String) -> Void) {
        self.login = login
        self.matchEnded = matchEnded
    }
}
