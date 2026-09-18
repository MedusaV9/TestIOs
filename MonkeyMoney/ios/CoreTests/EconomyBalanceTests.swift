import XCTest
@testable import MonkeyMoneyCore

/// Economy balance gates (§3.1b): every format pays in the same league as a
/// normal question, no single round decides the match, skill wins more often
/// than luck, and the jar/jackpot stay a beat — not a lottery.
final class EconomyBalanceTests: XCTestCase {
    struct RoundStat {
        var section: Int
        var minigame: String
        var kind: SectionKind
        var questions: Int
        /// Sum of positive deltas over all players in this section.
        var paidOut: Int
        /// Largest single booked win.
        var maxSingle: Int
    }

    /// Play a match and collect what each section paid out.
    func play(modus: Modus, players: Int, seed: UInt32) -> (state: EngineState, rounds: [RoundStat]) {
        var rounds: [RoundStat] = []
        var current: RoundStat?
        var lastPhase: Phase?
        let r = SimHarness.run(modus: modus, players: players, seed: seed, maxTicks: 400_000) { s, _ in
            if let section = s.currentSection, current?.section != s.sectionIndex, s.sectionIndex >= 0, s.phase != .lobby, s.phase != .intro {
                if let c = current { rounds.append(c) }
                current = RoundStat(section: s.sectionIndex, minigame: section.minigameId, kind: section.typ, questions: 0, paidOut: 0, maxSingle: 0)
            }
            if s.phase == .aufloesung, lastPhase != .aufloesung, var c = current {
                c.questions += 1
                c.paidOut += s.lastDeltas.values.filter { $0 > 0 }.reduce(0, +)
                c.maxSingle = max(c.maxSingle, s.lastDeltas.values.max() ?? 0)
                current = c
            }
            lastPhase = s.phase
        }
        if let c = current { rounds.append(c) }
        XCTAssertEqual(r.state.phase, .ende)
        return (r.state, rounds)
    }

    func testFormatAnchorsAreRelativeToTheQuestionValue() {
        // Bananen-Tresor (medium): 380 / 250 / 150, consolation 50, bullseye 750.
        let t = Economy.estimateLadder(value: 250)
        XCTAssertEqual(t.ladder, [380, 250, 150])
        XCTAssertEqual(t.rest, 50)
        XCTAssertEqual(t.bullseye, 750)
        // Pixel-Dschungel (hard): 750 down to ~130 in eight steps.
        let p = Economy.pixelLadder(value: 500, steps: 8)
        XCTAssertEqual(p.start, 750)
        XCTAssertEqual(p.floor, 130)
        XCTAssertLessThanOrEqual(p.start - 8 * p.step, 140)
        // Affenbank (medium): 50 → 800, no 1.600 any more.
        XCTAssertEqual(Economy.bankChain(value: 250), [50, 100, 200, 400, 800])
        // Kokosnuss-Uhr: sack 1.5 F, ten ticks.
        XCTAssertEqual(Economy.sackStart(value: 100).start, 150)
        XCTAssertEqual(Economy.sackStart(value: 500).tick, 80)
        // Jackpot: hard 1.000, ULTRAHARD 1.500 (never 2.000 flat).
        XCTAssertEqual(Economy.jackpotQuestionValue(.hard), 1000)
        XCTAssertEqual(Economy.jackpotQuestionValue(.ultrahard), 1500)
        // Alles oder Banane caps: half the balance, at most 1.5 F, all-in lifts it.
        XCTAssertEqual(Economy.wagerCap(balance: 2000, value: 500, allIn: false), 750)
        XCTAssertEqual(Economy.wagerCap(balance: 600, value: 500, allIn: false), 300)
        XCTAssertEqual(Economy.wagerCap(balance: 60, value: 500, allIn: false), 50)
        XCTAssertEqual(Economy.wagerCap(balance: 2000, value: 500, allIn: true), 2000)
    }

    func testAffenbankVerdicts() {
        // Two players: both right grows, one right holds, none burns.
        XCTAssertEqual(Affenbank.verdict(correct: 2, active: 2), "waechst")
        XCTAssertEqual(Affenbank.verdict(correct: 1, active: 2), "haelt")
        XCTAssertEqual(Affenbank.verdict(correct: 0, active: 2), "verbrennt")
        // Four players: split holds, majority grows, minority burns.
        XCTAssertEqual(Affenbank.verdict(correct: 2, active: 4), "haelt")
        XCTAssertEqual(Affenbank.verdict(correct: 3, active: 4), "waechst")
        XCTAssertEqual(Affenbank.verdict(correct: 1, active: 4), "verbrennt")
        XCTAssertEqual(Affenbank.verdict(correct: 2, active: 3), "waechst")
    }

    func testNoSingleRoundDominatesAKlassikShow() {
        var worstRatio = 0.0
        var lines: [String] = []
        for seed: UInt32 in [1, 2, 3] {
            let (_, rounds) = play(modus: .klassik, players: 4, seed: seed)
            let normal = rounds.filter { $0.kind == .runde && $0.questions > 0 }
            XCTAssertGreaterThanOrEqual(normal.count, 6)
            // Rounds are the unit of the show: every round (4 questions or one rapid-fire
            // format) pays roughly the same league — before the anchors the Pixel and
            // Affenbank rounds paid 5–10× a Basics round.
            let totals = normal.map { Double($0.paidOut) }
            let median = totals.sorted()[totals.count / 2]
            for r in normal {
                let ratio = Double(r.paidOut) / max(1, median)
                lines.append(String(format: "seed %d  %-18@ %d q  paid %5d  ratio %.2f  max single %4d", seed, r.minigame as NSString, r.questions, r.paidOut, ratio, r.maxSingle))
                worstRatio = max(worstRatio, ratio)
                XCTAssertLessThanOrEqual(Double(r.paidOut), median * 1.9 + 300, "\(r.minigame) pays \(r.paidOut) vs median round \(median) (seed \(seed))")
                // No single booked win above ULTRAHARD + full speed bonus (1.500); a whole
                // rapid-fire round (Affenbank/Stinkbanane book once) may reach a perfect normal round.
                let roundBased = MinigameRegistry.plugin(r.minigame)?.meta.roundBased == true
                XCTAssertLessThanOrEqual(r.maxSingle, roundBased ? 2200 : 1500, "\(r.minigame) single win \(r.maxSingle) (seed \(seed))")
            }
        }
        print("BALANCE Klassik per-round payouts:\n" + lines.joined(separator: "\n") + String(format: "\nworst round/median ratio %.2f", worstRatio))
        XCTAssertLessThan(worstRatio, 2.2)
    }

    func testJackpotAndFinaleStayBeatsNotLotteries() {
        for seed: UInt32 in [4, 5] {
            let (s, rounds) = play(modus: .klassik, players: 4, seed: seed)
            let normalTotal = rounds.filter { $0.kind == .runde }.reduce(0) { $0 + $1.paidOut }
            if let jackpot = rounds.first(where: { $0.kind == .jackpot }) {
                // The jackpot beat is at most a third of everything the normal rounds paid.
                XCTAssertLessThanOrEqual(jackpot.paidOut, normalTotal / 3 + 500, "jackpot \(jackpot.paidOut) vs rounds \(normalTotal) (seed \(seed))")
                XCTAssertLessThanOrEqual(jackpot.maxSingle, 1500 + 3000)
            }
            // Finale: W_final keeps the formula, nobody drops below zero.
            XCTAssertGreaterThanOrEqual(s.wFinal ?? 0, 500)
            for p in s.players { XCTAssertGreaterThanOrEqual(p.balance, 0) }
        }
    }

    func testSkillBeatsLuckMostOfTheTime() {
        // Bots p0…p3 with skills .35/.47/.59/.71 — the best bot should finish top-2 in most shows.
        var topTwo = 0
        var wins = 0
        let seeds: [UInt32] = [11, 12, 13, 14, 15, 16]
        for seed in seeds {
            let (s, _) = play(modus: .quick, players: 4, seed: seed)
            let ranking = s.ranking.map { $0.id }
            if ranking.first == "p3" { wins += 1 }
            if ranking.prefix(2).contains("p3") { topTwo += 1 }
        }
        print("BALANCE skill: best bot wins \(wins)/\(seeds.count), top-2 \(topTwo)/\(seeds.count)")
        XCTAssertGreaterThanOrEqual(topTwo, seeds.count / 2, "the strongest bot should be top-2 in at least half the shows")
    }

    func testQuickShowTotalsAreInTheHundredsNotTenThousands() {
        for seed: UInt32 in [21, 22] {
            let (s, rounds) = play(modus: .quick, players: 3, seed: seed)
            let winner = s.ranking.first?.balance ?? 0
            // A Quick show (12 normal questions + 3 finale) ends with the winner in the low thousands.
            XCTAssertGreaterThan(winner, 600, "winner \(winner) (seed \(seed))")
            XCTAssertLessThan(winner, 9000, "winner \(winner) (seed \(seed))")
            let roundsPaid = rounds.filter { $0.kind == .runde }.map { $0.paidOut }
            print("BALANCE Quick seed \(seed): rounds paid \(roundsPaid), winner \(winner), all \(s.ranking.map { $0.balance })")
        }
    }
    func testEstimateSliderNeverOffersHalfYears() {
        let years = EstimateSpec(richtwert: 2013, einheit: "", toleranz: 1, min: 2009, max: 2025, skala: "linear")
        XCTAssertEqual(BananenTresor.step(years), 1)
        let count = EstimateSpec(richtwert: 14, einheit: "Feiertage", toleranz: 8, min: 5, max: 18, skala: "linear")
        XCTAssertEqual(BananenTresor.step(count), 1)
        let metres = EstimateSpec(richtwert: 5.6, einheit: "Meter", toleranz: 30, min: 1, max: 20, skala: "linear")
        XCTAssertEqual(BananenTresor.step(metres), 0.5)
        let big = EstimateSpec(richtwert: 100_000, einheit: "US-Dollar", toleranz: 30_000, min: 10_000, max: 1_000_000, skala: "linear")
        XCTAssertEqual(BananenTresor.step(big), 10)
    }
}
