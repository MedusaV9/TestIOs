import Foundation

// MARK: - PlayerAction wire format
//
// `{"type":"choose","value":2}` style so the web client can build actions
// without knowing Swift's synthesized enum encoding.

extension PlayerAction {
    enum Keys: String, CodingKey { case type, value, at, id, stufe, avatar, list }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "choose": self = .choose(try c.decode(Int.self, forKey: .value))
        case "multiChoose": self = .multiChoose(try c.decode([Int].self, forKey: .list))
        case "buzz": self = .buzz(at: try c.decodeIfPresent(Millis.self, forKey: .at) ?? 0)
        case "number": self = .number(try c.decode(Double.self, forKey: .value))
        case "order": self = .order(try c.decode([Int].self, forKey: .list))
        case "wager": self = .wager(try c.decode(Int.self, forKey: .value))
        case "text": self = .text(try c.decode(String.self, forKey: .value))
        case "taps": self = .taps(try c.decode(Int.self, forKey: .value))
        case "chips": self = .chips(try c.decode([Int].self, forKey: .list))
        case "pickPlayer": self = .pickPlayer(try c.decode(String.self, forKey: .id))
        case "bank": self = .bank
        case "cheer": self = .cheer
        case "confirm": self = .confirm
        case "binary": self = .binary(try c.decode(String.self, forKey: .value))
        case "vote": self = .vote(try c.decode(String.self, forKey: .value))
        case "ready": self = .ready(try c.decode(String.self, forKey: .value))
        case "button": self = .button(try c.decode(String.self, forKey: .id))
        case "joker": self = .joker(id: try c.decode(String.self, forKey: .id), stufe: try c.decodeIfPresent(Int.self, forKey: .stufe))
        case "jokerBuy": self = .jokerBuy(try c.decode(String.self, forKey: .id))
        case "feedback": self = .feedback(try c.decode([String].self, forKey: .list))
        case "setLook": self = .setLook(try c.decode(Avatar.self, forKey: .avatar))
        case "setThemen": self = .setThemen(try c.decode([String].self, forKey: .list))
        case "radAktion": self = .radAktion(try c.decode(String.self, forKey: .value))
        case "teamWunsch": self = .teamWunsch(try c.decode(String.self, forKey: .value))
        default: throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "unknown action \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .choose(let i): try c.encode("choose", forKey: .type); try c.encode(i, forKey: .value)
        case .multiChoose(let l): try c.encode("multiChoose", forKey: .type); try c.encode(l, forKey: .list)
        case .buzz(let at): try c.encode("buzz", forKey: .type); try c.encode(at, forKey: .at)
        case .number(let v): try c.encode("number", forKey: .type); try c.encode(v, forKey: .value)
        case .order(let l): try c.encode("order", forKey: .type); try c.encode(l, forKey: .list)
        case .wager(let v): try c.encode("wager", forKey: .type); try c.encode(v, forKey: .value)
        case .text(let v): try c.encode("text", forKey: .type); try c.encode(v, forKey: .value)
        case .taps(let v): try c.encode("taps", forKey: .type); try c.encode(v, forKey: .value)
        case .chips(let l): try c.encode("chips", forKey: .type); try c.encode(l, forKey: .list)
        case .pickPlayer(let id): try c.encode("pickPlayer", forKey: .type); try c.encode(id, forKey: .id)
        case .bank: try c.encode("bank", forKey: .type)
        case .cheer: try c.encode("cheer", forKey: .type)
        case .confirm: try c.encode("confirm", forKey: .type)
        case .binary(let v): try c.encode("binary", forKey: .type); try c.encode(v, forKey: .value)
        case .vote(let v): try c.encode("vote", forKey: .type); try c.encode(v, forKey: .value)
        case .ready(let v): try c.encode("ready", forKey: .type); try c.encode(v, forKey: .value)
        case .button(let id): try c.encode("button", forKey: .type); try c.encode(id, forKey: .id)
        case .joker(let id, let stufe): try c.encode("joker", forKey: .type); try c.encode(id, forKey: .id); try c.encodeIfPresent(stufe, forKey: .stufe)
        case .jokerBuy(let id): try c.encode("jokerBuy", forKey: .type); try c.encode(id, forKey: .id)
        case .feedback(let l): try c.encode("feedback", forKey: .type); try c.encode(l, forKey: .list)
        case .setLook(let a): try c.encode("setLook", forKey: .type); try c.encode(a, forKey: .avatar)
        case .setThemen(let l): try c.encode("setThemen", forKey: .type); try c.encode(l, forKey: .list)
        case .radAktion(let v): try c.encode("radAktion", forKey: .type); try c.encode(v, forKey: .value)
        case .teamWunsch(let v): try c.encode("teamWunsch", forKey: .type); try c.encode(v, forKey: .value)
        }
    }
}

// MARK: - Envelopes

/// Client → server.
public enum ClientMessage: Codable, Equatable, Sendable {
    case hello(roomCode: String, role: Role, sessionToken: String?, name: String?, avatar: String?, gmPin: String?, profileId: String?, profilePin: String?, deviceToken: String?)
    case action(PlayerAction, idem: String?)
    case gm(GmCommand)
    case ping(t0: Millis)
    case sync
    case leave

    enum Keys: String, CodingKey { case t, roomCode, role, sessionToken, name, avatar, gmPin, profileId, profilePin, deviceToken, action, idem, cmd, t0 }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        switch try c.decode(String.self, forKey: .t) {
        case "hello":
            self = .hello(roomCode: try c.decodeIfPresent(String.self, forKey: .roomCode) ?? "", role: try c.decodeIfPresent(Role.self, forKey: .role) ?? .player,
                          sessionToken: try c.decodeIfPresent(String.self, forKey: .sessionToken), name: try c.decodeIfPresent(String.self, forKey: .name),
                          avatar: try c.decodeIfPresent(String.self, forKey: .avatar), gmPin: try c.decodeIfPresent(String.self, forKey: .gmPin),
                          profileId: try c.decodeIfPresent(String.self, forKey: .profileId), profilePin: try c.decodeIfPresent(String.self, forKey: .profilePin),
                          deviceToken: try c.decodeIfPresent(String.self, forKey: .deviceToken))
        case "action": self = .action(try c.decode(PlayerAction.self, forKey: .action), idem: try c.decodeIfPresent(String.self, forKey: .idem))
        case "gm": self = .gm(try c.decode(GmCommand.self, forKey: .cmd))
        case "ping": self = .ping(t0: try c.decodeIfPresent(Millis.self, forKey: .t0) ?? 0)
        case "sync": self = .sync
        case "leave": self = .leave
        case let other: throw DecodingError.dataCorruptedError(forKey: .t, in: c, debugDescription: "unknown message \(other)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .hello(let roomCode, let role, let token, let name, let avatar, let pin, let profileId, let profilePin, let deviceToken):
            try c.encode("hello", forKey: .t)
            try c.encode(roomCode, forKey: .roomCode)
            try c.encode(role, forKey: .role)
            try c.encodeIfPresent(token, forKey: .sessionToken)
            try c.encodeIfPresent(name, forKey: .name)
            try c.encodeIfPresent(avatar, forKey: .avatar)
            try c.encodeIfPresent(pin, forKey: .gmPin)
            try c.encodeIfPresent(profileId, forKey: .profileId)
            try c.encodeIfPresent(profilePin, forKey: .profilePin)
            try c.encodeIfPresent(deviceToken, forKey: .deviceToken)
        case .action(let a, let idem): try c.encode("action", forKey: .t); try c.encode(a, forKey: .action); try c.encodeIfPresent(idem, forKey: .idem)
        case .gm(let cmd): try c.encode("gm", forKey: .t); try c.encode(cmd, forKey: .cmd)
        case .ping(let t0): try c.encode("ping", forKey: .t); try c.encode(t0, forKey: .t0)
        case .sync: try c.encode("sync", forKey: .t)
        case .leave: try c.encode("leave", forKey: .t)
        }
    }
}

/// Server → client.
public enum ServerMessage: Codable, Equatable, Sendable {
    case welcome(playerId: String?, sessionToken: String, role: Role, serverTime: Millis)
    case player(PlayerView)
    case stage(StageView)
    case gm(GmView)
    case pong(t0: Millis, serverTime: Millis)
    case error(code: String, message: String)
    case closed(reason: String)
    case profileEvent(ProfileEvent)

    enum Keys: String, CodingKey { case t, playerId, sessionToken, role, serverTime, view, t0, code, message, reason, event }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        switch try c.decode(String.self, forKey: .t) {
        case "welcome": self = .welcome(playerId: try c.decodeIfPresent(String.self, forKey: .playerId), sessionToken: try c.decode(String.self, forKey: .sessionToken), role: try c.decode(Role.self, forKey: .role), serverTime: try c.decode(Millis.self, forKey: .serverTime))
        case "player": self = .player(try c.decode(PlayerView.self, forKey: .view))
        case "stage": self = .stage(try c.decode(StageView.self, forKey: .view))
        case "gm": self = .gm(try c.decode(GmView.self, forKey: .view))
        case "pong": self = .pong(t0: try c.decode(Millis.self, forKey: .t0), serverTime: try c.decode(Millis.self, forKey: .serverTime))
        case "error": self = .error(code: try c.decode(String.self, forKey: .code), message: try c.decode(String.self, forKey: .message))
        case "closed": self = .closed(reason: try c.decode(String.self, forKey: .reason))
        case "profileEvent": self = .profileEvent(try c.decode(ProfileEvent.self, forKey: .event))
        case let other: throw DecodingError.dataCorruptedError(forKey: .t, in: c, debugDescription: "unknown message \(other)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .welcome(let pid, let token, let role, let st):
            try c.encode("welcome", forKey: .t); try c.encodeIfPresent(pid, forKey: .playerId); try c.encode(token, forKey: .sessionToken); try c.encode(role, forKey: .role); try c.encode(st, forKey: .serverTime)
        case .player(let v): try c.encode("player", forKey: .t); try c.encode(v, forKey: .view)
        case .stage(let v): try c.encode("stage", forKey: .t); try c.encode(v, forKey: .view)
        case .gm(let v): try c.encode("gm", forKey: .t); try c.encode(v, forKey: .view)
        case .pong(let t0, let st): try c.encode("pong", forKey: .t); try c.encode(t0, forKey: .t0); try c.encode(st, forKey: .serverTime)
        case .error(let code, let msg): try c.encode("error", forKey: .t); try c.encode(code, forKey: .code); try c.encode(msg, forKey: .message)
        case .closed(let r): try c.encode("closed", forKey: .t); try c.encode(r, forKey: .reason)
        case .profileEvent(let e): try c.encode("profileEvent", forKey: .t); try c.encode(e, forKey: .event)
        }
    }
}

/// Match-end meta result pushed to a phone (AT, level-up, quests).
public struct ProfileEvent: Codable, Equatable, Sendable {
    public var profileId: String
    public var atDelta: Int
    public var atGesamt: Int
    public var level: Int
    public var levelUp: Bool
    public var quests: [String]
    public var passXp: Int
}

public enum Wire {
    public static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return e
    }()
    public static let decoder = JSONDecoder()

    public static func encode<T: Encodable>(_ v: T) -> Data { (try? encoder.encode(v)) ?? Data() }
    public static func decode<T: Decodable>(_ t: T.Type, _ d: Data) -> T? { try? decoder.decode(t, from: d) }
}
