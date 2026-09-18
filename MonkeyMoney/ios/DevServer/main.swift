import Foundation
import MonkeyMoneyCore

// Linux/macOS dev server: runs the real ShowServer against the repo resources so
// the web client (player + GM) can be tested in a browser without an iPad.
//   swift run mm-dev-server [port] [modus] [tempo] [league]   ("league" = League Edition catalogue)
let args = CommandLine.arguments
let port = UInt16(args.count > 1 ? args[1] : "8080") ?? 8080
let modus = Modus(rawValue: args.count > 2 ? args[2] : "quick") ?? .quick
let league = args.contains("league")
let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let resources = here.appendingPathComponent("Resources")
let loaded = try ContentCatalog.load(from: resources.appendingPathComponent("Content"))
let catalog = league ? loaded.filtered(pool: QuestionSets.set(QuestionSets.leagueId)?.pool ?? []) : loaded
let engine = Engine(catalog: catalog)
var rng = SeededRandom(seed: UInt32(truncatingIfNeeded: Int(Date().timeIntervalSince1970)))
let now = Int(Date().timeIntervalSince1970 * 1000)
var settings = MatchSettings(modus: modus)
settings.tempo = Tempo(rawValue: args.count > 3 ? args[3] : "normal") ?? .normal
if league { settings.applyQuestionSet(QuestionSets.leagueId) }
let state = EngineState(matchId: "dev-\(now)", roomCode: RoomHub.makeRoomCode(rng: &rng), seed: rng.state, settings: settings, now: now, gmPin: RoomHub.makeGmPin(rng: &rng))
let ip = HTTPServer.lanIPv4() ?? "127.0.0.1"
let hub = RoomHub(engine: engine, state: state, joinBaseURL: "http://\(ip):\(port)")
let server = ShowServer(port: port, hub: hub, meta: MetaStore(), roots: ShowServer.Roots(web: resources.appendingPathComponent("Web"), fonts: resources.appendingPathComponent("Fonts"), content: resources.appendingPathComponent("Content"), audio: resources.appendingPathComponent("Audio")))
// Dev-only stage console: /api/dev/next advances like the iPad's button, /api/dev/stage dumps the stage view.
server.extraRoutes = { req in
    guard req.path.hasPrefix("/api/dev/") else { return nil }
    switch req.path {
    case "/api/dev/next": server.stageCommand(.flowNext); return .text("ok")
    case "/api/dev/stage": return .json(server.withHub { Wire.encode($0.stageView(now: Int(Date().timeIntervalSince1970 * 1000))) })
    case "/api/dev/gm": return .json(server.withHub { Wire.encode($0.gmView(now: Int(Date().timeIntervalSince1970 * 1000))) })
    case "/api/dev/pin": return .text(server.withHub { $0.state.gmPin })
    default: return .notFound()
    }
}
server.edition = league ? "League Edition" : ""
try server.start()
print("Monkey Money dev server on http://\(ip):\(server.port)  room \(state.roomCode)  GM-PIN \(state.gmPin)  join \(hub.joinURL)")
print("Stage: GET /api/room · Player: /j/\(state.roomCode) · GM: /gm?code=\(state.roomCode)")
// Stage console: print scene changes, auto-advance nothing (gmLos: the stage button is /api/stage/next).
server.onStageChanged = { view in
    if ProcessInfo.processInfo.environment["MM_VERBOSE"] != nil { print("[stage] \(view.phase) \(view.sectionLabel) advance=\(view.advanceLabel ?? "-")") }
}
RunLoop.main.run()
