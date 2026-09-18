import Foundation

/// Question difficulty (GAME-DESIGN §0). Raw values match the compiled content.
public enum Difficulty: String, Codable, CaseIterable, Sendable, Comparable {
    case easy, medium, hard, ultrahard

    public var rank: Int {
        switch self {
        case .easy: return 0
        case .medium: return 1
        case .hard: return 2
        case .ultrahard: return 3
        }
    }

    public static func < (lhs: Difficulty, rhs: Difficulty) -> Bool { lhs.rank < rhs.rank }

    public var label: String {
        switch self {
        case .easy: return "Leicht"
        case .medium: return "Mittel"
        case .hard: return "Schwer"
        case .ultrahard: return "ULTRAHARD"
        }
    }

    public var oneUp: Difficulty {
        switch self {
        case .easy: return .medium
        case .medium: return .hard
        case .hard, .ultrahard: return .ultrahard
        }
    }
}

/// MM base values and timers (GAME-DESIGN §3.1, binding numbers).
public enum Money {
    /// Base value of a correct answer in Monkey Money.
    public static func value(_ d: Difficulty) -> Int {
        switch d {
        case .easy: return 100
        case .medium: return 250
        case .hard: return 500
        case .ultrahard: return 1000
        }
    }

    /// Answer window in milliseconds.
    public static func timerMs(_ d: Difficulty) -> Int {
        switch d {
        case .easy, .medium: return 15_000
        case .hard: return 20_000
        case .ultrahard: return 25_000
        }
    }

    /// Speed bonus with a kink (no blind-tap exploit):
    /// bonus = value × 0.5 × clamp((T − t) / (0.8 × T), 0, 1), rounded to 10s.
    public static func speedBonus(value: Int, answeredAfterMs: Int, timerMs: Int) -> Int {
        guard timerMs > 0 else { return 0 }
        let share = Double(timerMs - answeredAfterMs) / (0.8 * Double(timerMs))
        let factor = min(1, max(0, share))
        return Int((Double(value) * 0.5 * factor / 10).rounded()) * 10
    }

    /// Full payout for a correct answer: base + speed bonus.
    public static func questionWin(_ d: Difficulty, answeredAfterMs: Int, timerMs: Int) -> Int {
        let v = value(d)
        return v + speedBonus(value: v, answeredAfterMs: answeredAfterMs, timerMs: timerMs)
    }

    /// Display format "1.234 MM" (German grouping).
    public static func format(_ amount: Int) -> String {
        "\(formatNumber(amount)) MM"
    }

    public static func formatNumber(_ amount: Int) -> String {
        let negative = amount < 0
        var digits = Array(String(abs(amount)))
        var out: [Character] = []
        for (i, c) in digits.reversed().enumerated() {
            if i > 0 && i % 3 == 0 { out.append(".") }
            out.append(c)
        }
        digits = out.reversed()
        return (negative ? "-" : "") + String(digits)
    }

    /// Signed display "+380 MM" / "−100 MM".
    public static func formatDelta(_ amount: Int) -> String {
        amount >= 0 ? "+\(format(amount))" : "−\(format(-amount))"
    }
}
