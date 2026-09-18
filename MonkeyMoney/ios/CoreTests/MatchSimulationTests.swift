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
    struct Bot {
        var id: PlayerId
        var skill: Double
        var delayMs: Int
    }

    func runMatch(modus: Modus, players: Int, seed: UInt32, settingsPatch: ((inout MatchSettings) -> Void)? = nil, maxTicks: Int = 200_000) -> EngineState {
        let engine = Engine(catalog: TestContent.catalog)
        var settings = MatchSettings(modus: modus)
        settings.tempo = .zackig
        settings.gmLos = true
        settingsPatch?(&settings)
        var s = EngineState(matchId: "test", roomCode: "TEST", seed: seed, settings: settings, now: 1_000_000, gmPin: "1234")
        var now: Millis = 1_000_000
        var bots: [Bot] = []
        var rng = SeededRandom(seed: seed &+ 7)
        for i in 0..<players {
            let id = "p\(i)"
            bots.append(Bot(id: id, skill: 0.35 + Double(i) * 0.12, delayMs: 800 + i * 900))
            engine.reduce(&s, .join(playerId: id, name: "Affe \(i)", avatar: Avatar(affe: "don-bananas", farbe: "gelb"), profileId: nil, isBot: true), now: now)
        }
        engine.reduce(&s, .screenPresence(true), now: now)
        engine.reduce(&s, .gm(.flowNext), now: now)
        XCTAssertEqual(s.phase, .intro)
        var answeredKey: Set<String> = []
        var phasesSeen: Set<Phase> = []
        var ticks = 0
        while s.phase != .ende && ticks < maxTicks {
            ticks += 1
            now += 250
            engine.tick(&s, now: now)
            phasesSeen.insert(s.phase)
            for bot in bots {
                guard let view = engine.playerView(s, player: bot.id, now: now) else { continue }
                let key = "\(s.phase.rawValue)-\(s.sectionIndex)-\(s.questionIndex)-\(view.prompt.kind)-\(s.minigame?.startedAt ?? 0)-\(s.rad.subphase)"
                switch view.prompt {
                case .choice(_, let options, let chosen, _, _, _):
                    guard chosen == nil else { continue }
                    let elapsed = now - (s.minigame?.startedAt ?? s.phaseStartedAt)
                    guard elapsed >= bot.delayMs else { continue }
                    let open = options.filter { !$0.removed }
                    guard !open.isEmpty else { continue }
                    let pick = rng.chance(bot.skill) ? correctIndex(s, engine: engine, options: open) ?? open[rng.below(open.count)].id : open[rng.below(open.count)].id
                    engine.reduce(&s, .player(bot.id, .choose(pick)), now: now)
                case .bank(_, let options, let chosen, let pot, _, _):
                    if pot >= 400, rng.chance(0.3) { engine.reduce(&s, .player(bot.id, .bank), now: now) }
                    guard chosen == nil, !answeredKey.contains(key + "\(s.minigame?.data.count ?? 0)") else { continue }
                    let open = options.filter { !$0.removed }
                    if !open.isEmpty { engine.reduce(&s, .player(bot.id, .choose(open[rng.below(open.count)].id)), now: now) }
                case .number(_, let min, let max, _, _, _, let current, let locked, _):
                    guard current == nil, !locked else { continue }
                    engine.reduce(&s, .player(bot.id, .number(min + (max - min) * rng.next())), now: now)
                case .order(_, let items, _, let locked, _):
                    guard !locked, !answeredKey.contains(key) else { continue }
                    answeredKey.insert(key)
                    engine.reduce(&s, .player(bot.id, .order(rng.shuffled(items.map { $0.id }))), now: now)
                    engine.reduce(&s, .player(bot.id, .confirm), now: now)
                case .wager(_, _, let min, let max, let step, let current, let locked, _):
                    guard current == nil, !locked else { continue }
                    let w = min + step * rng.below(Swift.max(1, (max - min) / Swift.max(1, step) + 1))
                    engine.reduce(&s, .player(bot.id, .wager(w)), now: now)
                case .vote(_, let options, let chosen, _):
                    guard chosen == nil, let o = rng.pick(options) else { continue }
                    engine.reduce(&s, .player(bot.id, .vote(o.id)), now: now)
                case .explain(_, _, let ready, _, _):
                    if !ready { engine.reduce(&s, .player(bot.id, .ready("bereit")), now: now) }
                case .pickPlayer(_, _, let candidates, let chosen, _):
                    guard chosen == nil, let c = rng.pick(candidates) else { continue }
                    engine.reduce(&s, .player(bot.id, .pickPlayer(c.id)), now: now)
                case .binary(_, _, let a, let b, let chosen, _):
                    guard chosen == nil else { continue }
                    engine.reduce(&s, .player(bot.id, .binary(rng.chance(0.5) ? a : b)), now: now)
                case .confirm(_, _, _, let done, _):
                    if !done { engine.reduce(&s, .player(bot.id, .confirm), now: now) }
                case .chips(_, let options, let total, _, let locked, _):
                    guard !locked, !answeredKey.contains(key) else { continue }
                    answeredKey.insert(key)
                    var placed = Array(repeating: 0, count: options.count)
                    for _ in 0..<total { placed[rng.below(options.count)] += 1 }
                    engine.reduce(&s, .player(bot.id, .chips(placed)), now: now)
                    engine.reduce(&s, .player(bot.id, .confirm), now: now)
                case .text(_, _, _, let submitted, _):
                    guard submitted == nil, !answeredKey.contains(key) else { continue }
                    answeredKey.insert(key)
                    engine.reduce(&s, .player(bot.id, .text("Lüge \(bot.id) \(rng.below(999))")), now: now)
                case .buzzer(_, let armed, _, _, _):
                    if armed, rng.chance(0.15) { engine.reduce(&s, .player(bot.id, .buzz(at: now)), now: now) }
                case .feedback(_, let done):
                    if !done { engine.reduce(&s, .player(bot.id, .feedback(["gut", "ok", "alles"])), now: now) }
                case .actions(_, _, let buttons, _):
                    if let b = buttons.first(where: { $0.enabled }) { engine.reduce(&s, .player(bot.id, .button(b.id)), now: now) }
                default:
                    break
                }
            }
            // Stage advances the ceremony like a real host would.
            if s.phase == .ende { break }
        }
        XCTAssertEqual(s.phase, .ende, "match (\(modus)) did not reach the end within \(maxTicks) ticks — stuck in \(s.phase) section \(s.sectionIndex) q \(s.questionIndex) minigame \(s.minigame?.id ?? "-")")
        XCTAssertTrue(phasesSeen.contains(.frage))
        XCTAssertTrue(phasesSeen.contains(.aufloesung))
        XCTAssertTrue(phasesSeen.contains(.siegerehrung))
        return s
    }

    func correctIndex(_ s: EngineState, engine: Engine, options: [ChoiceOption]) -> Int? {
        guard let box = s.minigame, let plugin = MinigameRegistry.plugin(box.id) else { return nil }
        let info = plugin.gmInfo(box.data, engine.context(s, now: 0))
        guard let k = info.question?.korrekt else { return nil }
        return options.first { $0.text == k || $0.text.hasPrefix(k) }?.id
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
