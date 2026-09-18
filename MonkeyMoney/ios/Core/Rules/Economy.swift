import Foundation

/// Economy formulas (GAME-DESIGN §3) — pure and deterministic.
public enum Economy {
    public static func roundTo10(_ amount: Int) -> Int { Int((Double(amount) / 10).rounded()) * 10 }
    public static func roundUpTo50(_ amount: Double) -> Int { Int((amount / 50).rounded(.up)) * 50 }
    public static func roundTo50(_ amount: Int) -> Int { Int((Double(amount) / 50).rounded()) * 50 }

    // MARK: Streak (§3.1)

    /// ×1.5 from 3 correct in a row, ×2.0 from 5, hard cap ×2. `streakInclusive`
    /// counts the current correct answer.
    public static func streakFactor(_ streakInclusive: Int) -> Double {
        if streakInclusive >= 5 { return 2.0 }
        if streakInclusive >= 3 { return 1.5 }
        return 1.0
    }

    // MARK: Rückenwind (§3.4)

    /// >40 % behind the leader ⇒ ×1.25 · >60 % ⇒ ×1.5 · else ×1.
    public static func tailwindFactor(own: Int, leader: Int) -> Double {
        guard leader > 0 else { return 1.0 }
        let gap = Double(leader - max(0, own)) / Double(leader)
        if gap > 0.6 { return 1.5 }
        if gap > 0.4 { return 1.25 }
        return 1.0
    }

    /// The tailwind EXTRA can never catapult a player past the one ahead in a
    /// single booking (catching up yes, overtaking from standing no).
    public static func capTailwindExtra(extra: Int, afterBase: Int, playerAhead: Int) -> Int {
        max(0, min(extra, playerAhead - afterBase))
    }

    // MARK: Finale formula (§3.5)

    /// W_final = max(500, roundUp50(factor × G / Q)).
    public static func wFinal(gap: Int, q: Int, factor: Double = 1.25) -> Int {
        guard q > 0 else { return 500 }
        return max(500, roundUpTo50(factor * Double(max(0, gap)) / Double(q)))
    }

    /// Finale booking: correct +W, wrong −W/2, no answer 0.
    public static func finaleDelta(correct: Bool?, w: Int) -> Int {
        switch correct {
        case .some(true): return w
        case .some(false): return -w / 2
        case .none: return 0
        }
    }

    // MARK: Overdraft (§3.2)

    public static let overdraftLimit = -500
    public static let depositModeFactor = 0.75

    public static func isDepositMode(balance: Int) -> Bool { balance <= overdraftLimit }
    public static func clampToOverdraft(_ balance: Int, minimum: Int = overdraftLimit) -> Int { max(minimum, balance) }

    // MARK: Jackpot jar (§3.1/§3.2)

    public static let jackpotJarStart = 500
    public static let jackpotQuestionValue = 2000
    public static let complaintFee = 100
    public static let bananaTax = 100

    // MARK: Underdog constants (§3.4)

    public static let pityBanana = 300
    public static let applauseAlms = 25
    public static let bailoutGapShare = 0.15

    /// Social discount on joker prices: lower half −30 %, last place −50 %.
    public static func socialDiscount(place: Int, players: Int) -> Double {
        if players >= 2 && place == players { return 0.5 }
        if Double(place) > Double(players) / 2 { return 0.7 }
        return 1.0
    }

    // MARK: Match → All-Time (§3.6)

    /// AT = final balance / 10 (min 50); winner ×1.5.
    public static func allTimeFor(finalBalance: Int, isWinner: Bool) -> Int {
        let base = max(50, max(0, finalBalance) / 10)
        return isWinner ? Int((Double(base) * 1.5).rounded()) : base
    }

    /// GM score adjustment soft cap: ±20 % of the round maximum.
    public static func scoreAdjustSoftCap(questionsPerRound: Int) -> Int {
        Int((0.2 * 500 * Double(max(1, questionsPerRound))).rounded())
    }

    // MARK: Board game payouts (Spiele-Abend)

    /// One victory ladder for UNO / MADN / Bananopoly / Siedler; Affenturm pays half.
    public static let boardgameLadder = [700, 400, 200]
    public static let boardgameRest = 100

    public static func boardgamePayout(place: Int, half: Bool = false) -> Int {
        let base = place - 1 < boardgameLadder.count ? boardgameLadder[place - 1] : boardgameRest
        return half ? base / 2 : base
    }

    /// AT credit for a board game: MM/5, at least 20.
    public static func allTimeForBoardgame(mm: Int) -> Int { max(20, mm / 5) }
}

/// Level = function of lifetime AT income (§7.5): level n from 1000·n·(n+1)/2.
public enum Level {
    public static func atNeeded(for level: Int) -> Int {
        guard level > 0 else { return 0 }
        return 1000 * level * (level + 1) / 2
    }

    public static func level(forAT at: Int) -> Int {
        var n = 0
        while atNeeded(for: n + 1) <= at { n += 1 }
        return n
    }

    /// Progress 0…1 toward the next level.
    public static func progress(forAT at: Int) -> Double {
        let n = level(forAT: at)
        let lo = atNeeded(for: n)
        let hi = atNeeded(for: n + 1)
        guard hi > lo else { return 0 }
        return Double(at - lo) / Double(hi - lo)
    }
}
