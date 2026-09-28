import Foundation

public enum Modus: String, Codable, CaseIterable, Sendable {
    case quick, klassik, marathon, blitz, party, profi, eigen

    public var title: String {
        switch self {
        case .quick: return "Quick Cash"
        case .klassik: return "Klassik-Show"
        case .marathon: return "Marathon"
        case .blitz: return "Blitz-Show"
        case .party: return "Party-Chaos"
        case .profi: return "Quiz-Profi"
        case .eigen: return "Eigene Show"
        }
    }

    public var subtitle: String {
        switch self {
        case .quick: return "4 Runden · ~15–20 min · Ein-Tap-Start"
        case .klassik: return "6 Runden + Jackpot + Finale · ~40 min"
        case .marathon: return "9+ Runden · Halbzeit · alle Formate · ~70 min"
        case .blitz: return "3 Blitzrunden + Mini-Finale · ~10 min"
        case .party: return "6 Party-Runden · wenig Wissen, viel Chaos · ~30 min"
        case .profi: return "6 Wissensrunden + Jackpot · knifflig, ohne Glücksrad · ~40 min"
        case .eigen: return "Du baust die Playlist: Formate, Reihenfolge, Fragenzahl"
        }
    }

    public var emoji: String {
        switch self {
        case .quick: return "⚡"
        case .klassik: return "🎩"
        case .marathon: return "🏃"
        case .blitz: return "🌩️"
        case .party: return "🎉"
        case .profi: return "🎓"
        case .eigen: return "🛠️"
        }
    }
}

/// One round of a hand-built show ("Eigene Show").
public struct PlaylistItem: Codable, Equatable, Sendable {
    public var id: String
    public var fragen: Int

    public init(id: String, fragen: Int) {
        self.id = id
        self.fragen = fragen
    }
}

/// Show tempo — scales phase durations and question timers at runtime.
public enum Tempo: String, Codable, CaseIterable, Sendable {
    case zackig, normal, gemuetlich

    public var factor: Double {
        switch self {
        case .zackig: return 0.85
        case .normal: return 1.0
        case .gemuetlich: return 1.4
        }
    }

    public var label: String {
        switch self {
        case .zackig: return "Zackig"
        case .normal: return "Normal"
        case .gemuetlich: return "Gemütlich"
        }
    }
}

/// Weighted difficulty draw inside the honoured candidate pool.
public enum FragenMix: String, Codable, CaseIterable, Sendable {
    case locker, ausgewogen, knifflig

    public var weights: [Difficulty: Double]? {
        switch self {
        case .locker: return [.easy: 45, .medium: 35, .hard: 15, .ultrahard: 5]
        case .ausgewogen: return nil
        case .knifflig: return [.easy: 10, .medium: 25, .hard: 35, .ultrahard: 30]
        }
    }

    public var label: String {
        switch self {
        case .locker: return "🍌 Locker — mehr Alltagsfragen"
        case .ausgewogen: return "⚖️ Ausgewogen"
        case .knifflig: return "🧠 Knifflig"
        }
    }
}

public enum SlotTag: String, Codable, Sendable { case opener, aufbau, geld, konflikt, risiko, finale }

public enum KategorieWahl: String, Codable, Sendable { case keine, voting, letzter }

public enum TeamModus: String, Codable, CaseIterable, Sendable {
    case aus, zweier = "2er", vierLager = "2v2v2v2", frei
}

public enum SpielModus: String, Codable, Sendable { case quiz, spieleabend }

public struct MatchSettings: Codable, Equatable, Sendable {
    public var modus: Modus
    public var tempo: Tempo
    public var fragenMix: FragenMix
    /// 1.0 strict / 1.25 default / 1.5 chaos (§3.5).
    public var finaleFaktor: Double
    public var jokerAn: Bool
    public var radAn: Bool
    public var kategorienWahl: String // "voting" | "gm" | "aus"
    public var autoGm: Bool
    public var autoTipp: Bool
    public var kurzeShow: Bool
    public var alltimeItems: Bool
    public var tutorialVideos: Bool
    public var v2Formate: Bool
    public var teams: TeamModus
    public var musik: Bool
    public var musikVolume: Double
    /// Without a human Game Master the stage controls the flow (Start/Weiter).
    public var gmLos: Bool
    public var spielModus: SpielModus
    /// Region focus: share of German questions 0…1 (default 0.5 mix).
    public var deAnteil: Double
    /// Family mode: kid-safe pool (ab0), no punishments, timer +50 %.
    public var familienModus: Bool
    /// 18+ alcohol edition (opt in per player).
    public var alkoholEdition: Bool
    /// Category pool restriction — top-level and/or sub-category ids (empty = all).
    public var kategorienPool: [String]
    /// The preset behind the pool ("alle", "league", …, "eigen" for a hand-picked pool).
    public var fragenSet: String
    /// Custom round count override for "Custom" games (nil = blueprint).
    public var rundenOverride: Int?
    /// All-in allowed in Alles oder Banane.
    public var allInErlaubt: Bool
    /// Special rules toggles (SR1…SR7).
    public var specialRules: Set<SpecialRule>
    /// Show-Master: question timer OFF — answers wait until everyone answered or the GM resolves.
    public var timerAus: Bool
    /// Show-Master: fixed time per question in seconds (nil = per difficulty 15/15/20/25 s × tempo).
    public var fragenZeit: Int?
    /// Question filter (see `QuestionFilter`): category/sub ids, tiers, types and single questions switched off.
    public var kategorienAus: [String]
    public var schwierigkeitenAus: [Difficulty]
    public var typenAus: [QuestionType]
    public var fragenAus: [String]
    /// "Eigene Show": the hand-built playlist (empty = the Klassik playlist) and the jackpot beat.
    public var eigenePlaylist: [PlaylistItem]
    public var eigenerJackpot: Bool

    public init(modus: Modus = .klassik) {
        self.modus = modus
        tempo = .gemuetlich
        fragenMix = .locker
        finaleFaktor = 1.25
        jokerAn = modus != .quick
        radAn = true
        kategorienWahl = "voting"
        autoGm = true
        autoTipp = true
        kurzeShow = modus == .quick
        alltimeItems = true
        tutorialVideos = false
        v2Formate = true
        teams = .aus
        musik = true
        musikVolume = 1
        gmLos = true
        spielModus = .quiz
        deAnteil = 0.5
        familienModus = false
        alkoholEdition = false
        kategorienPool = []
        fragenSet = QuestionSets.alleId
        rundenOverride = nil
        allInErlaubt = false
        specialRules = []
        timerAus = false
        fragenZeit = nil
        kategorienAus = []
        schwierigkeitenAus = []
        typenAus = []
        fragenAus = []
        eigenePlaylist = []
        eigenerJackpot = true
        switch modus {
        case .blitz:
            tempo = .zackig
            kurzeShow = true
            jokerAn = false
            radAn = false
            kategorienWahl = "aus"
        case .party:
            tempo = .normal
        case .profi:
            tempo = .normal
            fragenMix = .knifflig
            radAn = false
            autoTipp = false
        case .eigen:
            tempo = .normal
        default:
            break
        }
    }

    /// Apply a question-set preset: pool + kid-safe flag follow the set.
    public mutating func applyQuestionSet(_ id: String) {
        guard let set = QuestionSets.set(id) else { return }
        fragenSet = set.id
        if set.id != QuestionSets.eigenId { kategorienPool = set.pool }
        if set.kidSafe { familienModus = true }
    }

    public var tempoFactor: Double { (familienModus ? 1.5 : 1.0) * tempo.factor }

    /// Scale a duration by the tempo of these settings.
    public func ms(_ base: Int) -> Int { Int((Double(base) * tempoFactor).rounded()) }

    public var autoGmAktiv: Bool { gmLos || autoGm }

    /// Settings patch from a GM/stage command — only known keys are applied.
    public mutating func apply(patch: [String: JSONValue]) {
        if let m = patch["modus"]?.stringValue, let modus = Modus(rawValue: m), modus != self.modus {
            var fresh = MatchSettings(modus: modus)
            fresh.gmLos = gmLos
            fresh.spielModus = spielModus
            fresh.teams = teams
            // The question pool is the Show-Master's choice, not the mode's.
            fresh.kategorienPool = kategorienPool
            fresh.fragenSet = fragenSet
            fresh.familienModus = familienModus
            fresh.alkoholEdition = alkoholEdition
            fresh.deAnteil = deAnteil
            fresh.timerAus = timerAus
            fresh.fragenZeit = fragenZeit
            fresh.kategorienAus = kategorienAus
            fresh.schwierigkeitenAus = schwierigkeitenAus
            fresh.typenAus = typenAus
            fresh.fragenAus = fragenAus
            fresh.eigenePlaylist = eigenePlaylist
            fresh.eigenerJackpot = eigenerJackpot
            self = fresh
        }
        if let s = patch["tempo"]?.stringValue, let v = Tempo(rawValue: s) { tempo = v }
        if let s = patch["fragenMix"]?.stringValue, let v = FragenMix(rawValue: s) { fragenMix = v }
        if let f = patch["finaleFaktor"]?.doubleValue, [1.0, 1.25, 1.5].contains(f) { finaleFaktor = f }
        if let b = patch["jokerAn"]?.boolValue { jokerAn = b }
        if let b = patch["radAn"]?.boolValue { radAn = b }
        if let s = patch["rad"]?.stringValue { radAn = s == "an" }
        if let s = patch["kategorienWahl"]?.stringValue, ["voting", "gm", "aus"].contains(s) { kategorienWahl = s }
        if let b = patch["autoGm"]?.boolValue { autoGm = b }
        if let b = patch["autoTipp"]?.boolValue { autoTipp = b }
        if let b = patch["kurzeShow"]?.boolValue { kurzeShow = b }
        if let b = patch["alltimeItems"]?.boolValue { alltimeItems = b }
        if let b = patch["tutorialVideos"]?.boolValue { tutorialVideos = b }
        if let b = patch["v2Formate"]?.boolValue { v2Formate = b }
        if let s = patch["teams"]?.stringValue, let v = TeamModus(rawValue: s) { teams = v }
        if let b = patch["musik"]?.boolValue { musik = b }
        if let s = patch["musik"]?.stringValue { musik = s == "an" }
        if let d = patch["musikVolume"]?.doubleValue { musikVolume = min(1, max(0, d)) }
        if let b = patch["gmLos"]?.boolValue { gmLos = b }
        if let s = patch["spielModus"]?.stringValue, let v = SpielModus(rawValue: s) { spielModus = v }
        if let d = patch["deAnteil"]?.doubleValue { deAnteil = min(1, max(0, d)) }
        if let b = patch["familienModus"]?.boolValue { familienModus = b }
        if let b = patch["alkoholEdition"]?.boolValue { alkoholEdition = b }
        if let b = patch["allInErlaubt"]?.boolValue { allInErlaubt = b }
        if let arr = patch["kategorienPool"]?.arrayValue {
            kategorienPool = arr.compactMap { $0.stringValue }
            fragenSet = QuestionSets.id(forPool: kategorienPool, kidSafe: false)
        }
        if let id = patch["fragenSet"]?.stringValue { applyQuestionSet(id) }
        if let arr = patch["specialRules"]?.arrayValue {
            specialRules = Set(arr.compactMap { $0.stringValue }.compactMap(SpecialRule.init(rawValue:)))
        }
        if let n = patch["rundenOverride"]?.intValue { rundenOverride = n <= 0 ? nil : n }
        if let b = patch["timerAus"]?.boolValue { timerAus = b }
        if let n = patch["fragenZeit"]?.intValue { fragenZeit = n <= 0 ? nil : min(300, max(5, n)) }
        if patch["fragenZeit"] == .null { fragenZeit = nil }
        applyFilter(patch: patch)
        if let arr = patch["eigenePlaylist"]?.arrayValue {
            eigenePlaylist = Array(arr.compactMap { v -> PlaylistItem? in
                let id: String?, n: Int?
                if case .object(let o) = v { id = o["id"]?.stringValue; n = o["fragen"]?.intValue } else { id = v.stringValue; n = nil }
                guard let id, Blueprints.eigenWaehlbar(id) else { return nil }
                return PlaylistItem(id: id, fragen: min(12, max(1, n ?? Blueprints.empfohleneFragen(id))))
            }.prefix(Blueprints.eigenMaxRunden))
        }
        if let b = patch["eigenerJackpot"]?.boolValue { eigenerJackpot = b }
        if gmLos { autoGm = true }
        if familienModus { alkoholEdition = false }
    }
}

extension MatchSettings {
    /// Filter keys of a settings patch. Arrays replace the list (unknown tiers/types
    /// are dropped); all four tiers off is rejected, all types off keeps `choice` on.
    mutating func applyFilter(patch: [String: JSONValue]) {
        func strings(_ key: String) -> [String]? {
            patch[key]?.arrayValue.map { arr in
                var out: [String] = []
                for s in arr.compactMap({ $0.stringValue }) where !s.isEmpty && !out.contains(s) { out.append(s) }
                return out
            }
        }
        if patch["filterReset"]?.boolValue == true {
            kategorienAus = []; schwierigkeitenAus = []; typenAus = []; fragenAus = []
        }
        if let v = strings("kategorienAus") { kategorienAus = v }
        if let v = strings("schwierigkeitenAus") {
            let tiers = v.compactMap(Difficulty.init(rawValue:))
            if tiers.count < Difficulty.allCases.count { schwierigkeitenAus = tiers }
        }
        if let v = strings("typenAus") {
            var types = v.compactMap(QuestionType.init(rawValue:))
            if types.count >= QuestionType.allCases.count { types.removeAll { $0 == .choice } }
            typenAus = types
        }
        if let v = strings("fragenAus") { fragenAus = v }
        if let id = patch["kategorieAus"]?.stringValue, !id.isEmpty, !kategorienAus.contains(id) { kategorienAus.append(id) }
        if let id = patch["kategorieAn"]?.stringValue { kategorienAus.removeAll { $0 == id } }
    }

    /// The filter as the pickers use it.
    public var questionFilter: QuestionFilter { QuestionFilter(settings: self) }
}

/// Old saves (and hand-written presets) lack newer keys: every field falls back to the mode default.
extension MatchSettings {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let modus = try c.decodeIfPresent(Modus.self, forKey: .modus) ?? .klassik
        self.init(modus: modus)
        func take<T: Decodable>(_ key: CodingKeys, _ current: T) throws -> T { try c.decodeIfPresent(T.self, forKey: key) ?? current }
        tempo = try take(.tempo, tempo)
        fragenMix = try take(.fragenMix, fragenMix)
        finaleFaktor = try take(.finaleFaktor, finaleFaktor)
        jokerAn = try take(.jokerAn, jokerAn)
        radAn = try take(.radAn, radAn)
        kategorienWahl = try take(.kategorienWahl, kategorienWahl)
        autoGm = try take(.autoGm, autoGm)
        autoTipp = try take(.autoTipp, autoTipp)
        kurzeShow = try take(.kurzeShow, kurzeShow)
        alltimeItems = try take(.alltimeItems, alltimeItems)
        tutorialVideos = try take(.tutorialVideos, tutorialVideos)
        v2Formate = try take(.v2Formate, v2Formate)
        teams = try take(.teams, teams)
        musik = try take(.musik, musik)
        musikVolume = try take(.musikVolume, musikVolume)
        gmLos = try take(.gmLos, gmLos)
        spielModus = try take(.spielModus, spielModus)
        deAnteil = try take(.deAnteil, deAnteil)
        familienModus = try take(.familienModus, familienModus)
        alkoholEdition = try take(.alkoholEdition, alkoholEdition)
        kategorienPool = try take(.kategorienPool, kategorienPool)
        fragenSet = try take(.fragenSet, fragenSet)
        rundenOverride = try c.decodeIfPresent(Int.self, forKey: .rundenOverride)
        allInErlaubt = try take(.allInErlaubt, allInErlaubt)
        specialRules = try take(.specialRules, specialRules)
        timerAus = try take(.timerAus, timerAus)
        fragenZeit = try c.decodeIfPresent(Int.self, forKey: .fragenZeit)
        kategorienAus = try take(.kategorienAus, kategorienAus)
        schwierigkeitenAus = try take(.schwierigkeitenAus, schwierigkeitenAus)
        typenAus = try take(.typenAus, typenAus)
        fragenAus = try take(.fragenAus, fragenAus)
        eigenePlaylist = try take(.eigenePlaylist, eigenePlaylist)
        eigenerJackpot = try take(.eigenerJackpot, eigenerJackpot)
    }
}

/// Special rules (GAME-DESIGN §5.4).
public enum SpecialRule: String, Codable, CaseIterable, Sendable {
    case vabanqueFinale = "sr1"
    case pleitegeier = "sr2"
    case notariatsRunde = "sr3"
    case affensteuer = "sr4"
    case kopfgeld = "sr5"
    case kapitalismusGong = "sr6"
    case bananenschale = "sr7"

    public var name: String {
        switch self {
        case .vabanqueFinale: return "Vabanque-Finale"
        case .pleitegeier: return "Pleitegeier"
        case .notariatsRunde: return "Notariats-Runde"
        case .affensteuer: return "Affensteuer"
        case .kopfgeld: return "Kopfgeld auf den Boss"
        case .kapitalismusGong: return "Kapitalismus-Gong"
        case .bananenschale: return "Die Bananenschale"
        }
    }

    public var emoji: String {
        switch self {
        case .vabanqueFinale: return "🎰"
        case .pleitegeier: return "🦅"
        case .notariatsRunde: return "🤫"
        case .affensteuer: return "📦"
        case .kopfgeld: return "🤠"
        case .kapitalismusGong: return "🔔"
        case .bananenschale: return "🍌"
        }
    }

    public var description: String {
        switch self {
        case .vabanqueFinale: return "Ersetzt das Lianen-Finale: verdeckter Einsatz 0–100 % auf die letzte Frage."
        case .pleitegeier: return "3 falsche Antworten in Folge: der Geier frisst 20 % des Kontos."
        case .notariatsRunde: return "Eine Runde ohne Joker und Tipps — Fragenwerte +25 %."
        case .affensteuer: return "Runden-Ende: der Führende zahlt 10 % in die Bananenkiste."
        case .kopfgeld: return "Wer den Dauer-Führenden direkt schlägt, kassiert 200 MM Prämie."
        case .kapitalismusGong: return "1× pro Match: Führender +10 % Zins, Letzter +20 % des Medians."
        case .bananenschale: return "Vor der letzten Frage jeder Runde: ganzen Rundengewinn setzen — ×2 oder weg."
        }
    }
}

/// Blueprint of one round in the match plan (before minigame resolution).
public struct RoundBlueprint: Codable, Equatable, Sendable {
    public var slot: SlotTag
    public var minigameId: String
    public var fragen: Int
    public var schwierigkeiten: [Difficulty]
    public var kategorieWahl: KategorieWahl
    public var radDanach: Bool
    public var v2: Bool

    public init(_ slot: SlotTag, _ minigameId: String, _ fragen: Int, _ schwierigkeiten: [Difficulty],
                _ kategorieWahl: KategorieWahl, _ radDanach: Bool, v2: Bool = false) {
        self.slot = slot
        self.minigameId = minigameId
        self.fragen = fragen
        self.schwierigkeiten = schwierigkeiten
        self.kategorieWahl = kategorieWahl
        self.radDanach = radDanach
        self.v2 = v2
    }
}

public struct ModeBlueprint: Sendable {
    public var runden: [RoundBlueprint]
    public var jackpotFrage: Bool
    public var finaleFragen: Int
    public var ultrahardMax: Int
    public var halbzeitNach: Int?
}

public enum Blueprints {
    static let opener: [Difficulty] = [.easy, .medium]
    static let aufbau: [Difficulty] = [.medium, .hard]
    static let geld: [Difficulty] = [.medium]
    static let konflikt: [Difficulty] = [.hard]
    static let risiko: [Difficulty] = [.hard, .ultrahard]
    static let leiter: [Difficulty] = [.easy, .medium, .hard, .ultrahard]

    /// The blueprint a match actually plays: the mode matrix, or the hand-built playlist.
    public static func blueprint(for settings: MatchSettings) -> ModeBlueprint {
        guard settings.modus == .eigen else { return blueprint(for: settings.modus) }
        let list = settings.eigenePlaylist.filter { eigenWaehlbar($0.id) }
        guard !list.isEmpty else {
            var bp = blueprint(for: .klassik)
            bp.jackpotFrage = settings.eigenerJackpot
            return bp
        }
        let n = list.count
        let runden = list.enumerated().map { i, item -> RoundBlueprint in
            // Dramaturgy by position: warm up, build up, the last round is the risk round.
            let slot: SlotTag = i == 0 ? .opener : (i == n - 1 && n >= 3 ? .risiko : (i % 3 == 2 ? .konflikt : .aufbau))
            let tiers: [Difficulty] = i == 0 ? opener : (slot == .risiko ? risiko : (slot == .konflikt ? konflikt : aufbau))
            return RoundBlueprint(slot, item.id, item.fragen, item.id == "risiko-leiter" ? leiter : tiers, i == 0 ? .keine : .voting, i % 2 == 1 && i < n - 1)
        }
        return ModeBlueprint(runden: runden, jackpotFrage: settings.eigenerJackpot && n >= 3, finaleFragen: n >= 5 ? 5 : 3,
                             ultrahardMax: 2, halbzeitNach: n >= 9 ? n / 2 : nil)
    }

    /// Formats a hand-built show may use (the finale and the tiebreak are fixed beats).
    public static func eigenWaehlbar(_ id: String) -> Bool {
        id != "lianen-finale" && id != "kokosnuss-shake" && MinigameRegistry.plugin(id) != nil
    }

    public static let eigenMaxRunden = 12

    /// Suggested question count of a format (its playlist size elsewhere, else 4).
    public static func empfohleneFragen(_ id: String) -> Int {
        let neu = ["affenzahn": 6, "letzter-affe": 10, "affenschaukel": 5, "herdentrieb": 5, "kokos-kopf": 4]
        if let n = neu[id] { return n }
        for m in [Modus.marathon, .klassik, .quick] { if let r = blueprint(for: m).runden.first(where: { $0.minigameId == id }) { return r.fragen } }
        return 4
    }

    /// Mode matrix (GAME-DESIGN §1.3): playlists + Q + wheel beats.
    public static func blueprint(for modus: Modus) -> ModeBlueprint {
        switch modus {
        case .quick:
            return ModeBlueprint(runden: [
                RoundBlueprint(.opener, "bananen-basics", 3, opener, .keine, false),
                RoundBlueprint(.aufbau, "kokosnuss-uhr", 3, aufbau, .voting, false),
                RoundBlueprint(.geld, "affenbank", 3, geld, .voting, true),
                RoundBlueprint(.risiko, "alles-oder-banane", 3, risiko, .voting, false),
            ], jackpotFrage: false, finaleFragen: 3, ultrahardMax: 1, halbzeitNach: nil)
        case .klassik:
            return ModeBlueprint(runden: [
                RoundBlueprint(.opener, "bananen-basics", 4, opener, .keine, false),
                RoundBlueprint(.aufbau, "bananen-tresor", 4, aufbau, .voting, true),
                RoundBlueprint(.aufbau, "pixel-dschungel", 4, aufbau, .keine, false),
                RoundBlueprint(.geld, "affenbank", 4, geld, .voting, true),
                RoundBlueprint(.konflikt, "stinkbanane", 4, konflikt, .letzter, true),
                RoundBlueprint(.risiko, "alles-oder-banane", 4, risiko, .voting, false),
            ], jackpotFrage: true, finaleFragen: 5, ultrahardMax: 2, halbzeitNach: nil)
        case .marathon:
            return ModeBlueprint(runden: [
                RoundBlueprint(.opener, "bananen-basics", 4, opener, .keine, false),
                RoundBlueprint(.aufbau, "kokosnuss-uhr", 4, aufbau, .voting, true),
                RoundBlueprint(.aufbau, "bananen-tresor", 4, aufbau, .voting, false),
                RoundBlueprint(.aufbau, "affenleiter", 4, aufbau, .voting, true),
                RoundBlueprint(.geld, "affenbank", 4, geld, .voting, false),
                RoundBlueprint(.geld, "monkey-market", 4, geld, .voting, false, v2: true),
                RoundBlueprint(.aufbau, "pixel-dschungel", 4, aufbau, .keine, true),
                RoundBlueprint(.aufbau, "song-rueckwaerts", 3, aufbau, .keine, false, v2: true),
                RoundBlueprint(.aufbau, "musikvideo-raten", 3, aufbau, .keine, false, v2: true),
                RoundBlueprint(.geld, "bananen-boerse", 4, geld, .voting, false, v2: true),
                RoundBlueprint(.geld, "buchstaben-telegramm", 4, geld, .keine, false, v2: true),
                RoundBlueprint(.aufbau, "wer-singts", 5, aufbau, .keine, false, v2: true),
                RoundBlueprint(.konflikt, "stinkbanane", 4, konflikt, .letzter, false),
                RoundBlueprint(.konflikt, "taschendieb", 4, konflikt, .voting, true),
                RoundBlueprint(.konflikt, "bananen-tortenschlacht", 8, konflikt, .voting, false, v2: true),
                RoundBlueprint(.konflikt, "bananen-bluff", 4, konflikt, .voting, false, v2: true),
                RoundBlueprint(.konflikt, "song-snippet", 3, konflikt, .keine, false, v2: true),
                RoundBlueprint(.konflikt, "lianensteg-duell", 7, konflikt, .voting, false, v2: true),
                RoundBlueprint(.konflikt, "bananen-boxkampf", 8, konflikt, .voting, false, v2: true),
                RoundBlueprint(.konflikt, "konter-quiz", 8, opener, .voting, false, v2: true),
                RoundBlueprint(.konflikt, "einer-gegen-alle", 6, aufbau, .voting, false, v2: true),
                RoundBlueprint(.konflikt, "affen-auktion", 4, konflikt, .voting, true, v2: true),
                RoundBlueprint(.risiko, "risiko-leiter", 8, leiter, .voting, false, v2: true),
                RoundBlueprint(.risiko, "alles-oder-banane", 4, risiko, .voting, false),
                RoundBlueprint(.konflikt, "goldener-affe", 4, risiko, .keine, false, v2: true),
            ], jackpotFrage: true, finaleFragen: 7, ultrahardMax: 2, halbzeitNach: 5)
        case .blitz:
            // ~10 minutes: three rapid formats, no wheel, no jackpot, a short finale.
            return ModeBlueprint(runden: [
                RoundBlueprint(.opener, "affenzahn", 6, opener, .keine, false),
                RoundBlueprint(.aufbau, "affenschaukel", 5, aufbau, .keine, false),
                RoundBlueprint(.risiko, "letzter-affe", 8, aufbau, .keine, false),
            ], jackpotFrage: false, finaleFragen: 3, ultrahardMax: 1, halbzeitNach: nil)
        case .party:
            // Opinions, memory, bluffing and chaos — knowledge is a side dish.
            return ModeBlueprint(runden: [
                RoundBlueprint(.opener, "herdentrieb", 5, geld, .keine, false),
                RoundBlueprint(.aufbau, "kokos-kopf", 4, geld, .keine, true),
                RoundBlueprint(.konflikt, "bananen-bluff", 4, konflikt, .voting, false, v2: true),
                RoundBlueprint(.konflikt, "stinkbanane", 4, opener, .letzter, true),
                RoundBlueprint(.geld, "affenschaukel", 5, geld, .voting, false),
                RoundBlueprint(.risiko, "bananen-tortenschlacht", 8, aufbau, .voting, false, v2: true),
            ], jackpotFrage: false, finaleFragen: 3, ultrahardMax: 1, halbzeitNach: nil)
        case .profi:
            // Knowledge first: harder tiers, the survival round, speed, estimates, the ladder.
            return ModeBlueprint(runden: [
                RoundBlueprint(.opener, "bananen-basics", 5, aufbau, .keine, false),
                RoundBlueprint(.aufbau, "letzter-affe", 10, aufbau, .voting, false),
                RoundBlueprint(.aufbau, "bananen-tresor", 4, konflikt, .voting, false),
                RoundBlueprint(.konflikt, "affenzahn", 6, konflikt, .voting, false),
                RoundBlueprint(.konflikt, "affenleiter", 4, konflikt, .voting, false),
                RoundBlueprint(.risiko, "risiko-leiter", 8, leiter, .voting, false, v2: true),
            ], jackpotFrage: true, finaleFragen: 5, ultrahardMax: 3, halbzeitNach: nil)
        case .eigen:
            // Resolved from the settings (see `blueprint(for settings:)`); Klassik as the default.
            return blueprint(for: .klassik)
        }
    }

    /// Playlist under the settings: v2 rounds only with the flag, optional round cap.
    public static func rounds(for settings: MatchSettings) -> [RoundBlueprint] {
        // A hand-built playlist is played as built (the v2 switch only thins the preset playlists).
        let bp = blueprint(for: settings)
        var list = settings.modus == .eigen ? bp.runden : bp.runden.filter { !$0.v2 || settings.v2Formate }
        if let cap = settings.rundenOverride, cap >= 2, cap < list.count {
            list = Array(list.prefix(cap))
        }
        return list
    }
}

/// Minimal JSON value used for loosely typed patches and wire payloads.
public enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let d = try? c.decode(Double.self) { self = .number(d); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "unsupported JSON value")
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let d):
            if d == d.rounded(), abs(d) < 1e15 { try c.encode(Int(d)) } else { try c.encode(d) }
        case .bool(let b): try c.encode(b)
        case .null: try c.encodeNil()
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }

    public var stringValue: String? { if case .string(let s) = self { return s }; return nil }
    public var doubleValue: Double? {
        if case .number(let d) = self { return d }
        if case .string(let s) = self { return Double(s) }
        return nil
    }
    public var intValue: Int? { doubleValue.map { Int($0) } }
    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        if case .string(let s) = self { return s == "true" ? true : (s == "false" ? false : nil) }
        return nil
    }
    public var arrayValue: [JSONValue]? { if case .array(let a) = self { return a }; return nil }
    public var objectValue: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }
    public subscript(key: String) -> JSONValue? { objectValue?[key] }

    public init(_ int: Int) { self = .number(Double(int)) }
    public init(_ s: String) { self = .string(s) }
}
