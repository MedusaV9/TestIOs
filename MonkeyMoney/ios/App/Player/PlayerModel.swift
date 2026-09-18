import Foundation
import SwiftUI
import Combine

/// Native phone client: connects to the iPad's WebSocket, keeps the session
/// token for reconnects, renders PlayerView / GmView.
@MainActor
final class PlayerModel: NSObject, ObservableObject {
    enum Screen: Equatable { case join, playing, gm }
    enum Status: Equatable { case offline, connecting, online }

    @Published var screen: Screen = .join
    @Published var status: Status = .offline
    @Published var host: String = UserDefaults.standard.string(forKey: "mm.host") ?? ""
    @Published var roomCode: String = UserDefaults.standard.string(forKey: "mm.code") ?? ""
    @Published var name: String = UserDefaults.standard.string(forKey: "mm.name") ?? ""
    @Published var avatar: Avatar = Avatar(wire: UserDefaults.standard.string(forKey: "mm.avatar") ?? "")
    @Published var view: PlayerView?
    @Published var gmView: GmView?
    @Published var error: String?
    @Published var toast: String?
    @Published var gmPin: String = ""
    @Published var isGm = false
    @Published var showScanner = false
    @Published var profileEvent: ProfileEvent?

    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var sessionToken: String? { get { UserDefaults.standard.string(forKey: "mm.token.\(roomCode)") } set { UserDefaults.standard.set(newValue, forKey: "mm.token.\(roomCode)") } }
    private var gmToken: String? { get { UserDefaults.standard.string(forKey: "mm.gmtoken.\(roomCode)") } set { UserDefaults.standard.set(newValue, forKey: "mm.gmtoken.\(roomCode)") } }
    private var pingTimer: Timer?
    private var reconnectDelay: Double = 0.8
    private var wantConnection = false
    private var lastMomentId = 0

    var deviceToken: String {
        if let t = UserDefaults.standard.string(forKey: "mm.device") { return t }
        let t = UUID().uuidString.lowercased()
        UserDefaults.standard.set(t, forKey: "mm.device")
        return t
    }

    /// Accepts `monkeymoney://join?code=LZVQ&host=192.168.2.224:8080`,
    /// `http(s)://<host>/j/LZVQ` and `.../gm?code=LZVQ`.
    func handle(url: URL) {
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var code = comps?.queryItems?.first { $0.name == "code" }?.value
        var hostPort = comps?.queryItems?.first { $0.name == "host" }?.value
        if let range = url.path.range(of: "/j/") { code = String(url.path[range.upperBound...]).prefix(4).uppercased() }
        if url.scheme?.hasPrefix("http") == true, let h = url.host {
            hostPort = h + (url.port.map { ":\($0)" } ?? "")
        }
        if let c = code { roomCode = c.uppercased() }
        if let h = hostPort { host = h }
        if url.path.contains("/gm") { isGm = true }
        if !roomCode.isEmpty, !host.isEmpty, !name.isEmpty || isGm { connect() }
    }

    func handleScanned(_ text: String) {
        guard let url = URL(string: text) else { return }
        handle(url: url)
        showScanner = false
    }

    // MARK: Connection

    func connect() {
        guard !host.isEmpty, roomCode.count == 4 else { error = "Bitte iPad-Adresse und Raum-Code eingeben."; return }
        UserDefaults.standard.set(host, forKey: "mm.host")
        UserDefaults.standard.set(roomCode, forKey: "mm.code")
        UserDefaults.standard.set(name, forKey: "mm.name")
        UserDefaults.standard.set(avatar.wire, forKey: "mm.avatar")
        wantConnection = true
        error = nil
        open()
    }

    func disconnect() {
        wantConnection = false
        pingTimer?.invalidate()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        status = .offline
        screen = .join
        view = nil
        gmView = nil
    }

    private func open() {
        guard wantConnection else { return }
        status = .connecting
        let hostClean = host.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let url = URL(string: "ws://\(hostClean)/ws") else { error = "Ungültige Adresse"; return }
        let s = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        session = s
        let t = s.webSocketTask(with: url)
        task = t
        t.resume()
        receive(on: t)
    }

    private func sendHello() {
        let hello: ClientMessage = isGm
            ? .hello(roomCode: roomCode, role: .gm, sessionToken: gmToken, name: nil, avatar: nil, gmPin: gmPin, profileId: nil, profilePin: nil, deviceToken: deviceToken)
            : .hello(roomCode: roomCode, role: .player, sessionToken: sessionToken, name: name, avatar: avatar.wire, gmPin: nil, profileId: nil, profilePin: nil, deviceToken: deviceToken)
        send(hello)
    }

    func send(_ msg: ClientMessage) {
        guard let t = task, let s = String(data: Wire.encode(msg), encoding: .utf8) else { return }
        t.send(.string(s)) { _ in }
    }

    func act(_ action: PlayerAction) {
        Haptics.tap()
        send(.action(action, idem: UUID().uuidString))
    }

    func gm(_ cmd: GmCommand) {
        Haptics.tap()
        send(.gm(cmd))
    }

    private func receive(on t: URLSessionWebSocketTask) {
        t.receive { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                switch result {
                case .failure:
                    self.dropped()
                case .success(let msg):
                    if case .string(let text) = msg, let m = Wire.decode(ServerMessage.self, Data(text.utf8)) { self.handle(m) }
                    if t === self.task { self.receive(on: t) }
                }
            }
        }
    }

    private func dropped() {
        status = .offline
        pingTimer?.invalidate()
        guard wantConnection else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in self?.open() }
        reconnectDelay = min(6, reconnectDelay * 1.6)
    }

    private func handle(_ m: ServerMessage) {
        switch m {
        case .welcome(_, let token, let role, let serverTime):
            if role == .gm { gmToken = token; screen = .gm } else { sessionToken = token; screen = .playing }
            ServerClock.offset = serverTime - Int(Date().timeIntervalSince1970 * 1000)
            status = .online
            reconnectDelay = 0.8
        case .player(let v):
            view = v
            if let h = v.haptic { h == "success" ? Haptics.success() : Haptics.error() }
            if let mo = v.moments.last, mo.id > lastMomentId { lastMomentId = mo.id; if mo.art != "sound" { showToast(mo.text) } }
        case .gm(let g):
            gmView = g
        case .pong(let t0, let serverTime):
            let rtt = Int(Date().timeIntervalSince1970 * 1000) - t0
            ServerClock.offset = serverTime + rtt / 2 - Int(Date().timeIntervalSince1970 * 1000)
        case .error(let code, let message):
            error = message
            if code == "room" || code == "pin" || code == "no-session" { sessionToken = nil; gmToken = nil; if code != "no-session" { disconnect() } }
        case .closed:
            showToast("Der Raum wurde geschlossen.")
            disconnect()
        case .profileEvent(let e):
            profileEvent = e
        case .stage:
            break
        }
    }

    func showToast(_ t: String) {
        toast = t
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { [weak self] in if self?.toast == t { self?.toast = nil } }
    }
}

extension PlayerModel: URLSessionWebSocketDelegate {
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        Task { @MainActor in
            self.sendHello()
            self.pingTimer?.invalidate()
            self.pingTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.send(.ping(t0: Int(Date().timeIntervalSince1970 * 1000))) }
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        Task { @MainActor in self.dropped() }
    }
}
