import Foundation

/// The seven v1 jokers (GAME-DESIGN §5.1).
public enum JokerId: String, Codable, CaseIterable, Sendable {
    case bananenSplit = "bananen-split"
    case ueberziehungskredit
    case goldeneBanane = "goldene-banane"
    case schmiergeld
    case rueckgaberecht
    case bananentresor
    case portfolioUmschichtung = "portfolio-umschichtung"
}

public enum JokerWindow: String, Codable, Sendable { case frage, vorFrage = "vor-frage", zwischenFragen = "zwischen-fragen" }

public enum JokerPrice: Equatable, Sendable {
    case gratis
    case flat(Int)
    case percentOfQuestion(Int)
    case percentOfBalance(Int)
}

public struct JokerDef: Sendable, Identifiable {
    public var id: JokerId
    public var name: String
    public var emoji: String
    public var beschreibung: String
    public var fenster: JokerWindow
    public var infoJoker: Bool
    public var gratisLadungen: Int
    public var maxKaeufe: Int
    public var preis: JokerPrice
    public var maxProFrage: Int?
    public var minOptions: Int
}

public enum Jokers {
    public static let all: [JokerDef] = [
        JokerDef(id: .bananenSplit, name: "Bananen-Split", emoji: "🍌",
                 beschreibung: "50:50 — die Affenhand reißt 2 falsche Optionen ab.",
                 fenster: .frage, infoJoker: true, gratisLadungen: 1, maxKaeufe: 2,
                 preis: .percentOfQuestion(40), maxProFrage: 1, minOptions: 3),
        JokerDef(id: .ueberziehungskredit, name: "Überziehungskredit", emoji: "⏳",
                 beschreibung: "+10 s auf den laufenden Timer (kein Speed-Bonus in den Dispo-Sekunden).",
                 fenster: .frage, infoJoker: false, gratisLadungen: 0, maxKaeufe: 2,
                 preis: .flat(150), maxProFrage: 1, minOptions: 0),
        JokerDef(id: .goldeneBanane, name: "Goldene Banane", emoji: "✨",
                 beschreibung: "Nächste Frage: Gewinn ×2 UND Strafen ×2 — Gold kostet Mut.",
                 fenster: .vorFrage, infoJoker: false, gratisLadungen: 1, maxKaeufe: 0,
                 preis: .gratis, maxProFrage: nil, minOptions: 0),
        JokerDef(id: .schmiergeld, name: "Schmiergeld", emoji: "🤫",
                 beschreibung: "Tipp kaufen: Stufe 1 nimmt eine falsche Option weg, Stufe 2 flüstert einen Hinweis.",
                 fenster: .frage, infoJoker: true, gratisLadungen: 0, maxKaeufe: 99,
                 preis: .percentOfQuestion(25), maxProFrage: nil, minOptions: 3),
        JokerDef(id: .rueckgaberecht, name: "Rückgaberecht", emoji: "↩️",
                 beschreibung: "Nach falscher Antwort sofort ein 2. Versuch — Gewinn nur 50 %.",
                 fenster: .frage, infoJoker: false, gratisLadungen: 0, maxKaeufe: 2,
                 preis: .percentOfQuestion(35), maxProFrage: 1, minOptions: 3),
        JokerDef(id: .bananentresor, name: "Bananentresor", emoji: "🛡️",
                 beschreibung: "Klau-Schutz: alle Klau-Effekte prallen 1 Runde lang ab.",
                 fenster: .zwischenFragen, infoJoker: false, gratisLadungen: 0, maxKaeufe: 2,
                 preis: .percentOfBalance(10), maxProFrage: nil, minOptions: 0),
        JokerDef(id: .portfolioUmschichtung, name: "Portfolio-Umschichtung", emoji: "🔄",
                 beschreibung: "Eigene Kategorie abwerfen — du bekommst eine Ersatzfrage anderer Kategorie.",
                 fenster: .vorFrage, infoJoker: false, gratisLadungen: 1, maxKaeufe: 1,
                 preis: .flat(250), maxProFrage: nil, minOptions: 0),
    ]

    public static func def(_ id: JokerId) -> JokerDef { all.first { $0.id == id }! }

    public static let schmiergeldStufe2Prozent = 35
    public static let mindestpreisKonto = 100

    /// Price of one charge (with social discount). Balance-based prices have a
    /// floor so protection never becomes almost free.
    public static func price(_ def: JokerDef, questionValue: Int, balance: Int, discount: Double = 1.0, stufe: Int? = nil) -> Int {
        var base: Double
        switch def.preis {
        case .gratis: return 0
        case .flat(let mm): base = Double(mm)
        case .percentOfQuestion(let p):
            let pct = def.id == .schmiergeld && stufe == 2 ? schmiergeldStufe2Prozent : p
            base = Double(pct) / 100 * Double(questionValue)
        case .percentOfBalance(let p):
            base = max(Double(mindestpreisKonto), Double(p) / 100 * Double(max(0, balance)))
        }
        return max(0, Economy.roundTo10(Int((base * discount).rounded())))
    }

    /// Starting inventory for one player (free charges).
    public static func startInventory() -> [JokerId: Int] {
        var inv: [JokerId: Int] = [:]
        for d in all { inv[d.id] = d.gratisLadungen }
        return inv
    }
}
