import Foundation
import BackgroundTasks
import WidgetKit

// MARK: - Background refresh (BGTaskScheduler)
// Periodically pulls partner status / moments / daily-question state from the
// couple server WITHOUT the app being open, refreshes the app-group snapshot
// and reloads all widget timelines.
//
// Honest iOS reality check (documented in README too): iOS decides when (and
// whether) BGAppRefreshTask runs — based on usage patterns, charger, Low
// Power Mode … Expect a handful of runs per day at best, none guaranteed.
// `earliestBeginDate` is a lower bound, not a schedule. Widgets therefore
// also refresh themselves (photo widget fetches directly; day-math widgets
// carry future-dated timeline entries), and the app refreshes on every open.

enum BackgroundRefresh {
    /// Must match `BGTaskSchedulerPermittedIdentifiers` in project.yml.
    static let taskId = "app.sooodreamy.refresh"

    /// Queues the next refresh (~30 min out; iOS decides the actual time).
    /// Re-submitting the same id simply replaces the pending request.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Fetches fresh couple context and rewrites the widget snapshot.
    /// Runs headless (SwiftUI `.backgroundTask` — no AppState involved) using
    /// the app-group-mirrored credentials.
    static func refreshNow() async {
        guard let creds = SharedStore.readServerCredentials(),
              let token = SharedKeychain.activeToken(profileID: creds.profileID),
              let base = URL(string: creds.baseURLString) else { return }
        let api = API(baseURL: base, token: token)

        // The authenticated server snapshot is the canonical compact source
        // for partner energy, active goal, and relationship level.
        guard let remote = try? await api.widgetSnapshot() else { return }
        let events = (try? await api.events()) ?? []

        var snapshot = SharedStore.readSnapshot() ?? WidgetSnapshot()
        snapshot.partnerName = remote.partner?.name
        snapshot.partnerAvatar = remote.partner?.avatar
        snapshot.partnerColorHex = remote.partner?.color
        snapshot.partnerMood = remote.partner?.mood
        snapshot.partnerMoodNote = remote.partner?.moodNote
        snapshot.partnerMoodUpdatedAt = remote.partner?.moodUpdatedAt
        snapshot.partnerEnergyLevel = remote.partner?.energy?.level
        snapshot.partnerEnergyNote = remote.partner?.energy?.note
        snapshot.partnerEnergySetAt = remote.partner?.energy?.setAt
        snapshot.partnerOnline = remote.partner?.online
        snapshot.myName = remote.me.name
        snapshot.anniversary = remote.couple.anniversary
        snapshot.daysTogether = remote.daysTogether

        let upcoming = events
            .compactMap { ev -> (EventItem, Int)? in
                guard let d = SharedDates.daysUntil(ev.date, repeatsYearly: ev.repeatsYearly),
                      d >= 0 else { return nil }
                return (ev, d)
            }
            .sorted { $0.1 < $1.1 }
        snapshot.nextEventTitle = remote.nextEvent?.title
        snapshot.nextEventEmoji = remote.nextEvent?.emoji
        snapshot.nextEventDate = remote.nextEvent?.date
        snapshot.allEvents = upcoming.map {
            WidgetEventLite(id: $0.0.id, title: $0.0.title, emoji: $0.0.emoji,
                            date: $0.0.date, repeatsYearly: $0.0.repeatsYearly)
        }

        snapshot.dailyAnsweredByMe = remote.dailyAnsweredByMe
        snapshot.dailyBothAnswered = remote.bothAnsweredToday
        snapshot.streak = remote.streak
        let question = ContentPack.dailyQuestion(dateKey: SharedDates.todayKey(),
                                                 coupleId: remote.couple.id)
        snapshot.dailyQuestionDE = question.text.de
        snapshot.dailyQuestionEN = question.text.en
        snapshot.canvasStrokeCount = remote.canvasStrokeCount
        snapshot.goalTitle = remote.goal?.title
        snapshot.goalEmoji = remote.goal?.emoji
        snapshot.goalPercent = remote.goal?.percent
        snapshot.levelNumber = remote.level?.level
        snapshot.levelTitleDE = remote.level?.title.de
        snapshot.levelTitleEN = remote.level?.title.en
        snapshot.levelProgress = remote.level?.progress
        if let photo = remote.latestPhoto {
            snapshot.photoURLString = api.mediaURL(photo.thumbUrl ?? photo.url)?.absoluteString
            snapshot.photoCaption = photo.caption
        } else {
            snapshot.photoURLString = nil
            snapshot.photoCaption = nil
        }

        snapshot.updatedAt = Date()
        SharedStore.writeSnapshot(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
