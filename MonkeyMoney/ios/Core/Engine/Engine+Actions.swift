import Foundation

extension Engine {
    // MARK: Player actions

    /// Who decides the "👍 Weiter" skip: connected human players (bots never hold the show up).
    static func weiterWaehler(_ s: EngineState) -> [PlayerId] { s.connectedPlayers.filter { !$0.isBot }.map { $0.id } }

    /// Skip-vote state in a waiting phase (nil elsewhere).
    static func weiterInfo(_ s: EngineState, player: PlayerId? = nil) -> WeiterInfo? {
        guard !s.paused, [.zwischenstand, .halbzeit, .highlights].contains(s.phase), let end = s.phaseEndsAt, end > 0 else { return nil }
        let humans = weiterWaehler(s)
        guard !humans.isEmpty else { return nil }
        return WeiterInfo(done: player.map { s.bereit.contains($0) } ?? false, anzahl: humans.filter { s.bereit.contains($0) }.count, noetig: humans.count, spieler: s.bereit)
    }

    func playerAction(_ s: inout EngineState, _ id: PlayerId, _ action: PlayerAction, now: Millis) {
        guard let pi = s.index(of: id) else { return }
        if s.paused { return }
        switch action {
        case .setLook(let avatar):
            guard s.phase == .lobby || s.phase == .ende || s.phase == .siegerehrung else { return }
            s.players[pi].avatar = avatar
            return
        case .setThemen(let t):
            s.players[pi].themen = Array(t.prefix(3))
            return
        case .teamWunsch:
            return
        case .feedback(let answers):
            s.feedback[id] = answers
            return
        case .joker(let jid, let stufe):
            useJoker(&s, player: id, jokerId: jid, stufe: stufe, now: now)
            return
        case .jokerBuy(let jid):
            buyJoker(&s, player: id, jokerId: jid, now: now)
            return
        default: break
        }

        switch s.phase {
        case .kategorieWahl:
            if case .vote(let k) = action, s.kategorie.optionen.contains(k) {
                if let l = s.kategorie.letzterWaehlt, l != id { return }
                s.kategorie.stimmen[id] = k
                s.kategorie.countdownAb = now + 8000
            }
        case .erklaerkarte:
            if case .ready(let what) = action {
                if what == "streik" {
                    if !s.streik.contains(id) { s.streik.append(id) }
                    s.bereit.removeAll { $0 == id }
                    let active = s.connectedPlayers.count
                    if s.streik.count * 2 > active, let section = s.currentSection, section.typ == .runde, section.minigameId != MinigameRegistry.fallbackId {
                        // Strike majority: minigame swapped for a single Blitzfrage (pot forfeited).
                        s.plan[s.sectionIndex].minigameId = MinigameRegistry.fallbackId
                        s.plan[s.sectionIndex].fragen = 1
                        s.addMoment("streik", "✊ STREIK! Das Minispiel entfällt — ersatzweise eine Blitzfrage.", at: now)
                        prepareSectionQuestions(&s, section: s.plan[s.sectionIndex])
                        s.phaseEndsAt = now + 3000
                    }
                } else {
                    if !s.bereit.contains(id) { s.bereit.append(id) }
                    let active = s.connectedPlayers.map { $0.id }
                    if active.allSatisfy({ s.bereit.contains($0) }) { s.phaseEndsAt = min(s.phaseEndsAt ?? now, now + 1200) }
                }
            }
        case .zwischenstand, .halbzeit, .highlights:
            // "👍 Weiter": when every connected human wants to move on, the wait shrinks to 1.5 s.
            if case .ready(let what) = action, what == "weiter" {
                if s.bereit.contains(id) { s.bereit.removeAll { $0 == id } } else { s.bereit.append(id) }
                let humans = Engine.weiterWaehler(s)
                if !humans.isEmpty, humans.allSatisfy({ s.bereit.contains($0) }), let end = s.phaseEndsAt, end > now + 1500 {
                    s.phaseEndsAt = now + 1500
                    s.addMoment("weiter", "👍 Alle wollen weiter!", at: now)
                }
            }
        case .frage:
            guard var box = s.minigame, let plugin = MinigameRegistry.plugin(box.id) else { return }
            var ctx = context(s, now: now)
            plugin.reduce(&box.data, action, id, &ctx)
            s.rng = ctx.rng
            s.minigame = box
            if case .buzz = action { s.players[pi].stats.buzzes += 1 }
        case .rad:
            if s.rad.subphase == "interaktion", case .binary(let v) = action { s.rad.votes[id] = v; checkInteractionEarlyClose(&s, now: now) }
            else if s.rad.subphase == "interaktion", case .confirm = action { s.rad.votes[id] = "umarmt"; checkInteractionEarlyClose(&s, now: now) }
            else if s.rad.subphase == "interaktion", case .radAktion(let v) = action { s.rad.votes[id] = v; checkInteractionEarlyClose(&s, now: now) }
        case .brettspiel:
            Boardgames.playerAction(&s, id, action, catalog: catalog, now: now)
        default:
            break
        }
        // GM votes & mood polls are phase independent.
        if case .vote(let v) = action, var gv = s.gmVote, gv.ergebnis == nil, let idx = Int(v), idx < gv.optionen.count {
            gv.stimmen[id] = idx
            s.gmVote = gv
        }
        if case .choose(let idx) = action, s.moodPoll != nil, s.phase != .frage { s.moodPoll?[id] = idx }
    }

    // MARK: Jokers (§5.1)

    func questionValueNow(_ s: EngineState) -> Int {
        if s.currentQuestionIds.indices.contains(s.questionIndex), let q = catalog.question(s.currentQuestionIds[s.questionIndex]) { return q.value }
        return 250
    }

    func jokerPrice(_ s: EngineState, player: Player, def: JokerDef, stufe: Int?) -> Int {
        let discount = Economy.socialDiscount(place: s.place(of: player.id), players: s.players.count)
        return Jokers.price(def, questionValue: questionValueNow(s), balance: player.balance, discount: discount, stufe: stufe)
    }

    func jokerUsable(_ s: EngineState, def: JokerDef, player: Player) -> Bool {
        guard s.settings.jokerAn, !s.isFinale, !s.roundMods.notariat else { return false }
        switch def.fenster {
        case .frage:
            guard s.phase == .frage, let box = s.minigame, let plugin = MinigameRegistry.plugin(box.id) else { return false }
            if def.id == .bananenSplit && !plugin.meta.jokerAktionen.contains("fiftyFifty") { return false }
            if def.id == .schmiergeld && !plugin.meta.jokerAktionen.contains("removeOne") { return false }
            if def.id == .rueckgaberecht && !plugin.meta.jokerAktionen.contains("secondTry") { return false }
            if def.id == .ueberziehungskredit && plugin.meta.roundBased { return false }
            // 50:50 / hint / second try need at least 3 options (never on Wahr/Falsch).
            if def.minOptions > 0, !plugin.meta.roundBased, s.currentQuestionIds.indices.contains(s.questionIndex),
               let q = catalog.question(s.currentQuestionIds[s.questionIndex]), q.choiceOptions.count < def.minOptions { return false }
            return true
        case .vorFrage:
            return s.phase == .erklaerkarte || s.phase == .kategorieWahl || s.phase == .aufloesung || s.phase == .zwischenstand
        case .zwischenFragen:
            return s.phase == .aufloesung || s.phase == .zwischenstand || s.phase == .erklaerkarte || s.phase == .kategorieWahl || s.phase == .rad
        }
    }

    func useJoker(_ s: inout EngineState, player id: PlayerId, jokerId: String, stufe: Int?, now: Millis) {
        guard let pi = s.index(of: id), let jid = JokerId(rawValue: jokerId) else { return }
        let def = Jokers.def(jid)
        var p = s.players[pi]
        guard jokerUsable(s, def: def, player: p) else { return }
        // Max 1 info joker per question, max per question rules.
        let usedKey = "used_\(jid.rawValue)_\(s.sectionIndex)_\(s.questionIndex)"
        if let maxPer = def.maxProFrage, (p.jokerKaeufe[usedKey] ?? 0) >= maxPer { return }
        if def.infoJoker, (p.jokerKaeufe["info_\(s.sectionIndex)_\(s.questionIndex)"] ?? 0) >= 1 { return }
        // Pay with a charge or buy on the spot.
        var charges = p.jokers[jid.rawValue] ?? 0
        var price = 0
        if charges > 0 {
            charges -= 1
        } else {
            price = jokerPrice(s, player: p, def: def, stufe: stufe)
            let bought = p.jokerKaeufe["kauf_\(jid.rawValue)"] ?? 0
            guard bought < def.maxKaeufe, price > 0 || def.preis == .gratis else { return }
            guard p.balance - price >= Economy.overdraftLimit else { return }
            p.jokerKaeufe["kauf_\(jid.rawValue)", default: 0] += 1
        }
        p.jokers[jid.rawValue] = charges

        // Effect
        var ok = true
        switch jid {
        case .bananenSplit, .schmiergeld, .rueckgaberecht, .ueberziehungskredit:
            guard var box = s.minigame, let plugin = MinigameRegistry.plugin(box.id) else { return }
            var ctx = context(s, now: now)
            switch jid {
            case .bananenSplit: plugin.gm(&box.data, .fiftyFifty(player: id), &ctx)
            case .schmiergeld:
                if stufe == 2 {
                    if s.currentQuestionIds.indices.contains(s.questionIndex), let q = catalog.question(s.currentQuestionIds[s.questionIndex]), let tip = q.tipps.first {
                        s.whispers[id] = "🤫 " + tip
                    } else { ok = false }
                } else { plugin.gm(&box.data, .removeOption(player: id), &ctx) }
            case .rueckgaberecht:
                let before = box.data
                plugin.gm(&box.data, .secondTry(player: id), &ctx)
                if box.data == before { ok = false }
            case .ueberziehungskredit:
                plugin.gm(&box.data, .timerExtend(ms: plugin.meta.roundBased ? 5000 : 10_000), &ctx)
            default: break
            }
            s.rng = ctx.rng
            s.minigame = box
        case .goldeneBanane:
            s.nextMods.goldeneBanane.insert(id)
        case .bananentresor:
            p.klauSchutzBisRunde = s.currentSection?.rundenNummer ?? 0
        case .portfolioUmschichtung:
            // Swap the upcoming question for one from another category.
            let nextIdx = s.phase == .aufloesung ? s.questionIndex + 1 : s.questionIndex
            if s.currentQuestionIds.indices.contains(nextIdx), let old = catalog.question(s.currentQuestionIds[nextIdx]) {
                let opts = pickOptions(s, anzahl: 1, kategorien: s.settings.kategorienPool, schwierigkeiten: s.settings.questionFilter.tiers([old.schw]),
                                       typen: old.typ.isChoiceLike ? [.choice, .emoji, .wahrFalsch] : [old.typ])
                if let fresh = catalog.pick(opts, rng: &s.rng).first(where: { $0.kat != old.kat }) ?? catalog.pick(opts, rng: &s.rng).first {
                    s.currentQuestionIds[nextIdx] = fresh.id
                    s.usedQuestionIds.append(fresh.id)
                } else { ok = false }
            } else { ok = false }
        }
        guard ok else { return }
        p.balance -= price
        p.jokerKaeufe[usedKey, default: 0] += 1
        if def.infoJoker { p.jokerKaeufe["info_\(s.sectionIndex)_\(s.questionIndex)", default: 0] += 1 }
        p.stats.jokerGenutzt += 1
        s.players[pi] = p
        let priceText = price > 0 ? " (−\(Money.format(price)))" : ""
        s.addMoment("joker", "\(def.emoji) \(p.name) zündet \(def.name)\(priceText)", player: id, betrag: price > 0 ? -price : nil, at: now)
        s.addLog("joker", "\(p.name): \(def.name) Stufe \(stufe ?? 1)", at: now)
    }

    func buyJoker(_ s: inout EngineState, player id: PlayerId, jokerId: String, now: Millis) {
        guard let pi = s.index(of: id), let jid = JokerId(rawValue: jokerId), s.settings.jokerAn else { return }
        let def = Jokers.def(jid)
        var p = s.players[pi]
        let bought = p.jokerKaeufe["kauf_\(jid.rawValue)"] ?? 0
        guard bought < def.maxKaeufe else { return }
        let price = jokerPrice(s, player: p, def: def, stufe: nil)
        guard price > 0, p.balance - price >= Economy.overdraftLimit else { return }
        p.balance -= price
        p.jokers[jid.rawValue, default: 0] += 1
        p.jokerKaeufe["kauf_\(jid.rawValue)", default: 0] += 1
        s.players[pi] = p
        s.addMoment("joker", "🛒 \(p.name) kauft \(def.name) für \(Money.format(price))", player: id, betrag: -price, at: now)
    }

    func jokerViews(_ s: EngineState, player: Player) -> [JokerView] {
        guard s.settings.jokerAn else { return [] }
        return Jokers.all.map { def in
            let charges = player.jokers[def.id.rawValue] ?? 0
            let price = jokerPrice(s, player: player, def: def, stufe: nil)
            let bought = player.jokerKaeufe["kauf_\(def.id.rawValue)"] ?? 0
            let usable = jokerUsable(s, def: def, player: player) && (charges > 0 || (bought < def.maxKaeufe && player.balance - price >= Economy.overdraftLimit))
            return JokerView(id: def.id.rawValue, name: def.name, emoji: def.emoji, ladungen: charges, preis: price,
                             kaufbar: charges == 0 && bought < def.maxKaeufe && def.preis != .gratis, nutzbar: usable, beschreibung: def.beschreibung)
        }
    }

    // MARK: GM commands (the 17 tools)

    func gmCommand(_ s: inout EngineState, _ cmd: GmCommand, now: Millis) {
        switch cmd {
        case .flowNext:
            flowNext(&s, now: now)
        case .flowSkipOpening:
            if s.phase == .intro { s.openingSkipped = true; s.phaseEndsAt = now }
        case .settingsSet(let patch):
            // Mid-match only the live knobs; plan-shaping settings wait for the lobby.
            guard s.phase == .lobby || s.phase == .ende || !patch.keys.contains(where: { Engine.lobbyOnlySettings.contains($0) }) else { return }
            if let b = patch["timerAus"]?.boolValue, b != s.settings.timerAus {
                s.addMoment("regie", b ? "⏱️ Timer aus — antwortet in Ruhe, der Show-Master löst auf" : "⏱️ Timer wieder an", at: now)
            }
            if let n = patch["fragenZeit"]?.intValue { s.addMoment("regie", n <= 0 ? "⏱️ Zeit pro Frage: nach Schwierigkeit" : "⏱️ Zeit pro Frage: \(n) s", at: now) }
            let poolBefore = s.settings.kategorienPool
            let filterBefore = s.settings.questionFilter
            s.settings.apply(patch: patch)
            if s.settings.kategorienPool != poolBefore || patch["fragenSet"] != nil {
                let name = QuestionSets.set(s.settings.fragenSet)?.name ?? "Eigene Auswahl"
                s.addMoment("regie", "📚 Fragen-Set: \(name)" + (s.phase == .lobby ? "" : " — gilt ab der nächsten Runde"), at: now)
            }
            if s.settings.questionFilter != filterBefore {
                // Live: upcoming questions that are now switched off leave the shelf right away.
                let swapped = refreshUpcoming(&s)
                let aktiv = catalog.katalogInfo(settings: s.settings).aktiv
                s.addMoment("regie", "🎛️ Fragen-Filter: \(aktiv) Fragen aktiv" + (swapped > 0 ? " — \(swapped) im Regal getauscht" : ""), at: now)
            }
            s.addLog("settings", "Einstellungen geändert: \(patch.keys.sorted().joined(separator: ", "))", at: now)
        case .scoreAdjust(let pid, let delta, let grund):
            guard let i = s.index(of: pid) else { return }
            let cap = Economy.scoreAdjustSoftCap(questionsPerRound: s.currentSection?.fragen ?? 4)
            let d = max(-cap * 2, min(cap * 2, Economy.roundTo50(delta)))
            s.players[i].balance = Economy.clampToOverdraft(s.players[i].balance + d)
            s.addMoment("bank", "🏦 Bananen-Bank: \(Money.formatDelta(d)) für \(s.players[i].name) — „\(grund)“", player: pid, betrag: d, at: now)
            s.addLog("gm", "score.adjust \(s.players[i].name) \(d) (\(grund))", at: now)
        case .timerExtend(let ms):
            guard s.phase == .frage, s.timerExtensions < 2, var box = s.minigame, let plugin = MinigameRegistry.plugin(box.id) else { return }
            var ctx = context(s, now: now)
            plugin.gm(&box.data, .timerExtend(ms: ms), &ctx)
            s.rng = ctx.rng
            s.minigame = box
            s.timerExtensions += 1
            s.addMoment("regie", "⏳ Zeitmaschine: +\(ms / 1000) s", at: now)
        case .pause(let text, let dauer):
            pause(&s, text: text, dauerMs: dauer, now: now)
        case .resume:
            resume(&s, now: now)
        case .kategoriePick(let k):
            guard s.phase == .kategorieWahl else { return }
            s.kategorie.stimmen = ["_gm": k]
            if !s.kategorie.optionen.contains(k) { s.kategorie.optionen.append(k) }
            closeKategorie(&s, now: now)
        case .hintGlobal:
            guard s.phase == .frage, s.tippStufe < 3, !s.roundMods.notariat else { return }
            s.tippStufe += 1
            s.nextMods.wertFaktor = max(0.25, s.nextMods.wertFaktor - 0.25)
            if var box = s.minigame, let plugin = MinigameRegistry.plugin(box.id), s.tippStufe == 1 {
                var ctx = context(s, now: now)
                plugin.gm(&box.data, .removeOption(player: nil), &ctx)
                s.rng = ctx.rng
                s.minigame = box
            }
            s.addMoment("tipp", "💡 Tipp-Kanone Stufe \(s.tippStufe): Fragenwert −25 %", at: now)
        case .whisper(let pid, let text):
            s.whispers[pid] = "🤫 " + text
            s.addLog("gm", "Flüster-Tipp an \(s.player(pid)?.name ?? pid)", at: now)
        case .voteStart(let frage, let optionen, let dauer, let bindend):
            s.gmVote = GmVote(frage: frage, optionen: optionen, stimmen: [:], endetAt: now + (dauer ?? 20_000), bindend: bindend, ergebnis: nil)
        case .questionMarkBroken(let grund, let refund):
            guard s.phase == .frage || s.phase == .aufloesung, let box = s.minigame, let plugin = MinigameRegistry.plugin(box.id) else { return }
            if s.phase == .aufloesung {
                // Roll back the booked deltas.
                for (pid, d) in s.lastDeltas { if let i = s.index(of: pid) { s.players[i].balance -= d } }
            }
            if refund == "grantAll" {
                let v = questionValueNow(s)
                for i in s.players.indices where s.players[i].connected { s.players[i].balance += v }
            }
            s.addMoment("buzzer", "🔴 Roter Buzzer: Frage annulliert (\(grund))", at: now)
            s.minigame = nil
            _ = plugin
            // Replacement question of the same tier if available.
            if s.currentQuestionIds.indices.contains(s.questionIndex), let old = catalog.question(s.currentQuestionIds[s.questionIndex]),
               let fresh = replacementQuestion(&s, for: old) {
                s.currentQuestionIds[s.questionIndex] = fresh.id
                s.usedQuestionIds.append(fresh.id)
                startQuestion(&s, now: now)
                return
            }
            s.minigame = box
            afterAufloesung(&s, now: now)
        case .gameSkip(let keepPoints):
            guard s.phase == .frage || s.phase == .erklaerkarte || s.phase == .aufloesung else { return }
            if s.phase == .frage, !keepPoints { s.minigame = nil }
            if s.phase == .frage, keepPoints, let box = s.minigame, let plugin = MinigameRegistry.plugin(box.id) {
                bookQuestion(&s, plugin: plugin, box: box, now: now)
                s.phaseEndsAt = now + 3000
                return
            }
            s.addMoment("regie", "⏭️ Notausgang: Runde übersprungen", at: now)
            finishSection(&s, now: now)
        case .punish(let pid, let strafe):
            guard let i = s.index(of: pid), s.punishedLast != pid, !s.settings.familienModus else { return }
            s.punishedLast = pid
            switch strafe {
            case "bananensteuer":
                s.players[i].balance -= Economy.bananaTax
                s.jackpotGlas += Economy.bananaTax
                s.addMoment("pranger", "⚖️ Bananen-Steuer: \(s.players[i].name) zahlt \(Money.format(Economy.bananaTax)) ins Glas", player: pid, betrag: -Economy.bananaTax, at: now)
            case "clown":
                s.players[i].clown = true
                s.addMoment("pranger", "🤡 \(s.players[i].name) trägt bis Rundenende die Clownsnase", player: pid, at: now)
            default:
                s.addMoment("pranger", "📳 Handy-Erdbeben für \(s.players[i].name)!", player: pid, at: now)
            }
        case .boost(let pid, let art, let grund):
            guard let i = s.index(of: pid), !s.boostsThisRound.contains(pid), s.place(of: pid) > 2 else { return }
            s.boostsThisRound.append(pid)
            switch art {
            case "x2": s.nextMods.boostX2.insert(pid)
            case "plus300": s.players[i].balance += 300
            default: s.players[i].jokers[JokerId.bananenSplit.rawValue, default: 0] += 1
            }
            s.addMoment("boost", "🐒 Gönnung vom Boss für \(s.players[i].name): \(art == "x2" ? "×2 nächste Frage" : art == "plus300" ? "+300 MM" : "Gratis-Joker") — „\(grund)“", player: pid, at: now)
        case .jokerGrant(let ziel, let jid):
            guard s.jokerGrantBudget > 0, JokerId(rawValue: jid) != nil else { return }
            let targets = ziel == "alle" ? s.players.map { $0.id } : [ziel]
            for t in targets { if let i = s.index(of: t) { s.players[i].jokers[jid, default: 0] += 1 } }
            s.jokerGrantBudget -= 1
            s.addMoment("joker", "🎁 Gnaden-Automat: \(Jokers.def(JokerId(rawValue: jid)!).name) für \(ziel == "alle" ? "alle" : s.player(ziel)?.name ?? ziel)", at: now)
        case .wheelSpin(let rig):
            guard s.phase == .zwischenstand || s.phase == .aufloesung || s.phase == .erklaerkarte, s.settings.radAn else { return }
            let target = rig.flatMap { WheelSegmentId(rawValue: $0) }
            if target != nil { s.addLog("gm", "Gezinktes Rad: \(rig ?? "")", at: now) }
            enterRad(&s, now: now, rig: target)
        case .moodPoll:
            guard s.moodPolls < 3 else { return }
            s.moodPolls += 1
            s.moodPoll = [:]
        case .feedbackCollect:
            s.addMoment("feedback", "📝 Feedback-Runde: 3 Fragen auf euren Handys", at: now)
        case .encore:
            guard s.phase == .aufloesung || s.phase == .frage, s.encoresThisRound < 2, let section = s.currentSection, section.typ == .runde else { return }
            let filter = s.settings.questionFilter
            var opts = pickOptions(s, anzahl: 1, kategorien: section.kategorie.map { [$0] } ?? s.settings.kategorienPool,
                                   schwierigkeiten: filter.tiers(section.schwierigkeiten), typen: contentTypes(s, section))
            var q = catalog.pick(opts, rng: &s.rng).first
            if q == nil { opts.kategorien = s.settings.kategorienPool; opts.schwierigkeiten = []; q = catalog.pick(opts, rng: &s.rng).first }
            if let q = q {
                s.currentQuestionIds.append(q.id)
                s.usedQuestionIds.append(q.id)
                s.encoresThisRound += 1
                s.addMoment("encore", "🎤 ENCORE! Eine Zusatzfrage", at: now)
            }
        case .soundPlay(let sfx):
            s.addMoment("sound", sfx, at: now)
        case .autoGmSet(let on):
            s.settings.autoGm = on || s.settings.gmLos
        case .revanche:
            revanche(&s, now: now)
        case .ende:
            if s.phase != .lobby { enterEnde(&s, now: now) }
        case .kick(let pid):
            leave(&s, pid, now: now)
        case .lookSet(let pid, let avatar):
            if let i = s.index(of: pid) { s.players[i].avatar = avatar }
        case .teamsShuffle:
            guard s.phase == .lobby else { return }
            Teams.assign(&s)
        case .boardgameStart(let id, let optionen):
            Boardgames.start(&s, id: id, optionen: optionen, catalog: catalog, now: now)
        case .boardgameAbort:
            Boardgames.abort(&s, now: now)
        case .boardgameLocal(let sitz, let action):
            Boardgames.localAction(&s, sitz: sitz, action, catalog: catalog, now: now)
        case .botAdd, .botRemove:
            break // handled by the room layer (bots are ordinary players)
        case .questionSkip:
            guard s.phase == .frage, let box = s.minigame, let section = s.currentSection else { return }
            // Annulled: nothing is booked, the next question (or the round end) follows.
            s.minigame = nil
            s.addMoment("regie", "⏭️ Frage übersprungen", at: now)
            s.addLog("gm", "Frage übersprungen: \(s.currentQuestionIds.indices.contains(s.questionIndex) ? s.currentQuestionIds[s.questionIndex] : "-")", at: now)
            if box.roundBased { finishSection(&s, now: now); return }
            s.questionIndex += 1
            if s.questionIndex < section.fragen + s.encoresThisRound && s.questionIndex < s.currentQuestionIds.count {
                startQuestion(&s, now: now)
            } else {
                finishSection(&s, now: now)
            }
        case .timerShift(let ms):
            guard s.phase == .frage, ms != 0, var box = s.minigame, let plugin = MinigameRegistry.plugin(box.id) else { return }
            var ctx = context(s, now: now)
            var shift = ms
            if ms < 0 {
                // Never below 3 s on the clock.
                guard !s.settings.timerAus, let dl = plugin.stage(box.data, false, ctx).wall?.deadline ?? s.phaseEndsAt else { return }
                shift = max(ms, min(0, 3000 - (dl - now)))
                guard shift < 0 else { return }
            }
            plugin.gm(&box.data, .timerShift(ms: shift), &ctx)
            s.rng = ctx.rng
            s.minigame = box
            let secs = String(format: "%.0f", Double(abs(shift)) / 1000)
            s.addMoment("regie", shift > 0 ? "⏳ Regie: +\(secs) s" : "⏩ Regie: −\(secs) s", at: now)
        case .questionReplace(let frageId):
            guard s.phase == .frage || s.phase == .erklaerkarte, s.currentSection != nil, s.currentQuestionIds.indices.contains(s.questionIndex) else { return }
            if s.phase == .frage { guard let box = s.minigame, !box.roundBased else { return } }
            let oldId = s.currentQuestionIds[s.questionIndex]
            let fresh = frageId.map { manualQuestion(s, $0) } ?? replacementQuestion(&s, for: catalog.question(oldId))
            guard let q = fresh else { s.addLog("gm", "Kein passender Ersatz für \(oldId)", at: now); return }
            if s.phase == .erklaerkarte { s.usedQuestionIds.removeAll { $0 == oldId } }
            s.currentQuestionIds[s.questionIndex] = q.id
            s.usedQuestionIds.append(q.id)
            s.addMoment("regie", "🔄 Frage getauscht", at: now)
            s.addLog("gm", "Frage getauscht: \(oldId) → \(q.id)", at: now)
            if s.phase == .frage {
                // Restart without booking.
                s.minigame = nil
                startQuestion(&s, now: now)
            }
        case .regalSwap(let index, let frageId):
            guard swappableRange(s).contains(index) else { return }
            let oldId = s.currentQuestionIds[index]
            let fresh = frageId.map { manualQuestion(s, $0) } ?? replacementQuestion(&s, for: catalog.question(oldId))
            guard let q = fresh else { s.addLog("gm", "Kein passender Ersatz für \(oldId)", at: now); return }
            swapUpcoming(&s, index, q)
            s.addLog("gm", "Regal: Frage \(index + 1) getauscht (\(oldId) → \(q.id))", at: now)
        case .questionBan(let id):
            guard catalog.question(id) != nil else { return }
            if !s.settings.fragenAus.contains(id) { s.settings.fragenAus.append(id) }
            let swapped = refreshUpcoming(&s)
            s.addLog("gm", "Frage gesperrt: \(id)" + (swapped > 0 ? " (aus dem Regal getauscht)" : ""), at: now)
        case .questionUnban(let id):
            s.settings.fragenAus.removeAll { $0 == id }
            s.addLog("gm", "Frage entsperrt: \(id)", at: now)
        }
    }

    // MARK: GM question tools (shelf, replacement, filter refresh)

    /// Does the current section run a round-based format (holds all its questions at once)?
    func sectionRoundBased(_ s: EngineState) -> Bool {
        if let box = s.minigame { return box.roundBased }
        return s.currentSection.map { resolvedPlugin(s, $0).meta.roundBased } ?? false
    }

    /// First shelf index that has not been asked yet.
    func regalStart(_ s: EngineState) -> Int {
        s.phase == .erklaerkarte ? s.questionIndex : s.questionIndex + 1
    }

    /// Shelf indices the GM may still swap (a running round format already holds its questions).
    func swappableRange(_ s: EngineState) -> Range<Int> {
        guard [.erklaerkarte, .frage, .aufloesung].contains(s.phase), let section = s.currentSection else { return 0..<0 }
        let roundBased = sectionRoundBased(s)
        if roundBased && s.phase != .erklaerkarte { return 0..<0 }
        let start = regalStart(s)
        let end = roundBased ? s.currentQuestionIds.count : min(s.currentQuestionIds.count, section.fragen + s.encoresThisRound)
        return start..<max(start, end)
    }

    /// A GM-chosen question: must exist, be unused, kid-safe when required and fit the format.
    func manualQuestion(_ s: EngineState, _ id: String) -> Question? {
        guard let q = catalog.question(id), !s.usedQuestionIds.contains(id), let section = s.currentSection else { return nil }
        if (s.settings.familienModus || s.players.contains { $0.kind }) && !q.isKidSafe { return nil }
        let types = contentTypes(s, section)
        if !types.isEmpty && !types.contains(q.typ) { return nil }
        return q
    }

    /// A fitting replacement: same tier and type first, inside the voted category, then
    /// the pool, then any type the format takes — always inside pool + filter.
    func replacementQuestion(_ s: inout EngineState, for old: Question?) -> Question? {
        guard let section = s.currentSection else { return nil }
        let pool = s.settings.kategorienPool
        let filter = s.settings.questionFilter
        let formatTypes = contentTypes(s, section)
        let ownTypes = old.map { [$0.typ] } ?? formatTypes
        let tiers = filter.tiers(old.map { [$0.schw] } ?? section.schwierigkeiten)
        let ladder: [([String], [Difficulty], [QuestionType])] = [
            (section.kategorie.map { [$0] } ?? pool, tiers, ownTypes),
            (pool, tiers, ownTypes),
            (pool, tiers, formatTypes),
            (pool, filter.tiers(section.schwierigkeiten), formatTypes),
            (pool, [], formatTypes),
        ]
        for (kats, schw, types) in ladder {
            let opts = pickOptions(s, anzahl: 1, kategorien: kats, schwierigkeiten: schw, typen: types)
            if let q = catalog.pick(opts, rng: &s.rng).first { return q }
        }
        return nil
    }

    func swapUpcoming(_ s: inout EngineState, _ index: Int, _ q: Question) {
        let oldId = s.currentQuestionIds[index]
        s.usedQuestionIds.removeAll { $0 == oldId }
        s.currentQuestionIds[index] = q.id
        s.usedQuestionIds.append(q.id)
    }

    /// Swap every upcoming shelf question the filter no longer allows. Returns the swap count.
    @discardableResult
    func refreshUpcoming(_ s: inout EngineState) -> Int {
        let filter = s.settings.questionFilter
        var swapped = 0
        for i in swappableRange(s) {
            guard let q = catalog.question(s.currentQuestionIds[i]), !filter.allows(q), let fresh = replacementQuestion(&s, for: q) else { continue }
            swapUpcoming(&s, i, fresh)
            swapped += 1
        }
        return swapped
    }

    /// Universal "Weiter" for every phase (stage in gmLos mode, GM always).
    func flowNext(_ s: inout EngineState, now: Millis) {
        if s.paused { resume(&s, now: now); return }
        switch s.phase {
        case .lobby:
            if s.settings.spielModus == .quiz { startMatch(&s, now: now) }
        case .intro:
            s.openingSkipped = true
            startNextSection(&s, now: now)
        case .kategorieWahl:
            closeKategorie(&s, now: now)
        case .erklaerkarte:
            startQuestion(&s, now: now)
        case .frage:
            guard let box = s.minigame, let plugin = MinigameRegistry.plugin(box.id) else { return }
            var b = box
            var ctx = context(s, now: now)
            plugin.gm(&b.data, .forceFinish, &ctx)
            s.rng = ctx.rng
            s.minigame = b
            bookQuestion(&s, plugin: plugin, box: b, now: now)
        case .aufloesung:
            afterAufloesung(&s, now: now)
        case .zwischenstand:
            afterZwischenstand(&s, now: now)
        case .rad:
            s.phaseEndsAt = now
        case .halbzeit:
            s.halbzeitGemacht = true
            startNextSection(&s, now: now)
        case .highlights:
            enterSiegerehrung(&s, now: now)
        case .siegerehrung:
            enterEnde(&s, now: now)
        case .ende:
            revanche(&s, now: now)
        case .pause:
            resume(&s, now: now)
        case .brettspiel:
            Boardgames.next(&s, catalog: catalog, now: now)
        }
    }
}
