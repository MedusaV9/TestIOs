import Foundation

extension Engine {
    /// Enter the wheel phase and spin (weights, pity timer, fair-finale pool).
    func enterRad(_ s: inout EngineState, now: Millis, rig: WheelSegmentId?) {
        let nextSection = s.sectionIndex + 1 < s.plan.count ? s.plan[s.sectionIndex + 1] : nil
        let nextIsMc = nextSection.map { resolvedPlugin(s, $0).meta.isMc } ?? false
        let ctx = Wheel.Context(fairFinale: s.fairFinaleWindow, nextIsMcQuestion: nextIsMc, lastSegment: s.rad.lastSegment,
                                spinsWithoutGold: s.rad.spinsWithoutGold, playerCount: s.players.count, alkoholEdition: s.settings.alkoholEdition,
                                anyoneBelow200: s.players.contains { $0.balance < 200 })
        let spin = Wheel.spin(ctx, rng: &s.rng, rigged: rig ?? s.rad.rigTarget)
        s.rad.face = spin.face.map { $0.id }
        s.rad.resultIndex = spin.resultIndex
        s.rad.subphase = "dreht"
        s.rad.spinStartedAt = now
        s.rad.spinDurationMs = s.settings.kurzeShow ? Dur.radDrehKurz : Dur.radDreh
        s.rad.votes = [:]
        s.rad.rigTarget = nil
        s.rad.spinsTotal += 1
        s.questionsSinceWheel = 0
        enter(&s, .rad, duration: nil, now: now)
        s.phaseEndsAt = now + s.rad.spinDurationMs
        s.addLog("rad", "Glücksrad dreht", at: now, data: rig.map { ["rig": .string($0.rawValue)] } ?? [:])
    }

    var radResult: (EngineState) -> WheelSegment? {
        { s in
            guard let i = s.rad.resultIndex, i < s.rad.face.count else { return nil }
            return Wheel.segment(s.rad.face[i])
        }
    }

    func tickRad(_ s: inout EngineState, now: Millis) {
        guard let end = s.phaseEndsAt, now >= end else { return }
        switch s.rad.subphase {
        case "dreht":
            guard let seg = radResult(s) else { startNextSection(&s, now: now); return }
            s.rad.lastSegment = seg.id
            s.rad.spinsWithoutGold = seg.klasse == .gold ? 0 : s.rad.spinsWithoutGold + 1
            applyWheelResult(&s, seg, now: now)
            s.rad.subphase = "erklaert"
            s.phaseEndsAt = now + s.settings.ms(Dur.radErklaert)
        case "erklaert":
            guard let seg = radResult(s) else { startNextSection(&s, now: now); return }
            if let interaction = seg.interaktion {
                s.rad.subphase = "interaktion"
                s.rad.interactionEndsAt = now + s.settings.ms(seg.interaktionMs)
                s.phaseEndsAt = s.rad.interactionEndsAt
                _ = interaction
            } else {
                s.rad.subphase = "fertig"
                s.phaseEndsAt = now + 1500
            }
        case "interaktion":
            guard let seg = radResult(s) else { startNextSection(&s, now: now); return }
            resolveInteraction(&s, seg, now: now)
            s.rad.subphase = "fertig"
            s.phaseEndsAt = now + 2500
        default:
            s.rad.subphase = "idle"
            startNextSection(&s, now: now)
        }
    }

    /// Interaction closes early once everyone voted.
    func checkInteractionEarlyClose(_ s: inout EngineState, now: Millis) {
        guard s.phase == .rad, s.rad.subphase == "interaktion", let seg = radResult(s) else { return }
        let needed: [PlayerId]
        switch seg.interaktion {
        case .kompliment: needed = s.connectedPlayers.map { $0.id }
        case .shot: needed = [slowestCorrect(s)].compactMap { $0 }
        default: needed = s.connectedPlayers.map { $0.id }
        }
        if !needed.isEmpty, needed.allSatisfy({ s.rad.votes[$0] != nil }) { s.phaseEndsAt = now }
    }

    func slowestCorrect(_ s: EngineState) -> PlayerId? {
        s.lastKorrekt.filter { $0.value }.keys.max { a, b in (s.player(a)?.stats.summeAntwortMs ?? 0) < (s.player(b)?.stats.summeAntwortMs ?? 0) }
    }

    func applyWheelResult(_ s: inout EngineState, _ seg: WheelSegment, now: Millis) {
        s.addMoment("rad", "\(seg.emoji) \(seg.name): \(seg.wirkung)", at: now)
        switch seg.id {
        case .doppelterZaster: s.nextMods.gewinnFaktor = 2
        case .halbeMiete: s.nextMods.timerFaktor = 0.5
        case .bananaBailout:
            let r = s.ranking
            guard r.count >= 2, let i = s.index(of: r[r.count - 1].id) else { return }
            let gap = r[r.count - 2].balance - r[r.count - 1].balance
            let bonus = Economy.roundTo50(Int(Double(max(0, gap)) * Economy.bailoutGapShare))
            s.players[i].balance += bonus
            s.players[i].jokers[JokerId.bananenSplit.rawValue, default: 0] += 1
            s.addMoment("bailout", "🪂 Banana Bailout: \(s.players[i].name) +\(Money.format(bonus)) + 1 Bananen-Split", player: s.players[i].id, betrag: bonus, at: now)
        case .dividende: s.roundMods.dividende = true
        case .insiderTipp: s.nextMods.insiderId = s.rng.pick(s.connectedPlayers.map { $0.id })
        case .inflation: s.roundMods.inflation = true
        case .affentheater: s.nextMods.geraeteMischung = true
        case .boersenRoulette: break // interaction
        case .umarmungsBonus: break // interaction
        case .steuerpruefung: s.nextMods.steuerpruefung = true
        case .blackout: s.nextMods.blackout = true
        case .tauschBoerse:
            // Swap balances with the seat neighbour (join order pairs).
            let ordered = s.players.sorted { $0.joinOrder < $1.joinOrder }.map { $0.id }
            var i = 0
            while i + 1 < ordered.count {
                if let a = s.index(of: ordered[i]), let b = s.index(of: ordered[i + 1]) {
                    let tmp = s.players[a].balance
                    s.players[a].balance = s.players[b].balance
                    s.players[b].balance = tmp
                }
                i += 2
            }
            s.addMoment("tausch", "🔁 Tausch-Börse: Sitznachbarn haben die Konten getauscht!", at: now)
        case .affeWuerfelt: s.nextMods.affeWuerfelt = true
        case .komplimentKonto:
            let ids = s.rng.shuffled(s.connectedPlayers.map { $0.id })
            s.rad.komplimentA = ids.first
            s.rad.komplimentB = ids.count > 1 ? ids[1] : nil
            if let a = s.rad.komplimentA, let b = s.rad.komplimentB {
                s.addMoment("kompliment", "💬 \(s.player(a)?.name ?? "") macht \(s.player(b)?.name ?? "") ein ernstes Kompliment — die Gruppe stimmt ab!", at: now)
            }
        case .shotOderSchotter: break
        }
    }

    func resolveInteraction(_ s: inout EngineState, _ seg: WheelSegment, now: Millis) {
        switch seg.id {
        case .boersenRoulette:
            for p in s.players { s.nextMods.boersenRoulette[p.id] = s.rad.votes[p.id] ?? "short" }
        case .umarmungsBonus:
            let hugged = s.rad.votes.filter { $0.value == "umarmt" }.map { $0.key }
            if hugged.count >= 2 {
                for h in hugged { if let i = s.index(of: h) { s.players[i].balance += 50 } }
                s.addMoment("umarmung", "🤗 \(hugged.count) Affen umarmt — je +50 MM!", at: now)
            }
        case .komplimentKonto:
            guard let a = s.rad.komplimentA, let b = s.rad.komplimentB else { return }
            let ja = s.rad.votes.values.filter { $0 == "ja" }.count
            let nein = s.rad.votes.values.filter { $0 == "nein" }.count
            if ja >= nein, ja > 0 {
                for id in [a, b] { if let i = s.index(of: id) { s.players[i].balance += 50 } }
                s.addMoment("kompliment", "💬 Kompliment angenommen — beide +50 MM", at: now)
            } else if let ia = s.index(of: a), let ib = s.index(of: b) {
                s.players[ia].balance -= 50
                s.players[ib].balance += 50
                s.addMoment("kompliment", "💬 Verweigert — \(s.players[ib].name) bekommt 50 MM von \(s.players[ia].name)", at: now)
            }
        case .shotOderSchotter:
            guard let p = slowestCorrect(s), let i = s.index(of: p) else { return }
            if s.rad.votes[p] == "shot" {
                s.players[i].balance += 50
                s.addMoment("shot", "🥃 \(s.players[i].name) nimmt den Shot: +50 MM Mut-Prämie", player: p, betrag: 50, at: now)
            } else {
                s.players[i].balance -= 100
                s.jackpotGlas += 100
                s.addMoment("shot", "🥃 \(s.players[i].name) zahlt 100 MM Feigheits-Steuer ins Glas", player: p, betrag: -100, at: now)
            }
        default: break
        }
    }

    func wheelView(_ s: EngineState) -> WheelView {
        let seg = radResult(s)
        var betroffene: [PlayerId] = []
        if let seg = seg {
            switch seg.id {
            case .bananaBailout: betroffene = [s.last?.id].compactMap { $0 }
            case .steuerpruefung: betroffene = [s.leader?.id].compactMap { $0 }
            case .komplimentKonto: betroffene = [s.rad.komplimentA, s.rad.komplimentB].compactMap { $0 }
            case .insiderTipp: betroffene = []
            default: break
            }
        }
        // The result travels with the view from the first frame: the stage needs it
        // to run the light chase (and its ticks) deterministically into the segment.
        return WheelView(face: s.rad.face.map { Wheel.segment($0) }, resultIndex: s.rad.resultIndex, subphase: s.rad.subphase,
                         spinStartedAt: s.rad.spinStartedAt, spinDurationMs: s.rad.spinDurationMs, erklaerung: s.rad.subphase == "dreht" ? nil : seg?.wirkung,
                         betroffene: betroffene, interactionEndsAt: s.rad.interactionEndsAt)
    }

    /// Phone prompt during the wheel.
    func wheelPrompt(_ s: EngineState, player: PlayerId) -> PlayerPrompt {
        guard let seg = radResult(s) else { return .idle(title: "🎡 Das Rad dreht …", subtitle: "Alle Augen auf den Bildschirm!") }
        switch s.rad.subphase {
        case "dreht": return .idle(title: "🎡 Das Rad dreht …", subtitle: "Alle Augen auf den Bildschirm!")
        case "erklaert": return .idle(title: "\(seg.emoji) \(seg.name)", subtitle: seg.wirkung)
        case "interaktion":
            switch seg.interaktion {
            case .longShort: return .binary(title: "📊 Börsen-Roulette", subtitle: "Long = mehr Gewinn, mehr Risiko", a: "long", b: "short", chosen: s.rad.votes[player], deadline: s.rad.interactionEndsAt)
            case .umarmt: return .confirm(title: "🤗 Umarmungs-Bonus", subtitle: "Real umarmen, dann drücken!", button: "Umarmt!", done: s.rad.votes[player] != nil, deadline: s.rad.interactionEndsAt)
            case .kompliment:
                if player == s.rad.komplimentA { return .idle(title: "💬 Du bist dran!", subtitle: "Mach \(s.player(s.rad.komplimentB ?? "")?.name ?? "") ein ernstes Kompliment") }
                return .binary(title: "💬 War das ein ernstes Kompliment?", subtitle: nil, a: "ja", b: "nein", chosen: s.rad.votes[player], deadline: s.rad.interactionEndsAt)
            case .shot:
                if player == slowestCorrect(s) { return .binary(title: "🥃 Shot oder Schotter?", subtitle: "Shot +50 MM · Schotter −100 MM", a: "shot", b: "schotter", chosen: s.rad.votes[player], deadline: s.rad.interactionEndsAt) }
                return .idle(title: "🥃 Shot oder Schotter", subtitle: "\(s.player(slowestCorrect(s) ?? "")?.name ?? "Jemand") entscheidet …")
            case .none: return .idle(title: seg.name, subtitle: seg.wirkung)
            }
        default: return .idle(title: "\(seg.emoji) \(seg.name)", subtitle: "Weiter geht's!")
        }
    }
}
