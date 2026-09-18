import Foundation

/// Glücksrad segments (GAME-DESIGN §5.3): 14 segments with weights, classes,
/// scopes and the fair-finale pool.
public enum WheelSegmentId: String, Codable, CaseIterable, Sendable {
    case doppelterZaster = "doppelter-zaster"
    case halbeMiete = "halbe-miete"
    case bananaBailout = "banana-bailout"
    case dividende
    case insiderTipp = "insider-tipp"
    case inflation
    case affentheater
    case boersenRoulette = "boersen-roulette"
    case umarmungsBonus = "umarmungs-bonus"
    case steuerpruefung
    case blackout
    case tauschBoerse = "tausch-boerse"
    case affeWuerfelt = "affe-wuerfelt"
    case komplimentKonto = "kompliment-konto"
    case shotOderSchotter = "shot-oder-schotter"
}

public enum WheelClass: String, Codable, Sendable { case gruen, blau, gold }
public enum WheelScope: String, Codable, Sendable { case sofort, naechsteFrage = "naechste-frage", runde }
public enum WheelInteraction: String, Codable, Sendable { case longShort = "long-short", umarmt, kompliment, shot }

public struct WheelSegment: Codable, Equatable, Sendable, Identifiable {
    public var id: WheelSegmentId
    public var name: String
    public var klasse: WheelClass
    public var gewicht: Double
    public var wirkung: String
    public var scope: WheelScope
    public var interaktion: WheelInteraction?
    public var interaktionMs: Int
    public var fairFinale: Bool
    public var brauchtMcFrage: Bool
    public var emoji: String
}

public enum Wheel {
    public static let segments: [WheelSegment] = [
        WheelSegment(id: .doppelterZaster, name: "Doppelter Zaster", klasse: .gruen, gewicht: 13,
                     wirkung: "Nächste Frage: Gewinne ×2, Verluste normal.", scope: .naechsteFrage,
                     interaktion: nil, interaktionMs: 0, fairFinale: true, brauchtMcFrage: false, emoji: "💰"),
        WheelSegment(id: .halbeMiete, name: "Halbe Miete", klasse: .gruen, gewicht: 13,
                     wirkung: "Nächste Frage: Antwortzeit halbiert!", scope: .naechsteFrage,
                     interaktion: nil, interaktionMs: 0, fairFinale: true, brauchtMcFrage: true, emoji: "⏱️"),
        WheelSegment(id: .bananaBailout, name: "Banana Bailout", klasse: .gruen, gewicht: 13,
                     wirkung: "Der Letzte bekommt +1 Joker (50:50) + 15 % des Abstands zum Vorletzten.", scope: .sofort,
                     interaktion: nil, interaktionMs: 0, fairFinale: true, brauchtMcFrage: false, emoji: "🪂"),
        WheelSegment(id: .dividende, name: "Dividende", klasse: .blau, gewicht: 7,
                     wirkung: "Rest der Runde: +5 % Zins auf den Kontostand pro richtiger Antwort.", scope: .runde,
                     interaktion: nil, interaktionMs: 0, fairFinale: false, brauchtMcFrage: false, emoji: "📈"),
        WheelSegment(id: .insiderTipp, name: "Insider-Tipp", klasse: .blau, gewicht: 7,
                     wirkung: "Jemand hat einen Insider-Tipp … (sieht die nächste Frage 3 s früher)", scope: .naechsteFrage,
                     interaktion: nil, interaktionMs: 0, fairFinale: true, brauchtMcFrage: true, emoji: "🕵️"),
        WheelSegment(id: .inflation, name: "Inflation!", klasse: .blau, gewicht: 7,
                     wirkung: "Rest der Runde: −3 % Kontostand pro Frage-Ende (mind. 50 MM).", scope: .runde,
                     interaktion: nil, interaktionMs: 0, fairFinale: false, brauchtMcFrage: false, emoji: "🎈"),
        WheelSegment(id: .affentheater, name: "Affentheater", klasse: .blau, gewicht: 7,
                     wirkung: "Nächste Frage: Bildschirm-Reihenfolge ≠ Handy-Reihenfolge — es zählt der TEXT auf deinem Handy!",
                     scope: .naechsteFrage, interaktion: nil, interaktionMs: 0, fairFinale: false, brauchtMcFrage: true, emoji: "🎭"),
        WheelSegment(id: .boersenRoulette, name: "Börsen-Roulette", klasse: .blau, gewicht: 7,
                     wirkung: "Jeder wählt blind Long/Short: richtig+Long +150 %, richtig+Short +50 %; falsch+Long −100 MM, falsch+Short ±0.",
                     scope: .naechsteFrage, interaktion: .longShort, interaktionMs: 5000, fairFinale: false, brauchtMcFrage: true, emoji: "📊"),
        WheelSegment(id: .umarmungsBonus, name: "Umarmungs-Bonus", klasse: .blau, gewicht: 7,
                     wirkung: "15 s: real umarmen + „Umarmt!“ drücken → je +50 MM.", scope: .sofort,
                     interaktion: .umarmt, interaktionMs: 15000, fairFinale: true, brauchtMcFrage: false, emoji: "🤗"),
        WheelSegment(id: .steuerpruefung, name: "Steuerprüfung", klasse: .blau, gewicht: 7,
                     wirkung: "Der Führende muss die nächste Frage richtig haben — sonst zahlt er 10 % in den Pott des Fragen-Gewinners.",
                     scope: .naechsteFrage, interaktion: nil, interaktionMs: 0, fairFinale: false, brauchtMcFrage: true, emoji: "🧾"),
        WheelSegment(id: .blackout, name: "Blackout im Studio", klasse: .gold, gewicht: 3,
                     wirkung: "Nächste Frage NUR auf den Handys — der Bildschirm zeigt Sendeausfall.", scope: .naechsteFrage,
                     interaktion: nil, interaktionMs: 0, fairFinale: true, brauchtMcFrage: true, emoji: "📺"),
        WheelSegment(id: .tauschBoerse, name: "Affen-Tausch-Börse", klasse: .gold, gewicht: 3,
                     wirkung: "SOFORT: alle tauschen den Kontostand mit dem Sitznachbarn!", scope: .sofort,
                     interaktion: nil, interaktionMs: 0, fairFinale: false, brauchtMcFrage: false, emoji: "🔁"),
        WheelSegment(id: .affeWuerfelt, name: "Der Affe würfelt", klasse: .gold, gewicht: 3,
                     wirkung: "Ein Bot-Affe rät die nächste Frage mit — wen er schlägt, der zahlt 50 MM Schmach-Gebühr in den Pott.",
                     scope: .naechsteFrage, interaktion: nil, interaktionMs: 0, fairFinale: false, brauchtMcFrage: true, emoji: "🎲"),
        WheelSegment(id: .komplimentKonto, name: "Kompliment-Konto", klasse: .gold, gewicht: 3,
                     wirkung: "A macht B binnen 20 s ein ernstes Kompliment (Gruppen-Vote) → beide +50 MM.", scope: .sofort,
                     interaktion: .kompliment, interaktionMs: 20000, fairFinale: false, brauchtMcFrage: false, emoji: "💬"),
        WheelSegment(id: .shotOderSchotter, name: "Shot oder Schotter", klasse: .gold, gewicht: 3,
                     wirkung: "Die langsamste richtige Antwort wählt: Shot trinken +50 MM oder 100 MM Feigheits-Steuer.",
                     scope: .sofort, interaktion: .shot, interaktionMs: 15000, fairFinale: false, brauchtMcFrage: false, emoji: "🥃"),
    ]

    public static func segment(_ id: WheelSegmentId) -> WheelSegment {
        segments.first { $0.id == id }!
    }

    public struct Context: Sendable {
        public var fairFinale: Bool
        public var nextIsMcQuestion: Bool
        public var lastSegment: WheelSegmentId?
        public var spinsWithoutGold: Int
        public var playerCount: Int
        public var alkoholEdition: Bool
        public var anyoneBelow200: Bool

        public init(fairFinale: Bool, nextIsMcQuestion: Bool, lastSegment: WheelSegmentId?, spinsWithoutGold: Int,
                    playerCount: Int, alkoholEdition: Bool = false, anyoneBelow200: Bool = false) {
            self.fairFinale = fairFinale
            self.nextIsMcQuestion = nextIsMcQuestion
            self.lastSegment = lastSegment
            self.spinsWithoutGold = spinsWithoutGold
            self.playerCount = playerCount
            self.alkoholEdition = alkoholEdition
            self.anyoneBelow200 = anyoneBelow200
        }
    }

    /// Segments compatible with the current situation ("does not apply here"
    /// results do not exist on the wheel).
    public static func compatible(_ ctx: Context) -> [WheelSegment] {
        segments.filter { s in
            if ctx.fairFinale && !s.fairFinale { return false }
            if s.brauchtMcFrage && !ctx.nextIsMcQuestion { return false }
            if s.id == ctx.lastSegment { return false }
            if s.id == .komplimentKonto && ctx.alkoholEdition { return false }
            if s.id == .shotOderSchotter && !ctx.alkoholEdition { return false }
            if s.id == .tauschBoerse && ctx.playerCount < 2 { return false }
            if s.id == .inflation && ctx.anyoneBelow200 { return false }
            if s.id == .umarmungsBonus && ctx.playerCount < 2 { return false }
            return true
        }
    }

    /// Weighted spin with pity timer (+2 % gold per spin after 4 without gold).
    /// Returns the ~10-segment wheel face and the index of the result on it.
    public static func spin(_ ctx: Context, rng: inout SeededRandom, rigged: WheelSegmentId? = nil) -> (face: [WheelSegment], resultIndex: Int) {
        var pool = compatible(ctx)
        if pool.isEmpty { pool = segments.filter { $0.fairFinale } }
        let pity = ctx.spinsWithoutGold > 4 ? Double(ctx.spinsWithoutGold - 4) * 2.0 : 0
        let weights = pool.map { $0.klasse == .gold ? $0.gewicht + pity : $0.gewicht }
        let picked = rigged.flatMap { r in segments.first { $0.id == r } } ?? pool[rng.weightedIndex(weights)]
        var face = pool.filter { $0.id != picked.id }
        face = rng.shuffled(face)
        face = Array(face.prefix(9))
        face.append(picked)
        face = rng.shuffled(face)
        return (face, face.firstIndex { $0.id == picked.id } ?? 0)
    }
}
