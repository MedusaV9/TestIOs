import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// "Couple Pulse" Live Activity (lock screen + Dynamic Island): a living card
/// showing what your partner is up to — presence, mood, last touch, streak.
/// Updated locally from the WebSocket while the app is open (no APNs).
struct CouplePulseAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var partnerOnline: Bool
        var partnerMood: String?
        var partnerMoodNote: String?
        /// Raw touch type ("heartbeat", "kiss", …) — mapped to an emoji via
        /// `TouchEmoji.map` so the widget never needs the app's models.
        var lastTouchType: String?
        var lastTouchAt: Date?
        var streak: Int
        var bothAnsweredToday: Bool
        var daysTogether: Int?
        var refreshedAt: Date
        /// Style + visible elements (2.0). Travels in the state so the
        /// in-app sheet restyles running activities without a restart.
        /// Optional: activities started before 2.0 decode fine.
        var config: LiveActivityConfig?
    }

    var myName: String
    var partnerName: String
}
#endif
