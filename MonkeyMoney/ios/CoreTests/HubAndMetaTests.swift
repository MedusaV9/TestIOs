import XCTest
@testable import MonkeyMoneyCore

final class HubAndMetaTests: XCTestCase {
    func makeHub() -> RoomHub {
        let engine = Engine(catalog: TestContent.catalog)
        var rng = SeededRandom(seed: 1)
        let code = RoomHub.makeRoomCode(rng: &rng)
        let state = EngineState(matchId: "m1", roomCode: code, seed: 1, settings: MatchSettings(modus: .quick), now: 1000, gmPin: "1234")
        return RoomHub(engine: engine, state: state, joinBaseURL: "http://192.168.2.224:8080")
    }

    func testJoinReconnectAndGmPin() throws {
        let hub = makeHub()
        let code = hub.state.roomCode
        XCTAssertEqual(code.count, 4)
        XCTAssertEqual(hub.joinURL, "http://192.168.2.224:8080/j/\(code)")
        var out = hub.handle("c1", .hello(roomCode: code.lowercased(), role: .player, sessionToken: nil, name: "Zoe", avatar: "kiki-krawall.gruen", gmPin: nil, profileId: nil, profilePin: nil, deviceToken: nil), now: 1000)
        guard case .welcome(let pid, let token, .player, _)? = out.first?.message, let playerId = pid else { return XCTFail("no welcome: \(out)") }
        XCTAssertEqual(hub.state.players.count, 1)
        XCTAssertEqual(hub.state.players[0].name, "Zoe")
        XCTAssertEqual(hub.state.players[0].avatar.affe, "kiki-krawall")
        // Wrong room code and wrong PIN are rejected.
        out = hub.handle("c2", .hello(roomCode: "XXXX", role: .player, sessionToken: nil, name: "Ben", avatar: nil, gmPin: nil, profileId: nil, profilePin: nil, deviceToken: nil), now: 1000)
        if case .error(let c, _)? = out.first?.message { XCTAssertEqual(c, "room") } else { XCTFail("expected room error") }
        out = hub.handle("c3", .hello(roomCode: code, role: .gm, sessionToken: nil, name: nil, avatar: nil, gmPin: "0000", profileId: nil, profilePin: nil, deviceToken: nil), now: 1000)
        if case .error(let c, _)? = out.first?.message { XCTAssertEqual(c, "pin") } else { XCTFail("expected pin error") }
        out = hub.handle("c3", .hello(roomCode: code, role: .gm, sessionToken: nil, name: nil, avatar: nil, gmPin: "1234", profileId: nil, profilePin: nil, deviceToken: nil), now: 1000)
        if case .welcome(_, _, .gm, _)? = out.first?.message {} else { XCTFail("gm welcome") }
        XCTAssertTrue(hub.state.gmOnline)
        // Players may not fire GM commands; the stage may in gmLos rooms.
        out = hub.handle("c1", .gm(.flowNext), now: 1000)
        if case .error(let c, _)? = out.first?.message { XCTAssertEqual(c, "forbidden") } else { XCTFail("player must not start") }
        // Disconnect + reconnect with the token restores the seat.
        _ = hub.connectionClosed("c1", now: 2000)
        XCTAssertFalse(hub.state.players[0].connected)
        out = hub.handle("c9", .hello(roomCode: code, role: .player, sessionToken: token, name: nil, avatar: nil, gmPin: nil, profileId: nil, profilePin: nil, deviceToken: nil), now: 3000)
        if case .welcome(let pid2, let token2, .player, _)? = out.first?.message { XCTAssertEqual(pid2, playerId); XCTAssertEqual(token2, token) } else { XCTFail("reconnect welcome") }
        XCTAssertTrue(hub.state.players[0].connected)
        XCTAssertEqual(hub.state.players.count, 1)
    }

    func testFullMatchOverTheWireProtocol() throws {
        let hub = makeHub()
        let code = hub.state.roomCode
        var tokens: [String: String] = [:]
        for (i, name) in ["Zoe", "Ben", "Mia"].enumerated() {
            let out = hub.handle("c\(i)", .hello(roomCode: code, role: .player, sessionToken: nil, name: name, avatar: nil, gmPin: nil, profileId: nil, profilePin: nil, deviceToken: nil), now: 1000)
            if case .welcome(_, let t, _, _)? = out.first?.message { tokens["c\(i)"] = t }
        }
        _ = hub.handle("screen", .hello(roomCode: "", role: .screen, sessionToken: nil, name: nil, avatar: nil, gmPin: nil, profileId: nil, profilePin: nil, deviceToken: nil), now: 1000)
        // The iPad (screen) starts the show in gmLos mode.
        var out = hub.stageCommand(.flowNext, now: 1000)
        XCTAssertEqual(hub.state.phase, .intro)
        XCTAssertTrue(out.contains { if case .stage = $0.message { return true }; return false })
        XCTAssertTrue(out.contains { if case .player = $0.message { return true }; return false })
        // JSON round trip of every outgoing message (what the WebSocket carries).
        for o in out {
            let data = Wire.encode(o.message)
            XCTAssertFalse(data.isEmpty)
            let back = Wire.decode(ServerMessage.self, data)
            XCTAssertNotNil(back)
        }
        // Drive the match with the phones answering through the wire format.
        var now: Millis = 1000
        var rng = SeededRandom(seed: 5)
        var ticks = 0
        while hub.state.phase != .ende && ticks < 40_000 {
            ticks += 1
            now += 250
            _ = hub.tick(now: now)
            for c in ["c0", "c1", "c2"] {
                guard let s = hub.session(for: c), let pid = s.playerId, let v = hub.engine.playerView(hub.state, player: pid, now: now) else { continue }
                var action: PlayerAction? = nil
                switch v.prompt {
                case .choice(_, let opts, let chosen, _, _, _): if chosen == nil, let o = rng.pick(opts.filter { !$0.removed }) { action = .choose(o.id) }
                case .bank(_, let opts, let chosen, _, _, _): if chosen == nil, let o = rng.pick(opts) { action = .choose(o.id) }
                case .number(_, let lo, let hi, _, _, _, let cur, _, _): if cur == nil { action = .number(lo + (hi - lo) * rng.next()) }
                case .wager(_, _, let lo, _, _, let cur, _, _): if cur == nil { action = .wager(lo) }
                case .vote(_, let opts, let chosen, _): if chosen == nil, let o = rng.pick(opts) { action = .vote(o.id) }
                case .explain(_, _, _, _, let ready, _, _): if !ready { action = .ready("bereit") }
                case .order(_, let items, _, let locked, _): if !locked { _ = hub.handle(c, .action(.order(rng.shuffled(items.map { $0.id })), idem: nil), now: now); action = .confirm }
                case .pickPlayer(_, _, let cands, let chosen, _): if chosen == nil, let o = rng.pick(cands) { action = .pickPlayer(o.id) }
                case .binary(_, _, let a, _, let chosen, _): if chosen == nil { action = .binary(a) }
                case .confirm(_, _, _, let done, _): if !done { action = .confirm }
                case .feedback(_, let done): if !done { action = .feedback(["a", "b", "c"]) }
                default: break
                }
                if let a = action {
                    // Encode → decode like the real transport does.
                    let data = Wire.encode(ClientMessage.action(a, idem: nil))
                    let msg = Wire.decode(ClientMessage.self, data)!
                    out = hub.handle(c, msg, now: now)
                }
            }
        }
        XCTAssertEqual(hub.state.phase, .ende)
        // A GM view carries the cheat sheet while questions run; final view is consistent JSON.
        let gm = hub.gmView(now: now)
        XCTAssertEqual(gm.roomCode, code)
        XCTAssertFalse(Wire.encode(gm).isEmpty)
    }

    func testPlayerActionWireFormat() throws {
        let cases: [PlayerAction] = [.choose(2), .buzz(at: 5), .number(3.5), .order([2, 0, 1]), .wager(300), .text("Lüge"), .taps(9), .chips([5, 5, 0, 0]),
                                     .pickPlayer("p1"), .bank, .cheer, .confirm, .binary("long"), .vote("sport"), .ready("streik"), .button("kaufen"),
                                     .joker(id: "bananen-split", stufe: nil), .joker(id: "schmiergeld", stufe: 2), .jokerBuy("rueckgaberecht"), .feedback(["x"]),
                                     .setLook(Avatar(affe: "kiki-krawall", farbe: "hexff8800")), .setThemen(["sport"]), .radAktion("ja"), .teamWunsch("team0")]
        for c in cases {
            let data = Wire.encode(c)
            let json = String(data: data, encoding: .utf8)!
            XCTAssertTrue(json.contains("\"type\""), json)
            XCTAssertEqual(Wire.decode(PlayerAction.self, data), c, json)
        }
        XCTAssertEqual(String(data: Wire.encode(PlayerAction.choose(2)), encoding: .utf8), "{\"type\":\"choose\",\"value\":2}")
    }

    func testMetaStoreProfilesShopAndBooking() {
        var meta = MetaStore()
        var rng = SeededRandom(seed: 2)
        var zoe = meta.create(name: "Zoe", avatar: Avatar(affe: "glitzer-gina", farbe: "pink"), pin: "4711", deviceToken: "dev1", now: 1000, rng: &rng)
        XCTAssertEqual(zoe.atAktuell, 300)
        XCTAssertEqual(zoe.level, 0)
        // Login: wrong PIN fails, known device works without PIN.
        XCTAssertEqual(meta.login(zoe.id, pin: "0000", deviceToken: "other", now: 2000), .failure(.pinWrong))
        XCTAssertEqual(meta.login(zoe.id, pin: nil, deviceToken: "other", now: 2000), .failure(.pinRequired))
        if case .success(let p) = meta.login(zoe.id, pin: nil, deviceToken: "dev1", now: 2000) { XCTAssertEqual(p.name, "Zoe") } else { XCTFail() }
        // Shop: too expensive, then affordable after a match booking.
        XCTAssertEqual(meta.buy(zoe.id, item: "buzzer-entenquak"), .failure(.tooExpensive))
        var player = Player(id: "p", name: "Zoe", avatar: zoe.avatar, joinOrder: 1, profileId: zoe.id)
        player.balance = 10_000
        player.stats.richtig = 12
        player.stats.laengsteSerie = 4
        player.stats.ultrahardRichtig = 1
        let event = meta.bookMatch(zoe.id, player: player, at: 1500, winner: true, matchId: "m1", now: 3000)
        XCTAssertNotNil(event)
        zoe = meta.profile(zoe.id)!
        // 300 + 1500 + first win 500 + first ultrahard 100 + quest bonuses.
        XCTAssertGreaterThanOrEqual(zoe.atGesamt, 2400)
        XCTAssertEqual(zoe.stats.siege, 1)
        XCTAssertTrue(zoe.ersteMale.contains("sieg"))
        XCTAssertGreaterThan(zoe.passXp, 100)
        // Idempotent booking.
        XCTAssertNil(meta.bookMatch(zoe.id, player: player, at: 1500, winner: true, matchId: "m1", now: 3000))
        XCTAssertEqual(meta.profile(zoe.id)!.stats.siege, 1)
        if case .success(let p) = meta.buy(zoe.id, item: "buzzer-entenquak") {
            XCTAssertTrue(p.besitz.contains("buzzer-entenquak"))
            XCTAssertEqual(p.ausgeruestet["buzzer"], "buzzer-entenquak")
        } else { XCTFail("buy failed") }
        XCTAssertEqual(meta.buy(zoe.id, item: "buzzer-entenquak"), .failure(.owned))
        // Level-gated item.
        if let gated = Shop.items.first(where: { ($0.minLevel ?? 0) > 3 }) {
            if case .failure(.levelGate(let lvl)) = meta.buy(zoe.id, item: gated.id) { XCTAssertEqual(lvl, gated.minLevel) }
        }
        XCTAssertEqual(Shop.items.count, 85)
        XCTAssertEqual(meta.boards().moneyBoss.first?.name, "Zoe")
        XCTAssertEqual(meta.autoTitle(zoe.id), "💰 Money-Boss")
        // Store survives JSON persistence.
        let data = try! JSONEncoder().encode(meta)
        XCTAssertEqual(try! JSONDecoder().decode(MetaStore.self, from: data), meta)
    }
}
