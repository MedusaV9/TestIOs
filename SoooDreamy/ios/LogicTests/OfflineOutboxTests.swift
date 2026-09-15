import Foundation
import XCTest
@testable import SoooDreamyLogic

final class OfflineOutboxTests: XCTestCase {
    private let scopeA = OutboxScope(profileID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                                     coupleID: "couple-a", memberID: "member-a")
    private let scopeB = OutboxScope(profileID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                                     coupleID: "couple-b", memberID: "member-b")

    func testStateDeduplicatesAndScopesEntriesInFIFOOrder() {
        var state = OfflineOutboxState()
        let late = entry(id: "late", scope: scopeA, text: "second", at: 20)
        let early = entry(id: "early", scope: scopeA, text: "first", at: 10)
        state.enqueue(late)
        state.enqueue(early)
        state.enqueue(entry(id: "early", scope: scopeA, text: "forged replacement", at: 30))
        state.enqueue(entry(id: "other", scope: scopeB, text: "private to B", at: 5))

        XCTAssertEqual(state.entries(for: scopeA).map(\.clientMessageID), ["early", "late"])
        XCTAssertEqual(state.entries(for: scopeA).map(\.text), ["first", "second"])
        XCTAssertEqual(state.entries(for: scopeB).map(\.clientMessageID), ["other"])
    }

    func testAttemptAndAcknowledgementAreIdempotent() {
        var state = OfflineOutboxState()
        state.enqueue(entry(id: "msg-1", scope: scopeA, text: "hello", at: 10))
        state.markAttempt(clientMessageID: "msg-1", at: Date(timeIntervalSince1970: 30))
        XCTAssertEqual(state.entries(for: scopeA).first?.attemptCount, 1)
        XCTAssertEqual(state.entries(for: scopeA).first?.lastAttemptAt,
                       Date(timeIntervalSince1970: 30))

        state.remove(clientMessageID: "msg-1")
        state.remove(clientMessageID: "msg-1")
        XCTAssertTrue(state.entries(for: scopeA).isEmpty)
    }

    func testStoreSurvivesReinitialization() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("outbox-\(UUID().uuidString)", isDirectory: true)
        let file = root.appendingPathComponent("state.json")
        defer { try? FileManager.default.removeItem(at: root) }

        let first = OfflineOutboxStore(fileURL: file)
        _ = first.enqueue(text: "do not lose", scope: scopeA, clientMessageID: "persisted",
                          createdAt: Date(timeIntervalSince1970: 42))

        let restored = OfflineOutboxStore(fileURL: file)
        XCTAssertEqual(restored.entries(for: scopeA).map(\.clientMessageID), ["persisted"])
        XCTAssertEqual(restored.entries(for: scopeA).first?.text, "do not lose")
    }

    func testBoundedQueueKeepsNewestEntries() {
        var state = OfflineOutboxState()
        for index in 0..<(OfflineOutboxState.maximumEntries + 5) {
            state.enqueue(entry(id: "id-\(index)", scope: scopeA, text: "\(index)",
                                at: TimeInterval(index)))
        }
        let entries = state.entries(for: scopeA)
        XCTAssertEqual(entries.count, OfflineOutboxState.maximumEntries)
        XCTAssertEqual(entries.first?.clientMessageID, "id-5")
    }

    private func entry(id: String, scope: OutboxScope, text: String,
                       at: TimeInterval) -> PendingChatText {
        PendingChatText(clientMessageID: id, scope: scope, text: text,
                        createdAt: Date(timeIntervalSince1970: at),
                        attemptCount: 0, lastAttemptAt: nil)
    }
}
