import Foundation

/// Shared helpers for the four music formats: a song question with the title
/// (or artist) as the correct option and distractors from the rest of the pool.
enum SongHelpers {
    static func options(target: Song, pool: [Song], artist: Bool, rng: inout SeededRandom) -> (options: [String], correct: Int) {
        let key: (Song) -> String = { artist ? ($0.artist.isEmpty ? $0.titel : $0.artist) : $0.titel }
        var distractors = pool.filter { $0.id != target.id }.map(key).filter { $0 != key(target) }
        distractors = Array(Set(distractors))
        distractors = rng.shuffled(distractors)
        var opts = Array(distractors.prefix(3))
        while opts.count < 3 { opts.append(["Unbekannter Künstler", "Bananen-Boogie", "Affen-Anthem", "Dschungel-Disco"][opts.count]) }
        opts.append(key(target))
        opts = rng.shuffled(opts)
        return (opts, opts.firstIndex(of: key(target)) ?? 0)
    }

    static func asQuestion(_ target: Song, options: [String], correct: Int, text: String, kat: String = "musik") -> Question {
        Question(id: "song_\(target.id)", kat: kat, sub: "songs", schw: target.schw, region: target.region, typ: .choice, text: text,
                 tipps: [target.jahr.map { "Erschienen \($0)." } ?? "", target.tags.first.map { "Stil: \($0)." } ?? ""].filter { !$0.isEmpty },
                 erkl: "\(target.titel) — \(target.artist)\(target.jahr.map { " (\($0))" } ?? "")", antworten: options, korrekt: correct)
    }

    static func songExtra(_ s: Song, snippet: String, playAt: Millis?, revealed: Bool, video: Bool = false) -> StageExtra {
        .song(songId: s.id, snippet: snippet, playAt: playAt, revealed: revealed, titel: revealed ? s.titel : nil, artist: revealed ? s.artist : nil, video: video, hint: video ? s.videoHint : nil)
    }
}

/// Rückwärts-Banane — the song plays backwards for 5 s, everyone guesses the title.
public enum SongRueckwaerts: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var core: ChoiceCore
        public var song: Song
        public var playAt: Millis
    }

    public static let meta = MinigameMeta(
        id: "song-rueckwaerts", name: "Rückwärts-Banane", emoji: "⏪",
        kurz: "Der Song läuft rückwärts — erkennst du ihn trotzdem?",
        erklaerung: "Der DJ dreht die Platte falsch herum: Fünf Sekunden Song rückwärts, dann vier Titel zur Auswahl. Alle antworten gleichzeitig, richtig zahlt den Songwert plus Speed-Bonus.",
        regeln: ["5 Sekunden Song — rückwärts!",
                 "Dann 4 Titel zur Auswahl, alle antworten gleichzeitig",
                 "Richtig zahlt den Songwert plus Speed-Bonus"],
        gewinn: "Richtig: Songwert + Speed-Bonus",
        contentKind: .songs(video: false), jokerAktionen: ["fiftyFifty", "removeOne"], musik: "music_round_dj", v2: true
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        let target = songs.first ?? Song(id: "s_none", titel: "Bananen-Boogie", artist: "Die Affen", jahr: nil, region: .global, schw: .medium, tags: [], hatVideo: false, videoHint: nil, komponist: nil)
        let (opts, correct) = SongHelpers.options(target: target, pool: songs + ctx.catalog.songs, artist: false, rng: &ctx.rng)
        let q = SongHelpers.asQuestion(target, options: opts, correct: correct, text: "Welcher Song läuft hier RÜCKWÄRTS?")
        var core = ChoiceCore(question: q, ctx: ctx, timerMs: ctx.answerWindow(20_000))
        core.startedAt = ctx.now + 5000
        core.deadline = core.startedAt + core.timerMs
        return State(core: core, song: target, playAt: ctx.now)
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        if case .choose(let i) = action, ctx.now >= state.core.startedAt { _ = state.core.answer(player, index: i, now: ctx.now) }
    }
    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) { state.core.applyGm(action, ctx: &ctx) }
    public static func tick(_ state: inout State, ctx: inout MinigameContext) {}
    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { ctx.now >= state.core.startedAt && state.core.finished(now: ctx.now, ctx: ctx) }
    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] { state.core.standardScores(ctx: ctx, speed: true) }
    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] { state.core.standardOutcomes(ctx: ctx, speed: true) }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        MinigameStageOutput(wall: state.core.wall(ctx: ctx, revealed: revealed), extra: SongHelpers.songExtra(state.song, snippet: "rueckwaerts5s", playAt: state.playAt, revealed: revealed), title: meta.name)
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed { return state.core.prompt(for: player, ctx: ctx, revealed: true, delta: scores(state, ctx: ctx)[player]) }
        if ctx.now < state.core.startedAt { return .idle(title: "⏪ Ohren auf!", subtitle: "Der Song läuft rückwärts …") }
        return state.core.prompt(for: player, ctx: ctx, revealed: false)
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) { state.core.gmInfo(ctx: ctx) }
}

/// Wer singt's? — 10 s from the middle of the song, guess the artist.
public enum WerSingts: MinigamePlugin {
    public typealias State = SongRueckwaerts.State

    public static let meta = MinigameMeta(
        id: "wer-singts", name: "Wer singt's?", emoji: "🎤",
        kurz: "Zehn Sekunden Song — welcher Künstler ist das?",
        erklaerung: "Zehn Sekunden aus der Mitte eines Songs. Wer singt das? Vier Namen zur Auswahl, alle antworten gleichzeitig. Richtig zahlt den Songwert plus Speed-Bonus.",
        regeln: ["10 Sekunden aus der Mitte eines Songs",
                 "Wer singt das? 4 Namen zur Auswahl",
                 "Alle antworten gleichzeitig"],
        gewinn: "Richtig: Songwert + Speed-Bonus",
        contentKind: .songs(video: false), jokerAktionen: ["fiftyFifty", "removeOne"], musik: "music_round_dj", v2: true
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        let target = songs.first ?? Song(id: "s_none", titel: "Bananen-Boogie", artist: "Die Affen", jahr: nil, region: .global, schw: .medium, tags: [], hatVideo: false, videoHint: nil, komponist: nil)
        let (opts, correct) = SongHelpers.options(target: target, pool: songs + ctx.catalog.songs, artist: true, rng: &ctx.rng)
        let q = SongHelpers.asQuestion(target, options: opts, correct: correct, text: "Wer singt / spielt diesen Song?")
        var core = ChoiceCore(question: q, ctx: ctx, timerMs: ctx.answerWindow(20_000))
        core.startedAt = ctx.now + 3000
        core.deadline = core.startedAt + core.timerMs
        return State(core: core, song: target, playAt: ctx.now)
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) { SongRueckwaerts.reduce(&state, action: action, from: player, ctx: &ctx) }
    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) { state.core.applyGm(action, ctx: &ctx) }
    public static func tick(_ state: inout State, ctx: inout MinigameContext) {}
    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { SongRueckwaerts.isFinished(state, ctx: ctx) }
    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] { state.core.standardScores(ctx: ctx, speed: true) }
    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] { state.core.standardOutcomes(ctx: ctx, speed: true) }
    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        MinigameStageOutput(wall: state.core.wall(ctx: ctx, revealed: revealed), extra: SongHelpers.songExtra(state.song, snippet: "mitte10s", playAt: state.playAt, revealed: revealed), title: meta.name)
    }
    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed { return state.core.prompt(for: player, ctx: ctx, revealed: true, delta: scores(state, ctx: ctx)[player]) }
        if ctx.now < state.core.startedAt { return .idle(title: "🎤 Ohren auf!", subtitle: "Wer singt das?") }
        return state.core.prompt(for: player, ctx: ctx, revealed: false)
    }
    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) { state.core.gmInfo(ctx: ctx) }
}

/// Stummfilm-Studio — a 3 s muted video vignette, guess the song.
public enum MusikvideoRaten: MinigamePlugin {
    public typealias State = SongRueckwaerts.State

    public static let meta = MinigameMeta(
        id: "musikvideo-raten", name: "Stummfilm-Studio", emoji: "🎬",
        kurz: "Drei Sekunden Video ohne Ton — welcher Song gehört dazu?",
        erklaerung: "Der Ton ist weg! Drei Sekunden Musikvideo-Vignette ohne Sound, danach vier Titel zur Auswahl. Wer die Bilder lesen kann, gewinnt den Songwert plus Speed-Bonus.",
        regeln: ["3 Sekunden Musikvideo — ohne Ton",
                 "Dann 4 Titel zur Auswahl",
                 "Wer die Bilder lesen kann, gewinnt"],
        gewinn: "Richtig: Songwert + Speed-Bonus",
        contentKind: .songs(video: true), jokerAktionen: ["fiftyFifty", "removeOne"], musik: "music_round_dj", v2: true, minVideoSongs: 3
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        let target = songs.first { $0.hatVideo } ?? songs.first ?? Song(id: "s_none", titel: "Bananen-Boogie", artist: "Die Affen", jahr: nil, region: .global, schw: .medium, tags: [], hatVideo: false, videoHint: nil, komponist: nil)
        let (opts, correct) = SongHelpers.options(target: target, pool: songs + ctx.catalog.songs, artist: false, rng: &ctx.rng)
        let q = SongHelpers.asQuestion(target, options: opts, correct: correct, text: "Welcher Song passt zu diesem stummen Clip?")
        var core = ChoiceCore(question: q, ctx: ctx, timerMs: ctx.answerWindow(20_000))
        core.startedAt = ctx.now + 4000
        core.deadline = core.startedAt + core.timerMs
        return State(core: core, song: target, playAt: ctx.now)
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) { SongRueckwaerts.reduce(&state, action: action, from: player, ctx: &ctx) }
    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) { state.core.applyGm(action, ctx: &ctx) }
    public static func tick(_ state: inout State, ctx: inout MinigameContext) {}
    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { SongRueckwaerts.isFinished(state, ctx: ctx) }
    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] { state.core.standardScores(ctx: ctx, speed: true) }
    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] { state.core.standardOutcomes(ctx: ctx, speed: true) }
    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        MinigameStageOutput(wall: state.core.wall(ctx: ctx, revealed: revealed), extra: SongHelpers.songExtra(state.song, snippet: "video3s", playAt: state.playAt, revealed: revealed, video: true), title: meta.name)
    }
    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed { return state.core.prompt(for: player, ctx: ctx, revealed: true, delta: scores(state, ctx: ctx)[player]) }
        if ctx.now < state.core.startedAt { return .idle(title: "🎬 Augen auf den Bildschirm!", subtitle: "Stummfilm läuft …") }
        return state.core.prompt(for: player, ctx: ctx, revealed: false)
    }
    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) { state.core.gmInfo(ctx: ctx) }
}

/// Blitz-DJ (Song-Snippet) — escalating buzzer: the snippet gets longer
/// (100 → 1000 ms) while the payout ladder decays. Wrong buzz = penalty into
/// the jar and locked out for this song. 3 songs per round.
public enum SongSnippet: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var songs: [Song]
        public var index: Int
        public var core: ChoiceCore?
        public var song: Song?
        public var stufe: Int
        public var stufeStartedAt: Millis
        public var buzzer: PlayerId?
        public var buzzedAt: Millis?
        public var lockedOut: [PlayerId]
        public var earned: [PlayerId: Int]
        public var revealUntil: Millis?
        public var finished: Bool
        public var lastCorrect: Bool?
        public var phase: String // hoeren | antworten | reveal
    }

    public static let stufen = [100, 200, 300, 500, 1000]
    static func treppe(_ d: Difficulty) -> [Int] {
        switch d {
        case .easy: return [300, 250, 200, 150, 100, 50]
        case .medium: return [600, 500, 400, 300, 200, 100]
        case .hard: return [1000, 800, 600, 400, 250, 100]
        case .ultrahard: return [1500, 1200, 900, 600, 400, 150]
        }
    }
    static let stufeMs = 4000
    static let answerMs = 8000
    static let penaltyShare = 0.25

    public static let meta = MinigameMeta(
        id: "song-snippet", name: "Blitz-DJ", emoji: "🎧",
        kurz: "Buzz-Treppe: je kürzer das Schnipsel, desto mehr Geld — Fehlbuzz kostet.",
        erklaerung: "Der Blitz-DJ spielt winzige Song-Schnipsel: erst 0,1 Sekunden, dann 0,2, 0,3, 0,5 und 1 Sekunde. Mit jeder Stufe sinkt der Gewinn. Wer buzzert, muss den Titel aus vier Optionen treffen: richtig = die aktuelle Stufe, falsch = 25 % Strafe ins Jackpot-Glas und Sperre für diesen Song. Drei Songs pro Runde.",
        regeln: ["Winzige Song-Schnipsel: 0,1 s → 0,2 → 0,3 → 0,5 → 1 s",
                 "Mit jeder Stufe sinkt der Gewinn",
                 "Buzzern, dann den Titel aus 4 Optionen treffen",
                 "Falsch: 25 % Strafe ins Glas und Sperre für diesen Song"],
        gewinn: "Richtig: aktuelle Stufe · Fehlbuzz: −25 % ins Glas",
        contentKind: .songs(video: false), roundBased: true, streak: false, strafenInsGlas: true, jokerAktionen: [], isMc: true, musik: "music_round_dj", v2: true
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        var s = State(songs: songs, index: 0, core: nil, song: nil, stufe: 0, stufeStartedAt: ctx.now, buzzer: nil, buzzedAt: nil, lockedOut: [], earned: [:], revealUntil: nil, finished: false, lastCorrect: nil, phase: "hoeren")
        nextSong(&s, ctx: &ctx)
        return s
    }

    static func nextSong(_ s: inout State, ctx: inout MinigameContext) {
        guard s.index < min(3, s.songs.count) else { s.finished = true; return }
        let target = s.songs[s.index]
        s.index += 1
        let (opts, correct) = SongHelpers.options(target: target, pool: s.songs + ctx.catalog.songs, artist: false, rng: &ctx.rng)
        var qctx = ctx
        qctx.mods = QuestionMods()
        s.core = ChoiceCore(question: SongHelpers.asQuestion(target, options: opts, correct: correct, text: "Welcher Song ist das?"), ctx: qctx, timerMs: ctx.ms(stufeMs * stufen.count))
        s.song = target
        s.stufe = 0
        s.stufeStartedAt = ctx.now
        s.buzzer = nil
        s.buzzedAt = nil
        s.lockedOut = []
        s.revealUntil = nil
        s.lastCorrect = nil
        s.phase = "hoeren"
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        switch (state.phase, action) {
        case ("hoeren", .buzz):
            guard state.buzzer == nil, !state.lockedOut.contains(player) else { return }
            state.buzzer = player
            state.buzzedAt = ctx.now
            state.phase = "antworten"
            state.core?.deadline = ctx.now + ctx.ms(answerMs)
        case ("antworten", .choose(let i)):
            guard player == state.buzzer, var c = state.core else { return }
            if c.answer(player, index: i, now: ctx.now) {
                state.core = c
                let ok = c.isCorrect(player) == true
                state.lastCorrect = ok
                let ladder = treppe(c.question.schw)
                if ok {
                    state.earned[player, default: 0] += ladder[min(state.stufe, ladder.count - 1)]
                    state.phase = "reveal"
                    state.revealUntil = ctx.now + ctx.ms(4000)
                } else {
                    state.earned[player, default: 0] -= Economy.roundTo10(Int(Double(ladder[min(state.stufe, ladder.count - 1)]) * penaltyShare))
                    state.lockedOut.append(player)
                    state.buzzer = nil
                    state.core?.answers[player] = nil
                    state.phase = "hoeren"
                    state.stufeStartedAt = ctx.now
                }
            }
        default: break
        }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        if case .forceFinish = action { state.finished = true }
        if case .timerShift(let ms) = action { state.stufeStartedAt += ms; state.core?.shift(ms: ms); if let r = state.revealUntil { state.revealUntil = r + ms } }
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {
        guard !state.finished else { return }
        switch state.phase {
        case "hoeren":
            let everyoneOut = ctx.players.filter { ctx.connected.contains($0) }.allSatisfy { state.lockedOut.contains($0) }
            if ctx.now >= state.stufeStartedAt + ctx.ms(stufeMs) {
                if state.stufe + 1 >= stufen.count || everyoneOut {
                    state.phase = "reveal"
                    state.lastCorrect = nil
                    state.revealUntil = ctx.now + ctx.ms(4000)
                } else {
                    state.stufe += 1
                    state.stufeStartedAt = ctx.now
                }
            }
        case "antworten":
            if let c = state.core, ctx.now > c.deadline + ChoiceCore.graceMs, let b = state.buzzer {
                state.lockedOut.append(b)
                state.buzzer = nil
                state.phase = "hoeren"
                state.stufeStartedAt = ctx.now
            }
        case "reveal":
            if let r = state.revealUntil, ctx.now >= r { nextSong(&state, ctx: &ctx) }
        default: break
        }
    }

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.finished }
    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] { Dictionary(uniqueKeysWithValues: ctx.players.map { ($0, state.earned[$0] ?? 0) }) }
    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        Dictionary(uniqueKeysWithValues: ctx.players.map { ($0, Outcome(correct: (state.earned[$0] ?? 0) > 0 ? true : ((state.earned[$0] ?? 0) < 0 ? false : nil), countsForStreak: false)) })
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        guard let c = state.core, let song = state.song else { return MinigameStageOutput(wall: nil, title: meta.name) }
        var qctx = ctx
        qctx.fragenNummer = state.index
        qctx.fragenGesamt = min(3, state.songs.count)
        var wall = c.wall(ctx: qctx, revealed: revealed || state.phase == "reveal")
        wall.wert = treppe(c.question.schw)[min(state.stufe, 5)]
        if state.phase == "hoeren" { wall.options = nil }
        let snippet = "buzz_ms\(stufen[min(state.stufe, stufen.count - 1)])"
        let extra: StageExtra = revealed ? .none : .buzzers(armed: state.phase == "hoeren", order: state.buzzer.map { [$0] } ?? [], lockedOut: state.lockedOut, stufe: "\(stufen[min(state.stufe, stufen.count - 1)]) ms", wert: wall.wert)
        let songExtra = SongHelpers.songExtra(song, snippet: snippet, playAt: state.phase == "hoeren" ? state.stufeStartedAt : nil, revealed: revealed || state.phase == "reveal")
        return MinigameStageOutput(wall: revealed ? nil : wall, extra: state.phase == "reveal" || revealed ? songExtra : extra, title: "\(meta.name) · Song \(state.index)/\(min(3, state.songs.count))")
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed { let s = state.earned[player] ?? 0; return .reveal(title: s > 0 ? "DJ-Ohr!" : (s < 0 ? "Fehlbuzz" : "Kein Buzz"), correct: s > 0 ? true : (s < 0 ? false : nil), delta: s, detail: nil, streak: 0, speedBonus: nil) }
        guard let c = state.core else { return .idle(title: meta.name, subtitle: nil) }
        switch state.phase {
        case "hoeren":
            if state.lockedOut.contains(player) { return .buzzer(question: nil, armed: false, pressed: false, lockedUntil: nil, hint: "Gesperrt für diesen Song") }
            return .buzzer(question: "Stufe \(state.stufe + 1)/5 · \(Money.format(treppe(c.question.schw)[min(state.stufe, 5)]))", armed: true, pressed: false, lockedUntil: nil, hint: nil)
        case "antworten":
            if player == state.buzzer { return c.prompt(for: player, ctx: ctx, revealed: false, hint: "🎧 Du hast gebuzzert — welcher Song?") }
            return .idle(title: "🎧 \(ctx.name(state.buzzer ?? "")) hat gebuzzert", subtitle: "Falsch = du bist dran!")
        default:
            return .reveal(title: state.lastCorrect == true ? (state.buzzer == player ? "RICHTIG!" : "\(ctx.name(state.buzzer ?? "")) hat's erkannt") : "Niemand wusste es", correct: state.buzzer == player ? state.lastCorrect : nil, delta: 0, detail: c.question.erkl, streak: 0, speedBonus: nil)
        }
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) { state.core?.gmInfo(ctx: ctx) ?? (nil, [:]) }
    public static func questionsUsed(_ state: State) -> Int { max(1, state.index) }
}

/// 7-Buchstaben-Telegramm — cooperative pairs: letters of a word are revealed
/// one by one; the first pair that types the word earns +250 each.
public enum BuchstabenTelegramm: MinigamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var words: [String]
        public var index: Int
        public var word: String
        public var revealed: Int
        public var startedAt: Millis
        public var pairs: [[PlayerId]]
        public var solvedBy: [Int]
        public var earned: [PlayerId: Int]
        public var attempts: [PlayerId: String]
        public var revealUntil: Millis?
        public var finished: Bool
        public var solvedWords: [Int]
    }

    static let letterMs = 2500
    static let pool = ["BANANEN", "AFFENZOO", "DSCHUNGEL", "JACKPOT", "KOKOSNUSS", "LIANE", "GORILLA", "TROMMEL", "SCHATZ", "PALME", "KAPUZINER", "URWALD", "TRESOR", "SPIELSHOW", "QUIZMASTER", "GOLDMUENZE", "BUZZER", "PAVIAN", "ORANGUTAN", "MANGO"]

    public static let meta = MinigameMeta(
        id: "buchstaben-telegramm", name: "7-Buchstaben-Telegramm", emoji: "📨",
        kurz: "Koop-Paare: Buchstabe für Buchstabe erscheint ein Wort — wer es zuerst tippt, kassiert.",
        erklaerung: "Koop-Geld! Ihr spielt in Zweier-Paaren. Auf dem Bildschirm erscheint alle zweieinhalb Sekunden ein weiterer Buchstabe eines Wortes. Sobald ein Partner das richtige Wort tippt, kassiert das Paar je 250 MM. Vier Wörter pro Runde — je früher, desto stolzer.",
        regeln: ["Ihr spielt in Zweier-Paaren",
                 "Alle 2,5 s erscheint ein weiterer Buchstabe eines Wortes",
                 "Tippt ein Partner das Wort zuerst, kassiert das Paar",
                 "Vier Wörter pro Runde"],
        gewinn: "Pro gelöstem Wort je 250 MM fürs Paar",
        contentKind: .none, roundBased: true, streak: false, jokerAktionen: [], isMc: false, musik: "market_trade", v2: true
    )

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        var words = songs.map { $0.titel.uppercased().replacingOccurrences(of: " ", with: "") }.filter { $0.count >= 5 && $0.count <= 12 && $0.allSatisfy { $0.isLetter } }
        words += pool
        words = ctx.rng.shuffled(Array(Set(words)))
        let shuffled = ctx.rng.shuffled(ctx.players)
        var pairs: [[PlayerId]] = []
        var i = 0
        while i < shuffled.count { pairs.append(Array(shuffled[i..<min(shuffled.count, i + 2)])); i += 2 }
        if pairs.count > 1, pairs.last?.count == 1 { let solo = pairs.removeLast()[0]; pairs[pairs.count - 1].append(solo) }
        return State(words: Array(words.prefix(4)), index: 0, word: words.first ?? "BANANEN", revealed: 1, startedAt: ctx.now, pairs: pairs, solvedBy: [], earned: [:], attempts: [:], revealUntil: nil, finished: false, solvedWords: [])
    }

    static func pairIndex(_ s: State, _ p: PlayerId) -> Int? { s.pairs.firstIndex { $0.contains(p) } }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        guard state.revealUntil == nil, case .text(let t) = action, let pi = pairIndex(state, player), !state.solvedBy.contains(pi) else { return }
        let guess = t.uppercased().replacingOccurrences(of: " ", with: "")
        state.attempts[player] = guess
        if guess == state.word {
            state.solvedBy.append(pi)
            for p in state.pairs[pi] { state.earned[p, default: 0] += 250 }
            if state.solvedBy.count == 1 { state.solvedWords.append(state.index) }
            state.revealUntil = ctx.now + ctx.ms(3000)
        }
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        if case .forceFinish = action { state.finished = true }
        if case .timerShift(let ms) = action { state.startedAt += ms; if let r = state.revealUntil { state.revealUntil = r + ms } }
    }

    static func nextWord(_ s: inout State, ctx: inout MinigameContext) {
        s.index += 1
        guard s.index < s.words.count else { s.finished = true; return }
        s.word = s.words[s.index]
        s.revealed = 1
        s.startedAt = ctx.now
        s.solvedBy = []
        s.attempts = [:]
        s.revealUntil = nil
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {
        guard !state.finished else { return }
        if let r = state.revealUntil { if ctx.now >= r { nextWord(&state, ctx: &ctx) }; return }
        let shouldReveal = 1 + (ctx.now - state.startedAt) / ctx.ms(letterMs)
        state.revealed = min(state.word.count, shouldReveal)
        if state.revealed >= state.word.count, ctx.now >= state.startedAt + ctx.ms(letterMs) * (state.word.count + 2) {
            state.revealUntil = ctx.now + ctx.ms(3000)
        }
    }

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.finished }
    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] { Dictionary(uniqueKeysWithValues: ctx.players.map { ($0, state.earned[$0] ?? 0) }) }
    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        Dictionary(uniqueKeysWithValues: ctx.players.map { ($0, Outcome(correct: (state.earned[$0] ?? 0) > 0, countsForStreak: false)) })
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        let letters = state.word.enumerated().map { $0.offset < state.revealed || state.revealUntil != nil || revealed ? String($0.element) : "_" }
        return MinigameStageOutput(wall: nil, extra: .telegram(pairs: state.pairs, letters: letters, solved: state.solvedBy, wort: state.revealUntil != nil || revealed ? state.word : nil),
                                   title: "\(meta.name) · Wort \(min(state.index + 1, state.words.count))/\(state.words.count)")
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        if revealed { let s = state.earned[player] ?? 0; return .reveal(title: s > 0 ? "Telegramm angekommen!" : "Leitung tot", correct: s > 0, delta: s, detail: nil, streak: 0, speedBonus: nil) }
        let pi = pairIndex(state, player)
        let partner = pi.flatMap { state.pairs[$0].first { $0 != player } }
        if let pi = pi, state.solvedBy.contains(pi) { return .idle(title: "✅ Gelöst: \(state.word)", subtitle: "+250 MM für euch beide") }
        if state.revealUntil != nil { return .idle(title: "Das Wort war: \(state.word)", subtitle: "Nächstes Telegramm kommt …") }
        let letters = state.word.enumerated().map { $0.offset < state.revealed ? String($0.element) : "_" }.joined(separator: " ")
        return .text(question: letters, placeholder: "Wort tippen …", maxLength: 16, submitted: nil, deadline: nil).withHint(partner.map { "📨 Partner: \(ctx.name($0))" })
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        (GmQuestionInfo(id: "wort_\(state.index)", text: "Telegramm-Wort", kategorie: "Musik", schwierigkeit: .medium, korrekt: state.word, erklaerung: "", tipps: [], typ: .choice), state.attempts)
    }
    public static func questionsUsed(_ state: State) -> Int { max(1, state.index + 1) }
}

extension PlayerPrompt {
    /// Attach a hint to a text prompt by folding it into the question line.
    func withHint(_ hint: String?) -> PlayerPrompt {
        guard let h = hint, case .text(let q, let ph, let max, let sub, let dl) = self else { return self }
        return .text(question: q + "\n" + h, placeholder: ph, maxLength: max, submitted: sub, deadline: dl)
    }
}
