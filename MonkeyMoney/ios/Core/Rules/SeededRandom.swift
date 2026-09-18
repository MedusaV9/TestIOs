import Foundation

/// Deterministic, serialisable random source (Mulberry32). Time and randomness
/// are always injected into the engine (GAME-DESIGN §0.10), so the whole match
/// can be replayed or saved — the state is a single UInt32 that lives in the
/// save file next to the engine state.
public struct SeededRandom: Codable, Equatable, Sendable {
    public private(set) var state: UInt32

    public init(seed: UInt32) {
        state = seed == 0 ? 0x9E37_79B9 : seed
    }

    public init(seed: Int) {
        self.init(seed: UInt32(truncatingIfNeeded: seed))
    }

    /// Uniform Double in [0, 1).
    public mutating func next() -> Double {
        state = state &+ 0x6D2B_79F5
        var t = state
        t = (t ^ (t >> 15)) &* (t | 1)
        t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
        let r = t ^ (t >> 14)
        return Double(r) / 4_294_967_296.0
    }

    /// Integer in `range`.
    public mutating func int(in range: ClosedRange<Int>) -> Int {
        let span = range.upperBound - range.lowerBound + 1
        return range.lowerBound + Int(next() * Double(span)) % span
    }

    /// Integer in [0, upper).
    public mutating func below(_ upper: Int) -> Int {
        guard upper > 0 else { return 0 }
        return Int(next() * Double(upper)) % upper
    }

    public mutating func chance(_ probability: Double) -> Bool {
        next() < probability
    }

    public mutating func pick<T>(_ items: [T]) -> T? {
        guard !items.isEmpty else { return nil }
        return items[below(items.count)]
    }

    /// Fisher-Yates shuffle driven exclusively by this generator.
    public mutating func shuffled<T>(_ items: [T]) -> [T] {
        var copy = items
        guard copy.count > 1 else { return copy }
        for i in stride(from: copy.count - 1, to: 0, by: -1) {
            let j = below(i + 1)
            copy.swapAt(i, j)
        }
        return copy
    }

    /// Weighted choice: returns the index of the picked weight.
    public mutating func weightedIndex(_ weights: [Double]) -> Int {
        let total = weights.reduce(0, +)
        guard total > 0 else { return 0 }
        var roll = next() * total
        for (i, w) in weights.enumerated() {
            roll -= w
            if roll < 0 { return i }
        }
        return weights.count - 1
    }
}
