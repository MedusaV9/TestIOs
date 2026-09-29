import XCTest
@testable import MonkeyMoneyCore

final class SmokeTests: XCTestCase {
    func testMoneyValues() {
        XCTAssertEqual(Money.value(.easy), 100)
        XCTAssertEqual(Money.value(.ultrahard), 1000)
        XCTAssertEqual(Money.speedBonus(value: 250, answeredAfterMs: 1000, timerMs: 15000), 130)
        XCTAssertEqual(Money.format(1234), "1.234 MM")
    }
}
