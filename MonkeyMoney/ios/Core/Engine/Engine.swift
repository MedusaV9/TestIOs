import Foundation

/// Commands of the Show-Master cockpit (human GM, stage-in-gmLos-mode and
/// the Auto-GM all fire the same commands — one logic, one log).
public enum GmCommand: Codable, Equatable, Sendable {
    case flowNext
    case flowSkipOpening
    case settingsSet([String: JSONValue])
    case scoreAdjust(playerId: PlayerId, delta: Int, grund: String)
    case timerExtend(ms: Int)
    case pause(text: String?, dauerMs: Int?)
    case resume
    case kategoriePick(String)
    case hintGlobal
    case whisper(playerId: PlayerId, text: String)
    case voteStart(frage: String, optionen: [String], dauerMs: Int?, bindend: Bool)
    case questionMarkBroken(grund: String, refund: String)
    case gameSkip(keepPoints: Bool)
    case punish(playerId: PlayerId, strafe: String)
    case boost(playerId: PlayerId, art: String, grund: String)
    case jokerGrant(ziel: String, jokerId: String)
    case wheelSpin(rigTarget: String?)
    case moodPoll
    case feedbackCollect
    case encore
    case soundPlay(String)
    case autoGmSet(Bool)
    case revanche
    case ende
    case kick(PlayerId)
    case lookSet(playerId: PlayerId, avatar: Avatar)
    case teamsShuffle
    case boardgameStart(id: String, optionen: [String: JSONValue])
    case boardgameAbort
    case boardgameLocal(sitz: String, action: PlayerAction)
    case botAdd(name: String, persona: String)
    case botRemove(PlayerId)
}

public enum EngineAction: Equatable, Sendable {
    case join(playerId: PlayerId, name: String, avatar: Avatar, profileId: String?, isBot: Bool)
    case leave(PlayerId)
    case connect(PlayerId)
    case disconnect(PlayerId)
    case player(PlayerId, PlayerAction)
    case gm(GmCommand)
    case screenPresence(Bool)
    case gmPresence(Bool)
}

/// Pure state machine. All entry points take `now` explicitly; nothing inside
/// reads the wall clock or system randomness.
public struct Engine: Sendable {
    public let catalog: ContentCatalog

    public init(catalog: ContentCatalog) {
        self.catalog = catalog
    }

    public static let maxPlayers = 8
    public static let maxPlayersSpieleabend = 12
    public static let minPlayers = 2
    public static let graceMs = 180_000

    // MARK: Phase durations (base ms, scaled by tempo)

    enum Dur {
        static let intro = 12_000
        static let kategorie = 15_000
        static let erklaer = 12_000
        static let aufloesung = 6000
        static let aufloesungErklaerung = 10_000
        static let aufloesungRunde = 8000
        static let zwischenstand = 8000
        static let radDreh = 5000
        static let radDrehKurz = 3000
        static let radErklaert = 5000
        static let highlights = 10_000
        static let siegerehrung = 30_000
        static let halbzeit = 120_000
    }

    // MARK: Reduce

    public func reduce(_ s: inout EngineState, _ action: EngineAction, now: Millis) {
        s.seq += 1
        switch action {
        case .join(let id, let name, let avatar, let profileId, let isBot):
            join(&s, id: id, name: name, avatar: avatar, profileId: profileId, isBot: isBot, now: now)
        case .leave(let id):
            leave(&s, id, now: now)
        case .connect(let id):
            if let i = s.index(of: id) {
                s.players[i].connected = true
                s.players[i].disconnectedAt = nil
                if var box = s.minigame, let plugin = MinigameRegistry.plugin(box.id) {
                    var ctx = context(s, now: now)
                    plugin.onReconnect(&box.data, id, &ctx)
                    s.rng = ctx.rng
                    s.minigame = box
                }
                s.addLog("presence", "\(s.players[i].name) ist wieder da", at: now)
            }
        case .disconnect(let id):
            if let i = s.index(of: id) {
                s.players[i].connected = false
                s.players[i].disconnectedAt = now
                if var box = s.minigame, let plugin = MinigameRegistry.plugin(box.id) {
                    var ctx = context(s, now: now)
                    plugin.onDisconnect(&box.data, id, &ctx)
                    s.rng = ctx.rng
                    s.minigame = box
                }
                s.addLog("presence", "\(s.players[i].name) hat die Verbindung verloren", at: now)
            }
        case .player(let id, let pa):
            playerAction(&s, id, pa, now: now)
        case .gm(let cmd):
            gmCommand(&s, cmd, now: now)
        case .screenPresence(let on):
            s.screenOnline = on
        case .gmPresence(let on):
            s.gmOnline = on
        }
    }

    // MARK: Join / leave

    func join(_ s: inout EngineState, id: PlayerId, name: String, avatar: Avatar, profileId: String?, isBot: Bool, now: Millis) {
        if let i = s.index(of: id) {
            s.players[i].connected = true
            s.players[i].name = name
            s.players[i].avatar = avatar
            return
        }
        let cap = s.settings.spielModus == .spieleabend ? Engine.maxPlayersSpieleabend : Engine.maxPlayers
        guard s.players.count < cap else { return }
        var p = Player(id: id, name: String(name.prefix(16)), avatar: avatar, joinOrder: (s.players.map { $0.joinOrder }.max() ?? 0) + 1, profileId: profileId, isBot: isBot)
        if s.phase != .lobby {
            // Late joiner: median balance, marked with the round.
            let balances = s.players.map { $0.balance }.sorted()
            p.balance = balances.isEmpty ? 0 : balances[balances.count / 2]
            p.beigetretenRunde = s.currentSection?.rundenNummer ?? 0
        }
        s.players.append(p)
        s.addLog("join", "\(p.name) ist beigetreten", at: now)
        s.addMoment("join", "\(p.name) ist da!", player: id, at: now)
        if !s.settings.alltimeItems || s.players.contains(where: { $0.profileId == nil && !$0.isBot }) {
            // Guest without history in the lobby: All-Time items auto-off (§7.4).
            s.settings.alltimeItems = false
        }
    }

    func leave(_ s: inout EngineState, _ id: PlayerId, now: Millis) {
        guard let i = s.index(of: id) else { return }
        let name = s.players[i].name
        if s.phase == .lobby || s.phase == .ende {
            s.players.remove(at: i)
        } else {
            // Active leave mid-match: balance becomes "Insolvenzmasse" in the jar.
            s.jackpotGlas += max(0, s.players[i].balance)
            s.players.remove(at: i)
        }
        s.addLog("leave", "\(name) hat den Raum verlassen", at: now)
    }

    // MARK: Context

    func context(_ s: EngineState, now: Millis) -> MinigameContext {
        var names: [PlayerId: String] = [:]
        var balances: [PlayerId: Int] = [:]
        var connected: Set<PlayerId> = []
        var schutz: Set<PlayerId> = []
        let round = s.currentSection?.rundenNummer ?? 0
        for p in s.players {
            names[p.id] = p.name
            balances[p.id] = p.balance
            if p.connected { connected.insert(p.id) }
            if let r = p.klauSchutzBisRunde, r >= round { schutz.insert(p.id) }
        }
        let section = s.currentSection ?? Section(typ: .runde, slot: .opener, minigameId: MinigameRegistry.fallbackId, fragen: 1, schwierigkeiten: [.easy], kategorieWahl: .keine, radDanach: false, rundenNummer: 1, kategorie: nil, notariat: false)
        return MinigameContext(now: now, rng: s.rng, settings: s.settings, players: s.players.map { $0.id }, names: names, balances: balances,
                               connected: connected, klauSchutz: schutz, mods: s.nextMods, section: section, catalog: catalog, teams: s.teams,
                               fragenNummer: s.questionIndex + 1, fragenGesamt: section.fragen, isFinale: section.typ == .finale, wFinal: s.wFinal ?? 500)
    }

    // MARK: Tick

    public func tick(_ s: inout EngineState, now: Millis) {
        guard !s.paused else {
            if let end = s.pauseEndsAt, now >= end { resume(&s, now: now) }
            return
        }
        switch s.phase {
        case .lobby:
            break
        case .intro:
            if let end = s.phaseEndsAt, now >= end { startNextSection(&s, now: now) }
        case .kategorieWahl:
            tickKategorie(&s, now: now)
        case .erklaerkarte:
            if let end = s.phaseEndsAt, now >= end { startQuestion(&s, now: now) }
        case .frage:
            tickFrage(&s, now: now)
        case .aufloesung:
            if let end = s.phaseEndsAt, now >= end { afterAufloesung(&s, now: now) }
        case .zwischenstand:
            if let end = s.phaseEndsAt, now >= end { afterZwischenstand(&s, now: now) }
        case .rad:
            tickRad(&s, now: now)
        case .halbzeit:
            if let end = s.phaseEndsAt, now >= end { s.halbzeitGemacht = true; startNextSection(&s, now: now) }
        case .highlights:
            if let end = s.phaseEndsAt, now >= end { enterSiegerehrung(&s, now: now) }
        case .siegerehrung:
            if let end = s.phaseEndsAt, now >= end { enterEnde(&s, now: now) }
        case .ende:
            break
        case .pause:
            break
        case .brettspiel:
            tickBoardgame(&s, now: now)
        }
        // Grace period: players disconnected longer than 180 s are frozen (kept, no removal).
        if let vote = s.gmVote, vote.ergebnis == nil, now >= vote.endetAt {
            var counts = Array(repeating: 0, count: vote.optionen.count)
            for v in vote.stimmen.values where v < counts.count { counts[v] += 1 }
            let best = counts.enumerated().max { $0.element < $1.element }?.offset ?? 0
            s.gmVote?.ergebnis = best
            s.addMoment("vote", "Abstimmung: „\(vote.optionen[best])“ (\(counts[best]) Stimmen)", at: now)
        }
    }

    // MARK: Match start & plan

    public func canStart(_ s: EngineState) -> Bool {
        s.phase == .lobby && s.players.count >= Engine.minPlayers && s.settings.spielModus == .quiz
    }

    func startMatch(_ s: inout EngineState, now: Millis) {
        guard canStart(s) else { return }
        s.plan = Plan.build(settings: s.settings, playerCount: s.players.count, songs: catalog.songs)
        s.sectionIndex = -1
        s.questionIndex = 0
        s.jackpotGlas = Economy.jackpotJarStart
        s.usedQuestionIds = []
        s.abend.beginnAt = s.abend.beginnAt ?? now
        for i in s.players.indices {
            s.players[i].balance = 0
            s.players[i].streak = 0
            s.players[i].jokers = Dictionary(uniqueKeysWithValues: Jokers.startInventory().map { ($0.key.rawValue, $0.value) })
            s.players[i].jokerKaeufe = [:]
            s.players[i].stats = PlayerMatchStats()
            s.players[i].matsch = false
            s.players[i].clown = false
        }
        Teams.assign(&s)
        s.songPool = catalog.songs.map { $0.id }
        s.usedSongIds = []
        s.addLog("match", "Match gestartet (\(s.settings.modus.title), \(s.players.count) Spieler)", at: now)
        enter(&s, .intro, duration: Dur.intro, now: now)
    }

    func enter(_ s: inout EngineState, _ phase: Phase, duration: Int?, now: Millis) {
        s.phase = phase
        s.phaseStartedAt = now
        s.phaseEndsAt = duration.map { now + s.settings.ms($0) }
        s.bereit = []
        s.streik = []
        s.timerExtensions = 0
    }

    /// Advance to the next section of the plan (or the ceremony).
    func startNextSection(_ s: inout EngineState, now: Millis) {
        s.sectionIndex += 1
        s.questionIndex = 0
        s.encoresThisRound = 0
        s.boostsThisRound = []
        s.roundMods = RoundMods()
        s.kategorie = CategoryVoteState()
        s.tippStufe = 0
        s.whispers = [:]
        guard let section = s.currentSection else {
            enterHighlights(&s, now: now)
            return
        }
        // Halbzeit (marathon): after the configured round, once.
        if let hz = Blueprints.blueprint(for: s.settings.modus).halbzeitNach, section.typ == .runde, section.rundenNummer == hz + 1, !s.halbzeitGemacht {
            s.halbzeitGemacht = true
            s.sectionIndex -= 1
            enter(&s, .halbzeit, duration: Dur.halbzeit, now: now)
            s.addMoment("halbzeit", "🍕 Halbzeit! Zwischenstand als Kurschart — weiter mit ▶", at: now)
            return
        }
        if section.typ == .finale, section.minigameId != "kokosnuss-shake" { prepareFinale(&s, now: now) }
        if section.typ == .jackpot { s.addMoment("jackpot", "💰 DIE JACKPOT-FRAGE! Doppelter Fragenwert + das Glas (\(Money.format(s.jackpotGlas)))", at: now) }
        if section.notariat { s.roundMods.notariat = true }
        let wantsVote = section.typ == .runde && section.kategorieWahl != .keine && s.settings.kategorienWahl != "aus"
        if wantsVote {
            enterKategorieWahl(&s, section: section, now: now)
        } else {
            enterErklaerkarte(&s, now: now)
        }
    }

    func enterKategorieWahl(_ s: inout EngineState, section: Section, now: Millis) {
        let supply = catalog.categoriesWithSupply(schwierigkeiten: section.schwierigkeiten, used: Set(s.usedQuestionIds), minimum: section.fragen, pool: s.settings.kategorienPool)
        var options = s.rng.shuffled(supply.isEmpty ? catalog.categories.map { $0.id } : supply)
        options = Array(options.prefix(4))
        s.kategorie = CategoryVoteState()
        s.kategorie.optionen = options
        s.kategorie.letzterWaehlt = section.kategorieWahl == .letzter ? s.last?.id : nil
        if s.settings.kategorienWahl == "gm" && s.gmOnline { s.kategorie.letzterWaehlt = nil }
        enter(&s, .kategorieWahl, duration: Dur.kategorie, now: now)
        s.kategorie.endetAt = s.phaseEndsAt
        if let l = s.kategorie.letzterWaehlt, let p = s.player(l) {
            s.addMoment("kategorie", "🎯 Comeback-Regel: \(p.name) wählt die Kategorie!", player: l, at: now)
        }
    }

    func tickKategorie(_ s: inout EngineState, now: Millis) {
        let voters = s.kategorie.letzterWaehlt.map { [$0] } ?? s.connectedPlayers.map { $0.id }
        let allVoted = !voters.isEmpty && voters.allSatisfy { s.kategorie.stimmen[$0] != nil }
        var close = allVoted || (s.phaseEndsAt.map { now >= $0 } ?? false)
        // Stall countdown: 8 s without a new vote ⇒ 3-s countdown.
        if !close, !s.kategorie.stimmen.isEmpty {
            if let c = s.kategorie.countdownAb, now >= c + 3000 { close = true }
        }
        if close { closeKategorie(&s, now: now) }
    }

    func closeKategorie(_ s: inout EngineState, now: Millis) {
        var counts: [String: Int] = [:]
        for v in s.kategorie.stimmen.values { counts[v, default: 0] += 1 }
        let winner: String
        if let best = counts.max(by: { a, b in a.value != b.value ? a.value < b.value : (s.rng.next() < 0.5) }) {
            winner = best.key
        } else {
            winner = s.rng.pick(s.kategorie.optionen) ?? catalog.categories.first?.id ?? "kurioses_mixed"
        }
        s.kategorie.gewinner = winner
        s.plan[s.sectionIndex].kategorie = winner
        s.addMoment("kategorie", "📚 Kategorie: \(catalog.categoryName(winner))", at: now)
        enterErklaerkarte(&s, now: now)
    }

    func enterErklaerkarte(_ s: inout EngineState, now: Millis) {
        guard let section = s.currentSection else { return }
        prepareSectionQuestions(&s, section: section)
        var dur = Dur.erklaer
        if section.typ == .jackpot || section.typ == .finale { dur = 8000 }
        if s.settings.kurzeShow { dur = min(dur, 6000) }
        enter(&s, .erklaerkarte, duration: dur, now: now)
    }

    /// Draw the questions of a section lazily (category may just have been voted).
    func prepareSectionQuestions(_ s: inout EngineState, section: Section) {
        let plugin = MinigameRegistry.plugin(section.minigameId) ?? MinigameRegistry.plugin(MinigameRegistry.fallbackId)!
        var count = section.fragen
        if plugin.meta.id == "affenbank" || plugin.meta.id == "stinkbanane" { count = max(count, 20) }
        var types: [QuestionType] = []
        if case .fragen(let t) = plugin.meta.contentKind { types = t }
        var used = Set(s.usedQuestionIds)
        var opts = PickOptions(anzahl: count, used: used, kategorien: section.kategorie.map { [$0] } ?? s.settings.kategorienPool,
                               schwierigkeiten: section.schwierigkeiten, typen: types, deAnteil: s.settings.deAnteil,
                               kidSafeOnly: s.settings.familienModus || s.players.contains { $0.kind }, allowAdult: s.settings.alkoholEdition,
                               mix: section.typ == .runde ? s.settings.fragenMix : .ausgewogen)
        var picked: [Question] = []
        if types.first == .bildPixel {
            // Picture riddles are the point of the Pixel-Dschungel: take them from any
            // category first (only a dozen exist), any difficulty, then fill up normally.
            var pix = opts
            pix.kategorien = []
            pix.typen = [.bildPixel]
            picked = catalog.pick(pix, rng: &s.rng)
            if picked.count < count {
                pix.schwierigkeiten = []
                pix.used = used.union(picked.map { $0.id })
                pix.anzahl = count - picked.count
                picked += catalog.pick(pix, rng: &s.rng)
            }
            opts.used = used.union(picked.map { $0.id })
            opts.anzahl = count - picked.count
        }
        if picked.count < count { picked += catalog.pick(opts, rng: &s.rng) }
        if picked.count < count {
            // Category exhausted: widen (any category), then any difficulty.
            opts.kategorien = []
            opts.used = used.union(picked.map { $0.id })
            opts.anzahl = count - picked.count
            picked += catalog.pick(opts, rng: &s.rng)
            if !picked.isEmpty && section.kategorie != nil {
                s.addMoment("kategorie", "📚 Kategorie erschöpft — weiter mit Mix!", at: s.phaseStartedAt)
            }
        }
        if picked.count < count {
            opts.schwierigkeiten = []
            opts.used = used.union(picked.map { $0.id })
            opts.anzahl = count - picked.count
            picked += catalog.pick(opts, rng: &s.rng)
        }
        // ULTRAHARD cap per match (§1.2): replace surplus with hard.
        let cap = Blueprints.blueprint(for: s.settings.modus).ultrahardMax
        for i in picked.indices where picked[i].schw == .ultrahard && section.typ == .runde {
            if s.ultrahardCount >= cap {
                var o = opts
                o.schwierigkeiten = [.hard]
                o.anzahl = 1
                o.used = used.union(picked.map { $0.id })
                if let r = catalog.pick(o, rng: &s.rng).first { picked[i] = r }
            } else {
                s.ultrahardCount += 1
            }
        }
        for q in picked { used.insert(q.id) }
        s.usedQuestionIds = Array(used)
        s.currentQuestionIds = picked.map { $0.id }
    }

    func prepareFinale(_ s: inout EngineState, now: Millis) {
        // Schuldenerlass + Mitleids-Banane (§1.1 / §3.4).
        for i in s.players.indices where s.players[i].balance < 0 {
            s.players[i].balance = 0
            s.addMoment("finale", "⚖️ Privatinsolvenz: \(s.players[i].name) startet schuldenfrei ins Finale", player: s.players[i].id, at: now)
        }
        if let last = s.last, s.players.count >= 2, let i = s.index(of: last.id) {
            s.players[i].balance += Economy.pityBanana
            s.addMoment("finale", "🍌 Mitleids-Banane: +\(Money.format(Economy.pityBanana)) für \(last.name)", player: last.id, betrag: Economy.pityBanana, at: now)
        }
        for p in s.players { s.bilanzVorFinale[p.id] = p.balance }
        for i in s.players.indices { s.players[i].stats.platzVorFinale = s.place(of: s.players[i].id) }
        let first = s.leader?.balance ?? 0
        let lastBal = s.last?.balance ?? 0
        let q = s.currentSection?.fragen ?? 3
        s.wFinal = Economy.wFinal(gap: first - lastBal, q: q, factor: s.settings.finaleFaktor)
        s.finaleAngesagt = true
        s.addMoment("finale", "🐊 Jede Finalfrage ist heute \(Money.format(s.wFinal ?? 500)) wert!", at: now)
    }

    // MARK: Questions

    func startQuestion(_ s: inout EngineState, now: Millis) {
        guard let section = s.currentSection else { return }
        let plugin = resolvedPlugin(s, section)
        let questions = s.currentQuestionIds.compactMap { catalog.question($0) }
        var qs: [Question]
        if plugin.meta.roundBased {
            qs = questions
        } else {
            guard s.questionIndex < questions.count else { finishSection(&s, now: now); return }
            qs = [questions[s.questionIndex]]
            if qs[0].schw == .ultrahard { s.addMoment("ultrahard", "🔥 DIE 1000er!! ULTRAHARD-Frage!", at: now) }
        }
        var songs: [Song] = []
        if case .songs(let video) = plugin.meta.contentKind {
            var pool = catalog.songs.filter { !s.usedSongIds.contains($0.id) && (!video || $0.hatVideo) }
            if pool.count < 4 { pool = catalog.songs.filter { !video || $0.hatVideo }; s.usedSongIds = [] }
            pool = s.rng.shuffled(pool)
            songs = Array(pool.prefix(max(4, plugin.meta.roundBased ? 8 : 4)))
            for song in songs.prefix(plugin.meta.roundBased ? 3 : 1) { s.usedSongIds.append(song.id) }
        }
        // Question value modifiers (Notariat +25 %, GM hint −25 %/step).
        s.nextMods.wertFaktor = (s.roundMods.notariat ? 1.25 : 1.0)
        var ctx = context(s, now: now)
        let data = plugin.initBox(qs, songs, &ctx)
        s.rng = ctx.rng
        s.minigame = MinigameBox(id: plugin.meta.id, data: data, startedAt: now, roundBased: plugin.meta.roundBased)
        s.tippStufe = 0
        s.whispers = [:]
        s.timerExtensions = 0
        enter(&s, .frage, duration: nil, now: now)
        s.addLog("frage", "Frage \(s.questionIndex + 1) (\(plugin.meta.name))", at: now)
    }

    func resolvedPlugin(_ s: EngineState, _ section: Section) -> AnyMinigame {
        let videoSongs = catalog.songs.filter { $0.hatVideo }.count
        return MinigameRegistry.resolve(section.minigameId, playerCount: s.players.count, songsAvailable: catalog.songs.count, videoSongs: videoSongs, v2: s.settings.v2Formate)
    }

    func tickFrage(_ s: inout EngineState, now: Millis) {
        guard var box = s.minigame, let plugin = MinigameRegistry.plugin(box.id) else { finishSection(&s, now: now); return }
        var ctx = context(s, now: now)
        plugin.tick(&box.data, &ctx)
        // Auto-GM: extend once when < 50 % answered and < 5 s left (question formats).
        if s.settings.autoGmAktiv, !s.settings.timerAus, s.timerExtensions == 0, !plugin.meta.roundBased {
            let stage = plugin.stage(box.data, false, ctx)
            if let wall = stage.wall, let dl = wall.deadline, dl - now < 5000, dl > now {
                let connected = s.connectedPlayers.count
                if connected > 0, Double(wall.answered.count) / Double(connected) < 0.5 {
                    plugin.gm(&box.data, .timerExtend(ms: 15_000), &ctx)
                    s.timerExtensions += 1
                    s.addMoment("regie", "⏳ Auto-Regie: +15 s", at: now)
                }
            }
        }
        s.rng = ctx.rng
        s.minigame = box
        if plugin.isFinished(box.data, ctx) {
            bookQuestion(&s, plugin: plugin, box: box, now: now)
        }
    }

    /// Book the minigame result and enter the reveal.
    func bookQuestion(_ s: inout EngineState, plugin: AnyMinigame, box: MinigameBox, now: Millis) {
        let ctx = context(s, now: now)
        let scores = plugin.scores(box.data, ctx)
        let outcomes = plugin.outcomes(box.data, ctx)
        let deltas = Scoring.book(&s, catalog: catalog, plugin: plugin, scores: scores, outcomes: outcomes, now: now)
        s.lastRoundQuestionAt = now
        s.questionsSinceWheel += 1
        let hasExplanation = (plugin.stage(box.data, true, ctx).wall?.erklaerung?.isEmpty == false)
        var dur = plugin.meta.roundBased ? Dur.aufloesungRunde : (hasExplanation ? Dur.aufloesungErklaerung : Dur.aufloesung)
        if s.settings.kurzeShow { dur = min(dur, 6000) }
        enter(&s, .aufloesung, duration: dur, now: now)
        s.lastDeltas = deltas
        if let best = deltas.max(by: { $0.value < $1.value }), best.value >= 750, let p = s.player(best.key) {
            s.addMoment("money", "💸 \(p.name) kassiert \(Money.format(best.value))!", player: p.id, betrag: best.value, at: now)
        }
    }

    func afterAufloesung(_ s: inout EngineState, now: Millis) {
        guard let section = s.currentSection, let box = s.minigame else { finishSection(&s, now: now); return }
        s.nextMods = QuestionMods()
        if box.roundBased {
            finishSection(&s, now: now)
            return
        }
        s.questionIndex += 1
        let total = section.fragen + s.encoresThisRound
        if s.questionIndex < total && s.questionIndex < s.currentQuestionIds.count {
            startQuestion(&s, now: now)
        } else {
            finishSection(&s, now: now)
        }
    }

    func finishSection(_ s: inout EngineState, now: Millis) {
        guard let section = s.currentSection else { enterHighlights(&s, now: now); return }
        s.minigame = nil
        // Round-end rules: Affensteuer (SR4), Kopfgeld tracking, Kapitalismus-Gong (SR6).
        Scoring.roundEnd(&s, section: section, now: now)
        switch section.typ {
        case .runde:
            if s.currentSection?.rundenNummer == 3, s.settings.specialRules.contains(.kapitalismusGong), !s.kapitalismusGongUsed { Scoring.kapitalismusGong(&s, now: now) }
            enter(&s, .zwischenstand, duration: Dur.zwischenstand, now: now)
        case .jackpot:
            startNextSection(&s, now: now)
        case .finale:
            // Tie at the top after the finale ⇒ Kokosnuss-Shake tiebreaker (§2.11), once.
            let r = s.ranking
            if r.count >= 2, r[0].balance == r[1].balance, section.minigameId != "kokosnuss-shake" {
                s.plan.append(Section(typ: .finale, slot: .finale, minigameId: "kokosnuss-shake", fragen: 1, schwierigkeiten: [], kategorieWahl: .keine, radDanach: false, rundenNummer: section.rundenNummer, kategorie: nil, notariat: false))
                s.addMoment("shake", "🥥 GLEICHSTAND! Der Kokosnuss-Shake entscheidet", at: now)
                startNextSection(&s, now: now)
            } else {
                enterHighlights(&s, now: now)
            }
        }
    }

    func afterZwischenstand(_ s: inout EngineState, now: Millis) {
        guard let section = s.currentSection else { startNextSection(&s, now: now); return }
        if section.radDanach && s.settings.radAn && s.players.count >= 2 {
            enterRad(&s, now: now, rig: nil)
        } else {
            startNextSection(&s, now: now)
        }
    }

    // MARK: Ceremony

    func enterHighlights(_ s: inout EngineState, now: Millis) {
        s.minigame = nil
        s.highlights = Highlights.build(s)
        enter(&s, .highlights, duration: Dur.highlights, now: now)
    }

    func enterSiegerehrung(_ s: inout EngineState, now: Millis) {
        s.awards = Awards.compute(s)
        // Team pots: 50/50 split happens implicitly (individual balances kept).
        if let winner = s.leader {
            s.addMoment("sieger", "👑 \(winner.name) gewinnt mit \(Money.format(winner.balance))!", player: winner.id, betrag: winner.balance, at: now)
        }
        // Abend telemetry: AT per head from the final standing.
        let ranking = s.ranking
        for (i, p) in ranking.enumerated() {
            let at = Economy.allTimeFor(finalBalance: p.balance, isWinner: i == 0)
            s.abend.proKopf[p.id, default: 0] += at
            s.abend.atGesamt += at
        }
        s.abend.spiele += 1
        enter(&s, .siegerehrung, duration: Dur.siegerehrung, now: now)
        s.addLog("match", "Siegerehrung", at: now)
    }

    func enterEnde(_ s: inout EngineState, now: Millis) {
        enter(&s, .ende, duration: nil, now: now)
    }

    /// Revanche: same room, same players, fresh balances (3-2-1 restart).
    func revanche(_ s: inout EngineState, now: Millis) {
        guard s.phase == .ende || s.phase == .siegerehrung else { return }
        s.revancheNummer += 1
        s.matchId = "\(s.roomCode)-\(s.revancheNummer)-\(now)"
        s.plan = []
        s.sectionIndex = 0
        s.questionIndex = 0
        s.minigame = nil
        s.wFinal = nil
        s.finaleAngesagt = false
        s.awards = []
        s.highlights = []
        s.moments = []
        s.bilanzVorFinale = [:]
        s.ultrahardCount = 0
        s.rad = WheelState()
        s.nextMods = QuestionMods()
        s.roundMods = RoundMods()
        s.kopfgeld = nil
        s.fuehrungsRunden = [:]
        s.kapitalismusGongUsed = false
        s.halbzeitGemacht = false
        for i in s.players.indices {
            s.players[i].balance = 0
            s.players[i].streak = 0
            s.players[i].wrongStreak = 0
            s.players[i].matsch = false
            s.players[i].clown = false
            s.players[i].klauSchutzBisRunde = nil
            s.players[i].rueckenwindAngesagt = false
            s.players[i].stats = PlayerMatchStats()
            s.players[i].jokers = Dictionary(uniqueKeysWithValues: Jokers.startInventory().map { ($0.key.rawValue, $0.value) })
            s.players[i].jokerKaeufe = [:]
        }
        enter(&s, .lobby, duration: nil, now: now)
        s.addMoment("revanche", "🔁 REVANCHE! Gleiche Affen, neues Geld.", at: now)
    }

    // MARK: Pause

    func pause(_ s: inout EngineState, text: String?, dauerMs: Int?, now: Millis) {
        guard !s.paused, s.phase != .lobby, s.phase != .ende else { return }
        s.paused = true
        s.pausedAt = now
        s.pauseText = text ?? "🍌 Bananen-Pause"
        s.pauseEndsAt = dauerMs.map { now + $0 }
        s.addMoment("pause", s.pauseText ?? "Pause", at: now)
    }

    func resume(_ s: inout EngineState, now: Millis) {
        guard s.paused, let at = s.pausedAt else { return }
        let shift = now - at
        s.paused = false
        s.pausedAt = nil
        s.pauseEndsAt = nil
        if let e = s.phaseEndsAt { s.phaseEndsAt = e + shift }
        s.phaseStartedAt += shift
        if let e = s.kategorie.endetAt { s.kategorie.endetAt = e + shift }
        if let c = s.kategorie.countdownAb { s.kategorie.countdownAb = c + shift }
        if let st = s.rad.spinStartedAt { s.rad.spinStartedAt = st + shift }
        if let ie = s.rad.interactionEndsAt { s.rad.interactionEndsAt = ie + shift }
        if var box = s.minigame, let plugin = MinigameRegistry.plugin(box.id) {
            var ctx = context(s, now: now)
            plugin.gm(&box.data, .timerShift(ms: shift), &ctx)
            s.rng = ctx.rng
            s.minigame = box
        }
        if var bg = s.boardgame {
            if let h = bg.howtoEndsAt { bg.howtoEndsAt = h + shift }
            s.boardgame = bg
            Boardgames.shift(&s, ms: shift, now: now)
        }
        s.addLog("pause", "Weiter geht's", at: now)
    }
}