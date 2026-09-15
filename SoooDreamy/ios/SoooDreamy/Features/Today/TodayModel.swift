import Foundation
import Observation

/// Data that Today derives beyond `AppState`: the newest partner message,
/// a "memory of the day" flashback and the daily date-idea suggestion.
@MainActor
@Observable
final class TodayModel {
    enum Flashback: Hashable {
        case photo(Photo, daysAgo: Int)
        case daily(DailyEntry, DailyQuestion, daysAgo: Int)
    }

    struct Milestone: Hashable {
        let count: Int
        let years: Bool
    }

    var latestPartnerMessage: Message?
    var flashback: Flashback?
    var discoverIdea: DateIdea?

    func load(appState: AppState) async {
        latestPartnerMessage = nil
        flashback = nil
        guard let api = appState.api, let couple = appState.couple else {
            discoverIdea = nil
            return
        }
        discoverIdea = Self.dailyIdea(coupleId: couple.id)

        async let messagesReq = try? api.messages(limit: 8)
        async let photosReq = try? api.photos()
        async let historyReq = try? api.dailyHistory(limit: 120)

        if let messages = await messagesReq {
            latestPartnerMessage = messages
                .filter { $0.senderId != appState.memberId }
                .max { $0.createdAt < $1.createdAt }
        }

        let cutoff = Date().addingTimeInterval(-7 * 86400)
        var candidates: [Flashback] = []
        if let photos = await photosReq {
            for photo in photos where photo.createdAt < cutoff {
                let days = Int(Date().timeIntervalSince(photo.createdAt) / 86400)
                candidates.append(.photo(photo, daysAgo: days))
            }
        }
        if let entries = await historyReq {
            for entry in entries where entry.bothAnswered {
                if let date = SharedDates.parse(entry.dateKey), date < cutoff {
                    let question = ContentPack.dailyQuestions.first { $0.id == entry.questionId }
                        ?? ContentPack.dailyQuestion(dateKey: entry.dateKey, coupleId: couple.id)
                    let days = Int(Date().timeIntervalSince(date) / 86400)
                    candidates.append(.daily(entry, question, daysAgo: days))
                }
            }
        }
        // Stable pick per day so the card doesn't reshuffle on every refresh.
        if !candidates.isEmpty {
            var generator = SeededGenerator(seed: Self.daySeed(coupleId: couple.id))
            flashback = candidates[generator.int(upTo: candidates.count)]
        }
    }

    /// Exactly X months / years together today?
    func monthiversary(for couple: Couple?) -> Milestone? {
        guard let key = couple?.anniversary, let start = SharedDates.parse(key) else { return nil }
        let cal = SharedDates.calendar
        let startDay = cal.startOfDay(for: start)
        let today = cal.startOfDay(for: Date())
        guard today > startDay else { return nil }
        let comps = cal.dateComponents([.month, .day], from: startDay, to: today)
        guard let months = comps.month, months >= 1, comps.day == 0 else { return nil }
        if months % 12 == 0 { return Milestone(count: months / 12, years: true) }
        return Milestone(count: months, years: false)
    }

    /// Deterministic idea of the day (same on both phones).
    static func dailyIdea(coupleId: String, dateKey: String = SharedDates.todayKey()) -> DateIdea? {
        let ideas = ContentPack.dateIdeas
        guard !ideas.isEmpty else { return nil }
        let seed = (dateKey + coupleId + "idea").unicodeScalars
            .reduce(5381 as UInt64) { ($0 << 5) &+ $0 &+ UInt64($1.value) }
        return ideas[Int(seed % UInt64(ideas.count))]
    }

    private static func daySeed(coupleId: String) -> Int {
        let s = (SharedDates.todayKey() + coupleId).unicodeScalars
            .reduce(5381 as UInt64) { ($0 << 5) &+ $0 &+ UInt64($1.value) }
        return Int(truncatingIfNeeded: s)
    }
}
