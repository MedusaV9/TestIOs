import XCTest
@testable import SoooDreamyLogic

final class ServerURLPolicyTests: XCTestCase {
    func testPublicHTTPSIsAccepted() {
        XCTAssertEqual(ServerURLPolicy.normalize("https://example.com"), "https://example.com")
        XCTAssertEqual(ServerURLPolicy.normalize("https://example.com/"), "https://example.com")
    }

    func testPublicHTTPWithoutExceptionIsRejected() {
        XCTAssertNil(ServerURLPolicy.normalize("http://example.com"))
        XCTAssertNil(ServerURLPolicy.normalize("http://8.8.8.8:7792"))
    }

    func testBarePublicHostDefaultsToHTTPS() {
        XCTAssertEqual(ServerURLPolicy.normalize("example.com"), "https://example.com")
        XCTAssertEqual(ServerURLPolicy.normalize("example.com:443"), "https://example.com:443")
    }

    func testPrivateLANHTTPIsAccepted() {
        XCTAssertEqual(ServerURLPolicy.normalize("http://192.168.1.20:4321"), "http://192.168.1.20:4321")
        XCTAssertEqual(ServerURLPolicy.normalize("http://10.0.0.2"), "http://10.0.0.2")
        XCTAssertEqual(ServerURLPolicy.normalize("http://localhost:4321"), "http://localhost:4321")
        XCTAssertEqual(ServerURLPolicy.normalize("http://100.64.1.2:4321"), "http://100.64.1.2:4321")
    }

    func testBarePrivateHostDefaultsToHTTP() {
        XCTAssertEqual(ServerURLPolicy.normalize("192.168.1.20:4321"), "http://192.168.1.20:4321")
        XCTAssertEqual(ServerURLPolicy.normalize("localhost:4321"), "http://localhost:4321")
    }

    func testAMPHostHTTPIsAccepted() {
        XCTAssertEqual(
            ServerURLPolicy.normalize("http://ark.atomi23.de:7792"),
            "http://ark.atomi23.de:7792"
        )
        XCTAssertEqual(
            ServerURLPolicy.normalize("  http://ark.atomi23.de:7792/  "),
            "http://ark.atomi23.de:7792"
        )
        XCTAssertEqual(
            ServerURLPolicy.normalize("https://ark.atomi23.de:7792"),
            "https://ark.atomi23.de:7792"
        )
    }

    func testAMPSubdomainIsNotAnException() {
        XCTAssertNil(ServerURLPolicy.normalize("http://www.ark.atomi23.de:7792"))
    }

    func testBareAMPHostDefaultsToHTTPNotHTTPS() {
        XCTAssertEqual(
            ServerURLPolicy.normalize("ark.atomi23.de:7792"),
            "http://ark.atomi23.de:7792"
        )
        XCTAssertEqual(
            ServerURLPolicy.normalize("ark.atomi23.de"),
            "http://ark.atomi23.de"
        )
    }

    func testAMPHostIsCaseInsensitive() {
        XCTAssertEqual(
            ServerURLPolicy.normalize("HTTP://ARK.ATOmi23.DE:7792"),
            "http://ARK.ATOmi23.DE:7792"
        )
    }

    func testEmptyAndGarbageRejected() {
        XCTAssertNil(ServerURLPolicy.normalize("   "))
        XCTAssertNil(ServerURLPolicy.normalize(""))
        XCTAssertNil(ServerURLPolicy.normalize("ftp://ark.atomi23.de:7792"))
    }
}
