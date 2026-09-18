import Foundation

public typealias PlayerId = String
/// Milliseconds since epoch (server clock). All deadlines use this unit.
public typealias Millis = Int

public enum Role: String, Codable, Sendable { case screen, player, gm, spectator }

/// Avatar wire format: monkey id + colour + cosmetics (shop extras).
public struct Avatar: Codable, Equatable, Hashable, Sendable {
    public var affe: String
    public var farbe: String
    public var extras: [String]

    public init(affe: String = "don-bananas", farbe: String = "gelb", extras: [String] = []) {
        self.affe = affe
        self.farbe = farbe
        self.extras = extras
    }

    /// `don-bananas.gelb.hut-zylinder+lv7`
    public var wire: String {
        var s = "\(affe).\(farbe)"
        if !extras.isEmpty { s += "." + extras.joined(separator: "+") }
        return s
    }

    public init(wire: String) {
        let parts = wire.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        affe = parts.count > 0 && !parts[0].isEmpty ? parts[0] : "don-bananas"
        farbe = parts.count > 1 && !parts[1].isEmpty ? parts[1] : "gelb"
        extras = parts.count > 2 ? parts[2].split(separator: "+").map(String.init) : []
    }
}

/// Per-match statistics that feed awards, highlights and the meta layer.
public struct PlayerMatchStats: Codable, Equatable, Sendable {
    public var richtig = 0
    public var falsch = 0
    public var keineAntwort = 0
    public var schnellsteMs: Int?
    public var summeAntwortMs = 0
    public var antwortenMitZeit = 0
    public var laengsteSerie = 0
    public var gestohlen = 0
    public var bestohlen = 0
    public var wettenGewonnen = 0
    public var wettenVerloren = 0
    public var jokerGenutzt = 0
    public var ultrahardRichtig = 0
    public var groessterGewinn = 0
    public var buzzes = 0
    public var fehlbuzzes = 0
    public var platzVorFinale: Int?

    public init() {}
}

public struct Player: Codable, Equatable, Sendable, Identifiable {
    public var id: PlayerId
    public var name: String
    public var avatar: Avatar
    public var balance: Int
    public var connected: Bool
    public var streak: Int
    public var wrongStreak: Int
    public var jokers: [String: Int]
    public var jokerKaeufe: [String: Int]
    public var profileId: String?
    public var isBot: Bool
    public var joinOrder: Int
    public var teamId: String?
    public var matsch: Bool
    public var clown: Bool
    public var klauSchutzBisRunde: Int?
    public var rueckenwindAngesagt: Bool
    public var beigetretenRunde: Int
    public var stats: PlayerMatchStats
    public var themen: [String]
    public var kind: Bool
    public var beifahrer: Bool
    public var disconnectedAt: Millis?

    public init(id: PlayerId, name: String, avatar: Avatar, joinOrder: Int, profileId: String? = nil, isBot: Bool = false) {
        self.id = id
        self.name = name
        self.avatar = avatar
        balance = 0
        connected = true
        streak = 0
        wrongStreak = 0
        jokers = Dictionary(uniqueKeysWithValues: Jokers.startInventory().map { ($0.key.rawValue, $0.value) })
        jokerKaeufe = [:]
        self.profileId = profileId
        self.isBot = isBot
        self.joinOrder = joinOrder
        teamId = nil
        matsch = false
        clown = false
        klauSchutzBisRunde = nil
        rueckenwindAngesagt = false
        beigetretenRunde = 0
        stats = PlayerMatchStats()
        themen = []
        kind = false
        beifahrer = false
        disconnectedAt = nil
    }
}

public struct Team: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var farbe: String
    public var mitglieder: [PlayerId]
    public var topf: Int
}

public enum Phase: String, Codable, Sendable {
    case lobby, intro, kategorieWahl = "kategorie-wahl", erklaerkarte, frage, aufloesung, zwischenstand, rad,
         halbzeit, pause, highlights, siegerehrung, ende, brettspiel
}

public enum SectionKind: String, Codable, Sendable { case runde, jackpot, finale }

/// One section of the match plan: a round, the jackpot beat or the finale.
public struct Section: Codable, Equatable, Sendable {
    public var typ: SectionKind
    public var slot: SlotTag
    public var minigameId: String
    public var fragen: Int
    public var schwierigkeiten: [Difficulty]
    public var kategorieWahl: KategorieWahl
    public var radDanach: Bool
    public var rundenNummer: Int
    public var kategorie: String?
    public var notariat: Bool
}

/// Question modifiers set by wheel, jokers or GM for the next question.
public struct QuestionMods: Codable, Equatable, Sendable {
    public var timerFaktor: Double = 1
    public var gewinnFaktor: Double = 1
    public var insiderId: PlayerId?
    public var insiderVorsprungMs = 3000
    public var geraeteMischung = false
    public var blackout = false
    public var steuerpruefung = false
    public var affeWuerfelt = false
    public var boersenRoulette: [PlayerId: String] = [:]
    public var goldeneBanane: Set<PlayerId> = []
    public var boostX2: Set<PlayerId> = []
    public var wertFaktor: Double = 1

    public init() {}
}

public struct RoundMods: Codable, Equatable, Sendable {
    public var dividende = false
    public var inflation = false
    public var notariat = false
    public init() {}
}

/// Stage moment/banner (every phone action gets a screen moment, §0.6).
public struct Moment: Codable, Equatable, Sendable, Identifiable {
    public var id: Int
    public var art: String
    public var text: String
    public var playerId: PlayerId?
    public var betrag: Int?
    public var at: Millis

    public init(id: Int, art: String, text: String, playerId: PlayerId? = nil, betrag: Int? = nil, at: Millis) {
        self.id = id
        self.art = art
        self.text = text
        self.playerId = playerId
        self.betrag = betrag
        self.at = at
    }
}

public struct LogEntry: Codable, Equatable, Sendable {
    public var at: Millis
    public var art: String
    public var text: String
    public var data: [String: JSONValue]
}

public struct WheelState: Codable, Equatable, Sendable {
    public var lastSegment: WheelSegmentId?
    public var spinsWithoutGold = 0
    public var face: [WheelSegmentId] = []
    public var resultIndex: Int?
    public var spinStartedAt: Millis?
    public var spinDurationMs = 0
    public var subphase: String = "idle" // idle | dreht | erklaert | interaktion | fertig
    public var interactionEndsAt: Millis?
    public var votes: [PlayerId: String] = [:]
    public var komplimentA: PlayerId?
    public var komplimentB: PlayerId?
    public var rigTarget: WheelSegmentId?
    public var respinsFree = 2
    public var spinsTotal = 0
    public init() {}
}

public struct CategoryVoteState: Codable, Equatable, Sendable {
    public var optionen: [String] = []
    public var stimmen: [PlayerId: String] = [:]
    public var letzterWaehlt: PlayerId?
    public var gewinner: String?
    public var endetAt: Millis?
    public var countdownAb: Millis?
    public init() {}
}

public struct GmVote: Codable, Equatable, Sendable {
    public var frage: String
    public var optionen: [String]
    public var stimmen: [PlayerId: Int]
    public var endetAt: Millis
    public var bindend: Bool
    public var ergebnis: Int?
}

public struct Award: Codable, Equatable, Sendable {
    public var titel: String
    public var emoji: String
    public var playerId: PlayerId
    public var detail: String
}

/// Snapshot of the flow position used by highlights.
public struct HighlightEntry: Codable, Equatable, Sendable {
    public var text: String
    public var emoji: String
    public var playerId: PlayerId?
}

/// Type-erased minigame state (each plugin owns its own Codable state).
public struct MinigameBox: Codable, Equatable, Sendable {
    public var id: String
    public var data: Data
    public var startedAt: Millis
    public var roundBased: Bool
}

/// Board game session (Spiele-Abend track) — see Boardgames/.
public struct BoardgameBox: Codable, Equatable, Sendable {
    public var id: String
    public var data: Data
    public var subphase: String // howto | spiel | ergebnis
    public var howtoEndsAt: Millis?
    public var sitze: [PlayerId]
    public var lokaleSitze: [String]
    public var ergebnis: [BoardgameResult]?
    public var startedAt: Millis
    public var optionen: [String: JSONValue]
}

public struct BoardgameResult: Codable, Equatable, Sendable {
    public var sitz: String
    public var name: String
    public var platz: Int
    public var mm: Int
    public var detail: String
    public var lokal: Bool
}

public struct AbendStats: Codable, Equatable, Sendable {
    public var beginnAt: Millis?
    public var atGesamt = 0
    public var spiele = 0
    public var proKopf: [PlayerId: Int] = [:]
    public init() {}
}

/// The whole match state — pure data, JSON-serialisable (save/load, reconnect
/// snapshots and the event log come for free).
public struct EngineState: Codable, Equatable, Sendable {
    public var matchId: String
    public var roomCode: String
    public var seed: UInt32
    public var rng: SeededRandom
    public var settings: MatchSettings
    public var phase: Phase
    public var phaseEndsAt: Millis?
    public var phaseStartedAt: Millis
    public var paused: Bool
    public var pausedAt: Millis?
    public var pauseText: String?
    public var pauseEndsAt: Millis?
    public var phaseBeforePause: Phase?
    public var players: [Player]
    public var teams: [Team]
    public var plan: [Section]
    public var sectionIndex: Int
    public var questionIndex: Int
    public var pool: [String]
    public var usedQuestionIds: [String]
    public var songPool: [String]
    public var usedSongIds: [String]
    public var currentQuestionIds: [String]
    public var minigame: MinigameBox?
    public var boardgame: BoardgameBox?
    public var jackpotGlas: Int
    public var affensteuerKiste: Int
    public var rad: WheelState
    public var nextMods: QuestionMods
    public var roundMods: RoundMods
    public var kategorie: CategoryVoteState
    public var bereit: [PlayerId]
    public var streik: [PlayerId]
    public var moments: [Moment]
    public var log: [LogEntry]
    public var tippStufe: Int
    public var whispers: [PlayerId: String]
    public var gmVote: GmVote?
    public var moodPoll: [PlayerId: Int]?
    public var moodPolls: Int
    public var feedback: [PlayerId: [String]]
    public var wFinal: Int?
    public var finaleAngesagt: Bool
    public var awards: [Award]
    public var highlights: [HighlightEntry]
    public var seq: Int
    public var momentSeq: Int
    public var lastRoundQuestionAt: Millis?
    public var questionsSinceWheel: Int
    public var ultrahardCount: Int
    public var timerExtensions: Int
    public var encoresThisRound: Int
    public var jokerGrantBudget: Int
    public var punishedLast: PlayerId?
    public var boostsThisRound: [PlayerId]
    public var kopfgeld: PlayerId?
    public var fuehrungsRunden: [PlayerId: Int]
    public var kapitalismusGongUsed: Bool
    public var letzteChanceGezeigt: Bool
    public var abend: AbendStats
    public var revancheNummer: Int
    public var halbzeitGemacht: Bool
    public var bilanzVorFinale: [PlayerId: Int]
    public var gmPin: String
    public var gmOnline: Bool
    public var screenOnline: Bool
    public var openingSkipped: Bool
    /// Deltas booked by the last question (for the reveal scene).
    public var lastDeltas: [PlayerId: Int]
    public var lastKorrekt: [PlayerId: Bool]

    public init(matchId: String, roomCode: String, seed: UInt32, settings: MatchSettings, now: Millis, gmPin: String) {
        self.matchId = matchId
        self.roomCode = roomCode
        self.seed = seed
        rng = SeededRandom(seed: seed)
        self.settings = settings
        phase = .lobby
        phaseEndsAt = nil
        phaseStartedAt = now
        paused = false
        pausedAt = nil
        pauseText = nil
        pauseEndsAt = nil
        phaseBeforePause = nil
        players = []
        teams = []
        plan = []
        sectionIndex = 0
        questionIndex = 0
        pool = []
        usedQuestionIds = []
        songPool = []
        usedSongIds = []
        currentQuestionIds = []
        minigame = nil
        boardgame = nil
        jackpotGlas = Economy.jackpotJarStart
        affensteuerKiste = 0
        rad = WheelState()
        nextMods = QuestionMods()
        roundMods = RoundMods()
        kategorie = CategoryVoteState()
        bereit = []
        streik = []
        moments = []
        log = []
        tippStufe = 0
        whispers = [:]
        gmVote = nil
        moodPoll = nil
        moodPolls = 0
        feedback = [:]
        wFinal = nil
        finaleAngesagt = false
        awards = []
        highlights = []
        seq = 0
        momentSeq = 0
        lastRoundQuestionAt = nil
        questionsSinceWheel = 0
        ultrahardCount = 0
        timerExtensions = 0
        encoresThisRound = 0
        jokerGrantBudget = 6
        punishedLast = nil
        boostsThisRound = []
        kopfgeld = nil
        fuehrungsRunden = [:]
        kapitalismusGongUsed = false
        letzteChanceGezeigt = false
        abend = AbendStats()
        revancheNummer = 0
        halbzeitGemacht = false
        bilanzVorFinale = [:]
        self.gmPin = gmPin
        gmOnline = false
        screenOnline = false
        openingSkipped = false
        lastDeltas = [:]
        lastKorrekt = [:]
    }

    public var currentSection: Section? {
        sectionIndex >= 0 && sectionIndex < plan.count ? plan[sectionIndex] : nil
    }

    public func player(_ id: PlayerId) -> Player? { players.first { $0.id == id } }
    public func index(of id: PlayerId) -> Int? { players.firstIndex { $0.id == id } }

    public var connectedPlayers: [Player] { players.filter { $0.connected } }

    /// Standings sorted by balance (ties by join order).
    public var ranking: [Player] {
        players.sorted { a, b in
            if a.balance != b.balance { return a.balance > b.balance }
            return a.joinOrder < b.joinOrder
        }
    }

    public func place(of id: PlayerId) -> Int {
        (ranking.firstIndex { $0.id == id } ?? 0) + 1
    }

    public var leader: Player? { ranking.first }
    public var last: Player? { ranking.last }

    public var isFinale: Bool { currentSection?.typ == .finale }
    public var isJackpot: Bool { currentSection?.typ == .jackpot }

    /// Fair-finale window: last 2 rounds + before the finale.
    public var fairFinaleWindow: Bool {
        let rounds = plan.filter { $0.typ == .runde }.count
        guard let s = currentSection else { return true }
        return s.typ != .runde || s.rundenNummer >= rounds - 1
    }

    public var lossFreeZone: Bool {
        guard let s = currentSection, s.typ == .runde else { return false }
        return s.rundenNummer <= max(1, Int((Double(plan.filter { $0.typ == .runde }.count) * 0.25).rounded()))
    }

    mutating func addMoment(_ art: String, _ text: String, player: PlayerId? = nil, betrag: Int? = nil, at: Millis) {
        momentSeq += 1
        moments.append(Moment(id: momentSeq, art: art, text: text, playerId: player, betrag: betrag, at: at))
        if moments.count > 12 { moments.removeFirst(moments.count - 12) }
    }

    mutating func addLog(_ art: String, _ text: String, at: Millis, data: [String: JSONValue] = [:]) {
        log.append(LogEntry(at: at, art: art, text: text, data: data))
        if log.count > 400 { log.removeFirst(log.count - 400) }
    }
}
