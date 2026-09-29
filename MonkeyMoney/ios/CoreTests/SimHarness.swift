import XCTest
@testable import MonkeyMoneyCore

/// Headless bot harness shared by the simulation and balance tests: bots with
/// a skill (chance to know the answer) and a reaction delay play a complete
/// match against the pure engine; an observer sees every tick.
enum SimHarness {
    struct Bot {
        var id: PlayerId
        var skill: Double
        var delayMs: Int
    }

    struct Result {
        var state: EngineState
        var phasesSeen: Set<Phase>
        var ticks: Int
    }

    static func bots(_ players: Int, spread: Bool = true) -> [Bot] {
        (0..<players).map { i in Bot(id: "p\(i)", skill: spread ? 0.35 + Double(i) * 0.12 : 0.6, delayMs: 800 + i * 900) }
    }

    static func correctIndex(_ s: EngineState, engine: Engine, options: [ChoiceOption]) -> Int? {
        guard let box = s.minigame, let plugin = MinigameRegistry.plugin(box.id) else { return nil }
        let info = plugin.gmInfo(box.data, engine.context(s, now: 0))
        guard let k = info.question?.korrekt else { return nil }
        return options.first { $0.text == k || $0.text.hasPrefix(k) }?.id
    }

    /// Run a whole match. `observe` is called after every tick with the state.
    static func run(modus: Modus, players: Int, seed: UInt32, settingsPatch: ((inout MatchSettings) -> Void)? = nil,
                    maxTicks: Int = 200_000, bots customBots: [Bot]? = nil, observe: ((EngineState, Millis) -> Void)? = nil) -> Result {
        let engine = Engine(catalog: TestContent.catalog)
        var settings = MatchSettings(modus: modus)
        settings.tempo = .zackig
        settings.gmLos = true
        settingsPatch?(&settings)
        var s = EngineState(matchId: "test", roomCode: "TEST", seed: seed, settings: settings, now: 1_000_000, gmPin: "1234")
        var now: Millis = 1_000_000
        let bots = customBots ?? self.bots(players)
        var rng = SeededRandom(seed: seed &+ 7)
        for b in bots {
            engine.reduce(&s, .join(playerId: b.id, name: "Affe \(b.id)", avatar: Avatar(affe: "don-bananas", farbe: "gelb"), profileId: nil, isBot: true), now: now)
        }
        engine.reduce(&s, .screenPresence(true), now: now)
        engine.reduce(&s, .gm(.flowNext), now: now)
        var answeredKey: Set<String> = []
        var phasesSeen: Set<Phase> = []
        var ticks = 0
        while s.phase != .ende && ticks < maxTicks {
            ticks += 1
            now += 250
            engine.tick(&s, now: now)
            phasesSeen.insert(s.phase)
            observe?(s, now)
            for bot in bots {
                guard let view = engine.playerView(s, player: bot.id, now: now) else { continue }
                let key = "\(s.phase.rawValue)-\(s.sectionIndex)-\(s.questionIndex)-\(view.prompt.kind)-\(s.minigame?.startedAt ?? 0)-\(s.rad.subphase)"
                switch view.prompt {
                case .choice(_, let options, let chosen, _, _, _):
                    guard chosen == nil else { continue }
                    let elapsed = now - (s.minigame?.startedAt ?? s.phaseStartedAt)
                    // Nobody recognises a picture at pixel level 0 — bots wait for level 3 (9 s).
                    let need = s.minigame?.id == "pixel-dschungel" ? 9000 + bot.delayMs : bot.delayMs
                    guard elapsed >= need else { continue }
                    let open = options.filter { !$0.removed }
                    guard !open.isEmpty else { continue }
                    let pick = rng.chance(bot.skill) ? correctIndex(s, engine: engine, options: open) ?? open[rng.below(open.count)].id : open[rng.below(open.count)].id
                    engine.reduce(&s, .player(bot.id, .choose(pick)), now: now)
                case .bank(_, let options, let chosen, let pot, _, _):
                    // Bank a grown pot sometimes, always on the last beat.
                    if pot >= 200, rng.chance(0.3) { engine.reduce(&s, .player(bot.id, .bank), now: now) }
                    guard chosen == nil, !answeredKey.contains(key + "\(s.minigame?.data.count ?? 0)") else { continue }
                    let open = options.filter { !$0.removed }
                    guard !open.isEmpty else { continue }
                    let pick = rng.chance(bot.skill) ? correctIndex(s, engine: engine, options: open) ?? open[rng.below(open.count)].id : open[rng.below(open.count)].id
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
                case .text(_, _, _, let submitted, _):
                    guard submitted == nil, !answeredKey.contains(key) else { continue }
                    answeredKey.insert(key)
                    engine.reduce(&s, .player(bot.id, .text("Lüge \(bot.id) \(rng.below(999))")), now: now)
                case .buzzer(_, let armed, _, _, _):
                    if armed, rng.chance(0.15) { engine.reduce(&s, .player(bot.id, .buzz(at: now)), now: now) }
                case .feedback(_, let done):
                    if !done { engine.reduce(&s, .player(bot.id, .feedback(["gut", "ok", "alles"])), now: now) }
                case .actions(_, _, let buttons, _):
                    if let b = buttons.first(where: { $0.enabled }) { engine.reduce(&s, .player(bot.id, .button(b.id)), now: now) }
                default:
                    break
                }
            }
            if s.phase == .ende { break }
        }
        return Result(state: s, phasesSeen: phasesSeen, ticks: ticks)
    }
}
