import Foundation

/// The 14 monkey puppets (assets/img/monkeys) and the 8 avatar colours.
public struct Monkey: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var titel: String
    public var emoji: String
}

public enum Monkeys {
    public static let all: [Monkey] = [
        Monkey(id: "don-bananas", name: "Don Bananas", titel: "der Pate", emoji: "🎩"),
        Monkey(id: "gitti-giro", name: "Gitti Giro", titel: "die Buchhalterin", emoji: "🧮"),
        Monkey(id: "kiki-krawall", name: "Kiki Krawall", titel: "das Chaos-Äffchen", emoji: "🎉"),
        Monkey(id: "baron-von-bananenstein", name: "Baron von Bananenstein", titel: "der Adlige", emoji: "🥂"),
        Monkey(id: "oma-zinseszins", name: "Oma Zinseszins", titel: "die Sparfüchsin", emoji: "🧶"),
        Monkey(id: "pumper-paule", name: "Pumper-Paule", titel: "der Gym-Gorilla", emoji: "💪"),
        Monkey(id: "schnarch-schorsch", name: "Schnarch-Schorsch", titel: "der Gemütliche", emoji: "😴"),
        Monkey(id: "glitzer-gina", name: "Glitzer-Gina", titel: "die Diva", emoji: "✨"),
        Monkey(id: "dj-trommelfell", name: "DJ Trommelfell", titel: "der Beat-Affe", emoji: "🎧"),
        Monkey(id: "astro-astrid", name: "Astro-Astrid", titel: "die Raumfahrerin", emoji: "🚀"),
        Monkey(id: "kommissar-kokosnuss", name: "Kommissar Kokosnuss", titel: "der Detektiv", emoji: "🔍"),
        Monkey(id: "iro-ines", name: "Iro-Ines", titel: "die Punkerin", emoji: "🎸"),
        Monkey(id: "abraka-dieter", name: "Abraka-Dieter", titel: "der Zauberer", emoji: "🪄"),
        Monkey(id: "kahuna-kalle", name: "Kahuna-Kalle", titel: "der Surfer", emoji: "🏄"),
    ]

    public static func monkey(_ id: String) -> Monkey { all.first { $0.id == id } ?? all[0] }

    public static let colors: [(id: String, hex: String, name: String)] = [
        ("gelb", "#FFD34E", "Gelb"), ("rot", "#E53950", "Rot"), ("gruen", "#7ED957", "Grün"), ("blau", "#3D7BFF", "Blau"),
        ("lila", "#8E5BFF", "Lila"), ("orange", "#FF8A3D", "Orange"), ("tuerkis", "#2ED3C6", "Türkis"), ("pink", "#FF6BD6", "Pink"),
    ]

    /// Hex colour of a colour token (catalogue id or free `hexRRGGBB`).
    public static func hex(for farbe: String) -> String {
        if farbe.hasPrefix("hex"), farbe.count == 9 { return "#" + farbe.dropFirst(3).uppercased() }
        return colors.first { $0.id == farbe }?.hex ?? colors[0].hex
    }

    /// Random look for the "Los geht's!" one-tap join.
    public static func randomLook(rng: inout SeededRandom) -> Avatar {
        Avatar(affe: all[rng.below(all.count)].id, farbe: colors[rng.below(colors.count)].id)
    }
}

/// Aggregate all-time statistics (the 15 stats of §7.2, derived from matches).
public struct ProfileStats: Codable, Equatable, Sendable {
    public var matches = 0
    public var siege = 0
    public var richtig = 0
    public var falsch = 0
    public var summeAntwortMs = 0
    public var antwortenMitZeit = 0
    public var schnellsteMs: Int?
    public var hoechsterEndstand = 0
    public var laengsteSerie = 0
    public var siegesSerie = 0
    public var aktuelleSiegesSerie = 0
    public var wettenGewonnen = 0
    public var wettenVerloren = 0
    public var gestohlen = 0
    public var bestohlen = 0
    public var comebacks = 0
    public var jokerGenutzt = 0
    public var ultrahardRichtig = 0
    public var kategorieRichtig: [String: Int] = [:]
    public var kategorieGesamt: [String: Int] = [:]
    public var brettspiele = 0
    public var brettspielSiege = 0

    public init() {}

    public var quote: Double { richtig + falsch == 0 ? 0 : Double(richtig) / Double(richtig + falsch) }
    public var medianAntwortMs: Int? { antwortenMitZeit == 0 ? nil : summeAntwortMs / antwortenMitZeit }
}

/// A local profile (no account, optional 4-digit PIN, device recognition).
public struct Profile: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var pin: String?
    public var deviceTokens: [String]
    public var avatar: Avatar
    public var atGesamt: Int
    public var atAktuell: Int
    public var besitz: [String]
    public var ausgeruestet: [String: String]
    public var stats: ProfileStats
    public var gebuchteMatches: [String]
    public var erstellt: Millis
    public var zuletzt: Millis
    public var titel: String?
    public var passXp: Int
    public var passSaison: String
    public var questFortschritt: [String: Int]
    public var questErledigt: [String]
    public var meilensteine: [String]
    public var ersteMale: [String]

    public init(id: String, name: String, avatar: Avatar, now: Millis) {
        self.id = id
        self.name = name
        pin = nil
        deviceTokens = []
        self.avatar = avatar
        atGesamt = 300 // Willkommens-AT
        atAktuell = 300
        besitz = []
        ausgeruestet = [:]
        stats = ProfileStats()
        gebuchteMatches = []
        erstellt = now
        zuletzt = now
        titel = nil
        passXp = 0
        passSaison = ""
        questFortschritt = [:]
        questErledigt = []
        meilensteine = []
        ersteMale = []
    }

    public var level: Int { Level.level(forAT: atGesamt) }

    /// Wire avatar including equipped visual extras and the level badge.
    public var wireAvatar: Avatar {
        var a = avatar
        a.extras = ausgeruestet.values.filter { Shop.item($0)?.visuell == true }.sorted() + ["lv\(level)"]
        return a
    }
}

/// Bestenlisten (§7.3) with fairness thresholds.
public struct BoardEntry: Codable, Equatable, Sendable {
    public var profileId: String
    public var name: String
    public var avatar: String
    public var wert: Double
    public var anzeige: String
}

public struct Boards: Codable, Equatable, Sendable {
    public var moneyBoss: [BoardEntry]
    public var kategorieMeister: [String: [BoardEntry]]
    public var blitzBuzzer: [BoardEntry]
    public var comebackKoenig: [BoardEntry]
}

/// Daily / monthly quests (deterministic rotation, progress measured per match).
public struct Quest: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var titel: String
    public var emoji: String
    public var ziel: Int
    public var xp: Int
    public var atBonus: Int
    public var monat: Bool
}

public enum Quests {
    public static let pool: [Quest] = [
        Quest(id: "richtig5", titel: "5 richtige Antworten in einem Abend", emoji: "🧠", ziel: 5, xp: 80, atBonus: 50, monat: false),
        Quest(id: "match1", titel: "Ein Match zu Ende spielen", emoji: "🏁", ziel: 1, xp: 80, atBonus: 30, monat: false),
        Quest(id: "sieg1", titel: "Ein Match gewinnen", emoji: "👑", ziel: 1, xp: 80, atBonus: 80, monat: false),
        Quest(id: "joker2", titel: "2 Joker zünden", emoji: "🃏", ziel: 2, xp: 80, atBonus: 40, monat: false),
        Quest(id: "wette1", titel: "Eine Wette gewinnen", emoji: "🎰", ziel: 1, xp: 80, atBonus: 40, monat: false),
        Quest(id: "serie3", titel: "3 richtige in Folge", emoji: "🔥", ziel: 3, xp: 80, atBonus: 40, monat: false),
        Quest(id: "brettspiel1", titel: "Ein Brettspiel spielen", emoji: "🎲", ziel: 1, xp: 80, atBonus: 40, monat: false),
        Quest(id: "ultrahard1", titel: "Eine ULTRAHARD-Frage knacken", emoji: "💎", ziel: 1, xp: 80, atBonus: 100, monat: false),
        Quest(id: "richtig40", titel: "40 richtige Antworten im Monat", emoji: "📚", ziel: 40, xp: 400, atBonus: 300, monat: true),
        Quest(id: "matches6", titel: "6 Matches im Monat", emoji: "📅", ziel: 6, xp: 400, atBonus: 300, monat: true),
        Quest(id: "pass15", titel: "Pass-Stufe 15 erreichen", emoji: "🎫", ziel: 15, xp: 400, atBonus: 400, monat: true),
    ]

    /// Three dailies per day (deterministic rotation) + the three monthlies.
    public static func active(dayKey: Int) -> [Quest] {
        let dailies = pool.filter { !$0.monat }
        var out: [Quest] = []
        for i in 0..<3 { out.append(dailies[(dayKey * 3 + i) % dailies.count]) }
        return out + pool.filter { $0.monat }
    }

    /// Season = UTC calendar month; 30 pass steps (100/150/200 XP).
    public static func passStep(xp: Int) -> Int {
        var remaining = xp
        var step = 0
        while step < 30 {
            let cost = step < 10 ? 100 : (step < 20 ? 150 : 200)
            if remaining < cost { break }
            remaining -= cost
            step += 1
        }
        return step
    }

    public static func seasonId(for now: Millis) -> String {
        let date = Date(timeIntervalSince1970: Double(now) / 1000)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 2026, c.month ?? 1)
    }

    public static func dayKey(for now: Millis) -> Int { now / 86_400_000 }
}

/// Pure meta store: profiles, shop purchases, match booking, boards.
/// Persistence (JSON file) is done by the app; every mutation here is a plain
/// function so it can be unit-tested on Linux.
public struct MetaStore: Codable, Equatable, Sendable {
    public var profiles: [Profile]
    public var version: Int

    public init() {
        profiles = []
        version = 1
    }

    public func profile(_ id: String) -> Profile? { profiles.first { $0.id == id } }

    public mutating func create(name: String, avatar: Avatar, pin: String?, deviceToken: String?, now: Millis, rng: inout SeededRandom) -> Profile {
        let id = "prof_" + String((0..<10).map { _ in Array("abcdefghijklmnopqrstuvwxyz0123456789")[rng.below(36)] })
        var p = Profile(id: id, name: String(name.prefix(16)), avatar: avatar, now: now)
        p.pin = pin.flatMap { $0.count == 4 && Int($0) != nil ? $0 : nil }
        if let d = deviceToken { p.deviceTokens = [d] }
        profiles.append(p)
        return p
    }

    public enum LoginError: Error, Equatable { case unknown, pinRequired, pinWrong }

    /// PIN or a known device token unlocks a profile.
    public mutating func login(_ id: String, pin: String?, deviceToken: String?, now: Millis) -> Result<Profile, LoginError> {
        guard let i = profiles.firstIndex(where: { $0.id == id }) else { return .failure(.unknown) }
        let p = profiles[i]
        if let required = p.pin {
            let deviceKnown = deviceToken.map { p.deviceTokens.contains($0) } ?? false
            if !deviceKnown {
                guard let given = pin else { return .failure(.pinRequired) }
                guard given == required else { return .failure(.pinWrong) }
            }
        }
        profiles[i].zuletzt = now
        if let d = deviceToken, !profiles[i].deviceTokens.contains(d) { profiles[i].deviceTokens.append(d) }
        return .success(profiles[i])
    }

    public func profiles(forDevice token: String) -> [Profile] {
        profiles.filter { $0.deviceTokens.contains(token) }.sorted { $0.zuletzt > $1.zuletzt }
    }

    public mutating func update(_ id: String, name: String?, avatar: Avatar?, pin: String??) {
        guard let i = profiles.firstIndex(where: { $0.id == id }) else { return }
        if let n = name, !n.isEmpty { profiles[i].name = String(n.prefix(16)) }
        if let a = avatar { profiles[i].avatar = a }
        if let p = pin { profiles[i].pin = p }
    }

    public enum ShopError: Error, Equatable { case unknownItem, owned, tooExpensive, levelGate(Int), unknownProfile }

    public mutating func buy(_ profileId: String, item itemId: String) -> Result<Profile, ShopError> {
        guard let i = profiles.firstIndex(where: { $0.id == profileId }) else { return .failure(.unknownProfile) }
        guard let item = Shop.item(itemId) else { return .failure(.unknownItem) }
        guard !profiles[i].besitz.contains(itemId) else { return .failure(.owned) }
        if let lvl = item.minLevel, profiles[i].level < lvl { return .failure(.levelGate(lvl)) }
        guard profiles[i].atAktuell >= item.preis else { return .failure(.tooExpensive) }
        profiles[i].atAktuell -= item.preis
        profiles[i].besitz.append(itemId)
        profiles[i].ausgeruestet[item.slot] = itemId
        return .success(profiles[i])
    }

    public mutating func equip(_ profileId: String, item itemId: String?, slot: String) {
        guard let i = profiles.firstIndex(where: { $0.id == profileId }) else { return }
        if let id = itemId {
            guard profiles[i].besitz.contains(id), Shop.item(id)?.slot == slot else { return }
            profiles[i].ausgeruestet[slot] = id
        } else {
            profiles[i].ausgeruestet[slot] = nil
        }
    }

    /// Book a finished match for a bound profile — idempotent per match id.
    public mutating func bookMatch(_ profileId: String, player: Player, at: Int, winner: Bool, matchId: String, now: Millis) -> ProfileEvent? {
        guard let i = profiles.firstIndex(where: { $0.id == profileId }), !profiles[i].gebuchteMatches.contains(matchId) else { return nil }
        var p = profiles[i]
        let levelBefore = p.level
        var bonus = 0
        // First-time bonuses (§3.6): never a farm source.
        if winner, !p.ersteMale.contains("sieg") { p.ersteMale.append("sieg"); bonus += 500 }
        if player.stats.ultrahardRichtig > 0, !p.ersteMale.contains("ultrahard") { p.ersteMale.append("ultrahard"); bonus += 100 }
        if player.stats.wettenGewonnen > 0, !p.ersteMale.contains("wette") { p.ersteMale.append("wette"); bonus += 250 }
        p.atGesamt += at + bonus
        p.atAktuell += at + bonus
        p.gebuchteMatches.append(matchId)
        if p.gebuchteMatches.count > 200 { p.gebuchteMatches.removeFirst() }
        p.stats.matches += 1
        if winner { p.stats.siege += 1; p.stats.aktuelleSiegesSerie += 1; p.stats.siegesSerie = max(p.stats.siegesSerie, p.stats.aktuelleSiegesSerie) } else { p.stats.aktuelleSiegesSerie = 0 }
        p.stats.richtig += player.stats.richtig
        p.stats.falsch += player.stats.falsch
        p.stats.summeAntwortMs += player.stats.summeAntwortMs
        p.stats.antwortenMitZeit += player.stats.antwortenMitZeit
        if let f = player.stats.schnellsteMs { p.stats.schnellsteMs = min(p.stats.schnellsteMs ?? Int.max, f) }
        p.stats.hoechsterEndstand = max(p.stats.hoechsterEndstand, player.balance)
        p.stats.laengsteSerie = max(p.stats.laengsteSerie, player.stats.laengsteSerie)
        p.stats.wettenGewonnen += player.stats.wettenGewonnen
        p.stats.wettenVerloren += player.stats.wettenVerloren
        p.stats.gestohlen += player.stats.gestohlen
        p.stats.bestohlen += player.stats.bestohlen
        p.stats.jokerGenutzt += player.stats.jokerGenutzt
        p.stats.ultrahardRichtig += player.stats.ultrahardRichtig
        if winner, (player.stats.platzVorFinale ?? 1) > 1 { p.stats.comebacks += 1 }
        // Milestones (unbuyable).
        if p.stats.richtig >= 100, !p.meilensteine.contains("grundgelehrter") { p.meilensteine.append("grundgelehrter") }
        if winner, (player.stats.platzVorFinale ?? 1) > 1, !p.meilensteine.contains("comeback-koenig") { p.meilensteine.append("comeback-koenig") }
        // Quests & pass.
        let season = Quests.seasonId(for: now)
        if p.passSaison != season { p.passSaison = season; p.passXp = 0; p.questFortschritt = p.questFortschritt.filter { !$0.key.hasPrefix("m:") }; p.questErledigt = p.questErledigt.filter { !$0.hasPrefix("m:\(season)") } }
        var xp = 50 + (winner ? 50 : 0)
        var done: [String] = []
        let day = Quests.dayKey(for: now)
        for q in Quests.active(dayKey: day) {
            let key = q.monat ? "m:\(season):\(q.id)" : "d:\(day):\(q.id)"
            guard !p.questErledigt.contains(key) else { continue }
            var progress = 0
            switch q.id {
            case "richtig5", "richtig40": progress = player.stats.richtig
            case "match1", "matches6": progress = 1
            case "sieg1": progress = winner ? 1 : 0
            case "joker2": progress = player.stats.jokerGenutzt
            case "wette1": progress = player.stats.wettenGewonnen
            case "serie3": progress = player.stats.laengsteSerie >= 3 ? 3 : 0
            case "ultrahard1": progress = player.stats.ultrahardRichtig
            case "pass15": progress = Quests.passStep(xp: p.passXp + xp)
            default: progress = 0
            }
            p.questFortschritt[key, default: 0] += q.id == "pass15" || q.id == "serie3" ? 0 : progress
            if q.id == "pass15" || q.id == "serie3" { p.questFortschritt[key] = max(p.questFortschritt[key] ?? 0, progress) }
            if (p.questFortschritt[key] ?? 0) >= q.ziel {
                p.questErledigt.append(key)
                xp += q.xp
                p.atGesamt += q.atBonus
                p.atAktuell += q.atBonus
                done.append("\(q.emoji) \(q.titel)")
            }
        }
        p.passXp += xp
        p.zuletzt = now
        profiles[i] = p
        return ProfileEvent(profileId: profileId, atDelta: at + bonus, atGesamt: p.atGesamt, level: p.level, levelUp: p.level > levelBefore, quests: done, passXp: p.passXp)
    }

    public mutating func bookBoardgame(_ profileId: String, mm: Int, won: Bool, now: Millis) {
        guard let i = profiles.firstIndex(where: { $0.id == profileId }) else { return }
        let at = Economy.allTimeForBoardgame(mm: mm)
        profiles[i].atGesamt += at
        profiles[i].atAktuell += at
        profiles[i].stats.brettspiele += 1
        if won { profiles[i].stats.brettspielSiege += 1 }
        profiles[i].zuletzt = now
    }

    /// The four leaderboards with their fairness thresholds (§7.3).
    public func boards() -> Boards {
        func entry(_ p: Profile, _ wert: Double, _ anzeige: String) -> BoardEntry {
            BoardEntry(profileId: p.id, name: p.name, avatar: p.wireAvatar.wire, wert: wert, anzeige: anzeige)
        }
        let money = profiles.sorted { $0.atGesamt > $1.atGesamt }.prefix(10).map { entry($0, Double($0.atGesamt), "\(Money.formatNumber($0.atGesamt)) AT") }
        var kat: [String: [BoardEntry]] = [:]
        for p in profiles {
            for (k, total) in p.stats.kategorieGesamt where total >= 20 {
                let q = Double(p.stats.kategorieRichtig[k] ?? 0) / Double(total)
                kat[k, default: []].append(entry(p, q, "\(Int(q * 100)) %"))
            }
        }
        for k in kat.keys { kat[k]?.sort { $0.wert > $1.wert } }
        let blitz = profiles.filter { $0.stats.antwortenMitZeit >= 30 }.compactMap { p in p.stats.medianAntwortMs.map { entry(p, Double(-$0), String(format: "%.1f s", Double($0) / 1000)) } }.sorted { $0.wert > $1.wert }
        let comeback = profiles.filter { $0.stats.comebacks + max(0, $0.stats.matches - $0.stats.siege) >= 5 && $0.stats.matches >= 5 }.map { p in
            let rate = Double(p.stats.comebacks) / Double(max(1, p.stats.matches))
            return entry(p, rate, "\(p.stats.comebacks) Comebacks")
        }.sorted { $0.wert > $1.wert }
        return Boards(moneyBoss: Array(money), kategorieMeister: kat, blitzBuzzer: Array(blitz.prefix(10)), comebackKoenig: Array(comeback.prefix(10)))
    }

    /// Titles awarded by board positions wander automatically.
    public func autoTitle(_ profileId: String) -> String? {
        let b = boards()
        if b.moneyBoss.first?.profileId == profileId { return "💰 Money-Boss" }
        if b.blitzBuzzer.first?.profileId == profileId { return "⚡ Blitz-Buzzer" }
        if b.comebackKoenig.first?.profileId == profileId { return "🚀 Comeback-König" }
        return nil
    }
}
