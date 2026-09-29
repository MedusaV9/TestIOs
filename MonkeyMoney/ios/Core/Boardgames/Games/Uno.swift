import Foundation

/// Bananen-Batsche (UNO) — 2–8, standard rules without draw stacking, a drawn
/// card may be played immediately, BANANE! call with penalty, AFK autoplay,
/// pass-and-play with hidden hands via the iPad hand-over gate.
public enum Uno: BoardgamePlugin {
    public struct State: Codable, Equatable, Sendable {
        public var hands: [String: [UnoCard]]
        public var drawPile: [UnoCard]
        public var discard: [UnoCard]
        public var current: Int
        public var direction: Int
        public var color: String
        public var pendingWild: Bool
        public var drewThisTurn: Bool
        public var bananeCalled: [String]
        public var bananeWindowUntil: [String: Millis]
        public var winner: String?
        public var lastEvent: String?
        public var turnDeadline: Millis
        public var seq: Int
        public var handover: Bool
        public var finishedOrder: [String]
        public var sitze: [String]
    }

    public static let meta = BoardgameMeta(
        id: "uno", name: "Bananen-Batsche (UNO)", emoji: "🃏", untertitel: "Kartenklassiker · 2–8 Affen",
        minSpieler: 2, maxSpieler: 8, phonesOnly: false, gemischteSitze: true,
        howto: ["Lege eine Karte, die zur Farbe oder Zahl der obersten Karte passt — oder eine schwarze Wild-Karte.",
                "Kannst du nicht, ziehst du eine Karte; passt sie, darfst du sie sofort legen. Aussetzen, Richtungswechsel und +2 gelten wie gewohnt (kein Stapeln).",
                "Bei der vorletzten Karte BANANE! rufen — sonst gibt es zwei Strafkarten. Wer zuerst keine Karten mehr hat, gewinnt."],
        varianten: [], halbePayout: false
    )

    static let colors = ["rot", "gelb", "gruen", "blau"]
    static let turnMs = 30_000

    static func deck(rng: inout SeededRandom) -> [UnoCard] {
        var d: [UnoCard] = []
        for c in colors {
            d.append(UnoCard(farbe: c, wert: "0"))
            for n in 1...9 { d.append(UnoCard(farbe: c, wert: String(n))); d.append(UnoCard(farbe: c, wert: String(n))) }
            for w in ["skip", "reverse", "draw2"] { d.append(UnoCard(farbe: c, wert: w)); d.append(UnoCard(farbe: c, wert: w)) }
        }
        for _ in 0..<4 { d.append(UnoCard(farbe: "schwarz", wert: "wild")); d.append(UnoCard(farbe: "schwarz", wert: "wild4")) }
        return rng.shuffled(d)
    }

    public static func initState(ctx: inout BoardgameContext) -> State {
        var pile = deck(rng: &ctx.rng)
        var hands: [String: [UnoCard]] = [:]
        for s in ctx.sitze { hands[s] = Array(pile.prefix(7)); pile.removeFirst(7) }
        var first = pile.removeFirst()
        while first.farbe == "schwarz" { pile.append(first); first = pile.removeFirst() }
        return State(hands: hands, drawPile: pile, discard: [first], current: 0, direction: 1, color: first.farbe, pendingWild: false, drewThisTurn: false,
                     bananeCalled: [], bananeWindowUntil: [:], winner: nil, lastEvent: "Los geht's — \(ctx.name(ctx.sitze[0])) beginnt!", turnDeadline: ctx.now + ctx.ms(turnMs), seq: 0,
                     handover: ctx.sitze[0].hasPrefix("lokal_"), finishedOrder: [], sitze: ctx.sitze)
    }

    static func seat(_ s: State, _ ctx: BoardgameContext) -> String { ctx.sitze[s.current % ctx.sitze.count] }
    static func top(_ s: State) -> UnoCard { s.discard.last! }

    static func playable(_ card: UnoCard, on top: UnoCard, color: String) -> Bool {
        card.farbe == "schwarz" || card.farbe == color || card.wert == top.wert
    }

    static func draw(_ s: inout State, _ sitz: String, _ n: Int, ctx: inout BoardgameContext) {
        for _ in 0..<n {
            if s.drawPile.isEmpty {
                let keep = s.discard.removeLast()
                s.drawPile = ctx.rng.shuffled(s.discard)
                s.discard = [keep]
            }
            if let c = s.drawPile.first { s.drawPile.removeFirst(); s.hands[sitz, default: []].append(c) }
        }
    }

    static func nextSeat(_ s: inout State, ctx: BoardgameContext, skip: Int = 0) {
        let n = ctx.sitze.count
        s.current = ((s.current + s.direction * (1 + skip)) % n + n) % n
        s.drewThisTurn = false
        s.turnDeadline = ctx.now + ctx.ms(turnMs)
        s.handover = seat(s, ctx).hasPrefix("lokal_")
        s.seq += 1
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from sitz: String, ctx: inout BoardgameContext) {
        guard state.winner == nil else { return }
        // BANANE! call is allowed any time by the owner of a 2-card hand.
        if case .button(let b) = action, b == "banane" {
            if (state.hands[sitz]?.count ?? 0) <= 2, !state.bananeCalled.contains(sitz) { state.bananeCalled.append(sitz); state.lastEvent = "🍌 \(ctx.name(sitz)) ruft BANANE!" }
            return
        }
        guard seat(state, ctx) == sitz else { return }
        if state.handover, case .confirm = action { state.handover = false; return }
        if state.pendingWild {
            if case .button(let c) = action, colors.contains(c) {
                state.color = c
                state.pendingWild = false
                finishTurn(&state, played: top(state), ctx: &ctx)
            }
            return
        }
        switch action {
        case .choose(let i):
            guard var hand = state.hands[sitz], i >= 0, i < hand.count else { return }
            let card = hand[i]
            guard playable(card, on: top(state), color: state.color) else { return }
            hand.remove(at: i)
            state.hands[sitz] = hand
            state.discard.append(card)
            state.lastEvent = "\(ctx.name(sitz)) legt \(label(card))"
            if hand.isEmpty {
                state.finishedOrder.append(sitz)
                state.winner = sitz
                return
            }
            if hand.count == 1, !state.bananeCalled.contains(sitz) {
                // Must call BANANE! within the window (checked in tick).
                state.bananeWindowUntil[sitz] = ctx.now + ctx.ms(2500)
            }
            if card.farbe == "schwarz" { state.pendingWild = true; return }
            state.color = card.farbe
            finishTurn(&state, played: card, ctx: &ctx)
        case .button(let b) where b == "ziehen":
            guard !state.drewThisTurn else { return }
            draw(&state, sitz, 1, ctx: &ctx)
            state.drewThisTurn = true
            if let last = state.hands[sitz]?.last, playable(last, on: top(state), color: state.color) {
                state.lastEvent = "\(ctx.name(sitz)) zieht — und darf legen!"
            } else {
                state.lastEvent = "\(ctx.name(sitz)) zieht."
                nextSeat(&state, ctx: ctx)
            }
        case .button(let b) where b == "passen":
            guard state.drewThisTurn else { return }
            nextSeat(&state, ctx: ctx)
        default: break
        }
    }

    static func finishTurn(_ s: inout State, played: UnoCard, ctx: inout BoardgameContext) {
        let currentSeat = seat(s, ctx)
        let hands = s.hands
        s.bananeCalled.removeAll { ($0 != currentSeat) && (hands[$0]?.count ?? 0) > 2 }
        let n = ctx.sitze.count
        switch played.wert {
        case "skip":
            nextSeat(&s, ctx: ctx, skip: 1)
        case "reverse":
            if n == 2 { nextSeat(&s, ctx: ctx, skip: 1) } else { s.direction *= -1; nextSeat(&s, ctx: ctx) }
        case "draw2":
            nextSeat(&s, ctx: ctx)
            let victim = seat(s, ctx)
            draw(&s, victim, 2, ctx: &ctx)
            s.lastEvent = "\(ctx.name(victim)) zieht 2!"
            nextSeat(&s, ctx: ctx)
        case "wild4":
            nextSeat(&s, ctx: ctx)
            let victim = seat(s, ctx)
            draw(&s, victim, 4, ctx: &ctx)
            s.lastEvent = "\(ctx.name(victim)) zieht 4!"
            nextSeat(&s, ctx: ctx)
        default:
            nextSeat(&s, ctx: ctx)
        }
    }

    public static func tick(_ state: inout State, ctx: inout BoardgameContext) {
        guard state.winner == nil else { return }
        // BANANE! penalty: forgot to call within the window.
        for (sitz, until) in state.bananeWindowUntil where ctx.now >= until {
            state.bananeWindowUntil[sitz] = nil
            if !state.bananeCalled.contains(sitz), (state.hands[sitz]?.count ?? 0) == 1 {
                draw(&state, sitz, 2, ctx: &ctx)
                state.lastEvent = "🍌 \(ctx.name(sitz)) hat BANANE! vergessen — 2 Strafkarten!"
            }
        }
        // Turn timer / AFK autoplay (phones only; local seats wait).
        let sitz = seat(state, ctx)
        let afk = !ctx.connected.contains(sitz)
        if !sitz.hasPrefix("lokal_"), ctx.now >= state.turnDeadline || afk && ctx.now >= state.turnDeadline - ctx.ms(turnMs) + 20_000 {
            autoplay(&state, sitz, ctx: &ctx)
        }
    }

    static func autoplay(_ s: inout State, _ sitz: String, ctx: inout BoardgameContext) {
        if s.pendingWild {
            let hand = s.hands[sitz] ?? []
            let best = colors.max { a, b in hand.filter { $0.farbe == a }.count < hand.filter { $0.farbe == b }.count } ?? "rot"
            reduce(&s, action: .button(best), from: sitz, ctx: &ctx)
            return
        }
        s.lastEvent = "⏰ \(ctx.name(sitz)) träumt — der Server spielt"
        if let idx = (s.hands[sitz] ?? []).firstIndex(where: { playable($0, on: top(s), color: s.color) }) {
            reduce(&s, action: .choose(idx), from: sitz, ctx: &ctx)
            if s.pendingWild { autoplay(&s, sitz, ctx: &ctx) }
        } else if !s.drewThisTurn {
            reduce(&s, action: .button("ziehen"), from: sitz, ctx: &ctx)
            if seat(s, ctx) == sitz, let idx = (s.hands[sitz] ?? []).firstIndex(where: { playable($0, on: top(s), color: s.color) }) {
                reduce(&s, action: .choose(idx), from: sitz, ctx: &ctx)
                if s.pendingWild { autoplay(&s, sitz, ctx: &ctx) }
            }
        } else {
            reduce(&s, action: .button("passen"), from: sitz, ctx: &ctx)
        }
    }

    public static func isFinished(_ state: State) -> Bool { state.winner != nil }

    public static func results(_ state: State, ctx: BoardgameContext) -> [(sitz: String, platz: Int, detail: String)] {
        let sorted = ctx.sitze.sorted { (state.hands[$0]?.count ?? 0) < (state.hands[$1]?.count ?? 0) }
        return sorted.enumerated().map { (i, s) in (s, i + 1, "\(state.hands[s]?.count ?? 0) Karten übrig") }
    }

    static func label(_ c: UnoCard) -> String {
        let f = ["rot": "🔴", "gelb": "🟡", "gruen": "🟢", "blau": "🔵", "schwarz": "⚫"][c.farbe] ?? ""
        let w = ["skip": "⛔", "reverse": "🔄", "draw2": "+2", "wild": "Wild", "wild4": "Wild +4"][c.wert] ?? c.wert
        return "\(f) \(w)"
    }

    public static func scene(_ state: State, ctx: BoardgameContext) -> BoardgameScene {
        var sizes: [String: Int] = [:]
        for s in ctx.sitze { sizes[s] = state.hands[s]?.count ?? 0 }
        return .uno(topCard: top(state), direction: state.direction, hands: sizes, current: seat(state, ctx), drawPile: state.drawPile.count, color: state.color,
                    lastEvent: state.lastEvent, deadline: state.turnDeadline)
    }

    public static func prompt(_ state: State, sitz: String, ctx: BoardgameContext) -> PlayerPrompt {
        let hand = state.hands[sitz] ?? []
        let mine = seat(state, ctx) == sitz
        if let w = state.winner { return .idle(title: w == sitz ? "🎉 Du hast gewonnen!" : "\(ctx.name(w)) hat gewonnen", subtitle: "\(hand.count) Karten übrig") }
        if mine, state.handover { return .confirm(title: "📲 \(ctx.name(sitz)) ist dran", subtitle: "Hand verdeckt — antippen, wenn du das iPad hast", button: "Ich bin's — zeigen", done: false, deadline: nil) }
        if mine, state.pendingWild {
            return .actions(title: "Welche Farbe?", lines: [], buttons: colors.map { ActionButton(id: $0, label: label(UnoCard(farbe: $0, wert: "")).trimmingCharacters(in: .whitespaces) + " " + $0.capitalized) }, deadline: state.turnDeadline)
        }
        let opts = hand.enumerated().map { ChoiceOption(id: $0.offset, text: label($0.element), removed: !mine || !playable($0.element, on: top(state), color: state.color)) }
        var buttons: [ActionButton] = []
        if mine {
            buttons.append(ActionButton(id: "ziehen", label: "Karte ziehen", style: "secondary", enabled: !state.drewThisTurn))
            if state.drewThisTurn { buttons.append(ActionButton(id: "passen", label: "Passen", style: "secondary")) }
        }
        if hand.count <= 2, !state.bananeCalled.contains(sitz) { buttons.append(ActionButton(id: "banane", label: "🍌 BANANE!", style: "danger")) }
        let title = mine ? "Du bist dran! Oben: \(label(top(state))) · Farbe \(state.color)" : "\(ctx.name(seat(state, ctx))) ist dran · Oben: \(label(top(state)))"
        return .cards(title: title, cards: opts, buttons: buttons, deadline: mine ? state.turnDeadline : nil, hint: "\(hand.count) Karten")
    }

    public static func currentSeat(_ state: State) -> String? { state.sitze.isEmpty ? nil : state.sitze[state.current % state.sitze.count] }
    public static func shift(_ state: inout State, ms: Int) { state.turnDeadline += ms }
}
