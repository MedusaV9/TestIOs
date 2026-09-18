import Foundation

/// Match plan: the mode blueprint under the settings, resolved into sections
/// (rounds + optional jackpot beat + finale) with slot dramaturgy.
public enum Plan {
    /// What the catalogue can feed this match under its settings (pool, family mode).
    public static func availability(settings: MatchSettings, playerCount: Int, catalog: ContentCatalog) -> MinigameRegistry.Availability {
        var counts = catalog.typeCounts(pool: settings.kategorienPool, kidSafe: settings.familienModus)
        if counts.isEmpty { counts = [.choice: 0] } // known-but-empty pool: everything falls back
        return MinigameRegistry.Availability(playerCount: playerCount, songsAvailable: catalog.songs.count,
                                             videoSongs: catalog.songs.filter { $0.hatVideo }.count, v2: settings.v2Formate, typeCounts: counts)
    }

    public static func build(settings: MatchSettings, playerCount: Int, catalog: ContentCatalog) -> [Section] {
        build(settings: settings, playerCount: playerCount, availability: availability(settings: settings, playerCount: playerCount, catalog: catalog))
    }

    /// Legacy entry (tests): songs only, no question-type gating.
    public static func build(settings: MatchSettings, playerCount: Int, songs: [Song]) -> [Section] {
        build(settings: settings, playerCount: playerCount,
              availability: MinigameRegistry.Availability(playerCount: playerCount, songsAvailable: songs.count, videoSongs: songs.filter { $0.hatVideo }.count, v2: settings.v2Formate))
    }

    public static func build(settings: MatchSettings, playerCount: Int, availability: MinigameRegistry.Availability) -> [Section] {
        let bp = Blueprints.blueprint(for: settings.modus)
        let rounds = Blueprints.rounds(for: settings)
        var sections: [Section] = []
        for (i, r) in rounds.enumerated() {
            let plugin = MinigameRegistry.resolve(r.minigameId, availability)
            // Song formats never need a category vote.
            var wahl = r.kategorieWahl
            if case .songs = plugin.meta.contentKind { wahl = .keine }
            if case .none = plugin.meta.contentKind { wahl = .keine }
            if settings.kategorienWahl == "aus" { wahl = .keine }
            let notariat = settings.specialRules.contains(.notariatsRunde) && i == max(1, rounds.count / 2)
            sections.append(Section(typ: .runde, slot: r.slot, minigameId: plugin.meta.id, fragen: r.fragen, schwierigkeiten: r.schwierigkeiten,
                                    kategorieWahl: wahl, radDanach: r.radDanach && settings.radAn, rundenNummer: i + 1, kategorie: nil, notariat: notariat))
        }
        // Jackpot beat directly before the RISIKO round (not in Quick).
        if bp.jackpotFrage, let risikoIdx = sections.lastIndex(where: { $0.slot == .risiko }) {
            let jackpot = Section(typ: .jackpot, slot: .risiko, minigameId: "vier-lianen", fragen: 1, schwierigkeiten: [.hard, .ultrahard],
                                  kategorieWahl: .keine, radDanach: false, rundenNummer: sections[risikoIdx].rundenNummer, kategorie: nil, notariat: false)
            sections.insert(jackpot, at: risikoIdx)
        }
        let finaleId = settings.specialRules.contains(.vabanqueFinale) ? "alles-oder-banane" : "lianen-finale"
        sections.append(Section(typ: .finale, slot: .finale, minigameId: finaleId, fragen: bp.finaleFragen, schwierigkeiten: [.medium, .hard],
                                kategorieWahl: .keine, radDanach: false, rundenNummer: rounds.count + 1, kategorie: nil, notariat: false))
        return sections
    }

    /// Rough duration estimate in minutes (for the mode picker).
    public static func estimateMinutes(settings: MatchSettings) -> Int {
        let rounds = Blueprints.rounds(for: settings)
        let questions = rounds.reduce(0) { $0 + $1.fragen } + Blueprints.blueprint(for: settings.modus).finaleFragen
        let perQuestion = 45.0 * settings.tempoFactor
        let overhead = Double(rounds.count) * 40 * settings.tempoFactor + 120
        return Int((Double(questions) * perQuestion + overhead) / 60)
    }
}

/// Team mode "Affenbanden" — fixed pairs (or four camps) with a strength snake draft.
public enum Teams {
    static let names = ["Bananen-Barone", "Krypto-Kapuziner", "Goldene Gibbons", "Dschungel-Dukaten", "Schimpansen-Sparkasse", "Makaken-Millionäre"]
    static let colors = ["gelb", "lila", "gruen", "blau", "orange", "pink"]

    public static func assign(_ s: inout EngineState) {
        s.teams = []
        for i in s.players.indices { s.players[i].teamId = nil }
        guard s.settings.teams != .aus, s.players.count >= 4 else { return }
        let teamCount = s.settings.teams == .vierLager ? 4 : s.players.count / 2
        guard teamCount >= 2 else { return }
        // Snake draft by current balance (equal at start → join order) keeps teams even.
        let ranked = s.players.sorted { $0.balance != $1.balance ? $0.balance > $1.balance : $0.joinOrder < $1.joinOrder }
        var teams: [Team] = (0..<teamCount).map { Team(id: "team\($0)", name: names[$0 % names.count], farbe: colors[$0 % colors.count], mitglieder: [], topf: 0) }
        var idx = 0
        var dir = 1
        for p in ranked {
            teams[idx].mitglieder.append(p.id)
            if let i = s.index(of: p.id) { s.players[i].teamId = teams[idx].id }
            idx += dir
            if idx == teamCount { idx = teamCount - 1; dir = -1 } else if idx < 0 { idx = 0; dir = 1 }
        }
        s.teams = teams
    }

    public static func totals(_ s: EngineState) -> [String: Int] {
        var t: [String: Int] = [:]
        for team in s.teams { t[team.id] = team.mitglieder.reduce(0) { $0 + (s.player($1)?.balance ?? 0) } }
        return t
    }
}

/// Replay highlights shown before the ceremony.
public enum Highlights {
    public static func build(_ s: EngineState) -> [HighlightEntry] {
        var out: [HighlightEntry] = []
        if let fastest = s.players.compactMap({ p in p.stats.schnellsteMs.map { (p, $0) } }).min(by: { $0.1 < $1.1 }) {
            out.append(HighlightEntry(text: "Schnellste Antwort: \(fastest.0.name) in \(String(format: "%.1f", Double(fastest.1) / 1000)) s", emoji: "⚡", playerId: fastest.0.id))
        }
        if let streak = s.players.max(by: { $0.stats.laengsteSerie < $1.stats.laengsteSerie }), streak.stats.laengsteSerie >= 3 {
            out.append(HighlightEntry(text: "Längste Serie: \(streak.name) mit \(streak.stats.laengsteSerie) richtigen in Folge", emoji: "🔥", playerId: streak.id))
        }
        if let big = s.players.max(by: { $0.stats.groessterGewinn < $1.stats.groessterGewinn }), big.stats.groessterGewinn >= 500 {
            out.append(HighlightEntry(text: "Größter Einzelgewinn: \(big.name) kassierte \(Money.format(big.stats.groessterGewinn))", emoji: "💸", playerId: big.id))
        }
        if let thief = s.players.max(by: { $0.stats.gestohlen < $1.stats.gestohlen }), thief.stats.gestohlen > 0 {
            out.append(HighlightEntry(text: "Meistergauner: \(thief.name) klaute \(Money.format(thief.stats.gestohlen))", emoji: "🦝", playerId: thief.id))
        }
        if let comeback = s.players.first(where: { p in (p.stats.platzVorFinale ?? 1) > 1 && s.place(of: p.id) == 1 }) {
            out.append(HighlightEntry(text: "Comeback: \(comeback.name) kam von Platz \(comeback.stats.platzVorFinale ?? 0) zum Sieg", emoji: "🚀", playerId: comeback.id))
        }
        if let matsch = s.players.first(where: { $0.matsch }) {
            out.append(HighlightEntry(text: "Matsch-Affe des Abends: \(matsch.name)", emoji: "💩", playerId: matsch.id))
        }
        if out.isEmpty { out.append(HighlightEntry(text: "Ein Abend voller Bananen — danke fürs Spielen!", emoji: "🍌", playerId: nil)) }
        return out
    }
}

/// Awards (3 podiums + fun stats) for the ceremony (§1.1).
public enum Awards {
    public static func compute(_ s: EngineState) -> [Award] {
        var awards: [Award] = []
        let players = s.players
        guard !players.isEmpty else { return [] }
        func quote(_ p: Player) -> Double {
            let total = p.stats.richtig + p.stats.falsch
            return total == 0 ? 0 : Double(p.stats.richtig) / Double(total)
        }
        if let brain = players.max(by: { a, b in a.stats.richtig != b.stats.richtig ? a.stats.richtig < b.stats.richtig : quote(a) < quote(b) }), brain.stats.richtig > 0 {
            awards.append(Award(titel: "Quiz-Hirn", emoji: "🧠", playerId: brain.id, detail: "\(brain.stats.richtig)× richtig"))
        }
        if let quiet = players.filter({ $0.stats.bestohlen == 0 && $0.stats.gestohlen == 0 }).max(by: { quote($0) < quote($1) }), quote(quiet) > 0, players.count >= 3 {
            awards.append(Award(titel: "Stiller Star", emoji: "🌟", playerId: quiet.id, detail: "\(Int(quote(quiet) * 100)) % Quote, kein Klau"))
        }
        if let fast = players.compactMap({ p in p.stats.schnellsteMs.map { (p, $0) } }).min(by: { $0.1 < $1.1 }) {
            awards.append(Award(titel: "Blitz-Buzzer", emoji: "⚡", playerId: fast.0.id, detail: "\(String(format: "%.1f", Double(fast.1) / 1000)) s"))
        }
        if let comeback = players.first(where: { p in (p.stats.platzVorFinale ?? 1) > 1 && s.place(of: p.id) == 1 }) {
            awards.append(Award(titel: "Comeback des Abends", emoji: "🚀", playerId: comeback.id, detail: "Rückenwind genutzt"))
        }
        if let gambler = players.max(by: { ($0.stats.wettenGewonnen + $0.stats.wettenVerloren) < ($1.stats.wettenGewonnen + $1.stats.wettenVerloren) }), gambler.stats.wettenGewonnen + gambler.stats.wettenVerloren > 0 {
            awards.append(Award(titel: "Zocker-Affe", emoji: "🎰", playerId: gambler.id, detail: "\(gambler.stats.wettenGewonnen) Wetten gewonnen"))
        }
        if let joker = players.max(by: { $0.stats.jokerGenutzt < $1.stats.jokerGenutzt }), joker.stats.jokerGenutzt > 0 {
            awards.append(Award(titel: "Joker-König", emoji: "🃏", playerId: joker.id, detail: "\(joker.stats.jokerGenutzt) Joker gezündet"))
        }
        return Array(awards.prefix(4))
    }
}
