import Foundation

// MARK: - Rituals & relationship models (v3.0 — Agent A)
// Mirrors the server shapes in server/src/rituals.js exactly.

// MARK: Audio check-in "Wie war dein Tag?"

/// One member's recorded memo for a day (server withholds the partner's
/// memo until you recorded your own — anti-spoiler like the daily question).
struct Daymemo: Codable, Hashable {
    let id: String
    /// Server path (`/api/daymemos/:id/raw`) — resolve via `API.mediaURL`.
    let url: String
    let durationSec: Double?
    let recordedAt: Date
}

/// Per-viewer view of one day: `partner` stays nil until I recorded mine.
struct DaymemoDay: Codable, Hashable {
    let dateKey: String
    let mine: Daymemo?
    let partner: Daymemo?
    let partnerRecorded: Bool
    let bothRecorded: Bool
    let streak: Int
}

struct DaymemosResponse: Codable {
    let days: [DaymemoDay]
    let streak: Int
}

// MARK: Time capsules

/// A sealed letter. For the recipient, `text`/`photoId` are nil until the
/// capsule was opened — the SERVER holds the content back, not the client.
struct TimeCapsule: Codable, Identifiable, Hashable {
    let id: String
    let title: String?
    let emoji: String?
    let unlockAt: Date
    let createdBy: String
    let forMember: String
    let createdAt: Date
    let openedAt: Date?
    /// unlockAt has passed — the recipient MAY open now.
    let unlocked: Bool
    let text: String?
    let photoId: String?
}

struct CapsulesResponse: Codable { let capsules: [TimeCapsule] }
struct CapsuleResponse: Codable { let capsule: TimeCapsule }

// MARK: Need button

/// The shame-free one-tap signals (5.0 adds `love` and `presence`).
enum NeedType: String, Codable, CaseIterable, Identifiable {
    case space, closeness, listen, distraction, love, presence, comfort
    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .space: return "🌿"
        case .comfort: return "🫂"
        case .distraction: return "🎈"
        case .closeness: return "💞"
        case .listen: return "👂"
        case .love: return "❤️"
        case .presence: return "🤍"
        }
    }

    var titleKey: String { "needs.type.\(rawValue)" }
}

struct NeedSignal: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let note: String?
    let senderId: String
    let forMember: String
    let createdAt: Date
    let ackAt: Date?
    let ackNote: String?

    var needType: NeedType? { NeedType(rawValue: type) }
}

struct NeedsResponse: Codable { let needs: [NeedSignal] }
struct NeedResponse: Codable { let need: NeedSignal }

// MARK: Shared goals

struct GoalContribution: Codable, Identifiable, Hashable {
    let id: String
    let memberId: String
    let amount: Double
    let note: String?
    let createdAt: Date
}

struct SharedGoal: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let emoji: String?
    let targetValue: Double
    let unit: String?
    let targetDate: String?
    let createdBy: String
    let createdAt: Date
    let completedAt: Date?
    let contributions: [GoalContribution]
    /// Server-computed sum & clamped percent (0…100).
    let total: Double
    let percent: Double
}

struct GoalsResponse: Codable { let goals: [SharedGoal] }
struct GoalResponse: Codable { let goal: SharedGoal }

/// Contribution result; `milestone` = highest 25/50/75/100 marker crossed
/// by this booking (drives the confetti).
struct GoalContributionResponse: Codable {
    let contribution: GoalContribution
    let goal: SharedGoal
    let milestone: Int?
}

// MARK: Week plan

struct AvailabilityMark: Codable, Hashable {
    let status: String
    let setAt: Date
}

struct WeekplanSlot: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let emoji: String?
    /// call / movie / date / custom
    let kind: String
    /// One-off slot (exactly one of dateKey/weekday is set).
    let dateKey: String?
    /// Recurring slot: 0 = Sunday … 6 = Saturday (UTC).
    let weekday: Int?
    /// "HH:MM" or nil.
    let time: String?
    let createdBy: String
    let createdAt: Date
}

struct WeekplanDay: Codable, Hashable {
    let dateKey: String
    let weekday: Int
    let availability: [String: AvailabilityMark]
    let slots: [WeekplanSlot]
    /// Both partners marked the day and neither is busy. ✨
    let overlap: Bool
}

struct WeekplanResponse: Codable {
    let start: String
    /// Mutable so an availability PUT can patch one day in place.
    var days: [WeekplanDay]
    let slots: [WeekplanSlot]
}

struct WeekplanDayResponse: Codable { let day: WeekplanDay }
struct WeekplanSlotResponse: Codable { let slot: WeekplanSlot }

// MARK: App-event log (v3.0 — GET /api/app-events)

/// One entry of the couple's shared milestone log. `data` is a small
/// free-form object (e.g. `{gameId, cardIndex, title}` for `movie_match`).
struct AppEventRecord: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let memberId: String?
    let data: [String: JSONValue]?
    let createdAt: Date

    /// Convenience: the string value of a `data` field, if present.
    func dataString(_ key: String) -> String? {
        if case .string(let value) = data?[key] { return value }
        return nil
    }
}

struct AppEventsResponse: Codable { let events: [AppEventRecord] }

// MARK: Energy traffic light

/// 🟢🟡🔴 after-work status — the server hides it once older than 12 h.
struct MemberEnergy: Codable, Hashable {
    let level: String
    let note: String?
    let setAt: Date
}

enum EnergyLevel: String, Codable, CaseIterable, Identifiable {
    case green, yellow, red
    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .green: return "🟢"
        case .yellow: return "🟡"
        case .red: return "🔴"
        }
    }

    var titleKey: String { "energy.level.\(rawValue)" }
    var hintKey: String { "energy.hint.\(rawValue)" }
}

struct EnergyResponse: Codable { let energy: MemberEnergy? }

// MARK: "Unser Monat" magazine

struct MagazinePhoto: Codable, Identifiable, Hashable {
    let id: String
    let url: String
    let thumbUrl: String?
    let caption: String?
    let favorites: [String]
}

/// The both-answered daily entry with the most heart that month.
struct MagazineQuote: Codable, Hashable {
    let dateKey: String
    let questionId: Int?
    let answers: [String: String]
}

struct MagazineSong: Codable, Hashable {
    let id: String
    let title: String
    let artist: String?
    let heartedBy: [String]
}

struct MagazineStats: Codable, Hashable {
    let messages: Int
    let touches: Int
    let photosAdded: Int
    let videosAdded: Int
    let gamesPlayed: Int
    let wordleDays: Int
    let dailyBothAnswered: Int
    let checkinDaysBoth: Int
    let daymemoDays: Int
    let hugsSent: Int
    let potdDays: Int
    let goalsCompleted: Int
}

struct MagazineIssue: Codable, Hashable {
    let month: String
    let generatedAt: Date
    let photos: [MagazinePhoto]
    let quote: MagazineQuote?
    let song: MagazineSong?
    let stats: MagazineStats
    /// Read receipts: memberId → first-seen timestamp.
    let seen: [String: Date]
}

struct MagazineMonthsResponse: Codable { let months: [String] }

struct MagazineSeenResponse: Codable {
    let month: String
    let seen: [String: Date]
}

// MARK: - WS payloads

/// `capsule_sealed` / `capsule_opened` — per-member tailored (recipient
/// frames are redacted until opened).
struct CapsuleEventPayload: Codable { let capsule: TimeCapsule }

struct NeedEventPayload: Codable { let need: NeedSignal }

/// `goal_updated` carries the crossed milestone (25/50/75/100) for confetti.
struct GoalEventPayload: Codable {
    let goal: SharedGoal
    let milestone: Int?
}

struct WeekplanAvailabilityPayload: Codable {
    let dateKey: String
    let memberId: String
    let status: String?
    let day: WeekplanDay
}

struct WeekplanSlotPayload: Codable { let slot: WeekplanSlot }

/// `energy` — nil energy = the member cleared their light.
struct EnergyEventPayload: Codable {
    let memberId: String
    let energy: MemberEnergy?
}

struct MagazineSeenPayload: Codable {
    let month: String
    let memberId: String
    let seen: [String: Date]
}
