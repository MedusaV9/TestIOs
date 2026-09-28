import XCTest
@testable import MonkeyMoneyCore

/// The four new show modes (Blitz, Party, Quiz-Profi, Eigene Show), the
/// hand-built playlist and the "👍 Weiter" skip vote of the waiting phases.
final class ShowModesTests: XCTestCase {
    var catalog: ContentCatalog { TestContent.catalog }

    /// Per-round payouts of a whole bot match (positive deltas per section).
    func payouts(_ modus: Modus, players: Int, seed: UInt32, patch: ((inout MatchSettings) -> Void)? = nil) -> (state: EngineState, paid: [Int: Int]) {
        var paid: [Int: Int] = [:]
        var last: Phase?
        let r = SimHarness.run(modus: modus, players: players, seed: seed, settingsPatch: patch, maxTicks: 400_000) { s, _ in
            if s.phase == .aufloesung, last != .aufloesung, s.currentSection?.typ == .runde {
                paid[s.sectionIndex, default: 0] += s.lastDeltas.values.filter { $0 > 0 }.reduce(0, +)
            }
            last = s.phase
        }
        return (r.state, paid)
    }

    func testNewModesPlayToTheEndAndNoRoundDominates() {
        for (modus, players) in [(Modus.blitz, 2), (.blitz, 8), (.party, 4), (.profi, 4), (.eigen, 3)] {
            let (s, paid) = payouts(modus, players: players, seed: 5)
            XCTAssertEqual(s.phase, .ende, "\(modus) \(players)p stuck in \(s.phase)")
            let rounds = s.plan.filter { $0.typ == .runde }
            XCTAssertEqual(rounds.map(\.minigameId), Blueprints.rounds(for: s.settings).map(\.minigameId),
                           "\(modus): the playlist formats run as planned (no fallback to Vier Lianen)")
            let totals = paid.values.map(Double.init).sorted()
            guard !totals.isEmpty else { XCTFail("\(modus): nothing paid"); continue }
            let median = totals[totals.count / 2]
            for (i, v) in paid { XCTAssertLessThanOrEqual(Double(v), median * 1.9 + 300, "\(modus) round \(s.plan[i].minigameId) pays \(v) vs median \(median)") }
            print("MODES \(modus) \(players)p rounds \(rounds.map(\.minigameId)) paid \(paid.sorted { $0.key < $1.key }.map(\.value)) winner \(s.ranking.first?.balance ?? 0)")
        }
    }

    func testModeDefaultsAndDurations() {
        let blitz = MatchSettings(modus: .blitz)
        XCTAssertEqual(blitz.tempo, .zackig)
        XCTAssertFalse(blitz.radAn)
        XCTAssertTrue(blitz.kurzeShow)
        XCTAssertLessThanOrEqual(Plan.estimateMinutes(settings: blitz), 15, "Blitz is a ~10 minute show")
        let profi = MatchSettings(modus: .profi)
        XCTAssertEqual(profi.fragenMix, .knifflig)
        XCTAssertFalse(profi.radAn)
        XCTAssertTrue(Blueprints.blueprint(for: profi).jackpotFrage)
        XCTAssertTrue(Plan.build(settings: profi, playerCount: 4, catalog: catalog).contains { $0.typ == .jackpot })
        for m in Modus.allCases {
            let s = MatchSettings(modus: m)
            XCTAssertFalse(Blueprints.rounds(for: s).isEmpty, "\(m)")
            XCTAssertFalse(m.title.isEmpty || m.subtitle.isEmpty || m.emoji.isEmpty)
            let minutes = Plan.estimateMinutes(settings: s)
            XCTAssertTrue((5...180).contains(minutes), "\(m): \(minutes) min")
        }
        // Old saves keep decoding; the mode round-trips.
        for m in Modus.allCases {
            let back = try? JSONDecoder().decode(MatchSettings.self, from: JSONEncoder().encode(MatchSettings(modus: m)))
            XCTAssertEqual(back?.modus, m)
        }
    }

    func testEigenePlaylistPatchPlanAndJackpot() {
        var s = MatchSettings(modus: .klassik)
        s.apply(patch: ["modus": .string("eigen")])
        XCTAssertEqual(s.modus, .eigen)
        // Empty playlist = the Klassik playlist.
        XCTAssertEqual(Blueprints.rounds(for: s).map(\.minigameId), Blueprints.blueprint(for: .klassik).runden.map(\.minigameId))
        s.apply(patch: ["eigenePlaylist": .array([
            .object(["id": .string("affenzahn"), "fragen": .number(99)]),
            .string("herdentrieb"),
            .string("gibts-nicht"),
            .string("lianen-finale"),
            .object(["id": .string("bananen-tresor"), "fragen": .number(0)]),
            .string("letzter-affe"),
        ])])
        XCTAssertEqual(s.eigenePlaylist, [PlaylistItem(id: "affenzahn", fragen: 12), PlaylistItem(id: "herdentrieb", fragen: 5),
                                          PlaylistItem(id: "bananen-tresor", fragen: 1), PlaylistItem(id: "letzter-affe", fragen: 10)],
                       "unknown ids and the fixed finale are dropped, counts clamped to 1…12, defaults from the format")
        let plan = Plan.build(settings: s, playerCount: 4, catalog: catalog)
        XCTAssertEqual(plan.filter { $0.typ == .runde }.map(\.minigameId), ["affenzahn", "herdentrieb", "bananen-tresor", "letzter-affe"])
        XCTAssertEqual(plan.filter { $0.typ == .runde }.first?.kategorieWahl, .keine, "the opener starts right away")
        XCTAssertEqual(plan.last?.typ, .finale)
        let jackpot = plan.firstIndex { $0.typ == .jackpot }
        XCTAssertNotNil(jackpot)
        XCTAssertEqual(plan[jackpot! + 1].minigameId, "letzter-affe", "the jackpot comes right before the last (risk) round")
        s.apply(patch: ["eigenerJackpot": .bool(false)])
        XCTAssertFalse(Plan.build(settings: s, playerCount: 4, catalog: catalog).contains { $0.typ == .jackpot })
        // At most 12 rounds; the playlist survives a mode switch and back.
        s.apply(patch: ["eigenePlaylist": .array(Array(repeating: .string("bananen-basics"), count: 20))])
        XCTAssertEqual(s.eigenePlaylist.count, Blueprints.eigenMaxRunden)
        s.apply(patch: ["modus": .string("quick")])
        s.apply(patch: ["modus": .string("eigen")])
        XCTAssertEqual(s.eigenePlaylist.count, Blueprints.eigenMaxRunden)
        XCTAssertTrue(Engine.lobbyOnlySettings.contains("eigenePlaylist"))
        // A long hand-built show gets a halftime.
        XCTAssertEqual(Blueprints.blueprint(for: s).halbzeitNach, 6)
    }

    func testWeiterVoteShortensTheStandings() {
        let engine = Engine(catalog: catalog)
        var settings = MatchSettings(modus: .quick)
        settings.tempo = .normal
        var s = EngineState(matchId: "w", roomCode: "WEIT", seed: 3, settings: settings, now: 0, gmPin: "1111")
        for i in 0..<3 { engine.reduce(&s, .join(playerId: "p\(i)", name: "P\(i)", avatar: Avatar(), profileId: nil, isBot: false), now: 0) }
        engine.reduce(&s, .join(playerId: "bot", name: "Bot", avatar: Avatar(), profileId: nil, isBot: true), now: 0)
        engine.reduce(&s, .gm(.flowNext), now: 0)
        var now: Millis = 0
        while s.phase != .zwischenstand && now < 900_000 {
            now += 250
            engine.tick(&s, now: now)
            if s.phase == .frage { engine.reduce(&s, .gm(.flowNext), now: now) }
        }
        XCTAssertEqual(s.phase, .zwischenstand)
        let end = s.phaseEndsAt!
        XCTAssertGreaterThan(end, now + 3000)
        XCTAssertEqual(engine.playerView(s, player: "p0", now: now)?.weiter, WeiterInfo(done: false, anzahl: 0, noetig: 3, spieler: []), "bots don't vote")
        engine.reduce(&s, .player("p0", .ready("weiter")), now: now)
        engine.reduce(&s, .player("p1", .ready("weiter")), now: now)
        XCTAssertEqual(s.phaseEndsAt, end, "not everybody yet")
        XCTAssertEqual(engine.playerView(s, player: "p0", now: now)?.weiter?.done, true)
        XCTAssertEqual(engine.stageView(s, now: now, joinURL: "", gmURL: "").weiter?.anzahl, 2)
        // Changing your mind takes the vote back.
        engine.reduce(&s, .player("p1", .ready("weiter")), now: now)
        XCTAssertEqual(engine.playerView(s, player: "p1", now: now)?.weiter?.done, false)
        engine.reduce(&s, .player("p1", .ready("weiter")), now: now)
        engine.reduce(&s, .player("p2", .ready("weiter")), now: now)
        XCTAssertEqual(s.phaseEndsAt, now + 1500)
        XCTAssertTrue(s.moments.contains { $0.text.contains("Alle wollen weiter") })
        // The next phase starts without votes.
        while s.phase == .zwischenstand { now += 250; engine.tick(&s, now: now) }
        XCTAssertTrue(s.bereit.isEmpty)
        XCTAssertNil(engine.playerView(s, player: "p0", now: now)?.weiter.flatMap { $0.done ? $0 : nil })
    }
}
