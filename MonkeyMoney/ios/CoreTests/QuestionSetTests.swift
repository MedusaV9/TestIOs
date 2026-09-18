import XCTest
@testable import MonkeyMoneyCore

/// Question sets (Fragen-Set): presets, pool-aware votes and plans, and the
/// League Edition catalogue that contains nothing but Runeterra.
final class QuestionSetTests: XCTestCase {
    var catalog: ContentCatalog { TestContent.catalog }

    func testPresetsHaveQuestionsAndLeagueIsRuneterraOnly() {
        let infos = catalog.questionSetInfos(activePool: [], kidSafe: false)
        XCTAssertTrue(infos.contains { $0.id == "alle" && $0.aktiv && $0.anzahl == catalog.questions.count })
        let league = infos.first { $0.id == QuestionSets.leagueId }
        XCTAssertNotNil(league)
        XCTAssertGreaterThan(league?.anzahl ?? 0, 150)
        for q in catalog.questions(inPool: ["league_of_legends"]) { XCTAssertEqual(q.sub, "league_of_legends") }
        // Every listed preset can actually be played (has questions).
        for i in infos where i.id != QuestionSets.eigenId { XCTAssertGreaterThan(i.anzahl, 0, i.id) }
    }

    func testSettingsPatchAppliesPresetAndDetectsCustomPool() {
        var s = MatchSettings(modus: .klassik)
        s.apply(patch: ["fragenSet": .string("league")])
        XCTAssertEqual(s.kategorienPool, ["league_of_legends"])
        XCTAssertEqual(s.fragenSet, "league")
        s.apply(patch: ["kategorienPool": .array([.string("sport"), .string("musik")])])
        XCTAssertEqual(s.fragenSet, QuestionSets.eigenId)
        s.apply(patch: ["kategorienPool": .array([.string("gaming")])])
        XCTAssertEqual(s.fragenSet, "gaming", "a hand-picked pool that equals a preset reads as that preset")
        s.apply(patch: ["kategorienPool": .array([])])
        XCTAssertEqual(s.fragenSet, QuestionSets.alleId)
        // Mode switch keeps the pool.
        s.apply(patch: ["fragenSet": .string("league")])
        s.apply(patch: ["modus": .string("quick")])
        XCTAssertEqual(s.kategorienPool, ["league_of_legends"])
        XCTAssertEqual(s.modus, .quick)
    }

    func testCategoryVoteFollowsThePool() {
        // Whole catalogue: top-level categories.
        let all = catalog.categoriesWithSupply(schwierigkeiten: [.easy, .medium], used: [], minimum: 4)
        XCTAssertGreaterThanOrEqual(all.count, 10)
        // One top-level category: its sub-categories.
        let gaming = catalog.categoriesWithSupply(schwierigkeiten: [], used: [], minimum: 4, pool: ["gaming"])
        XCTAssertTrue(gaming.contains("league_of_legends"))
        XCTAssertTrue(gaming.contains("minecraft"))
        XCTAssertFalse(gaming.contains("gaming"))
        // A single sub-category: nothing to vote on → the engine skips the vote.
        let lol = catalog.categoriesWithSupply(schwierigkeiten: [], used: [], minimum: 4, pool: ["league_of_legends"])
        XCTAssertEqual(lol, ["league_of_legends"])
        XCTAssertEqual(catalog.categoryName("league_of_legends"), "League of Legends")
        XCTAssertEqual(catalog.categoryEmoji("league_of_legends"), "🎮")
    }

    func testPlanFallsBackToFormatsThePoolCanServe() {
        var league = MatchSettings(modus: .klassik)
        league.applyQuestionSet("league")
        let plan = Plan.build(settings: league, playerCount: 4, catalog: catalog)
        let ids = plan.map { $0.minigameId }
        XCTAssertFalse(ids.contains("pixel-dschungel"), "no picture riddles in Runeterra → Vier Lianen instead")
        XCTAssertTrue(ids.contains("bananen-tresor"), "LoL has estimate questions")
        XCTAssertTrue(ids.contains("affenbank"))
        // The League Edition catalogue: only LoL questions, no songs → music formats fall back too.
        let edition = catalog.filtered(pool: ["league_of_legends"])
        XCTAssertEqual(edition.questions.count, catalog.questions(inPool: ["league_of_legends"]).count)
        XCTAssertTrue(edition.songs.isEmpty)
        var marathon = MatchSettings(modus: .marathon)
        marathon.applyQuestionSet("league")
        let mplan = Plan.build(settings: marathon, playerCount: 4, catalog: edition)
        XCTAssertFalse(mplan.contains { ["song-snippet", "song-rueckwaerts", "musikvideo-raten", "wer-singts", "pixel-dschungel"].contains($0.minigameId) })
        XCTAssertGreaterThan(mplan.count, 10)
    }

    func testLeagueOnlyShowRunsToTheEndWithOnlyLeagueQuestions() {
        let r = SimHarness.run(modus: .quick, players: 3, seed: 77) { s in s.applyQuestionSet("league") }
        XCTAssertEqual(r.state.phase, .ende)
        for id in r.state.usedQuestionIds {
            let q = catalog.question(id)
            XCTAssertEqual(q?.sub, "league_of_legends", "\(id) is not a League question")
        }
        XCTAssertGreaterThan(r.state.usedQuestionIds.count, 8)
    }

    func testGmViewCarriesSetsAndCategoryTree() {
        let engine = Engine(catalog: catalog)
        var s = EngineState(matchId: "m", roomCode: "ABCD", seed: 1, settings: MatchSettings(modus: .quick), now: 0, gmPin: "0000")
        engine.reduce(&s, .gm(.settingsSet(["fragenSet": .string("gaming")])), now: 0)
        let g = engine.gmView(s, now: 0, joinURL: "", gmURL: "")
        XCTAssertTrue(g.fragenSets.first { $0.id == "gaming" }?.aktiv ?? false)
        let gaming = g.kategorien.first { $0.id == "gaming" }
        XCTAssertNotNil(gaming)
        XCTAssertTrue(gaming?.gewaehlt ?? false)
        XCTAssertTrue(gaming?.unter.contains { $0.id == "league_of_legends" && $0.anzahl > 100 } ?? false)
        XCTAssertFalse(g.kategorien.first { $0.id == "sport" }?.gewaehlt ?? true)
        XCTAssertTrue(g.poolInfo.contains("Gaming"))
        XCTAssertTrue(g.lobbyOnlySettings.contains("modus"))
        // Mid-match the pool may change, the mode may not.
        engine.reduce(&s, .join(playerId: "a", name: "A", avatar: Avatar(), profileId: nil, isBot: true), now: 0)
        engine.reduce(&s, .join(playerId: "b", name: "B", avatar: Avatar(), profileId: nil, isBot: true), now: 0)
        engine.reduce(&s, .gm(.flowNext), now: 0)
        XCTAssertEqual(s.phase, .intro)
        engine.reduce(&s, .gm(.settingsSet(["fragenSet": .string("sport")])), now: 1)
        XCTAssertEqual(s.settings.kategorienPool, ["sport"])
        engine.reduce(&s, .gm(.settingsSet(["modus": .string("marathon")])), now: 1)
        XCTAssertEqual(s.settings.modus, .quick)
    }
}
