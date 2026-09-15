import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// Live Activity (lock screen + Dynamic Island) counting down to a couple event.
struct CountdownActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Bumped when the user refreshes; the countdown itself is rendered
        /// with `Text(timerInterval:)`, so no periodic updates are needed.
        var refreshedAt: Date
        /// Live couple context (updated from the WebSocket while the app is
        /// open, no APNs). All optional — old activities render without them.
        var partnerOnline: Bool?
        var partnerMood: String?
        var lastTouchEmoji: String?
        var streak: Int?
        var note: String?
        /// Style + visible elements (2.0). Travels in the state so the
        /// in-app sheet restyles running activities without a restart.
        /// Optional: activities started before 2.0 decode fine.
        var config: LiveActivityConfig?
        /// Set once the moment arrived — flips the layout to a celebration.
        var celebration: Bool?
    }

    var title: String
    var emoji: String
    var targetDate: Date
    var partnerName: String?
}
#endif
