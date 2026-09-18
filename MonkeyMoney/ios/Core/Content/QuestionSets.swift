import Foundation

/// A named question pool the Show-Master can pick with one tap ("Fragen-Set").
/// `pool` holds top-level category ids and/or sub-category ids; empty = whole
/// catalogue. Sets are presets over `MatchSettings.kategorienPool` — a custom
/// category selection is the set `eigen`.
public struct QuestionSet: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var emoji: String
    public var beschreibung: String
    public var pool: [String]
    /// Kid-safe questions only (Familien-Modus pool).
    public var kidSafe: Bool

    public init(id: String, name: String, emoji: String, beschreibung: String, pool: [String], kidSafe: Bool = false) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.beschreibung = beschreibung
        self.pool = pool
        self.kidSafe = kidSafe
    }
}

public enum QuestionSets {
    public static let alleId = "alle"
    public static let eigenId = "eigen"
    public static let leagueId = "league"

    public static let all: [QuestionSet] = [
        QuestionSet(id: alleId, name: "Alles", emoji: "🌍", beschreibung: "Alle 14 Kategorien, bunt gemischt", pool: []),
        QuestionSet(id: leagueId, name: "League of Legends", emoji: "⚔️", beschreibung: "Nur Runeterra: Champions, Lore, Items, Esports", pool: ["league_of_legends"]),
        QuestionSet(id: "gaming", name: "Gaming", emoji: "🎮", beschreibung: "LoL, Minecraft, Nintendo, Pokémon, Fortnite, Retro, Esport", pool: ["gaming"]),
        QuestionSet(id: "popkultur", name: "Popkultur", emoji: "🎬", beschreibung: "Filme & Serien, Musik, Internet & Memes", pool: ["filme_serien", "musik", "internet_memes"]),
        QuestionSet(id: "wissen", name: "Wissen", emoji: "🔬", beschreibung: "Wissenschaft, Geschichte, Geographie, Tiere, Technik", pool: ["wissenschaft", "geschichte", "geographie", "tiere_natur", "technik_autos"]),
        QuestionSet(id: "deutschland", name: "Deutschland", emoji: "🇩🇪", beschreibung: "Deutschland-Spezial: Politik, Sprache, Alltag, Gesetze", pool: ["deutschland_spezial"]),
        QuestionSet(id: "sport", name: "Sport", emoji: "⚽", beschreibung: "Bundesliga, Olympia, Rekorde", pool: ["sport"]),
        QuestionSet(id: "kinder", name: "Kinder & Familie", emoji: "🧒", beschreibung: "Alle Kategorien, nur kindgerechte Fragen", pool: [], kidSafe: true),
        QuestionSet(id: eigenId, name: "Eigene Auswahl", emoji: "🎛️", beschreibung: "Kategorien und Unterkategorien selbst zusammenstellen", pool: []),
    ]

    public static func set(_ id: String) -> QuestionSet? { all.first { $0.id == id } }

    /// Set id that describes a pool (a preset when it matches exactly, else `eigen`/`alle`).
    public static func id(forPool pool: [String], kidSafe: Bool) -> String {
        if let match = all.first(where: { $0.id != eigenId && Set($0.pool) == Set(pool) && $0.kidSafe == kidSafe }) { return match.id }
        return pool.isEmpty ? alleId : eigenId
    }
}

/// What the GM cockpit shows for a question set: the preset plus how many
/// questions the current catalogue can serve for it.
public struct QuestionSetInfo: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var emoji: String
    public var beschreibung: String
    public var anzahl: Int
    public var aktiv: Bool
}

/// A category (or sub-category) with its question count for the pool picker.
public struct CategoryInfo: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var emoji: String
    public var farbe: String
    public var anzahl: Int
    public var gewaehlt: Bool
    public var unter: [CategoryInfo]

    public init(id: String, name: String, emoji: String, farbe: String, anzahl: Int, gewaehlt: Bool, unter: [CategoryInfo] = []) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.farbe = farbe
        self.anzahl = anzahl
        self.gewaehlt = gewaehlt
        self.unter = unter
    }
}

public extension ContentCatalog {
    /// Does a question belong to a pool (top-level or sub-category ids; empty = everything)?
    static func inPool(_ q: Question, _ pool: [String]) -> Bool {
        pool.isEmpty || pool.contains(q.kat) || pool.contains(q.sub)
    }

    /// Questions of a pool (optionally kid-safe only).
    func questions(inPool pool: [String], kidSafe: Bool = false) -> [Question] {
        questions.filter { Self.inPool($0, pool) && (!kidSafe || $0.isKidSafe) }
    }

    /// Question count per type inside a pool — what the plan resolver uses to
    /// decide whether a format (estimate, sort, picture) can be served.
    func typeCounts(pool: [String], kidSafe: Bool = false) -> [QuestionType: Int] {
        var counts: [QuestionType: Int] = [:]
        for q in questions(inPool: pool, kidSafe: kidSafe) { counts[q.typ, default: 0] += 1 }
        return counts
    }

    /// Name of a top-level or sub-category id.
    func categoryDisplayName(_ id: String) -> String {
        if let c = categories.first(where: { $0.id == id }) { return c.name }
        if let s = taxonomy.subcategory(id) { return s.name }
        return id
    }

    /// Emoji of a top-level id, or of a sub-category's parent.
    func categoryDisplayEmoji(_ id: String) -> String {
        if let c = categories.first(where: { $0.id == id }) { return c.emoji }
        if let s = taxonomy.subcategory(id), let c = categories.first(where: { $0.id == s.ober }) { return c.emoji }
        return "❓"
    }

    /// "Gaming · League of Legends" — category path of a question for the cheat sheet.
    func categoryPath(_ q: Question) -> String {
        let top = categoryDisplayName(q.kat)
        if let sub = taxonomy.subcategory(q.sub), sub.name != top { return "\(top) · \(sub.name)" }
        return top
    }

    /// Sub-categories of a top-level category (with questions).
    func subcategories(of kat: String) -> [SubCategory] {
        taxonomy.unter.filter { $0.ober == kat }
    }

    /// Presets with counts for the cockpit; sets without a single question are dropped.
    func questionSetInfos(activePool: [String], kidSafe: Bool) -> [QuestionSetInfo] {
        var activeId = QuestionSets.id(forPool: activePool, kidSafe: kidSafe)
        if let r = restriction, activePool.isEmpty { activeId = QuestionSets.id(forPool: r, kidSafe: kidSafe) }
        return QuestionSets.all.compactMap { set in
            // A restricted edition offers only the presets that live inside its slice.
            if let r = restriction, set.pool.isEmpty || !Set(set.pool).isSubset(of: Set(r)) { return nil }
            let n = set.id == QuestionSets.eigenId ? questions(inPool: activePool, kidSafe: kidSafe).count : questions(inPool: set.pool, kidSafe: set.kidSafe).count
            if n == 0 && set.id != QuestionSets.eigenId { return nil }
            return QuestionSetInfo(id: set.id, name: set.name, emoji: set.emoji, beschreibung: set.beschreibung, anzahl: n, aktiv: set.id == activeId)
        }
    }

    /// Category tree with counts and selection state for the pool picker.
    func categoryInfos(activePool: [String], kidSafe: Bool) -> [CategoryInfo] {
        var perKat: [String: Int] = [:], perSub: [String: Int] = [:]
        for q in questions where !kidSafe || q.isKidSafe {
            perKat[q.kat, default: 0] += 1
            perSub[q.sub, default: 0] += 1
        }
        return categories.compactMap { c in
            guard let n = perKat[c.id], n > 0 else { return nil }
            let subs = subcategories(of: c.id).compactMap { s -> CategoryInfo? in
                guard let m = perSub[s.id], m > 0 else { return nil }
                return CategoryInfo(id: s.id, name: s.name, emoji: c.emoji, farbe: c.farbe, anzahl: m, gewaehlt: activePool.contains(s.id) || activePool.contains(c.id))
            }
            return CategoryInfo(id: c.id, name: c.name, emoji: c.emoji, farbe: c.farbe, anzahl: n, gewaehlt: activePool.isEmpty || activePool.contains(c.id), unter: subs)
        }
    }

    /// A catalogue restricted to a pool (the League Edition ships only Runeterra; songs drop out).
    func filtered(pool: [String], keepSongs: Bool = false) -> ContentCatalog {
        ContentCatalog(questions: questions(inPool: pool), taxonomy: taxonomy, songs: keepSongs ? songs : [], restriction: pool)
    }
}
