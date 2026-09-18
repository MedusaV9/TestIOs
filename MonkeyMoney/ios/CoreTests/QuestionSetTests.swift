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
        XCTAssertGreaterThanOrEqual(league?.anzahl ?? 0, 2500, "the League pack promises at least 2500 questions")
        let lol = catalog.questions(inPool: QuestionSets.leaguePool)
        for q in lol { XCTAssertTrue(QuestionSets.leaguePool.contains(q.sub), q.id) }
        // Every difficulty is well stocked — von leicht bis ULTRAHARD.
        for d in Difficulty.allCases { XCTAssertGreaterThanOrEqual(lol.filter { $0.schw == d }.count, 300, "\(d)") }
        // Every sub-category and the main formats are represented.
        for sub in QuestionSets.leaguePool { XCTAssertGreaterThan(lol.filter { $0.sub == sub }.count, 50, sub) }
        for t in [QuestionType.choice, .wahrFalsch, .schaetz, .sortier, .mehrfach] { XCTAssertGreaterThan(lol.filter { $0.typ == t }.count, 10, "\(t)") }
        // No duplicate texts, every choice has exactly one correct option inside range.
        XCTAssertEqual(Set(lol.map { $0.text }).count, lol.count)
        for q in lol where q.typ == .choice { XCTAssertTrue(q.choiceOptions.indices.contains(q.correctIndex ?? -1), q.id); XCTAssertEqual(Set(q.choiceOptions).count, q.choiceOptions.count, q.id) }
        // Every listed preset can actually be played (has questions).
        for i in infos where i.id != QuestionSets.eigenId { XCTAssertGreaterThan(i.anzahl, 0, i.id) }
    }

    func testSettingsPatchAppliesPresetAndDetectsCustomPool() {
        var s = MatchSettings(modus: .klassik)
        s.apply(patch: ["fragenSet": .string("league")])
        XCTAssertEqual(s.kategorienPool, QuestionSets.leaguePool)
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
        XCTAssertEqual(s.kategorienPool, QuestionSets.leaguePool)
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
        XCTAssertEqual(catalog.categoryName("league_of_legends"), "LoL · Allgemein")
        XCTAssertEqual(catalog.categoryEmoji("league_of_legends"), "⚔️")
        // The League pool has six subs → a real vote (Champions vs. Lore vs. Esports …).
        let league = catalog.categoriesWithSupply(schwierigkeiten: [.easy, .medium], used: [], minimum: 4, pool: QuestionSets.leaguePool)
        XCTAssertEqual(Set(league), Set(QuestionSets.leaguePool))
        XCTAssertEqual(catalog.categoryName("lol_champions"), "LoL · Champions & Fähigkeiten")
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
        let edition = catalog.filtered(pool: QuestionSets.leaguePool)
        XCTAssertEqual(edition.questions.count, catalog.questions(inPool: QuestionSets.leaguePool).count)
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
            XCTAssertTrue(QuestionSets.leaguePool.contains(q?.sub ?? ""), "\(id) is not a League question")
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
