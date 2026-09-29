import XCTest
@testable import MonkeyMoneyCore

/// Harness for the five "Neue Formate": forces a plan of chosen formats onto a
/// real engine match and plays it with skill bots that understand every prompt
/// kind the formats use (choice, binary, order, pickPlayer, cheer …).
enum NFSim {
    struct Bot {
        var id: PlayerId
        var skill: Double
        var delayMs: Int
    }

    struct Result {
        var state: EngineState
        var phasesSeen: Set<Phase>
        var ticks: Int
        /// Positive deltas booked per section index.
        var paid: [Int: Int]
        /// Questions played per section (round formats report their own count).
        var played: [Int: Int]
        var minigames: Set<String>
    }

    static let engine = Engine(catalog: TestContent.catalog)

    static func bots(_ n: Int) -> [Bot] {
        let step = n > 1 ? 0.36 / Double(n - 1) : 0
        return (0..<n).map { i in Bot(id: "p\(i)", skill: 0.35 + Double(i) * step, delayMs: 900 + i * (3600 / max(1, n))) }
    }

    static func section(_ id: String, fragen: Int, schw: [Difficulty], nr: Int) -> Section {
        Section(typ: .runde, slot: .aufbau, minigameId: id, fragen: fragen, schwierigkeiten: schw, kategorieWahl: .keine,
                radDanach: false, rundenNummer: nr, kategorie: nil, notariat: false)
    }

    static func decode<T: Decodable>(_ t: T.Type, _ s: EngineState) -> T? {
        guard let box = s.minigame else { return nil }
        return try? JSONDecoder().decode(t, from: box.data)
    }

    /// The bot's answer for the prompt on its phone (nil = nothing to do).
    static func decide(_ s: EngineState, prompt: PlayerPrompt, bot: Bot, rng: inout SeededRandom) -> [PlayerAction] {
        let info = s.minigame.flatMap { box in MinigameRegistry.plugin(box.id)?.gmInfo(box.data, engine.context(s, now: 0)).question }
        switch prompt {
        case .choice(_, let options, let chosen, _, _, _):
            guard chosen == nil else { return [] }
            let open = options.filter { !$0.removed }
            guard !open.isEmpty else { return [] }
            if s.minigame?.id == "herdentrieb" {
                // The herd leans to the first option.
                return [.choose(rng.chance(0.45) ? open[0].id : open[rng.below(open.count)].id)]
            }
            let right = info.flatMap { k in open.first { $0.text == k.korrekt }?.id }
            return [.choose(rng.chance(bot.skill) ? (right ?? open[rng.below(open.count)].id) : open[rng.below(open.count)].id)]
        case .binary(_, _, let a, let b, let chosen, _):
            guard chosen == nil else { return [] }
            let right = info.map { $0.korrekt.hasPrefix(Affenschaukel.hoeher) ? a : b } ?? a
            let wrong = right == a ? b : a
            // Higher/lower is easier than a 4-way question: skill + a coin flip.
            return [.binary(rng.chance(bot.skill) ? right : (rng.chance(0.5) ? right : wrong))]
        case .order(_, let items, _, let locked, _):
            guard !locked else { return [] }
            var order = rng.shuffled(items.map { $0.id })
            if let k = decode(KokosKopf.State.self, s) {
                order = k.sequenz
                let pPerfect = pow(bot.skill + 0.25, 1 + Double(max(0, order.count - 4)) * 0.4)
                if !rng.chance(pPerfect) {
                    for _ in 0..<(1 + rng.below(2)) {
                        let i = rng.below(order.count), j = rng.below(order.count)
                        order.swapAt(i, j)
                    }
                }
            }
            return [.order(order), .confirm]
        case .pickPlayer(_, _, let candidates, let chosen, _):
            guard chosen == nil, let c = rng.pick(candidates) else { return [] }
            return [.pickPlayer(c.id)]
        case .cheer:
            return rng.chance(0.2) ? [.cheer] : []
        case .explain(_, _, _, _, let ready, _, _):
            return ready ? [] : [.ready("bereit")]
        case .vote(_, let options, let chosen, _):
            guard chosen == nil, let o = rng.pick(options) else { return [] }
            return [.vote(o.id)]
        case .number(_, let lo, let hi, _, _, _, let current, let locked, _):
            guard current == nil, !locked else { return [] }
            return [.number(lo + (hi - lo) * rng.next())]
        case .wager(_, _, let lo, let hi, let step, let current, let locked, _):
            guard current == nil, !locked else { return [] }
            return [.wager(lo + step * rng.below(max(1, (hi - lo) / max(1, step) + 1)))]
        case .confirm(_, _, _, let done, _):
            return done ? [] : [.confirm]
        case .bank(_, let options, let chosen, _, _, _):
            guard chosen == nil, let o = options.first(where: { !$0.removed }) else { return [] }
            return [.choose(o.id)]
        case .text(_, _, _, let submitted, _):
            return submitted == nil ? [.text("Banane \(bot.id)")] : []
        case .feedback(_, let done):
            return done ? [] : [.feedback(["gut", "ok", "alles"])]
        default:
            return []
        }
    }

    /// Play a match whose rounds are replaced by `formats` (the finale etc. stay).
    static func run(formats: [String], players: Int, seed: UInt32, fragen: [String: Int] = [:], schw: [Difficulty] = [.medium],
                    modus: Modus = .quick, keepTail: Bool = true, bots customBots: [Bot]? = nil, maxTicks: Int = 120_000,
                    patch: ((inout MatchSettings) -> Void)? = nil,
                    hook: ((inout EngineState, Millis, Int) -> Void)? = nil) -> Result {
        var settings = MatchSettings(modus: modus)
        settings.tempo = .zackig
        settings.gmLos = true
        settings.radAn = false
        patch?(&settings)
        var s = EngineState(matchId: "nf", roomCode: "NEUE", seed: seed, settings: settings, now: 1_000_000, gmPin: "1234")
        var now: Millis = 1_000_000
        let bots = customBots ?? self.bots(players)
        var rng = SeededRandom(seed: seed &+ 99)
        for b in bots {
            engine.reduce(&s, .join(playerId: b.id, name: "Affe \(b.id)", avatar: Avatar(affe: "don-bananas", farbe: "gelb"), profileId: nil, isBot: true), now: now)
        }
        engine.reduce(&s, .screenPresence(true), now: now)
        engine.reduce(&s, .gm(.flowNext), now: now)
        let tail = keepTail ? s.plan.filter { $0.typ != .runde } : []
        s.plan = formats.enumerated().map { section($0.element, fragen: fragen[$0.element] ?? 4, schw: schw, nr: $0.offset + 1) } + tail
        var seen: [String: Millis] = [:]
        var phases: Set<Phase> = []
        var paid: [Int: Int] = [:]
        var played: [Int: Int] = [:]
        var minigames: Set<String> = []
        var lastPhase: Phase? = nil
        var ticks = 0
        while s.phase != .ende && ticks < maxTicks {
            ticks += 1
            now += 250
            engine.tick(&s, now: now)
            phases.insert(s.phase)
            hook?(&s, now, ticks)
            if let id = s.minigame?.id { minigames.insert(id) }
            if s.phase == .aufloesung, lastPhase != .aufloesung {
                paid[s.sectionIndex, default: 0] += s.lastDeltas.values.filter { $0 > 0 }.reduce(0, +)
                if let box = s.minigame, let plugin = MinigameRegistry.plugin(box.id) {
                    played[s.sectionIndex, default: 0] += box.roundBased ? plugin.questionsUsed(box.data) : 1
                }
            }
            lastPhase = s.phase
            for bot in bots {
                guard s.player(bot.id)?.connected == true, let view = engine.playerView(s, player: bot.id, now: now) else { continue }
                let key = "\(s.phase.rawValue)-\(s.sectionIndex)-\(s.questionIndex)-\(view.prompt.kind)-\(promptKey(view.prompt))"
                let first = seen[bot.id + key] ?? now
                seen[bot.id + key] = first
                guard now - first >= bot.delayMs else { continue }
                for a in decide(s, prompt: view.prompt, bot: bot, rng: &rng) { engine.reduce(&s, .player(bot.id, a), now: now) }
            }
        }
        return Result(state: s, phasesSeen: phases, ticks: ticks, paid: paid, played: played, minigames: minigames)
    }

    static func promptKey(_ p: PlayerPrompt) -> String {
        switch p {
        case .choice(let q, _, _, _, _, _): return q
        case .binary(let t, let sub, _, _, _, _): return t + (sub ?? "")
        case .order(let q, _, _, _, _): return q
        case .pickPlayer(let t, _, _, _, _): return t
        default: return ""
        }
    }

    // MARK: Unit-test context

    static func ctx(players: [PlayerId], now: Millis = 10_000, fragen: Int = 4, schw: [Difficulty] = [.medium], seed: UInt32 = 1,
                    patch: ((inout MatchSettings) -> Void)? = nil) -> MinigameContext {
        var settings = MatchSettings(modus: .klassik)
        settings.tempo = .normal
        patch?(&settings)
        var names: [PlayerId: String] = [:]
        for p in players { names[p] = "Affe \(p)" }
        return MinigameContext(now: now, rng: SeededRandom(seed: seed), settings: settings, players: players, names: names,
                               balances: Dictionary(uniqueKeysWithValues: players.map { ($0, 0) }), connected: Set(players), klauSchutz: [],
                               mods: QuestionMods(), section: section("x", fragen: fragen, schw: schw, nr: 1), catalog: TestContent.catalog)
    }

    static func choiceQuestions(_ n: Int, schw: Difficulty = .medium) -> [Question] {
        (0..<n).map { i in Question(id: "nf_q\(i)", kat: "kurioses_mixed", schw: schw, typ: .choice, text: "Testfrage \(i)?",
                                    antworten: ["A\(i)", "B\(i)", "C\(i)", "D\(i)"], korrekt: i % 4) }
    }
}

final class NeueFormateTests: XCTestCase {
    let alle = ["affenzahn", "letzter-affe", "affenschaukel", "herdentrieb", "kokos-kopf"]
    /// Recommended round sizes (section.fragen) — see the report for the show-mode agent.
    let groesse = ["affenzahn": 6, "letzter-affe": 10, "affenschaukel": 5, "herdentrieb": 5, "kokos-kopf": 4]

    // MARK: Whole matches + balance gate

    /// One match per (players, seed): a standard 4-question Bananen-Basics round first
    /// (the show's economic unit), then all five new formats at their recommended size.
    /// Every format must finish, and a round of it must pay 0.5–1.8× the standard round.
    func testAllNewFormatsFinishAndPayLikeAStandardRound() {
        var ratios: [String: [Double]] = [:]
        var lines: [String] = []
        for (players, seeds) in [(2, [UInt32(1), 2]), (4, [1, 2]), (8, [1])] {
            for seed in seeds {
                let plan = ["bananen-basics"] + alle
                var sizes = groesse
                sizes["bananen-basics"] = 4
                let r = NFSim.run(formats: plan, players: players, seed: seed, fragen: sizes, keepTail: false)
                XCTAssertEqual(r.state.phase, .ende, "\(players)p seed \(seed) stuck in \(r.state.phase)")
                // Herdentrieb needs a herd: from 3 players (2 players get the fallback format).
                let expected = players >= 3 ? alle : alle.filter { $0 != "herdentrieb" }
                XCTAssertTrue(Set(expected).isSubset(of: r.minigames), "\(players)p: not all formats ran: \(r.minigames.sorted())")
                let base = Double(max(1, r.paid[0] ?? 0))
                for (i, id) in alle.enumerated() where expected.contains(id) {
                    let ratio = Double(r.paid[i + 1] ?? 0) / base
                    ratios["\(id) \(players)p", default: []].append(ratio)
                    lines.append(String(format: "%@ %dp seed %d: paid %d vs standard round %.0f → %.2f (played %d)", id, players, seed, r.paid[i + 1] ?? 0, base, ratio, r.played[i + 1] ?? 0))
                }
            }
        }
        print("BALANCE-NF\n" + lines.joined(separator: "\n"))
        for (key, rs) in ratios {
            let avg = rs.reduce(0, +) / Double(rs.count)
            XCTAssertGreaterThanOrEqual(avg, 0.5, "\(key) pays too little: \(avg)")
            XCTAssertLessThanOrEqual(avg, 1.8, "\(key) pays too much: \(avg)")
        }
    }

    // MARK: Pure rules

    func testAffenzahnSpeedPodium() {
        let w = 250
        let r = Affenzahn.rangliste([("a", 3000, true), ("b", 1200, true), ("c", 800, false), ("d", nil, nil), ("e", 2000, true), ("f", 2500, true)], wert: w)
        let by = Dictionary(uniqueKeysWithValues: r.map { ($0.player, $0) })
        XCTAssertEqual(r.first?.player, "b", "fastest correct first")
        XCTAssertEqual(by["b"]?.platz, 1)
        XCTAssertEqual(by["e"]?.platz, 2)
        XCTAssertEqual(by["f"]?.platz, 3)
        XCTAssertEqual(by["a"]?.platz, 4)
        XCTAssertEqual(by["b"]?.points, NeueFormate.betrag(w, NeueFormate.Anteil.affenzahn[0]))
        XCTAssertEqual(by["e"]?.points, NeueFormate.betrag(w, NeueFormate.Anteil.affenzahn[1]))
        XCTAssertEqual(by["f"]?.points, NeueFormate.betrag(w, NeueFormate.Anteil.affenzahn[2]))
        XCTAssertEqual(by["a"]?.points, NeueFormate.betrag(w, NeueFormate.Anteil.affenzahnRest))
        XCTAssertEqual(by["c"]?.points, 0, "wrong answers are free but pay nothing, even when fast")
        XCTAssertEqual(by["d"]?.points, 0)
        // Equal times share the place.
        let tie = Affenzahn.rangliste([("x", 1000, true), ("y", 1000, true), ("z", 1500, true)], wert: w)
        XCTAssertEqual(tie.filter { $0.platz == 1 }.count, 2)
        XCTAssertEqual(tie.first { $0.player == "z" }?.platz, 3)
    }

    func testLetzterAffeVerdictMercyAndWinner() {
        let u = LetzterAffe.urteil(alive: ["a", "b", "c"]) { ["a": true, "b": false][$0] ?? nil }
        XCTAssertEqual(u.survivors, ["a"])
        XCTAssertEqual(u.out, ["b", "c"], "no answer knocks you out too")
        XCTAssertFalse(u.gnade)
        let mercy = LetzterAffe.urteil(alive: ["a", "b"]) { _ in false }
        XCTAssertEqual(mercy.survivors, ["a", "b"], "all wrong: nobody falls")
        XCTAssertTrue(mercy.gnade)
        // A perfect bot against random guessers is the last monkey, the round ends early,
        // the winner gets the bonus and the others tipped once.
        let bots = [NFSim.Bot(id: "p0", skill: 1.0, delayMs: 900), NFSim.Bot(id: "p1", skill: 0, delayMs: 1500), NFSim.Bot(id: "p2", skill: 0, delayMs: 2100)]
        var end: LetzterAffe.State?
        let r = NFSim.run(formats: ["letzter-affe"], players: 3, seed: 7, fragen: ["letzter-affe": 12], keepTail: false, bots: bots) { s, _, _ in
            if s.phase == .aufloesung, end == nil { end = NFSim.decode(LetzterAffe.State.self, s) }
        }
        XCTAssertEqual(r.state.phase, .ende)
        guard let st = end else { return XCTFail("no reveal") }
        XCTAssertEqual(st.sieger, ["p0"])
        XCTAssertEqual(st.bonus["p0"], NeueFormate.betrag(st.bonusWert, NeueFormate.Anteil.letzterBonus))
        XCTAssertLessThan(st.gespielt, 12, "the round ends as soon as one monkey is left")
        XCTAssertTrue(Set(st.tipps.keys).isSubset(of: ["p1", "p2"]), "only knocked-out monkeys tip")
        XCTAssertEqual(st.leben["p0"], LetzterAffe.startLeben, "the perfect monkey never lost a life")
        XCTAssertTrue(st.out.allSatisfy { st.leben[$0.player] == 0 }, "out = no lives left")
        for (p, t) in st.tipps { XCTAssertEqual(st.tippGewinn[p] ?? 0, t == "p0" ? NeueFormate.betrag(st.bonusWert, NeueFormate.Anteil.tippRichtig) : 0) }
    }

    func testAffenschaukelAnchorAndStreak() {
        let questions = TestContent.catalog.questions.filter { $0.typ == .schaetz && $0.schaetz != nil }
        XCTAssertGreaterThan(questions.count, 100)
        var rng = SeededRandom(seed: 3)
        for q in questions {
            let spec = q.schaetz!
            let jahr = Affenschaukel.istJahr(spec, text: q.text)
            let tol = Affenschaukel.toleranz(spec, jahr: jahr)
            for _ in 0..<3 {
                let a = Affenschaukel.anker(spec, text: q.text, rng: &rng)
                XCTAssertGreaterThan(abs(a - spec.richtwert), tol, "\(q.id): anchor \(a) inside the tolerance zone of \(spec.richtwert) ± \(tol)")
                if jahr { XCTAssertEqual(a, a.rounded(), "\(q.id): years stay whole") }
            }
        }
        let w = 250
        XCTAssertEqual(Affenschaukel.punkte(wert: w, serie: 1), NeueFormate.betrag(w, NeueFormate.Anteil.schaukel))
        XCTAssertEqual(Affenschaukel.punkte(wert: w, serie: 2), NeueFormate.betrag(w, NeueFormate.Anteil.schaukel * NeueFormate.Anteil.schaukelSerie2))
        XCTAssertEqual(Affenschaukel.punkte(wert: w, serie: 5), NeueFormate.betrag(w, NeueFormate.Anteil.schaukel * NeueFormate.Anteil.schaukelSerie3))
    }

    func testHerdentriebMajorityTieAndLoneWolf() {
        let w = 250
        let herd = Herdentrieb.auswertung([("a", 0), ("b", 0), ("c", 0), ("d", 1), ("e", 1), ("f", 2)], optionen: 3, wert: w)
        XCTAssertEqual(herd.mehrheit, [0])
        XCTAssertEqual(herd.punkte["a"], NeueFormate.betrag(w, NeueFormate.Anteil.herde))
        XCTAssertEqual(herd.punkte["d"], 0)
        XCTAssertEqual(herd.einzel, ["f"])
        XCTAssertEqual(herd.counts, [3, 2, 1])
        let tie = Herdentrieb.auswertung([("a", 0), ("b", 0), ("c", 1), ("d", 1)], optionen: 2, wert: w)
        XCTAssertEqual(tie.mehrheit, [0, 1])
        XCTAssertEqual(tie.punkte["c"], NeueFormate.betrag(w, NeueFormate.Anteil.herdeGleichstand))
        let loners = Herdentrieb.auswertung([("a", 0), ("b", 1), ("c", 2)], optionen: 3, wert: w)
        XCTAssertTrue(loners.mehrheit.isEmpty, "a herd needs at least two monkeys")
        XCTAssertEqual(Set(loners.einzel), ["a", "b", "c"])
        XCTAssertTrue(loners.punkte.values.allSatisfy { $0 == 0 })
        XCTAssertGreaterThanOrEqual(Herdentrieb.fragen.count, 160)
        for q in Herdentrieb.fragen {
            XCTAssert((2...4).contains(q.optionen.count), "2–4 options: \(q.text)")
            XCTAssertEqual(q.optionen.count, q.emojis.count, q.text)
            XCTAssertEqual(Set(q.optionen).count, q.optionen.count, "distinct options: \(q.text)")
        }
        XCTAssertEqual(Set(Herdentrieb.fragen.map { $0.text }).count, Herdentrieb.fragen.count, "no duplicate prompts")
    }

    func testKokosKopfPartialAndFastestPerfect() {
        let w = 250
        let seq = [3, 1, 4, 0]
        let r = KokosKopf.bewerte([("a", [3, 1, 4, 0], 5000), ("b", [3, 1, 4, 0], 4000), ("c", [3, 4, 1, 0], 3000), ("d", nil, nil)], sequenz: seq, wert: w)
        XCTAssertEqual(Set(r.perfekt), ["a", "b"])
        XCTAssertEqual(r.schnellster, ["b"], "fastest PERFECT, not fastest overall")
        XCTAssertEqual(r.punkte["b"], NeueFormate.betrag(w, NeueFormate.Anteil.kokosPerfekt) + NeueFormate.betrag(w, NeueFormate.Anteil.kokosSchnellster))
        XCTAssertEqual(r.punkte["a"], NeueFormate.betrag(w, NeueFormate.Anteil.kokosPerfekt))
        XCTAssertEqual(r.richtige["c"], 2)
        XCTAssertEqual(r.punkte["c"], NeueFormate.betrag(w, NeueFormate.Anteil.kokosPosition * 2))
        XCTAssertNil(r.punkte["d"])
        XCTAssertEqual(KokosKopf.laenge(schritt: 0), 4)
        XCTAssertEqual(KokosKopf.laenge(schritt: 3), 7)
    }

    /// Explain cards quote the real payout constants (texts are generated from them).
    func testRulesTextsMatchThePayouts() {
        let texts = alle.compactMap { MinigameRegistry.plugin($0)?.meta }.map { ($0.id, ($0.regeln + [$0.gewinn, $0.erklaerung]).joined(separator: " ")) }
        XCTAssertEqual(texts.count, 5)
        let f = NeueFormate.faktor
        let expect: [String: [String]] = [
            "affenzahn": NeueFormate.Anteil.affenzahn.map(f) + [f(NeueFormate.Anteil.affenzahnRest)],
            "letzter-affe": [f(NeueFormate.Anteil.ueberlebt), f(NeueFormate.Anteil.letzterBonus), f(NeueFormate.Anteil.tippRichtig)],
            "affenschaukel": [f(NeueFormate.Anteil.schaukel)],
            "herdentrieb": [f(NeueFormate.Anteil.herde), f(NeueFormate.Anteil.herdeGleichstand)],
            "kokos-kopf": [f(NeueFormate.Anteil.kokosPerfekt), f(NeueFormate.Anteil.kokosPosition), f(NeueFormate.Anteil.kokosSchnellster)],
        ]
        for (id, text) in texts { for e in expect[id] ?? [] { XCTAssertTrue(text.contains(e), "\(id): rules text lacks \(e)") } }
    }
}
