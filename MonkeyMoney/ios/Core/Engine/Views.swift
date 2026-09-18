import Foundation

// MARK: - Declarative UI contracts
//
// The engine never renders anything. It describes WHAT each device shows:
// `PlayerPrompt` for the phones (native SwiftUI, App Clip and the web fallback
// all render the same ~16 prompt kinds), `StageScene` for the iPad stage and
// `GmView` for the Show-Master cockpit. Minigames only produce these values,
// so 27 formats work on every client without per-format UI code.

public struct ChoiceOption: Codable, Equatable, Sendable, Identifiable {
    public var id: Int
    public var text: String
    public var removed: Bool
    public var count: Int?

    public init(id: Int, text: String, removed: Bool = false, count: Int? = nil) {
        self.id = id
        self.text = text
        self.removed = removed
        self.count = count
    }
}

public struct OrderItem: Codable, Equatable, Sendable, Identifiable {
    public var id: Int
    public var text: String
    public init(id: Int, text: String) {
        self.id = id
        self.text = text
    }
}

public struct PlayerRef: Codable, Equatable, Sendable, Identifiable {
    public var id: PlayerId
    public var name: String
    public var avatar: String
    public var balance: Int
    public var connected: Bool
    public var teamId: String?
    public var matsch: Bool
    public var clown: Bool
    public var streak: Int
    public var platz: Int

    public init(_ p: Player, platz: Int) {
        id = p.id
        name = p.name
        avatar = p.avatar.wire
        balance = p.balance
        connected = p.connected
        teamId = p.teamId
        matsch = p.matsch
        clown = p.clown
        streak = p.streak
        self.platz = platz
    }
}

public struct VoteOption: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var label: String
    public var emoji: String?
    public var count: Int
    public init(id: String, label: String, emoji: String? = nil, count: Int = 0) {
        self.id = id
        self.label = label
        self.emoji = emoji
        self.count = count
    }
}

/// What ONE phone shows right now.
public indirect enum PlayerPrompt: Codable, Equatable, Sendable {
    /// Look at the big screen (title + optional subtitle).
    case idle(title: String, subtitle: String?)
    /// Multiple choice (2–8 options). `chosen` = locked answer, `secondTry` = Rückgaberecht window open.
    case choice(question: String, options: [ChoiceOption], chosen: Int?, deadline: Millis?, secondTry: Bool, hint: String?)
    /// Pick several options (mehrfach).
    case multiChoice(question: String, options: [ChoiceOption], chosen: [Int], required: Int, locked: Bool, deadline: Millis?)
    /// One giant buzzer.
    case buzzer(question: String?, armed: Bool, pressed: Bool, lockedUntil: Millis?, hint: String?)
    /// Estimate slider / number input.
    case number(question: String, min: Double, max: Double, step: Double, log: Bool, unit: String, current: Double?, locked: Bool, deadline: Millis?)
    /// Drag-sort list.
    case order(question: String, items: [OrderItem], order: [Int], locked: Bool, deadline: Millis?)
    /// Money wager slider.
    case wager(title: String, subtitle: String?, min: Int, max: Int, step: Int, current: Int?, locked: Bool, deadline: Millis?)
    /// Free text (bluff lies, telegram words).
    case text(question: String, placeholder: String, maxLength: Int, submitted: String?, deadline: Millis?)
    /// Tap frenzy (Kokosnuss-Shake).
    case tapFrenzy(title: String, count: Int, deadline: Millis?, active: Bool)
    /// Distribute chips on options (Monkey Market / Börse).
    case chips(question: String, options: [ChoiceOption], total: Int, placed: [Int], locked: Bool, deadline: Millis?)
    /// Choose a player (steal victim, duel opponent, werewolf vote…).
    case pickPlayer(title: String, subtitle: String?, candidates: [PlayerRef], chosen: PlayerId?, deadline: Millis?)
    /// Affenbank: answer + BANK! button.
    case bank(question: String?, options: [ChoiceOption], chosen: Int?, pot: Int, banked: Int, deadline: Millis?)
    /// Spectator drum button while someone else holds the bomb etc.
    case cheer(title: String, subtitle: String?, taps: Int)
    /// Single confirm button (Umarmt!, Bereit, Ertragen…).
    case confirm(title: String, subtitle: String?, button: String, done: Bool, deadline: Millis?)
    /// Two-way choice with labels (Long/Short, Shot/Schotter, weiter/runter…).
    case binary(title: String, subtitle: String?, a: String, b: String, chosen: String?, deadline: Millis?)
    /// Category / GM vote.
    case vote(title: String, options: [VoteOption], chosen: String?, deadline: Millis?)
    /// Result card after a question.
    case reveal(title: String, correct: Bool?, delta: Int, detail: String?, streak: Int, speedBonus: Int?)
    /// Explain card readiness with strike option.
    case explain(title: String, text: String, ready: Bool, streik: Bool, deadline: Millis?)
    /// Free-form status list (e.g. Bananopoly portfolio) with action buttons.
    case actions(title: String, lines: [String], buttons: [ActionButton], deadline: Millis?)
    /// Feedback form (Abspann).
    case feedback(questions: [String], done: Bool)
    /// Hand of cards + action buttons (UNO and other card games).
    case cards(title: String, cards: [ChoiceOption], buttons: [ActionButton], deadline: Millis?, hint: String?)

    public var kind: String {
        switch self {
        case .idle: return "idle"
        case .choice: return "choice"
        case .multiChoice: return "multiChoice"
        case .buzzer: return "buzzer"
        case .number: return "number"
        case .order: return "order"
        case .wager: return "wager"
        case .text: return "text"
        case .tapFrenzy: return "tapFrenzy"
        case .chips: return "chips"
        case .pickPlayer: return "pickPlayer"
        case .bank: return "bank"
        case .cheer: return "cheer"
        case .confirm: return "confirm"
        case .binary: return "binary"
        case .vote: return "vote"
        case .reveal: return "reveal"
        case .explain: return "explain"
        case .actions: return "actions"
        case .feedback: return "feedback"
        case .cards: return "cards"
        }
    }
}

public struct ActionButton: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var label: String
    public var style: String // primary | secondary | danger
    public var enabled: Bool
    public init(id: String, label: String, style: String = "primary", enabled: Bool = true) {
        self.id = id
        self.label = label
        self.style = style
        self.enabled = enabled
    }
}

/// Joker as shown on the phone.
public struct JokerView: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var emoji: String
    public var ladungen: Int
    public var preis: Int
    public var kaufbar: Bool
    public var nutzbar: Bool
    public var beschreibung: String
}

/// Per-player view (what the phone renders).
public struct PlayerView: Codable, Equatable, Sendable {
    public var roomCode: String
    public var phase: Phase
    public var me: PlayerRef
    public var prompt: PlayerPrompt
    public var jokers: [JokerView]
    public var statusText: String
    public var phaseEndsAt: Millis?
    public var paused: Bool
    public var pauseText: String?
    public var serverTime: Millis
    public var rueckenwind: Double
    public var whisper: String?
    public var moments: [Moment]
    public var ranking: [PlayerRef]
    public var teamTopf: Int?
    public var sectionLabel: String
    public var ohneScreen: Bool
    public var haptic: String?
    public var flash: String?
}

// MARK: Stage

public struct QuestionWall: Codable, Equatable, Sendable {
    public var text: String
    public var kategorie: String
    public var kategorieName: String
    public var kategorieEmoji: String
    public var schwierigkeit: Difficulty
    public var wert: Int
    public var options: [ChoiceOption]?
    public var answered: [PlayerId]
    public var deadline: Millis?
    public var timerMs: Int
    public var revealed: Bool
    public var correctIndex: Int?
    public var answersByPlayer: [PlayerId: Int]
    public var image: String?
    public var pixelLevel: Int?
    public var erklaerung: String?
    public var tipp: String?
    public var nummer: Int
    public var gesamt: Int
    public var blackout: Bool
    public var goldenFor: [PlayerId]

    public init(text: String, kategorie: String, kategorieName: String, kategorieEmoji: String, schwierigkeit: Difficulty,
                wert: Int, options: [ChoiceOption]?, answered: [PlayerId], deadline: Millis?, timerMs: Int, revealed: Bool,
                correctIndex: Int?, answersByPlayer: [PlayerId: Int], image: String? = nil, pixelLevel: Int? = nil,
                erklaerung: String? = nil, tipp: String? = nil, nummer: Int, gesamt: Int, blackout: Bool = false,
                goldenFor: [PlayerId] = []) {
        self.text = text
        self.kategorie = kategorie
        self.kategorieName = kategorieName
        self.kategorieEmoji = kategorieEmoji
        self.schwierigkeit = schwierigkeit
        self.wert = wert
        self.options = options
        self.answered = answered
        self.deadline = deadline
        self.timerMs = timerMs
        self.revealed = revealed
        self.correctIndex = correctIndex
        self.answersByPlayer = answersByPlayer
        self.image = image
        self.pixelLevel = pixelLevel
        self.erklaerung = erklaerung
        self.tipp = tipp
        self.nummer = nummer
        self.gesamt = gesamt
        self.blackout = blackout
        self.goldenFor = goldenFor
    }
}

public struct Guess: Codable, Equatable, Sendable {
    public var playerId: PlayerId
    public var value: Double
    public var distanz: Double?
    public var platz: Int?
}

public struct Bet: Codable, Equatable, Sendable {
    public var playerId: PlayerId
    public var betrag: Int
    public var revealed: Bool
}

/// Minigame-specific stage widgets, rendered around/under the question wall.
public indirect enum StageExtra: Codable, Equatable, Sendable {
    case none
    /// Kokosnuss-Uhr: shrinking money sack with frozen amounts per player.
    case sack(current: Int, start: Int, frozen: [PlayerId: Int])
    /// Affenbank: chain pot, banked amounts, last bank event.
    case bankPot(pot: Int, chain: Int, banked: [PlayerId: Int], lastBanker: PlayerId?, majorityCorrect: Bool?, durchgang: Int)
    /// Stinkbanane: who holds the bomb, fuse tension 0…1, passes so far.
    case bomb(holder: PlayerId?, tension: Double, passes: Int, exploded: PlayerId?, durchgang: Int)
    /// Alles oder Banane: bets (revealed one by one), teaser.
    case bets(bets: [Bet], teaser: String?, phase: String)
    /// Bananen-Tresor: number line with guesses and truth.
    case numberLine(min: Double, max: Double, unit: String, guesses: [Guess], truth: Double?, log: Bool)
    /// Affenleiter: items in correct order (revealed steps) + player orders.
    case ladder(items: [String], correctOrder: [Int], revealedSteps: Int, playerOrders: [PlayerId: [Int]], werte: [String])
    /// Pixel-Dschungel: image, level 0…8, jackpot ladder.
    case pixel(image: String, level: Int, maxLevel: Int, jackpot: Int, locked: [PlayerId])
    /// Taschendieb: thief/victim/amount cutscene.
    case steal(thief: PlayerId?, victim: PlayerId?, betrag: Int, phase: String, candidates: [PlayerId])
    /// Lianen-Finale: normalised liana lengths + W.
    case lianen(lengths: [PlayerId: Double], w: Int, deltas: [PlayerId: Int])
    /// Buzzer race (song snippet, goldener affe, boxkampf…): who buzzed, rank order.
    case buzzers(armed: Bool, order: [PlayerId], lockedOut: [PlayerId], stufe: String?, wert: Int)
    /// Chips on doors (Monkey Market / Börse): per option total chips, quotes.
    case chips(perOption: [Int], quotes: [Double]?, placedBy: [PlayerId: [Int]])
    /// Auction: current bids.
    case auction(bids: [PlayerId: Int], leader: PlayerId?, endsAt: Millis?, phase: String)
    /// Bluff: submitted lies (anonymised), votes.
    case bluff(entries: [ChoiceOption], authors: [Int: PlayerId]?, votes: [PlayerId: Int], phase: String, truthIndex: Int?)
    /// Duel: two fighters, score/HP, spectator bets.
    case duel(a: PlayerId, b: PlayerId, scoreA: Int, scoreB: Int, maxScore: Int, bets: [PlayerId: PlayerId], phase: String, label: String)
    /// Generic ladder of steps (Risiko-Leiter / Goldener Affe stages).
    case steps(labels: [String], current: Int, positions: [PlayerId: Int], banked: [PlayerId: Int])
    /// Pie fight: dirt levels per player, who is out.
    case pies(dirt: [PlayerId: Int], out: [PlayerId], maxDirt: Int)
    /// Telegram: pairs and revealed letters.
    case telegram(pairs: [[PlayerId]], letters: [String], solved: [Int], wort: String?)
    /// One vs all: soloist and crowd tallies.
    case oneVsAll(solist: PlayerId, solistCorrect: Bool?, crowd: [PlayerId: Int], crowdCorrect: Int, frage: Int)
    /// Song formats: audio cue to play on the stage + reveal info.
    case song(songId: String, snippet: String, playAt: Millis?, revealed: Bool, titel: String?, artist: String?, video: Bool, hint: [String]?)
    /// Free key/value stats card.
    case card(title: String, lines: [String])
}

public struct WheelView: Codable, Equatable, Sendable {
    public var face: [WheelSegment]
    public var resultIndex: Int?
    public var subphase: String
    public var spinStartedAt: Millis?
    public var spinDurationMs: Int
    public var erklaerung: String?
    public var betroffene: [PlayerId]
    public var interactionEndsAt: Millis?
}

public struct PodiumEntry: Codable, Equatable, Sendable {
    public var player: PlayerRef
    public var platz: Int
    public var mm: Int
    public var at: Int
    public var delta: Int
}

public struct StandingEntry: Codable, Equatable, Sendable {
    public var player: PlayerRef
    public var delta: Int
    public var rueckenwind: Double
}

public struct LobbyInfo: Codable, Equatable, Sendable {
    public var joinURL: String
    public var gmURL: String
    public var gmPin: String
    public var maxPlayers: Int
    public var canStart: Bool
    public var startHint: String
    public var settings: MatchSettings
    public var boardgames: [BoardgameCard]
}

public struct BoardgameCard: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var emoji: String
    public var untertitel: String
    public var minSpieler: Int
    public var maxSpieler: Int
    public var phonesOnly: Bool
    public var howto: [String]
    public var startbar: Bool
    public var hinweis: String
    public var varianten: [String]
}

public struct ExplainCardView: Codable, Equatable, Sendable {
    public var minigameId: String
    public var name: String
    public var emoji: String
    public var text: String
    public var slot: SlotTag
    public var rundenNummer: Int
    public var rundenGesamt: Int
    public var bereit: [PlayerId]
    public var streik: [PlayerId]
    public var kategorie: String?
    public var deadline: Millis?
}

/// The scene the iPad renders.
public indirect enum StageScene: Codable, Equatable, Sendable {
    case lobby(LobbyInfo)
    case intro(headline: String, specialRules: [String], deadline: Millis?)
    case kategorieWahl(optionen: [VoteOption], letzter: PlayerRef?, deadline: Millis?, countdownAb: Millis?, gewinner: String?)
    case erklaerkarte(ExplainCardView)
    case frage(wall: QuestionWall?, extra: StageExtra, minigameId: String, sectionKind: SectionKind, title: String)
    case aufloesung(wall: QuestionWall?, extra: StageExtra, deltas: [PlayerId: Int], minigameId: String, sectionKind: SectionKind)
    case zwischenstand(entries: [StandingEntry], rundenNummer: Int, rundenGesamt: Int, deadline: Millis?, halbzeit: Bool)
    case rad(WheelView)
    case pause(text: String, endsAt: Millis?, standings: [StandingEntry])
    case highlights(entries: [HighlightEntry], deadline: Millis?)
    case siegerehrung(podium: [PodiumEntry], awards: [Award], deadline: Millis?, revancheMoeglich: Bool, abend: AbendStats)
    case ende(podium: [PodiumEntry])
    case brettspiel(BoardgameStageView)
}

public struct BoardgameStageView: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var subphase: String
    public var howto: [String]
    public var howtoEndsAt: Millis?
    public var view: JSONValue
    public var ergebnis: [BoardgameResult]?
    public var aktuellerSpieler: String?
    public var lokalerPrompt: String?
    public var sitze: [String]
}

public struct StageView: Codable, Equatable, Sendable {
    public var roomCode: String
    public var phase: Phase
    public var scene: StageScene
    public var players: [PlayerRef]
    public var teams: [Team]
    public var jackpotGlas: Int
    public var jackpotAktiv: Bool
    public var moments: [Moment]
    public var serverTime: Millis
    public var paused: Bool
    public var sectionLabel: String
    public var progress: Double
    public var gmOnline: Bool
    public var gmLos: Bool
    public var canAdvance: Bool
    public var advanceLabel: String?
    public var audio: AudioCue?
    public var modus: Modus
    public var seq: Int
    public var specialRules: [String]
    public var affensteuerKiste: Int
}

/// Music/SFX hint for the stage (the stage decides what to actually play).
public struct AudioCue: Codable, Equatable, Sendable {
    public var music: String?
    public var sfx: [String]
    public init(music: String?, sfx: [String] = []) {
        self.music = music
        self.sfx = sfx
    }
}

// MARK: GM

public struct GmQuestionInfo: Codable, Equatable, Sendable {
    public var id: String
    public var text: String
    public var kategorie: String
    public var schwierigkeit: Difficulty
    public var korrekt: String
    public var erklaerung: String
    public var tipps: [String]
    public var typ: QuestionType
}

public struct GmView: Codable, Equatable, Sendable {
    public var stage: StageView
    public var spickzettel: GmQuestionInfo?
    public var antworten: [PlayerId: String]
    public var regal: [GmQuestionInfo]
    public var settings: MatchSettings
    public var log: [LogEntry]
    public var timerExtensionsLeft: Int
    public var jokerBudget: Int
    public var encoresLeft: Int
    public var moodPollsLeft: Int
    public var dramaScore: Int
    public var empfehlung: String
    public var vote: GmVote?
    public var canRig: Bool
    public var gmPin: String
    public var players: [Player]
    public var roomCode: String
    public var joinURL: String
}
