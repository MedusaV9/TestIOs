import Foundation

/// Cosmetic shop item (§7.4). No item ever changes points, timers or
/// questions — the only exceptions are the modifier vouchers, which are
/// announced publicly and blocked in the finale.
public struct ShopItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var emoji: String
    public var typ: String
    public var slot: String
    public var preis: Int
    public var beschreibung: String
    public var minLevel: Int?
    public var visuell: Bool

    public init(id: String, name: String, emoji: String, typ: String, slot: String, preis: Int, beschreibung: String, minLevel: Int? = nil, visuell: Bool = false) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.typ = typ
        self.slot = slot
        self.preis = preis
        self.beschreibung = beschreibung
        self.minLevel = minLevel
        self.visuell = visuell
    }

    /// Rarity purely from the price (§7.4): Grün <1.100 · Reif <2.100 · Gold <4.200 · Diamant.
    public var seltenheit: String {
        if preis >= 4200 { return "diamant" }
        if preis >= 2100 { return "gold" }
        if preis >= 1100 { return "reif" }
        return "gruen"
    }

    /// Price expressed in evenings (~600 AT per evening) — anti dark pattern.
    public var preisInAbenden: String {
        let abende = Double(preis) / 600.0
        if abende < 1 { return "< 1 Abend" }
        return "≈ \(Int(abende.rounded(.up))) Abende"
    }
}

public enum Shop {
    /// The 85-item catalogue of the original, unchanged prices (W7 rebalance).
    public static let items: [ShopItem] = [
        ShopItem(id: "buzzer-entenquak", name: "Buzzer „Entenquak“", emoji: "🦆", typ: "sound", slot: "buzzer", preis: 400, beschreibung: "Dein Lock-in quakt."),
        ShopItem(id: "buzzer-modem", name: "Buzzer „Dial-up-Modem“", emoji: "📠", typ: "sound", slot: "buzzer", preis: 500, beschreibung: "Brzzzt-krrrsch — Antwort eingewählt."),
        ShopItem(id: "buzzer-oper", name: "Buzzer „Opern-Aaah“", emoji: "🎭", typ: "sound", slot: "buzzer", preis: 500, beschreibung: "Dramatischer Einsatz, jedes Mal."),
        ShopItem(id: "buzzer-furz", name: "Buzzer „Furz Deluxe“", emoji: "💨", typ: "sound", slot: "buzzer", preis: 600, beschreibung: "Der Klassiker. Deluxe-Edition."),
        ShopItem(id: "buzzer-hupe", name: "Buzzer „Hupe“", emoji: "📯", typ: "sound", slot: "buzzer", preis: 250, beschreibung: "Tröööt — Vorfahrt für deine Antwort."),
        ShopItem(id: "buzzer-klingel", name: "Buzzer „Fahrradklingel“", emoji: "🚲", typ: "sound", slot: "buzzer", preis: 250, beschreibung: "Ring-ring! Antwort kommt durch."),
        ShopItem(id: "buzzer-quaek-hupe", name: "Buzzer „Quietsch-Ente“", emoji: "🐥", typ: "sound", slot: "buzzer", preis: 400, beschreibung: "Quiek-quiek. Niemand nimmt dich ernst. Perfekt."),
        ShopItem(id: "buzzer-glocke", name: "Buzzer „Rezeptions-Glocke“", emoji: "🛎️", typ: "sound", slot: "buzzer", preis: 250, beschreibung: "Pling! Service, bitte — eine Antwort."),
        ShopItem(id: "buzzer-boing", name: "Buzzer „Boing“", emoji: "🤸", typ: "sound", slot: "buzzer", preis: 400, beschreibung: "Cartoon-Sprungfeder. Deine Antwort federt rein."),
        ShopItem(id: "buzzer-pfeife", name: "Buzzer „Trillerpfeife“", emoji: "⚽", typ: "sound", slot: "buzzer", preis: 250, beschreibung: "Schiri-Pfiff — Abpfiff für die Konkurrenz."),
        ShopItem(id: "buzzer-wecker", name: "Buzzer „Wecker“", emoji: "⏰", typ: "sound", slot: "buzzer", preis: 400, beschreibung: "Mechanisches Rasseln — Schorschs Lieblingsklang."),
        ShopItem(id: "buzzer-airhorn", name: "Buzzer „Airhorn“", emoji: "📢", typ: "sound", slot: "buzzer", preis: 500, beschreibung: "Druckluft-Fanfare. Das ganze Stadion weiß Bescheid."),
        ShopItem(id: "hut-zylinder", name: "Kopf „Zylinder“", emoji: "🎩", typ: "accessoire", slot: "hut", preis: 400, beschreibung: "Old Money.", visuell: true),
        ShopItem(id: "hut-bananenhelm", name: "Kopf „Bananen-Helm“", emoji: "🍌", typ: "accessoire", slot: "hut", preis: 600, beschreibung: "Sicherheit geht vor.", visuell: true),
        ShopItem(id: "gesicht-monokel", name: "Gesicht „Monokel“", emoji: "🧐", typ: "accessoire", slot: "gesicht", preis: 400, beschreibung: "Für das prüfende Starren.", visuell: true),
        ShopItem(id: "gesicht-3dbrille", name: "Gesicht „3D-Brille“", emoji: "🕶️", typ: "accessoire", slot: "gesicht", preis: 500, beschreibung: "Die Show in 3D.", visuell: true),
        ShopItem(id: "hand-kaffeetasse", name: "Hand „Kaffeetasse“", emoji: "☕", typ: "accessoire", slot: "hand", preis: 400, beschreibung: "Erst der Kaffee, dann die Antwort.", visuell: true),
        ShopItem(id: "hand-minibuzzer", name: "Hand „Mini-Buzzer“", emoji: "🔴", typ: "accessoire", slot: "hand", preis: 600, beschreibung: "Immer buzzer-bereit.", visuell: true),
        ShopItem(id: "titel-bananen-baron", name: "Titel „Bananen-Baron“", emoji: "👑", typ: "titel", slot: "titel", preis: 400, beschreibung: "Adel verpflichtet zu nichts."),
        ShopItem(id: "titel-buzzer-berserker", name: "Titel „Buzzer-Berserker“", emoji: "⚡", typ: "titel", slot: "titel", preis: 600, beschreibung: "Erst drücken, dann denken."),
        ShopItem(id: "sticker-boersen-panik", name: "Sticker „Börsen-Panik“ (8 Taunts)", emoji: "📉", typ: "sticker", slot: "sticker", preis: 700, beschreibung: "8 Taunts für Auflösungs-Fenster."),
        ShopItem(id: "konfetti-bananen-regen", name: "Konfetti „Bananen-Regen“", emoji: "🍌", typ: "konfetti", slot: "konfetti", preis: 1200, beschreibung: "Es regnet Bananen statt Scheine."),
        ShopItem(id: "konfetti-8bit", name: "Konfetti „8-Bit-Scheine“", emoji: "👾", typ: "konfetti", slot: "konfetti", preis: 1400, beschreibung: "Pixel-Geld wie 1987."),
        ShopItem(id: "fell-leopard", name: "Fell „Leopard“", emoji: "🐆", typ: "avatar", slot: "fell", preis: 1400, beschreibung: "Raubkatzen-Chic.", visuell: true),
        ShopItem(id: "fell-neon", name: "Fell „Neon“", emoji: "🌈", typ: "avatar", slot: "fell", preis: 1600, beschreibung: "Leuchtet bis in die letzte Reihe.", minLevel: 3, visuell: true),
        ShopItem(id: "spezies-orang-utan", name: "Spezies „Orang-Utan“", emoji: "🦧", typ: "avatar", slot: "spezies", preis: 2500, beschreibung: "Rotes Edel-Fell.", minLevel: 5, visuell: true),
        ShopItem(id: "spezies-pavian", name: "Spezies „Pavian“", emoji: "🐒", typ: "avatar", slot: "spezies", preis: 2500, beschreibung: "Grau, würdevoll, gefährlich.", minLevel: 5, visuell: true),
        ShopItem(id: "avatar-hologramm", name: "„Hologramm-Affe“ (animiert)", emoji: "✨", typ: "avatar", slot: "holo", preis: 7000, beschreibung: "Flimmert wie aus der Zukunft.", minLevel: 10, visuell: true),
        ShopItem(id: "badge-spende", name: "Spenden-Badge „Bananen-Stiftung“", emoji: "💛", typ: "badge", slot: "badge", preis: 600, beschreibung: "1.000 AT an die Bananen-Stiftung. Fürs Herz."),
        ShopItem(id: "titel-bananen-fluesterer", name: "Titel „Bananen-Flüsterer“", emoji: "🤫", typ: "titel", slot: "titel", preis: 500, beschreibung: "Die Bananen erzählen dir alles."),
        ShopItem(id: "titel-ultrahard-ueberlebender", name: "Titel „ULTRAHARD-Überlebender“", emoji: "💀", typ: "titel", slot: "titel", preis: 1200, beschreibung: "Hat die 1.000er-Frage gesehen und lebt noch.", minLevel: 4),
        ShopItem(id: "titel-zins-geniesser", name: "Titel „Zins-Genießer“", emoji: "🛋️", typ: "titel", slot: "titel", preis: 400, beschreibung: "Lässt das Geld arbeiten. Selbst? Niemals."),
        ShopItem(id: "titel-frisch-gewaschen", name: "Titel „Frisch gewaschen“", emoji: "🧼", typ: "titel", slot: "titel", preis: 400, beschreibung: "Das Geld, versteht sich."),
        ShopItem(id: "titel-jackpot-magnet", name: "Titel „Jackpot-Magnet“", emoji: "🍯", typ: "titel", slot: "titel", preis: 700, beschreibung: "Das Glas kommt freiwillig zu dir."),
        ShopItem(id: "titel-schaetz-orakel", name: "Titel „Schätz-Orakel“", emoji: "🔮", typ: "titel", slot: "titel", preis: 600, beschreibung: "Plusminus 3 % — immer."),
        ShopItem(id: "titel-affenkoenig", name: "Titel „Affenkönig“", emoji: "🦍", typ: "titel", slot: "titel", preis: 2200, beschreibung: "Es gibt nur einen. Meistens.", minLevel: 6),
        ShopItem(id: "titel-pleitegeier", name: "Titel „Pleitegeier“", emoji: "🦅", typ: "titel", slot: "titel", preis: 400, beschreibung: "Für Ironiker mit Dispo-Erfahrung."),
        ShopItem(id: "titel-eiskalter-analyst", name: "Titel „Eiskalter Analyst“", emoji: "🧊", typ: "titel", slot: "titel", preis: 600, beschreibung: "Erst denken, dann drücken. Immer."),
        ShopItem(id: "titel-lianen-legende", name: "Titel „Lianen-Legende“", emoji: "🌿", typ: "titel", slot: "titel", preis: 1300, beschreibung: "Schwingt sich durch jedes Finale."),
        ShopItem(id: "banner-dschungelnacht", name: "Banner „Dschungel-Nacht“", emoji: "🌙", typ: "banner", slot: "banner", preis: 1200, beschreibung: "Tiefgrünes Blätterdach mit Mondlicht.", visuell: true),
        ShopItem(id: "banner-bananenplantage", name: "Banner „Bananen-Tapete“", emoji: "🍌", typ: "banner", slot: "banner", preis: 1200, beschreibung: "Bananen. Überall Bananen.", visuell: true),
        ShopItem(id: "banner-retro-arcade", name: "Banner „Retro-Arcade“", emoji: "👾", typ: "banner", slot: "banner", preis: 1400, beschreibung: "CRT-Streifen wie 1987.", visuell: true),
        ShopItem(id: "banner-casino-neon", name: "Banner „Casino-Neon“", emoji: "🎰", typ: "banner", slot: "banner", preis: 1600, beschreibung: "Las Vegas fürs Pult.", visuell: true),
        ShopItem(id: "banner-goldregen", name: "Banner „Goldregen“", emoji: "🪙", typ: "banner", slot: "banner", preis: 1600, beschreibung: "Es schimmert, wo du stehst.", minLevel: 6, visuell: true),
        ShopItem(id: "banner-weltraum", name: "Banner „Weltraum“", emoji: "🚀", typ: "banner", slot: "banner", preis: 2500, beschreibung: "Anti-Schwerkraft-Scheine nicht inklusive.", minLevel: 8, visuell: true),
        ShopItem(id: "namestil-neon-gruen", name: "Name „Neon-Grün“", emoji: "🟢", typ: "namestil", slot: "namestil", preis: 700, beschreibung: "Dein Name leuchtet dezent nach.", visuell: true),
        ShopItem(id: "namestil-eisblau", name: "Name „Eisblau“", emoji: "🧊", typ: "namestil", slot: "namestil", preis: 700, beschreibung: "Kühl. Klar. Analytisch.", visuell: true),
        ShopItem(id: "namestil-gold-glitzer", name: "Name „Gold-Glitzer“", emoji: "✨", typ: "namestil", slot: "namestil", preis: 1400, beschreibung: "Old-Money-Schimmer im Schriftzug.", minLevel: 7, visuell: true),
        ShopItem(id: "namestil-regenbogen", name: "Name „Regenbogen“", emoji: "🌈", typ: "namestil", slot: "namestil", preis: 1600, beschreibung: "Alle Farben, sanft rotierend.", minLevel: 9, visuell: true),
        ShopItem(id: "konfetti-goldmuenzen", name: "Konfetti „Goldmünzen-Regen“", emoji: "🪙", typ: "konfetti", slot: "konfetti", preis: 1400, beschreibung: "Kling, kling — Münzen statt Scheine."),
        ShopItem(id: "konfetti-herbstlaub", name: "Konfetti „Herbstlaub“", emoji: "🍂", typ: "konfetti", slot: "konfetti", preis: 1200, beschreibung: "Melancholisch reich. Für die Ironiker."),
        ShopItem(id: "hut-blumenkranz", name: "Kopf „Blumenkranz“", emoji: "🌸", typ: "accessoire", slot: "hut", preis: 600, beschreibung: "Flower-Power fürs Fell.", visuell: true),
        ShopItem(id: "hut-pirat", name: "Kopf „Piratenhut“", emoji: "🏴‍☠️", typ: "accessoire", slot: "hut", preis: 700, beschreibung: "Dreispitz mit Totenkopf — Beute garantiert.", visuell: true),
        ShopItem(id: "hut-partyhut", name: "Kopf „Party-Hut“", emoji: "🥳", typ: "accessoire", slot: "hut", preis: 700, beschreibung: "Mit Konfetti-Spitze. Immer Grund zum Feiern.", visuell: true),
        ShopItem(id: "hut-propeller", name: "Kopf „Propeller-Kappe“", emoji: "🚁", typ: "accessoire", slot: "hut", preis: 1200, beschreibung: "Der Propeller dreht wirklich. Abheben nicht garantiert.", visuell: true),
        ShopItem(id: "hut-teufelshoerner", name: "Kopf „Teufelshörner“", emoji: "😈", typ: "accessoire", slot: "hut", preis: 1300, beschreibung: "Für den kleinen Klau zwischendurch.", visuell: true),
        ShopItem(id: "hut-heiligenschein", name: "Kopf „Heiligenschein“", emoji: "😇", typ: "accessoire", slot: "hut", preis: 1300, beschreibung: "Schwebt. Du hast NIE geklaut.", visuell: true),
        ShopItem(id: "hut-ritterhelm", name: "Kopf „Ritterhelm“", emoji: "⚔️", typ: "accessoire", slot: "hut", preis: 1400, beschreibung: "Volle Deckung gegen Buzzer-Attacken.", visuell: true),
        ShopItem(id: "hut-krone", name: "Kopf „Goldene Krone“", emoji: "👑", typ: "accessoire", slot: "hut", preis: 2800, beschreibung: "Echtgold-Optik mit Juwelen. Für Affenkönige.", minLevel: 8, visuell: true),
        ShopItem(id: "gesicht-schnurrbart", name: "Gesicht „Schnurrbart“", emoji: "🥸", typ: "accessoire", slot: "gesicht", preis: 500, beschreibung: "Fein gezwirbelt. Sehr seriös.", visuell: true),
        ShopItem(id: "gesicht-augenklappe", name: "Gesicht „Augenklappe“", emoji: "🦜", typ: "accessoire", slot: "gesicht", preis: 500, beschreibung: "Ein Auge reicht für diese Fragen.", visuell: true),
        ShopItem(id: "gesicht-sonnenbrille", name: "Gesicht „Sonnenbrille“", emoji: "🕶️", typ: "accessoire", slot: "gesicht", preis: 1200, beschreibung: "Verspiegelt. Niemand sieht dich zweifeln.", visuell: true),
        ShopItem(id: "gesicht-kaugummi", name: "Gesicht „XXL-Kaugummi“", emoji: "🫧", typ: "accessoire", slot: "gesicht", preis: 1300, beschreibung: "Rosa Riesen-Blase. Pulsiert. Platzt nie.", visuell: true),
        ShopItem(id: "fell-tiger", name: "Fell „Tiger-Streifen“", emoji: "🐯", typ: "avatar", slot: "fell", preis: 1400, beschreibung: "Echtes Streifen-Muster im Fell — Raubtier-Modus.", visuell: true),
        ShopItem(id: "fell-dalmatiner", name: "Fell „Dalmatiner-Bananen“", emoji: "🍌", typ: "avatar", slot: "fell", preis: 1400, beschreibung: "Punkte? Nein: Mini-Bananen. Überall.", visuell: true),
        ShopItem(id: "fell-camo", name: "Fell „Dschungel-Camo“", emoji: "🪖", typ: "avatar", slot: "fell", preis: 1500, beschreibung: "Tarnflecken — im Dschungel unsichtbar, am Buzzer nicht.", visuell: true),
        ShopItem(id: "fell-sterne", name: "Fell „Sternenhimmel“", emoji: "⭐", typ: "avatar", slot: "fell", preis: 1600, beschreibung: "Sterne im Fell. Astrologisch wertvoll.", visuell: true),
        ShopItem(id: "fell-goldglitzer", name: "Fell „Gold-Glitzer“", emoji: "✨", typ: "avatar", slot: "fell", preis: 3400, beschreibung: "Subtiler Gold-Schimmer, funkelt bei jeder Bewegung.", minLevel: 10, visuell: true),
        ShopItem(id: "podium-girlande", name: "Podium „Bananen-Girlande“", emoji: "🌿", typ: "podium", slot: "podium", preis: 1400, beschreibung: "Dein Podest ist geschmückt wie zum Erntedankfest.", visuell: true),
        ShopItem(id: "podium-neon", name: "Podium „Neon-Glow“", emoji: "💡", typ: "podium", slot: "podium", preis: 1600, beschreibung: "Dein Podest pulsiert türkis. Las Vegas nickt.", visuell: true),
        ShopItem(id: "podium-goldrahmen", name: "Podium „Goldrahmen“", emoji: "🖼️", typ: "podium", slot: "podium", preis: 2200, beschreibung: "Dein Podest, museumsreif eingerahmt.", minLevel: 6, visuell: true),
        ShopItem(id: "einlauf-rauchwolke", name: "Einlauf „Rauchwolke“", emoji: "💨", typ: "einlauf", slot: "einlauf", preis: 1600, beschreibung: "Du erscheinst im Opening aus einer Rauchwolke.", visuell: true),
        ShopItem(id: "einlauf-blitz", name: "Einlauf „Blitz-Einschlag“", emoji: "⚡", typ: "einlauf", slot: "einlauf", preis: 2500, beschreibung: "Ein Blitz schlägt ein — und da stehst DU.", minLevel: 7, visuell: true),
        ShopItem(id: "effekt-schimmernd", name: "Effekt „Schimmernd“", emoji: "🌈", typ: "effekt", slot: "farbEffekt", preis: 1400, beschreibung: "Deine Farbe wandert sanft durchs Spektrum — dezent, aber edel.", visuell: true),
        ShopItem(id: "effekt-leuchtend", name: "Effekt „Leuchtend“", emoji: "💡", typ: "effekt", slot: "farbEffekt", preis: 2500, beschreibung: "Weicher Glow in deiner Farbe — um Affe UND Namensschild.", visuell: true),
        ShopItem(id: "effekt-funkelnd", name: "Effekt „Funkelnd“", emoji: "✨", typ: "effekt", slot: "farbEffekt", preis: 3400, beschreibung: "Kleine Sterne funkeln um deinen Affen. Das ganze Studio schaut hin.", minLevel: 8, visuell: true),
        ShopItem(id: "hand-banane", name: "Hand „Snack-Banane“", emoji: "🍌", typ: "accessoire", slot: "hand", preis: 500, beschreibung: "Nervennahrung, immer griffbereit.", visuell: true),
        ShopItem(id: "hand-zauberstab", name: "Hand „Zauberstab“", emoji: "🪄", typ: "accessoire", slot: "hand", preis: 700, beschreibung: "Für die ganz schwierigen Fragen: Simsalabim.", visuell: true),
        ShopItem(id: "hut-melone", name: "Kopf „Melone“", emoji: "🎳", typ: "accessoire", slot: "hut", preis: 600, beschreibung: "Britisch-seriös. Die Antwort ist sicher irgendwo im Schirm.", visuell: true),
        ShopItem(id: "banner-sonnenuntergang", name: "Banner „Sonnenuntergang“", emoji: "🌅", typ: "banner", slot: "banner", preis: 1200, beschreibung: "Goldene Stunde, jede Runde.", visuell: true),
        ShopItem(id: "banner-lavastrom", name: "Banner „Lavastrom“", emoji: "🌋", typ: "banner", slot: "banner", preis: 1400, beschreibung: "Heißer Boden unterm Podest.", visuell: true),
        ShopItem(id: "namestil-lava", name: "Name „Lavaglut“", emoji: "🔥", typ: "namestil", slot: "namestil", preis: 1300, beschreibung: "Dein Name glüht wie frische Lava.", visuell: true),
        ShopItem(id: "titel-farb-magier", name: "Titel „Farb-Magier“", emoji: "🎨", typ: "titel", slot: "titel", preis: 500, beschreibung: "Kennt alle 16.777.216 Farben. Persönlich."),
        ShopItem(id: "titel-glanzstueck", name: "Titel „Glanzstück“", emoji: "💎", typ: "titel", slot: "titel", preis: 700, beschreibung: "Poliert sich täglich selbst."),
        ShopItem(id: "titel-schaufenster-affe", name: "Titel „Schaufenster-Affe“", emoji: "🛍️", typ: "titel", slot: "titel", preis: 400, beschreibung: "Wohnt praktisch im AT-Shop."),
    ]

    public static func item(_ id: String) -> ShopItem? { items.first { $0.id == id } }

    public static let slots = ["buzzer", "hut", "gesicht", "hand", "fell", "titel", "konfetti", "banner", "namestil", "podium", "einlauf", "farbEffekt", "spezies", "holo", "badge", "sticker"]

    public static let slotNames: [String: String] = [
        "buzzer": "Buzzer-Sound", "hut": "Kopf", "gesicht": "Gesicht", "hand": "Hand", "fell": "Fell", "titel": "Titel", "konfetti": "Money-Regen",
        "banner": "Banner", "namestil": "Namens-Stil", "podium": "Podium", "einlauf": "Einlauf", "farbEffekt": "Farb-Effekt", "spezies": "Spezies", "holo": "Hologramm", "badge": "Abzeichen", "sticker": "Sticker"
    ]
}
