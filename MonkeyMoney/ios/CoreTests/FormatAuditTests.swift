import XCTest
@testable import MonkeyMoneyCore

/// Format audit (agent A): drives every existing format through the real
/// engine with bots and edge cases — 2/8 players, disconnects, late joiners,
/// timer off, fixed question time, pause/resume, every GM tool and the
/// question jokers — and gates the bugs found in the audit.
final class AuditDriver {
    let engine = Engine(catalog: TestContent.catalog)
    var s: EngineState
    var now: Millis = 1_000_000
    var rng: SeededRandom
    var bots: [SimHarness.Bot]
    var answeredKey: Set<String> = []
    /// Bots that do not act (disconnected or asleep).
    var silent: Set<PlayerId> = []
    let format: String
    var forcedSection = 0
    var bookings = 0
    var bookedDeltas: [[PlayerId: Int]] = []
    var lastPhase: Phase = .lobby
    var problems: [String] = []
    var fallbackSeen = false
    var ticks = 0

    static let all = ["vier-lianen", "bananen-basics", "kokosnuss-uhr", "bananen-tresor", "affenleiter", "pixel-dschungel", "affenbank",
                      "stinkbanane", "taschendieb", "alles-oder-banane", "lianen-finale", "monkey-market", "bananen-boerse", "affen-auktion",
                      "bananen-bluff", "lianensteg-duell", "goldener-affe", "risiko-leiter", "einer-gegen-alle", "konter-quiz",
                      "bananen-boxkampf", "bananen-tortenschlacht", "buchstaben-telegramm", "song-snippet", "song-rueckwaerts",
                      "musikvideo-raten", "wer-singts", "kokosnuss-shake"]

    init(format: String, players: Int, seed: UInt32 = 5, fragen: Int? = nil, modus: Modus = .klassik,
         schwierigkeiten: [Difficulty]? = nil, patch: (inout MatchSettings) -> Void = { _ in }) {
        self.format = format
        var settings = MatchSettings(modus: modus)
        settings.tempo = .zackig
        settings.gmLos = true
        settings.v2Formate = true
        settings.radAn = false
        settings.kategorienWahl = "aus"
        patch(&settings)
        s = EngineState(matchId: "audit", roomCode: "AUDT", seed: seed, settings: settings, now: now, gmPin: "0000")
        rng = SeededRandom(seed: seed &+ 11)
        bots = SimHarness.bots(players)
        for b in bots {
            engine.reduce(&s, .join(playerId: b.id, name: "Affe \(b.id)", avatar: Avatar(affe: "don-bananas", farbe: "gelb"), profileId: nil, isBot: true), now: now)
        }
        engine.reduce(&s, .screenPresence(true), now: now)
        engine.reduce(&s, .gm(.flowNext), now: now)
        if let i = s.plan.firstIndex(where: { $0.typ == .runde }) {
            s.plan[i].minigameId = format
            s.plan[i].fragen = fragen ?? AuditDriver.defaultFragen(format)
            s.plan[i].kategorieWahl = .keine
            s.plan[i].radDanach = false
            if let d = schwierigkeiten { s.plan[i].schwierigkeiten = d }
            forcedSection = i
        }
        engine.reduce(&s, .gm(.flowNext), now: now) // intro → explain card
    }

    /// Question count the blueprints give a format (Marathon playlist), else 3.
    static func defaultFragen(_ id: String) -> Int {
        Blueprints.blueprint(for: .marathon).runden.first { $0.minigameId == id }?.fragen ?? 3
    }

    var plugin: AnyMinigame? { s.minigame.flatMap { MinigameRegistry.plugin($0.id) } }
    var inForcedSection: Bool { s.sectionIndex == forcedSection && [.erklaerkarte, .frage, .aufloesung].contains(s.phase) }

    func advance(_ ms: Int = 250) {
        now += ms
        engine.tick(&s, now: now)
        ticks += 1
        observe()
    }

    func observe() {
        if s.phase == .aufloesung, lastPhase != .aufloesung, s.sectionIndex == forcedSection {
            bookings += 1
            bookedDeltas.append(s.lastDeltas)
        }
        lastPhase = s.phase
        if ticks % 4 == 0 { checkFallback() }
    }

    func checkFallback() {
        guard let box = s.minigame, let plugin = MinigameRegistry.plugin(box.id) else { return }
        let ctx = engine.context(s, now: now)
        if let id = plugin.gmInfo(box.data, ctx).question?.id, id.hasPrefix("fallback_") { fallbackSeen = true }
        let marker = "Monkey-Money-Studio"
        if let w = plugin.stage(box.data, s.phase == .aufloesung, ctx).wall, w.text.contains(marker) { fallbackSeen = true }
    }

    func join(_ id: PlayerId, act: Bool = true) {
        engine.reduce(&s, .join(playerId: id, name: "Spät \(id)", avatar: Avatar(), profileId: nil, isBot: true), now: now)
        if act { bots.append(SimHarness.Bot(id: id, skill: 0.6, delayMs: 1500)) }
    }

    func disconnect(_ id: PlayerId) {
        silent.insert(id)
        engine.reduce(&s, .disconnect(id), now: now)
    }

    func reconnect(_ id: PlayerId) {
        silent.remove(id)
        engine.reduce(&s, .connect(id), now: now)
    }

    func gm(_ cmd: GmCommand) { engine.reduce(&s, .gm(cmd), now: now) }

    /// Tick until the explain card is over and the forced format runs.
    @discardableResult
    func toQuestion(maxMs: Int = 120_000) -> Bool {
        var t = 0
        while s.phase != .frage && t < maxMs { advance(); botsAct(); t += 250 }
        return s.phase == .frage
    }

    /// Tick (with bots) until the forced section is over. Returns simulated ms.
    @discardableResult
    func finishSection(maxMs: Int = 30 * 60_000, each: ((AuditDriver) -> Void)? = nil) -> Int {
        var t = 0
        while inForcedSection && t < maxMs {
            advance()
            botsAct()
            each?(self)
            t += 250
        }
        if inForcedSection { problems.append("\(format): section stuck in \(s.phase) after \(maxMs / 1000) s (minigame \(s.minigame?.id ?? "-"))") }
        if fallbackSeen { problems.append("\(format): fallback question reached the players") }
        return t
    }

    func correctIndex(_ options: [ChoiceOption]) -> Int? { SimHarness.correctIndex(s, engine: engine, options: options) }

    func prompt(_ id: PlayerId) -> PlayerPrompt? { engine.playerView(s, player: id, now: now)?.prompt }

    func botsAct() {
        for bot in bots where !silent.contains(bot.id) {
            guard let view = engine.playerView(s, player: bot.id, now: now) else { continue }
            let key = "\(bot.id)-\(s.phase.rawValue)-\(s.sectionIndex)-\(s.questionIndex)-\(view.prompt.kind)-\(s.minigame?.startedAt ?? 0)"
            switch view.prompt {
            case .choice(_, let options, let chosen, _, _, _):
                guard chosen == nil else { continue }
                let elapsed = now - (s.minigame?.startedAt ?? s.phaseStartedAt)
                let need = s.minigame?.id == "pixel-dschungel" ? 9000 + bot.delayMs : bot.delayMs
                guard elapsed >= need else { continue }
                let open = options.filter { !$0.removed }
                guard !open.isEmpty else { continue }
                let pick = rng.chance(bot.skill) ? correctIndex(open) ?? open[rng.below(open.count)].id : open[rng.below(open.count)].id
                engine.reduce(&s, .player(bot.id, .choose(pick)), now: now)
            case .bank(_, let options, let chosen, let pot, _, _):
                if pot >= 200, rng.chance(0.3) { engine.reduce(&s, .player(bot.id, .bank), now: now) }
                guard chosen == nil else { continue }
                let open = options.filter { !$0.removed }
                guard !open.isEmpty else { continue }
                let pick = rng.chance(bot.skill) ? correctIndex(open) ?? open[rng.below(open.count)].id : open[rng.below(open.count)].id
                engine.reduce(&s, .player(bot.id, .choose(pick)), now: now)
            case .number(_, let min, let max, _, _, _, let current, let locked, _):
                guard current == nil, !locked else { continue }
                engine.reduce(&s, .player(bot.id, .number(min + (max - min) * rng.next())), now: now)
            case .order(_, let items, _, let locked, _):
                guard !locked, !answeredKey.contains(key) else { continue }
                answeredKey.insert(key)
                engine.reduce(&s, .player(bot.id, .order(rng.shuffled(items.map { $0.id }))), now: now)
                engine.reduce(&s, .player(bot.id, .confirm), now: now)
            case .wager(_, _, let min, let max, let step, let current, let locked, _):
                guard current == nil, !locked else { continue }
                let w = min + step * rng.below(Swift.max(1, (max - min) / Swift.max(1, step) + 1))
                engine.reduce(&s, .player(bot.id, .wager(w)), now: now)
            case .vote(_, let options, let chosen, _):
                guard chosen == nil, let o = rng.pick(options) else { continue }
                engine.reduce(&s, .player(bot.id, .vote(o.id)), now: now)
            case .explain(_, _, _, _, let ready, _, _):
                if !ready { engine.reduce(&s, .player(bot.id, .ready("bereit")), now: now) }
            case .pickPlayer(_, _, let candidates, let chosen, _):
                guard chosen == nil, let c = rng.pick(candidates) else { continue }
                engine.reduce(&s, .player(bot.id, .pickPlayer(c.id)), now: now)
            case .binary(_, _, let a, let b, let chosen, _):
                guard chosen == nil else { continue }
                engine.reduce(&s, .player(bot.id, .binary(rng.chance(0.5) ? a : b)), now: now)
            case .confirm(_, _, _, let done, _):
                if !done { engine.reduce(&s, .player(bot.id, .confirm), now: now) }
            case .chips(_, let options, let total, _, let locked, _):
                guard !locked, !answeredKey.contains(key) else { continue }
                answeredKey.insert(key)
                var placed = Array(repeating: 0, count: options.count)
                for _ in 0..<total { placed[rng.below(options.count)] += 1 }
                engine.reduce(&s, .player(bot.id, .chips(placed)), now: now)
                engine.reduce(&s, .player(bot.id, .confirm), now: now)
            case .text(let q, _, _, let submitted, _):
                guard submitted == nil, !answeredKey.contains(key + q) else { continue }
                answeredKey.insert(key + q)
                engine.reduce(&s, .player(bot.id, .text("Lüge \(bot.id) \(rng.below(999))")), now: now)
            case .buzzer(_, let armed, _, _, _):
                if armed, rng.chance(0.15) { engine.reduce(&s, .player(bot.id, .buzz(at: now)), now: now) }
            case .tapFrenzy(_, _, _, let active):
                if active, rng.chance(0.25) { engine.reduce(&s, .player(bot.id, .taps(3 + rng.below(6))), now: now) }
            case .cheer:
                if rng.chance(0.05) { engine.reduce(&s, .player(bot.id, .cheer), now: now) }
            default:
                break
            }
        }
    }

    /// Deadline the phone of `id` shows right now (any prompt kind).
    func promptDeadline(_ id: PlayerId) -> Millis? {
        switch prompt(id) {
        case .choice(_, _, _, let d, _, _), .number(_, _, _, _, _, _, _, _, let d), .order(_, _, _, _, let d),
             .wager(_, _, _, _, _, _, _, let d), .text(_, _, _, _, let d), .chips(_, _, _, _, _, let d), .pickPlayer(_, _, _, _, let d),
             .bank(_, _, _, _, _, let d), .confirm(_, _, _, _, let d), .binary(_, _, _, _, _, let d), .tapFrenzy(_, _, let d, _):
            return d
        default: return nil
        }
    }

    var balances: [PlayerId: Int] { Dictionary(uniqueKeysWithValues: s.players.map { ($0.id, $0.balance) }) }
}

final class FormatAuditTests: XCTestCase {
    // MARK: Broad edge-case sweep over all 28 formats

    func sweep(_ name: String, formats: [String] = AuditDriver.all, players: Int = 4, patch: @escaping (inout MatchSettings) -> Void = { _ in },
               maxMs: Int = 30 * 60_000, setup: ((AuditDriver) -> Void)? = nil, each: ((AuditDriver) -> Void)? = nil,
               check: ((AuditDriver, Int) -> Void)? = nil) {
        var lines: [String] = []
        for f in formats {
            if ProcessInfo.processInfo.environment["AUDIT_TRACE"] != nil { FileHandle.standardError.write(Data("AUDIT-START \(name) \(f)\n".utf8)) }
            let d = AuditDriver(format: f, players: players, patch: patch)
            guard d.toQuestion() else { XCTFail("\(name) \(f): never reached the question"); continue }
            setup?(d)
            let ms = d.finishSection(maxMs: maxMs, each: each)
            for p in d.problems { XCTFail("\(name) \(p)") }
            check?(d, ms)
            lines.append(String(format: "%@ %-24@ %4.0f s  %d bookings", name, f as NSString, Double(ms) / 1000, d.bookings))
        }
        print("AUDIT " + name + "\n" + lines.joined(separator: "\n"))
    }

    func testSweepFourPlayers() { sweep("4p") }
    func testSweepTwoPlayers() { sweep("2p", players: 2) }
    func testSweepEightPlayers() { sweep("8p", players: 8) }

    func testSweepTimerOffNothingWaitsForever() {
        // Timer off: every format must still end as soon as everybody acted — no hour-long waits.
        sweep("timerAus", patch: { $0.timerAus = true }, maxMs: 8 * 60_000)
    }

    func testSweepFixedQuestionTime() {
        sweep("fragenZeit5", patch: { $0.fragenZeit = 5 })
    }

    func testSweepDisconnectMidRound() {
        sweep("disc", setup: { d in d.advance(1000); d.disconnect("p1") }, each: { d in
            if d.ticks == 120 { d.reconnect("p1") }
        })
    }

    func testSweepEveryoneDisconnects() {
        sweep("allGone", maxMs: 10 * 60_000, setup: { d in for b in d.bots { d.disconnect(b.id) } })
    }

    func testSweepLateJoiner() {
        sweep("late", setup: { d in d.advance(1500); d.join("p9") })
    }

    func testSweepPauseShiftsEveryClock() {
        // Pause 40 s once in every sub-phase (every new prompt kind on some phone); the phone clocks must move along.
        for watcher in ["p0", "p1", "p3"] {
            var seen: Set<String> = []
            sweep("pause-\(watcher)", each: { d in
                guard d.s.phase == .frage, let before = d.promptDeadline(watcher), before > d.now + 1000 else { return }
                let kind = "\(d.format)-\(d.s.questionIndex)-\(d.prompt(watcher)?.kind ?? "-")"
                guard !seen.contains(kind) else { return }
                seen.insert(kind)
                d.gm(.pause(text: nil, dauerMs: nil))
                d.now += 40_000
                d.engine.tick(&d.s, now: d.now)
                d.gm(.resume)
                if let a = d.promptDeadline(watcher), a < before + 39_000 {
                    d.problems.append("\(d.format): pause did not shift the \(d.prompt(watcher)?.kind ?? "-") deadline of \(watcher) (\(before - d.now + 40_000) ms left before, \(a - d.now) ms after)")
                } else if d.promptDeadline(watcher) == nil {
                    d.problems.append("\(d.format): resume ended the \(kind) sub-phase of \(watcher) at once")
                }
            })
        }
    }

    // MARK: GM tools on every format

    static let gmTools: [(String, GmCommand)] = [
        ("flowNext", .flowNext), ("skip", .questionSkip), ("replace", .questionReplace(frageId: nil)),
        ("shift+", .timerShift(ms: 10_000)), ("shift-", .timerShift(ms: -60_000)), ("extend", .timerExtend(ms: 10_000)),
        ("hint", .hintGlobal), ("broken", .questionMarkBroken(grund: "kaputt", refund: "none")),
        ("encore", .encore), ("gameSkipKeep", .gameSkip(keepPoints: true)), ("gameSkip", .gameSkip(keepPoints: false)),
    ]

    func testSweepGmToolsNeverCrashOrStick() {
        // Every tool on every format would be 11 × 28 section runs (~3 min); a rotation gives each
        // format 5 different tools and every tool ≥ 12 formats — same coverage of tool × format kinds.
        let tools = FormatAuditTests.gmTools
        for (t, (name, cmd)) in tools.enumerated() {
            let formats = AuditDriver.all.enumerated().filter { (i, _) in (0..<5).contains { k in (i + k) % tools.count == t } }.map { $0.element }
            sweep("gm-\(name)", formats: formats, setup: { d in
                d.advance(1500)
                d.gm(cmd)
            }, each: { d in
                // Once more in the middle of a round format's internal flow.
                if d.ticks == 40, d.s.phase == .frage { d.gm(cmd) }
            })
        }
    }
}
