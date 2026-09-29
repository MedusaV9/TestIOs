import XCTest
@testable import MonkeyMoneyCore

/// Loads the real content bundle (7.660 questions, 58 songs) from the repo.
enum TestContent {
    static let catalog: ContentCatalog = {
        let here = URL(fileURLWithPath: #filePath)
        let dir = here.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Content")
        return try! ContentCatalog.load(from: dir)
    }()
}

/// Headless bots play complete matches against the pure engine — the same
/// E2E gate the original project had (tools/bots), now inside `swift test`.
final class MatchSimulationTests: XCTestCase {
    func runMatch(modus: Modus, players: Int, seed: UInt32, settingsPatch: ((inout MatchSettings) -> Void)? = nil, maxTicks: Int = 200_000) -> EngineState {
        let r = SimHarness.run(modus: modus, players: players, seed: seed, settingsPatch: settingsPatch, maxTicks: maxTicks)
        let s = r.state
        XCTAssertEqual(s.phase, .ende, "match (\(modus)) did not reach the end within \(maxTicks) ticks — stuck in \(s.phase) section \(s.sectionIndex) q \(s.questionIndex) minigame \(s.minigame?.id ?? "-")")
        XCTAssertTrue(r.phasesSeen.contains(.frage))
        XCTAssertTrue(r.phasesSeen.contains(.aufloesung))
        XCTAssertTrue(r.phasesSeen.contains(.siegerehrung))
        return s
    }

    func testQuickMatchRunsToTheEnd() {
        let s = runMatch(modus: .quick, players: 3, seed: 42)
        XCTAssertEqual(s.plan.filter { $0.typ == .runde }.count, 4)
        XCTAssertFalse(s.plan.contains { $0.typ == .jackpot })
        XCTAssertEqual(s.plan.last?.typ, .finale)
        XCTAssertEqual(s.plan.last?.fragen, 3)
        XCTAssertNotNil(s.wFinal)
        XCTAssertGreaterThanOrEqual(s.wFinal ?? 0, 500)
        XCTAssertFalse(s.awards.isEmpty)
        XCTAssertGreaterThan(s.usedQuestionIds.count, 10)
    }

    func testKlassikMatchWithJackpotAndWheel() {
        let s = runMatch(modus: .klassik, players: 4, seed: 7)
        XCTAssertTrue(s.plan.contains { $0.typ == .jackpot })
        XCTAssertGreaterThanOrEqual(s.rad.spinsTotal, 2)
        XCTAssertEqual(s.plan.last?.fragen, 5)
        // Every player ends at or above the finale floor of 0.
        for p in s.players { XCTAssertGreaterThanOrEqual(p.balance, 0) }
        // The event log tracks bookings.
        XCTAssertTrue(s.log.contains { $0.art == "buchung" })
    }

    func testMarathonWithAllV2FormatsCompletes() {
        let s = runMatch(modus: .marathon, players: 5, seed: 99, maxTicks: 400_000)
        let ids = Set(s.plan.map { $0.minigameId })
        // Song formats are available (58 songs, 44 with video) and stay in the plan.
        XCTAssertTrue(ids.contains("song-rueckwaerts"))
        XCTAssertTrue(ids.contains("musikvideo-raten"))
        XCTAssertTrue(ids.contains("bananen-bluff"))
        XCTAssertTrue(ids.contains("risiko-leiter"))
        XCTAssertGreaterThan(ids.count, 15)
    }

    func testSpecialRulesAndTeamsMatch() {
        let s = runMatch(modus: .klassik, players: 4, seed: 3) { st in
            st.specialRules = [.pleitegeier, .affensteuer, .kopfgeld, .kapitalismusGong, .notariatsRunde]
            st.teams = .zweier
            st.alkoholEdition = true
        }
        XCTAssertEqual(s.teams.count, 2)
        XCTAssertTrue(s.plan.contains { $0.notariat })
    }

    func testVabanqueFinaleReplacesLianen() {
        let s = runMatch(modus: .quick, players: 2, seed: 11) { st in st.specialRules = [.vabanqueFinale] }
        XCTAssertEqual(s.plan.last?.minigameId, "alles-oder-banane")
    }

    func testTieAfterFinaleTriggersKokosnussShake() {
        let engine = Engine(catalog: TestContent.catalog)
        var settings = MatchSettings(modus: .quick)
        settings.tempo = .zackig
        var s = EngineState(matchId: "tie", roomCode: "TIEE", seed: 3, settings: settings, now: 0, gmPin: "0000")
        for i in 0..<2 { engine.reduce(&s, .join(playerId: "p\(i)", name: "P\(i)", avatar: Avatar(), profileId: nil, isBot: false), now: 0) }
        engine.reduce(&s, .gm(.flowNext), now: 0)
        var now: Millis = 0
        var sawShake = false
        var forcedTie = false
        var ticks = 0
        while s.phase != .ende && ticks < 60_000 {
            ticks += 1
            now += 250
            engine.tick(&s, now: now)
            // Force an exact tie when the finale's first question starts; nobody answers afterwards.
            if !forcedTie, s.isFinale, s.phase == .frage {
                forcedTie = true
                for i in s.players.indices { s.players[i].balance = 1000 }
            }
            if s.minigame?.id == "kokosnuss-shake" {
                sawShake = true
                if let v = engine.playerView(s, player: "p0", now: now), case .tapFrenzy(_, _, _, let active) = v.prompt, active {
                    engine.reduce(&s, .player("p0", .taps(9)), now: now)
                }
            }
        }
        XCTAssertEqual(s.phase, .ende)
        XCTAssertTrue(forcedTie)
        XCTAssertTrue(sawShake, "tie must trigger the Kokosnuss-Shake")
        XCTAssertEqual(s.ranking.first?.id, "p0")
        XCTAssertEqual(s.ranking[0].balance - s.ranking[1].balance, 50)
        XCTAssertEqual(s.plan.filter { $0.minigameId == "kokosnuss-shake" }.count, 1, "the shake runs once")
    }

    func testEngineStateSurvivesSaveLoadRoundTrip() throws {
        let engine = Engine(catalog: TestContent.catalog)
        var s = EngineState(matchId: "m", roomCode: "ABCD", seed: 5, settings: MatchSettings(modus: .klassik), now: 100, gmPin: "0000")
        for i in 0..<3 { engine.reduce(&s, .join(playerId: "p\(i)", name: "P\(i)", avatar: Avatar(), profileId: nil, isBot: false), now: 100) }
        engine.reduce(&s, .gm(.flowNext), now: 100)
        var now: Millis = 100
        while s.phase != .frage && now < 200_000 { now += 250; engine.tick(&s, now: now) }
        XCTAssertEqual(s.phase, .frage)
        let data = try JSONEncoder().encode(s)
        let restored = try JSONDecoder().decode(EngineState.self, from: data)
        if restored != s {
            let ma = Mirror(reflecting: s).children, mb = Mirror(reflecting: restored).children
            for (a, b) in zip(ma, mb) where "\(a.value)" != "\(b.value)" { print("DIFF \(a.label ?? "?"): \(a.value) VS \(b.value)") }
        }
        XCTAssertEqual(restored, s)
        // Both copies evolve identically (deterministic RNG in the state).
        var a = s, b = restored
        for _ in 0..<40 { now += 250; engine.tick(&a, now: now); engine.tick(&b, now: now) }
        XCTAssertEqual(a, b)
    }

    func testPauseShiftsDeadlines() {
        let engine = Engine(catalog: TestContent.catalog)
        var s = EngineState(matchId: "m", roomCode: "ABCD", seed: 9, settings: MatchSettings(modus: .quick), now: 0, gmPin: "0000")
        for i in 0..<2 { engine.reduce(&s, .join(playerId: "p\(i)", name: "P\(i)", avatar: Avatar(), profileId: nil, isBot: false), now: 0) }
        engine.reduce(&s, .gm(.flowNext), now: 0)
        var now: Millis = 0
        while s.phase != .frage && now < 200_000 { now += 250; engine.tick(&s, now: now) }
        let deadlineBefore = engine.stageView(s, now: now, joinURL: "", gmURL: "").scene
        engine.reduce(&s, .gm(.pause(text: "Pizza!", dauerMs: nil)), now: now)
        XCTAssertTrue(s.paused)
        for _ in 0..<400 { now += 250; engine.tick(&s, now: now) }
        XCTAssertEqual(s.phase, .frage, "paused match must not advance")
        engine.reduce(&s, .gm(.resume), now: now)
        XCTAssertFalse(s.paused)
        if case .frage(let wall, _, _, _, _) = deadlineBefore, let before = wall?.deadline {
            if case .frage(let wall2, _, _, _, _) = engine.stageView(s, now: now, joinURL: "", gmURL: "").scene, let after = wall2?.deadline {
                XCTAssertGreaterThan(after, before + 90_000)
            }
        }
    }
}
