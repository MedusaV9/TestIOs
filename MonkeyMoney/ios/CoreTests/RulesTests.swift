import XCTest
@testable import MonkeyMoneyCore

final class RulesTests: XCTestCase {
    func testContentBundleLoads() {
        let c = TestContent.catalog
        XCTAssertGreaterThanOrEqual(c.questions.count, 7000)
        XCTAssertEqual(c.categories.count, 14)
        XCTAssertGreaterThanOrEqual(c.songs.count, 50)
        XCTAssertGreaterThanOrEqual(c.songs.filter { $0.hatVideo }.count, 40)
        XCTAssertEqual(c.questions.filter { $0.typ == .bildPixel }.count, 12)
        // Every choice question has a valid correct index.
        for q in c.questions where q.typ.isChoiceLike {
            XCTAssertNotNil(q.correctIndex, q.id)
            XCTAssertTrue(q.choiceOptions.indices.contains(q.correctIndex ?? -1), q.id)
        }
        for q in c.questions where q.typ == .sortier {
            XCTAssertEqual(q.elemente?.count, q.reihenfolge?.count, q.id)
        }
    }

    func testPickHonoursCategoryAndDifficulty() {
        var rng = SeededRandom(seed: 1)
        let qs = TestContent.catalog.pick(PickOptions(anzahl: 20, kategorien: ["sport"], schwierigkeiten: [.easy], typen: [.choice]), rng: &rng)
        XCTAssertEqual(qs.count, 20)
        XCTAssertTrue(qs.allSatisfy { $0.kat == "sport" && $0.schw == .easy && $0.typ == .choice })
        XCTAssertEqual(Set(qs.map { $0.id }).count, 20)
    }

    func testFragenMixLockerIsEasier() {
        var rngA = SeededRandom(seed: 3), rngB = SeededRandom(seed: 3)
        let locker = TestContent.catalog.pick(PickOptions(anzahl: 300, schwierigkeiten: [.easy, .medium, .hard, .ultrahard], typen: [.choice], mix: .locker), rng: &rngA)
        let knifflig = TestContent.catalog.pick(PickOptions(anzahl: 300, schwierigkeiten: [.easy, .medium, .hard, .ultrahard], typen: [.choice], mix: .knifflig), rng: &rngB)
        let easyShareA = Double(locker.filter { $0.schw == .easy }.count) / 300
        let easyShareB = Double(knifflig.filter { $0.schw == .easy }.count) / 300
        XCTAssertGreaterThan(easyShareA, easyShareB + 0.15)
    }

    func testEconomyFormulas() {
        XCTAssertEqual(Economy.streakFactor(2), 1.0)
        XCTAssertEqual(Economy.streakFactor(3), 1.5)
        XCTAssertEqual(Economy.streakFactor(5), 2.0)
        XCTAssertEqual(Economy.streakFactor(9), 2.0)
        XCTAssertEqual(Economy.tailwindFactor(own: 100, leader: 1000), 1.5)
        XCTAssertEqual(Economy.tailwindFactor(own: 500, leader: 1000), 1.25)
        XCTAssertEqual(Economy.tailwindFactor(own: 900, leader: 1000), 1.0)
        // Example from GAME-DESIGN §3.5: 6.800 vs 2.700, Q=5 ⇒ 1.050.
        XCTAssertEqual(Economy.wFinal(gap: 4100, q: 5), 1050)
        XCTAssertEqual(Economy.wFinal(gap: 0, q: 5), 500)
        XCTAssertEqual(Economy.finaleDelta(correct: false, w: 1050), -525)
        XCTAssertEqual(Economy.allTimeFor(finalBalance: 10_000, isWinner: true), 1500)
        XCTAssertEqual(Economy.allTimeFor(finalBalance: 200, isWinner: false), 50)
        XCTAssertEqual(Economy.socialDiscount(place: 4, players: 4), 0.5)
        XCTAssertEqual(Economy.socialDiscount(place: 3, players: 4), 0.7)
        XCTAssertEqual(Economy.socialDiscount(place: 1, players: 4), 1.0)
        XCTAssertEqual(Level.level(forAT: 15_000), 5)
        XCTAssertEqual(Level.level(forAT: 999), 0)
    }

    func testJokerPrices() {
        XCTAssertEqual(Jokers.price(Jokers.def(.bananenSplit), questionValue: 250, balance: 1000), 100)
        XCTAssertEqual(Jokers.price(Jokers.def(.schmiergeld), questionValue: 1000, balance: 0, stufe: 2), 350)
        XCTAssertEqual(Jokers.price(Jokers.def(.bananentresor), questionValue: 250, balance: 5000), 500)
        XCTAssertEqual(Jokers.price(Jokers.def(.bananentresor), questionValue: 250, balance: 100), 100) // floor
        XCTAssertEqual(Jokers.price(Jokers.def(.goldeneBanane), questionValue: 250, balance: 100), 0)
    }

    func testWheelWeightsAndFairFinale() {
        XCTAssertEqual(Wheel.segments.filter { $0.id != .shotOderSchotter }.reduce(0) { $0 + $1.gewicht }, 100)
        let fair = Wheel.compatible(Wheel.Context(fairFinale: true, nextIsMcQuestion: true, lastSegment: nil, spinsWithoutGold: 0, playerCount: 4))
        XCTAssertEqual(Set(fair.map { $0.id }), [.doppelterZaster, .halbeMiete, .bananaBailout, .insiderTipp, .umarmungsBonus, .blackout])
        var rng = SeededRandom(seed: 12)
        var lastId: WheelSegmentId? = nil
        var gold = 0
        for _ in 0..<2000 {
            let spin = Wheel.spin(Wheel.Context(fairFinale: false, nextIsMcQuestion: true, lastSegment: lastId, spinsWithoutGold: 0, playerCount: 4), rng: &rng)
            let picked = spin.face[spin.resultIndex]
            XCTAssertNotEqual(picked.id, lastId, "Pech-Schutz: never the same segment twice in a row")
            XCTAssertLessThanOrEqual(spin.face.count, 10)
            if picked.klasse == .gold { gold += 1 }
            lastId = picked.id
        }
        XCTAssertGreaterThan(gold, 100)
        XCTAssertLessThan(gold, 400)
    }

    func testSeededRandomIsDeterministicAndSerialisable() throws {
        var a = SeededRandom(seed: 77)
        let data = try JSONEncoder().encode(a)
        var b = try JSONDecoder().decode(SeededRandom.self, from: data)
        for _ in 0..<50 { XCTAssertEqual(a.next(), b.next()) }
        let shuffled = a.shuffled(Array(1...20))
        XCTAssertEqual(Set(shuffled), Set(1...20))
    }

    func testPlanQuickKlassikMarathon() {
        let quick = Plan.build(settings: MatchSettings(modus: .quick), playerCount: 3, songs: TestContent.catalog.songs)
        XCTAssertEqual(quick.map { $0.minigameId }, ["bananen-basics", "kokosnuss-uhr", "affenbank", "alles-oder-banane", "lianen-finale"])
        let klassik = Plan.build(settings: MatchSettings(modus: .klassik), playerCount: 4, songs: TestContent.catalog.songs)
        XCTAssertEqual(klassik.filter { $0.typ == .jackpot }.count, 1)
        XCTAssertEqual(klassik.firstIndex { $0.typ == .jackpot }, klassik.firstIndex { $0.slot == .risiko })
        var noV2 = MatchSettings(modus: .marathon)
        noV2.v2Formate = false
        let marathon = Plan.build(settings: noV2, playerCount: 4, songs: [])
        XCTAssertFalse(marathon.contains { MinigameRegistry.plugin($0.minigameId)?.meta.v2 == true })
        // Without songs the music formats fall back to Vier Lianen.
        let noSongs = Plan.build(settings: MatchSettings(modus: .marathon), playerCount: 4, songs: [])
        XCTAssertFalse(noSongs.contains { $0.minigameId == "song-rueckwaerts" })
    }

    func testSettingsPatchWhitelist() {
        var s = MatchSettings(modus: .klassik)
        s.apply(patch: ["tempo": .string("zackig"), "gmLos": .bool(true), "autoGm": .bool(false), "bogus": .string("x"), "finaleFaktor": .number(1.5)])
        XCTAssertEqual(s.tempo, .zackig)
        XCTAssertTrue(s.autoGm, "gmLos forces autoGm")
        XCTAssertEqual(s.finaleFaktor, 1.5)
        s.apply(patch: ["modus": .string("quick")])
        XCTAssertEqual(s.modus, .quick)
        XCTAssertFalse(s.jokerAn)
        XCTAssertTrue(s.gmLos, "room mode survives a mode switch")
    }

    func testAvatarWire() {
        let a = Avatar(wire: "don-bananas.gelb.hut-zylinder+lv7")
        XCTAssertEqual(a.affe, "don-bananas")
        XCTAssertEqual(a.farbe, "gelb")
        XCTAssertEqual(a.extras, ["hut-zylinder", "lv7"])
        XCTAssertEqual(a.wire, "don-bananas.gelb.hut-zylinder+lv7")
        XCTAssertEqual(Avatar(wire: "").affe, "don-bananas")
    }

    func testMinigameRegistryHasAllTwentySevenFormats() {
        XCTAssertEqual(MinigameRegistry.all.count, 28)
        XCTAssertEqual(Set(MinigameRegistry.all.map { $0.meta.id }).count, 28)
        XCTAssertEqual(BoardgameRegistry.all.count, 6)
    }
}
