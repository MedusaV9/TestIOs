import Foundation

// MARK: - Welle 2: shared plumbing
//
// Three round-based formats (🪜 Tipp-Treppe, ✅ Faktencheck, 🪢 Tauziehen) built
// like the "Neue Formate": several internal questions with a short mini-reveal
// in between, one booking at the end of the round, payouts as multiples of
// F = question value. Decisions never depend on Dictionary/Set order (players
// are walked in `ctx.players` order, randomness only from `ctx.rng`).
//
// Stage widgets: the formats ride on the existing `StageExtra.card` case — the
// single line starts with `Welle2.marker` and carries a JSON payload that
// stage/extras-neu2.js decodes (plain cards of other formats render as before).

public enum Welle2 {
    /// Payout multipliers relative to F (100 / 250 / 500 / 1.000) — the single place
    /// to tune the three formats; explain cards and phone texts are generated from them.
    public enum Anteil {
        // 🪜 Tipp-Treppe: right answer by the hint step it was locked at
        // (0 = before any hint, 1–3 = after hint 1–3). Wrong or none: 0.
        public static let treppe: [Double] = [2.0, 1.4, 0.9, 0.5]
        // ✅ Faktencheck: base per right fact × in-round streak multiplier
        // (1st right ×1, 2nd in a row ×1,5, 3rd ×2, from the 4th ×3 = cap).
        public static let faktBasis = 0.6
        public static let faktSerie: [Double] = [1.0, 1.5, 2.0, 3.0]
        /// A wrong fact costs this (never below a balance of 0); no answer costs nothing.
        public static let faktFalsch = 0.2
        // 🪢 Tauziehen: per member of the winning team × F × questions/4,
        // MVP bonus × F, draw: every team member × F × questions/4.
        public static let zugSieg = 1.0
        public static let zugMvp = 0.5
        public static let zugRemis = 0.4
        /// Rope pulls: every right answer 1, the fastest right answer of a question 2.
        public static let zugNormal = 1
        public static let zugSchnellster = 2
        /// Questions per "unit" of the team payout (1.0 F at 4 questions, 1.5 F at 6 …).
        public static let zugFragenBasis = 4.0
    }

    /// Mini-reveal lengths (base ms, scaled by tempo).
    enum Reveal {
        static let treppe = 3500
        static let fakt = 3000
        static let zug = 3200
    }

    /// Tipp-Treppe: base interval between two hints (tempo-scaled; the question clock is 4 intervals).
    static let treppeStufeMs = 4000
    /// Faktencheck: the short blitz clock of a fact.
    static let faktTimerMs = 7000

    /// First line of a Welle-2 stage card: marker + JSON payload.
    public static let marker = "§W2§"

    /// Wrap a widget payload into the stage card the web widgets decode (sorted keys → deterministic wire).
    static func karte<T: Encodable>(_ titel: String, _ payload: T) -> StageExtra {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let json = (try? enc.encode(payload)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return .card(title: titel, lines: [marker + json])
    }

    /// Decode a Welle-2 card payload (tests / tools).
    public static func payload<T: Decodable>(_ t: T.Type, from extra: StageExtra) -> T? {
        guard case .card(_, let lines) = extra, let first = lines.first, first.hasPrefix(marker) else { return nil }
        return try? JSONDecoder().decode(t, from: Data(first.dropFirst(marker.count).utf8))
    }

    /// "2×" · "1,4×" — shared multiplier formatting.
    static func f(_ k: Double) -> String { NeueFormate.faktor(k) }

    /// Blitz clock for rapid formats: tempo × wheel factor; the Show-Master's fixed
    /// time per question wins; timer off = until everybody answered.
    static func blitzTimer(_ base: Int, ctx: MinigameContext) -> Int {
        if ctx.timerAus { return MinigameContext.unlimitedMs }
        if let fixed = ctx.settings.fragenZeit { return max(3000, Int(Double(fixed * 1000) * ctx.mods.timerFaktor)) }
        return max(3000, Int(Double(ctx.ms(base)) * ctx.mods.timerFaktor))
    }

    /// Player → value maps as the widgets receive them (only the given players, stable order irrelevant in JSON objects).
    static func map(_ values: [PlayerId: Int], _ players: [PlayerId]) -> [String: Int] {
        var out: [String: Int] = [:]
        for p in players { if let v = values[p] { out[p] = v } }
        return out
    }
}
