import XCTest
@testable import SoooDreamyLogic

/// Pins the daily-quest determinism, the shared-checkbox reducer and the
/// streak math — all pure (dateKeys injected, no OS clock).
final class DailyQuestsLogicTests: XCTestCase {
    private let anna = "member-a"
    private let ben = "member-b"

    func testPoolIsBigAndClean() {
        let pool = ContentPack.dailyQuests
        XCTAssertGreaterThanOrEqual(pool.count, 40, "spec wants 40+ quests")
        XCTAssertEqual(Set(pool.map(\.id)).count, pool.count, "ids must be unique")
        for quest in pool {
            XCTAssertFalse(quest.text.de.isEmpty)
            XCTAssertFalse(quest.text.en.isEmpty)
            XCTAssertFalse(quest.emoji.isEmpty)
        }
    }

    func testQuestIndexesAreDeterministicAndDistinct() {
        let first = DailyQuests.questIndexes(coupleId: "cp_1", dateKey: "2026-08-08")
        let again = DailyQuests.questIndexes(coupleId: "cp_1", dateKey: "2026-08-08")
        XCTAssertEqual(first, again, "same couple + day → same quests on both devices")
        XCTAssertEqual(first.count, DailyQuests.questsPerDay)
        XCTAssertEqual(Set(first).count, first.count, "no duplicate quests in one day")
        for index in first {
            XCTAssertTrue(ContentPack.dailyQuests.indices.contains(index))
        }
    }

    func testQuestIndexesVaryByDayAndCouple() {
        let base = DailyQuests.questIndexes(coupleId: "cp_1", dateKey: "2026-08-08")
        let nextDay = DailyQuests.questIndexes(coupleId: "cp_1", dateKey: "2026-08-09")
        let otherCouple = DailyQuests.questIndexes(coupleId: "cp_2", dateKey: "2026-08-08")
        XCTAssertNotEqual(base, nextDay)
        XCTAssertNotEqual(base, otherCouple)
    }

    func testReduceFirstTapWinsAndSkipsAliens() {
        let valid = [3, 17, 42]
        let state = DailyQuests.reduce(events: [
            .done(member: anna, questIndex: 17),
            .done(member: ben, questIndex: 17), // re-check → ignored
            .done(member: ben, questIndex: 5), // not today's quest → skipped
            .done(member: ben, questIndex: 3),
        ], validIndexes: valid)
        XCTAssertEqual(state.doneCount, 2)
        XCTAssertEqual(state.doneBy[17], anna, "first tap wins")
        XCTAssertEqual(state.doneBy[3], ben)
        XCTAssertNil(state.doneBy[5])
    }

    func testStreakCountsBackFromToday() {
        let done: Set<String> = ["2026-08-06", "2026-08-07", "2026-08-08"]
        XCTAssertEqual(DailyQuests.streak(completedDays: done, today: "2026-08-08"), 3)
    }

    func testStreakGraceWhileTodayInProgress() {
        // Today not done yet → the chain ending yesterday still counts.
        let done: Set<String> = ["2026-08-06", "2026-08-07"]
        XCTAssertEqual(DailyQuests.streak(completedDays: done, today: "2026-08-08"), 2)
    }

    func testStreakBreaksOnGap() {
        let done: Set<String> = ["2026-08-04", "2026-08-05", "2026-08-07"]
        XCTAssertEqual(DailyQuests.streak(completedDays: done, today: "2026-08-07"), 1)
        XCTAssertEqual(DailyQuests.streak(completedDays: [], today: "2026-08-08"), 0)
    }

    func testPreviousDayHandlesMonthAndYearBounds() {
        XCTAssertEqual(DailyQuests.previousDay(of: "2026-08-08"), "2026-08-07")
        XCTAssertEqual(DailyQuests.previousDay(of: "2026-03-01"), "2026-02-28")
        XCTAssertEqual(DailyQuests.previousDay(of: "2024-03-01"), "2024-02-29")
        XCTAssertEqual(DailyQuests.previousDay(of: "2026-01-01"), "2025-12-31")
        XCTAssertNil(DailyQuests.previousDay(of: "kaputt"))
    }
}
