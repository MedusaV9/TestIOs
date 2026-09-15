import XCTest
@testable import SoooDreamyLogic

/// `L10nUsageTests` scans literal `L10n.t("…")` calls; keys that views build
/// at runtime slip through. These pin every dynamically composed key.
final class DynamicL10nKeysTests: XCTestCase {
    private func assertExists(_ key: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNotEqual(L10n.t(key), key, "missing L10n key \(key)", file: file, line: line)
    }

    func testGreetingKeysForEveryHour() {
        for hour in 0..<24 {
            let key = NextStepRules.greetingKey(hour: hour)
            assertExists(key)
            assertExists(key + ".named")
        }
    }

    /// Keys chosen by a ternary inside `L10n.t(...)` are invisible to the
    /// literal scan (`L10n\.t\(\s*"…"`), so they are listed here.
    func testNextStepKeysChosenAtRuntime() {
        for key in ["today.next.special.today", "today.next.special.today.sub",
                    "today.next.special.tomorrow", "today.next.special.tomorrow.sub",
                    "today.next.checkinMorning", "today.next.checkinNight",
                    "today.next.game.one", "today.next.game.many",
                    "today.next.daily.partnerAnswered", "today.next.daily.open",
                    "today.next.daily.partnerAnswered.sub", "today.next.daily.open.sub"] {
            assertExists(key)
        }
        XCTAssertEqual(L10n.t("today.next.special.today", ["title": "Jahrestag"]).contains("Jahrestag"), true)
    }

    func testSearchScopeAndKindTitles() {
        for scope in SearchScope.allCases { assertExists(scope.titleKey) }
        for kind in SearchKind.allCases { assertExists(kind.titleKey) }
    }

    func testGreetingsAreLocalisedInBothLanguages() {
        let original = L10n.language
        defer { L10n.language = original }
        for lang in [AppLanguage.de, .en] {
            L10n.language = lang
            XCTAssertNotEqual(L10n.t("today.greeting.morning.named", ["name": "Mia"]),
                              L10n.t("today.greeting.night.named", ["name": "Mia"]))
            XCTAssertTrue(L10n.t("today.greeting.morning.named", ["name": "Mia"]).contains("Mia"))
        }
    }
}
