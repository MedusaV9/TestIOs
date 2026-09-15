import Foundation

/// Client-side mirror of the server level curve (server/src/gamification.js)
/// — pure Foundation so it runs in the Linux logic tests and in the widget
/// process. The SERVER is the source of truth for XP; this mirror only
/// derives display values (ring progress, "XP to next level") from a total.
///
/// Curve: threshold to REACH level n (1-based) is T(n) = 100·(n−1)·n/2
/// (triangular numbers × 100): L1=0, L2=100, L3=300, L4=600, L5=1000, …
enum LevelMath {
    /// Number of distinct level titles (levels above clamp to the last one).
    static let maxTitleLevel = 10

    /// Cumulative XP required to reach `level`.
    static func xpForLevel(_ level: Int) -> Int {
        let n = max(1, level)
        return 100 * (n - 1) * n / 2
    }

    /// 1-based level for a total XP amount (unbounded).
    static func level(forXP xp: Int) -> Int {
        var level = 1
        while xpForLevel(level + 1) <= xp { level += 1 }
        return level
    }

    /// Progress 0…1 through the current level.
    static func progress(forXP xp: Int) -> Double {
        let level = level(forXP: xp)
        let current = xpForLevel(level)
        let next = xpForLevel(level + 1)
        guard next > current else { return 0 }
        return min(1, Double(xp - current) / Double(next - current))
    }

    /// L10n key of the title for a level (clamped to the catalog).
    static func titleKey(forLevel level: Int) -> String {
        "level.title.\(min(maxTitleLevel, max(1, level)))"
    }
}
