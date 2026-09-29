import XCTest
@testable import MonkeyMoneyCore

/// Pixel-Dschungel: the picture round always gets its pictures (from the
/// active pool), the money stair is anchored and the phone reports the
/// locked level; without pictures the plan swaps the format out.
final class PixelDschungelTests: XCTestCase {
    func testKlassikPixelRoundDrawsPictureRiddlesFirst() {
        var sawPixelRound = false
        var pictures = 0, total = 0
        let r = SimHarness.run(modus: .klassik, players: 3, seed: 5, maxTicks: 400_000) { s, _ in
            guard s.phase == .frage, s.minigame?.id == "pixel-dschungel", s.currentQuestionIds.indices.contains(s.questionIndex) else { return }
            sawPixelRound = true
        }
        XCTAssertTrue(sawPixelRound, "Klassik has a Pixel-Dschungel round")
        // Every question the pixel section drew is a picture riddle (12 exist, 4 needed).
        for sec in r.state.plan where sec.minigameId == "pixel-dschungel" {
            XCTAssertEqual(sec.kategorieWahl, .keine, "no category vote before the picture round")
        }
        let used = r.state.usedQuestionIds.compactMap { TestContent.catalog.question($0) }
        for q in used where q.typ == .bildPixel { pictures += 1 }
        total = used.count
        XCTAssertGreaterThanOrEqual(pictures, 4, "the four pixel questions of the round are pictures (\(pictures)/\(total))")
    }

    func testMoneyStairAndLockedLevel() {
        let catalog = TestContent.catalog
        let q = catalog.questions.first { $0.typ == .bildPixel && $0.schw == .easy } ?? catalog.questions.first { $0.typ == .bildPixel }!
        var settings = MatchSettings(modus: .klassik)
        settings.tempo = .normal
        let section = Section(typ: .runde, slot: .aufbau, minigameId: "pixel-dschungel", fragen: 4, schwierigkeiten: [.easy], kategorieWahl: .keine, radDanach: false, rundenNummer: 1, kategorie: nil, notariat: false)
        var ctx = MinigameContext(now: 1000, rng: SeededRandom(seed: 1), settings: settings, players: ["a", "b"], names: ["a": "A", "b": "B"], balances: ["a": 0, "b": 0],
                                  connected: ["a", "b"], klauSchutz: [], mods: QuestionMods(), section: section, catalog: catalog)
        var st = PixelDschungel.initState(questions: [q], songs: [], ctx: &ctx)
        let stair = PixelDschungel.stair(st)
        XCTAssertEqual(stair.count, 9)
        XCTAssertEqual(stair.first, Economy.pixelLadder(value: Money.value(q.schw), steps: 8).start)
        XCTAssertEqual(stair.last, Economy.pixelLadder(value: Money.value(q.schw), steps: 8).floor)
        for i in 1..<stair.count { XCTAssertLessThanOrEqual(stair[i], stair[i - 1]) }
        // Level 0 at start, level 3 after 9 s (3-s steps), capped at 8.
        XCTAssertEqual(PixelDschungel.level(st, now: 1000), 0)
        XCTAssertEqual(PixelDschungel.level(st, now: 1000 + 9000), 3)
        XCTAssertEqual(PixelDschungel.level(st, now: 1000 + 60_000), 8)
        // A answers at level 3 → locked value is the stair at 3; the phone says so.
        ctx.now = 1000 + 9500
        PixelDschungel.reduce(&st, action: .choose(q.correctIndex ?? 0), from: "a", ctx: &ctx)
        XCTAssertEqual(st.levelAt["a"], 3)
        if case .idle(let title, let subtitle) = PixelDschungel.prompt(st, player: "a", revealed: false, ctx: ctx) {
            XCTAssertTrue(title.contains("Eingeloggt"))
            XCTAssertTrue(subtitle?.contains("Stufe 4") ?? false)
            XCTAssertTrue(subtitle?.contains(Money.format(stair[3])) ?? false)
        } else { XCTFail("locked player should see the idle card") }
        // Stage extra carries the picture and the stair.
        let out = PixelDschungel.stage(st, revealed: false, ctx: ctx)
        if case .pixel(let image, let level, _, let jackpot, let stufen, let locked) = out.extra {
            XCTAssertEqual(image, q.bild ?? "")
            XCTAssertFalse(image.isEmpty)
            XCTAssertEqual(level, 3)
            XCTAssertEqual(jackpot, stair[3])
            XCTAssertEqual(stufen, stair)
            XCTAssertEqual(locked, ["a"])
        } else { XCTFail("pixel extra expected") }
        // Scores: A gets the level-3 value; B (no answer) nothing.
        ctx.now = 1000 + 40_000
        let scores = PixelDschungel.scores(st, ctx: ctx)
        XCTAssertEqual(scores["a"], stair[3])
        XCTAssertEqual(scores["b"], 0)
    }
}
