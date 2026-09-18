import SwiftUI

/// Spiele-Abend stage: how-to card, the six boards, result screen and the
/// pass-and-play prompt for local iPad seats.
struct BoardgameStage: View {
    @EnvironmentObject var host: HostModel
    var view: BoardgameStageView
    var players: [PlayerRef]

    var scene: BoardgameScene? { host.server?.withHub { Boardgames.scene($0.state, now: ServerClock.now()) } }

    var body: some View {
        VStack(spacing: 10) {
            switch view.subphase {
            case "howto":
                VStack(spacing: 14) {
                    Text(view.name.uppercased()).font(.outfit(48, .black)).foregroundStyle(MM.gold).bouncy()
                    ForEach(Array(view.howto.enumerated()), id: \.offset) { i, line in
                        HStack(alignment: .top, spacing: 14) {
                            Text("\(i + 1)").font(.outfit(24, .black)).foregroundStyle(MM.ink).frame(width: 40, height: 40).background(Circle().fill(MM.gold))
                            Text(line).font(.poppins(20)).foregroundStyle(MM.cream).lineSpacing(3)
                        }.frame(maxWidth: 900, alignment: .leading).bouncy(delay: Double(i) * 0.2)
                    }
                    CountdownText(deadline: view.howtoEndsAt)
                }
            case "ergebnis":
                VStack(spacing: 14) {
                    Text("🏁 ERGEBNIS · \(view.name)").font(.outfit(40, .black)).foregroundStyle(MM.gold).bouncy()
                    ForEach(view.ergebnis ?? [], id: \.sitz) { r in
                        HStack(spacing: 14) {
                            Text("\(r.platz)").font(.outfit(30, .black)).foregroundStyle(r.platz == 1 ? MM.gold : MM.cream).frame(width: 44)
                            if let p = players.first(where: { $0.id == r.sitz }) { MonkeyImage(avatar: Avatar(wire: p.avatar), face: r.platz == 1 ? "jubel" : "neutral").frame(height: 56) } else { Text("📱").font(.system(size: 30)) }
                            VStack(alignment: .leading) { Text(r.name).font(.outfit(20, .bold)); Text(r.detail).font(.poppins(13)).opacity(0.8) }.foregroundStyle(MM.cream)
                            Spacer()
                            Text(r.lokal ? "📱 Lokaler Sitz — ohne Konto" : "+\(Money.format(r.mm))").font(.outfit(20, .black)).foregroundStyle(MM.gold)
                        }.padding(.horizontal, 18).padding(.vertical, 8).frame(maxWidth: 800).background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.3)))
                    }
                    HStack { GoldButton(title: "Rematch!", icon: "arrow.clockwise", compact: true) { host.command(.flowNext) }; GoldButton(title: "Zur Spiele-Lobby", icon: "house", style: .ghost, compact: true) { host.command(.boardgameAbort) } }
                }.overlay(ParticleRain(kind: .confetti, count: 50, duration: 4))
            default:
                HStack(alignment: .top, spacing: 16) {
                    board.frame(maxWidth: .infinity, maxHeight: .infinity)
                    rail.frame(width: 300)
                }
            }
        }
        .padding(.horizontal, 26)
    }

    // MARK: Rail (status, seats, local prompt)

    @ViewBuilder
    var rail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(view.name).font(.outfit(24, .black)).foregroundStyle(MM.gold)
            if let cur = view.aktuellerSpieler { Chip(text: "Am Zug: \(cur)", gold: true) }
            if let prompt = view.lokalerPrompt { Text(prompt).font(.poppins(16, .bold)).foregroundStyle(MM.cream) }
            if let sitz = localSeatOnTurn, let p = host.server?.withHub({ Boardgames.localPrompt($0.state, sitz: sitz, now: ServerClock.now()) }) {
                LocalSeatPromptView(prompt: p) { action in host.command(.boardgameLocal(sitz: sitz, action: action)) }
            }
            Divider().overlay(MM.gold.opacity(0.3))
            ForEach(players) { p in
                HStack { MonkeyImage(avatar: Avatar(wire: p.avatar)).frame(height: 36); Text(p.name).font(.poppins(14, .bold)).foregroundStyle(MM.cream); Spacer(); Text(Money.format(p.balance)).font(.outfit(14, .black)).foregroundStyle(MM.gold) }
            }
            Spacer()
            GoldButton(title: "✕ Spiel abbrechen", style: .ghost, compact: true) { host.command(.boardgameAbort) }
        }
        .padding(16).background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.3)))
    }

    var localSeatOnTurn: String? {
        host.server?.withHub { hub in
            guard let box = hub.state.boardgame, let plugin = BoardgameRegistry.plugin(box.id), let c = plugin.currentSeat(box.data), c.hasPrefix("lokal_") else { return nil }
            return c
        }
    }

    // MARK: Boards

    var board: AnyView {
        switch scene {
        case .towers(let towers, let stufe, let risiko, let chosen, _, let banked, let soloBonus): return AnyView(towersBoard(towers, stufe, risiko, chosen, banked, soloBonus))
        case .werwolf(let phase, let alive, let dead, let text, let day, let deadline, _, let roles): return AnyView(werwolfBoard(phase, alive, dead, text, day, deadline, roles))
        case .uno(let top, let direction, let hands, let current, let drawPile, let color, let lastEvent, let deadline): return AnyView(unoBoard(top, direction, hands, current, drawPile, color, lastEvent, deadline))
        case .madn(let tokens, let current, let dice, let seq, let message, let kurz, let deadline): return AnyView(madnBoard(tokens, current, dice, seq, message, kurz, deadline))
        case .bananopoly(let fields, let positions, let cash, let current, let dice, let event, let round, let deadline, let owners, let stands): return AnyView(bananopolyBoard(fields, positions, cash, current, dice, event, round, deadline, owners, stands))
        case .siedler(let v): return AnyView(siedlerBoard(v))
        case .none: return AnyView(Text("…").foregroundStyle(MM.cream))
        }
    }

    @ViewBuilder
    func towersBoard(_ towers: [TowerView], _ stufe: Int, _ risiko: Int, _ chosen: [PlayerId], _ banked: [PlayerId: Int], _ soloBonus: PlayerId?) -> some View {

            VStack(spacing: 12) {
                HStack { Chip(text: "Stufe \(stufe + 1)/8", gold: true); Chip(text: "Einsturz-Risiko \(risiko) %", icon: "exclamationmark.triangle"); Chip(text: "\(chosen.count) gewählt") ; if let s = soloBonus, let p = players.first(where: { $0.id == s }) { Chip(text: "⭐ Solo-Bonus \(p.name)", gold: true) } }
                HStack(alignment: .bottom, spacing: 26) {
                    ForEach(towers, id: \.index) { t in
                        VStack(spacing: 2) {
                            HStack(spacing: -10) { ForEach(players.filter { t.climbers.contains($0.id) }) { p in MonkeyImage(avatar: Avatar(wire: p.avatar), face: "denk").frame(height: 44) } }.frame(height: 46)
                            ForEach((0..<max(1, t.height)).reversed(), id: \.self) { i in
                                RoundedRectangle(cornerRadius: 4).fill(t.collapsed ? MM.red.opacity(0.5) : (i == t.height - 1 ? MM.gold : MM.wood)).frame(width: CGFloat(90 - i * 4), height: 22)
                                    .overlay(Text("\(Affenturm.stepLoot[min(i, 7)])").font(.poppins(10, .bold)).foregroundStyle(MM.ink))
                            }
                            Text(t.collapsed ? "💥" : "🗼").font(.system(size: 24))
                        }
                        .rotationEffect(.degrees(t.collapsed ? 12 : Double(risiko) / 50 * (t.climbers.isEmpty ? 0 : 2) * sin(Date().timeIntervalSince1970 * 6)))
                    }
                }
                HStack(spacing: 12) { ForEach(players) { p in Chip(text: "\(p.name): \(banked[p.id] ?? 0) 🍌") } }
            }
    }

    @ViewBuilder
    func werwolfBoard(_ phase: String, _ alive: [PlayerId], _ dead: [PlayerId], _ text: String, _ day: Int, _ deadline: Millis?, _ roles: [PlayerId: String]?) -> some View {
        VStack(spacing: 12) {
            Text(text).font(.outfit(30, .black)).foregroundStyle(phase.hasPrefix("nacht") ? MM.lila : MM.gold).multilineTextAlignment(.center).id(text).bouncy()
            HStack { Chip(text: phase.hasPrefix("nacht") ? "🌙 Nacht \(day)" : "☀️ Tag \(day)", gold: true); CountdownText(deadline: deadline, font: .outfit(24, .black)) }
            SeatCircle(players: players, radius: 200, night: phase.hasPrefix("nacht"), dead: dead, roles: roles, current: nil, hands: nil, center: phase.hasPrefix("nacht") ? "🌙" : "☀️")
                .frame(height: 460)
            Text("\(alive.count) leben · \(dead.count) tot").font(.poppins(13)).foregroundStyle(MM.cream.opacity(0.7))
        }
    }

    @ViewBuilder
    func unoBoard(_ top: UnoCard, _ direction: Int, _ hands: [String: Int], _ current: String, _ drawPile: Int, _ color: String, _ lastEvent: String?, _ deadline: Millis?) -> some View {
        VStack(spacing: 14) {
            HStack { Chip(text: "Am Zug: \(name(current))", gold: true); Chip(text: direction > 0 ? "↻ Richtung" : "↺ Richtung"); Chip(text: "Stapel \(drawPile)"); CountdownText(deadline: deadline, font: .outfit(22, .black)) }
            ZStack {
                Circle().fill(MM.panelDark).frame(width: 460, height: 460).overlay(Circle().strokeBorder(MM.wood, lineWidth: 14))
                UnoCardView(card: top, activeColor: color).frame(width: 110, height: 160).rotationEffect(.degrees(-6))
                SeatCircle(players: players, radius: 250, night: false, dead: [], roles: nil, current: current, hands: hands, center: nil, sitze: view.sitze, names: { name($0) })
            }.frame(height: 520)
            if let e = lastEvent { Text(e).font(.poppins(16, .semibold)).foregroundStyle(MM.gold).id(e).bouncy() }
        }
    }

    @ViewBuilder
    func madnBoard(_ tokens: [MadnToken], _ current: String, _ dice: Int?, _ seq: Int, _ message: String?, _ kurz: Bool, _ deadline: Millis?) -> some View {

            VStack(spacing: 10) {
                HStack { Chip(text: "Am Zug: \(name(current))", gold: true); Chip(text: kurz ? "Kurze Partie" : "Klassisch"); if let d = dice { Text(["", "⚀", "⚁", "⚂", "⚃", "⚄", "⚅"][d]).font(.system(size: 44)).id(seq).bouncy() }; CountdownText(deadline: deadline, font: .outfit(22, .black)) }
                MadnBoard(tokens: tokens, sitze: view.sitze, players: players).frame(width: 520, height: 520)
                if let m = message { Text(m).font(.poppins(16, .semibold)).foregroundStyle(MM.gold) }
            }
    }

    @ViewBuilder
    func bananopolyBoard(_ fields: [BananopolyField], _ positions: [String: Int], _ cash: [String: Int], _ current: String, _ dice: [Int]?, _ event: String?, _ round: Int, _ deadline: Millis?, _ owners: [Int: String], _ stands: [Int]) -> some View {

            VStack(spacing: 10) {
                HStack { Chip(text: "Am Zug: \(name(current))", gold: true); Chip(text: "Runde \(round)/4"); if let d = dice, d.count == 2 { Text(["", "⚀", "⚁", "⚂", "⚃", "⚄", "⚅"][d[0]] + ["", "⚀", "⚁", "⚂", "⚃", "⚄", "⚅"][d[1]]).font(.system(size: 36)) }; CountdownText(deadline: deadline, font: .outfit(22, .black)) }
                BananopolyBoard(fields: fields, positions: positions, owners: owners, stands: stands, sitze: view.sitze, players: players).frame(width: 560, height: 560)
                HStack(spacing: 10) { ForEach(view.sitze, id: \.self) { s in Chip(text: "\(name(s)): \(cash[s] ?? 0) MM", gold: s == current) } }
                if let e = event { Text(e).font(.poppins(16, .semibold)).foregroundStyle(MM.gold).id(e).bouncy() }
            }
    }

    @ViewBuilder
    func siedlerBoard(_ v: SiedlerStageView) -> some View {

            VStack(spacing: 10) {
                HStack { Chip(text: "Am Zug: \(name(v.current))", gold: true); Chip(text: v.phase); if let d = v.dice, d.count == 2 { Text("🎲 \(d[0] + d[1])").font(.outfit(24, .black)).foregroundStyle(MM.gold) }; if let l = v.longestRoad { Chip(text: "🛤️ Längster Pfad: \(name(l))") }; CountdownText(deadline: v.deadline, font: .outfit(22, .black)) }
                SiedlerBoard(view: v, players: players).frame(width: 560, height: 500)
                HStack(spacing: 10) { ForEach(view.sitze, id: \.self) { s in Chip(text: "\(name(s)) ⭐\(v.points[s] ?? 0) · 🃏\(v.handSizes[s] ?? 0)", gold: s == v.current) } }
                if let o = v.offer { Text("🤝 \(o)").font(.poppins(16, .bold)).foregroundStyle(MM.gold) }
                if let e = v.event { Text(e).font(.poppins(15)).foregroundStyle(MM.cream) }
            }
    }

    func name(_ sitz: String) -> String {
        if let p = players.first(where: { $0.id == sitz }) { return p.name }
        if sitz.hasPrefix("lokal_"), let i = Int(sitz.dropFirst(6)), host.server?.withHub({ $0.state.boardgame?.lokaleSitze.indices.contains(i) }) == true { return host.server?.withHub { $0.state.boardgame?.lokaleSitze[i] } ?? sitz }
        return sitz
    }

    func roleEmoji(_ r: String) -> String { ["werwolf": "🐺", "seherin": "🔮", "hexe": "🧪"][r] ?? "🐒" }
}

struct UnoCardView: View {
    var card: UnoCard
    var activeColor: String?
    var body: some View {
        let col: Color = { switch card.farbe == "schwarz" ? (activeColor ?? "schwarz") : card.farbe { case "rot": return MM.red; case "gelb": return MM.goldDark; case "gruen": return Color(hex: "#3AA655"); case "blau": return MM.blue; default: return .black } }()
        RoundedRectangle(cornerRadius: 14).fill(col).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white, lineWidth: 5))
            .overlay(Text(["skip": "⛔", "reverse": "🔄", "draw2": "+2", "wild": "W", "wild4": "W+4"][card.wert] ?? card.wert).font(.outfit(48, .black)).foregroundStyle(.white).shadow(radius: 3))
            .shadow(color: .black.opacity(0.5), radius: 10, y: 6)
    }
}

/// MADN cross board (11×11, 40 ring fields, 4 houses, 4 target lanes).
struct MadnBoard: View {
    var tokens: [MadnToken]; var sitze: [String]; var players: [PlayerRef]
    static let seatColors: [Color] = [MM.gold, MM.red, MM.green, MM.blue]

    func gridPos(_ pos: Int) -> (Double, Double) {
        // Parametric ring: walk the cross outline (40 cells).
        let path: [(Int, Int)] = MadnBoard.crossPath
        let p = path[((pos % 40) + 40) % 40]
        return (Double(p.0), Double(p.1))
    }

    /// Ring cells on the 11×11 cross, clockwise; start fields at 0/10/20/30.
    static let crossPath: [(Int, Int)] = {
        let seq: [(Int, Int)] = [(0, 4), (1, 4), (2, 4), (3, 4), (4, 4), (4, 3), (4, 2), (4, 1), (4, 0), (5, 0), (6, 0), (6, 1), (6, 2), (6, 3), (6, 4), (7, 4), (8, 4), (9, 4), (10, 4), (10, 5), (10, 6), (9, 6), (8, 6), (7, 6), (6, 6), (6, 7), (6, 8), (6, 9), (6, 10), (5, 10), (4, 10), (4, 9), (4, 8), (4, 7), (4, 6), (3, 6), (2, 6), (1, 6), (0, 6), (0, 5)]
        return seq
    }()

    static let houses: [[(Int, Int)]] = [[(0, 0), (1, 0), (0, 1), (1, 1)], [(9, 0), (10, 0), (9, 1), (10, 1)], [(9, 9), (10, 9), (9, 10), (10, 10)], [(0, 9), (1, 9), (0, 10), (1, 10)]]
    static let lanes: [[(Int, Int)]] = [[(1, 5), (2, 5), (3, 5), (4, 5)], [(5, 1), (5, 2), (5, 3), (5, 4)], [(9, 5), (8, 5), (7, 5), (6, 5)], [(5, 9), (5, 8), (5, 7), (5, 6)]]

    var body: some View {
        GeometryReader { geo in
            let cell = geo.size.width / 11
            ZStack {
                RoundedRectangle(cornerRadius: 24).fill(MM.wood).overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color(hex: "#5A3A1C"), lineWidth: 6))
                ringFields(cell)
                housesAndLanes(cell)
                tokenViews(cell)
            }
        }
    }

    func point(_ g: (Double, Double), _ cell: CGFloat) -> CGPoint { CGPoint(x: (g.0 + 0.5) * cell, y: (g.1 + 0.5) * cell) }

    func ringFields(_ cell: CGFloat) -> some View {
        ForEach(0..<40, id: \.self) { i in
            let color: Color = i % 10 == 0 ? MadnBoard.seatColors[i / 10].opacity(0.6) : MM.cream
            Circle().fill(color).frame(width: cell * 0.78, height: cell * 0.78).position(point(gridPos(i), cell))
        }
    }

    func housesAndLanes(_ cell: CGFloat) -> some View {
        ForEach(0..<16, id: \.self) { n in
            let s = n / 4, i = n % 4
            let h = MadnBoard.houses[s][i], l = MadnBoard.lanes[s][i]
            Circle().fill(MadnBoard.seatColors[s].opacity(0.35)).frame(width: cell * 0.7, height: cell * 0.7).position(point((Double(h.0), Double(h.1)), cell))
            Circle().fill(MadnBoard.seatColors[s].opacity(0.55)).frame(width: cell * 0.7, height: cell * 0.7).position(point((Double(l.0), Double(l.1)), cell))
        }
    }

    func tokenViews(_ cell: CGFloat) -> some View {
        ForEach(Array(tokens.enumerated()), id: \.offset) { _, t in
            let seat = sitze.firstIndex(of: t.sitz) ?? 0
            let pos = tokenPosition(t, seat: seat)
            MadnTokenView(color: MadnBoard.seatColors[seat % 4], avatar: players.first { $0.id == t.sitz }.map { Avatar(wire: $0.avatar) }, size: cell * 0.82)
                .position(point(pos, cell))
                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: t.pos)
        }
    }

    func tokenPosition(_ t: MadnToken, seat: Int) -> (Double, Double) {
        if t.pos == -1 {
            let h = MadnBoard.houses[seat % 4][t.index % 4]
            return (Double(h.0), Double(h.1))
        }
        if t.pos >= 100 {
            let l = MadnBoard.lanes[seat % 4][min(3, t.pos - 100)]
            return (Double(l.0), Double(l.1))
        }
        return gridPos(t.pos)
    }
}

/// Bananopoly 28-field ring on an 8×8 border.
struct BananopolyBoard: View {
    var fields: [BananopolyField]; var positions: [String: Int]; var owners: [Int: String]; var stands: [Int]; var sitze: [String]; var players: [PlayerRef]
    static let pairColors: [Color] = [Color(hex: "#8B5E34"), MM.blue, MM.lila, MM.orange, MM.red, MM.gold, MM.green, Color(hex: "#2ED3C6"), Color(hex: "#C0C0C0")]

    func cell(_ i: Int) -> (Int, Int) {
        // 28 cells around an 8×8 border, LOS bottom-left, clockwise.
        if i < 7 { return (0, 7 - i) }
        if i < 14 { return (i - 7, 0) }
        if i < 21 { return (7, i - 14) }
        return (28 - i, 7)
    }

    var body: some View {
        GeometryReader { geo in
            let c = geo.size.width / 8
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(MM.panelDark).overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(MM.wood, lineWidth: 8))
                Text("BANANOPOLY").font(.outfit(34, .black)).foregroundStyle(MM.gold).rotationEffect(.degrees(-30))
                fieldTiles(c)
                tokens(c)
            }
        }
    }

    func pos(_ i: Int, _ c: CGFloat) -> CGPoint { let p = cell(i); return CGPoint(x: (CGFloat(p.0) + 0.5) * c, y: (CGFloat(p.1) + 0.5) * c) }

    func ownerColor(_ index: Int) -> Color {
        guard let o = owners[index] else { return Color.black.opacity(0.3) }
        return MadnBoard.seatColors[(sitze.firstIndex(of: o) ?? 0) % 4].opacity(0.35)
    }

    func fieldTiles(_ c: CGFloat) -> some View {
        ForEach(fields, id: \.index) { f in
            BananopolyTile(field: f, owned: owners[f.index] != nil, ownerColor: ownerColor(f.index), stand: stands.contains(f.index))
                .frame(width: c - 3, height: c - 3)
                .position(pos(f.index, c))
        }
    }

    func tokens(_ c: CGFloat) -> some View {
        ForEach(Array(sitze.enumerated()), id: \.offset) { i, s in
            let p = pos(positions[s] ?? 0, c)
            MadnTokenView(color: MadnBoard.seatColors[i % 4], avatar: players.first { $0.id == s }.map { Avatar(wire: $0.avatar) }, size: c * 0.5)
                .position(x: p.x + CGFloat(i % 2) * 14 - 7, y: p.y + CGFloat(i / 2) * 14 - 7)
                .animation(.spring(response: 0.6, dampingFraction: 0.75), value: positions[s] ?? 0)
        }
    }
}

struct BananopolyTile: View {
    var field: BananopolyField
    var owned: Bool
    var ownerColor: Color
    var stand: Bool
    static let icons: [String: String] = ["los": "🏁", "karte": "🃏", "steuer": "💸", "kaefig-besuch": "🔒", "ab-in-kaefig": "🚔", "frei": "🍌"]
    var body: some View {
        VStack(spacing: 1) {
            if let paar = field.paar { Rectangle().fill(BananopolyBoard.pairColors[paar % 9]).frame(height: 8) }
            Text(field.typ == "grundstueck" ? field.name : (BananopolyTile.icons[field.typ] ?? "")).font(.poppins(field.typ == "grundstueck" ? 8 : 20, .bold)).foregroundStyle(MM.cream).lineLimit(2).multilineTextAlignment(.center)
            if stand { Text("🍌").font(.system(size: 10)) }
        }
        .background(RoundedRectangle(cornerRadius: 6).fill(ownerColor).overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(owned ? MM.gold : Color.white.opacity(0.1))))
    }
}

/// Players arranged on a circle (Werwolf village / UNO table).
struct SeatCircle: View {
    var players: [PlayerRef]
    var radius: CGFloat
    var night: Bool
    var dead: [PlayerId]
    var roles: [PlayerId: String]?
    var current: String?
    var hands: [String: Int]?
    var center: String?
    var sitze: [String]? = nil
    var names: ((String) -> String)? = nil

    var seats: [String] { sitze ?? players.map { $0.id } }

    var body: some View {
        ZStack {
            if let c = center {
                Circle().stroke(MM.gold.opacity(0.3), lineWidth: 2).frame(width: radius * 2.1, height: radius * 2.1)
                Text(c).font(.system(size: 60))
            }
            ForEach(Array(seats.enumerated()), id: \.offset) { i, sitz in
                seat(sitz).offset(offset(for: i))
            }
        }
    }

    func offset(for i: Int) -> CGSize {
        let a = Double(i) / Double(max(1, seats.count)) * 2 * Double.pi - Double.pi / 2
        return CGSize(width: cos(a) * Double(radius), height: sin(a) * Double(radius))
    }

    func seat(_ sitz: String) -> SeatView {
        SeatView(sitz: sitz, player: players.first { $0.id == sitz }, night: night, isDead: dead.contains(sitz), role: roles?[sitz], isCurrent: current == sitz, hand: hands?[sitz], name: names?(sitz))
    }
}

struct SeatView: View {
    var sitz: String
    var player: PlayerRef?
    var night: Bool
    var isDead: Bool
    var role: String?
    var isCurrent: Bool
    var hand: Int?
    var name: String?
    var body: some View {
        VStack(spacing: 2) {
            if let p = player {
                MonkeyImage(avatar: Avatar(wire: p.avatar), face: isDead ? "frust" : (night || isCurrent ? "denk" : "neutral")).frame(height: 66).opacity(isDead ? 0.35 : 1)
            } else { Text("📱").font(.system(size: 36)) }
            Text(name ?? player?.name ?? sitz).font(.poppins(12, .bold)).foregroundStyle(isCurrent ? MM.gold : MM.cream)
            if isDead { Text("👻 " + (role.map { roleEmoji($0) } ?? "")).font(.system(size: 14)) }
            else if let r = role { Text(roleEmoji(r)).font(.system(size: 14)) }
            if let h = hand { Text("\(h) Karten").font(.poppins(11)).foregroundStyle(MM.cream.opacity(0.8)) }
        }
    }
    func roleEmoji(_ r: String) -> String { ["werwolf": "🐺", "seherin": "🔮", "hexe": "🧪"][r] ?? "🐒" }
}

/// Siedler hex island (pointy-top axial), buildings and roads.
struct SiedlerBoard: View {
    var view: SiedlerStageView; var players: [PlayerRef]
    static let resColors: [String: Color] = ["banane": MM.gold, "holz": Color(hex: "#2E7D32"), "stein": Color(hex: "#7D8CA3"), "kokos": MM.wood, "blatt": MM.green, "duerr": Color(hex: "#C9A66B")]
    static let resEmoji: [String: String] = ["banane": "🍌", "holz": "🪵", "stein": "🪨", "kokos": "🥥", "blatt": "🍃", "duerr": "🏜️"]

    var body: some View {
        GeometryReader { geo in
            let R = min(geo.size.width, geo.size.height) / 11
            let cx = geo.size.width / 2, cy = geo.size.height / 2
            ZStack {
                ForEach(Array(view.hexes.enumerated()), id: \.offset) { i, h in
                    let (x, y) = center(h.q, h.r, R)
                    Hexagon().fill(SiedlerBoard.resColors[h.rohstoff] ?? .gray).frame(width: R * 2 * 0.98, height: R * 2 * 0.98)
                        .overlay(Hexagon().stroke(MM.wood, lineWidth: 3))
                        .overlay(VStack(spacing: 0) { Text(SiedlerBoard.resEmoji[h.rohstoff] ?? "").font(.system(size: R * 0.5)); if let z = h.zahl { Text("\(z)").font(.outfit(R * 0.42, .black)).foregroundStyle(z == 6 || z == 8 ? MM.red : MM.ink).padding(.horizontal, 6).background(Capsule().fill(MM.cream)) } })
                        .overlay(view.robber == i ? Text("🐒").font(.system(size: R * 0.7)).offset(y: -R * 0.5) : nil)
                        .position(x: cx + x, y: cy + y)
                }
                ForEach(view.roads, id: \.edge) { r in
                    let cs = r.edge.split(separator: "|").map(String.init)
                    if cs.count == 2, let a = parse(cs[0]), let b = parse(cs[1]) {
                        Path { p in p.move(to: CGPoint(x: cx + a.0 * R, y: cy + a.1 * R)); p.addLine(to: CGPoint(x: cx + b.0 * R, y: cy + b.1 * R)) }
                            .stroke(seatColor(r.sitz), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    }
                }
                ForEach(view.buildings, id: \.corner) { b in
                    if let c = parse(b.corner) {
                        Text(b.stufe == 2 ? "🌳" : "🏠").font(.system(size: R * (b.stufe == 2 ? 0.7 : 0.55))).padding(3).background(Circle().fill(seatColor(b.sitz))).position(x: cx + c.0 * R, y: cy + c.1 * R)
                    }
                }
            }
        }
    }

    func center(_ q: Int, _ r: Int, _ R: CGFloat) -> (CGFloat, CGFloat) { (CGFloat(sqrt(3) * (Double(q) + Double(r) / 2)) * R, CGFloat(1.5 * Double(r)) * R) }
    func parse(_ key: String) -> (CGFloat, CGFloat)? {
        let p = key.split(separator: ",").compactMap { Double($0) }
        return p.count == 2 ? (CGFloat(p[0]), CGFloat(p[1])) : nil
    }
    func seatColor(_ sitz: String) -> Color { MadnBoard.seatColors[(view.points.keys.sorted().firstIndex(of: sitz) ?? 0) % 4] }
}

struct MadnTokenView: View {
    var color: Color
    var avatar: Avatar?
    var size: CGFloat
    var body: some View {
        ZStack {
            Circle().fill(color).overlay(Circle().strokeBorder(MM.ink, lineWidth: 2))
            if let a = avatar { MonkeyImage(avatar: a).frame(height: size * 0.72) } else { Text("📱").font(.system(size: size * 0.45)) }
        }
        .frame(width: size, height: size)
    }
}

struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for i in 0..<6 {
            let a = Double(i) * .pi / 3 - .pi / 6
            let pt = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// Renders a prompt for a local (pass-and-play) seat on the iPad rail.
struct LocalSeatPromptView: View {
    var prompt: PlayerPrompt
    var send: (PlayerAction) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch prompt {
            case .actions(let title, let lines, let buttons, _):
                Text(title).font(.outfit(18, .bold)).foregroundStyle(MM.cream)
                ForEach(lines, id: \.self) { Text($0).font(.poppins(12)).foregroundStyle(MM.cream.opacity(0.8)) }
                ForEach(buttons) { b in GoldButton(title: b.label, style: b.style == "primary" ? .gold : (b.style == "danger" ? .red : .ghost), compact: true) { send(.button(b.id)) }.disabled(!b.enabled).opacity(b.enabled ? 1 : 0.5) }
            case .choice(let q, let opts, _, _, _, _):
                Text(q).font(.poppins(13, .bold)).foregroundStyle(MM.cream)
                ForEach(opts) { o in GoldButton(title: o.text, style: .ghost, compact: true) { send(.choose(o.id)) }.disabled(o.removed).opacity(o.removed ? 0.4 : 1) }
            case .cards(let title, let cards, let buttons, _, _):
                Text(title).font(.poppins(13, .bold)).foregroundStyle(MM.cream)
                ScrollView(.horizontal) { HStack { ForEach(cards) { c in Button { send(.choose(c.id)) } label: { Text(c.text).font(.poppins(12, .bold)).padding(8).background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.4))).foregroundStyle(MM.cream) }.disabled(c.removed).opacity(c.removed ? 0.4 : 1) } } }
                ForEach(buttons) { b in GoldButton(title: b.label, style: .ghost, compact: true) { send(.button(b.id)) }.disabled(!b.enabled) }
            case .confirm(let title, _, let button, let done, _):
                Text(title).font(.poppins(13, .bold)).foregroundStyle(MM.cream)
                GoldButton(title: button, compact: true) { send(.confirm) }.disabled(done)
            case .binary(let title, _, let a, let b, _, _):
                Text(title).font(.poppins(13, .bold)).foregroundStyle(MM.cream)
                HStack { GoldButton(title: a, compact: true) { send(.binary(a)) }; GoldButton(title: b, style: .ghost, compact: true) { send(.binary(b)) } }
            case .idle(let t, let s):
                Text(t).font(.poppins(13, .bold)).foregroundStyle(MM.cream); if let s = s { Text(s).font(.poppins(11)).foregroundStyle(MM.cream.opacity(0.7)) }
            default:
                Text("📲 Aktion auf dem Handy").font(.poppins(12)).foregroundStyle(MM.cream.opacity(0.7))
            }
        }
        .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(MM.gold.opacity(0.12)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(MM.gold.opacity(0.5))))
    }
}
