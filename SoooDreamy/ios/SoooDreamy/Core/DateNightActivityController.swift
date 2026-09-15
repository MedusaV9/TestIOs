import Foundation
import ActivityKit

/// Drives the Date-Night Live Activity (v3.0 Agent C): one activity per
/// planned date night, phase changes as state updates (never a restart —
/// the Dynamic Island would flicker). Both partners run their own activity;
/// the server relays plan/phase via `datenight_update`, and the activity's
/// own "Weiter" button (DateNightAdvanceIntent) works even app-closed.
@MainActor
enum DateNightActivityController {
    static var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Reconciles the running activity with the server state:
    /// nil → end, new id → restart, same id → phase/style update.
    static func sync(_ dateNight: DateNight?) {
        let running = Activity<DateNightActivityAttributes>.activities
        guard let night = dateNight else {
            for activity in running {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }
            return
        }
        let state = contentState(for: night)
        // Afterglow winds the evening down: the activity dims 3 h later.
        let stale = night.phase == .afterglow
            ? night.phaseChangedAt.addingTimeInterval(3 * 3600)
            : night.startsAt.addingTimeInterval(6 * 3600)
        if let existing = running.first(where: { $0.attributes.dateNightId == night.id }) {
            Task {
                await existing.update(ActivityContent(state: state, staleDate: stale))
            }
            return
        }
        for activity in running {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        guard isSupported else { return }
        let attributes = DateNightActivityAttributes(
            dateNightId: night.id,
            partnerName: SharedStore.readSnapshot()?.partnerName)
        _ = try? Activity.request(attributes: attributes,
                                  content: ActivityContent(state: state, staleDate: stale))
    }

    private static func contentState(for night: DateNight) -> DateNightActivityAttributes.ContentState {
        DateNightActivityAttributes.ContentState(
            title: night.title,
            emoji: night.emoji,
            startsAt: night.startsAt,
            phase: night.phase.rawValue,
            phaseChangedAt: night.phaseChangedAt,
            refreshedAt: Date(),
            config: SharedStore.readLiveActivityConfig())
    }
}
