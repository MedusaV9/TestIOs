import XCTest
@testable import MonkeyMoneyCore

/// Show-Master timer control: timer OFF and fixed time per question.
final class TimerControlTests: XCTestCase {
    func startedQuestion(patch: (inout MatchSettings) -> Void) -> (Engine, EngineState, Millis) {
        let engine = Engine(catalog: TestContent.catalog)
        var settings = MatchSettings(modus: .quick)
        settings.tempo = .normal
        patch(&settings)
        var s = EngineState(matchId: "t", roomCode: "TIME", seed: 21, settings: settings, now: 0, gmPin: "0000")
        for i in 0..<3 { engine.reduce(&s, .join(playerId: "p\(i)", name: "P\(i)", avatar: Avatar(), profileId: nil, isBot: false), now: 0) }
        engine.reduce(&s, .gm(.flowNext), now: 0)
        var now: Millis = 0
        while s.phase != .frage && now < 300_000 { now += 250; engine.tick(&s, now: now) }
        XCTAssertEqual(s.phase, .frage)
        return (engine, s, now)
    }

    func testTimerOffNeverAutoFinishesUntilEveryoneAnswered() {
        var (engine, s, now) = startedQuestion { $0.timerAus = true }
        // No deadline is shown to anyone.
        let stage = engine.stageView(s, now: now, joinURL: "", gmURL: "")
        if case .frage(let wall, _, _, _, _) = stage.scene { XCTAssertNil(wall?.deadline) } else { XCTFail("expected question scene") }
        if case .choice(_, _, _, let deadline, _, _)? = engine.playerView(s, player: "p0", now: now)?.prompt { XCTAssertNil(deadline) } else { XCTFail("expected choice prompt") }
        // Five minutes pass with only two answers — the question must still be open.
        engine.reduce(&s, .player("p0", .choose(0)), now: now)
        engine.reduce(&s, .player("p1", .choose(1)), now: now)
        for _ in 0..<1200 { now += 250; engine.tick(&s, now: now) }
        XCTAssertEqual(s.phase, .frage, "timer off: the question waits for the last player")
        XCTAssertEqual(s.timerExtensions, 0, "Auto-GM must not extend a timer that is off")
        // The last answer resolves it.
        engine.reduce(&s, .player("p2", .choose(2)), now: now)
        now += 250
        engine.tick(&s, now: now)
        XCTAssertEqual(s.phase, .aufloesung)
    }

    func testTimerOffGmCanResolveManually() {
        var (engine, s, now) = startedQuestion { $0.timerAus = true }
        engine.reduce(&s, .player("p0", .choose(0)), now: now)
        for _ in 0..<400 { now += 250; engine.tick(&s, now: now) }
        XCTAssertEqual(s.phase, .frage)
        engine.reduce(&s, .gm(.flowNext), now: now)
        XCTAssertEqual(s.phase, .aufloesung, "the Show-Master's Auflösen ends the question")
    }

    func testTimerCanBeSwitchedOffAndOnMidMatchViaSettingsPatch() {
        var (engine, s, now) = startedQuestion { _ in }
        XCTAssertFalse(s.settings.timerAus)
        engine.reduce(&s, .gm(.settingsSet(["timerAus": .bool(true)])), now: now)
        XCTAssertTrue(s.settings.timerAus)
        XCTAssertTrue(s.moments.contains { $0.text.contains("Timer aus") })
        engine.reduce(&s, .gm(.settingsSet(["timerAus": .bool(false), "fragenZeit": .number(60)])), now: now)
        XCTAssertFalse(s.settings.timerAus)
        XCTAssertEqual(s.settings.fragenZeit, 60)
        engine.reduce(&s, .gm(.settingsSet(["fragenZeit": .number(0)])), now: now)
        XCTAssertNil(s.settings.fragenZeit)
    }

    func testFixedTimePerQuestionOverridesDifficultyTimer() {
        let (engine, s, now) = startedQuestion { $0.fragenZeit = 60 }
        let stage = engine.stageView(s, now: now, joinURL: "", gmURL: "")
        guard case .frage(let wall?, _, _, _, _) = stage.scene, let deadline = wall.deadline else { return XCTFail("expected wall with deadline") }
        XCTAssertEqual(wall.timerMs, 60_000)
        XCTAssertGreaterThanOrEqual(deadline - s.minigame!.startedAt, 60_000)
        // Default (per difficulty, tempo normal) is 15/20/25 s — never 60.
        let (engine2, s2, now2) = startedQuestion { _ in }
        if case .frage(let wall2?, _, _, _, _) = engine2.stageView(s2, now: now2, joinURL: "", gmURL: "").scene {
            XCTAssertTrue([15_000, 20_000, 25_000].contains(wall2.timerMs), "got \(wall2.timerMs)")
        } else { XCTFail() }
    }

    func testAnswerWindowHelper() {
        var settings = MatchSettings(modus: .klassik)
        settings.tempo = .normal
        let section = Section(typ: .runde, slot: .opener, minigameId: "bananen-tresor", fragen: 1, schwierigkeiten: [.easy], kategorieWahl: .keine, radDanach: false, rundenNummer: 1, kategorie: nil, notariat: false)
        var ctx = MinigameContext(now: 0, rng: SeededRandom(seed: 1), settings: settings, players: ["a"], names: [:], balances: [:], connected: [], klauSchutz: [], mods: QuestionMods(), section: section, catalog: TestContent.catalog)
        XCTAssertEqual(ctx.answerWindow(20_000), 20_000)
        ctx.settings.fragenZeit = 60
        XCTAssertEqual(ctx.answerWindow(20_000), 60_000, "a fixed override never shortens a longer window but lengthens shorter ones")
        ctx.settings.fragenZeit = 10
        XCTAssertEqual(ctx.answerWindow(20_000), 20_000)
        ctx.settings.timerAus = true
        XCTAssertEqual(ctx.answerWindow(20_000), MinigameContext.unlimitedMs)
        XCTAssertNil(ctx.visible(12345))
    }
}
