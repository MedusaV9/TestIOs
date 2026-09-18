import Foundation

public enum QuestionType: String, Codable, Sendable {
    case choice
    case wahrFalsch = "wahr_falsch"
    case emoji
    case bildPixel = "bild_pixel"
    case mehrfach
    case schaetz
    case sortier

    /// Types that can be presented as a 4-option (or 2-option) choice question.
    public var isChoiceLike: Bool {
        switch self {
        case .choice, .wahrFalsch, .emoji, .bildPixel: return true
        default: return false
        }
    }
}

public enum Region: String, Codable, Sendable { case de, global }

public struct EstimateSpec: Codable, Equatable, Sendable {
    public var richtwert: Double
    public var einheit: String
    public var toleranz: Double
    public var min: Double
    public var max: Double
    public var skala: String

    public init(richtwert: Double, einheit: String, toleranz: Double, min: Double, max: Double, skala: String) {
        self.richtwert = richtwert
        self.einheit = einheit
        self.toleranz = toleranz
        self.min = min
        self.max = max
        self.skala = skala
    }
}

/// One question from the compiled content bundle (fragen.json).
public struct Question: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var kat: String
    public var sub: String
    public var schw: Difficulty
    public var region: Region
    public var typ: QuestionType
    public var alter: String
    public var text: String
    public var tipps: [String]
    public var erkl: String
    public var antworten: [String]?
    public var korrekt: Int?
    public var emojis: String?
    public var bild: String?
    public var korrektBool: Bool?
    public var korrektMehrfach: [Int]?
    public var schaetz: EstimateSpec?
    public var elemente: [String]?
    public var reihenfolge: [Int]?
    public var werte: [String]?

    public init(id: String, kat: String, sub: String = "", schw: Difficulty, region: Region = .global, typ: QuestionType,
                alter: String = "ab0", text: String, tipps: [String] = [], erkl: String = "", antworten: [String]? = nil,
                korrekt: Int? = nil, emojis: String? = nil, bild: String? = nil, korrektBool: Bool? = nil,
                korrektMehrfach: [Int]? = nil, schaetz: EstimateSpec? = nil, elemente: [String]? = nil,
                reihenfolge: [Int]? = nil, werte: [String]? = nil) {
        self.id = id
        self.kat = kat
        self.sub = sub
        self.schw = schw
        self.region = region
        self.typ = typ
        self.alter = alter
        self.text = text
        self.tipps = tipps
        self.erkl = erkl
        self.antworten = antworten
        self.korrekt = korrekt
        self.emojis = emojis
        self.bild = bild
        self.korrektBool = korrektBool
        self.korrektMehrfach = korrektMehrfach
        self.schaetz = schaetz
        self.elemente = elemente
        self.reihenfolge = reihenfolge
        self.werte = werte
    }

    public var isKidSafe: Bool { alter == "ab0" }
    public var isAdultOnly: Bool { alter == "ab18" }
    public var value: Int { Money.value(schw) }
    public var timerMs: Int { Money.timerMs(schw) }

    /// Options as presented to players for choice-like questions
    /// (wahr/falsch becomes a 2-option question, emoji prefixes the text).
    public var choiceOptions: [String] {
        switch typ {
        case .wahrFalsch: return ["Wahr", "Falsch"]
        default: return antworten ?? []
        }
    }

    public var correctIndex: Int? {
        switch typ {
        case .wahrFalsch: return korrektBool.map { $0 ? 0 : 1 }
        default: return korrekt
        }
    }

    /// Display text for the wall (emoji riddles inline the emojis).
    public var displayText: String {
        if typ == .emoji, let e = emojis { return "\(text)\n\(e)" }
        return text
    }

    /// Placeholder question used when the pool is exhausted (never expected in practice).
    public static func fallback(_ n: Int) -> Question {
        Question(id: "fallback_\(n)", kat: "kurioses_mixed", schw: .easy, typ: .choice,
                 text: "Wie viele Bananen isst ein Affe pro Tag im Monkey-Money-Studio?",
                 tipps: ["Es sind mehr als drei."], erkl: "Die Studio-Affen sind Vielfraße.",
                 antworten: ["1", "3", "5", "Alle"], korrekt: 3)
    }
}

public struct Category: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var emoji: String
    public var farbe: String
}

public struct SubCategory: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var ober: String
    public var name: String
}

public struct Taxonomy: Codable, Sendable {
    public var ober: [Category]
    public var unter: [SubCategory]

    public func category(_ id: String) -> Category? { ober.first { $0.id == id } }
    public func subcategory(_ id: String) -> SubCategory? { unter.first { $0.id == id } }

    public static let empty = Taxonomy(ober: [], unter: [])

    /// Built-in fallback taxonomy (the 14 main categories) if the bundle is missing.
    public static let builtin = Taxonomy(ober: [
        Category(id: "gaming", name: "Gaming", emoji: "🎮", farbe: "#7C4DFF"),
        Category(id: "filme_serien", name: "Filme & Serien", emoji: "🎬", farbe: "#E53935"),
        Category(id: "musik", name: "Musik", emoji: "🎵", farbe: "#FF9800"),
        Category(id: "sport", name: "Sport", emoji: "⚽", farbe: "#4CAF50"),
        Category(id: "wissenschaft", name: "Wissenschaft", emoji: "🔬", farbe: "#00BCD4"),
        Category(id: "geschichte", name: "Geschichte", emoji: "🏛️", farbe: "#795548"),
        Category(id: "geographie", name: "Geographie", emoji: "🌍", farbe: "#3F51B5"),
        Category(id: "essen_trinken", name: "Essen & Trinken", emoji: "🍕", farbe: "#FFC107"),
        Category(id: "internet_memes", name: "Internet & Memes", emoji: "😂", farbe: "#FF4081"),
        Category(id: "deutschland_spezial", name: "Deutschland-Spezial", emoji: "🇩🇪", farbe: "#111111"),
        Category(id: "tiere_natur", name: "Tiere & Natur", emoji: "🦁", farbe: "#8BC34A"),
        Category(id: "kunst_literatur", name: "Kunst & Literatur", emoji: "🎨", farbe: "#9C27B0"),
        Category(id: "technik_autos", name: "Technik & Autos", emoji: "🚗", farbe: "#607D8B"),
        Category(id: "kurioses_mixed", name: "Kurioses & Mixed", emoji: "🎲", farbe: "#009688"),
    ], unter: [])
}

/// Song from the music pack (Blitz-DJ, Rückwärts-Banane, Wer singt's, Stummfilm).
public struct Song: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var titel: String
    public var artist: String
    public var jahr: Int?
    public var region: Region
    public var schw: Difficulty
    public var tags: [String]
    public var hatVideo: Bool
    public var videoHint: [String]?
    public var komponist: String?

    /// Media file name (without folder) for a snippet kind.
    public static func file(for kind: SnippetKind) -> String {
        switch kind {
        case .intro5s: return "intro5s.m4a"
        case .mitte10s: return "mitte10s.m4a"
        case .rueckwaerts5s: return "rueckwaerts5s.m4a"
        case .buzz(let ms): return "buzz_ms\(ms).m4a"
        case .video3s: return "video3s.mp4"
        }
    }

    public enum SnippetKind: Equatable, Sendable {
        case intro5s, mitte10s, rueckwaerts5s, video3s
        case buzz(Int)
    }
}
