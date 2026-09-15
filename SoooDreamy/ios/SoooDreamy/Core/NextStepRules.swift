import Foundation

/// The one thing worth doing next on "Heute" — derived from real state
/// instead of a wall of nudges. Pure logic (Foundation only) so the priority
/// order is unit-tested on Linux.
///
/// Priority, highest first:
/// 1. A special day is today (anniversary, planned date) — the day itself leads.
/// 2. A game is waiting for my move — the partner is literally waiting.
/// 3. The partner answered today's question and I have not.
/// 4. Morning check-in still open during the morning hours.
/// 5. Good-night check-in still open in the evening.
/// 6. A special day is tomorrow — time to plan something.
/// 7. Today's question unanswered by both.
/// 8. My mood is stale (or never set) — say how I feel.
/// 9. Nothing arrived from the partner today — send a little love.
/// 10. Everything done: a quiet "all caught up".
enum NextStepRules {
    struct SpecialDay: Equatable {
        var title: String
        var emoji: String
        var daysUntil: Int
    }

    enum Kind: Equatable {
        case specialDay(SpecialDay)
        case gameTurn(count: Int)
        case answerDaily(partnerAnswered: Bool)
        case morningCheckin
        case nightCheckin
        case shareMood
        case sendLove
        case allDone
    }

    struct Input {
        var hour: Int                       // 0…23 local time
        var gamesAwaiting: Int = 0
        var myAnswered = false
        var partnerAnswered = false
        var questionAvailable = true
        var morningDone = false
        var nightDone = false
        var myMoodAge: TimeInterval? = nil  // nil = never set
        var receivedTouchToday = false
        var hasPartner = true
        var nextSpecialDay: SpecialDay? = nil  // nearest upcoming event, if any
    }

    enum Daypart: Equatable { case morning, day, evening, night }

    static func daypart(hour: Int) -> Daypart {
        switch hour {
        case 5..<11: return .morning
        case 11..<18: return .day
        case 18..<23: return .evening
        default: return .night
        }
    }

    /// Mood counts as stale after a day.
    static let moodStaleAfter: TimeInterval = 24 * 3600

    static func nextStep(_ input: Input) -> Kind {
        guard input.hasPartner else { return .allDone }
        if let day = input.nextSpecialDay, day.daysUntil == 0 { return .specialDay(day) }
        if input.gamesAwaiting > 0 { return .gameTurn(count: input.gamesAwaiting) }
        if input.questionAvailable, input.partnerAnswered, !input.myAnswered {
            return .answerDaily(partnerAnswered: true)
        }
        let part = daypart(hour: input.hour)
        if part == .morning, !input.morningDone { return .morningCheckin }
        if (part == .evening || part == .night), !input.nightDone { return .nightCheckin }
        if let day = input.nextSpecialDay, day.daysUntil == 1 { return .specialDay(day) }
        if input.questionAvailable, !input.myAnswered { return .answerDaily(partnerAnswered: false) }
        if input.myMoodAge.map({ $0 > moodStaleAfter }) ?? true { return .shareMood }
        if !input.receivedTouchToday { return .sendLove }
        return .allDone
    }

    /// L10n key of the greeting for the hour ("Guten Morgen" …).
    static func greetingKey(hour: Int) -> String {
        switch daypart(hour: hour) {
        case .morning: return "today.greeting.morning"
        case .day: return "today.greeting.day"
        case .evening: return "today.greeting.evening"
        case .night: return "today.greeting.night"
        }
    }
}
