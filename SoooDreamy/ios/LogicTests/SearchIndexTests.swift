import XCTest
@testable import SoooDreamyLogic

/// The search tab's filtering rules: every word must match, case and accents
/// don't matter, scopes split memories from chat, newest first.
final class SearchIndexTests: XCTestCase {
    private func hit(_ id: String, kind: SearchKind, text: String, daysAgo: Int = 0) -> SearchHit {
        SearchHit(id: id, kind: kind, title: text, subtitle: nil,
                  date: Date(timeIntervalSince1970: 1_700_000_000 - Double(daysAgo) * 86_400),
                  target: kind == .chat ? .chat(messageId: id) : .memories(.events),
                  haystack: text)
    }

    private var corpus: SearchCorpus {
        var c = SearchCorpus()
        c.append(hit("rome", kind: .moments, text: "Städtetrip nach Rom", daysAgo: 30))
        c.append(hit("cafe", kind: .photos, text: "Café Müller am Fluss", daysAgo: 3))
        c.append(hit("msg", kind: .chat, text: "Ich freu mich auf Rom!", daysAgo: 1))
        c.append(hit("song", kind: .songs, text: "Roma — Bosco", daysAgo: 10))
        return c
    }

    func testEmptyQueryReturnsNothing() {
        XCTAssertTrue(corpus.hits(matching: "", scope: .all).isEmpty)
        XCTAssertTrue(corpus.hits(matching: "   ", scope: .all).isEmpty)
    }

    func testCaseAndDiacriticsAreIgnored() {
        XCTAssertEqual(corpus.hits(matching: "cafe muller", scope: .all).map(\.id), ["cafe"])
        XCTAssertEqual(corpus.hits(matching: "STÄDTETRIP", scope: .all).map(\.id), ["rome"])
    }

    func testEveryWordMustMatch() {
        XCTAssertEqual(corpus.hits(matching: "rom fluss", scope: .all), [])
        XCTAssertEqual(Set(corpus.hits(matching: "rom", scope: .all).map(\.id)), ["rome", "msg", "song"])
    }

    func testNewestFirst() {
        XCTAssertEqual(corpus.hits(matching: "rom", scope: .all).map(\.id), ["msg", "song", "rome"])
    }

    func testScopesSplitChatFromMemories() {
        XCTAssertEqual(corpus.hits(matching: "rom", scope: .chat).map(\.id), ["msg"])
        XCTAssertEqual(corpus.hits(matching: "rom", scope: .memories).map(\.id), ["song", "rome"])
    }

    func testKindsHaveSymbolsAndL10nKeys() {
        for kind in SearchKind.allCases {
            XCTAssertFalse(kind.symbol.isEmpty)
            XCTAssertEqual(kind.titleKey, "search.kind.\(kind.rawValue)")
        }
        XCTAssertFalse(SearchKind.chat.inMemories)
        XCTAssertTrue(SearchKind.journal.inMemories)
    }
}
