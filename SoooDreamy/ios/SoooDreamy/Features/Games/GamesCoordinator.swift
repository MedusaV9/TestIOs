import Foundation
import Observation

/// v3.0 parallel game sessions: one `GameEngine` per game type plus the list
/// of ALL open sessions (for the hub's "your running games" banners and the
/// "Du bist dran!" hints). Routes socket events to the right engine and
/// keeps the open list fresh — the per-type engines stay the single source
/// of truth inside each game view.
@MainActor
@Observable
final class GamesCoordinator {

    /// All non-ended sessions of the couple, newest first.
    var openSessions: [GameSession] = []

    @ObservationIgnored private var engines: [GameKind: GameEngine] = [:]

    /// Error sink shared by all engines (wired to `AppState.handleAPIError`).
    @ObservationIgnored var onError: ((Error) -> Void)?

    /// The lazily-created engine tracking sessions of one game type.
    func engine(for kind: GameKind) -> GameEngine {
        if let engine = engines[kind] { return engine }
        let engine = GameEngine(kind: kind)
        engine.onError = { [weak self] error in self?.onError?(error) }
        engines[kind] = engine
        return engine
    }

    /// Fetch all open sessions and seed the per-type engines (app start,
    /// tab appear). Best effort — errors stay quiet like `GameEngine.resume`.
    func refresh(api: API?) async {
        guard let api, let games = try? await api.openGames() else { return }
        openSessions = games
        for game in games {
            guard let kind = game.kind else { continue }
            engine(for: kind).adopt(game)
        }
    }

    /// Feed every `.serverEvent` here — updates the open list and forwards
    /// to the engines (which dedupe/filter themselves, so double-feeding
    /// from individual game views stays harmless).
    func handle(_ event: ServerEvent) {
        switch event.type {
        case .gameCreated, .gameStarted, .gameEnded:
            guard let game = event.decode(GameOnlyResponse.self)?.game else { return }
            if let kind = game.kind {
                engine(for: kind).handle(event)
            }
            upsert(game)
        case .gameMove:
            guard let payload = event.decode(GameMovePayload.self) else { return }
            for engine in engines.values {
                engine.handle(event)
            }
            // Keep the open list's move tails fresh for the turn hints.
            if let idx = openSessions.firstIndex(where: { $0.id == payload.gameId }),
               !openSessions[idx].moves.contains(where: { $0.id == payload.move.id }) {
                openSessions[idx].moves.append(payload.move)
            }
        default:
            break
        }
    }

    /// Server switch / logout: drop every session context.
    func reset() {
        openSessions = []
        for engine in engines.values {
            engine.adopt(nil)
        }
    }

    private func upsert(_ game: GameSession) {
        openSessions.removeAll { $0.id == game.id }
        if game.state != "ended" {
            openSessions.insert(game, at: 0)
        }
    }

    /// "Du bist dran!" heuristic, mirroring the server's inbox `games`
    /// bucket: a lobby invitation from the partner, or an active game whose
    /// last move came from the partner.
    func awaitingMe(_ game: GameSession, myId: String?) -> Bool {
        guard let myId else { return false }
        if game.state == "lobby" { return game.createdBy != myId }
        guard game.state == "active", let last = game.moves.last else { return false }
        return last.memberId != myId
    }
}
