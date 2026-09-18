import Foundation

/// Generic phone input — every prompt kind has exactly one action shape.
public enum PlayerAction: Codable, Equatable, Sendable {
    case choose(Int)
    case multiChoose([Int])
    case buzz(at: Millis)
    case number(Double)
    case order([Int])
    case wager(Int)
    case text(String)
    case taps(Int)
    case chips([Int])
    case pickPlayer(PlayerId)
    case bank
    case cheer
    case confirm
    case binary(String)
    case vote(String)
    case ready(String)
    case button(String)
    case joker(id: String, stufe: Int?)
    case jokerBuy(String)
    case feedback([String])
    case setLook(Avatar)
    case setThemen([String])
    case radAktion(String)
    case teamWunsch(String)
}

/// GM/engine intervention every plugin understands.
public enum GmMinigameAction: Equatable, Sendable {
    case timerExtend(ms: Int)
    case timerShift(ms: Int)
    case forceFinish
    case removeOption(player: PlayerId?)
    case fiftyFifty(player: PlayerId)
    case secondTry(player: PlayerId)
    case skipQuestion
}

public struct Outcome: Codable, Equatable, Sendable {
    /// true = correct, false = wrong, nil = no answer / not applicable.
    public var correct: Bool?
    public var answeredAfterMs: Int?
    public var timerMs: Int?
    public var speedBonus: Int
    /// Whether this outcome counts for the streak chain (question formats only).
    public var countsForStreak: Bool
    public var detail: String?

    public init(correct: Bool?, answeredAfterMs: Int? = nil, timerMs: Int? = nil, speedBonus: Int = 0, countsForStreak: Bool = true, detail: String? = nil) {
        self.correct = correct
        self.answeredAfterMs = answeredAfterMs
        self.timerMs = timerMs
        self.speedBonus = speedBonus
        self.countsForStreak = countsForStreak
        self.detail = detail
    }
}

public enum ContentKind: Equatable, Sendable {
    case fragen([QuestionType])
    case songs(video: Bool)
    case none

    public static let choiceLike = ContentKind.fragen([.choice, .emoji, .wahrFalsch, .bildPixel])
}

public struct MinigameMeta: Sendable {
    public var id: String
    public var name: String
    public var emoji: String
    public var kurz: String
    public var erklaerung: String
    /// Explain card as a checklist: 3–5 short rules, one payout line —
    /// what the iPad shows big and the phones show as bullets.
    public var regeln: [String]
    public var gewinn: String
    public var minPlayers: Int
    public var maxPlayers: Int
    public var contentKind: ContentKind
    /// Round-based plugins receive ALL questions of the round and book once at the end.
    public var roundBased: Bool
    /// Do results feed the streak chain (§3.1)?
    public var streak: Bool
    /// Penalties flow into the jackpot jar.
    public var strafenInsGlas: Bool
    public var jokerAktionen: Set<String>
    /// Is the phone prompt a multiple-choice question (wheel compatibility)?
    public var isMc: Bool
    public var musik: String
    public var v2: Bool
    public var minVideoSongs: Int

    public init(id: String, name: String, emoji: String, kurz: String, erklaerung: String, regeln: [String] = [], gewinn: String = "",
                minPlayers: Int = 2, maxPlayers: Int = 8,
                contentKind: ContentKind = .choiceLike, roundBased: Bool = false, streak: Bool = true, strafenInsGlas: Bool = false,
                jokerAktionen: Set<String> = ["fiftyFifty", "removeOne", "secondTry"], isMc: Bool = true, musik: String = "question_bed_easy",
                v2: Bool = false, minVideoSongs: Int = 0) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.kurz = kurz
        self.erklaerung = erklaerung
        self.regeln = regeln.isEmpty ? [erklaerung] : regeln
        self.gewinn = gewinn
        self.minPlayers = minPlayers
        self.maxPlayers = maxPlayers
        self.contentKind = contentKind
        self.roundBased = roundBased
        self.streak = streak
        self.strafenInsGlas = strafenInsGlas
        self.jokerAktionen = jokerAktionen
        self.isMc = isMc
        self.musik = musik
        self.v2 = v2
        self.minVideoSongs = minVideoSongs
    }
}

/// Everything a plugin may know about the match. Clock and randomness are
/// injected (never `Date()` / `random()` inside a plugin).
public struct MinigameContext: Sendable {
    public var now: Millis
    public var rng: SeededRandom
    public var settings: MatchSettings
    public var players: [PlayerId]
    public var names: [PlayerId: String]
    public var balances: [PlayerId: Int]
    public var connected: Set<PlayerId>
    public var klauSchutz: Set<PlayerId>
    public var mods: QuestionMods
    public var section: Section
    public var catalog: ContentCatalog
    public var teams: [Team]
    public var medianRtt: [PlayerId: Int]
    public var fragenNummer: Int
    public var fragenGesamt: Int
    public var isFinale: Bool
    public var wFinal: Int

    public init(now: Millis, rng: SeededRandom, settings: MatchSettings, players: [PlayerId], names: [PlayerId: String],
                balances: [PlayerId: Int], connected: Set<PlayerId>, klauSchutz: Set<PlayerId>, mods: QuestionMods,
                section: Section, catalog: ContentCatalog, teams: [Team] = [], medianRtt: [PlayerId: Int] = [:],
                fragenNummer: Int = 1, fragenGesamt: Int = 1, isFinale: Bool = false, wFinal: Int = 0) {
        self.now = now
        self.rng = rng
        self.settings = settings
        self.players = players
        self.names = names
        self.balances = balances
        self.connected = connected
        self.klauSchutz = klauSchutz
        self.mods = mods
        self.section = section
        self.catalog = catalog
        self.teams = teams
        self.medianRtt = medianRtt
        self.fragenNummer = fragenNummer
        self.fragenGesamt = fragenGesamt
        self.isFinale = isFinale
        self.wFinal = wFinal
    }

    public func name(_ id: PlayerId) -> String { names[id] ?? "?" }
    public func ms(_ base: Int) -> Int { settings.ms(base) }

    /// Effectively "no timer" — an hour; the question ends when everyone answered or the GM resolves.
    public static let unlimitedMs = 3_600_000

    public var timerAus: Bool { settings.timerAus }

    /// Timer for a question honouring difficulty, tempo, the Show-Master's
    /// fixed time-per-question override, the timer-off switch and wheel modifiers.
    public func timerMs(for q: Question) -> Int {
        if settings.timerAus { return MinigameContext.unlimitedMs }
        let base = settings.fragenZeit.map { $0 * 1000 } ?? settings.ms(Money.timerMs(q.schw))
        return max(3000, Int(Double(base) * mods.timerFaktor))
    }

    /// Answer window for non-MC inputs (estimate, sort, bets, bids, lies…):
    /// tempo-scaled, never shorter than the fixed override, unlimited when the timer is off.
    public func answerWindow(_ base: Int) -> Int {
        if settings.timerAus { return MinigameContext.unlimitedMs }
        let scaled = settings.ms(base)
        if let fixed = settings.fragenZeit { return max(scaled, fixed * 1000) }
        return scaled
    }

    /// Deadline as shown to clients — hidden while the timer is off.
    public func visible(_ deadline: Millis?) -> Millis? { settings.timerAus ? nil : deadline }

    public var richest: PlayerId? {
        players.max { (balances[$0] ?? 0) < (balances[$1] ?? 0) }
    }

    public var poorest: PlayerId? {
        players.min { (balances[$0] ?? 0) < (balances[$1] ?? 0) }
    }
}

public struct MinigameStageOutput: Sendable {
    public var wall: QuestionWall?
    public var extra: StageExtra
    public var title: String
    public var audio: AudioCue?

    public init(wall: QuestionWall?, extra: StageExtra = .none, title: String = "", audio: AudioCue? = nil) {
        self.wall = wall
        self.extra = extra
        self.title = title
        self.audio = audio
    }
}

public protocol MinigamePlugin {
    associatedtype State: Codable & Equatable & Sendable
    static var meta: MinigameMeta { get }
    static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State
    static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext)
    static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext)
    static func tick(_ state: inout State, ctx: inout MinigameContext)
    static func onDisconnect(_ state: inout State, player: PlayerId, ctx: inout MinigameContext)
    static func onReconnect(_ state: inout State, player: PlayerId, ctx: inout MinigameContext)
    static func isFinished(_ state: State, ctx: MinigameContext) -> Bool
    static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int]
    static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome]
    static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput
    static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt
    static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String])
    /// Questions consumed so far (round-based plugins report how far they got).
    static func questionsUsed(_ state: State) -> Int
}

public extension MinigamePlugin {
    static func onDisconnect(_ state: inout State, player: PlayerId, ctx: inout MinigameContext) {}
    static func onReconnect(_ state: inout State, player: PlayerId, ctx: inout MinigameContext) {}
    static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {}
    static func questionsUsed(_ state: State) -> Int { 1 }
}

/// Type-erased plugin so the engine can hold any format in `MinigameBox`.
public struct AnyMinigame: Sendable {
    public let meta: MinigameMeta
    public let initBox: @Sendable ([Question], [Song], inout MinigameContext) -> Data
    public let reduce: @Sendable (inout Data, PlayerAction, PlayerId, inout MinigameContext) -> Void
    public let gm: @Sendable (inout Data, GmMinigameAction, inout MinigameContext) -> Void
    public let tick: @Sendable (inout Data, inout MinigameContext) -> Void
    public let onDisconnect: @Sendable (inout Data, PlayerId, inout MinigameContext) -> Void
    public let onReconnect: @Sendable (inout Data, PlayerId, inout MinigameContext) -> Void
    public let isFinished: @Sendable (Data, MinigameContext) -> Bool
    public let scores: @Sendable (Data, MinigameContext) -> [PlayerId: Int]
    public let outcomes: @Sendable (Data, MinigameContext) -> [PlayerId: Outcome]
    public let stage: @Sendable (Data, Bool, MinigameContext) -> MinigameStageOutput
    public let prompt: @Sendable (Data, PlayerId, Bool, MinigameContext) -> PlayerPrompt
    public let gmInfo: @Sendable (Data, MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String])
    public let questionsUsed: @Sendable (Data) -> Int

    public init<P: MinigamePlugin>(_ plugin: P.Type) {
        meta = P.meta
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let dec = JSONDecoder()
        func load(_ d: Data) -> P.State? { try? dec.decode(P.State.self, from: d) }
        func save(_ s: P.State) -> Data { (try? enc.encode(s)) ?? Data() }
        initBox = { q, s, ctx in save(P.initState(questions: q, songs: s, ctx: &ctx)) }
        reduce = { d, a, p, ctx in
            guard var s = load(d) else { return }
            P.reduce(&s, action: a, from: p, ctx: &ctx)
            d = save(s)
        }
        gm = { d, a, ctx in
            guard var s = load(d) else { return }
            P.gm(&s, action: a, ctx: &ctx)
            d = save(s)
        }
        tick = { d, ctx in
            guard var s = load(d) else { return }
            P.tick(&s, ctx: &ctx)
            d = save(s)
        }
        onDisconnect = { d, p, ctx in
            guard var s = load(d) else { return }
            P.onDisconnect(&s, player: p, ctx: &ctx)
            d = save(s)
        }
        onReconnect = { d, p, ctx in
            guard var s = load(d) else { return }
            P.onReconnect(&s, player: p, ctx: &ctx)
            d = save(s)
        }
        isFinished = { d, ctx in load(d).map { P.isFinished($0, ctx: ctx) } ?? true }
        scores = { d, ctx in load(d).map { P.scores($0, ctx: ctx) } ?? [:] }
        outcomes = { d, ctx in load(d).map { P.outcomes($0, ctx: ctx) } ?? [:] }
        stage = { d, r, ctx in load(d).map { P.stage($0, revealed: r, ctx: ctx) } ?? MinigameStageOutput(wall: nil) }
        prompt = { d, p, r, ctx in load(d).map { P.prompt($0, player: p, revealed: r, ctx: ctx) } ?? .idle(title: "…", subtitle: nil) }
        gmInfo = { d, ctx in load(d).map { P.gmInfo($0, ctx: ctx) } ?? (nil, [:]) }
        questionsUsed = { d in load(d).map { P.questionsUsed($0) } ?? 1 }
    }
}

/// Static registry of all formats. Playlist wishes that are not available
/// (e.g. song formats without songs) fall back to Vier Lianen.
public enum MinigameRegistry {
    public static let all: [AnyMinigame] = [
        AnyMinigame(VierLianen.self),
        AnyMinigame(BananenBasics.self),
        AnyMinigame(KokosnussUhr.self),
        AnyMinigame(BananenTresor.self),
        AnyMinigame(Affenleiter.self),
        AnyMinigame(PixelDschungel.self),
        AnyMinigame(Affenbank.self),
        AnyMinigame(Stinkbanane.self),
        AnyMinigame(Taschendieb.self),
        AnyMinigame(AllesOderBanane.self),
        AnyMinigame(LianenFinale.self),
        AnyMinigame(MonkeyMarket.self),
        AnyMinigame(BananenBoerse.self),
        AnyMinigame(AffenAuktion.self),
        AnyMinigame(BananenBluff.self),
        AnyMinigame(LianenstegDuell.self),
        AnyMinigame(GoldenerAffe.self),
        AnyMinigame(RisikoLeiter.self),
        AnyMinigame(EinerGegenAlle.self),
        AnyMinigame(KonterQuiz.self),
        AnyMinigame(BananenBoxkampf.self),
        AnyMinigame(BananenTortenschlacht.self),
        AnyMinigame(BuchstabenTelegramm.self),
        AnyMinigame(SongSnippet.self),
        AnyMinigame(SongRueckwaerts.self),
        AnyMinigame(MusikvideoRaten.self),
        AnyMinigame(WerSingts.self),
        AnyMinigame(KokosnussShake.self),
    ]

    public static func plugin(_ id: String) -> AnyMinigame? { all.first { $0.meta.id == id } }

    public static let fallbackId = "vier-lianen"

    /// What the current match can feed a format: players, songs, and — inside
    /// the chosen question pool — how many questions of each type exist.
    public struct Availability: Sendable {
        public var playerCount: Int
        public var songsAvailable: Int
        public var videoSongs: Int
        public var v2: Bool
        public var typeCounts: [QuestionType: Int]

        public init(playerCount: Int, songsAvailable: Int, videoSongs: Int, v2: Bool, typeCounts: [QuestionType: Int] = [:]) {
            self.playerCount = playerCount
            self.songsAvailable = songsAvailable
            self.videoSongs = videoSongs
            self.v2 = v2
            self.typeCounts = typeCounts
        }

        /// Empty counts = "not known" (legacy callers) → no type gating.
        var typesKnown: Bool { !typeCounts.isEmpty }
    }

    /// Resolve a playlist wish to an available plugin for this match.
    public static func resolve(_ id: String, playerCount: Int, songsAvailable: Int, videoSongs: Int, v2: Bool) -> AnyMinigame {
        resolve(id, Availability(playerCount: playerCount, songsAvailable: songsAvailable, videoSongs: videoSongs, v2: v2))
    }

    public static func resolve(_ id: String, _ a: Availability) -> AnyMinigame {
        if let p = plugin(id), available(p, a) { return p }
        return plugin(fallbackId)!
    }

    public static func available(_ p: AnyMinigame, playerCount: Int, songsAvailable: Int, videoSongs: Int, v2: Bool) -> Bool {
        available(p, Availability(playerCount: playerCount, songsAvailable: songsAvailable, videoSongs: videoSongs, v2: v2))
    }

    /// A format is available when the players fit, its songs exist and the
    /// question pool holds the types it is built around (an estimate round
    /// needs Schätz-Fragen, the ladder Sortier-Fragen, the Pixel-Dschungel a
    /// picture riddle) — otherwise the playlist falls back to Vier Lianen.
    public static func available(_ p: AnyMinigame, _ a: Availability) -> Bool {
        if p.meta.v2 && !a.v2 { return false }
        if a.playerCount < p.meta.minPlayers || a.playerCount > p.meta.maxPlayers { return false }
        switch p.meta.contentKind {
        case .songs(let video):
            if video { return a.videoSongs >= max(3, p.meta.minVideoSongs) }
            return a.songsAvailable >= 3
        case .fragen(let types):
            guard a.typesKnown, let primary = types.first else { return true }
            // The first listed type is the format's essence (Schätz for the Tresor,
            // Sortier for the ladder, a picture for the Pixel-Dschungel); the rest are
            // fallbacks. Choice-like formats run on any pool with a handful of questions.
            switch primary {
            case .schaetz, .sortier: return (a.typeCounts[primary] ?? 0) >= 4
            case .bildPixel: return (a.typeCounts[.bildPixel] ?? 0) >= 1
            default: return types.reduce(0) { $0 + (a.typeCounts[$1] ?? 0) } >= 4
            }
        case .none:
            return true
        }
    }
}
