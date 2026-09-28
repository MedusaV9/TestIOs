import XCTest
@testable import MonkeyMoneyCore

/// Fine-grained question filter: categories/subs, tiers, types and single
/// questions switched off — in the pickers, the vote, a whole match, the
/// catalogue counts and the settings patch / save format.
final class QuestionFilterTests: XCTestCase {
    var catalog: ContentCatalog { TestContent.catalog }

    func testSubExclusionInsideIncludedParentAndTopExclusion() {
        let filter = QuestionFilter(kategorien: ["minecraft"])
        let gaming = catalog.candidates(PickOptions(anzahl: 1, kategorien: ["gaming"], allowAdult: true, filter: filter))
        XCTAssertFalse(gaming.isEmpty)
        XCTAssertFalse(gaming.contains { $0.sub == "minecraft" }, "an excluded sub stays out even though its parent is in the pool")
        XCTAssertTrue(gaming.contains { $0.sub == "league_of_legends" })
        let all = catalog.candidates(PickOptions(anzahl: 1, allowAdult: true, filter: QuestionFilter(kategorien: ["gaming"])))
        XCTAssertFalse(all.contains { $0.kat == "gaming" }, "an excluded top category excludes all its subs")
        XCTAssertEqual(catalog.questions(inPool: ["gaming"], filter: filter).count,
                       catalog.questions(inPool: ["gaming"]).count - catalog.questions.filter { $0.sub == "minecraft" }.count)
    }

    func testSingleIdBanAndTypeCounts() {
        let q = catalog.questions.first { $0.typ == .choice && !$0.isAdultOnly }!
        let opts = PickOptions(anzahl: 1, kategorien: [q.sub], allowAdult: true, filter: QuestionFilter(ids: [q.id]))
        XCTAssertFalse(catalog.candidates(opts).contains { $0.id == q.id })
        let counts = catalog.typeCounts(pool: [], filter: QuestionFilter(typen: [.schaetz, .sortier]))
        XCTAssertNil(counts[.schaetz])
        XCTAssertNil(counts[.sortier])
        XCTAssertGreaterThan(counts[.choice] ?? 0, 100)
        // Plan gating follows the filter: no estimates → the Tresor falls back.
        var s = MatchSettings(modus: .klassik)
        s.typenAus = [.schaetz]
        XCTAssertFalse(Plan.build(settings: s, playerCount: 4, catalog: catalog).contains { $0.minigameId == "bananen-tresor" })
    }

    func testTiersMapToNearestEnabled() {
        let f = QuestionFilter(schwierigkeiten: [.easy, .medium])
        XCTAssertEqual(f.tiers([.easy, .medium]), [.hard])
        XCTAssertEqual(f.tiers([.medium, .hard]), [.hard])
        XCTAssertEqual(QuestionFilter(schwierigkeiten: [.hard, .ultrahard]).tiers([.hard, .ultrahard]), [.medium])
        XCTAssertEqual(QuestionFilter(schwierigkeiten: [.medium]).tiers([.medium]), [.easy, .hard])
        XCTAssertEqual(QuestionFilter.none.tiers([.hard]), [.hard])
    }

    func testDisabledTiersTypesAndCategoriesNeverDrawnInAFullMatch() {
        var voteOptions: Set<String> = []
        let r = SimHarness.run(modus: .quick, players: 3, seed: 11, settingsPatch: { s in
            s.schwierigkeitenAus = [.easy, .ultrahard]
            s.typenAus = [.wahrFalsch, .emoji]
            s.kategorienAus = ["sport", "musik"]
        }, observe: { s, _ in
            if s.phase == .kategorieWahl { voteOptions.formUnion(s.kategorie.optionen) }
        })
        XCTAssertEqual(r.state.phase, .ende)
        XCTAssertGreaterThan(r.state.usedQuestionIds.count, 8)
        for id in r.state.usedQuestionIds {
            guard let q = catalog.question(id) else { continue }
            XCTAssertFalse([Difficulty.easy, .ultrahard].contains(q.schw), "\(id) has a disabled tier \(q.schw)")
            XCTAssertFalse([QuestionType.wahrFalsch, .emoji].contains(q.typ), "\(id) has a disabled type")
            XCTAssertFalse(["sport", "musik"].contains(q.kat), "\(id) is in a disabled category")
        }
        XCTAssertFalse(voteOptions.contains("sport") || voteOptions.contains("musik"), "vote offered a disabled category: \(voteOptions)")
        XCTAssertFalse(r.state.moments.contains { $0.text.contains("Filter zu streng") })
    }

    func testCategoryVoteExcludesDisabled() {
        let filter = QuestionFilter(kategorien: ["sport", "geschichte"])
        let all = catalog.categoriesWithSupply(schwierigkeiten: [.medium], used: [], minimum: 4, filter: filter)
        XCTAssertFalse(all.contains("sport") || all.contains("geschichte"))
        XCTAssertGreaterThanOrEqual(all.count, 8)
        let gaming = catalog.categoriesWithSupply(schwierigkeiten: [], used: [], minimum: 4, pool: ["gaming"], filter: QuestionFilter(kategorien: ["minecraft"]))
        XCTAssertFalse(gaming.contains("minecraft"))
        XCTAssertTrue(gaming.contains("league_of_legends"))
        let league = catalog.categoriesWithSupply(schwierigkeiten: [], used: [], minimum: 4, pool: QuestionSets.leaguePool, filter: QuestionFilter(kategorien: ["lol_lore"]))
        XCTAssertEqual(Set(league), Set(QuestionSets.leaguePool).subtracting(["lol_lore"]))
    }

    func testSettingsPatchRulesAndModeCarryOver() {
        var s = MatchSettings(modus: .klassik)
        s.apply(patch: ["schwierigkeitenAus": .array([.string("easy"), .string("quatsch")]), "typenAus": .array([.string("schaetz")]),
                        "kategorienAus": .array([.string("sport"), .string("sport")]), "fragenAus": .array([.string("q1")])])
        XCTAssertEqual(s.schwierigkeitenAus, [.easy], "unknown tiers are dropped")
        XCTAssertEqual(s.typenAus, [.schaetz])
        XCTAssertEqual(s.kategorienAus, ["sport"])
        XCTAssertEqual(s.fragenAus, ["q1"])
        // All four tiers off is rejected.
        s.apply(patch: ["schwierigkeitenAus": .array(Difficulty.allCases.map { .string($0.rawValue) })])
        XCTAssertEqual(s.schwierigkeitenAus, [.easy])
        // All types off keeps the choice questions.
        s.apply(patch: ["typenAus": .array(QuestionType.allCases.map { .string($0.rawValue) })])
        XCTAssertFalse(s.typenAus.contains(.choice))
        XCTAssertEqual(s.typenAus.count, QuestionType.allCases.count - 1)
        // Single toggles.
        s.apply(patch: ["kategorieAus": .string("musik")])
        XCTAssertEqual(s.kategorienAus, ["sport", "musik"])
        s.apply(patch: ["kategorieAn": .string("sport")])
        XCTAssertEqual(s.kategorienAus, ["musik"])
        // Mode switch keeps the filter; reset clears it.
        s.apply(patch: ["modus": .string("quick")])
        XCTAssertEqual(s.modus, .quick)
        XCTAssertEqual(s.kategorienAus, ["musik"])
        XCTAssertEqual(s.schwierigkeitenAus, [.easy])
        XCTAssertEqual(s.fragenAus, ["q1"])
        s.apply(patch: ["filterReset": .bool(true)])
        XCTAssertTrue(s.questionFilter.isEmpty)
    }

    func testOldSaveWithoutFilterKeysDecodes() throws {
        var settings = MatchSettings(modus: .marathon)
        settings.kategorienPool = ["gaming"]
        settings.timerAus = true
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as! [String: Any]
        for k in ["kategorienAus", "schwierigkeitenAus", "typenAus", "fragenAus"] { XCTAssertNotNil(json.removeValue(forKey: k)) }
        let back = try JSONDecoder().decode(MatchSettings.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(back, settings)
        XCTAssertTrue(back.questionFilter.isEmpty)
        // A whole engine state from before the reveal fields still loads.
        var state = EngineState(matchId: "m", roomCode: "ABCD", seed: 3, settings: settings, now: 0, gmPin: "1111")
        state.lastReveal = nil
        var stateJson = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as! [String: Any]
        var sj = stateJson["settings"] as! [String: Any]
        sj.removeValue(forKey: "fragenAus")
        stateJson["settings"] = sj
        stateJson.removeValue(forKey: "rundenStartBalance")
        let loaded = try JSONDecoder().decode(EngineState.self, from: JSONSerialization.data(withJSONObject: stateJson))
        XCTAssertEqual(loaded.settings.kategorienPool, ["gaming"])
        // Round trip with filter values.
        settings.schwierigkeitenAus = [.ultrahard]
        settings.typenAus = [.sortier]
        XCTAssertEqual(try JSONDecoder().decode(MatchSettings.self, from: JSONEncoder().encode(settings)), settings)
    }

    func testCatalogCountsAreConsistent() {
        var s = MatchSettings(modus: .klassik)
        let plain = catalog.katalogInfo(settings: s)
        XCTAssertEqual(plain.gesamt, catalog.questions.count)
        XCTAssertEqual(plain.aktiv, catalog.questions.count)
        XCTAssertTrue(plain.kategorien.allSatisfy { $0.gewaehlt && $0.unter.allSatisfy { $0.gewaehlt } }, "empty pool = everything chosen, subs too")
        s.schwierigkeitenAus = [.ultrahard]
        s.typenAus = [.sortier]
        s.fragenAus = [catalog.questions[0].id]
        let k = catalog.katalogInfo(settings: s)
        XCTAssertEqual(k.fragenAus, 1)
        XCTAssertEqual(k.aktiv, k.schwierigkeiten.reduce(0) { $0 + $1.aktiv })
        XCTAssertEqual(k.aktiv, k.kategorien.reduce(0) { $0 + $1.aktiv })
        XCTAssertEqual(k.aktiv, k.typen.reduce(0) { $0 + $1.aktiv })
        XCTAssertEqual(k.schwierigkeiten.first { $0.id == "ultrahard" }?.aus, true)
        XCTAssertEqual(k.schwierigkeiten.first { $0.id == "ultrahard" }?.aktiv, 0)
        XCTAssertEqual(k.schwierigkeiten.map(\.name), ["Leicht", "Mittel", "Schwer", "ULTRAHARD"])
        XCTAssertEqual(k.typen.first { $0.id == "sortier" }?.name, "Sortieren")
        XCTAssertEqual(k.typen.first { $0.id == "sortier" }?.aus, true)
        for c in k.kategorien {
            // Per-tier counts ignore the tier switch; the enabled ones add up to `aktiv`.
            let enabled = c.proSchwierigkeit.filter { $0.key != "ultrahard" }.values.reduce(0, +)
            XCTAssertEqual(enabled, c.aktiv, c.id)
            XCTAssertLessThanOrEqual(c.aktiv, c.anzahl)
        }
        // Switching a category off: flagged and gone from the drawable total.
        s.kategorienAus = ["sport", "lol_lore"]
        let k2 = catalog.katalogInfo(settings: s)
        let sport = k2.kategorien.first { $0.id == "sport" }!
        XCTAssertTrue(sport.aus)
        XCTAssertTrue(k2.kategorien.first { $0.id == "gaming" }!.unter.first { $0.id == "lol_lore" }!.aus)
        XCTAssertFalse(k2.kategorien.first { $0.id == "gaming" }!.aus)
        let lore = k2.kategorien.first { $0.id == "gaming" }!.unter.first { $0.id == "lol_lore" }!
        XCTAssertEqual(k2.aktiv, k.aktiv - sport.aktiv - lore.aktiv)
        // GM view carries the catalogue.
        let engine = Engine(catalog: catalog)
        var st = EngineState(matchId: "m", roomCode: "ABCD", seed: 1, settings: s, now: 0, gmPin: "0000")
        engine.reduce(&st, .gm(.settingsSet(["kategorieAus": .string("musik")])), now: 0)
        let g = engine.gmView(st, now: 0, joinURL: "", gmURL: "")
        XCTAssertEqual(g.katalog?.kategorien.first { $0.id == "musik" }?.aus, true)
        XCTAssertTrue(st.moments.contains { $0.text.contains("Fragen-Filter") })
    }
}
