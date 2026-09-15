import Foundation

// Replay & Zuschauer-Modus 🎬 — pure deterministic core, UI-free.
//
// The architecture gifts us this feature: deterministic reducers +
// persisted move lists (`GET /api/games` keeps `moves` incl. `createdAt`)
// mean a replay is just the move list played back step by step, and live
// spectating is the same feed driven by `game_move` frames (the relay
// broadcasts to ALL sockets of the couple — a second device included).
//
// This core covers the pure parts: the time-lapse (real move gaps — hours
// in async games! — compressed into watchable playback delays), the
// "Wende-Moment" (turning point) and the highlight rules per game type.

enum Replay {
    /// Playback pacing at 1× speed: every real gap between two moves is
    /// compressed into this window (async pauses become a beat, rapid-fire
    /// stays readable).
    static let minDelay = 0.55
    static let maxDelay = 2.2

    /// Compressed playback delay for one real gap (seconds) at a speed
    /// multiplier (1, 2, 4 …). Deterministic, monotonic in the gap.
    static func playbackDelay(forGap gap: Double, speed: Double) -> Double {
        let clamped = Swift.min(maxDelay, Swift.max(minDelay, gap))
        return clamped / Swift.max(0.25, speed)
    }

    /// Delays for a whole move list from its real inter-move gaps
    /// (`gaps[0]` is the pause before the first move — usually 0).
    static func delays(gaps: [Double], speed: Double) -> [Double] {
        gaps.map { playbackDelay(forGap: $0, speed: speed) }
    }

    /// The "Wende-Moment": the LAST highlight that is not the final move —
    /// the dramatic beat before the ending. nil when the match had none.
    static func turningPoint(highlights: [Bool]) -> Int? {
        guard highlights.count > 1 else { return nil }
        for index in stride(from: highlights.count - 2, through: 0, by: -1)
        where highlights[index] {
            return index
        }
        return nil
    }

    /// Whether a move counts as a highlight. `magnitude` is the move's
    /// pre-extracted weight (sunk ships, points scored, 1 for a completed
    /// match/correct guess) — the mapping stays testable without JSON.
    static func isHighlight(gameType: String, moveKind: String, magnitude: Int) -> Bool {
        switch (gameType, moveKind) {
        case ("battleship", "report"):
            return magnitude >= 1 // a ship went down
        case ("battleship", "reveal"), ("stadtlandfluss", "reveal"), ("twotruths", "reveal"):
            return true // the big unmasking
        case ("kniffel", "score"):
            return magnitude >= 25 // a monster entry
        case ("pictionary", "guess"):
            return magnitude >= 1 // correct guess
        case ("movieroulette", "swipe"):
            return magnitude >= 1 // completed a match
        case ("dailyquests", "quest_done"):
            return true
        default:
            return false
        }
    }

    /// Feed emoji per (game type, move kind) — generic fallback included.
    static func stepEmoji(gameType: String, moveKind: String) -> String {
        switch moveKind {
        case "commit": return "🔐"
        case "reveal": return "🔓"
        case "salvo": return "💣"
        case "report": return "🛟"
        case "round_start": return "🏁"
        case "stroke": return "🖌️"
        case "guess": return "💬"
        case "roll": return "🎲"
        case "score": return "✏️"
        case "swipe": return gameType == "movieroulette" ? "🍿" : "👉"
        case "statements": return "🗣️"
        case "rate": return "⚖️"
        case "quest_done": return "✅"
        default: return "▶️"
        }
    }
}
