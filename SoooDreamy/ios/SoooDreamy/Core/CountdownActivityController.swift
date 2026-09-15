import Foundation
import ActivityKit

/// Starts/stops/updates the countdown Live Activity (lock screen + Dynamic Island).
/// Updates come from the WebSocket while the app is open — no APNs involved.
///
/// Lifecycle (2.0): activities carry a `staleDate` shortly after the target so
/// iOS dims outdated content; when the moment arrives while the app runs, the
/// activity flips to a celebration state and dismisses itself a few hours
/// later. Styling travels in the ContentState (`LiveActivityConfig`).
@MainActor
enum CountdownActivityController {
    static var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    static var activeEventTitle: String? {
        Activity<CountdownActivityAttributes>.activities.first?.attributes.title
    }

    @discardableResult
    static func start(for event: EventItem, partnerName: String?) -> Bool {
        guard isSupported,
              let target = SharedDates.nextOccurrence(event.date, repeatsYearly: event.repeatsYearly),
              target > Date() else { return false }
        stopAll()
        let attributes = CountdownActivityAttributes(title: event.title,
                                                     emoji: event.emoji,
                                                     targetDate: target,
                                                     partnerName: partnerName)
        // Content is stale 30 min past the moment: if the app never got the
        // chance to flip to the celebration, iOS at least dims the timer.
        let content = ActivityContent(state: currentState(),
                                      staleDate: target.addingTimeInterval(30 * 60))
        do {
            _ = try Activity.request(attributes: attributes, content: content)
            return true
        } catch {
            return false
        }
    }

    /// Refreshes all running countdown activities from the shared widget snapshot.
    static func updateFromSnapshot() {
        let snapshot = SharedStore.readSnapshot()
        update(partnerOnline: snapshot?.partnerOnline,
               mood: snapshot?.partnerMood,
               lastTouchEmoji: snapshot?.lastTouchType.map(TouchEmoji.map),
               streak: snapshot?.streak,
               note: snapshot?.partnerMoodNote)
        finishIfDue()
    }

    /// Pushes fresh couple context into every running countdown activity.
    static func update(partnerOnline: Bool?, mood: String?, lastTouchEmoji: String?,
                       streak: Int?, note: String? = nil) {
        let activities = Activity<CountdownActivityAttributes>.activities
        guard !activities.isEmpty else { return }
        let state = CountdownActivityAttributes.ContentState(
            refreshedAt: Date(),
            partnerOnline: partnerOnline,
            partnerMood: mood,
            lastTouchEmoji: lastTouchEmoji,
            streak: streak,
            note: note,
            config: SharedStore.readLiveActivityConfig())
        for activity in activities {
            let staleDate = activity.attributes.targetDate.addingTimeInterval(30 * 60)
            let content = ActivityContent(state: state, staleDate: staleDate)
            Task {
                await activity.update(content)
            }
        }
    }

    /// Restyles running activities after the Live-Activity sheet changed the
    /// config — same data, new `config` in the state.
    static func pushConfig() {
        updateFromSnapshot()
    }

    /// Flips activities whose moment arrived into a celebration that
    /// dismisses itself 3 h later (called from snapshot updates/foreground).
    static func finishIfDue() {
        for activity in Activity<CountdownActivityAttributes>.activities
        where activity.attributes.targetDate <= Date() {
            var state = activity.content.state
            guard state.celebration != true else { continue }
            state.celebration = true
            state.refreshedAt = Date()
            state.config = SharedStore.readLiveActivityConfig()
            let content = ActivityContent(state: state, staleDate: nil)
            Task {
                await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(3 * 3600)))
            }
        }
    }

    /// Ends running countdowns for a deleted event (matched by title).
    static func stop(matchingTitle title: String) {
        for activity in Activity<CountdownActivityAttributes>.activities
        where activity.attributes.title == title {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Ends countdowns whose event no longer exists (e.g. partner deleted it).
    static func stopIfEventMissing(events: [EventItem]) {
        let titles = Set(events.map(\.title))
        for activity in Activity<CountdownActivityAttributes>.activities
        where !titles.contains(activity.attributes.title) {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    static func stopAll() {
        for activity in Activity<CountdownActivityAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private static func currentState() -> CountdownActivityAttributes.ContentState {
        let snapshot = SharedStore.readSnapshot()
        return CountdownActivityAttributes.ContentState(
            refreshedAt: Date(),
            partnerOnline: snapshot?.partnerOnline,
            partnerMood: snapshot?.partnerMood,
            lastTouchEmoji: snapshot?.lastTouchType.map(TouchEmoji.map),
            streak: snapshot?.streak,
            note: snapshot?.partnerMoodNote,
            config: SharedStore.readLiveActivityConfig())
    }
}
