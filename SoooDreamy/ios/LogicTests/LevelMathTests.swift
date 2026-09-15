import XCTest
@testable import SoooDreamyLogic

/// Mirrors server/test/gamification.test.js expectations — the curve must
/// stay identical on both sides (server computes, client displays).
final class LevelMathTests: XCTestCase {
    func testCurveThresholds() {
        XCTAssertEqual(LevelMath.xpForLevel(1), 0)
        XCTAssertEqual(LevelMath.xpForLevel(2), 100)
        XCTAssertEqual(LevelMath.xpForLevel(3), 300)
        XCTAssertEqual(LevelMath.xpForLevel(4), 600)
        XCTAssertEqual(LevelMath.xpForLevel(5), 1000)
        XCTAssertEqual(LevelMath.xpForLevel(10), 4500)
        XCTAssertEqual(LevelMath.xpForLevel(11), 5500)
    }

    func testLevelForXP() {
        XCTAssertEqual(LevelMath.level(forXP: 0), 1)
        XCTAssertEqual(LevelMath.level(forXP: 99), 1)
        XCTAssertEqual(LevelMath.level(forXP: 100), 2)
        XCTAssertEqual(LevelMath.level(forXP: 299), 2)
        XCTAssertEqual(LevelMath.level(forXP: 300), 3)
        XCTAssertEqual(LevelMath.level(forXP: 1000), 5)
        XCTAssertEqual(LevelMath.level(forXP: 4499), 9)
        XCTAssertEqual(LevelMath.level(forXP: 4500), 10)
        XCTAssertEqual(LevelMath.level(forXP: 123_456), LevelMath.level(forXP: 123_456)) // no crash, unbounded
    }

    func testLevelIsMonotonicAndConsistentWithThresholds() {
        var last = 1
        for xp in stride(from: 0, through: 12_000, by: 37) {
            let level = LevelMath.level(forXP: xp)
            XCTAssertGreaterThanOrEqual(level, last)
            XCTAssertLessThanOrEqual(LevelMath.xpForLevel(level), xp)
            XCTAssertGreaterThan(LevelMath.xpForLevel(level + 1), xp)
            last = level
        }
    }

    func testProgressWithinLevel() {
        XCTAssertEqual(LevelMath.progress(forXP: 0), 0)
        XCTAssertEqual(LevelMath.progress(forXP: 50), 0.5, accuracy: 0.0001)
        XCTAssertEqual(LevelMath.progress(forXP: 100), 0, accuracy: 0.0001) // fresh level 2
        XCTAssertEqual(LevelMath.progress(forXP: 200), 0.5, accuracy: 0.0001) // halfway to L3
        XCTAssertLessThanOrEqual(LevelMath.progress(forXP: 999), 1)
    }

    func testTitleKeysClampToCatalog() {
        XCTAssertEqual(LevelMath.titleKey(forLevel: 1), "level.title.1")
        XCTAssertEqual(LevelMath.titleKey(forLevel: 10), "level.title.10")
        XCTAssertEqual(LevelMath.titleKey(forLevel: 37), "level.title.10")
        XCTAssertEqual(LevelMath.titleKey(forLevel: -2), "level.title.1")
        // Every catalog key resolves in DE and EN.
        for n in 1...LevelMath.maxTitleLevel {
            let text = PlatformL10n.table["level.title.\(n)"]
            XCTAssertNotNil(text, "missing level title \(n)")
        }
    }

    func testPlatformTableHasBadgeStringsForAllKnownBadges() {
        let badgeIds = ["first_touch", "touches_500", "hundred_kisses", "hug_marathon",
                        "streak_week", "streak_month", "checkin_month", "wordle_ten",
                        "gamer_25", "photographers", "picasso", "bucket_10", "songbirds",
                        "level_5", "level_10", "night_owls", "early_birds", "icon_gifted",
                        "duet_partners", "quest_complete"]
        for id in badgeIds {
            XCTAssertNotNil(PlatformL10n.table["badge.name.\(id)"], "missing badge name \(id)")
            XCTAssertNotNil(PlatformL10n.table["badge.desc.\(id)"], "missing badge desc \(id)")
        }
    }
}
