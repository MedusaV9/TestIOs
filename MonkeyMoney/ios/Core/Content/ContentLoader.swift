import Foundation

/// Question pick options (mirrors the original content-loader contract).
public struct PickOptions: Sendable {
    public var anzahl: Int
    public var used: Set<String>
    public var kategorien: [String]
    public var schwierigkeiten: [Difficulty]
    public var typen: [QuestionType]
    public var deAnteil: Double
    public var kidSafeOnly: Bool
    public var allowAdult: Bool
    public var mix: FragenMix

    public init(anzahl: Int, used: Set<String> = [], kategorien: [String] = [], schwierigkeiten: [Difficulty] = [],
                typen: [QuestionType] = [], deAnteil: Double = 0.5, kidSafeOnly: Bool = false, allowAdult: Bool = false,
                mix: FragenMix = .ausgewogen) {
        self.anzahl = anzahl
        self.used = used
        self.kategorien = kategorien
        self.schwierigkeiten = schwierigkeiten
        self.typen = typen
        self.deAnteil = deAnteil
        self.kidSafeOnly = kidSafeOnly
        self.allowAdult = allowAdult
        self.mix = mix
    }
}

/// The whole content catalogue: questions, taxonomy and songs. Loaded once
/// from the bundle (or a directory on Linux for tests), then queried purely.
public final class ContentCatalog: @unchecked Sendable {
    public let questions: [Question]
    public let taxonomy: Taxonomy
    public let songs: [Song]
    private let byId: [String: Question]

    public init(questions: [Question], taxonomy: Taxonomy, songs: [Song]) {
        self.questions = questions
        self.taxonomy = taxonomy
        self.songs = songs
        var map: [String: Question] = [:]
        for q in questions { map[q.id] = q }
        byId = map
    }

    public static let empty = ContentCatalog(questions: [], taxonomy: .builtin, songs: [])

    public func question(_ id: String) -> Question? { byId[id] }

    /// Load `fragen.json`, `taxonomie.json`, `songs.json` from a directory.
    public static func load(from directory: URL) throws -> ContentCatalog {
        let decoder = JSONDecoder()
        struct FragenFile: Decodable { var fragen: [Question] }
        struct SongsFile: Decodable { var songs: [Song] }
        let fragen = try decoder.decode(FragenFile.self, from: Data(contentsOf: directory.appendingPathComponent("fragen.json"))).fragen
        let tax = (try? decoder.decode(Taxonomy.self, from: Data(contentsOf: directory.appendingPathComponent("taxonomie.json")))) ?? .builtin
        let songs = (try? decoder.decode(SongsFile.self, from: Data(contentsOf: directory.appendingPathComponent("songs.json"))).songs) ?? []
        return ContentCatalog(questions: fragen, taxonomy: tax, songs: songs)
    }

    public var categories: [Category] { taxonomy.ober.isEmpty ? Taxonomy.builtin.ober : taxonomy.ober }

    public func categoryName(_ id: String) -> String { categories.first { $0.id == id }?.name ?? id }
    public func categoryEmoji(_ id: String) -> String { categories.first { $0.id == id }?.emoji ?? "❓" }

    /// Candidate filter shared by all pickers.
    public func candidates(_ opts: PickOptions) -> [Question] {
        questions.filter { q in
            if opts.used.contains(q.id) { return false }
            if !opts.kategorien.isEmpty && !opts.kategorien.contains(q.kat) && !opts.kategorien.contains(q.sub) { return false }
            if !opts.schwierigkeiten.isEmpty && !opts.schwierigkeiten.contains(q.schw) { return false }
            if !opts.typen.isEmpty && !opts.typen.contains(q.typ) { return false }
            if opts.kidSafeOnly && !q.isKidSafe { return false }
            if !opts.allowAdult && q.isAdultOnly { return false }
            return true
        }
    }

    /// Weighted, deterministic draw. Region share and difficulty mix are
    /// applied as weights inside the honoured candidate pool; empty tiers
    /// simply drop out (never an empty draw as long as candidates exist).
    public func pick(_ opts: PickOptions, rng: inout SeededRandom) -> [Question] {
        var pool = candidates(opts)
        var out: [Question] = []
        var used = opts.used
        while out.count < opts.anzahl, !pool.isEmpty {
            var tierCounts: [Difficulty: Int] = [:]
            if opts.mix.weights != nil { for q in pool { tierCounts[q.schw, default: 0] += 1 } }
            let weights = pool.map { q -> Double in
                var w = 1.0
                if let mix = opts.mix.weights {
                    w *= (mix[q.schw] ?? 1) / Double(max(1, tierCounts[q.schw] ?? 1))
                }
                w *= q.region == .de ? max(0.05, opts.deAnteil) : max(0.05, 1 - opts.deAnteil)
                return w
            }
            let idx = rng.weightedIndex(weights)
            let q = pool.remove(at: idx)
            used.insert(q.id)
            out.append(q)
        }
        return out
    }

    /// Songs for the music formats.
    public func pickSongs(anzahl: Int, used: Set<String>, mitVideo: Bool, rng: inout SeededRandom) -> [Song] {
        var pool = songs.filter { !used.contains($0.id) && (!mitVideo || $0.hatVideo) }
        pool = rng.shuffled(pool)
        return Array(pool.prefix(anzahl))
    }

    /// Category ids that still have enough unused questions of the given tiers.
    public func categoriesWithSupply(schwierigkeiten: [Difficulty], used: Set<String>, minimum: Int = 4, pool: [String] = []) -> [String] {
        var counts: [String: Int] = [:]
        for q in questions where !used.contains(q.id) && (schwierigkeiten.isEmpty || schwierigkeiten.contains(q.schw)) && q.typ.isChoiceLike {
            if !pool.isEmpty && !pool.contains(q.kat) { continue }
            counts[q.kat, default: 0] += 1
        }
        return categories.map { $0.id }.filter { (counts[$0] ?? 0) >= minimum }
    }
}
