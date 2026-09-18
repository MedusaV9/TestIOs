import Foundation

extension Engine {
    // MARK: Helpers

    func refs(_ s: EngineState) -> [PlayerRef] {
        let ranking = s.ranking
        return s.players.map { p in PlayerRef(p, platz: (ranking.firstIndex { $0.id == p.id } ?? 0) + 1) }
    }

    func sectionLabel(_ s: EngineState) -> String {
        guard let section = s.currentSection else { return s.phase == .lobby ? "Lobby" : "Show" }
        let rounds = s.plan.filter { $0.typ == .runde }.count
        let plugin = MinigameRegistry.plugin(section.minigameId)
        switch section.typ {
        case .runde: return "Runde \(section.rundenNummer)/\(rounds) · \(plugin?.meta.name ?? section.minigameId)"
        case .jackpot: return "💰 Jackpot-Frage"
        case .finale: return "🐊 Finale"
        }
    }

    func progress(_ s: EngineState) -> Double {
        guard !s.plan.isEmpty else { return 0 }
        let totalQ = s.plan.reduce(0) { $0 + $1.fragen }
        let doneQ = s.plan.prefix(max(0, s.sectionIndex)).reduce(0) { $0 + $1.fragen } + s.questionIndex
        return min(1, Double(doneQ) / Double(max(1, totalQ)))
    }

    func standings(_ s: EngineState) -> [StandingEntry] {
        let leader = s.leader?.balance ?? 0
        return refs(s).sorted { $0.platz < $1.platz }.map { r in
            StandingEntry(player: r, delta: s.lastDeltas[r.id] ?? 0, rueckenwind: Economy.tailwindFactor(own: r.balance, leader: leader))
        }
    }

    func podium(_ s: EngineState) -> [PodiumEntry] {
        let ranking = s.ranking
        return ranking.enumerated().map { (i, p) in
            PodiumEntry(player: PlayerRef(p, platz: i + 1), platz: i + 1, mm: p.balance,
                        at: Economy.allTimeFor(finalBalance: p.balance, isWinner: i == 0), delta: p.balance - (s.bilanzVorFinale[p.id] ?? p.balance))
        }
    }

    /// Value of the jackpot question once it is drawn (hard 1.000 / ULTRAHARD 1.500).
    func jackpotValue(_ s: EngineState) -> Int {
        let d = s.currentQuestionIds.first.flatMap { catalog.question($0) }?.schw ?? .hard
        return Economy.jackpotQuestionValue(d)
    }

    func explainCard(_ s: EngineState) -> ExplainCardView {
        let section = s.currentSection!
        let plugin = resolvedPlugin(s, section)
        var text = plugin.meta.erklaerung
        var kurz = plugin.meta.kurz
        var regeln = plugin.meta.regeln
        var gewinn = plugin.meta.gewinn
        var name = plugin.meta.name
        var emoji = plugin.meta.emoji
        if section.typ == .jackpot {
            let value = jackpotValue(s)
            name = "Die Jackpot-Frage"
            emoji = "💰"
            kurz = "EINE Frage für alle — und das Glas geht mit."
            regeln = ["Eine einzige Frage — alle antworten gleichzeitig",
                      "Richtig: \(Money.format(value)) plus das komplette Jackpot-Glas",
                      "Mehrere Richtige teilen sich das Glas",
                      "Keine Joker — nur Wissen"]
            gewinn = "\(Money.format(value)) + Glas (\(Money.format(s.jackpotGlas))) · Falsch: 0"
            text = "EINE Frage für alle: \(Money.format(value)) plus der komplette Inhalt des Jackpot-Glases (\(Money.format(s.jackpotGlas))). Wer richtig liegt, teilt sich den Schatz. Keine Joker — nur Wissen."
        }
        if section.typ == .finale {
            let w = s.wFinal ?? 500
            name = section.minigameId == "alles-oder-banane" ? "Vabanque-Finale" : "Das große Lianen-Finale"
            emoji = "🐊"
            kurz = "\(section.fragen) Fragen, jede \(Money.format(w)) wert — der Letzte kann noch gewinnen."
            if section.minigameId != "alles-oder-banane" {
                regeln = ["\(section.fragen) Finalfragen — jede ist \(Money.format(w)) wert",
                          "Richtig: +\(Money.format(w)) · falsch: −\(Money.format(w / 2)) · keine Antwort: ±0",
                          "Deine Liane hängt über dem Krokodil-Fluss — so lang wie dein Konto",
                          "Keine Joker, keine Streaks, kein Speed-Bonus"]
                gewinn = "Richtig +\(Money.format(w)) · Falsch −\(Money.format(w / 2))"
            }
            text = "Jede der \(section.fragen) Finalfragen ist heute \(Money.format(w)) wert: richtig +\(Money.format(w)), falsch −\(Money.format(w / 2)). Keine Joker, keine Streaks, kein Speed-Bonus. " + plugin.meta.erklaerung
        }
        if section.notariat {
            text = "🤫 NOTARIATS-RUNDE: keine Joker, keine Tipps — dafür +25 % auf alle Fragenwerte. " + text
            regeln.insert("🤫 Notariats-Runde: keine Joker, keine Tipps — alle Fragenwerte +25 %", at: 0)
        }
        return ExplainCardView(minigameId: plugin.meta.id, name: name, emoji: emoji, kurz: kurz, text: text, regeln: regeln, gewinn: gewinn,
                               slot: section.slot, rundenNummer: section.rundenNummer,
                               rundenGesamt: s.plan.filter { $0.typ == .runde }.count, bereit: s.bereit, streik: s.streik,
                               kategorie: section.kategorie.map { catalog.categoryName($0) }, deadline: s.phaseEndsAt)
    }

    /// Music bed per phase. The cue only names the bed — one-shot effects
    /// (stingers, the reveal beat, applause) are the stage regie's job, so
    /// they fire exactly once per event instead of once per state update.
    func audioCue(_ s: EngineState, stage: MinigameStageOutput?) -> AudioCue {
        switch s.phase {
        case .lobby: return AudioCue(music: "lobby_loop")
        case .intro: return AudioCue(music: "intro_stinger")
        case .kategorieWahl, .erklaerkarte: return AudioCue(music: "standings_groove")
        case .frage, .aufloesung:
            // The question bed keeps running through the reveal (the regie ducks it).
            if let a = stage?.audio, a.music != nil { return AudioCue(music: a.music) }
            if s.isFinale { return AudioCue(music: "finale_showdown") }
            if s.isJackpot { return AudioCue(music: "jackpot_drama") }
            if let box = s.minigame, let p = MinigameRegistry.plugin(box.id) {
                if s.currentQuestionIds.indices.contains(s.questionIndex), let q = catalog.question(s.currentQuestionIds[s.questionIndex]), q.schw >= .hard, p.meta.musik == "question_bed_easy" {
                    return AudioCue(music: "question_bed_hard")
                }
                return AudioCue(music: p.meta.musik)
            }
            return AudioCue(music: "question_bed_easy")
        case .zwischenstand, .halbzeit: return AudioCue(music: "standings_groove")
        case .rad: return AudioCue(music: "wheel_spin")
        case .highlights: return AudioCue(music: "credits_outro")
        case .siegerehrung: return AudioCue(music: "victory_podium")
        case .ende: return AudioCue(music: "credits_outro")
        case .pause: return AudioCue(music: "lobby_loop")
        case .brettspiel: return AudioCue(music: s.boardgame?.id == "werwolf" ? "werwolf_night" : "boardgame_bed")
        }
    }

    // MARK: Stage

    public func stageView(_ s: EngineState, now: Millis, joinURL: String, gmURL: String) -> StageView {
        let scene: StageScene
        var stageOut: MinigameStageOutput? = nil
        switch s.phase {
        case .lobby:
            let canStart = canStart(s)
            let hint = s.settings.spielModus == .spieleabend ? "Wähle unten ein Spiel." : (s.players.count < Engine.minPlayers ? "Mindestens \(Engine.minPlayers) Spieler — scannt den QR-Code!" : "Alle da? Dann ▶ Start.")
            scene = .lobby(LobbyInfo(joinURL: joinURL, gmURL: gmURL, gmPin: s.gmPin, maxPlayers: s.settings.spielModus == .spieleabend ? Engine.maxPlayersSpieleabend : Engine.maxPlayers,
                                     canStart: canStart, startHint: hint, settings: s.settings, boardgames: Boardgames.cards(s)))
        case .intro:
            scene = .intro(headline: "\(s.settings.modus.title) · \(s.players.count) Affen", specialRules: s.settings.specialRules.map { "\($0.emoji) \($0.name)" }, deadline: s.phaseEndsAt)
        case .kategorieWahl:
            var counts: [String: Int] = [:]
            for v in s.kategorie.stimmen.values { counts[v, default: 0] += 1 }
            let opts = s.kategorie.optionen.map { VoteOption(id: $0, label: catalog.categoryName($0), emoji: catalog.categoryEmoji($0), count: counts[$0] ?? 0) }
            scene = .kategorieWahl(optionen: opts, letzter: s.kategorie.letzterWaehlt.flatMap { id in refs(s).first { $0.id == id } }, deadline: s.kategorie.endetAt, countdownAb: s.kategorie.countdownAb, gewinner: s.kategorie.gewinner)
        case .erklaerkarte:
            scene = .erklaerkarte(explainCard(s))
        case .frage, .aufloesung:
            let revealed = s.phase == .aufloesung
            if let box = s.minigame, let plugin = MinigameRegistry.plugin(box.id) {
                let out = plugin.stage(box.data, revealed, context(s, now: now))
                stageOut = out
                if revealed {
                    scene = .aufloesung(wall: out.wall, extra: out.extra, deltas: s.lastDeltas, minigameId: box.id, sectionKind: s.currentSection?.typ ?? .runde)
                } else {
                    scene = .frage(wall: out.wall, extra: out.extra, minigameId: box.id, sectionKind: s.currentSection?.typ ?? .runde, title: out.title)
                }
            } else {
                scene = .frage(wall: nil, extra: .none, minigameId: "", sectionKind: .runde, title: "")
            }
        case .zwischenstand, .halbzeit:
            scene = .zwischenstand(entries: standings(s), rundenNummer: s.currentSection?.rundenNummer ?? 0, rundenGesamt: s.plan.filter { $0.typ == .runde }.count, deadline: s.phaseEndsAt, halbzeit: s.phase == .halbzeit)
        case .rad:
            scene = .rad(wheelView(s))
        case .pause:
            scene = .pause(text: s.pauseText ?? "Pause", endsAt: s.pauseEndsAt, standings: standings(s))
        case .highlights:
            scene = .highlights(entries: s.highlights, deadline: s.phaseEndsAt)
        case .siegerehrung:
            scene = .siegerehrung(podium: podium(s), awards: s.awards, deadline: s.phaseEndsAt, revancheMoeglich: true, abend: s.abend)
        case .ende:
            scene = .ende(podium: podium(s))
        case .brettspiel:
            scene = .brettspiel(Boardgames.stageView(s, catalog: catalog, now: now))
        }
        if s.paused, s.phase != .lobby {
            return StageView(roomCode: s.roomCode, phase: .pause, scene: .pause(text: s.pauseText ?? "Pause", endsAt: s.pauseEndsAt, standings: standings(s)), players: refs(s), teams: s.teams,
                             jackpotGlas: s.jackpotGlas, jackpotAktiv: s.plan.contains { $0.typ == .jackpot }, moments: s.moments, serverTime: now, paused: true,
                             sectionLabel: sectionLabel(s), progress: progress(s), gmOnline: s.gmOnline, gmLos: s.settings.gmLos, canAdvance: true, advanceLabel: "Weiter",
                             audio: AudioCue(music: "lobby_loop"), modus: s.settings.modus, seq: s.seq, specialRules: s.settings.specialRules.map { $0.name }, affensteuerKiste: s.affensteuerKiste,
                             timerAus: s.settings.timerAus, fragenZeit: s.settings.fragenZeit)
        }
        let advance = advanceLabel(s)
        return StageView(roomCode: s.roomCode, phase: s.phase, scene: scene, players: refs(s), teams: s.teams, jackpotGlas: s.jackpotGlas,
                         jackpotAktiv: s.plan.contains { $0.typ == .jackpot } && s.sectionIndex <= (s.plan.firstIndex { $0.typ == .jackpot } ?? 0),
                         moments: s.moments, serverTime: now, paused: s.paused, sectionLabel: sectionLabel(s), progress: progress(s), gmOnline: s.gmOnline,
                         gmLos: s.settings.gmLos, canAdvance: advance != nil, advanceLabel: advance, audio: audioCue(s, stage: stageOut), modus: s.settings.modus,
                         seq: s.seq, specialRules: s.settings.specialRules.map { $0.name }, affensteuerKiste: s.affensteuerKiste,
                         timerAus: s.settings.timerAus, fragenZeit: s.settings.fragenZeit)
    }

    /// Label of the stage "Weiter" button (nil = nothing to advance right now).
    func advanceLabel(_ s: EngineState) -> String? {
        switch s.phase {
        case .lobby: return s.settings.spielModus == .quiz ? (canStart(s) ? "Starten, wenn alle da sind!" : nil) : nil
        case .intro: return "Überspringen"
        case .kategorieWahl: return "Wahl schließen"
        case .erklaerkarte: return "Los geht's"
        case .frage: return "Auflösen"
        case .aufloesung: return "Nächste Frage"
        case .zwischenstand: return "Weiter"
        case .rad: return s.rad.subphase == "dreht" ? nil : "Weiter"
        case .halbzeit: return "Weiter mit der Show"
        case .highlights: return "Zur Siegerehrung"
        case .siegerehrung: return "Zum Abspann"
        case .ende: return "Revanche"
        case .pause: return "Weiter"
        case .brettspiel: return Boardgames.advanceLabel(s)
        }
    }

    // MARK: Player

    public func playerView(_ s: EngineState, player id: PlayerId, now: Millis) -> PlayerView? {
        guard let p = s.player(id) else { return nil }
        let ref = PlayerRef(p, platz: s.place(of: id))
        var prompt: PlayerPrompt
        var status = sectionLabel(s)
        var haptic: String? = nil
        var flash: String? = nil
        switch s.phase {
        case .lobby:
            prompt = s.settings.spielModus == .spieleabend ? Boardgames.lobbyPrompt(s, id) : .idle(title: "Du bist drin! 🎉", subtitle: s.players.count < 2 ? "Wartet auf weitere Affen …" : "Der Bildschirm startet die Show.")
            status = "Lobby · \(s.players.count) Spieler"
        case .intro:
            prompt = .idle(title: "🎬 Die Show beginnt!", subtitle: s.screenOnline ? "Augen auf den großen Bildschirm!" : "Der Game Master führt durch den Abend!")
        case .kategorieWahl:
            let mayVote = s.kategorie.letzterWaehlt == nil || s.kategorie.letzterWaehlt == id
            var counts: [String: Int] = [:]
            for v in s.kategorie.stimmen.values { counts[v, default: 0] += 1 }
            let opts = s.kategorie.optionen.map { VoteOption(id: $0, label: catalog.categoryName($0), emoji: catalog.categoryEmoji($0), count: counts[$0] ?? 0) }
            prompt = mayVote ? .vote(title: s.kategorie.letzterWaehlt == id ? "🎯 DU wählst die Kategorie!" : "Welche Kategorie?", options: opts, chosen: s.kategorie.stimmen[id], deadline: s.kategorie.endetAt)
                             : .idle(title: "🎯 \(s.player(s.kategorie.letzterWaehlt ?? "")?.name ?? "") wählt die Kategorie", subtitle: "Comeback-Regel")
        case .erklaerkarte:
            let card = explainCard(s)
            prompt = .explain(title: "\(card.emoji) \(card.name)", text: card.kurz, regeln: card.regeln, gewinn: card.gewinn.isEmpty ? nil : card.gewinn,
                              ready: s.bereit.contains(id), streik: s.streik.contains(id), deadline: s.phaseEndsAt)
        case .frage, .aufloesung:
            let revealed = s.phase == .aufloesung
            if let box = s.minigame, let plugin = MinigameRegistry.plugin(box.id) {
                prompt = plugin.prompt(box.data, id, revealed, context(s, now: now))
                if revealed, case .reveal(let title, let correct, let plain, var detail, _, _) = prompt {
                    // The card shows the BOOKED delta (streak, wheel, Rückenwind, alms …), and says why it differs.
                    let delta = s.lastDeltas[id] ?? 0
                    var notes: [String] = []
                    if correct == false, delta > 0 { notes.append("🍌 Applaus-Almosen: als Einzige/r daneben — \(Money.format(delta)) Trost") }
                    if correct == true, plugin.meta.streak, p.streak >= 3, !s.isFinale { notes.append("🔥 Streak ×\(p.streak >= 5 ? "2" : "1,5")") }
                    if correct == true, delta > plain, s.nextMods.gewinnFaktor > 1 { notes.append("🎡 Doppelter Zaster") }
                    if correct == true, delta > plain, s.leader?.id != id, Economy.tailwindFactor(own: p.balance - delta, leader: s.leader?.balance ?? 0) > 1 { notes.append("🌬️ Rückenwind") }
                    if !notes.isEmpty { detail = ([detail].compactMap { $0 } + notes).joined(separator: " · ") }
                    prompt = .reveal(title: title, correct: correct, delta: delta, detail: detail, streak: p.streak, speedBonus: nil)
                    haptic = correct == true ? "success" : (correct == false ? "error" : nil)
                    flash = correct == true ? "richtig" : (correct == false ? "falsch" : nil)
                }
            } else {
                prompt = .idle(title: "…", subtitle: nil)
            }
        case .zwischenstand, .halbzeit:
            prompt = .idle(title: "Platz \(ref.platz) · \(Money.format(p.balance))", subtitle: s.lastDeltas[id].map { "Letzte Runde: \(Money.formatDelta($0))" })
        case .rad:
            prompt = wheelPrompt(s, player: id)
        case .pause:
            prompt = .idle(title: s.pauseText ?? "Pause", subtitle: "Gleich geht's weiter")
        case .highlights:
            prompt = .idle(title: "🎞️ Highlights des Abends", subtitle: "Augen auf den Bildschirm")
        case .siegerehrung:
            let pod = podium(s).first { $0.player.id == id }
            prompt = .idle(title: ref.platz == 1 ? "👑 DU HAST GEWONNEN!" : "Platz \(ref.platz)", subtitle: "\(Money.format(p.balance)) → +\(pod?.at ?? 0) All-Time")
        case .ende:
            prompt = s.feedback[id] == nil ? .feedback(questions: ["Wie fandest du die Fragen?", "Wie war das Tempo?", "Was war dein Highlight?"], done: false)
                                          : .idle(title: "Danke fürs Spielen! 🍌", subtitle: "Der Bildschirm startet die Revanche.")
        case .brettspiel:
            prompt = Boardgames.playerPrompt(s, id, catalog: catalog, now: now)
        }
        if s.paused, s.phase != .lobby { prompt = .idle(title: s.pauseText ?? "🍌 Bananen-Pause", subtitle: s.pauseEndsAt.map { "Weiter in \(max(0, ($0 - now) / 1000)) s" } ?? "Gleich geht's weiter") }
        if let vote = s.gmVote, vote.ergebnis == nil, s.phase != .frage {
            prompt = .vote(title: vote.frage, options: vote.optionen.enumerated().map { VoteOption(id: String($0.offset), label: $0.element) }, chosen: vote.stimmen[id].map(String.init), deadline: vote.endetAt)
        }
        if let poll = s.moodPoll, poll[id] == nil, s.phase != .frage {
            prompt = .choice(question: "Blitz-Stimmung: Wie geht's dir gerade?", options: ["🥱", "😐", "🙂", "😄", "🤩"].enumerated().map { ChoiceOption(id: $0.offset, text: $0.element) }, chosen: nil, deadline: now + 5000, secondTry: false, hint: nil)
        }
        let leader = s.leader?.balance ?? 0
        return PlayerView(roomCode: s.roomCode, phase: s.paused ? .pause : s.phase, me: ref, prompt: prompt, jokers: jokerViews(s, player: p), statusText: status,
                          phaseEndsAt: s.phaseEndsAt, paused: s.paused, pauseText: s.pauseText, serverTime: now,
                          rueckenwind: Economy.tailwindFactor(own: p.balance, leader: leader), whisper: s.whispers[id], moments: Array(s.moments.suffix(3)),
                          ranking: refs(s).sorted { $0.platz < $1.platz }, teamTopf: p.teamId.flatMap { t in s.teams.first { $0.id == t }?.topf },
                          sectionLabel: sectionLabel(s), ohneScreen: !s.screenOnline, haptic: haptic, flash: flash)
    }

    // MARK: GM

    public func gmView(_ s: EngineState, now: Millis, joinURL: String, gmURL: String) -> GmView {
        let stage = stageView(s, now: now, joinURL: joinURL, gmURL: gmURL)
        var spick: GmQuestionInfo? = nil
        var answers: [PlayerId: String] = [:]
        if let box = s.minigame, let plugin = MinigameRegistry.plugin(box.id) {
            let info = plugin.gmInfo(box.data, context(s, now: now))
            spick = info.question
            answers = info.answers
        }
        // Shelf: the next 5 questions of the current section.
        var regal: [GmQuestionInfo] = []
        for qid in s.currentQuestionIds.dropFirst(s.questionIndex + 1).prefix(5) {
            if let q = catalog.question(qid) {
                let korrekt = q.correctIndex.flatMap { i in q.choiceOptions.indices.contains(i) ? q.choiceOptions[i] : nil } ?? q.schaetz.map { "\($0.richtwert) \($0.einheit)" } ?? "—"
                regal.append(GmQuestionInfo(id: q.id, text: q.text, kategorie: catalog.categoryName(q.kat), schwierigkeit: q.schw, korrekt: korrekt, erklaerung: q.erkl, tipps: q.tipps, typ: q.typ))
            }
        }
        // Drama meter lite: score gap, spread, remaining rounds.
        let ranking = s.ranking
        var drama = 50
        var empfehlung = "Alles im Fluss."
        if ranking.count >= 2 {
            let gap = ranking[0].balance - ranking[1].balance
            let avg = max(1, ranking.reduce(0) { $0 + $1.balance } / ranking.count)
            let rel = Double(gap) / Double(avg)
            drama = max(0, min(100, Int(100 - rel * 60)))
            if rel > 0.6 { empfehlung = "Blowout-Gefahr: Rad drehen oder Aufholjagd-Boost für den Letzten." }
            else if s.questionsSinceWheel >= 4 { empfehlung = "Vier Fragen ohne Rad — Zeit für einen Dreh." }
            else if rel < 0.1 { empfehlung = "Kopf-an-Kopf! Encore-Frage lohnt sich." }
        }
        return GmView(stage: stage, spickzettel: spick, antworten: answers, regal: regal, settings: s.settings, log: Array(s.log.suffix(40)),
                      timerExtensionsLeft: max(0, 2 - s.timerExtensions), jokerBudget: s.jokerGrantBudget, encoresLeft: max(0, 2 - s.encoresThisRound),
                      moodPollsLeft: max(0, 3 - s.moodPolls), dramaScore: drama, empfehlung: empfehlung, vote: s.gmVote,
                      canRig: s.phase == .zwischenstand, gmPin: s.gmPin, players: s.players, roomCode: s.roomCode, joinURL: joinURL)
    }
}
