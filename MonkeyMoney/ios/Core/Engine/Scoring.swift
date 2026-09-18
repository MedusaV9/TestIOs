import Foundation

/// The booking pipeline (GAME-DESIGN §3): plugin deltas → streak → jokers/wheel
/// multipliers → Rückenwind with overtaking cap → penalties into the jar →
/// overdraft/finale clamps → post-question effects (inflation, Steuerprüfung,
/// Pleitegeier, Affe würfelt, Applaus-Almosen). Returns the booked deltas.
public enum Scoring {
    @discardableResult
    static func book(_ s: inout EngineState, catalog: ContentCatalog, plugin: AnyMinigame, scores: [PlayerId: Int], outcomes: [PlayerId: Outcome], now: Millis) -> [PlayerId: Int] {
        let isFinale = s.isFinale
        let isJackpot = s.isJackpot
        let leaderBefore = s.leader
        let ranking = s.ranking
        var deltas: [PlayerId: Int] = [:]
        var korrekt: [PlayerId: Bool] = [:]
        let wrongOnes = outcomes.filter { $0.value.correct == false }.map { $0.key }
        let answered = outcomes.filter { $0.value.correct != nil }.count
        var jackpotWon = false
        let currentQuestion = s.currentQuestionIds.indices.contains(s.questionIndex) ? catalog.question(s.currentQuestionIds[s.questionIndex]) : nil

        for i in s.players.indices {
            let id = s.players[i].id
            var delta = scores[id] ?? 0
            var alms = 0
            let o = outcomes[id] ?? Outcome(correct: nil)
            var p = s.players[i]

            // Jackpot question: twice the question value + the jar for the correct ones.
            if isJackpot, o.correct == true, delta > 0 {
                delta = Economy.jackpotQuestionValue(currentQuestion?.schw ?? .hard)
                jackpotWon = true
            }

            if o.correct == true {
                korrekt[id] = true
                p.stats.richtig += 1
                if let ms = o.answeredAfterMs {
                    p.stats.schnellsteMs = min(p.stats.schnellsteMs ?? Int.max, max(1, ms))
                    p.stats.summeAntwortMs += ms
                    p.stats.antwortenMitZeit += 1
                }
                if plugin.meta.streak && o.countsForStreak {
                    p.streak += 1
                    p.stats.laengsteSerie = max(p.stats.laengsteSerie, p.streak)
                    if !isFinale, delta > 0 { delta = Economy.roundTo10(Int(Double(delta) * Economy.streakFactor(p.streak))) }
                }
                p.wrongStreak = 0
                if currentQuestion?.schw == .ultrahard { p.stats.ultrahardRichtig += 1 }
            } else if o.correct == false {
                korrekt[id] = false
                p.stats.falsch += 1
                if o.countsForStreak { p.streak = 0 }
                p.wrongStreak += 1
                // Applaus-Almosen (§3.4): the only wrong one among answering players —
                // deliberately half a note, added after the multipliers below.
                if wrongOnes.count == 1, answered >= 2, !isFinale, delta == 0 { alms = Economy.applauseAlms }
            } else {
                if o.countsForStreak, p.connected, plugin.meta.streak { p.streak = 0 }
                p.stats.keineAntwort += 1
            }

            // Multipliers on wins (not in the finale — the formula must hold exactly).
            if delta > 0, !isFinale {
                var factor = s.nextMods.gewinnFaktor
                if s.nextMods.goldeneBanane.contains(id) { factor *= 2 }
                if s.nextMods.boostX2.contains(id) { factor *= 2 }
                if let roulette = s.nextMods.boersenRoulette[id] {
                    factor *= roulette == "long" ? 2.5 : 1.5
                }
                delta = Economy.roundTo10(Int(Double(delta) * factor))
                if s.roundMods.dividende { delta += Economy.roundTo10(Int(Double(max(0, p.balance)) * 0.05)) }
                if Economy.isDepositMode(balance: p.balance) { delta = Economy.roundTo10(Int(Double(delta) * Economy.depositModeFactor)) }
                // Rückenwind with overtaking cap (§3.4).
                if let leader = leaderBefore, leader.id != id {
                    let f = Economy.tailwindFactor(own: p.balance, leader: leader.balance)
                    if f > 1 {
                        let extra = Economy.roundTo10(Int(Double(delta) * (f - 1)))
                        let ahead = ranking.last(where: { $0.balance > p.balance })?.balance ?? leader.balance
                        let capped = Economy.capTailwindExtra(extra: extra, afterBase: p.balance + delta, playerAhead: ahead)
                        delta += capped
                        if !p.rueckenwindAngesagt, capped > 0 {
                            p.rueckenwindAngesagt = true
                            s.addMoment("rueckenwind", "🌬️ Rückenwind für \(p.name)! ×\(String(format: "%.2g", f))", player: id, at: now)
                        }
                    }
                }
            } else if delta < 0 {
                if s.nextMods.goldeneBanane.contains(id), !isFinale { delta *= 2 }
                if let roulette = s.nextMods.boersenRoulette[id], o.correct == false {
                    delta = roulette == "long" ? -100 : 0
                }
                if plugin.meta.strafenInsGlas { s.jackpotGlas += -delta }
                if Economy.isDepositMode(balance: p.balance) { delta = 0 }
            } else if let roulette = s.nextMods.boersenRoulette[id], o.correct == false {
                delta = roulette == "long" ? -100 : 0
            }

            delta += alms
            if delta > 0 { p.stats.groessterGewinn = max(p.stats.groessterGewinn, delta) }
            if plugin.meta.id == "alles-oder-banane" || plugin.meta.id == "affen-auktion" {
                if delta > 0 { p.stats.wettenGewonnen += 1 } else if delta < 0 { p.stats.wettenVerloren += 1 }
            }
            if plugin.meta.id == "taschendieb" {
                if delta > 0, o.detail == "🦝 Dieb" { p.stats.gestohlen += delta }
                if delta < 0 { p.stats.bestohlen += -delta }
            }

            let minimum = isFinale ? 0 : Economy.overdraftLimit
            let newBalance = Economy.clampToOverdraft(p.balance + delta, minimum: minimum)
            delta = newBalance - p.balance
            p.balance = newBalance
            deltas[id] = delta
            s.players[i] = p
        }

        if isJackpot, jackpotWon {
            // Winners share the jar.
            let winners = korrekt.filter { $0.value }.map { $0.key }
            let share = winners.isEmpty ? 0 : Economy.roundTo10(s.jackpotGlas / winners.count)
            for w in winners { if let i = s.index(of: w) { s.players[i].balance += share; deltas[w, default: 0] += share } }
            s.addMoment("jackpot", "💰 JACKPOT GEKNACKT! \(Money.format(s.jackpotGlas)) aus dem Glas verteilt", betrag: s.jackpotGlas, at: now)
            s.jackpotGlas = 0
        }

        // Team pots mirror member balances.
        for t in s.teams.indices { s.teams[t].topf = s.teams[t].mitglieder.reduce(0) { $0 + (s.player($1)?.balance ?? 0) } }

        postQuestion(&s, plugin: plugin, korrekt: korrekt, outcomes: outcomes, leaderBefore: leaderBefore, deltas: &deltas, now: now)
        s.lastKorrekt = korrekt
        s.addLog("buchung", "Buchung \(plugin.meta.name): " + deltas.map { "\(s.player($0.key)?.name ?? $0.key) \(Money.formatDelta($0.value))" }.joined(separator: ", "), at: now)
        return deltas
    }

    static func postQuestion(_ s: inout EngineState, plugin: AnyMinigame, korrekt: [PlayerId: Bool], outcomes: [PlayerId: Outcome], leaderBefore: Player?, deltas: inout [PlayerId: Int], now: Millis) {
        guard !s.isFinale else { return }
        // Inflation: −3 % per question end (min 50).
        if s.roundMods.inflation {
            for i in s.players.indices where s.players[i].balance > 200 {
                let cut = max(50, Economy.roundTo10(Int(Double(s.players[i].balance) * 0.03)))
                s.players[i].balance -= cut
                deltas[s.players[i].id, default: 0] -= cut
            }
        }
        // Steuerprüfung: leader must be right, else pays 10 % into the winner's pot.
        if s.nextMods.steuerpruefung, let leader = leaderBefore, korrekt[leader.id] != true, let li = s.index(of: leader.id) {
            let tax = Economy.roundTo50(Int(Double(max(0, s.players[li].balance)) * 0.10))
            if tax > 0 {
                s.players[li].balance -= tax
                deltas[leader.id, default: 0] -= tax
                let winners = korrekt.filter { $0.value }.map { $0.key }
                if let w = winners.min(by: { (outcomes[$0]?.answeredAfterMs ?? Int.max) < (outcomes[$1]?.answeredAfterMs ?? Int.max) }), let wi = s.index(of: w) {
                    s.players[wi].balance += tax
                    deltas[w, default: 0] += tax
                    s.addMoment("steuer", "🧾 Steuerprüfung: \(leader.name) zahlt \(Money.format(tax)) an \(s.players[wi].name)", player: leader.id, betrag: -tax, at: now)
                } else {
                    s.jackpotGlas += tax
                    s.addMoment("steuer", "🧾 Steuerprüfung: \(leader.name) zahlt \(Money.format(tax)) ins Glas", player: leader.id, betrag: -tax, at: now)
                }
            }
        }
        // Der Affe würfelt: the bot guesses; whoever it beats pays 50 MM shame fee.
        if s.nextMods.affeWuerfelt, plugin.meta.isMc {
            let botCorrect = s.rng.chance(0.25)
            if botCorrect {
                var fee = 0
                for i in s.players.indices where korrekt[s.players[i].id] != true && s.players[i].balance >= 50 {
                    s.players[i].balance -= 50
                    deltas[s.players[i].id, default: 0] -= 50
                    fee += 50
                }
                s.jackpotGlas += fee
                if fee > 0 { s.addMoment("affe", "🎲 Der Bot-Affe lag richtig — \(Money.format(fee)) Schmach-Gebühr ins Glas!", at: now) }
            } else {
                s.addMoment("affe", "🎲 Der Bot-Affe hat sich vertippt. Glück gehabt!", at: now)
            }
        }
        // Pleitegeier (SR2): 3 wrong in a row ⇒ vulture eats 20 %.
        if s.settings.specialRules.contains(.pleitegeier) {
            for i in s.players.indices where s.players[i].wrongStreak >= 3 && s.players[i].balance > 0 {
                let bite = Economy.roundTo50(Int(Double(s.players[i].balance) * 0.2))
                s.players[i].balance -= bite
                s.players[i].wrongStreak = 0
                deltas[s.players[i].id, default: 0] -= bite
                s.addMoment("geier", "🦅 Pleitegeier frisst \(Money.format(bite)) von \(s.players[i].name)", player: s.players[i].id, betrag: -bite, at: now)
            }
        }
        // Kopfgeld (SR5): beating the long-time leader directly pays 200 from the bank.
        if s.settings.specialRules.contains(.kopfgeld), let boss = s.kopfgeld, korrekt[boss] != true {
            let hunters = korrekt.filter { $0.value && $0.key != boss }.map { $0.key }
            for h in hunters { if let i = s.index(of: h) { s.players[i].balance += 200; deltas[h, default: 0] += 200 } }
            if !hunters.isEmpty { s.addMoment("kopfgeld", "🤠 Kopfgeld kassiert: \(hunters.compactMap { s.player($0)?.name }.joined(separator: ", "))", at: now) }
        }
        // Umarmung/kompliment/rueckenwind handled elsewhere; Letzte-Chance banner at 60 %.
        if !s.letzteChanceGezeigt, Double(s.sectionIndex) / Double(max(1, s.plan.count)) >= 0.6, let last = s.last, let leader = s.leader, leader.id != last.id {
            s.letzteChanceGezeigt = true
            s.addMoment("chance", "🎯 Letzte Chance: \(last.name) braucht \(Money.format(leader.balance - last.balance)) bis zur Spitze", player: last.id, at: now)
        }
    }

    /// Effects at the end of a round (section).
    static func roundEnd(_ s: inout EngineState, section: Section, now: Millis) {
        guard section.typ == .runde else { return }
        if let leader = s.leader {
            s.fuehrungsRunden[leader.id, default: 0] += 1
            if s.settings.specialRules.contains(.kopfgeld), (s.fuehrungsRunden[leader.id] ?? 0) >= 2, s.kopfgeld != leader.id {
                s.kopfgeld = leader.id
                s.addMoment("kopfgeld", "🤠 WANTED: Kopfgeld auf \(leader.name) — 200 MM für jeden, der ihn schlägt!", player: leader.id, at: now)
            }
            if s.settings.specialRules.contains(.affensteuer), let i = s.index(of: leader.id), leader.balance > 0 {
                if let schutz = s.players[i].klauSchutzBisRunde, schutz >= section.rundenNummer {
                    s.addMoment("steuer", "🛡️ Bananentresor blockt die Affensteuer für \(leader.name)", player: leader.id, at: now)
                } else {
                    let tax = Economy.roundTo50(Int(Double(leader.balance) * 0.10))
                    s.players[i].balance -= tax
                    s.affensteuerKiste += tax
                    s.addMoment("steuer", "📦 Affensteuer: \(leader.name) zahlt \(Money.format(tax)) in die Bananenkiste", player: leader.id, betrag: -tax, at: now)
                }
            }
        }
        for i in s.players.indices { s.players[i].wrongStreak = 0 }
    }

    /// Kapitalismus-Gong (SR6), once per match: leader +10 % interest, last +20 % of the median.
    static func kapitalismusGong(_ s: inout EngineState, now: Millis) {
        guard !s.kapitalismusGongUsed, let leader = s.leader, let last = s.last, leader.id != last.id else { return }
        s.kapitalismusGongUsed = true
        let balances = s.players.map { $0.balance }.sorted()
        let median = balances[balances.count / 2]
        if let li = s.index(of: leader.id) { s.players[li].balance += Economy.roundTo50(Int(Double(max(0, leader.balance)) * 0.10)) }
        if let la = s.index(of: last.id) { s.players[la].balance += Economy.roundTo50(Int(Double(max(0, median)) * 0.20)) }
        s.addMoment("gong", "🔔 Kapitalismus-Gong! Zinsen für \(leader.name), Grundeinkommen für \(last.name)", at: now)
    }

    /// Affensteuer payout at match end: the winner of the last question takes the crate.
    static func payoutAffensteuer(_ s: inout EngineState, now: Millis) {
        guard s.affensteuerKiste > 0 else { return }
        if let w = s.lastKorrekt.filter({ $0.value }).keys.first, let i = s.index(of: w) {
            s.players[i].balance += s.affensteuerKiste
            s.addMoment("steuer", "📦 Bananenkiste: \(Money.format(s.affensteuerKiste)) für \(s.players[i].name)", player: w, betrag: s.affensteuerKiste, at: now)
        }
        s.affensteuerKiste = 0
    }
}
