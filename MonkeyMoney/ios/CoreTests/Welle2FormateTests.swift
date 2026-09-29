import XCTest
@testable import MonkeyMoneyCore

/// Welle 2: 🪜 Tipp-Treppe, ✅ Faktencheck, 🪢 Tauziehen — payout rules, generated
/// rule texts, whole bot matches (NFSim / SimHarness) and the edge-case sweeps of the
/// format audit (2/4/8 players, disconnects, late joiners, timer off, fixed time,
/// pause, every GM tool).
final class Welle2FormateTests: XCTestCase {
    let alle = ["tipp-treppe", "faktencheck", "tauziehen"]
    /// Recommended round sizes (Blueprints.empfohleneFragen).
    let groesse = ["tipp-treppe": 4, "faktencheck": 8, "tauziehen": 6]

    // MARK: Helpers

    static func choice(_ id: String, schw: Difficulty = .medium, tipps: [String] = ["Tipp eins", "Tipp zwei", "Tipp drei"], korrekt: Int = 1) -> Question {
        Question(id: id, kat: "kurioses_mixed", schw: schw, typ: .choice, text: "Frage \(id)?", tipps: tipps,
                 antworten: ["A \(id)", "B \(id)", "C \(id)", "D \(id)"], korrekt: korrekt)
    }

    static func fakt(_ id: String, wahr: Bool, schw: Difficulty = .medium) -> Question {
        Question(id: id, kat: "kurioses_mixed", schw: schw, typ: .wahrFalsch, text: "Behauptung \(id).", erkl: "Erklärung \(id).", korrektBool: wahr)
    }

    /// Unit context with balances.
    static func ctx(_ balances: [(PlayerId, Int)], fragen: Int, patch: ((inout MatchSettings) -> Void)? = nil) -> MinigameContext {
        var c = NFSim.ctx(players: balances.map { $0.0 }, fragen: fragen, patch: patch)
        c.balances = Dictionary(uniqueKeysWithValues: balances)
        return c
    }

    // MARK: 🪜 Tipp-Treppe — rules

    func testTippTreppePayoutPerStep() {
        for w in [100, 250, 500, 1000] {
            let werte = (0...3).map { TippTreppe.punkte(wert: w, stufe: $0) }
            for (i, k) in Welle2.Anteil.treppe.enumerated() { XCTAssertEqual(werte[i], NeueFormate.betrag(w, k), "F \(w) step \(i)") }
            XCTAssertEqual(werte, werte.sorted(by: >), "every hint makes the answer cheaper")
        }
        XCTAssertEqual(TippTreppe.punkte(wert: 250, stufe: 0), 500, "before any hint: 2 F")
        XCTAssertEqual(TippTreppe.punkte(wert: 250, stufe: 1), 350, "after hint 1: 1,4 F")
        XCTAssertEqual(TippTreppe.punkte(wert: 1000, stufe: 2), 900, "after hint 2: 0,9 F")
        XCTAssertEqual(TippTreppe.punkte(wert: 1000, stufe: 3), 500, "after hint 3: 0,5 F")
        XCTAssertEqual(TippTreppe.punkte(wert: 250, stufe: 7), TippTreppe.punkte(wert: 250, stufe: 3), "clamped to the last step")
    }

    func testTippTreppeHintsFillUpMissingTips() {
        var rng = SeededRandom(seed: 4)
        let full = Self.choice("h3")
        let three = TippTreppe.hinweise(full, options: full.choiceOptions, correct: 1, rng: &rng)
        XCTAssertEqual(three.texte, full.tipps)
        XCTAssertEqual(three.streichen, [nil, nil, nil])
        let one = Self.choice("h1", tipps: ["Nur ein Tipp"])
        let h1 = TippTreppe.hinweise(one, options: one.choiceOptions, correct: 1, rng: &rng)
        XCTAssertEqual(h1.texte.count, 3)
        XCTAssertEqual(h1.texte[0], "Nur ein Tipp")
        XCTAssertEqual(h1.streichen.compactMap { $0 }.count, 2, "two wrong options get struck")
        XCTAssertFalse(h1.streichen.contains(1), "never the right one")
        XCTAssertEqual(Set(h1.streichen.compactMap { $0 }).count, 2)
        let none = Self.choice("h0", tipps: [])
        let h0 = TippTreppe.hinweise(none, options: none.choiceOptions, correct: 1, rng: &rng)
        XCTAssertEqual(h0.streichen.compactMap { $0 }.count, 2, "at least two options stay")
        XCTAssertEqual(h0.texte[2], "🔤 Die Antwort beginnt mit »B«")
        let duo = Question(id: "duo", kat: "x", schw: .easy, typ: .wahrFalsch, text: "?", korrektBool: true)
        let hd = TippTreppe.hinweise(duo, options: duo.choiceOptions, correct: 0, rng: &rng)
        XCTAssertEqual(hd.texte.count, 3)
        XCTAssertTrue(hd.streichen.allSatisfy { $0 == nil }, "two options: nothing to strike")
    }

    /// A question: a locks before any hint, b after hint 1, c after hint 2 (wrong), d after hint 3, e never.
    func testTippTreppeRoundPaysByTheStepYouLockedIn() {
        var ctx = Self.ctx([("a", 0), ("b", 0), ("c", 0), ("d", 0), ("e", 0)], fragen: 2)
        let q = [Self.choice("t1"), Self.choice("t2", schw: .hard, korrekt: 2)]
        var s = TippTreppe.initState(questions: q, songs: [], ctx: &ctx)
        let t0 = ctx.now, step = s.stufeMs
        XCTAssertEqual(step, Welle2.treppeStufeMs, "normal tempo: 16 s clock, a hint every 4 s")
        XCTAssertEqual(s.core?.timerMs, 4 * step)
        XCTAssertEqual(s.offen, 0, "no hint at the start")
        func at(_ t: Int) { ctx.now = t; TippTreppe.tick(&s, ctx: &ctx) }
        at(t0 + 500)
        TippTreppe.reduce(&s, action: .choose(1), from: "a", ctx: &ctx)
        guard case .choice(_, _, _, _, _, let hint0) = TippTreppe.prompt(s, player: "b", revealed: false, ctx: ctx) else { return XCTFail("choice prompt") }
        XCTAssertTrue(hint0?.contains("+500") == true, "phone shows today's value: \(hint0 ?? "-")")
        at(t0 + step + 100)
        XCTAssertEqual(s.offen, 1)
        let wall = TippTreppe.stage(s, revealed: false, ctx: ctx).wall
        XCTAssertNil(wall?.tipp, "the hints stand on the staircase widget")
        XCTAssertEqual(Welle2.payload(TippTreppe.View.self, from: TippTreppe.stage(s, revealed: false, ctx: ctx).extra)?.tipps, ["Tipp eins"])
        XCTAssertEqual(wall?.wert, 350, "the wall value drops with every hint")
        TippTreppe.reduce(&s, action: .choose(1), from: "b", ctx: &ctx)
        at(t0 + 2 * step + 100)
        TippTreppe.reduce(&s, action: .choose(0), from: "c", ctx: &ctx)
        // While asking, the widget shows who locked at which step — never right/wrong.
        let v = Welle2.payload(TippTreppe.View.self, from: TippTreppe.stage(s, revealed: false, ctx: ctx).extra)
        XCTAssertEqual(v?.locked, ["a": 0, "b": 1, "c": 2])
        XCTAssertEqual(v?.tipps.count, 2)
        XCTAssertEqual(v?.ergebnis, [])
        at(t0 + 3 * step + 100)
        XCTAssertEqual(s.offen, 3)
        TippTreppe.reduce(&s, action: .choose(1), from: "d", ctx: &ctx)
        XCTAssertEqual(s.phase, "frage", "e is still out")
        at(t0 + 4 * step + ChoiceCore.graceMs + 1)
        XCTAssertEqual(s.phase, "mini")
        let p = s.punkte
        XCTAssertEqual(p["a"], 500)
        XCTAssertEqual(p["b"], 350)
        XCTAssertNil(p["c"], "wrong = 0")
        XCTAssertEqual(p["d"], 130)
        XCTAssertNil(p["e"])
        XCTAssertEqual(s.ohneTipp["a"], 1)
        let mini = Welle2.payload(TippTreppe.View.self, from: TippTreppe.stage(s, revealed: false, ctx: ctx).extra)
        XCTAssertEqual(mini?.tipps.count, 3, "the mini-reveal shows the whole staircase")
        XCTAssertEqual(mini?.ergebnis.first { $0.player == "c" }?.correct, false)
        XCTAssertEqual(mini?.ergebnis.first { $0.player == "e" }?.stufe, nil)
        XCTAssertNil(TippTreppe.stage(s, revealed: false, ctx: ctx).wall, "mini-reveal: whole scene for the widget")
        // Next question: everybody locks in at once → ends early, before any hint.
        at(ctx.now + 10_000)
        XCTAssertEqual(s.index, 1)
        XCTAssertEqual(s.wert, 500)
        for x in ["a", "b", "c", "d", "e"] { TippTreppe.reduce(&s, action: .choose(2), from: x, ctx: &ctx) }
        at(ctx.now + 250)
        XCTAssertEqual(s.phase, "mini")
        XCTAssertEqual(s.punkte["e"], 1000, "hard question, no hint: 2 × 500")
        at(ctx.now + 10_000)
        XCTAssertTrue(TippTreppe.isFinished(s, ctx: ctx))
        XCTAssertEqual(TippTreppe.scores(s, ctx: ctx), ["a": 1500, "b": 1350, "c": 1000, "d": 1130, "e": 1000])
        XCTAssertEqual(TippTreppe.outcomes(s, ctx: ctx)["c"]?.correct, true)
        guard case .reveal(_, _, let delta, _, _, _) = TippTreppe.prompt(s, player: "b", revealed: true, ctx: ctx) else { return XCTFail("reveal") }
        XCTAssertEqual(delta, 1350)
    }

    func testTippTreppeGeneratedStrikeAndTimerOffAndSkip() {
        // A question without tips: the strike hints remove options on the wall and the phones.
        var ctx = Self.ctx([("a", 0), ("b", 0)], fragen: 3) { $0.timerAus = true }
        var s = TippTreppe.initState(questions: [Self.choice("n0", tipps: []), Self.choice("n1"), Self.choice("n2")], songs: [], ctx: &ctx)
        XCTAssertEqual(s.questions.first?.id, "n1", "questions with three tips go first")
        XCTAssertEqual(s.core?.deadline, ctx.now + MinigameContext.unlimitedMs, "timer off")
        XCTAssertEqual(s.stufeMs, Welle2.treppeStufeMs, "hints keep coming without a timer")
        XCTAssertNil(TippTreppe.stage(s, revealed: false, ctx: ctx).wall?.deadline)
        // GM skip annuls the running question: nothing booked, next question.
        TippTreppe.reduce(&s, action: .choose(1), from: "a", ctx: &ctx)
        TippTreppe.gm(&s, action: .skipQuestion, ctx: &ctx)
        XCTAssertEqual(s.index, 1)
        XCTAssertEqual(s.gespielt, 0)
        XCTAssertTrue(s.punkte.isEmpty)
        TippTreppe.gm(&s, action: .skipQuestion, ctx: &ctx)
        XCTAssertEqual(s.core?.question.id, "n0")
        let t0 = ctx.now
        ctx.now = t0 + 2 * s.stufeMs + 50
        TippTreppe.tick(&s, ctx: &ctx)
        XCTAssertEqual(s.core?.globalRemoved.count, 2, "two strike hints are open")
        XCTAssertFalse(s.core?.globalRemoved.contains(1) ?? true)
        guard case .choice(_, let opts, _, _, _, _) = TippTreppe.prompt(s, player: "b", revealed: false, ctx: ctx) else { return XCTFail("choice") }
        XCTAssertEqual(opts.filter { $0.removed }.count, 2)
        // Timer off: it waits for everybody, far past the nominal clock …
        ctx.now = t0 + 120_000
        TippTreppe.tick(&s, ctx: &ctx)
        XCTAssertEqual(s.phase, "frage")
        XCTAssertEqual(s.offen, 3)
        TippTreppe.reduce(&s, action: .choose(1), from: "a", ctx: &ctx)
        TippTreppe.reduce(&s, action: .choose(1), from: "b", ctx: &ctx)
        TippTreppe.tick(&s, ctx: &ctx)
        XCTAssertEqual(s.phase, "mini")
        XCTAssertEqual(s.punkte["a"], TippTreppe.punkte(wert: 250, stufe: 3))
        ctx.now += 10_000
        TippTreppe.tick(&s, ctx: &ctx)
        XCTAssertTrue(TippTreppe.isFinished(s, ctx: ctx))
        XCTAssertEqual(TippTreppe.questionsUsed(s), 3)
    }

    func testTippTreppePauseMovesTheHintSchedule() {
        var ctx = Self.ctx([("a", 0), ("b", 0)], fragen: 1)
        var s = TippTreppe.initState(questions: [Self.choice("p")], songs: [], ctx: &ctx)
        let t0 = ctx.now
        ctx.now = t0 + s.stufeMs - 500
        TippTreppe.tick(&s, ctx: &ctx)
        XCTAssertEqual(s.offen, 0)
        // 40 s pause: the engine shifts the minigame clocks on resume.
        ctx.now += 40_000
        TippTreppe.gm(&s, action: .timerShift(ms: 40_000), ctx: &ctx)
        TippTreppe.tick(&s, ctx: &ctx)
        XCTAssertEqual(s.offen, 0, "the pause did not open a hint")
        ctx.now += 600
        TippTreppe.tick(&s, ctx: &ctx)
        XCTAssertEqual(s.offen, 1)
    }

    // MARK: ✅ Faktencheck — rules

    func testFaktencheckStreakMultiplierAndCost() {
        let w = 250
        XCTAssertEqual(Faktencheck.faktor(serie: 1), 1.0)
        XCTAssertEqual(Faktencheck.faktor(serie: 2), 1.5)
        XCTAssertEqual(Faktencheck.faktor(serie: 3), 2.0)
        XCTAssertEqual(Faktencheck.faktor(serie: 4), 3.0)
        XCTAssertEqual(Faktencheck.faktor(serie: 11), 3.0, "3× is the cap")
        XCTAssertEqual((1...5).map { Faktencheck.gewinn(wert: w, serie: $0) }, [150, 230, 300, 450, 450].map { $0 },
                       "0,6 F × 1 / 1,5 / 2 / 3 / 3")
        for n in 1...6 { XCTAssertEqual(Faktencheck.gewinn(wert: w, serie: n), NeueFormate.betrag(w, Welle2.Anteil.faktBasis * Faktencheck.faktor(serie: n))) }
        XCTAssertEqual(Faktencheck.strafe(wert: w, guthaben: 5000), 50, "0,2 F")
        XCTAssertEqual(Faktencheck.strafe(wert: w, guthaben: 30), 30, "never below 0")
        XCTAssertEqual(Faktencheck.strafe(wert: w, guthaben: 0), 0)
        XCTAssertEqual(Faktencheck.strafe(wert: w, guthaben: -400), 0, "in the red: no further cost")
    }

    func testFaktencheckSeriesRound() {
        // a (rich): ✔✔✔✔✔ ✗ ✔ · b (broke): ✗ ✔ ✗ … · c never answers.
        var ctx = Self.ctx([("a", 2000), ("b", 0), ("c", 500)], fragen: 7)
        let facts = (0..<7).map { Self.fakt("f\($0)", wahr: $0 % 2 == 0) }
        var s = Faktencheck.initState(questions: facts, songs: [], ctx: &ctx)
        XCTAssertEqual(s.core?.timerMs, Welle2.faktTimerMs, "short blitz clock (normal tempo)")
        XCTAssertEqual(s.core?.options, ["Wahr", "Falsch"])
        let aRight = [true, true, true, true, true, false, true]
        let bRight = [false, true, false, true, true, true, true]
        for i in 0..<7 {
            let truth = s.core!.correctIndex
            Faktencheck.reduce(&s, action: .choose(aRight[i] ? truth : 1 - truth), from: "a", ctx: &ctx)
            // Binary labels work too.
            let bIdx = bRight[i] ? truth : 1 - truth
            Faktencheck.reduce(&s, action: .binary(bIdx == 0 ? "✅ Wahr" : "❌ Falsch"), from: "b", ctx: &ctx)
            ctx.now = s.core!.deadline + ChoiceCore.graceMs + 1
            Faktencheck.tick(&s, ctx: &ctx)
            XCTAssertEqual(s.phase, "mini", "fact \(i)")
            if i == 5 { XCTAssertEqual(s.serie["a"], 0, "a wrong fact resets the streak") }
            XCTAssertEqual(s.serie["c"], 0, "no answer: streak gone")
            ctx.now += 5000
            Faktencheck.tick(&s, ctx: &ctx)
        }
        XCTAssertTrue(Faktencheck.isFinished(s, ctx: ctx))
        let g = { (n: Int) in Faktencheck.gewinn(wert: 250, serie: n) }
        XCTAssertEqual(s.punkte["a"], g(1) + g(2) + g(3) + g(4) + g(5) - 50 + g(1))
        XCTAssertEqual(s.besteSerie["a"], 5)
        // b: first wrong is free (balance 0), then +150, then wrong costs 50, then a streak of 4.
        XCTAssertEqual(s.kosten["b"], 50)
        XCTAssertEqual(s.punkte["b"], g(1) - 50 + g(1) + g(2) + g(3) + g(4))
        XCTAssertNil(s.punkte["c"], "no answer costs nothing")
        XCTAssertNil(Faktencheck.outcomes(s, ctx: ctx)["c"]?.correct ?? nil)
        let v = Welle2.payload(Faktencheck.View.self, from: Faktencheck.stage(s, revealed: true, ctx: ctx).extra)
        XCTAssertEqual(v?.phase, "fertig")
        XCTAssertEqual(v?.besteSerie["a"], 5)
    }

    func testFaktencheckNetLossIsBookedAndTruthHiddenWhileAsking() {
        var ctx = Self.ctx([("a", 1000), ("b", 1000)], fragen: 2)
        var s = Faktencheck.initState(questions: [Self.fakt("x", wahr: true), Self.fakt("y", wahr: false)], songs: [], ctx: &ctx)
        let asking = Welle2.payload(Faktencheck.View.self, from: Faktencheck.stage(s, revealed: false, ctx: ctx).extra)
        XCTAssertNil(asking?.wahr, "the stamp only comes after the fact closed")
        XCTAssertEqual(asking?.fakt, "Behauptung x.")
        for _ in 0..<2 {
            let wrong = 1 - s.core!.correctIndex
            Faktencheck.reduce(&s, action: .choose(wrong), from: "a", ctx: &ctx)
            Faktencheck.reduce(&s, action: .choose(s.core!.correctIndex), from: "b", ctx: &ctx)
            Faktencheck.tick(&s, ctx: &ctx)
            XCTAssertEqual(s.phase, "mini", "all in → closes at once")
            let mini = Welle2.payload(Faktencheck.View.self, from: Faktencheck.stage(s, revealed: false, ctx: ctx).extra)
            XCTAssertEqual(mini?.wahr, s.letzteWahr)
            ctx.now += 5000
            Faktencheck.tick(&s, ctx: &ctx)
        }
        XCTAssertEqual(Faktencheck.scores(s, ctx: ctx)["a"], -100, "two wrong facts: −2 × 0,2 F")
        XCTAssertEqual(Faktencheck.outcomes(s, ctx: ctx)["a"]?.correct, false)
        XCTAssertEqual(Faktencheck.scores(s, ctx: ctx)["b"], 150 + 230)
    }

    // MARK: 🪢 Tauziehen — rules

    func testTauziehenSnakeDraftIsFairAndDeterministic() {
        let four = Self.ctx([("p0", 300), ("p1", 900), ("p2", 700), ("p3", 500)], fragen: 6)
        let t4 = Tauziehen.teams(four)
        // Ranking p1, p2, p3, p0 → A gets 1st + 4th, B 2nd + 3rd.
        XCTAssertEqual(t4.a, ["p1", "p0"])
        XCTAssertEqual(t4.b, ["p2", "p3"])
        var five = Self.ctx([("a", 0), ("b", 0), ("c", 0), ("d", 0), ("e", 0)], fragen: 6)
        let t5 = Tauziehen.teams(five)
        XCTAssertEqual(t5.a, ["a", "d", "e"], "equal balances: seat order")
        XCTAssertEqual(t5.b, ["b", "c"])
        five.connected.remove("a")
        XCTAssertEqual(Tauziehen.teams(five).b, ["c", "d"], "disconnected players are drafted last")
        let eight = Self.ctx((0..<8).map { ("p\($0)", 1000 - $0 * 100) }, fragen: 6)
        let t8 = Tauziehen.teams(eight)
        XCTAssertEqual(t8.a, ["p0", "p3", "p4", "p7"])
        XCTAssertEqual(t8.b, ["p1", "p2", "p5", "p6"])
        for n in 2...12 {
            let c = Self.ctx((0..<n).map { ("p\($0)", ($0 * 37) % 11 * 100) }, fragen: 6)
            let t = Tauziehen.teams(c)
            XCTAssertEqual(t.a.count + t.b.count, n)
            XCTAssertLessThanOrEqual(abs(t.a.count - t.b.count), 1, "\(n) players")
            XCTAssertEqual(Set(t.a).intersection(t.b), [])
        }
    }

    func testTauziehenPullsWinnerAndPayout() {
        // Fastest right pulls double; spectators never pull.
        let pulls = Tauziehen.zuege(richtigNachZeit: ["x", "b1", "a1", "a2"], team: { ["a1": "a", "a2": "a", "b1": "b"][$0] }, ms: { _ in 1000 })
        XCTAssertEqual(pulls.map { $0.player }, ["b1", "a1", "a2"])
        XCTAssertEqual(pulls.map { $0.zug }, [2, 1, 1])
        // Per-member strength: 3 against 2 players.
        XCTAssertEqual(Tauziehen.sieger(zugA: 6, zugB: 4, groesseA: 3, groesseB: 2), "remis", "6/3 = 4/2")
        XCTAssertEqual(Tauziehen.sieger(zugA: 7, zugB: 4, groesseA: 3, groesseB: 2), "a")
        XCTAssertEqual(Tauziehen.sieger(zugA: 5, zugB: 4, groesseA: 3, groesseB: 2), "b")
        XCTAssertEqual(Tauziehen.knoten(zugA: 0, zugB: 0, groesseA: 2, groesseB: 2, gesamt: 6), 0)
        XCTAssertLessThan(Tauziehen.knoten(zugA: 4, zugB: 1, groesseA: 2, groesseB: 2, gesamt: 6), 0, "negative = team A's side")
        XCTAssertEqual(Tauziehen.knoten(zugA: 0, zugB: 99, groesseA: 2, groesseB: 2, gesamt: 6), 1, "clamped")
        // 6 medium questions: Σ F = 1.500 → a win pays 1,0 × 1.500 / 4 each, the MVP +0,5 F, a draw 0,4 × 1.500 / 4.
        let win = Tauziehen.auszahlung(sieger: "a", teamA: ["a1", "a2"], teamB: ["b1", "b2"], rundenWert: 1500, gespielt: 6, mvp: "a2")
        XCTAssertEqual(win["a1"], NeueFormate.betrag(1500, Welle2.Anteil.zugSieg / 4))
        XCTAssertEqual(win["a1"], 380)
        XCTAssertEqual(win["a2"], 380 + NeueFormate.betrag(250, Welle2.Anteil.zugMvp))
        XCTAssertNil(win["b1"])
        let draw = Tauziehen.auszahlung(sieger: "remis", teamA: ["a1", "a2"], teamB: ["b1"], rundenWert: 1500, gespielt: 6, mvp: nil)
        XCTAssertEqual(draw, ["a1": 150, "a2": 150, "b1": 150])
        // Scales with the question count: 8 questions pay twice as much as 4.
        let w4 = Tauziehen.auszahlung(sieger: "b", teamA: [], teamB: ["b"], rundenWert: 4 * 250, gespielt: 4, mvp: nil)["b"]
        let w8 = Tauziehen.auszahlung(sieger: "b", teamA: [], teamB: ["b"], rundenWert: 8 * 250, gespielt: 8, mvp: nil)["b"]
        XCTAssertEqual(w4, 250, "4 questions: 1,0 F")
        XCTAssertEqual(w8, 500)
        XCTAssertTrue(Tauziehen.auszahlung(sieger: "a", teamA: ["a"], teamB: [], rundenWert: 0, gespielt: 0, mvp: nil).isEmpty)
    }

    func testTauziehenRoundTeamAWinsWithMvp() {
        var ctx = Self.ctx([("p0", 800), ("p1", 600), ("p2", 400), ("p3", 200), ("late", 0)], fragen: 4)
        ctx.players.removeLast()
        var s = Tauziehen.initState(questions: (0..<4).map { Self.choice("z\($0)") }, songs: [], ctx: &ctx)
        XCTAssertEqual(s.teamA, ["p0", "p3"])
        XCTAssertEqual(s.teamB, ["p1", "p2"])
        // A late joiner watches (no team, no pull, the round does not wait for them).
        ctx.players.append("late")
        ctx.connected.insert("late")
        guard case .idle = Tauziehen.prompt(s, player: "late", revealed: false, ctx: ctx) else { return XCTFail("spectator prompt") }
        for i in 0..<4 {
            let right = s.core!.correctIndex
            // p3 is fastest (double), p0 right, team B wrong; question 3: B right and fastest.
            if i == 2 {
                ctx.now += 100; Tauziehen.reduce(&s, action: .choose(right), from: "p1", ctx: &ctx)
                ctx.now += 100; Tauziehen.reduce(&s, action: .choose(right), from: "p2", ctx: &ctx)
                ctx.now += 100; Tauziehen.reduce(&s, action: .choose((right + 1) % 4), from: "p0", ctx: &ctx)
                ctx.now += 100; Tauziehen.reduce(&s, action: .choose((right + 1) % 4), from: "p3", ctx: &ctx)
            } else {
                ctx.now += 100; Tauziehen.reduce(&s, action: .choose(right), from: "p3", ctx: &ctx)
                ctx.now += 100; Tauziehen.reduce(&s, action: .choose(right), from: "p0", ctx: &ctx)
                ctx.now += 100; Tauziehen.reduce(&s, action: .choose((right + 1) % 4), from: "p1", ctx: &ctx)
                ctx.now += 100; Tauziehen.reduce(&s, action: .choose((right + 1) % 4), from: "p2", ctx: &ctx)
            }
            Tauziehen.reduce(&s, action: .choose(right), from: "late", ctx: &ctx)
            Tauziehen.tick(&s, ctx: &ctx)
            XCTAssertEqual(s.phase, "mini", "question \(i): the four team members are in")
            let v = Welle2.payload(Tauziehen.View.self, from: Tauziehen.stage(s, revealed: false, ctx: ctx).extra)
            XCTAssertEqual(v?.letzte.first?.zug, 2)
            ctx.now += 6000
            Tauziehen.tick(&s, ctx: &ctx)
        }
        XCTAssertTrue(Tauziehen.isFinished(s, ctx: ctx))
        XCTAssertEqual(s.zugA, 3 * 3)
        XCTAssertEqual(s.zugB, 3)
        XCTAssertEqual(s.sieger, "a")
        XCTAssertEqual(s.mvp, "p3", "most pulls (3 double pulls)")
        let pay = Tauziehen.scores(s, ctx: ctx)
        XCTAssertEqual(pay["p0"], 250)
        XCTAssertEqual(pay["p3"], 250 + 130)
        XCTAssertEqual(pay["p1"], 0)
        XCTAssertEqual(pay["late"], 0)
        XCTAssertNil(Tauziehen.outcomes(s, ctx: ctx)["late"]?.correct ?? nil)
        let end = Welle2.payload(Tauziehen.View.self, from: Tauziehen.stage(s, revealed: true, ctx: ctx).extra)
        XCTAssertEqual(end?.sieger, "a")
        XCTAssertEqual(end?.mvp, "p3")
        XCTAssertEqual(end?.teams.map { $0.mitglieder }, [["p0", "p3"], ["p1", "p2"]])
    }

    func testTauziehenEarlyBookingAndDrawAfterSkips() {
        var ctx = Self.ctx([("a", 0), ("b", 0), ("c", 0), ("d", 0)], fragen: 3)
        var s = Tauziehen.initState(questions: (0..<3).map { Self.choice("s\($0)") }, songs: [], ctx: &ctx)
        // "Notausgang mit Punkten" books before the end: nothing played = draw with nothing to share.
        XCTAssertEqual(Tauziehen.scores(s, ctx: ctx).values.reduce(0, +), 0)
        for _ in 0..<3 { Tauziehen.gm(&s, action: .skipQuestion, ctx: &ctx) }
        XCTAssertTrue(Tauziehen.isFinished(s, ctx: ctx))
        XCTAssertEqual(s.sieger, "remis")
        XCTAssertTrue(s.auszahlung.isEmpty)
    }

    // MARK: Explain cards

    /// Explain cards quote the real payout constants (texts are generated from them).
    func testRulesTextsMatchThePayouts() {
        let f = Welle2.f
        let text = { (id: String) -> String in
            guard let m = MinigameRegistry.plugin(id)?.meta else { return "" }
            return (m.regeln + [m.gewinn, m.erklaerung, m.kurz]).joined(separator: " ")
        }
        for k in Welle2.Anteil.treppe { XCTAssertTrue(text("tipp-treppe").contains(f(k)), "tipp-treppe lacks \(f(k))") }
        XCTAssertTrue(text("faktencheck").contains(f(Welle2.Anteil.faktBasis)))
        XCTAssertTrue(text("faktencheck").contains(f(Welle2.Anteil.faktFalsch)))
        for k in Welle2.Anteil.faktSerie.dropFirst() { XCTAssertTrue(text("faktencheck").contains("×" + f(k).dropLast()), "faktencheck lacks ×\(f(k).dropLast())") }
        for k in [Welle2.Anteil.zugSieg, Welle2.Anteil.zugMvp, Welle2.Anteil.zugRemis] { XCTAssertTrue(text("tauziehen").contains(f(k)), "tauziehen lacks \(f(k))") }
        XCTAssertTrue(text("tauziehen").contains("pro \(Int(Welle2.Anteil.zugFragenBasis)) Fragen"))
        for id in alle {
            let m = MinigameRegistry.plugin(id)!.meta
            XCTAssertTrue((3...5).contains(m.regeln.count), id)
            XCTAssertFalse(m.gewinn.isEmpty, id)
            XCTAssertTrue(m.roundBased && !m.streak && m.v2, id)
            XCTAssertTrue(m.jokerAktionen.isEmpty, "\(id): round formats take no question jokers")
        }
        XCTAssertEqual(MinigameRegistry.plugin("tauziehen")?.meta.minPlayers, 4)
    }

    // MARK: Integration: registry, playlist, plan

    func testSelectableInTheEigeneShowPlaylist() {
        for id in alle {
            XCTAssertNotNil(MinigameRegistry.plugin(id), id)
            XCTAssertTrue(Blueprints.eigenWaehlbar(id), id)
        }
        XCTAssertEqual(alle.map(Blueprints.empfohleneFragen), [4, 8, 6])
        var s = MatchSettings(modus: .eigen)
        s.apply(patch: ["eigenePlaylist": .array(alle.map { .string($0) })])
        XCTAssertEqual(s.eigenePlaylist, [PlaylistItem(id: "tipp-treppe", fragen: 4), PlaylistItem(id: "faktencheck", fragen: 8), PlaylistItem(id: "tauziehen", fragen: 6)])
        let plan = Plan.build(settings: s, playerCount: 4, catalog: TestContent.catalog)
        XCTAssertEqual(plan.filter { $0.typ == .runde }.map(\.minigameId), alle)
        XCTAssertEqual(Plan.build(settings: s, playerCount: 3, catalog: TestContent.catalog).filter { $0.typ == .runde }.map(\.minigameId),
                       ["tipp-treppe", "faktencheck", MinigameRegistry.fallbackId], "Tauziehen needs 4 players")
        let minutes = Plan.estimateMinutes(settings: s)
        XCTAssertTrue((5...40).contains(minutes), "\(minutes) min")
        // Per-format seconds are used: the three rounds are quicker than three classic 45-s rounds of the same size.
        var classic = s
        classic.eigenePlaylist = [PlaylistItem(id: "bananen-basics", fragen: 4), PlaylistItem(id: "bananen-basics", fragen: 8), PlaylistItem(id: "bananen-basics", fragen: 6)]
        XCTAssertLessThan(minutes, Plan.estimateMinutes(settings: classic))
    }

    // MARK: Whole matches

    /// A standard 4-question Bananen-Basics round first, then the three formats at their
    /// recommended size. Every format finishes; the payout is gated against the standard round.
    /// Bands per format (at the specified constants): Tipp-Treppe ≈ 1×, Faktencheck ≈ 1,7× (streaks
    /// over 8 facts), Tauziehen ≈ 0,2× (only the winning half of the table is paid, once).
    func testAllThreeFinishInBotMatchesAndPayLikeARound() {
        var ratios: [String: [Double]] = [:]
        var lines: [String] = []
        for (players, seeds) in [(2, [UInt32(1)]), (4, [1, 2, 3]), (8, [1])] {
            for seed in seeds {
                var sizes = groesse
                sizes["bananen-basics"] = 4
                let r = NFSim.run(formats: ["bananen-basics"] + alle, players: players, seed: seed, fragen: sizes, keepTail: false)
                XCTAssertEqual(r.state.phase, .ende, "\(players)p seed \(seed) stuck in \(r.state.phase)")
                let expected = players >= 4 ? alle : alle.filter { $0 != "tauziehen" }
                XCTAssertTrue(Set(expected).isSubset(of: r.minigames), "\(players)p: not all formats ran: \(r.minigames.sorted())")
                if players < 4 { XCTAssertFalse(r.minigames.contains("tauziehen"), "Tauziehen needs 4 players") }
                let base = Double(max(1, r.paid[0] ?? 0))
                for (i, id) in alle.enumerated() where expected.contains(id) {
                    XCTAssertEqual(r.played[i + 1], groesse[id], "\(id) \(players)p played the full round")
                    let ratio = Double(r.paid[i + 1] ?? 0) / base
                    ratios[id, default: []].append(ratio)
                    lines.append(String(format: "%@ %dp seed %d: paid %d vs standard round %.0f → %.2f", id, players, seed, r.paid[i + 1] ?? 0, base, ratio))
                }
            }
        }
        print("BALANCE-W2\n" + lines.joined(separator: "\n"))
        let band: [String: ClosedRange<Double>] = ["tipp-treppe": 0.5...1.8, "faktencheck": 0.8...2.3, "tauziehen": 0.1...0.6]
        for id in alle {
            let rs = ratios[id] ?? []
            let avg = rs.reduce(0, +) / Double(max(1, rs.count))
            print(String(format: "BALANCE-W2 %@ avg %.2f", id, avg))
            XCTAssertTrue(band[id]!.contains(avg), "\(id) pays \(avg)× a standard round, expected \(band[id]!)")
        }
    }

    /// The same seed plays the same show (no Dictionary/Set order in any decision).
    func testDeterministicReplay() {
        let small = ["tipp-treppe": 3, "faktencheck": 4, "tauziehen": 3]
        let a = NFSim.run(formats: alle, players: 5, seed: 9, fragen: small, keepTail: false)
        let b = NFSim.run(formats: alle, players: 5, seed: 9, fragen: small, keepTail: false)
        XCTAssertEqual(a.state.phase, .ende)
        XCTAssertEqual(a.state.players.map { $0.balance }, b.state.players.map { $0.balance })
        XCTAssertEqual(a.paid, b.paid)
    }

    /// Full "Eigene Show" matches with the SimHarness bots (2 / 4 / 8 players).
    func testEigeneShowWithTheNewFormatsPlaysThrough() {
        for players in [2, 4, 8] {
            let r = SimHarness.run(modus: .eigen, players: players, seed: 3, settingsPatch: { s in
                s.eigenePlaylist = [PlaylistItem(id: "tipp-treppe", fragen: 4), PlaylistItem(id: "faktencheck", fragen: 8), PlaylistItem(id: "tauziehen", fragen: 6)]
            }, maxTicks: 300_000)
            XCTAssertEqual(r.state.phase, .ende, "\(players)p stuck in \(r.state.phase)")
            let rounds = r.state.plan.filter { $0.typ == .runde }.map(\.minigameId)
            XCTAssertEqual(rounds, players >= 4 ? alle : ["tipp-treppe", "faktencheck", MinigameRegistry.fallbackId])
        }
    }

    // MARK: Format-audit sweeps (the FormatAuditTests gates on the three formats)

    func sweep(_ name: String, players: Int = 4, patch: @escaping (inout MatchSettings) -> Void = { _ in }, maxMs: Int = 30 * 60_000,
               setup: ((AuditDriver) -> Void)? = nil, each: ((AuditDriver) -> Void)? = nil, check: ((AuditDriver, Int, Set<String>) -> Void)? = nil) {
        for f in alle {
            let d = AuditDriver(format: f, players: players, fragen: groesse[f], patch: patch)
            guard d.toQuestion() else { XCTFail("\(name) \(f): never reached the question"); continue }
            var ran: Set<String> = []
            setup?(d)
            let ms = d.finishSection(maxMs: maxMs, each: { d in
                if let id = d.s.minigame?.id { ran.insert(id) }
                each?(d)
            })
            for p in d.problems { XCTFail("\(name) \(p)") }
            check?(d, ms, ran)
            print(String(format: "AUDIT-W2 %@ %-12@ %4.0f s  %d bookings", name, f as NSString, Double(ms) / 1000, d.bookings))
        }
    }

    func testSweepTwoFourEightPlayers() {
        for n in [2, 4, 8] {
            sweep("\(n)p", players: n) { d, _, ran in
                let expected = d.format == "tauziehen" && n < 4 ? MinigameRegistry.fallbackId : d.format
                XCTAssertTrue(ran.contains(expected), "\(d.format) \(n)p ran \(ran)")
                if expected == d.format { XCTAssertEqual(d.bookings, 1, "\(d.format) \(n)p: one booking per round") }
                if d.format != "faktencheck" { XCTAssertTrue(d.bookedDeltas.allSatisfy { $0.values.allSatisfy { $0 >= 0 } }, "\(d.format): never negative") }
            }
        }
    }

    func testSweepTimerOffAndFixedTime() {
        sweep("timerAus", patch: { $0.timerAus = true }, maxMs: 8 * 60_000) { d, ms, _ in
            XCTAssertEqual(d.bookings, 1, d.format)
            XCTAssertLessThan(ms, 5 * 60_000, "\(d.format): timer off must not wait for the hour clock")
        }
        sweep("fragenZeit5", patch: { $0.fragenZeit = 5 }) { d, _, _ in XCTAssertEqual(d.bookings, 1, d.format) }
    }

    func testSweepDisconnectLateJoinerAndEveryoneGone() {
        sweep("disc", setup: { d in d.advance(1000); d.disconnect("p1") }, each: { d in if d.ticks == 120 { d.reconnect("p1") } }) { d, _, _ in
            XCTAssertEqual(d.bookings, 1, d.format)
        }
        sweep("disc-timerAus", patch: { $0.timerAus = true }, maxMs: 8 * 60_000, setup: { d in d.advance(500); d.disconnect("p2") }) { d, _, _ in
            XCTAssertEqual(d.bookings, 1, "\(d.format): a missing player never blocks the question")
        }
        sweep("late", setup: { d in d.advance(1500); d.join("p9") }) { d, _, _ in XCTAssertEqual(d.bookings, 1, d.format) }
        sweep("allGone", maxMs: 10 * 60_000, setup: { d in for b in d.bots { d.disconnect(b.id) } })
    }

    func testSweepPauseShiftsEveryClock() {
        var seen: Set<String> = []
        sweep("pause", each: { d in
            let watcher = "p1"
            guard d.s.phase == .frage, let before = d.promptDeadline(watcher), before > d.now + 1000 else { return }
            let kind = "\(d.format)-\(d.s.questionIndex)-\(d.prompt(watcher)?.kind ?? "-")"
            guard !seen.contains(kind) else { return }
            seen.insert(kind)
            d.gm(.pause(text: nil, dauerMs: nil))
            d.now += 40_000
            d.engine.tick(&d.s, now: d.now)
            d.gm(.resume)
            if let a = d.promptDeadline(watcher), a < before + 39_000 {
                d.problems.append("\(d.format): pause did not shift the deadline")
            } else if d.promptDeadline(watcher) == nil {
                d.problems.append("\(d.format): resume ended the sub-phase at once")
            }
        })
        XCTAssertGreaterThanOrEqual(seen.count, 3)
    }

    func testSweepGmToolsNeverCrashOrStick() {
        for (name, cmd) in FormatAuditTests.gmTools {
            sweep("gm-\(name)", setup: { d in
                d.advance(1500)
                d.gm(cmd)
            }, each: { d in
                if d.ticks == 40, d.s.phase == .frage { d.gm(cmd) }
            })
        }
    }

    /// GM "Frage überspringen" on a round format annuls the whole round (engine rule); "Frage tauschen" is refused mid-round.
    func testGmSkipAndReplaceMidRound() {
        for f in alle {
            let d = AuditDriver(format: f, players: 4, fragen: groesse[f])
            XCTAssertTrue(d.toQuestion())
            let before = d.balances
            d.advance(2000)
            d.botsAct()
            d.gm(.questionReplace(frageId: nil))
            XCTAssertEqual(d.s.phase, .frage, "\(f): replace is ignored while the round runs")
            d.gm(.questionSkip)
            XCTAssertNotEqual(d.s.minigame?.id, f, "\(f): skipped")
            d.finishSection()
            XCTAssertTrue(d.problems.isEmpty, "\(f): \(d.problems)")
            XCTAssertEqual(d.bookings, 0, "\(f): annulled — nothing booked")
            XCTAssertEqual(d.balances, before, f)
        }
    }
}

extension Welle2FormateTests {
    /// Quiz-Profi opens with the Tipp-Treppe: the whole show plays as planned and no round
    /// dominates (the ShowModesTests gate) over several seeds.
    func testProfiWithTippTreppeStaysBalanced() {
        XCTAssertEqual(Blueprints.blueprint(for: .profi).runden.first?.minigameId, "tipp-treppe")
        for seed in [UInt32(1), 3, 8] {
            var paid: [Int: Int] = [:]
            var last: Phase?
            let r = SimHarness.run(modus: .profi, players: 4, seed: seed, maxTicks: 400_000) { s, _ in
                if s.phase == .aufloesung, last != .aufloesung, s.currentSection?.typ == .runde {
                    paid[s.sectionIndex, default: 0] += s.lastDeltas.values.filter { $0 > 0 }.reduce(0, +)
                }
                last = s.phase
            }
            XCTAssertEqual(r.state.phase, .ende, "seed \(seed)")
            XCTAssertEqual(r.state.plan.filter { $0.typ == .runde }.map(\.minigameId), Blueprints.rounds(for: r.state.settings).map(\.minigameId))
            let totals = paid.values.map(Double.init).sorted()
            let median = totals.isEmpty ? 0 : totals[totals.count / 2]
            for (i, v) in paid { XCTAssertLessThanOrEqual(Double(v), median * 1.9 + 300, "seed \(seed): \(r.state.plan[i].minigameId) pays \(v) vs median \(median)") }
            print("PROFI-W2 seed \(seed) paid \(paid.sorted { $0.key < $1.key }.map { "\(r.state.plan[$0.key].minigameId)=\($0.value)" })")
        }
    }
}
