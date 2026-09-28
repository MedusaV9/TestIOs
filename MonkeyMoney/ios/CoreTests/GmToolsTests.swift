import XCTest
@testable import MonkeyMoneyCore

/// Show-Master question tools (skip, clock shift, replace, shelf swap, ban)
/// and the richer reveal data (summary, phone result, round delta).
final class GmToolsTests: XCTestCase {
    var catalog: ContentCatalog { TestContent.catalog }

    func startedQuestion(players: Int = 3, patch: (inout MatchSettings) -> Void = { _ in }) -> (Engine, EngineState, Millis) {
        let engine = Engine(catalog: catalog)
        var settings = MatchSettings(modus: .quick)
        settings.tempo = .normal
        patch(&settings)
        var s = EngineState(matchId: "g", roomCode: "GMGM", seed: 33, settings: settings, now: 0, gmPin: "4242")
        for i in 0..<players { engine.reduce(&s, .join(playerId: "p\(i)", name: "P\(i)", avatar: Avatar(), profileId: nil, isBot: false), now: 0) }
        engine.reduce(&s, .gm(.flowNext), now: 0)
        var now: Millis = 0
        while s.phase != .frage && now < 300_000 { now += 250; engine.tick(&s, now: now) }
        XCTAssertEqual(s.phase, .frage)
        XCTAssertEqual(s.minigame?.id, "bananen-basics")
        return (engine, s, now)
    }

    func wallQuestionId(_ engine: Engine, _ s: EngineState, _ now: Millis) -> String? {
        guard let box = s.minigame, let plugin = MinigameRegistry.plugin(box.id) else { return nil }
        return plugin.gmInfo(box.data, engine.context(s, now: now)).question?.id
    }

    func deadline(_ engine: Engine, _ s: EngineState, _ now: Millis) -> Millis? {
        if case .frage(let wall, _, _, _, _) = engine.stageView(s, now: now, joinURL: "", gmURL: "").scene { return wall?.deadline }
        return nil
    }

    func correctIndex(_ engine: Engine, _ s: EngineState, _ now: Millis) -> Int {
        let q = catalog.question(wallQuestionId(engine, s, now)!)!
        return q.correctIndex ?? 0
    }

    func testQuestionSkipAnnulsWithoutBooking() {
        var (engine, s, now) = startedQuestion()
        let balances = s.players.map(\.balance)
        let qi = s.questionIndex
        engine.reduce(&s, .player("p0", .choose(correctIndex(engine, s, now))), now: now + 500)
        engine.reduce(&s, .gm(.questionSkip), now: now + 600)
        XCTAssertEqual(s.phase, .frage)
        XCTAssertEqual(s.questionIndex, qi + 1)
        XCTAssertEqual(s.players.map(\.balance), balances, "a skipped question books nothing")
        XCTAssertEqual(s.players[0].stats.richtig, 0)
        XCTAssertTrue(s.moments.contains { $0.text == "⏭️ Frage übersprungen" })
        XCTAssertEqual(wallQuestionId(engine, s, now), s.currentQuestionIds[qi + 1])
        // Skipping the last question of the round ends the round.
        now += 1000
        while s.phase == .frage { engine.reduce(&s, .gm(.questionSkip), now: now) }
        XCTAssertEqual(s.phase, .zwischenstand)
    }

    func testTimerShiftBothWaysWithClampAndNoLimit() {
        var (engine, s, now) = startedQuestion()
        let d0 = deadline(engine, s, now)!
        engine.reduce(&s, .player("p0", .choose(0)), now: now + 1000)
        engine.reduce(&s, .gm(.timerShift(ms: -5000)), now: now)
        XCTAssertEqual(deadline(engine, s, now), d0 - 5000)
        for _ in 0..<3 { engine.reduce(&s, .gm(.timerShift(ms: 2000)), now: now) }
        XCTAssertEqual(deadline(engine, s, now), d0 + 1000, "no limit on the number of shifts")
        engine.reduce(&s, .gm(.timerShift(ms: -600_000)), now: now)
        XCTAssertEqual(deadline(engine, s, now), now + 3000, "at least 3 s stay on the clock")
        engine.reduce(&s, .gm(.timerShift(ms: -1000)), now: now)
        XCTAssertEqual(deadline(engine, s, now), now + 3000)
        // The given answer keeps its answer time (1.0 s).
        let g = engine.gmView(s, now: now, joinURL: "", gmURL: "")
        XCTAssertEqual(g.antwortenDetail["p0"]?.ms, 1000)
        XCTAssertNotNil(g.antwortenDetail["p0"]?.richtig)
        XCTAssertEqual(g.aktuelleFrageId, wallQuestionId(engine, s, now))
    }

    func testQuestionReplaceWithIdAndRandom() {
        var (engine, s, now) = startedQuestion()
        let balances = s.players.map(\.balance)
        let old = s.currentQuestionIds[s.questionIndex]
        let fresh = catalog.questions.first { $0.typ == .choice && !s.usedQuestionIds.contains($0.id) && !$0.isAdultOnly }!
        engine.reduce(&s, .gm(.questionReplace(frageId: fresh.id)), now: now + 100)
        XCTAssertEqual(s.phase, .frage)
        XCTAssertEqual(s.currentQuestionIds[s.questionIndex], fresh.id)
        XCTAssertEqual(wallQuestionId(engine, s, now), fresh.id)
        XCTAssertEqual(s.players.map(\.balance), balances)
        XCTAssertTrue(s.usedQuestionIds.contains(old), "the shown question stays used")
        // A used id is refused.
        engine.reduce(&s, .gm(.questionReplace(frageId: old)), now: now + 200)
        XCTAssertEqual(s.currentQuestionIds[s.questionIndex], fresh.id)
        // Random replacement: another fitting question of the section.
        engine.reduce(&s, .gm(.questionReplace(frageId: nil)), now: now + 300)
        let random = s.currentQuestionIds[s.questionIndex]
        XCTAssertNotEqual(random, fresh.id)
        XCTAssertTrue(catalog.question(random)!.typ.isChoiceLike)
        XCTAssertEqual(wallQuestionId(engine, s, now + 300), random)
    }

    func testRegalSwapAndBan() {
        var (engine, s, now) = startedQuestion()
        var g = engine.gmView(s, now: now, joinURL: "", gmURL: "")
        guard let first = g.regal.first, let idx = first.index else { return XCTFail("shelf is empty") }
        XCTAssertEqual(idx, s.questionIndex + 1)
        XCTAssertEqual(first.tauschbar, true)
        XCTAssertNotNil(first.antworten)
        // Random swap.
        engine.reduce(&s, .gm(.regalSwap(index: idx, frageId: nil)), now: now)
        XCTAssertNotEqual(s.currentQuestionIds[idx], first.id)
        XCTAssertFalse(s.usedQuestionIds.contains(first.id), "an unasked shelf question goes back to the catalogue")
        // Swap with a given id.
        let pick = catalog.questions.first { $0.typ == .choice && !s.usedQuestionIds.contains($0.id) && !$0.isAdultOnly }!
        engine.reduce(&s, .gm(.regalSwap(index: idx, frageId: pick.id)), now: now)
        XCTAssertEqual(s.currentQuestionIds[idx], pick.id)
        // The running question is not on the shelf.
        engine.reduce(&s, .gm(.regalSwap(index: s.questionIndex, frageId: nil)), now: now)
        XCTAssertEqual(wallQuestionId(engine, s, now), s.currentQuestionIds[s.questionIndex])
        // Banning an upcoming question swaps it out automatically.
        engine.reduce(&s, .gm(.questionBan(frageId: pick.id)), now: now)
        XCTAssertTrue(s.settings.fragenAus.contains(pick.id))
        XCTAssertFalse(s.currentQuestionIds.contains(pick.id))
        g = engine.gmView(s, now: now, joinURL: "", gmURL: "")
        XCTAssertEqual(g.katalog?.fragenAus, 1)
        engine.reduce(&s, .gm(.questionUnban(frageId: pick.id)), now: now)
        XCTAssertFalse(s.settings.fragenAus.contains(pick.id))
    }

    func testFilterChangeMidRoundSwapsTheShelf() {
        var (engine, s, now) = startedQuestion()
        let upcoming = Array(s.currentQuestionIds[(s.questionIndex + 1)...])
        let tiers = Set(upcoming.compactMap { catalog.question($0)?.schw })
        guard let off = tiers.first else { return XCTFail() }
        engine.reduce(&s, .gm(.settingsSet(["schwierigkeitenAus": .array([.string(off.rawValue)])])), now: now)
        for id in s.currentQuestionIds[(s.questionIndex + 1)...] { XCTAssertNotEqual(catalog.question(id)?.schw, off) }
        XCTAssertTrue(s.moments.contains { $0.text.contains("Fragen-Filter") })
    }

    func testRevealSummaryPhoneResultAndRoundDelta() {
        var (engine, s, now) = startedQuestion()
        let k = correctIndex(engine, s, now)
        let n = catalog.question(wallQuestionId(engine, s, now)!)!.choiceOptions.count
        engine.reduce(&s, .player("p0", .choose(k)), now: now + 1200)
        engine.reduce(&s, .player("p1", .choose(k)), now: now + 2500)
        engine.reduce(&s, .player("p2", .choose((k + 1) % n)), now: now + 3000)
        now += 3250
        engine.tick(&s, now: now)
        XCTAssertEqual(s.phase, .aufloesung)
        XCTAssertEqual(s.phaseEndsAt! - s.phaseStartedAt, 8500, "Quick = kurze Show: reveal capped at 8.5 s (7 s + fanfare)")
        guard case .aufloesung(_, _, _, _, _, let reveal?) = engine.stageView(s, now: now, joinURL: "", gmURL: "").scene else { return XCTFail("no reveal summary") }
        XCTAssertEqual(reveal.eintraege.count, 3)
        XCTAssertEqual(reveal.richtigAnzahl, 2)
        XCTAssertEqual(reveal.antwortAnzahl, 3)
        XCTAssertEqual(reveal.schnellster, "p0")
        XCTAssertEqual(reveal.schnellsterMs, 1200)
        XCTAssertNotNil(reveal.richtigText)
        let e0 = reveal.eintraege.first { $0.playerId == "p0" }!
        XCTAssertEqual(e0.richtig, true)
        XCTAssertEqual(e0.platzNachher, 1)
        XCTAssertEqual(e0.balanceVorher, 0)
        XCTAssertGreaterThan(e0.speedBonus ?? 0, 0)
        XCTAssertEqual(reveal.eintraege.first { $0.playerId == "p2" }?.richtig, false)
        XCTAssertTrue(s.moments.contains { $0.art == "schnell" && $0.text.contains("P0 am schnellsten (1,2 s)") })
        // Phone: result card data, speed bonus in the reveal prompt, stats.
        let v = engine.playerView(s, player: "p0", now: now)!
        XCTAssertEqual(v.ergebnis?.richtig, true)
        XCTAssertEqual(v.ergebnis?.antwortMs, 1200)
        XCTAssertEqual(v.ergebnis?.platzNachher, 1)
        XCTAssertEqual(v.ergebnis?.balance, s.player("p0")!.balance)
        XCTAssertEqual(v.stats.richtig, 1)
        if case .reveal(_, _, _, _, _, let bonus) = v.prompt { XCTAssertEqual(bonus, e0.speedBonus) } else { XCTFail("expected reveal prompt") }
        // Finish the round: the standings carry the round delta and the place at round start.
        while s.phase != .zwischenstand && now < 600_000 {
            now += 250
            engine.tick(&s, now: now)
            if s.phase == .frage { engine.reduce(&s, .player("p0", .choose(correctIndex(engine, s, now))), now: now) }
        }
        XCTAssertEqual(s.phase, .zwischenstand)
        guard case .zwischenstand(let entries, _, _, _, _) = engine.stageView(s, now: now, joinURL: "", gmURL: "").scene else { return XCTFail() }
        for e in entries {
            XCTAssertEqual(e.rundenDelta, e.player.balance, "first round: round delta = balance")
            XCTAssertGreaterThan(e.platzVorher, 0)
        }
        if case .idle(_, let sub) = engine.playerView(s, player: "p0", now: now)!.prompt { XCTAssertTrue(sub?.hasPrefix("Diese Runde: +") ?? false, sub ?? "") }
        // p0 answered everything right: a 3er-Serie banner came up once.
        XCTAssertEqual(s.moments.filter { $0.art == "serie" && $0.text.contains("3er-Serie") }.count, 1)
    }

    func testQuestionBrowserRestEndpoint() throws {
        var settings = MatchSettings(modus: .klassik)
        settings.schwierigkeitenAus = [.ultrahard]
        let banned = catalog.questions.first { $0.kat == "geographie" && $0.schw == .easy }!
        settings.fragenAus = [banned.id]
        let hub = RoomHub(engine: Engine(catalog: catalog), state: EngineState(matchId: "m", roomCode: "ABCD", seed: 1, settings: settings, now: 0, gmPin: "4711"), joinBaseURL: "")
        let tmp = FileManager.default.temporaryDirectory
        let server = ShowServer(port: 0, hub: hub, meta: MetaStore(), roots: .init(web: tmp, fonts: tmp, content: tmp))
        func get(_ path: String, _ query: [String: String], remote: String = "192.168.1.20") -> HTTPServer.Response {
            server.api(HTTPServer.Request(method: "GET", path: path, query: query, headers: [:], body: Data(), remoteAddress: remote))
        }
        XCTAssertEqual(get("/api/fragen", [:]).status, 403, "answers are secret for phones")
        XCTAssertEqual(get("/api/fragen", ["pin": "0000"]).status, 403)
        XCTAssertEqual(get("/api/fragen", ["pin": "4711", "limit": "1"]).status, 200)
        struct Q: Decodable { var id: String; var kat: String; var sub: String; var schw: String; var typ: String; var text: String; var korrekt: String; var aus: Bool; var gebannt: Bool; var antworten: [String]? }
        struct Page: Decodable { var gesamt: Int; var offset: Int; var fragen: [Q] }
        let r = get("/api/fragen", ["kat": "geographie", "schw": "easy", "limit": "500"], remote: "127.0.0.1")
        let page = try JSONDecoder().decode(Page.self, from: r.body)
        XCTAssertEqual(page.gesamt, catalog.questions.filter { $0.kat == "geographie" && $0.schw == .easy }.count)
        XCTAssertTrue(page.fragen.allSatisfy { $0.kat == "geographie" && $0.schw == "easy" })
        XCTAssertEqual(page.fragen.map(\.id), page.fragen.sorted { ($0.sub, $0.id) < ($1.sub, $1.id) }.map(\.id), "stable order: sub, then id")
        let b = page.fragen.first { $0.id == banned.id }!
        XCTAssertTrue(b.gebannt && b.aus)
        XCTAssertEqual(b.korrekt, banned.correctDisplay)
        // nurAus: ultrahard questions are all filtered out.
        let aus = try JSONDecoder().decode(Page.self, from: get("/api/fragen", ["nurAus": "1", "schw": "ultrahard", "limit": "5"], remote: "127.0.0.1").body)
        XCTAssertEqual(aus.gesamt, catalog.questions.filter { $0.schw == .ultrahard }.count)
        XCTAssertTrue(aus.fragen.allSatisfy { $0.aus })
        // Search is case- and diacritic-insensitive over text and answers.
        let word = banned.text.split(separator: " ").map(String.init).max { $0.count < $1.count }!
        let hit = try JSONDecoder().decode(Page.self, from: get("/api/fragen", ["q": word.uppercased(), "limit": "500"], remote: "127.0.0.1").body)
        XCTAssertTrue(hit.fragen.contains { $0.id == banned.id }, word)
        let umlaut = catalog.questions.first { $0.text.contains("ü") }!
        let plainWord = umlaut.text.split(separator: " ").first { $0.contains("ü") }!.replacingOccurrences(of: "ü", with: "u")
        let hit2 = try JSONDecoder().decode(Page.self, from: get("/api/fragen", ["q": plainWord, "limit": "500"], remote: "127.0.0.1").body)
        XCTAssertTrue(hit2.fragen.contains { $0.id == umlaut.id }, plainWord)
        // Single question.
        let one = try JSONDecoder().decode(Q.self, from: get("/api/fragen/\(banned.id)", [:], remote: "127.0.0.1").body)
        XCTAssertEqual(one.id, banned.id)
        XCTAssertEqual(get("/api/fragen/gibtsnicht", [:], remote: "127.0.0.1").status, 404)
    }

    func testWireFormatAndAuthorisation() throws {
        let cmds: [(String, GmCommand)] = [
            (#"{"questionSkip":{}}"#, .questionSkip),
            (#"{"timerShift":{"ms":-5000}}"#, .timerShift(ms: -5000)),
            (#"{"questionReplace":{}}"#, .questionReplace(frageId: nil)),
            (#"{"questionReplace":{"frageId":"abc"}}"#, .questionReplace(frageId: "abc")),
            (#"{"regalSwap":{"index":2}}"#, .regalSwap(index: 2, frageId: nil)),
            (#"{"regalSwap":{"index":2,"frageId":"abc"}}"#, .regalSwap(index: 2, frageId: "abc")),
            (#"{"questionBan":{"frageId":"abc"}}"#, .questionBan(frageId: "abc")),
            (#"{"questionUnban":{"frageId":"abc"}}"#, .questionUnban(frageId: "abc")),
        ]
        for (json, cmd) in cmds {
            XCTAssertEqual(Wire.decode(GmCommand.self, Data(json.utf8)), cmd, json)
            let msg = Wire.decode(ClientMessage.self, Data(#"{"t":"gm","cmd":\#(json)}"#.utf8))
            XCTAssertEqual(msg, .gm(cmd), json)
        }
        let hub = RoomHub(engine: Engine(catalog: catalog), state: EngineState(matchId: "m", roomCode: "ABCD", seed: 1, settings: MatchSettings(), now: 0, gmPin: "1234"), joinBaseURL: "")
        let gm = RoomHub.Session(token: "g", role: .gm, playerId: nil, profileId: nil, lastSeen: 0)
        let screen = RoomHub.Session(token: "s", role: .screen, playerId: nil, profileId: nil, lastSeen: 0)
        for (_, cmd) in cmds {
            XCTAssertTrue(hub.allowed(cmd, for: gm))
            XCTAssertFalse(hub.allowed(cmd, for: screen))
        }
        XCTAssertTrue(hub.allowed(.botAdd(name: "x", persona: "y"), for: gm))
        XCTAssertTrue(hub.allowed(.lookSet(playerId: "p", avatar: Avatar()), for: gm))
    }
}
