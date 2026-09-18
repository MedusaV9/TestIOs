import Foundation

/// Kokosnuss-Shake — the global tiebreaker (§2.11): 3-s countdown, 10 s of
/// tap frenzy on a coconut, taps reported in 1-s batches, plausibility cap
/// 12 taps/s. The winner takes the tie (+50 MM); a renewed tie → 3-s sudden death.
public enum KokosnussShake: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var contestants: [PlayerId]
        public var startAt: Millis
        public var endAt: Millis
        public var taps: [PlayerId: Int]
        public var suddenDeath: Bool
        public var finished: Bool
        public var lastBatchAt: [PlayerId: Millis]
    }

    public static let meta = MinigameMeta(
        id: "kokosnuss-shake", name: "Kokosnuss-Shake", emoji: "🥥",
        kurz: "Gleichstand! 10 Sekunden Kokosnuss-Schütteln entscheiden.",
        erklaerung: "Gleichstand an der Spitze! Die Kokosnuss entscheidet: Nach dem 3-Sekunden-Countdown schüttelt ihr zehn Sekunden lang so schnell ihr könnt. Wer mehr schafft, gewinnt den Gleichstand (+50 MM). Erneuter Gleichstand = 3 Sekunden Sudden Death.",
        contentKind: .none, roundBased: true, streak: false, jokerAktionen: [], isMc: false, musik: "bomb_pass"
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        // Contestants: everyone sharing the top balance (at least two).
        let top = ctx.balances.values.max() ?? 0
        var tied = ctx.players.filter { (ctx.balances[$0] ?? 0) == top }
        if tied.count < 2 { tied = Array(ctx.players.prefix(2)) }
        return State(contestants: tied, startAt: ctx.now + 3000, endAt: ctx.now + 13_000, taps: [:], suddenDeath: false, finished: false, lastBatchAt: [:])
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        guard case .taps(let n) = action, state.contestants.contains(player), ctx.now >= state.startAt, ctx.now <= state.endAt + 1500, !state.finished else { return }
        let since = ctx.now - (state.lastBatchAt[player] ?? state.startAt)
        let cap = max(12, 12 * max(1, since) / 1000 + 12)
        state.taps[player, default: 0] += min(max(0, n), cap)
        state.lastBatchAt[player] = ctx.now
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {
        guard !state.finished, ctx.now >= state.endAt + 1500 else { return }
        let best = state.contestants.map { state.taps[$0] ?? 0 }.max() ?? 0
        let winners = state.contestants.filter { (state.taps[$0] ?? 0) == best }
        if winners.count > 1, !state.suddenDeath {
            state.suddenDeath = true
            state.contestants = winners
            state.taps = [:]
            state.startAt = ctx.now + 1500
            state.endAt = state.startAt + 3000
            return
        }
        state.finished = true
    }

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.finished }

    static func winner(_ s: State, ctx: MinigameContext) -> PlayerId? {
        let best = s.contestants.map { s.taps[$0] ?? 0 }.max() ?? 0
        let w = s.contestants.filter { (s.taps[$0] ?? 0) == best }
        return w.count == 1 ? w[0] : w.min { ctx.players.firstIndex(of: $0) ?? 0 < ctx.players.firstIndex(of: $1) ?? 0 }
    }

    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] {
        var s: [PlayerId: Int] = [:]
        for p in ctx.players { s[p] = 0 }
        if let w = winner(state, ctx: ctx) { s[w] = 50 }
        return s
    }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        Dictionary(uniqueKeysWithValues: ctx.players.map { ($0, Outcome(correct: state.contestants.contains($0) ? ($0 == winner(state, ctx: ctx)) : nil, countsForStreak: false, detail: "\(state.taps[$0] ?? 0) Taps")) })
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        var extra: [String] = state.contestants.map { "\(ctx.name($0)): \(state.taps[$0] ?? 0) 🥥" }
        if let w = winner(state, ctx: ctx), revealed { extra.append("🏆 \(ctx.name(w)) gewinnt den Gleichstand!") }
        return MinigameStageOutput(wall: nil, extra: .card(title: state.suddenDeath ? "SUDDEN DEATH!" : (ctx.now < state.startAt ? "Bereit … \(max(0, (state.startAt - ctx.now + 999) / 1000))" : "SCHÜTTELN!"), lines: extra), title: meta.name)
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed { let w = winner(state, ctx: ctx); return .reveal(title: w == player ? "🥥 GLEICHSTAND GEWONNEN!" : "Kokosnuss-Shake", correct: state.contestants.contains(player) ? w == player : nil, delta: w == player ? 50 : 0, detail: "\(state.taps[player] ?? 0) Taps", streak: 0, speedBonus: nil) }
        guard state.contestants.contains(player) else { return .cheer(title: "🥥 Kokosnuss-Shake", subtitle: state.contestants.map { ctx.name($0) }.joined(separator: " vs "), taps: 0) }
        return .tapFrenzy(title: ctx.now < state.startAt ? "Bereit …" : "SCHÜTTELN! 🥥", count: state.taps[player] ?? 0, deadline: state.endAt, active: ctx.now >= state.startAt && ctx.now <= state.endAt)
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        (nil, Dictionary(uniqueKeysWithValues: state.contestants.map { ($0, "\(state.taps[$0] ?? 0) Taps") }))
    }
}
