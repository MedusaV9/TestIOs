import Foundation

// MARK: - Server models (mirror docs/API.md exactly)

struct Member: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var avatar: String
    var color: String
    var mood: String?
    var moodNote: String?
    var moodUpdatedAt: Date?
    var online: Bool?
    var lastSeenAt: Date?
    var lastReadAt: Date?
    /// v2.0: "currently listening to …" — the server nils it after 60 min.
    var nowPlaying: NowPlaying?
    /// v3.0: 🟢🟡🔴 after-work energy light — the server nils it after 12 h.
    var energy: MemberEnergy?
    var joinedAt: Date?
}

/// v2.0: a member's now-playing music status (set manually or from the
/// system player; auto-hidden by the server once older than 60 minutes).
struct NowPlaying: Codable, Hashable {
    let title: String
    let artist: String?
    let setAt: Date
}

struct Couple: Codable, Hashable {
    let id: String
    let code: String
    var name: String?
    var anniversary: String?
    let createdAt: Date
    var members: [Member]
}

struct AuthResponse: Codable {
    let token: String
    let sessionId: String?
    let expiresAt: Date?
    let coupleId: String
    let memberId: String
    let couple: Couple
}

struct CoupleResponse: Codable {
    let couple: Couple
    let me: String
}

enum TouchKind: String, Codable, CaseIterable, Identifiable {
    case heartbeat, kiss, hug, missyou, tickle, thinking
    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .heartbeat: return "💓"
        case .kiss: return "😘"
        case .hug: return "🫂"
        case .missyou: return "🥺"
        case .tickle: return "🪶"
        case .thinking: return "💭"
        }
    }

    var titleKey: String { "touch.\(rawValue)" }
}

struct Touch: Codable, Identifiable, Hashable {
    let id: String
    let type: TouchKind
    let senderId: String
    let createdAt: Date
}

enum MessageKind: String, Codable {
    case text, letter, voice, photo
}

struct Message: Codable, Identifiable, Hashable {
    let id: String
    let senderId: String
    /// Stable client id for durable outbox retries; nil on pre-v4 messages.
    let clientMessageId: String?
    let type: MessageKind
    let text: String?
    let title: String?
    let audioUrl: String?
    let durationSec: Double?
    /// Photo messages only (v1.7): id of the referenced gallery photo.
    /// The photo has its own lifetime — its media may 404 after deletion.
    let photoId: String?
    /// Letters only: seal tag like "sad", "missme", "custom:<text>" —
    /// the recipient opens the letter when the moment fits.
    let openWhen: String?
    /// Emoji reactions: emoji → memberIds who reacted.
    var reactions: [String: [String]]?
    /// v1.8: set when the sender edited the text (text/letter only);
    /// nil = never edited. `createdAt` (and thus ordering) never changes.
    var editedAt: Date?
    let createdAt: Date
}

struct Photo: Codable, Identifiable, Hashable {
    let id: String
    let uploaderId: String
    var caption: String?
    let url: String
    let thumbUrl: String?
    let width: Int?
    let height: Int?
    /// Optional album name (free string) — nil = not filed in any album.
    var album: String?
    /// memberIds who marked this photo as a favorite.
    var favorites: [String]?
    let createdAt: Date

    func isFavorite(of memberId: String?) -> Bool {
        guard let memberId else { return false }
        return favorites?.contains(memberId) ?? false
    }
}

/// v2.0: a shared gallery video (streamed from the server with Range support).
struct Video: Codable, Identifiable, Hashable {
    let id: String
    let uploaderId: String
    var caption: String?
    let url: String
    var thumbUrl: String?
    let width: Int?
    let height: Int?
    /// Playback length in seconds (rounded to 0.1 s by the server).
    let duration: Double?
    /// File size on the server — shown in the player info line.
    let bytes: Int?
    /// memberIds who marked this video as a favorite.
    var favorites: [String]?
    let createdAt: Date

    func isFavorite(of memberId: String?) -> Bool {
        guard let memberId else { return false }
        return favorites?.contains(memberId) ?? false
    }

    /// "1:07" style duration badge for the grid.
    var durationLabel: String? {
        guard let duration, duration > 0 else { return nil }
        let total = Int(duration.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Spicy Vault (v2.0)

/// Public KDF parameters + PIN verifier for the end-to-end encrypted vault.
/// The server stores this openly — it contains no secrets (the verifier can
/// only be opened with the key derived from the couple's vault PIN).
struct VaultConfig: Codable, Hashable {
    let kdf: String
    let iterations: Int
    /// Base64 random per-couple salt.
    let salt: String
    /// Base64 AES-GCM sealed box of a known plaintext — decrypting it
    /// successfully proves the entered PIN is right.
    let verifier: String
    let createdBy: String?
    let createdAt: Date?
}

/// One encrypted vault blob as the server sees it. Everything sensitive
/// (caption, poster, the content itself) lives INSIDE the ciphertext.
struct VaultItem: Codable, Identifiable, Hashable {
    let id: String
    let uploaderId: String
    /// Coarse hint only ("photo" | "video" | "note") so the grid can show
    /// a matching placeholder while locked/undecrypted.
    let kind: String
    let url: String
    let bytes: Int?
    let createdAt: Date
}

struct VaultConfigResponse: Codable { let config: VaultConfig? }
struct VaultItemsResponse: Codable { let items: [VaultItem] }
struct VaultItemResponse: Codable { let item: VaultItem }

// MARK: - Wordle duel

struct WordleResult: Codable, Hashable {
    let memberId: String
    let rows: Int
    let win: Bool
    let grid: String            // emoji grid (🟩🟨⬛ lines)
    let lang: String
    let finishedAt: Date
}

/// Per-member view: partner's result stays hidden until I finished (no spoilers).
/// Results are per language — the duel compares same-language boards.
struct WordleDayResponse: Codable, Hashable {
    let dateKey: String
    let lang: String?
    let mine: WordleResult?
    let partner: WordleResult?
    let partnerFinished: Bool
}

struct WordleHistoryResponse: Codable {
    let days: [WordleDayResponse]
}

// MARK: - Shared soundtrack

struct Song: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var artist: String?
    var note: String?
    var link: String?
    let addedBy: String
    var heartedBy: [String]?
    let createdAt: Date

    func isHearted(by memberId: String?) -> Bool {
        guard let memberId else { return false }
        return heartedBy?.contains(memberId) ?? false
    }
}

// MARK: - Love coupons

struct Coupon: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var emoji: String
    var note: String?
    let createdBy: String
    let forMember: String
    var redeemedAt: Date?
    /// Optional expiry — an unredeemed coupon past this date can no longer
    /// be redeemed (the server answers `409 expired`).
    var expiresAt: Date?
    let createdAt: Date

    /// Expired = past its expiry date and never redeemed.
    func isExpired(at now: Date = Date()) -> Bool {
        guard redeemedAt == nil, let expiresAt else { return false }
        return expiresAt <= now
    }
}

/// One entry of a member's mood history (server keeps the last ~60 per member).
struct MoodEntry: Codable, Identifiable, Hashable {
    let id: String
    let memberId: String
    let mood: String
    let moodNote: String?
    let createdAt: Date
}

struct EventItem: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var emoji: String
    var date: String            // "YYYY-MM-DD"
    var repeatsYearly: Bool
    let createdBy: String
    let createdAt: Date
}

struct BucketItem: Codable, Identifiable, Hashable {
    let id: String
    var text: String
    var emoji: String?
    var done: Bool
    var doneAt: Date?
    let createdBy: String
    let createdAt: Date
}

struct CanvasStroke: Codable, Identifiable, Hashable {
    let id: String
    let memberId: String
    let color: String
    let width: Double
    let tool: String            // "pen" | "marker" | "eraser"
    let points: [[Double]]      // normalized 0..1
    let createdAt: Date
}

enum GameKind: String, Codable, CaseIterable, Identifiable {
    case quiz, thisorthat, wouldyourather, truthordare, questions36, emojiriddle
    // v2.0 realtime games
    case connectfour, photomemory, quizduel
    // v3.0 games & activities
    case battleship, pictionary, kniffel, movieroulette, stadtlandfluss
    case twotruths, dailyquests
    var id: String { rawValue }
}

struct GameMove: Codable, Identifiable, Hashable {
    let id: String
    let memberId: String
    let data: JSONValue
    let createdAt: Date
}

struct GameSession: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    var state: String           // "lobby" | "active" | "ended"
    let createdBy: String
    var payload: JSONValue?
    var result: JSONValue?
    var moves: [GameMove]
    let createdAt: Date

    var kind: GameKind? { GameKind(rawValue: type) }
}

struct DailyEntry: Codable, Hashable {
    let dateKey: String
    let questionId: Int?
    let myAnswer: String?
    let partnerAnswer: String?
    let bothAnswered: Bool
    let streak: Int
}

struct TouchStats: Codable, Hashable {
    let total: Int
    let byType: [String: Int]
}

struct Stats: Codable, Hashable {
    let daysTogether: Int?
    let touchesSent: TouchStats
    let touchesReceived: TouchStats
    let messages: Int
    let photos: Int
    /// v2.0 — optional so the app still decodes pre-2.0 server responses.
    let videos: Int?
    let bucketDone: Int
    let bucketTotal: Int
    let dailyStreak: Int
    let dailyAnswered: Int
    let gamesPlayed: Int
}

struct HealthResponse: Codable {
    let ok: Bool
    let name: String
    let version: String
}

// MARK: - Widget snapshot (thin mirror of GET /api/widget-snapshot)

/// One-call server payload for home-screen widgets. Named `…Response` (with
/// nested parts) because `WidgetSnapshot` is taken by the App Group blob in
/// Shared/SharedBridge.swift, which compiles into the same targets.
struct WidgetSnapshotResponse: Codable, Hashable {
    struct Partner: Codable, Hashable {
        let id: String
        let name: String
        let avatar: String
        let color: String
        let mood: String?
        let moodNote: String?
        let moodUpdatedAt: Date?
        let online: Bool
        let lastSeenAt: Date?
        let energy: MemberEnergy?
    }

    struct Me: Codable, Hashable {
        let id: String
        let name: String
        let avatar: String
        let color: String
    }

    struct CoupleInfo: Codable, Hashable {
        let id: String
        let name: String?
        let anniversary: String?    // "YYYY-MM-DD"
    }

    struct LatestPhoto: Codable, Hashable {
        let id: String
        let url: String
        let thumbUrl: String?
        let caption: String?
        let favorites: [String]
    }

    struct NextEvent: Codable, Hashable {
        let id: String
        let title: String
        let emoji: String?
        let date: String            // resolved next occurrence, "YYYY-MM-DD" (yearly events wrap)
        let repeatsYearly: Bool
    }

    struct GoalSummary: Codable, Hashable {
        let id: String
        let title: String
        let emoji: String?
        let targetValue: Double
        let unit: String?
        let targetDate: String?
        let total: Double
        let percent: Double
    }

    struct LevelSummary: Codable, Hashable {
        let level: Int
        let title: LocalizedText
        let progress: Double
        let xp: Int
    }

    let partner: Partner?           // nil on a single-member couple
    let me: Me
    let couple: CoupleInfo
    let daysTogether: Int
    let streak: Int
    let bothAnsweredToday: Bool
    let dailyAnsweredByMe: Bool
    let latestPhoto: LatestPhoto?   // newest favorited, else newest overall
    let nextEvent: NextEvent?       // soonest upcoming
    let canvasStrokeCount: Int
    let canvasUpdatedAt: Date?
    let goal: GoalSummary?
    let level: LevelSummary?
    let serverTime: Date
}

// MARK: - Inbox (v1.6 — GET /api/inbox?since=ISO)

/// Aggregated "missed while you were away" activity strictly after `since`.
/// Mirrors the server shape: one `{count, last?}` bucket per category — the
/// buckets (and their counts) stay optional so the client tolerates servers
/// that omit categories. Untyped `last` teasers (touch/photo/coupon) are
/// ignored; only the message teaser is consumed for the dashboard card.
struct InboxResponse: Codable, Hashable {
    struct Bucket: Codable, Hashable {
        let count: Int?
    }

    /// Teaser of the newest missed message (`text` truncated server-side).
    struct MessageTeaser: Codable, Hashable {
        let id: String
        let senderId: String?
        let kind: String?
        let text: String?
        let createdAt: Date?
    }

    struct MessagesBucket: Codable, Hashable {
        let count: Int?
        let last: MessageTeaser?
    }

    /// v3.0 "Du bist dran!" digest — open games where I should act.
    struct GamesBucket: Codable, Hashable {
        struct AwaitingGame: Codable, Hashable {
            let gameId: String
            let type: String
        }

        let count: Int?
        let awaitingMe: [AwaitingGame]?
    }

    /// v3.0 need button digest: new signals for me since `since`, plus the
    /// newest still-unacknowledged one so app-open can surface it (no push).
    struct NeedsBucket: Codable, Hashable {
        let count: Int?
        let openNeed: NeedSignal?
    }

    let messages: MessagesBucket?
    let touches: Bucket?
    let photos: Bucket?
    let couponsForMe: Bucket?
    let songs: Bucket?
    let canvasStrokes: Bucket?
    let games: GamesBucket?
    let needsForMe: NeedsBucket?
    let dailyPartnerAnswered: Bool?
    let serverTime: Date?

    var messageCount: Int { messages?.count ?? 0 }
    var touchCount: Int { touches?.count ?? 0 }
    var photoCount: Int { photos?.count ?? 0 }
    var couponCount: Int { couponsForMe?.count ?? 0 }
    var songCount: Int { songs?.count ?? 0 }
    var canvasCount: Int { canvasStrokes?.count ?? 0 }
    var gamesCount: Int { games?.count ?? 0 }
    var needsCount: Int { needsForMe?.count ?? 0 }
    var partnerAnsweredDaily: Bool { dailyPartnerAnswered ?? false }

    var total: Int {
        messageCount + touchCount + photoCount + couponCount + songCount
            + canvasCount + gamesCount + needsCount + (partnerAnsweredDaily ? 1 : 0)
    }
    var isEmpty: Bool { total == 0 }
}

// MARK: - List wrappers

struct MessagesResponse: Codable { let messages: [Message] }
struct PhotosResponse: Codable { let photos: [Photo] }
struct MoodsResponse: Codable { let moods: [MoodEntry] }
struct DailyListResponse: Codable { let entries: [DailyEntry] }
struct CouponsResponse: Codable { let coupons: [Coupon] }
struct CouponResponse: Codable { let coupon: Coupon }
struct SongsResponse: Codable { let songs: [Song] }
struct SongResponse: Codable { let song: Song }
struct EventsResponse: Codable { let events: [EventItem] }
struct BucketResponse: Codable { let items: [BucketItem] }
struct StrokesResponse: Codable { let strokes: [CanvasStroke] }
struct TouchesResponse: Codable { let touches: [Touch] }
struct GameResponse: Codable { let game: GameSession? }
struct MemberResponse: Codable { let member: Member }
struct CoupleOnlyResponse: Codable { let couple: Couple }
struct MessageResponse: Codable { let message: Message }
struct PhotoResponse: Codable { let photo: Photo }
struct VideosResponse: Codable { let videos: [Video] }
struct VideoResponse: Codable { let video: Video }
struct EventResponse: Codable { let event: EventItem }
struct BucketItemResponse: Codable { let item: BucketItem }
struct StrokeResponse: Codable { let stroke: CanvasStroke }
struct TouchResponse: Codable { let touch: Touch }
struct GameOnlyResponse: Codable { let game: GameSession }
struct MoveResponse: Codable { let move: GameMove }
/// v1.6 `GET /api/games?limit=` — past sessions, newest first.
struct GamesListResponse: Codable { let games: [GameSession] }
/// v1.6 `POST /api/messages/read` — server timestamp of the read receipt.
struct MessagesReadResponse: Codable { let at: Date }

// MARK: - WebSocket events

enum ServerEventType: String, Codable {
    case welcome, presence, touch, message
    case memberUpdated = "member_updated"
    case coupleUpdated = "couple_updated"
    case coupleDissolved = "couple_dissolved"
    case partnerJoined = "partner_joined"
    case dailyAnswer = "daily_answer"
    case canvasStroke = "canvas_stroke"
    case canvasClear = "canvas_clear"
    case photoAdded = "photo_added"
    case photoUpdated = "photo_updated"
    case photoDeleted = "photo_deleted"
    case videoAdded = "video_added"
    case videoUpdated = "video_updated"
    case videoDeleted = "video_deleted"
    case vaultConfigSet = "vault_config_set"
    case vaultItemAdded = "vault_item_added"
    case vaultItemDeleted = "vault_item_deleted"
    case vaultReset = "vault_reset"
    case canvasStrokeDeleted = "canvas_stroke_deleted"
    case eventAdded = "event_added"
    case eventUpdated = "event_updated"
    case eventDeleted = "event_deleted"
    case bucketAdded = "bucket_added"
    case bucketUpdated = "bucket_updated"
    case bucketDeleted = "bucket_deleted"
    case gameCreated = "game_created"
    case gameStarted = "game_started"
    case gameMove = "game_move"
    case gameEnded = "game_ended"
    case messageUpdated = "message_updated"
    case wordleResult = "wordle_result"
    case couponAdded = "coupon_added"
    case couponRedeemed = "coupon_redeemed"
    case couponDeleted = "coupon_deleted"
    case songAdded = "song_added"
    case songUpdated = "song_updated"
    case songDeleted = "song_deleted"
    case messageDeleted = "message_deleted"
    case messageRead = "message_read"
    case haptic
    case hapticPatternAdded = "haptic_pattern_added"
    case hapticPatternUpdated = "haptic_pattern_updated"
    case hapticPatternDeleted = "haptic_pattern_deleted"
    // v2.0 couple features
    case checkin
    case listAdded = "list_added"
    case listUpdated = "list_updated"
    case listDeleted = "list_deleted"
    case hugQueued = "hug_queued"
    case hugOpened = "hug_opened"
    case potdSubmitted = "potd_submitted"
    case nowPlayingChanged = "now_playing"
    // v3.0 rituals & relationship (Agent A)
    case daymemo
    case capsuleSealed = "capsule_sealed"
    case capsuleOpened = "capsule_opened"
    case capsuleDeleted = "capsule_deleted"
    case need
    case needAcked = "need_acked"
    case goalAdded = "goal_added"
    case goalUpdated = "goal_updated"
    case goalDeleted = "goal_deleted"
    case weekplanAvailability = "weekplan_availability"
    case weekplanSlotAdded = "weekplan_slot_added"
    case weekplanSlotUpdated = "weekplan_slot_updated"
    case weekplanSlotDeleted = "weekplan_slot_deleted"
    case energy
    case magazineSeen = "magazine_seen"
    // v3.0 level & platform (Agent C)
    case appEvent = "app_event"
    case levelUp = "level_up"
    case badgeUnlocked = "badge_unlocked"
    case questCompleted = "quest_completed"
    case iconGift = "icon_gift"
    case iconGiftOpened = "icon_gift_opened"
    case duetStart = "duet_start"
    case heartbeatTap = "heartbeat_tap"
    case datenightUpdate = "datenight_update"
    case typing, pong
}

/// A raw event received from the server socket. `payload` is re-decoded
/// by interested consumers via `decode(_:)`.
struct ServerEvent {
    let type: ServerEventType
    let rawData: Data

    private struct PayloadBox<T: Decodable>: Decodable { let payload: T }

    func decode<T: Decodable>(_ type: T.Type) -> T? {
        try? API.decoder.decode(PayloadBox<T>.self, from: rawData).payload
    }
}

extension Notification.Name {
    /// Posted on the main queue for every incoming `ServerEvent` (object = ServerEvent).
    static let serverEvent = Notification.Name("sooodreamy.serverEvent")
}

// MARK: - Event payloads

struct PresencePayload: Codable {
    let memberId: String
    let online: Bool
    let lastSeenAt: Date?
}

struct WelcomePayload: Codable {
    let memberId: String
    let coupleId: String
    let partnerOnline: Bool
}

struct TypingPayload: Codable {
    let memberId: String
    let isTyping: Bool
}

struct IdPayload: Codable { let id: String }

struct GameMovePayload: Codable {
    let gameId: String
    let move: GameMove
}

/// v1.6 `message_read` event: a member marked the chat as read at `at`.
struct MessageReadPayload: Codable {
    let memberId: String
    let at: Date
}

// MARK: - v2.0 couple features

/// One check-in day: `memberId → ISO time` per kind. Missing = not yet.
struct CheckinDay: Codable, Hashable, Identifiable {
    let dateKey: String
    let morning: [String: Date]
    let night: [String: Date]

    var id: String { dateKey }

    func checkedIn(_ memberId: String?, kind: String) -> Bool {
        guard let memberId else { return false }
        return (kind == "morning" ? morning : night)[memberId] != nil
    }
}

struct CheckinsResponse: Codable {
    let days: [CheckinDay]
    let streak: Int
}

struct CheckinDayResponse: Codable {
    let day: CheckinDay
    let streak: Int
}

/// v2.0 `checkin` WS event.
struct CheckinEventPayload: Codable {
    let memberId: String
    let kind: String
    let day: CheckinDay
    let streak: Int
}

/// A shared list (shopping, movies, …) with checkable items.
struct SharedList: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var emoji: String?
    let createdBy: String
    let createdAt: Date
    var items: [SharedListItem]

    var openCount: Int { items.filter { !$0.done }.count }
}

struct SharedListItem: Codable, Identifiable, Hashable {
    let id: String
    var text: String
    var done: Bool
    var doneAt: Date?
    let createdBy: String
    let createdAt: Date
}

struct SharedListsResponse: Codable { let lists: [SharedList] }
struct SharedListResponse: Codable { let list: SharedList }

/// A queued hug — sent while the partner sleeps, opened when they wake up.
struct Hug: Codable, Identifiable, Hashable {
    let id: String
    let from: String
    let to: String
    let note: String?
    let emoji: String
    let createdAt: Date
    var openedAt: Date?
}

struct HugsResponse: Codable { let hugs: [Hug] }
struct HugResponse: Codable { let hug: Hug }

/// Photo of the day: per member the submitted gallery photo for a dateKey.
struct PotdEntry: Codable, Hashable {
    let photoId: String
    let submittedAt: Date
}

struct PotdDay: Codable, Identifiable, Hashable {
    let dateKey: String
    let entries: [String: PotdEntry]

    var id: String { dateKey }
}

struct PotdDaysResponse: Codable { let days: [PotdDay] }
struct PotdDayResponse: Codable { let day: PotdDay }

/// v2.0 `potd_submitted` WS event.
struct PotdEventPayload: Codable {
    let dateKey: String
    let memberId: String
    let photoId: String
    let day: PotdDay
}

/// v2.0 `now_playing` WS event (nowPlaying nil = cleared).
struct NowPlayingEventPayload: Codable {
    let memberId: String
    let nowPlaying: NowPlaying?
}

struct NowPlayingResponse: Codable { let nowPlaying: NowPlaying }

/// "Unser Jahr" — everything the server still remembers about one year.
/// Early-year numbers can be lower bounds (capped lists roll off).
struct YearReview: Codable, Hashable {
    let year: Int
    let generatedAt: Date
    let photosAdded: Int
    let videosAdded: Int
    let messagesByMember: [String: Int]
    let touchesByMember: [String: Int]
    let topTouchType: [String: String?]
    let gamesPlayed: Int
    let gameWins: [String: Int]
    let wordleDaysPlayed: Int
    let wordleWins: [String: Int]
    let dailyBothAnswered: Int
    let checkinDaysBoth: Int
    let checkinStreak: Int
    let hugsSent: Int
    let hugsOpened: Int
    let couponsRedeemed: Int
    let songsAdded: Int
    let bucketDone: Int
    let eventsCreated: Int
    let potdDays: Int
}

// MARK: - JSONValue (free-form JSON for game payloads/moves)

enum JSONValue: Codable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else if let o = try? c.decode([String: JSONValue].self) { self = .object(o) }
        else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n): try c.encode(n)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }

    // Convenience accessors
    var stringValue: String? { if case .string(let s) = self { return s }; return nil }
    var numberValue: Double? { if case .number(let n) = self { return n }; return nil }
    var intValue: Int? { numberValue.map { Int($0) } }
    var boolValue: Bool? { if case .bool(let b) = self { return b }; return nil }
    var arrayValue: [JSONValue]? { if case .array(let a) = self { return a }; return nil }
    var objectValue: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }

    subscript(key: String) -> JSONValue? { objectValue?[key] }
}

// MARK: - v3.0 Level, Badges, Quest & Platform (Agent C)

/// Server-delivered DE/EN string pair (level titles etc.).
struct LocalizedText: Codable, Hashable {
    let de: String
    let en: String

    var resolved: String { L10n.isGerman ? de : en }
}

/// `GET /api/level` — the couple's relationship level.
struct LevelState: Codable, Hashable {
    let xp: Int
    let level: Int
    let title: LocalizedText
    /// XP inside the current level / XP the level spans (ring display).
    let levelXp: Int
    let nextLevelXp: Int
    let progress: Double
    let maxTitleLevel: Int
}

/// One badge on the shelf. Secret badges stay disguised until unlocked.
struct BadgeState: Codable, Hashable, Identifiable {
    struct Progress: Codable, Hashable {
        let current: Int
        let target: Int
    }

    let id: String
    let secret: Bool
    let unlocked: Bool
    let unlockedAt: Date?
    let progress: Progress
}

struct BadgesResponse: Codable { let badges: [BadgeState] }

/// Onboarding quest ("first week"): 7 derived steps.
struct QuestStep: Codable, Hashable, Identifiable {
    let id: String
    let done: Bool
}

struct QuestState: Codable, Hashable {
    let steps: [QuestStep]
    let done: Bool
    let completedAt: Date?
    let isNewCouple: Bool
    let bonusXp: Int
}

/// A pending (or just-opened) app-icon gift from the partner.
struct IconGift: Codable, Hashable {
    let id: String
    let icon: String
    let note: String?
    let fromMemberId: String
    let sentAt: Date
    let openedAt: Date?
}

struct IconGiftResponse: Codable { let gift: IconGift? }

/// A synchronized haptic duet: both phones play `events` at server time
/// `startAtMs` (converted to local time via ClockSync).
struct DuetSession: Codable, Hashable {
    let id: String
    let name: String?
    let events: [HapticEventSpec]
    let startedBy: String
    let startAtMs: Double
    let serverNowMs: Double
}

struct DuetResponse: Codable { let duet: DuetSession }

enum DateNightPhase: String, Codable, CaseIterable {
    case anticipation, live, afterglow

    var emoji: String {
        switch self {
        case .anticipation: return "✨"
        case .live: return "💞"
        case .afterglow: return "🌙"
        }
    }

    var next: DateNightPhase? {
        switch self {
        case .anticipation: return .live
        case .live: return .afterglow
        case .afterglow: return nil
        }
    }
}

/// The couple's planned date night (drives the Live Activity on both phones).
struct DateNight: Codable, Hashable {
    let id: String
    let title: String?
    let emoji: String?
    let startsAt: Date
    let phase: DateNightPhase
    let createdBy: String
    let createdAt: Date
    let phaseChangedAt: Date
}

struct DateNightResponse: Codable { let dateNight: DateNight? }

// v3.0 WS payloads (Agent C)

struct LevelUpPayload: Codable, Identifiable {
    let level: Int
    let title: LocalizedText
    let xp: Int

    /// One ceremony per reached level (drives `sheet(item:)`).
    var id: Int { level }
}

struct BadgeUnlockedPayload: Codable { let badge: BadgeState }
struct QuestCompletedPayload: Codable { let quest: QuestState }
struct IconGiftPayload: Codable { let gift: IconGift }
struct DuetStartPayload: Codable { let duet: DuetSession }
struct DateNightUpdatePayload: Codable { let dateNight: DateNight? }

struct HeartbeatTapPayload: Codable {
    let memberId: String
    let intensity: Double
}

/// `pong` payload — `echo` correlates the answer with our ping (ClockSync).
struct PongPayload: Codable { let echo: String? }
