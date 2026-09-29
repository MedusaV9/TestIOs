import Foundation

/// Bananopoly — party-length property classic: 28-field ring, 9 colour pairs,
/// one banana stand per property (rent ×2, full pair ×2), 16 banana cards,
/// monkey cage with 3 simplified escapes, ends after round 4 or first bankruptcy.
public enum Bananopoly: BoardgamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var sitze: [String]
        public var positions: [String: Int]
        public var cash: [String: Int]
        public var owners: [Int: String]
        public var stands: [Int]
        public var current: Int
        public var dice: [Int]?
        public var phase: String // wuerfeln | entscheiden | fertig
        public var rounds: [String: Int]
        public var inCage: [String: Int]
        public var event: String?
        public var seq: Int
        public var lastRound: Bool
        public var bankrupt: String?
        public var winner: String?
        public var turnDeadline: Millis
        public var cardIndex: Int
        public var bankFlow: Int
        public var pendingBuy: Int?
    }

    public static let meta = BoardgameMeta(
        id: "bananopoly", name: "Bananopoly", emoji: "🏘️", untertitel: "Immobilien-Klassiker in Party-Länge · 2–6 Affen",
        minSpieler: 2, maxSpieler: 6, phonesOnly: false, gemischteSitze: true,
        howto: ["Würfle, zieh über den 28er-Ring und kaufe freie Grundstücke. Landest du auf fremdem Besitz, zahlst du Miete.",
                "Ein Bananenstand pro Grundstück (kostet nochmal den Kaufpreis) verdoppelt die Miete, ein komplettes Farbpaar nochmal ×2. Bananen-Karten bringen Ereignisse, der Affenkäfig hält dich fest.",
                "Nach 4 Runden (oder bei der ersten Pleite) wird abgerechnet: Bargeld + Grundstücke + Stände = Nettovermögen."],
        varianten: [], halbePayout: false
    )

    public static let fields: [BananopolyField] = {
        let names = ["LOS", "Lianen-Kreuzung", "Bananen-Karte", "Kokos-Klippe", "Affensteuer", "REHWEI-Wasserfall", "Goobytheke", "Affenkäfig (Besuch)",
                     "Palmen-Promenade", "Bananen-Karte", "Affen-Baumarkt", "Termiten-Schreinerei", "Freier Bananentag", "Dschungel-Dampfer", "Bananen-Karte",
                     "Mango-Markt", "Kakao-Kaskade", "Ab in den Käfig", "Papageien-Plaza", "Bananen-Karte", "Gorilla-Galerie", "Liana-Lounge",
                     "Schatzhöhle", "Bananen-Karte", "Baumhaus-Boulevard", "Wolken-Wipfel", "Bananen-Steuer", "Gipfel-Penthouse"]
        var out: [BananopolyField] = []
        let prices = [0, 80, 0, 80, 0, 100, 100, 0, 140, 0, 140, 160, 0, 180, 0, 200, 200, 0, 240, 0, 240, 280, 300, 0, 320, 360, 0, 400]
        for i in 0..<28 {
            let typ: String
            switch i {
            case 0: typ = "los"
            case 7: typ = "kaefig-besuch"
            case 12: typ = "frei"
            case 17: typ = "ab-in-kaefig"
            case 4, 26: typ = "steuer"
            case 2, 9, 14, 19, 23: typ = "karte"
            default: typ = "grundstueck"
            }
            let paar: Int? = typ == "grundstueck" ? [1: 0, 3: 0, 5: 1, 6: 1, 8: 2, 10: 2, 11: 3, 13: 3, 15: 4, 16: 4, 18: 5, 20: 5, 21: 6, 22: 6, 24: 7, 25: 7, 27: 8][i] : nil
            out.append(BananopolyField(index: i, name: names[i], typ: typ, preis: prices[i], paar: paar))
        }
        return out
    }()

    static let startCash = 1200
    static let salary = 200
    static let turnMs = 25_000
    static let cards: [(String, String, Int)] = [
        ("Die Bank zahlt dir eine Dividende: +100 MM", "bank", 100), ("Bananenschale! Arztkosten: −50 MM", "bank", -50),
        ("Geburtstag! Jeder Affe schenkt dir 30 MM", "jeder", 30), ("Du verlierst eine Wette: zahle jedem 20 MM", "jeder", -20),
        ("Rücke vor bis LOS und kassiere das Gehalt", "gehe", 0), ("Ab in den Affenkäfig!", "kaefig", 0),
        ("Stand-TÜV: 40 MM pro Bananenstand", "tuev", 40), ("Der Bananen-Kurs steigt: +150 MM", "bank", 150),
        ("Strafzettel für Falschparken der Liane: −80 MM", "bank", -80), ("Rücke 3 Felder vor", "vor", 3),
        ("Gehe 3 Felder zurück", "vor", -3), ("Rücke vor zum Gipfel-Penthouse", "gehe", 27),
        ("Kokosnuss auf den Kopf: −30 MM", "bank", -30), ("Du findest einen Goldzahn: +60 MM", "bank", 60),
        ("Tausche Platz mit dem Affen vor dir", "tausch", 0), ("Freier Bananentag für dich: +50 MM", "bank", 50),
    ]

    public static func initState(ctx: inout BoardgameContext) -> State {
        var cash: [String: Int] = [:]
        var pos: [String: Int] = [:]
        var rounds: [String: Int] = [:]
        for s in ctx.sitze { cash[s] = startCash; pos[s] = 0; rounds[s] = 0 }
        return State(sitze: ctx.sitze, positions: pos, cash: cash, owners: [:], stands: [], current: 0, dice: nil, phase: "wuerfeln", rounds: rounds, inCage: [:],
                     event: "\(ctx.name(ctx.sitze[0])) beginnt!", seq: 0, lastRound: false, bankrupt: nil, winner: nil, turnDeadline: ctx.now + ctx.ms(turnMs),
                     cardIndex: ctx.rng.below(cards.count), bankFlow: 0, pendingBuy: nil)
    }

    static func seatOf(_ s: State) -> String { s.sitze[s.current % s.sitze.count] }

    static func rent(_ s: State, field: Int) -> Int {
        let f = fields[field]
        guard let owner = s.owners[field] else { return 0 }
        var r = f.preis / 4
        if s.stands.contains(field) { r *= 2 }
        if let paar = f.paar, fields.filter({ $0.paar == paar }).allSatisfy({ s.owners[$0.index] == owner }) { r *= 2 }
        return r
    }

    static func netWorth(_ s: State, _ sitz: String) -> Int {
        var w = s.cash[sitz] ?? 0
        for (f, o) in s.owners where o == sitz { w += fields[f].preis + (s.stands.contains(f) ? fields[f].preis : 0) }
        return w
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from sitz: String, ctx: inout BoardgameContext) {
        guard state.winner == nil, seatOf(state) == sitz else { return }
        switch (state.phase, action) {
        case ("wuerfeln", .button(let b)):
            if b == "wuerfeln" { rollAndMove(&state, ctx: &ctx) }
            if b == "kaution", (state.inCage[sitz] ?? 0) > 0, (state.cash[sitz] ?? 0) >= 50 { pay(&state, sitz, 50, to: nil); state.inCage[sitz] = nil; state.event = "\(ctx.name(sitz)) zahlt 50 MM Kaution"; rollAndMove(&state, ctx: &ctx) }
        case ("entscheiden", .button(let b)):
            let pos = state.positions[sitz] ?? 0
            if b == "kaufen", state.owners[pos] == nil, fields[pos].typ == "grundstueck", (state.cash[sitz] ?? 0) >= fields[pos].preis {
                pay(&state, sitz, fields[pos].preis, to: nil)
                state.owners[pos] = sitz
                state.event = "\(ctx.name(sitz)) kauft \(fields[pos].name)"
            }
            if b == "bauen", state.owners[pos] == sitz, !state.stands.contains(pos), (state.cash[sitz] ?? 0) >= fields[pos].preis {
                pay(&state, sitz, fields[pos].preis, to: nil)
                state.stands.append(pos)
                state.event = "\(ctx.name(sitz)) baut einen Bananenstand auf \(fields[pos].name)"
            }
            endTurn(&state, ctx: &ctx)
        default: break
        }
    }

    static func pay(_ s: inout State, _ from: String, _ amount: Int, to: String?) {
        s.cash[from, default: 0] -= amount
        if let t = to { s.cash[t, default: 0] += amount } else { s.bankFlow -= amount }
    }

    static func rollAndMove(_ s: inout State, ctx: inout BoardgameContext) {
        let sitz = seatOf(s)
        let d1 = ctx.rng.int(in: 1...6), d2 = ctx.rng.int(in: 1...6)
        s.dice = [d1, d2]
        s.seq += 1
        if let tries = s.inCage[sitz] {
            if d1 == d2 { s.inCage[sitz] = nil; s.event = "🔓 Pasch! \(ctx.name(sitz)) ist frei" }
            else if tries >= 2 { pay(&s, sitz, 50, to: nil); s.inCage[sitz] = nil; s.event = "\(ctx.name(sitz)) muss 50 MM Kaution zahlen" }
            else { s.inCage[sitz] = tries + 1; s.event = "\(ctx.name(sitz)) bleibt im Käfig (\(tries + 1)/3)"; endTurn(&s, ctx: &ctx); return }
        }
        advance(&s, sitz, by: d1 + d2, ctx: &ctx)
    }

    static func advance(_ s: inout State, _ sitz: String, by steps: Int, ctx: inout BoardgameContext) {
        let old = s.positions[sitz] ?? 0
        var pos = (old + steps) % 28
        if pos < 0 { pos += 28 }
        if steps > 0, old + steps >= 28 {
            s.cash[sitz, default: 0] += salary
            s.bankFlow += salary
            s.rounds[sitz, default: 0] += 1
            if (s.rounds[sitz] ?? 0) >= 4 { s.lastRound = true }
        }
        s.positions[sitz] = pos
        land(&s, sitz, ctx: &ctx, depth: 0)
    }

    static func land(_ s: inout State, _ sitz: String, ctx: inout BoardgameContext, depth: Int) {
        let pos = s.positions[sitz] ?? 0
        let f = fields[pos]
        switch f.typ {
        case "grundstueck":
            if let o = s.owners[pos], o != sitz {
                let r = rent(s, field: pos)
                pay(&s, sitz, r, to: o)
                s.event = "\(ctx.name(sitz)) zahlt \(r) MM Miete an \(ctx.name(o))"
                endTurn(&s, ctx: &ctx)
            } else {
                s.phase = "entscheiden"
                s.turnDeadline = ctx.now + ctx.ms(15_000)
                s.event = s.owners[pos] == nil ? "\(ctx.name(sitz)) landet auf \(f.name) — zu kaufen: \(f.preis) MM · Miete ab \(f.preis / 4) MM" : "\(ctx.name(sitz)) ist zu Hause auf \(f.name)"
            }
        case "steuer":
            pay(&s, sitz, 100, to: nil)
            s.event = "\(ctx.name(sitz)) zahlt 100 MM Steuer"
            endTurn(&s, ctx: &ctx)
        case "ab-in-kaefig":
            s.positions[sitz] = 7
            s.inCage[sitz] = 0
            s.event = "🔒 \(ctx.name(sitz)) wandert in den Affenkäfig!"
            endTurn(&s, ctx: &ctx)
        case "karte":
            let card = cards[s.cardIndex % cards.count]
            s.cardIndex += 1
            s.event = "🃏 \(card.0)"
            switch card.1 {
            case "bank": s.cash[sitz, default: 0] += card.2; s.bankFlow += card.2; endTurn(&s, ctx: &ctx)
            case "jeder":
                for o in s.sitze where o != sitz { pay(&s, o, card.2, to: sitz) }
                endTurn(&s, ctx: &ctx)
            case "gehe":
                if card.2 == 0 { advance(&s, sitz, by: (28 - (s.positions[sitz] ?? 0)) % 28 == 0 ? 28 : (28 - (s.positions[sitz] ?? 0)), ctx: &ctx) }
                else if depth < 2 { let cur = s.positions[sitz] ?? 0; advance(&s, sitz, by: card.2 >= cur ? card.2 - cur : 28 - cur + card.2, ctx: &ctx) } else { endTurn(&s, ctx: &ctx) }
            case "kaefig": s.positions[sitz] = 7; s.inCage[sitz] = 0; endTurn(&s, ctx: &ctx)
            case "tuev":
                let n = s.stands.filter { s.owners[$0] == sitz }.count
                pay(&s, sitz, n * card.2, to: nil)
                endTurn(&s, ctx: &ctx)
            case "vor":
                if depth < 2 { s.positions[sitz] = ((s.positions[sitz] ?? 0) + card.2 + 28) % 28; land(&s, sitz, ctx: &ctx, depth: depth + 1) } else { endTurn(&s, ctx: &ctx) }
            case "tausch":
                if let other = s.sitze.filter({ $0 != sitz }).max(by: { (s.positions[$0] ?? 0) < (s.positions[$1] ?? 0) }) {
                    let tmp = s.positions[sitz] ?? 0
                    s.positions[sitz] = s.positions[other] ?? 0
                    s.positions[other] = tmp
                }
                endTurn(&s, ctx: &ctx)
            default: endTurn(&s, ctx: &ctx)
            }
        default:
            endTurn(&s, ctx: &ctx)
        }
    }

    static func endTurn(_ s: inout State, ctx: inout BoardgameContext) {
        let sitz = seatOf(s)
        if (s.cash[sitz] ?? 0) < 0 { s.bankrupt = sitz; finish(&s, ctx: ctx); return }
        s.phase = "wuerfeln"
        s.dice = nil
        let wasLast = s.current == s.sitze.count - 1
        s.current = (s.current + 1) % s.sitze.count
        s.turnDeadline = ctx.now + ctx.ms(turnMs)
        if s.lastRound, wasLast { finish(&s, ctx: ctx) }
    }

    static func finish(_ s: inout State, ctx: BoardgameContext) {
        s.phase = "fertig"
        s.winner = s.sitze.filter { $0 != s.bankrupt }.max { netWorth(s, $0) < netWorth(s, $1) } ?? s.sitze[0]
        s.event = "🏁 Kassensturz! \(ctx.name(s.winner!)) hat das größte Vermögen."
    }

    public static func tick(_ state: inout State, ctx: inout BoardgameContext) {
        guard state.winner == nil else { return }
        let sitz = seatOf(state)
        guard !sitz.hasPrefix("lokal_") else { return }
        if ctx.now >= state.turnDeadline || !ctx.connected.contains(sitz) {
            if state.phase == "wuerfeln" { rollAndMove(&state, ctx: &ctx) }
            else if state.phase == "entscheiden" {
                let pos = state.positions[sitz] ?? 0
                let buy = state.owners[pos] == nil && (state.cash[sitz] ?? 0) - fields[pos].preis >= 200
                reduce(&state, action: .button(buy ? "kaufen" : "weiter"), from: sitz, ctx: &ctx)
            }
        }
    }

    public static func isFinished(_ state: State) -> Bool { state.winner != nil }

    public static func results(_ state: State, ctx: BoardgameContext) -> [(sitz: String, platz: Int, detail: String)] {
        let sorted = state.sitze.sorted { a, b in
            if a == state.bankrupt { return false }
            if b == state.bankrupt { return true }
            return netWorth(state, a) > netWorth(state, b)
        }
        return sorted.enumerated().map { (i, s) in (s, i + 1, s == state.bankrupt ? "💥 bankrott" : "Netto \(netWorth(state, s)) MM · \(state.owners.values.filter { $0 == s }.count) Grundstücke") }
    }

    public static func scene(_ state: State, ctx: BoardgameContext) -> BoardgameScene {
        .bananopoly(fields: fields, positions: state.positions, cash: state.cash, current: seatOf(state), dice: state.dice, event: state.event,
                    round: (state.rounds.values.min() ?? 0) + 1, deadline: state.turnDeadline, owners: state.owners, stands: state.stands)
    }

    public static func prompt(_ state: State, sitz: String, ctx: BoardgameContext) -> PlayerPrompt {
        let cash = state.cash[sitz] ?? 0
        let mine = state.owners.filter { $0.value == sitz }.keys.sorted().map { fields[$0].name + (state.stands.contains($0) ? " 🍌" : "") }
        let lines = ["💵 Bargeld: \(cash) MM · Netto: \(netWorth(state, sitz)) MM", "Runde \((state.rounds[sitz] ?? 0) + 1)/4"] + (mine.isEmpty ? ["Kein Besitz"] : ["Besitz: " + mine.joined(separator: ", ")])
        if let w = state.winner { return .idle(title: w == sitz ? "🏆 Vermögens-Sieger!" : "\(ctx.name(w)) gewinnt", subtitle: lines.joined(separator: "\n")) }
        guard seatOf(state) == sitz else { return .actions(title: "\(ctx.name(seatOf(state))) ist dran", lines: lines + [state.event ?? ""], buttons: [], deadline: nil) }
        if state.phase == "wuerfeln" {
            var buttons = [ActionButton(id: "wuerfeln", label: "🎲 Würfeln")]
            if state.inCage[sitz] != nil, cash >= 50 { buttons.append(ActionButton(id: "kaution", label: "🔓 50 MM Kaution zahlen", style: "secondary")) }
            return .actions(title: state.inCage[sitz] != nil ? "🔒 Du sitzt im Affenkäfig" : "Du bist dran!", lines: lines, buttons: buttons, deadline: state.turnDeadline)
        }
        let pos = state.positions[sitz] ?? 0
        var buttons: [ActionButton] = []
        if state.owners[pos] == nil { buttons.append(ActionButton(id: "kaufen", label: "🏷️ Kaufen (\(fields[pos].preis) MM)", enabled: cash >= fields[pos].preis)) }
        if state.owners[pos] == sitz, !state.stands.contains(pos) { buttons.append(ActionButton(id: "bauen", label: "🍌 Bananenstand bauen (\(fields[pos].preis) MM)", enabled: cash >= fields[pos].preis)) }
        buttons.append(ActionButton(id: "weiter", label: "Weiter", style: "secondary"))
        return .actions(title: fields[pos].name, lines: lines, buttons: buttons, deadline: state.turnDeadline)
    }

    public static func currentSeat(_ state: State) -> String? { seatOf(state) }
    public static func shift(_ state: inout State, ms: Int) { state.turnDeadline += ms }
}
