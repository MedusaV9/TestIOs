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

    // MARK: Balance measurement (printed)

    func testBalanceMeasurement() {
        for players in [2, 4, 8] {
            for id in alle {
                let n = groesse[id]!
                var fmt = 0.0, basics = 0.0, playedSum = 0.0
                for seed: UInt32 in [1, 2, 3, 4, 5] {
                    let a = NFSim.run(formats: [id], players: players, seed: seed, fragen: [id: n], keepTail: false)
                    let b = NFSim.run(formats: ["bananen-basics"], players: players, seed: seed, fragen: ["bananen-basics": n], keepTail: false)
                    fmt += Double(a.paid[0] ?? 0)
                    basics += Double(b.paid[0] ?? 0)
                    playedSum += Double(a.played[0] ?? 0)
                    XCTAssertEqual(a.state.phase, .ende)
                }
                let perQ = basics / Double(n)
                print(String(format: "BALANCE-NF %@ players %d size %d: format %.0f  basics %.0f  ratio %.2f  played %.1f  ratio/played %.2f", id, players, n, fmt / 5, basics / 5,
                             fmt / max(1, basics), playedSum / 5, fmt / max(1, perQ * max(1, playedSum))))
            }
        }
    }
}
