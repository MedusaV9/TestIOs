import Foundation
import UIKit

enum APIError: LocalizedError {
    case invalidURL
    case http(status: Int, code: String?, message: String?)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return L10n.t("error.invalidURL")
        case .http(let status, let code, let message):
            return message ?? code ?? "HTTP \(status)"
        case .decoding:
            return L10n.t("error.decoding")
        case .transport(let err):
            return err.localizedDescription
        }
    }

    var isUnauthorized: Bool {
        if case .http(let status, _, _) = self { return status == 401 }
        return false
    }
}

/// Stateless HTTP client for one server + token pair.
struct API {
    let baseURL: URL
    let token: String?

    private struct PushMutationResponse: Decodable {
        let deliveryAvailable: Bool?
        let ok: Bool?
    }

    // ISO8601DateFormatter is documented thread-safe; the unsafe marker only
    // silences the Swift 6 Sendable-capture warning.
    nonisolated(unsafe) private static let isoFracFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            if let date = API.isoFracFormatter.date(from: s) ?? API.isoFormatter.date(from: s) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Bad date: \(s)")
        }
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 120
        cfg.waitsForConnectivity = false
        return URLSession(configuration: cfg)
    }()

    /// Separate session for big media uploads (videos) — same connection
    /// behaviour but a much longer resource timeout so a 50 MB clip on a
    /// slow uplink doesn't get cut off mid-transfer.
    private static let uploadSession: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 60
        cfg.timeoutIntervalForResource = 900
        cfg.waitsForConnectivity = false
        return URLSession(configuration: cfg)
    }()

    private struct ErrorBody: Decodable { let error: String?; let message: String? }
    private struct Empty: Decodable {}

    /// ISO8601 string (with fractional seconds) for dates in JSON bodies —
    /// matches the wire format the server emits and `decoder` parses.
    static func isoString(_ date: Date) -> String {
        isoFracFormatter.string(from: date)
    }

    /// Folds a double-optional PATCH parameter into a JSON body so endpoints
    /// that support clearing can distinguish the three cases:
    /// `.none` = omit (keep server value), `.some(nil)` = explicit JSON null
    /// (clear the field), `.some(value)` = set the new value.
    static func encodeNulls(_ body: inout [String: Any?], _ key: String, _ value: String??) {
        if case .some(let inner) = value { body[key] = inner ?? NSNull() }
    }

    // MARK: Request core

    /// Internal (not private) so feature-area extensions in separate files
    /// (e.g. RitualsAPI.swift) can add endpoints without touching this file.
    func request<T: Decodable>(_ method: String, _ path: String,
                                       query: [String: String] = [:],
                                       jsonBody: [String: Any?]? = nil,
                                       rawBody: Data? = nil,
                                       contentType: String? = nil,
                                       headers: [String: String] = [:],
                                       longUpload: Bool = false,
                                       as type: T.Type) async throws -> T {
        guard var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        comps.path = (comps.path.hasSuffix("/") ? String(comps.path.dropLast()) : comps.path) + path
        if !query.isEmpty {
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = comps.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        if let jsonBody {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let clean = jsonBody.compactMapValues { $0 }
            req.httpBody = try JSONSerialization.data(withJSONObject: clean)
        } else if let rawBody {
            req.setValue(contentType ?? "application/octet-stream", forHTTPHeaderField: "Content-Type")
            req.httpBody = rawBody
        }

        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await (longUpload ? API.uploadSession : API.session).data(for: req)
        } catch {
            throw APIError.transport(error)
        }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let body = try? API.decoder.decode(ErrorBody.self, from: data)
            throw APIError.http(status: status, code: body?.error, message: body?.message)
        }
        if T.self == Data.self, let data = data as? T { return data }
        do {
            return try API.decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    // MARK: Health & pairing (no token needed)

    func health() async throws -> HealthResponse {
        try await request("GET", "/api/health", as: HealthResponse.self)
    }

    func createCouple(name: String, avatar: String, color: String) async throws -> AuthResponse {
        try await request("POST", "/api/couples",
                          jsonBody: ["name": name, "avatar": avatar, "color": color,
                                     "deviceId": SharedKeychain.deviceID(),
                                     "deviceName": UIDevice.current.name],
                          as: AuthResponse.self)
    }

    func joinCouple(code: String, name: String, avatar: String, color: String) async throws -> AuthResponse {
        try await request("POST", "/api/couples/join",
                          jsonBody: ["code": code, "name": name, "avatar": avatar, "color": color,
                                     "deviceId": SharedKeychain.deviceID(),
                                     "deviceName": UIDevice.current.name],
                          as: AuthResponse.self)
    }

    /// Registers the APNs token against the authenticated session's device id.
    /// The server never accepts a client-supplied device id for this operation.
    func registerPushDevice(apnsToken: String, environment: String,
                            bundleId: String, language: String) async throws -> Bool {
        let response = try await request(
            "POST", "/api/push-devices/current",
            jsonBody: [
                "apnsToken": apnsToken,
                "environment": environment,
                "bundleId": bundleId,
                "language": language,
            ],
            as: PushMutationResponse.self
        )
        return response.deliveryAvailable ?? false
    }

    func unregisterPushDevice() async throws {
        _ = try await request("DELETE", "/api/push-devices/current",
                              as: PushMutationResponse.self)
    }

    // MARK: Couple & profile

    func getCouple() async throws -> CoupleResponse {
        try await request("GET", "/api/couple", as: CoupleResponse.self)
    }

    func updateMe(name: String? = nil, avatar: String? = nil, color: String? = nil,
                  mood: String?? = nil, moodNote: String?? = nil) async throws -> Member {
        var body: [String: Any?] = [:]
        if let name { body["name"] = name }
        if let avatar { body["avatar"] = avatar }
        if let color { body["color"] = color }
        if case .some(let m) = mood { body["mood"] = m ?? NSNull() }
        if case .some(let n) = moodNote { body["moodNote"] = n ?? NSNull() }
        return try await request("PATCH", "/api/me", jsonBody: body, as: MemberResponse.self).member
    }

    func updateCouple(name: String? = nil, anniversary: String? = nil) async throws -> Couple {
        var body: [String: Any?] = [:]
        if let name { body["name"] = name }
        if let anniversary { body["anniversary"] = anniversary }
        return try await request("PATCH", "/api/couple", jsonBody: body, as: CoupleOnlyResponse.self).couple
    }

    func dissolveCouple() async throws {
        struct OK: Decodable { let ok: Bool }
        _ = try await request("DELETE", "/api/couple", as: OK.self)
    }

    // MARK: Touches

    @discardableResult
    func sendTouch(_ kind: TouchKind) async throws -> Touch {
        try await request("POST", "/api/touches", jsonBody: ["type": kind.rawValue], as: TouchResponse.self).touch
    }

    func recentTouches(limit: Int = 30) async throws -> [Touch] {
        try await request("GET", "/api/touches/recent", query: ["limit": String(limit)], as: TouchesResponse.self).touches
    }

    // MARK: Haptic patterns (v2.0)

    private static func hapticEventsJSON(_ events: [HapticEventSpec]) -> [[String: Double]] {
        events.map { ["t": $0.t, "i": $0.i, "s": $0.s, "d": $0.d] }
    }

    func hapticPatterns() async throws -> [HapticPatternModel] {
        try await request("GET", "/api/haptics", as: HapticPatternsResponse.self).patterns
    }

    @discardableResult
    func saveHapticPattern(name: String, emoji: String?, events: [HapticEventSpec]) async throws -> HapticPatternModel {
        try await request("POST", "/api/haptics",
                          jsonBody: ["name": name, "emoji": emoji,
                                     "events": Self.hapticEventsJSON(events)],
                          as: HapticPatternResponse.self).pattern
    }

    @discardableResult
    func renameHapticPattern(id: String, name: String, emoji: String?) async throws -> HapticPatternModel {
        try await request("PATCH", "/api/haptics/\(id)",
                          jsonBody: ["name": name, "emoji": emoji ?? NSNull()],
                          as: HapticPatternResponse.self).pattern
    }

    func deleteHapticPattern(id: String) async throws {
        struct OK: Decodable { let ok: Bool }
        _ = try await request("DELETE", "/api/haptics/\(id)", as: OK.self)
    }

    /// Relays a saved library pattern to the partner.
    @discardableResult
    func sendHapticPattern(id: String) async throws -> HapticSend {
        try await request("POST", "/api/haptics/\(id)/send", as: HapticSendResponse.self).haptic
    }

    /// Relays an ad-hoc recording without saving it first.
    @discardableResult
    func sendHaptic(name: String? = nil, emoji: String? = nil, events: [HapticEventSpec]) async throws -> HapticSend {
        try await request("POST", "/api/haptics/send",
                          jsonBody: ["name": name, "emoji": emoji,
                                     "events": Self.hapticEventsJSON(events)],
                          as: HapticSendResponse.self).haptic
    }

    /// Relay history (both directions) — lets you replay missed vibes.
    func recentHaptics(limit: Int = 30) async throws -> [HapticSend] {
        try await request("GET", "/api/haptics/recent", query: ["limit": String(limit)],
                          as: HapticsRecentResponse.self).haptics
    }

    // MARK: Check-ins (v2.0)

    func checkins(limit: Int = 30) async throws -> CheckinsResponse {
        try await request("GET", "/api/checkins", query: ["limit": String(limit)],
                          as: CheckinsResponse.self)
    }

    @discardableResult
    func checkin(kind: String) async throws -> CheckinDayResponse {
        try await request("POST", "/api/checkins", jsonBody: ["kind": kind],
                          as: CheckinDayResponse.self)
    }

    // MARK: Shared lists (v2.0)

    func sharedLists() async throws -> [SharedList] {
        try await request("GET", "/api/lists", as: SharedListsResponse.self).lists
    }

    @discardableResult
    func addSharedList(name: String, emoji: String?) async throws -> SharedList {
        try await request("POST", "/api/lists",
                          jsonBody: ["name": name, "emoji": emoji],
                          as: SharedListResponse.self).list
    }

    @discardableResult
    func renameSharedList(id: String, name: String, emoji: String?) async throws -> SharedList {
        try await request("PATCH", "/api/lists/\(id)",
                          jsonBody: ["name": name, "emoji": emoji],
                          as: SharedListResponse.self).list
    }

    func deleteSharedList(id: String) async throws {
        struct OK: Decodable { let ok: Bool }
        _ = try await request("DELETE", "/api/lists/\(id)", as: OK.self)
    }

    @discardableResult
    func addListItem(listId: String, text: String) async throws -> SharedList {
        try await request("POST", "/api/lists/\(listId)/items", jsonBody: ["text": text],
                          as: SharedListResponse.self).list
    }

    @discardableResult
    func setListItemDone(listId: String, itemId: String, done: Bool) async throws -> SharedList {
        try await request("PATCH", "/api/lists/\(listId)/items/\(itemId)", jsonBody: ["done": done],
                          as: SharedListResponse.self).list
    }

    func deleteListItem(listId: String, itemId: String) async throws {
        struct OK: Decodable { let ok: Bool }
        _ = try await request("DELETE", "/api/lists/\(listId)/items/\(itemId)", as: OK.self)
    }

    // MARK: Hug queue (v2.0)

    func hugs() async throws -> [Hug] {
        try await request("GET", "/api/hugs", as: HugsResponse.self).hugs
    }

    @discardableResult
    func queueHug(note: String?, emoji: String?) async throws -> Hug {
        var body: [String: Any?] = [:]
        if let note, !note.isEmpty { body["note"] = note }
        if let emoji { body["emoji"] = emoji }
        return try await request("POST", "/api/hugs", jsonBody: body,
                                 as: HugResponse.self).hug
    }

    @discardableResult
    func openHug(id: String) async throws -> Hug {
        try await request("POST", "/api/hugs/\(id)/open", jsonBody: [:],
                          as: HugResponse.self).hug
    }

    // MARK: Photo of the day (v2.0)

    func potdDays(limit: Int = 30) async throws -> [PotdDay] {
        try await request("GET", "/api/potd", query: ["limit": String(limit)],
                          as: PotdDaysResponse.self).days
    }

    @discardableResult
    func submitPotd(dateKey: String, photoId: String) async throws -> PotdDay {
        try await request("POST", "/api/potd/\(dateKey)", jsonBody: ["photoId": photoId],
                          as: PotdDayResponse.self).day
    }

    // MARK: Now playing (v2.0)

    @discardableResult
    func setNowPlaying(title: String, artist: String?) async throws -> NowPlaying {
        try await request("PUT", "/api/nowplaying",
                          jsonBody: ["title": title, "artist": artist],
                          as: NowPlayingResponse.self).nowPlaying
    }

    func clearNowPlaying() async throws {
        struct OK: Decodable { let ok: Bool }
        _ = try await request("DELETE", "/api/nowplaying", as: OK.self)
    }

    // MARK: Year review (v2.0)

    func yearReview(year: Int? = nil) async throws -> YearReview {
        var query: [String: String] = [:]
        if let year { query["year"] = String(year) }
        return try await request("GET", "/api/yearreview", query: query, as: YearReview.self)
    }

    // MARK: Messages & voice

    func messages(limit: Int = 50, before: String? = nil) async throws -> [Message] {
        var q = ["limit": String(limit)]
        if let before { q["before"] = before }
        return try await request("GET", "/api/messages", query: q, as: MessagesResponse.self).messages
    }

    @discardableResult
    func sendMessage(type: MessageKind, text: String, title: String? = nil,
                     openWhen: String? = nil, clientMessageId: String? = nil) async throws -> Message {
        try await request("POST", "/api/messages",
                          jsonBody: ["type": type.rawValue, "text": text, "title": title,
                                     "openWhen": openWhen, "clientMessageId": clientMessageId],
                          as: MessageResponse.self).message
    }

    /// v1.7: send a photo message referencing an existing gallery photo
    /// (either member's). `text` is an optional caption.
    @discardableResult
    func sendPhotoMessage(photoId: String, text: String? = nil) async throws -> Message {
        try await request("POST", "/api/messages",
                          jsonBody: ["type": MessageKind.photo.rawValue, "photoId": photoId,
                                     "text": text],
                          as: MessageResponse.self).message
    }

    @discardableResult
    func sendVoice(data: Data, durationSec: Double) async throws -> Message {
        try await request("POST", "/api/voice", rawBody: data, contentType: "audio/mp4",
                          headers: ["X-Duration-Sec": String(format: "%.2f", durationSec)],
                          as: MessageResponse.self).message
    }

    /// Toggle my emoji reaction on a message.
    @discardableResult
    func toggleReaction(messageId: String, emoji: String) async throws -> Message {
        try await request("POST", "/api/messages/\(messageId)/reactions",
                          jsonBody: ["emoji": emoji], as: MessageResponse.self).message
    }

    /// v1.8: rewrite the text of one of MY text/letter messages — the server
    /// sets `editedAt` and broadcasts `message_updated {message}`.
    @discardableResult
    func editMessage(id: String, text: String) async throws -> Message {
        try await request("PATCH", "/api/messages/\(id)",
                          jsonBody: ["text": text], as: MessageResponse.self).message
    }

    /// v1.6: delete one of MY messages (server broadcasts `message_deleted {id}`).
    func deleteMessage(id: String) async throws {
        struct OK: Decodable { let ok: Bool }
        _ = try await request("DELETE", "/api/messages/\(id)", as: OK.self)
    }

    /// v1.6: mark the whole chat as read for me — returns the server-side
    /// read timestamp and broadcasts `message_read {memberId, at}`.
    @discardableResult
    func markMessagesRead() async throws -> Date {
        try await request("POST", "/api/messages/read", jsonBody: [:],
                          as: MessagesReadResponse.self).at
    }

    // MARK: Inbox (v1.6)

    /// Aggregated activity the caller missed since `since` (missed-inbox card).
    func inbox(since: Date) async throws -> InboxResponse {
        try await request("GET", "/api/inbox", query: ["since": API.isoString(since)],
                          as: InboxResponse.self)
    }

    // MARK: Wordle duel

    @discardableResult
    func submitWordle(dateKey: String, rows: Int, win: Bool, grid: String, lang: String) async throws -> WordleDayResponse {
        try await request("POST", "/api/wordle/\(dateKey)",
                          jsonBody: ["rows": rows, "win": win, "grid": grid, "lang": lang],
                          as: WordleDayResponse.self)
    }

    func wordleDay(dateKey: String, lang: String) async throws -> WordleDayResponse {
        try await request("GET", "/api/wordle/\(dateKey)", query: ["lang": lang],
                          as: WordleDayResponse.self)
    }

    /// Past duel days (per-member views, newest first, anti-spoiler applied per day).
    func wordleHistory(limit: Int = 30, lang: String) async throws -> [WordleDayResponse] {
        try await request("GET", "/api/wordle", query: ["limit": String(limit), "lang": lang],
                          as: WordleHistoryResponse.self).days
    }

    // MARK: Photos

    func photos() async throws -> [Photo] {
        try await request("GET", "/api/photos", as: PhotosResponse.self).photos
    }

    @discardableResult
    func uploadPhoto(jpeg: Data, caption: String?, width: Int?, height: Int?) async throws -> Photo {
        var headers: [String: String] = [:]
        if let caption, !caption.isEmpty {
            headers["X-Caption"] = caption.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        }
        if let width { headers["X-Width"] = String(width) }
        if let height { headers["X-Height"] = String(height) }
        return try await request("POST", "/api/photos", rawBody: jpeg, contentType: "image/jpeg",
                                 headers: headers, as: PhotoResponse.self).photo
    }

    func deletePhoto(id: String) async throws {
        struct OK: Decodable { let ok: Bool }
        _ = try await request("DELETE", "/api/photos/\(id)", as: OK.self)
    }

    /// Attach a small grid thumbnail to an uploaded photo (uploader only).
    @discardableResult
    func uploadPhotoThumb(photoId: String, jpeg: Data) async throws -> Photo {
        try await request("POST", "/api/photos/\(photoId)/thumb", rawBody: jpeg,
                          contentType: "image/jpeg", as: PhotoResponse.self).photo
    }

    /// Toggle whether the photo is one of MY favorites.
    @discardableResult
    func togglePhotoFavorite(id: String) async throws -> Photo {
        try await request("POST", "/api/photos/\(id)/favorite", jsonBody: [:],
                          as: PhotoResponse.self).photo
    }

    /// PATCH caption and/or album. Double optionals distinguish "leave as-is"
    /// (`.none`) from "clear" (`.some(nil)` → explicit JSON null).
    @discardableResult
    func patchPhoto(id: String, caption: String?? = nil, album: String?? = nil) async throws -> Photo {
        var body: [String: Any?] = [:]
        API.encodeNulls(&body, "caption", caption)
        API.encodeNulls(&body, "album", album)
        return try await request("PATCH", "/api/photos/\(id)", jsonBody: body,
                                 as: PhotoResponse.self).photo
    }

    // MARK: Videos (v2.0)

    func videos() async throws -> [Video] {
        try await request("GET", "/api/videos", as: VideosResponse.self).videos
    }

    /// Upload a (client-side compressed) MP4. Metadata travels in headers
    /// because the body is the raw video bytes.
    @discardableResult
    func uploadVideo(mp4: Data, caption: String?, width: Int?, height: Int?,
                     duration: Double?) async throws -> Video {
        var headers: [String: String] = [:]
        if let caption, !caption.isEmpty {
            headers["X-Caption"] = caption.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        }
        if let width { headers["X-Width"] = String(width) }
        if let height { headers["X-Height"] = String(height) }
        if let duration { headers["X-Duration"] = String(format: "%.2f", duration) }
        return try await request("POST", "/api/videos", rawBody: mp4, contentType: "video/mp4",
                                 headers: headers, longUpload: true, as: VideoResponse.self).video
    }

    /// Attach a poster/grid thumbnail to an uploaded video (uploader only).
    @discardableResult
    func uploadVideoThumb(videoId: String, jpeg: Data) async throws -> Video {
        try await request("POST", "/api/videos/\(videoId)/thumb", rawBody: jpeg,
                          contentType: "image/jpeg", as: VideoResponse.self).video
    }

    /// Toggle whether the video is one of MY favorites.
    @discardableResult
    func toggleVideoFavorite(id: String) async throws -> Video {
        try await request("POST", "/api/videos/\(id)/favorite", jsonBody: [:],
                          as: VideoResponse.self).video
    }

    /// PATCH the caption (`.some(nil)` clears it via explicit JSON null).
    @discardableResult
    func patchVideo(id: String, caption: String?? = nil) async throws -> Video {
        var body: [String: Any?] = [:]
        API.encodeNulls(&body, "caption", caption)
        return try await request("PATCH", "/api/videos/\(id)", jsonBody: body,
                                 as: VideoResponse.self).video
    }

    func deleteVideo(id: String) async throws {
        struct OK: Decodable { let ok: Bool }
        _ = try await request("DELETE", "/api/videos/\(id)", as: OK.self)
    }

    // MARK: Spicy Vault (v2.0) — server only ever sees encrypted blobs

    func vaultConfig() async throws -> VaultConfig? {
        try await request("GET", "/api/vault/config", as: VaultConfigResponse.self).config
    }

    @discardableResult
    func setVaultConfig(kdf: String, iterations: Int, salt: String,
                        verifier: String) async throws -> VaultConfig {
        struct Wrapped: Decodable { let config: VaultConfig }
        return try await request("PUT", "/api/vault/config",
                                 jsonBody: ["kdf": kdf, "iterations": iterations,
                                            "salt": salt, "verifier": verifier],
                                 as: Wrapped.self).config
    }

    func vaultItems() async throws -> [VaultItem] {
        try await request("GET", "/api/vault", as: VaultItemsResponse.self).items
    }

    @discardableResult
    func uploadVaultItem(blob: Data, kind: String) async throws -> VaultItem {
        try await request("POST", "/api/vault/items", rawBody: blob,
                          contentType: "application/octet-stream",
                          headers: ["X-Vault-Kind": kind],
                          longUpload: true, as: VaultItemResponse.self).item
    }

    /// Downloads the full encrypted blob (decryption happens on-device).
    func vaultItemData(id: String) async throws -> Data {
        try await request("GET", "/api/vault/\(id)/raw", longUpload: true, as: Data.self)
    }

    func deleteVaultItem(id: String) async throws {
        struct OK: Decodable { let ok: Bool }
        _ = try await request("DELETE", "/api/vault/\(id)", as: OK.self)
    }

    /// Wipes config + all items (forgotten-PIN escape hatch).
    func resetVault() async throws {
        struct OK: Decodable { let ok: Bool }
        _ = try await request("DELETE", "/api/vault", as: OK.self)
    }

    // MARK: Love coupons

    func coupons() async throws -> [Coupon] {
        try await request("GET", "/api/coupons", as: CouponsResponse.self).coupons
    }

    /// Creates a coupon FOR the partner (server resolves the receiver).
    /// `expiresAt` is optional — past it the coupon can no longer be redeemed.
    @discardableResult
    func createCoupon(title: String, emoji: String, note: String?,
                      expiresAt: Date? = nil) async throws -> Coupon {
        var body: [String: Any?] = ["title": title, "emoji": emoji, "note": note]
        if let expiresAt { body["expiresAt"] = API.isoString(expiresAt) }
        return try await request("POST", "/api/coupons", jsonBody: body,
                                 as: CouponResponse.self).coupon
    }

    /// Redeem a coupon that was made for me.
    @discardableResult
    func redeemCoupon(id: String) async throws -> Coupon {
        try await request("POST", "/api/coupons/\(id)/redeem", jsonBody: [:],
                          as: CouponResponse.self).coupon
    }

    /// Delete an unredeemed coupon I created.
    func deleteCoupon(id: String) async throws {
        struct OK: Decodable { let ok: Bool }
        _ = try await request("DELETE", "/api/coupons/\(id)", as: OK.self)
    }

    // MARK: Shared soundtrack

    func songs() async throws -> [Song] {
        try await request("GET", "/api/songs", as: SongsResponse.self).songs
    }

    @discardableResult
    func addSong(title: String, artist: String?, note: String?, link: String?) async throws -> Song {
        try await request("POST", "/api/songs",
                          jsonBody: ["title": title, "artist": artist, "note": note, "link": link],
                          as: SongResponse.self).song
    }

    /// PATCH a song. `title` can only be replaced; artist/note/link are
    /// double optionals so callers can CLEAR them with an explicit JSON null
    /// (`.some(nil)`) or leave them untouched (`.none`) — see `encodeNulls`.
    @discardableResult
    func updateSong(id: String, title: String? = nil, artist: String?? = nil,
                    note: String?? = nil, link: String?? = nil) async throws -> Song {
        var body: [String: Any?] = [:]
        if let title { body["title"] = title }
        API.encodeNulls(&body, "artist", artist)
        API.encodeNulls(&body, "note", note)
        API.encodeNulls(&body, "link", link)
        return try await request("PATCH", "/api/songs/\(id)", jsonBody: body,
                                 as: SongResponse.self).song
    }

    /// Toggle my heart on a song.
    @discardableResult
    func toggleSongHeart(id: String) async throws -> Song {
        try await request("POST", "/api/songs/\(id)/heart", jsonBody: [:],
                          as: SongResponse.self).song
    }

    func deleteSong(id: String) async throws {
        struct OK: Decodable { let ok: Bool }
        _ = try await request("DELETE", "/api/songs/\(id)", as: OK.self)
    }

    /// Absolute media URL without credentials. Callers that fetch it must use
    /// `mediaRequest`/`mediaData` so bearer secrets stay in headers.
    func mediaURL(_ path: String) -> URL? {
        guard var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }
        comps.path = path
        return comps.url
    }

    func mediaRequest(_ path: String) -> URLRequest? {
        guard let url = mediaURL(path) else { return nil }
        var request = URLRequest(url: url)
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return request
    }

    func mediaData(_ path: String) async throws -> Data {
        try await request("GET", path, as: Data.self)
    }

    // MARK: Events

    func events() async throws -> [EventItem] {
        try await request("GET", "/api/events", as: EventsResponse.self).events
    }

    @discardableResult
    func addEvent(title: String, emoji: String, date: String, repeatsYearly: Bool) async throws -> EventItem {
        try await request("POST", "/api/events",
                          jsonBody: ["title": title, "emoji": emoji, "date": date, "repeatsYearly": repeatsYearly],
                          as: EventResponse.self).event
    }

    @discardableResult
    func updateEvent(id: String, title: String? = nil, emoji: String? = nil,
                     date: String? = nil, repeatsYearly: Bool? = nil) async throws -> EventItem {
        var body: [String: Any?] = [:]
        if let title { body["title"] = title }
        if let emoji { body["emoji"] = emoji }
        if let date { body["date"] = date }
        if let repeatsYearly { body["repeatsYearly"] = repeatsYearly }
        return try await request("PATCH", "/api/events/\(id)", jsonBody: body, as: EventResponse.self).event
    }

    func deleteEvent(id: String) async throws {
        struct OK: Decodable { let ok: Bool }
        _ = try await request("DELETE", "/api/events/\(id)", as: OK.self)
    }

    // MARK: Bucket list

    func bucket() async throws -> [BucketItem] {
        try await request("GET", "/api/bucket", as: BucketResponse.self).items
    }

    @discardableResult
    func addBucketItem(text: String, emoji: String?) async throws -> BucketItem {
        try await request("POST", "/api/bucket", jsonBody: ["text": text, "emoji": emoji],
                          as: BucketItemResponse.self).item
    }

    @discardableResult
    func updateBucketItem(id: String, text: String? = nil, emoji: String? = nil, done: Bool? = nil) async throws -> BucketItem {
        var body: [String: Any?] = [:]
        if let text { body["text"] = text }
        if let emoji { body["emoji"] = emoji }
        if let done { body["done"] = done }
        return try await request("PATCH", "/api/bucket/\(id)", jsonBody: body, as: BucketItemResponse.self).item
    }

    func deleteBucketItem(id: String) async throws {
        struct OK: Decodable { let ok: Bool }
        _ = try await request("DELETE", "/api/bucket/\(id)", as: OK.self)
    }

    // MARK: Daily question

    func daily(dateKey: String) async throws -> DailyEntry {
        try await request("GET", "/api/daily/\(dateKey)", as: DailyEntry.self)
    }

    @discardableResult
    func answerDaily(dateKey: String, questionId: Int, text: String) async throws -> DailyEntry {
        try await request("POST", "/api/daily/\(dateKey)",
                          jsonBody: ["questionId": questionId, "text": text], as: DailyEntry.self)
    }

    // MARK: Canvas

    func canvasStrokes() async throws -> [CanvasStroke] {
        try await request("GET", "/api/canvas", as: StrokesResponse.self).strokes
    }

    @discardableResult
    func addStroke(color: String, width: Double, tool: String, points: [[Double]]) async throws -> CanvasStroke {
        try await request("POST", "/api/canvas/strokes",
                          jsonBody: ["color": color, "width": width, "tool": tool, "points": points],
                          as: StrokeResponse.self).stroke
    }

    func clearCanvas() async throws {
        struct OK: Decodable { let ok: Bool }
        _ = try await request("DELETE", "/api/canvas", as: OK.self)
    }

    /// Remove one of MY strokes (undo). 403 for the partner's strokes.
    func deleteStroke(id: String) async throws {
        struct OK: Decodable { let ok: Bool }
        _ = try await request("DELETE", "/api/canvas/strokes/\(id)", as: OK.self)
    }

    // MARK: Mood history & daily journal

    func moods(limit: Int = 80) async throws -> [MoodEntry] {
        try await request("GET", "/api/moods", query: ["limit": String(limit)],
                          as: MoodsResponse.self).moods
    }

    /// Past daily-question entries (my view), newest dateKey first.
    func dailyHistory(limit: Int = 60) async throws -> [DailyEntry] {
        try await request("GET", "/api/daily", query: ["limit": String(limit)],
                          as: DailyListResponse.self).entries
    }

    // MARK: Games

    @discardableResult
    func createGame(type: GameKind, payload: JSONValue? = nil) async throws -> GameSession {
        var body: [String: Any?] = ["type": type.rawValue]
        if let payload {
            let data = try API.encoder.encode(payload)
            body["payload"] = try JSONSerialization.jsonObject(with: data)
        }
        return try await request("POST", "/api/games", jsonBody: body, as: GameOnlyResponse.self).game
    }

    @discardableResult
    func joinGame(id: String) async throws -> GameSession {
        try await request("POST", "/api/games/\(id)/join", jsonBody: [:], as: GameOnlyResponse.self).game
    }

    @discardableResult
    func sendMove(gameId: String, data: JSONValue) async throws -> GameMove {
        let encoded = try API.encoder.encode(data)
        let obj = try JSONSerialization.jsonObject(with: encoded)
        return try await request("POST", "/api/games/\(gameId)/move", jsonBody: ["data": obj],
                                 as: MoveResponse.self).move
    }

    @discardableResult
    func endGame(id: String, result: JSONValue? = nil) async throws -> GameSession {
        var body: [String: Any?] = [:]
        if let result {
            let data = try API.encoder.encode(result)
            body["result"] = try JSONSerialization.jsonObject(with: data)
        }
        return try await request("POST", "/api/games/\(id)/end", jsonBody: body, as: GameOnlyResponse.self).game
    }

    func activeGame() async throws -> GameSession? {
        try await request("GET", "/api/games/active", as: GameResponse.self).game
    }

    /// v3.0: ALL non-ended sessions (lobby/active), newest first — with
    /// parallel sessions per type this replaces the single `/active` fetch.
    func openGames() async throws -> [GameSession] {
        try await request("GET", "/api/games/open", as: GamesListResponse.self).games
    }

    /// v3.0: one session in any state (replay deep-links, spectator refresh).
    func game(id: String) async throws -> GameSession {
        try await request("GET", "/api/games/\(id)", as: GameOnlyResponse.self).game
    }

    /// v1.6: past game sessions (incl. results), newest first.
    func games(limit: Int = 30) async throws -> [GameSession] {
        try await request("GET", "/api/games", query: ["limit": String(limit)],
                          as: GamesListResponse.self).games
    }

    // MARK: Stats

    func stats() async throws -> Stats {
        try await request("GET", "/api/stats", as: Stats.self)
    }

    // MARK: Widget snapshot

    /// Everything a home-screen widget needs in one authenticated call.
    func widgetSnapshot() async throws -> WidgetSnapshotResponse {
        try await request("GET", "/api/widget-snapshot", as: WidgetSnapshotResponse.self)
    }

    // MARK: v3.0 Level, Badges & Quest (Agent C)

    func level() async throws -> LevelState {
        try await request("GET", "/api/level", as: LevelState.self)
    }

    func badges() async throws -> [BadgeState] {
        try await request("GET", "/api/badges", as: BadgesResponse.self).badges
    }

    func quest() async throws -> QuestState {
        try await request("GET", "/api/quest", as: QuestState.self)
    }

    // MARK: v3.0 Platform delights (Agent C)

    /// Gifts an alternate app icon to the partner (unwrap ceremony on their side).
    @discardableResult
    func sendIconGift(icon: String, note: String? = nil) async throws -> IconGift {
        struct Response: Decodable { let gift: IconGift }
        return try await request("POST", "/api/icongift",
                                 jsonBody: ["icon": icon, "note": note],
                                 as: Response.self).gift
    }

    /// My pending (unopened) icon gift — nil when there is none.
    func pendingIconGift() async throws -> IconGift? {
        try await request("GET", "/api/icongift", as: IconGiftResponse.self).gift
    }

    /// Unwraps the pending gift (tells the sender their surprise landed).
    @discardableResult
    func openIconGift() async throws -> IconGift {
        struct Response: Decodable { let gift: IconGift }
        return try await request("POST", "/api/icongift/open", jsonBody: [:], as: Response.self).gift
    }

    /// Starts a synchronized haptic duet — `duet_start` is broadcast to both.
    @discardableResult
    func startDuet(events: [HapticEventSpec], name: String? = nil) async throws -> DuetSession {
        let encoded = try API.encoder.encode(events)
        let list = try JSONSerialization.jsonObject(with: encoded)
        return try await request("POST", "/api/duet",
                                 jsonBody: ["events": list, "name": name],
                                 as: DuetResponse.self).duet
    }

    /// Plans (or replaces) tonight's date night.
    @discardableResult
    func setDateNight(title: String?, emoji: String?, startsAt: Date) async throws -> DateNight {
        struct Response: Decodable { let dateNight: DateNight }
        return try await request("POST", "/api/datenight",
                                 jsonBody: ["title": title, "emoji": emoji,
                                            "startsAt": API.isoFracFormatter.string(from: startsAt)],
                                 as: Response.self).dateNight
    }

    func dateNight() async throws -> DateNight? {
        try await request("GET", "/api/datenight", as: DateNightResponse.self).dateNight
    }

    /// Advances the phase (Vorfreude → Los → Ausklang); either partner may.
    @discardableResult
    func setDateNightPhase(_ phase: DateNightPhase) async throws -> DateNight {
        struct Response: Decodable { let dateNight: DateNight }
        return try await request("POST", "/api/datenight/phase",
                                 jsonBody: ["phase": phase.rawValue],
                                 as: Response.self).dateNight
    }

    func clearDateNight() async throws {
        struct OK: Decodable { let ok: Bool }
        _ = try await request("DELETE", "/api/datenight", as: OK.self)
    }
}
