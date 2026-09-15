import XCTest
@testable import SoooDreamyLogic

/// The "Jetzt dran" card shows exactly one action; these pin the priority
/// order and the time-of-day boundaries.
final class NextStepRulesTests: XCTestCase {
    private func input(hour: Int) -> NextStepRules.Input {
        var i = NextStepRules.Input(hour: hour)
        i.myMoodAge = 3600            // fresh mood by default
        i.receivedTouchToday = true   // not a quiet day by default
        return i
    }

    func testDayparts() {
        XCTAssertEqual(NextStepRules.daypart(hour: 5), .morning)
        XCTAssertEqual(NextStepRules.daypart(hour: 10), .morning)
        XCTAssertEqual(NextStepRules.daypart(hour: 11), .day)
        XCTAssertEqual(NextStepRules.daypart(hour: 17), .day)
        XCTAssertEqual(NextStepRules.daypart(hour: 18), .evening)
        XCTAssertEqual(NextStepRules.daypart(hour: 22), .evening)
        XCTAssertEqual(NextStepRules.daypart(hour: 23), .night)
        XCTAssertEqual(NextStepRules.daypart(hour: 3), .night)
    }

    func testSpecialDayTodayLeadsEverything() {
        var i = input(hour: 8)
        i.gamesAwaiting = 2
        i.partnerAnswered = true
        let day = NextStepRules.SpecialDay(title: "Jahrestag", emoji: "💍", daysUntil: 0)
        i.nextSpecialDay = day
        XCTAssertEqual(NextStepRules.nextStep(i), .specialDay(day))
    }

    func testSpecialDayTomorrowSitsBelowCheckinsAboveOpenQuestion() {
        var i = input(hour: 8)
        let eve = NextStepRules.SpecialDay(title: "Date", emoji: "🍝", daysUntil: 1)
        i.nextSpecialDay = eve
        XCTAssertEqual(NextStepRules.nextStep(i), .morningCheckin)
        i.morningDone = true
        XCTAssertEqual(NextStepRules.nextStep(i), .specialDay(eve))
        i.myAnswered = true
        XCTAssertEqual(NextStepRules.nextStep(i), .specialDay(eve))
    }

    func testFartherEventsAreNotANextStep() {
        var i = input(hour: 14)
        i.nextSpecialDay = NextStepRules.SpecialDay(title: "Urlaub", emoji: "🏝️", daysUntil: 2)
        XCTAssertEqual(NextStepRules.nextStep(i), .answerDaily(partnerAnswered: false))
    }

    func testGameTurnBeatsEverything() {
        var i = input(hour: 8)
        i.gamesAwaiting = 2
        i.partnerAnswered = true
        XCTAssertEqual(NextStepRules.nextStep(i), .gameTurn(count: 2))
    }

    func testPartnerAnsweredComesBeforeCheckin() {
        var i = input(hour: 8)
        i.partnerAnswered = true
        XCTAssertEqual(NextStepRules.nextStep(i), .answerDaily(partnerAnswered: true))
        i.myAnswered = true
        XCTAssertEqual(NextStepRules.nextStep(i), .morningCheckin)
    }

    func testMorningAndNightCheckins() {
        var morning = input(hour: 7)
        morning.myAnswered = true
        XCTAssertEqual(NextStepRules.nextStep(morning), .morningCheckin)
        morning.morningDone = true
        XCTAssertEqual(NextStepRules.nextStep(morning), .allDone)

        var night = input(hour: 21)
        night.myAnswered = true
        XCTAssertEqual(NextStepRules.nextStep(night), .nightCheckin)
        night.nightDone = true
        XCTAssertEqual(NextStepRules.nextStep(night), .allDone)

        var lateNight = input(hour: 1)
        lateNight.myAnswered = true
        XCTAssertEqual(NextStepRules.nextStep(lateNight), .nightCheckin)
    }

    func testDaytimeFallsThroughToQuestionMoodAndLove() {
        var i = input(hour: 14)
        XCTAssertEqual(NextStepRules.nextStep(i), .answerDaily(partnerAnswered: false))
        i.myAnswered = true
        XCTAssertEqual(NextStepRules.nextStep(i), .allDone)
        i.myMoodAge = nil
        XCTAssertEqual(NextStepRules.nextStep(i), .shareMood)
        i.myMoodAge = 2 * 24 * 3600
        XCTAssertEqual(NextStepRules.nextStep(i), .shareMood)
        i.myMoodAge = 60
        i.receivedTouchToday = false
        XCTAssertEqual(NextStepRules.nextStep(i), .sendLove)
    }

    func testNoQuestionAvailableSkipsDailyStep() {
        var i = input(hour: 14)
        i.questionAvailable = false
        i.partnerAnswered = true
        XCTAssertEqual(NextStepRules.nextStep(i), .allDone)
    }

    func testWithoutPartnerNothingIsDue() {
        var i = input(hour: 8)
        i.hasPartner = false
        i.gamesAwaiting = 3
        XCTAssertEqual(NextStepRules.nextStep(i), .allDone)
    }

    func testGreetingKeys() {
        XCTAssertEqual(NextStepRules.greetingKey(hour: 6), "today.greeting.morning")
        XCTAssertEqual(NextStepRules.greetingKey(hour: 13), "today.greeting.day")
        XCTAssertEqual(NextStepRules.greetingKey(hour: 19), "today.greeting.evening")
        XCTAssertEqual(NextStepRules.greetingKey(hour: 0), "today.greeting.night")
    }
}
