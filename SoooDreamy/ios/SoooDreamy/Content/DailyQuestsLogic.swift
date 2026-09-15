import Foundation

// Paar-Tagesquests ⚔️ — pure deterministic core, UI-free.
//
// The day's 3 quests derive from coupleId + dateKey (djb2 → SplitMix64),
// so both devices agree on the set without any server round-trip. State
// lives on the relay: one `dailyquests` session per day (payload
// `{dateKey}`), moves `{kind: "quest_done", questIndex}` — shared
// checkboxes, first tap wins. Each check makes the relay emit a
// `quest_done` app event (XP hook for the platform layer). The client
// completing the last quest ends the day's session with
// `result: {done, total, dateKey}`; streaks derive from the history.

/// One quest of the bundled pool (see Data/DailyQuestsData.swift).
struct DailyQuestItem: Identifiable, Hashable {
    let id: Int
    let emoji: String
    let text: LText
}

// MARK: - Events

enum DailyQuestsEvent {
    case done(member: String, questIndex: Int)
}

// MARK: - State

struct DailyQuestsState {
    /// Quest pool index → member who checked it FIRST (shared checkbox).
    var doneBy: [Int: String]

    var doneCount: Int { doneBy.count }
}

// MARK: - Rules

enum DailyQuests {
    static let questsPerDay = 3

    /// The day's quest indexes into the pool — deterministic from
    /// coupleId + dateKey, identical on both devices, always distinct.
    static func questIndexes(coupleId: String, dateKey: String,
                             poolSize: Int = ContentPack.dailyQuests.count) -> [Int] {
        let seedText = "quests|" + dateKey + "|" + coupleId
        let seed = seedText.unicodeScalars.reduce(5381 as UInt64) {
            ($0 << 5) &+ $0 &+ UInt64($1.value)
        }
        var generator = SeededGenerator(seed: Int(truncatingIfNeeded: seed))
        var picked: [Int] = []
        while picked.count < Swift.min(questsPerDay, poolSize) {
            let index = generator.int(upTo: poolSize)
            if !picked.contains(index) {
                picked.append(index)
            }
        }
        return picked
    }

    /// The day's quests, resolved against the bundled pool.
    static func quests(coupleId: String, dateKey: String) -> [DailyQuestItem] {
        questIndexes(coupleId: coupleId, dateKey: dateKey).map { ContentPack.dailyQuests[$0] }
    }

    /// Reduces ordered quest_done events. Defensive: indexes outside the
    /// day's set are skipped, the FIRST check per quest wins (re-checks by
    /// the partner or double sends change nothing).
    static func reduce(events: [DailyQuestsEvent], validIndexes: [Int]) -> DailyQuestsState {
        var state = DailyQuestsState(doneBy: [:])
        for case .done(let member, let index) in events {
            guard validIndexes.contains(index), state.doneBy[index] == nil else { continue }
            state.doneBy[index] = member
        }
        return state
    }

    /// Streak = consecutive fully-completed days ending today — or ending
    /// yesterday while today is still in progress (checkins pattern).
    /// Pure: `today` is injected, no OS clock.
    static func streak(completedDays: Set<String>, today: String) -> Int {
        var cursor: String? = completedDays.contains(today) ? today : previousDay(of: today)
        var count = 0
        while let day = cursor, completedDays.contains(day) {
            count += 1
            cursor = previousDay(of: day)
        }
        return count
    }

    /// "YYYY-MM-DD" → the previous day's key (UTC math — dateKeys are plain
    /// calendar dates, so the timezone only needs to be self-consistent).
    static func previousDay(of dateKey: String) -> String? {
        let parts = dateKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = 12
        guard let date = calendar.date(from: components),
              let previous = calendar.date(byAdding: .day, value: -1, to: date) else {
            return nil
        }
        let result = calendar.dateComponents([.year, .month, .day], from: previous)
        return String(format: "%04d-%02d-%02d",
                      result.year ?? 0, result.month ?? 0, result.day ?? 0)
    }
}
