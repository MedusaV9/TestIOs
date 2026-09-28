import Foundation

/// Fine-grained question filter of the Show-Master (settings + cockpit):
/// categories/sub-categories, difficulty tiers, question types and single
/// question ids switched OFF. Built from `MatchSettings`; enforced by every
/// picker (`PickOptions.filter`), the category vote, the plan's format gating
/// and the catalogue counts. Excluding a top-level category excludes all its
/// subs; excluding a sub only excludes that sub (even inside an included parent).
public struct QuestionFilter: Codable, Equatable, Sendable {
    public var kategorien: Set<String>
    public var schwierigkeiten: Set<Difficulty>
    public var typen: Set<QuestionType>
    public var ids: Set<String>

    public init(kategorien: Set<String> = [], schwierigkeiten: Set<Difficulty> = [], typen: Set<QuestionType> = [], ids: Set<String> = []) {
        self.kategorien = kategorien
        self.schwierigkeiten = schwierigkeiten
        self.typen = typen
        self.ids = ids
    }

    public init(settings: MatchSettings) {
        self.init(kategorien: Set(settings.kategorienAus), schwierigkeiten: Set(settings.schwierigkeitenAus),
                  typen: Set(settings.typenAus), ids: Set(settings.fragenAus))
    }

    public static let none = QuestionFilter()

    public var isEmpty: Bool { kategorien.isEmpty && schwierigkeiten.isEmpty && typen.isEmpty && ids.isEmpty }

    /// Only the single-question bans (what survives the last-resort relaxation).
    public var onlyBans: QuestionFilter { QuestionFilter(ids: ids) }

    public func allows(_ q: Question) -> Bool {
        !ids.contains(q.id) && !schwierigkeiten.contains(q.schw) && !typen.contains(q.typ) && allowsCategory(of: q)
    }

    public func allowsCategory(of q: Question) -> Bool { !kategorien.contains(q.kat) && !kategorien.contains(q.sub) }

    /// Enabled tiers of a section: its own tiers minus the switched-off ones; when all
    /// of them are off, the nearest enabled tiers by rank (easy/medium → medium/hard …).
    public func tiers(_ wanted: [Difficulty]) -> [Difficulty] {
        let enabled = Difficulty.allCases.filter { !schwierigkeiten.contains($0) }
        guard !enabled.isEmpty else { return wanted }
        if wanted.isEmpty { return schwierigkeiten.isEmpty ? [] : enabled }
        let own = wanted.filter { !schwierigkeiten.contains($0) }
        if !own.isEmpty { return own }
        var out: [Difficulty] = []
        for w in wanted {
            let best = enabled.map { abs($0.rank - w.rank) }.min() ?? 0
            for e in enabled where abs(e.rank - w.rank) == best && !out.contains(e) { out.append(e) }
        }
        return out.sorted()
    }
}

public extension QuestionType {
    /// German label for the cockpit/filter.
    var label: String {
        switch self {
        case .choice: return "Auswahl"
        case .wahrFalsch: return "Wahr/Falsch"
        case .emoji: return "Emoji"
        case .bildPixel: return "Pixelbild"
        case .mehrfach: return "Mehrfach"
        case .schaetz: return "Schätzen"
        case .sortier: return "Sortieren"
        }
    }
}

public extension Difficulty {
    var emoji: String {
        switch self {
        case .easy: return "🍌"
        case .medium: return "🥥"
        case .hard: return "🌶️"
        case .ultrahard: return "💀"
        }
    }
}

public extension Question {
    /// Display string of the correct answer for any question type.
    var correctDisplay: String {
        switch typ {
        case .wahrFalsch: return korrektBool.map { $0 ? "Wahr" : "Falsch" } ?? "—"
        case .mehrfach:
            let opts = antworten ?? []
            let list = (korrektMehrfach ?? []).compactMap { opts.indices.contains($0) ? opts[$0] : nil }
            return list.isEmpty ? "—" : list.joined(separator: ", ")
        case .schaetz:
            guard let s = schaetz else { return "—" }
            let v = s.richtwert == s.richtwert.rounded() && abs(s.richtwert) < 1e15 ? Money.formatNumber(Int(s.richtwert)) : String(format: "%.2f", s.richtwert).replacingOccurrences(of: ".", with: ",")
            return s.einheit.isEmpty ? v : "\(v) \(s.einheit)"
        case .sortier:
            let items = elemente ?? []
            let order = reihenfolge ?? Array(items.indices)
            let list = order.compactMap { items.indices.contains($0) ? items[$0] : nil }
            return list.isEmpty ? "—" : list.joined(separator: " → ")
        default:
            let opts = choiceOptions
            return correctIndex.flatMap { opts.indices.contains($0) ? opts[$0] : nil } ?? "—"
        }
    }
}

/// One difficulty tier in the catalogue view.
public struct KatalogSchwierigkeit: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var emoji: String
    /// Questions of this tier in the pool (kid-safe applied).
    public var anzahl: Int
    /// …of which pass the whole filter (0 when the tier is off).
    public var aktiv: Int
    public var aus: Bool
}

/// One question type in the catalogue view.
public struct KatalogTyp: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var anzahl: Int
    public var aktiv: Int
    public var aus: Bool
}

/// The whole filterable catalogue for the settings screen and the GM cockpit.
public struct KatalogInfo: Codable, Equatable, Sendable {
    /// Questions in the catalogue (kid-safe applied).
    public var gesamt: Int
    /// Questions that can actually be drawn: pool + filter + kid-safe.
    public var aktiv: Int
    public var schwierigkeiten: [KatalogSchwierigkeit]
    public var typen: [KatalogTyp]
    public var kategorien: [CategoryInfo]
    /// Number of single questions banned (`fragenAus`).
    public var fragenAus: Int
}

public extension ContentCatalog {
    func katalogInfo(settings: MatchSettings) -> KatalogInfo {
        let kid = settings.familienModus
        let filter = QuestionFilter(settings: settings)
        let pool = settings.kategorienPool
        let base = questions.filter { !kid || $0.isKidSafe }
        let inPool = base.filter { Self.inPool($0, pool) }
        let active = inPool.filter { filter.allows($0) }
        let tiers = Difficulty.allCases.map { d in
            KatalogSchwierigkeit(id: d.rawValue, name: d.label, emoji: d.emoji, anzahl: inPool.filter { $0.schw == d }.count,
                                 aktiv: active.filter { $0.schw == d }.count, aus: filter.schwierigkeiten.contains(d))
        }
        let types = QuestionType.allCases.compactMap { t -> KatalogTyp? in
            let n = inPool.filter { $0.typ == t }.count
            guard n > 0 || filter.typen.contains(t) else { return nil }
            return KatalogTyp(id: t.rawValue, name: t.label, anzahl: n, aktiv: active.filter { $0.typ == t }.count, aus: filter.typen.contains(t))
        }
        return KatalogInfo(gesamt: base.count, aktiv: active.count, schwierigkeiten: tiers, typen: types,
                           kategorien: categoryInfos(activePool: pool, kidSafe: kid, filter: filter), fragenAus: settings.fragenAus.count)
    }
}
