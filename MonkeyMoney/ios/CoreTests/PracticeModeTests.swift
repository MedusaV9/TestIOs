import XCTest
@testable import MonkeyMoneyCore

/// Übungsmodus REST API served by the iPad: question → answer → stats.
final class PracticeModeTests: XCTestCase {
    func makeServer() -> ShowServer {
        let engine = Engine(catalog: TestContent.catalog)
        let state = EngineState(matchId: "m", roomCode: "PRAC", seed: 3, settings: MatchSettings(modus: .quick), now: 1000, gmPin: "1234")
        let hub = RoomHub(engine: engine, state: state, joinBaseURL: "http://localhost:8080")
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        return ShowServer(port: 0, hub: hub, meta: MetaStore(), roots: ShowServer.Roots(web: tmp, fonts: tmp, content: tmp))
    }

    func get(_ server: ShowServer, _ path: String, _ query: [String: String]) -> HTTPServer.Response {
        server.route(HTTPServer.Request(method: "GET", path: path, query: query, headers: [:], body: Data()))
    }

    func post(_ server: ShowServer, _ path: String, _ json: String) -> HTTPServer.Response {
        server.route(HTTPServer.Request(method: "POST", path: path, query: [:], headers: [:], body: Data(json.utf8)))
    }

    struct Q: Decodable { var id: String; var options: [String]; var schw: String; var katName: String; var text: String }
    struct A: Decodable { struct S: Decodable { var gespielt: Int; var richtig: Int; var serie: Int; var beste: Int }; var correct: Bool; var correctIndex: Int; var erkl: String; var stats: S }

    func testQuestionAnswerAndStreakBookkeeping() throws {
        let server = makeServer()
        let r1 = get(server, "/api/uebung/frage", ["device": "d1", "schw": "easy"])
        XCTAssertEqual(r1.status, 200)
        let q = try JSONDecoder().decode(Q.self, from: r1.body)
        XCTAssertEqual(q.schw, "easy")
        XCTAssertGreaterThanOrEqual(q.options.count, 2)
        // Find the correct index by asking the catalog (the API never leaks it).
        let question = TestContent.catalog.question(q.id)!
        let correctText = question.choiceOptions[question.correctIndex!]
        let shownCorrect = q.options.firstIndex(of: correctText)!
        let a1 = try JSONDecoder().decode(A.self, from: post(server, "/api/uebung/antwort", "{\"id\":\"\(q.id)\",\"index\":\(shownCorrect),\"device\":\"d1\"}").body)
        XCTAssertTrue(a1.correct)
        XCTAssertEqual(a1.correctIndex, shownCorrect)
        XCTAssertEqual(a1.stats.gespielt, 1); XCTAssertEqual(a1.stats.richtig, 1); XCTAssertEqual(a1.stats.serie, 1)
        // Answering twice is rejected — no double counting.
        XCTAssertEqual(post(server, "/api/uebung/antwort", "{\"id\":\"\(q.id)\",\"index\":0,\"device\":\"d1\"}").status, 409)
        // A wrong answer resets the streak but keeps the best.
        let r2 = get(server, "/api/uebung/frage", ["device": "d1"])
        let q2 = try JSONDecoder().decode(Q.self, from: r2.body)
        XCTAssertNotEqual(q2.id, q.id, "recently played questions are not repeated")
        let question2 = TestContent.catalog.question(q2.id)!
        let wrong = q2.options.firstIndex { $0 != question2.choiceOptions[question2.correctIndex!] }!
        let a2 = try JSONDecoder().decode(A.self, from: post(server, "/api/uebung/antwort", "{\"id\":\"\(q2.id)\",\"index\":\(wrong),\"device\":\"d1\"}").body)
        XCTAssertFalse(a2.correct)
        XCTAssertEqual(a2.stats.serie, 0); XCTAssertEqual(a2.stats.beste, 1); XCTAssertEqual(a2.stats.gespielt, 2)
        // Devices are independent.
        let other = try JSONDecoder().decode(Q.self, from: get(server, "/api/uebung/frage", ["device": "d2"]).body)
        XCTAssertFalse(other.id.isEmpty)
    }

    func testCategoryFilterAndKidSafe() throws {
        let server = makeServer()
        let cats = try JSONDecoder().decode([Category].self, from: get(server, "/api/kategorien", [:]).body)
        XCTAssertFalse(cats.isEmpty)
        let kat = cats.first { c in TestContent.catalog.questions.contains { $0.kat == c.id && $0.typ == .choice } }!
        for _ in 0..<5 {
            let q = try JSONDecoder().decode(Q.self, from: get(server, "/api/uebung/frage", ["device": "d3", "kat": kat.id, "familie": "1"]).body)
            let full = TestContent.catalog.question(q.id)!
            XCTAssertEqual(full.kat, kat.id)
            XCTAssertTrue(full.isKidSafe)
            _ = post(server, "/api/uebung/antwort", "{\"id\":\"\(q.id)\",\"index\":0,\"device\":\"d3\"}")
        }
        XCTAssertEqual(get(server, "/uebung", [:]).status, 404, "page is served from the web root (missing in this temp root → 404, not a crash)")
    }
}
