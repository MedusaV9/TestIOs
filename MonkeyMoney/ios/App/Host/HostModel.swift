import Foundation
import SwiftUI
import Combine

/// The iPad host: owns the embedded show server, the content catalogue,
/// profiles (meta store) and save slots. Publishes the stage view.
@MainActor
final class HostModel: ObservableObject {
    enum Screen: Equatable { case menu, modes, lobby, stage, profiles, shop, boards, settings, saves, howto }

    @Published var screen: Screen = .menu
    @Published var stage: StageView?
    @Published var lanIP: String = HTTPServer.lanIPv4() ?? "—"
    @Published var port: UInt16 = 8080
    @Published var serverError: String?
    @Published var meta = MetaStore()
    @Published var showGmCode = false
    @Published var showQrLarge = false
    @Published var gmPanelOpen = false
    @Published var autosaveAvailable: SaveSlot?
    @Published var slots: [SaveSlot?] = [nil, nil, nil]
    @Published var settingsDraft = MatchSettings(modus: .klassik)
    @Published var lastAudioMusic: String?
    @Published var localSeatNames: [String] = []
    @Published var toast: String?

    let catalog: ContentCatalog
    let audio = AudioManager.shared
    let regie = SoundRegie(audio: AudioManager.shared)
    private(set) var server: ShowServer?
    private var cancellables: Set<AnyCancellable> = []
    private var lastPhase: Phase?

    struct SaveSlot: Codable, Identifiable {
        var id: Int
        var savedAt: Millis
        var state: EngineState
        var label: String
    }

    init() {
        let dir = Bundle.main.url(forResource: "Content", withExtension: nil) ?? Bundle.main.bundleURL.appendingPathComponent("Content")
        catalog = (try? ContentCatalog.load(from: dir)) ?? .empty
        meta = Self.loadMeta()
        loadSlots()
    }

    // MARK: Persistence

    static var appSupport: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("MonkeyMoney", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func loadMeta() -> MetaStore {
        let url = appSupport.appendingPathComponent("meta.json")
        guard let data = try? Data(contentsOf: url), let m = try? JSONDecoder().decode(MetaStore.self, from: data) else { return MetaStore() }
        return m
    }

    func persistMeta(_ m: MetaStore) {
        meta = m
        let url = Self.appSupport.appendingPathComponent("meta.json")
        if let data = try? JSONEncoder().encode(m) { try? data.write(to: url, options: .atomic) }
    }

    func loadSlots() {
        for i in 0..<3 { slots[i] = readSlot(i + 1) }
        autosaveAvailable = readSlot(0)
        if let a = autosaveAvailable, a.state.phase == .ende || a.state.phase == .lobby { autosaveAvailable = nil }
    }

    func readSlot(_ n: Int) -> SaveSlot? {
        let url = Self.appSupport.appendingPathComponent(n == 0 ? "autosave.json" : "slot-\(n).json")
        guard let data = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(SaveSlot.self, from: data) else { return nil }
        return s
    }

    func writeSlot(_ n: Int) {
        guard let srv = server else { return }
        let state = srv.withHub { $0.state }
        let label = "\(state.settings.modus.title) · \(state.players.count) Spieler · \(state.phase == .lobby ? "Lobby" : "Runde \(state.currentSection?.rundenNummer ?? 0)")"
        let slot = SaveSlot(id: n, savedAt: Int(Date().timeIntervalSince1970 * 1000), state: state, label: label)
        let url = Self.appSupport.appendingPathComponent(n == 0 ? "autosave.json" : "slot-\(n).json")
        if let data = try? JSONEncoder().encode(slot) { try? data.write(to: url, options: .atomic) }
        loadSlots()
        if n > 0 { toast = "💾 Gespeichert in Slot \(n)" }
    }

    func deleteSlot(_ n: Int) {
        try? FileManager.default.removeItem(at: Self.appSupport.appendingPathComponent(n == 0 ? "autosave.json" : "slot-\(n).json"))
        loadSlots()
    }

    // MARK: Server lifecycle

    var joinURL: String { server?.withHub { $0.joinURL } ?? "http://\(lanIP):\(port)" }
    var gmURL: String { server?.withHub { $0.gmURL } ?? "http://\(lanIP):\(port)/gm" }
    var roomCode: String { server?.withHub { $0.state.roomCode } ?? "----" }
    var gmPin: String { server?.withHub { $0.state.gmPin } ?? "----" }

    /// Start (or restart) the show server with fresh room state.
    func startShow(settings: MatchSettings, restoring: EngineState? = nil) {
        stopShow()
        regie.reset()
        var rng = SeededRandom(seed: UInt32(truncatingIfNeeded: Int(Date().timeIntervalSince1970)))
        let now = Int(Date().timeIntervalSince1970 * 1000)
        lanIP = HTTPServer.lanIPv4() ?? "127.0.0.1"
        var state = restoring ?? EngineState(matchId: "m-\(now)", roomCode: RoomHub.makeRoomCode(rng: &rng), seed: rng.state, settings: settings, now: now, gmPin: RoomHub.makeGmPin(rng: &rng))
        if restoring != nil {
            // Loaded match: keep code & PIN, players rejoin by reconnecting; everyone starts disconnected.
            for i in state.players.indices { state.players[i].connected = state.players[i].isBot }
            if state.phase != .lobby, !state.paused { state.paused = true; state.pausedAt = now; state.pauseText = "💾 Spiel geladen — weiter mit ▶" }
        }
        let engine = Engine(catalog: catalog)
        let roots = ShowServer.Roots(
            web: Bundle.main.url(forResource: "Web", withExtension: nil) ?? Bundle.main.bundleURL.appendingPathComponent("Web"),
            fonts: Bundle.main.url(forResource: "Fonts", withExtension: nil) ?? Bundle.main.bundleURL.appendingPathComponent("Fonts"),
            content: Bundle.main.url(forResource: "Content", withExtension: nil) ?? Bundle.main.bundleURL.appendingPathComponent("Content"),
            audio: Bundle.main.url(forResource: "Audio", withExtension: nil))
        var started: ShowServer? = nil
        for p in UInt16(8080)...UInt16(8086) {
            let hub = RoomHub(engine: engine, state: state, joinBaseURL: "http://\(lanIP):\(p)")
            let s = ShowServer(port: p, hub: hub, meta: meta, roots: roots)
            s.onMetaChanged = { [weak self] m in Task { @MainActor in self?.persistMeta(m) } }
            s.onStageChanged = { [weak self] view in Task { @MainActor in self?.stageUpdated(view) } }
            do {
                try s.start()
                started = s
                port = p
                break
            } catch {
                s.http.stop()
                serverError = error.localizedDescription
            }
        }
        guard let srv = started else { serverError = "Server konnte nicht starten (Ports 8080–8086 belegt)."; return }
        server = srv
        srv.withHub { $0.engine.reduce(&$0.state, .screenPresence(true), now: now) }
        serverError = nil
        screen = .lobby
        stage = server?.withHub { $0.stageView(now: now) }
    }

    func stopShow() {
        server?.stop()
        server = nil
        audio.stopMusic()
    }

    func stageUpdated(_ view: StageView) {
        let previous = stage
        stage = view
        if view.phase != lastPhase {
            lastPhase = view.phase
            if [.zwischenstand, .rad, .lobby, .siegerehrung, .brettspiel, .halbzeit].contains(view.phase) { writeSlot(0) }
            if view.phase == .lobby, previous?.phase == .ende || previous?.phase == .siegerehrung { screen = .lobby }
            if view.phase != .lobby, screen == .lobby { screen = .stage }
        }
        // Audio: the regie turns transitions into stingers, the reveal beat and the beds.
        let musicOn = view.scene.musicAllowed && (server?.withHub { $0.state.settings.musik } ?? true)
        regie.update(view, musicOn: musicOn)
        if case .frage(_, let extra, _, _, _) = view.scene, case .song(let songId, let snippet, let playAt, _, _, _, _, _) = extra {
            if let at = playAt, at != lastSnippetAt {
                lastSnippetAt = at
                audio.playSnippet(songId: songId, snippet: snippet)
            }
        }
    }
    private var lastSnippetAt: Millis?

    // MARK: Stage actions

    func command(_ cmd: GmCommand) {
        server?.stageCommand(cmd)
    }

    func localAction(_ pid: PlayerId, _ action: PlayerAction) {
        server?.stagePlayerAction(pid, action)
    }

    func addBot() {
        guard let srv = server else { return }
        let personas = [("Kokos 🤖", "gitti-giro", "gruen"), ("Splitter 🤖", "kiki-krawall", "rot"), ("Banana Joe 🤖", "schnarch-schorsch", "gelb"), ("Prof. Pavian 🤖", "baron-von-bananenstein", "lila"), ("Chaos-Kalle 🤖", "kahuna-kalle", "tuerkis")]
        let n = srv.withHub { $0.state.players.filter { $0.isBot }.count }
        guard n < personas.count else { return }
        let p = personas[n]
        let now = Int(Date().timeIntervalSince1970 * 1000)
        srv.queue.async {
            srv.hub.engine.reduce(&srv.hub.state, .join(playerId: "bot_\(n)", name: p.0, avatar: Avatar(affe: p.1, farbe: p.2), profileId: nil, isBot: true), now: now)
        }
        startBotBrain()
    }

    private var botTimer: Timer?

    /// Bots answer with a persona skill/tempo — the same headless logic the tests use.
    func startBotBrain() {
        guard botTimer == nil else { return }
        botTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.botTick() }
        }
    }

    private func botTick() {
        guard let srv = server else { return }
        srv.queue.async {
                let now = Int(Date().timeIntervalSince1970 * 1000)
                let bots = srv.hub.state.players.filter { $0.isBot }
                guard !bots.isEmpty else { return }
                var rng = SeededRandom(seed: UInt32(truncatingIfNeeded: now))
                for (i, bot) in bots.enumerated() {
                    guard let v = srv.hub.engine.playerView(srv.hub.state, player: bot.id, now: now) else { continue }
                    let skill = [0.85, 0.6, 0.55, 0.75, 0.5][i % 5]
                    let elapsed = now - (srv.hub.state.minigame?.startedAt ?? srv.hub.state.phaseStartedAt)
                    guard elapsed > 2500 + i * 1500 else { continue }
                    var action: PlayerAction? = nil
                    switch v.prompt {
                    case .choice(_, let opts, let chosen, _, _, _):
                        guard chosen == nil else { continue }
                        let open = opts.filter { !$0.removed }
                        var pick = rng.pick(open)?.id
                        if rng.chance(skill), let box = srv.hub.state.minigame, let plugin = MinigameRegistry.plugin(box.id) {
                            let info = plugin.gmInfo(box.data, srv.hub.engine.context(srv.hub.state, now: now))
                            if let k = info.question?.korrekt, let c = open.first(where: { $0.text == k || $0.text.hasPrefix(k) }) { pick = c.id }
                        }
                        if let p = pick { action = .choose(p) }
                    case .bank(_, let opts, let chosen, let pot, _, _):
                        if pot >= 400, rng.chance(0.3) { srv.hub.engine.reduce(&srv.hub.state, .player(bot.id, .bank), now: now) }
                        if chosen == nil, let o = rng.pick(opts) { action = .choose(o.id) }
                    case .number(_, let lo, let hi, _, _, _, let cur, let locked, _): if cur == nil, !locked { action = .number(lo + (hi - lo) * rng.next()) }
                    case .wager(_, _, let lo, let hi, let step, let cur, let locked, _): if cur == nil, !locked { action = .wager(lo + step * rng.below(max(1, (hi - lo) / max(1, step) + 1))) }
                    case .vote(_, let opts, let chosen, _): if chosen == nil, let o = rng.pick(opts) { action = .vote(o.id) }
                    case .explain(_, _, _, _, let ready, _, _): if !ready { action = .ready("bereit") }
                    case .order(_, let items, _, let locked, _): if !locked { srv.hub.engine.reduce(&srv.hub.state, .player(bot.id, .order(rng.shuffled(items.map { $0.id }))), now: now); action = .confirm }
                    case .pickPlayer(_, _, let cands, let chosen, _): if chosen == nil, let c = rng.pick(cands) { action = .pickPlayer(c.id) }
                    case .binary(_, _, let a, let b, let chosen, _): if chosen == nil { action = .binary(rng.chance(0.5) ? a : b) }
                    case .confirm(_, _, _, let done, _): if !done { action = .confirm }
                    case .chips(_, let opts, let total, _, let locked, _):
                        if !locked { var placed = Array(repeating: 0, count: opts.count); for _ in 0..<total { placed[rng.below(max(1, opts.count))] += 1 }; srv.hub.engine.reduce(&srv.hub.state, .player(bot.id, .chips(placed)), now: now); action = .confirm }
                    case .text(_, _, _, let submitted, _): if submitted == nil { action = .text("Bananen-Fakt \(rng.below(99))") }
                    case .buzzer(_, let armed, _, _, _): if armed, rng.chance(0.2) { action = .buzz(at: now) }
                    case .feedback(_, let done): if !done { action = .feedback(["🍌", "👍", "Alles"]) }
                    case .actions(_, _, let buttons, _): if let b = buttons.first(where: { $0.enabled }), rng.chance(0.6) { action = .button(b.id) }
                    case .cards(_, let cards, let buttons, _, _):
                        if let c = cards.first(where: { !$0.removed }) { action = .choose(c.id) } else if let b = buttons.first(where: { $0.enabled && $0.id != "banane" }) { action = .button(b.id) }
                    default: break
                    }
                    if let a = action { srv.hub.engine.reduce(&srv.hub.state, .player(bot.id, a), now: now) }
                }
        }
    }

    func removeBots() {
        guard let srv = server else { return }
        let now = Int(Date().timeIntervalSince1970 * 1000)
        srv.queue.async {
            for b in srv.hub.state.players.filter({ $0.isBot }) { srv.hub.engine.reduce(&srv.hub.state, .leave(b.id), now: now) }
        }
    }

    /// Player seated on the iPad itself (pass-and-play seat in board games).
    func loadSlotAndStart(_ slot: SaveSlot) {
        startShow(settings: slot.state.settings, restoring: slot.state)
        screen = slot.state.phase == .lobby ? .lobby : .stage
    }
}

extension StageScene {
    /// Music beds are silenced during the song formats' snippet playback.
    var musicAllowed: Bool {
        if case .frage(_, let extra, _, _, _) = self, case .song = extra { return false }
        return true
    }
}
