import XCTest
@testable import SoooDreamyLogic

/// Invitation links must survive the round trip app → server page → app, and
/// hand-typed codes must be normalised exactly like the server expects.
final class InvitationTests: XCTestCase {
    private let server = URL(string: "https://sooo.example.com:4321")!

    func testCodeNormalisation() {
        XCTAssertEqual(Invitation.normalizeCode("abc234"), "ABC234")
        XCTAssertEqual(Invitation.normalizeCode(" ab-c 2_34 "), "ABC234")
        XCTAssertEqual(Invitation.normalizeCode("ABC234XYZ"), "ABC234")   // extra characters ignored
        XCTAssertNil(Invitation.normalizeCode("ABC23"))
        XCTAssertNil(Invitation.normalizeCode(""))
        XCTAssertNil(Invitation.normalizeCode("💜💜💜💜💜💜"))
    }

    func testWellFormedUsesServerAlphabet() {
        XCTAssertTrue(Invitation.isWellFormedCode("ABC234"))
        XCTAssertFalse(Invitation.isWellFormedCode("ABC0O1"))   // 0, O, 1 are not in the alphabet
        XCTAssertFalse(Invitation.isWellFormedCode("abc234"))   // lower case must be normalised first
        XCTAssertFalse(Invitation.isWellFormedCode("ABC23"))
    }

    func testPageURL() {
        XCTAssertEqual(Invitation.pageURL(server: server, code: "abc234")?.absoluteString,
                       "https://sooo.example.com:4321/invite?code=ABC234")
        XCTAssertNil(Invitation.pageURL(server: server, code: "AB"))
    }

    func testDeepLinkRoundTrip() {
        let link = Invitation.deepLink(server: server, code: "ABC234")
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.scheme, "sooodreamy")
        XCTAssertEqual(link?.host(), "pair")
        let payload = Invitation.parse(link!)
        XCTAssertEqual(payload, Invitation.Payload(server: server.absoluteString, code: "ABC234"))
    }

    func testParseMatchesTheServerRenderedLink() {
        // Exactly what the /invite page emits (server percent-encoded).
        let url = URL(string: "sooodreamy://pair?server=http%3A%2F%2F192.168.1.20%3A4321&code=ABC234")!
        XCTAssertEqual(Invitation.parse(url), Invitation.Payload(server: "http://192.168.1.20:4321", code: "ABC234"))
    }

    func testParseRejectsOtherLinksAndBadCodes() {
        XCTAssertNil(Invitation.parse(URL(string: "sooodreamy://tab/home")!))
        XCTAssertNil(Invitation.parse(URL(string: "https://example.com/pair?code=ABC234")!))
        XCTAssertNil(Invitation.parse(URL(string: "sooodreamy://pair?code=AB")!))
        XCTAssertNil(Invitation.parse(URL(string: "sooodreamy://pair?server=x")!))
        // Code without a server is fine — the active server is used.
        XCTAssertEqual(Invitation.parse(URL(string: "sooodreamy://pair?code=abc234")!),
                       Invitation.Payload(server: nil, code: "ABC234"))
    }
}
