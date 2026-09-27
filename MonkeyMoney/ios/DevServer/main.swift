import Foundation
import MonkeyMoneyCore

// Linux/macOS dev server: runs the real ShowHost (the same object the iPad app
// runs) against the repo resources, so the whole UI — stage, phones, cockpit —
// can be opened and tested in any browser.
//
//   swift run mm-dev-server [port] [flags…]
//     league          League Edition catalogue
//     demo=MODUS      open a lobby right away (quick|klassik|marathon)
//     bots=N          …with N bots
//     autostart       …and start the match
//
//   http://localhost:PORT/stage   Bühne (what the iPad shows)
//   http://<ip>:PORT/j/CODE       Handy
//   http://<ip>:PORT/gm?code=CODE Regiepult
let args = CommandLine.arguments
let port = UInt16(args.count > 1 ? args[1] : "8080") ?? 8080
func flag(_ name: String) -> String? {
    args.first { $0.hasPrefix(name + "=") }.map { String($0.dropFirst(name.count + 1)) }
}
let league = args.contains("league")
let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let resources = here.appendingPathComponent("Resources")
let loaded = try ContentCatalog.load(from: resources.appendingPathComponent("Content"))
let catalog = league ? loaded.filtered(pool: QuestionSets.set(QuestionSets.leagueId)?.pool ?? []) : loaded
let storage = URL(fileURLWithPath: flag("storage") ?? NSTemporaryDirectory()).appendingPathComponent("mm-dev-\(port)")
let roots = ShowServer.Roots(web: resources.appendingPathComponent("Web"), fonts: resources.appendingPathComponent("Fonts"),
                             content: resources.appendingPathComponent("Content"), audio: resources.appendingPathComponent("Audio"))
let host = ShowHost(config: .init(storage: storage, roots: roots, catalog: catalog, edition: league ? "League Edition" : "",
                                  editionQuestionSet: league ? QuestionSets.leagueId : QuestionSets.alleId, openHostAPI: true, ports: port...port))
func nowMs() -> Int { Int(Date().timeIntervalSince1970 * 1000) }
// Dev console: /api/dev/next advances like the stage's button, /api/dev/stage|gm dump the views.
host.extraRoutes = { req in
    guard req.path.hasPrefix("/api/dev/") else { return nil }
    let server = host.server!
    switch req.path {
    case "/api/dev/next": server.stageCommand(.flowNext); return .text("ok")
    case "/api/dev/stage": return .json(server.withHub { Wire.encode($0.stageView(now: nowMs())) })
    case "/api/dev/gm": return .json(server.withHub { Wire.encode($0.gmView(now: nowMs())) })
    case "/api/dev/player":
        let id = req.query["id"] ?? ""
        return .json(server.withHub { hub in Wire.encode(hub.engine.playerView(hub.state, player: id, now: nowMs())) })
    case "/api/dev/pin": return .text(server.withHub { $0.state.gmPin })
    case "/api/dev/code": return .text(server.withHub { $0.state.roomCode })
    default: return .notFound()
    }
}
host.onStage = { view in
    if ProcessInfo.processInfo.environment["MM_VERBOSE"] != nil { print("[stage] \(view.phase) \(view.sectionLabel) advance=\(view.advanceLabel ?? "-")") }
}
try host.start()
if let m = flag("demo") {
    var s = host.defaultSettings(Modus(rawValue: m) ?? .quick)
    if let t = flag("tempo"), let v = Tempo(rawValue: t) { s.tempo = v }
    host.startShow(settings: s)
    if let n = Int(flag("bots") ?? "0"), n > 0 {
        host.addBots(n)
    }
    if args.contains("autostart") { host.server.stageCommand(.flowNext) }
}
let code = host.server.withHub { $0.state.roomCode }
print("Monkey Money dev server on \(host.baseURL)")
print("Bühne: http://localhost:\(host.port)/stage · Handy: \(host.baseURL)/j/\(code) · Regie: \(host.baseURL)/gm?code=\(code) (PIN \(host.server.withHub { $0.state.gmPin }))")
RunLoop.main.run()
