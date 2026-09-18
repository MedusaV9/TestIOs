import SwiftUI

/// Question wall + minigame extra + player podiums (the “LED wall” of the show).
struct QuestionStage: View {
    var wall: QuestionWall?
    var extra: StageExtra
    var minigameId: String
    var kind: SectionKind
    var title: String
    var players: [PlayerRef]
    var revealed: Bool
    var deltas: [PlayerId: Int]

    var body: some View {
        VStack(spacing: 10) {
            if let w = wall, !w.blackout {
                wallView(w)
            } else if let w = wall, w.blackout {
                blackout(w)
            }
            extraView
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            podiums
        }
        .padding(.horizontal, 26)
        .overlay(alignment: .top) {
            if revealed, deltas.values.contains(where: { $0 >= 750 }) { ParticleRain(kind: .coins, count: 50, duration: 3) }
            if revealed, case .bomb(_, _, _, let exploded, _) = extra, exploded != nil { ParticleRain(kind: .mud, count: 40, duration: 2.5) }
        }
    }

    // MARK: Wall

    @ViewBuilder
    func wallView(_ w: QuestionWall) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Chip(text: "Frage \(w.nummer)\(w.gesamt > 0 ? " / \(w.gesamt)" : "")", gold: true)
                Chip(text: "\(w.kategorieEmoji) \(w.kategorieName)")
                Chip(text: w.schwierigkeit.label, icon: w.schwierigkeit == .ultrahard ? "flame.fill" : nil)
                if !title.isEmpty { Chip(text: title) }
                Spacer()
                if kind == .jackpot { Chip(text: "💰 JACKPOT", gold: true) }
                Text(Money.format(w.wert)).font(.outfit(26, .black)).foregroundStyle(MM.gold)
                if !revealed, let dl = w.deadline {
                    ZStack {
                        Circle().stroke(Color.black.opacity(0.4), lineWidth: 6).frame(width: 58, height: 58)
                        TimelineView(.animation(minimumInterval: 0.1)) { _ in
                            let remain = max(0, Double(dl - ServerClock.now()))
                            Circle().trim(from: 0, to: min(1, remain / Double(max(1, w.timerMs)))).stroke(remain < 5000 ? MM.red : MM.gold, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 58, height: 58)
                        }
                        CountdownText(deadline: dl, font: .outfit(22, .black))
                    }
                }
            }
            if let img = w.image, w.pixelLevel != nil || minigameId == "pixel-dschungel" {
                PixelImage(name: img, level: w.pixelLevel ?? 8, maxLevel: 8).frame(height: 260)
            }
            Text(w.text).font(.outfit(w.text.count > 90 ? 30 : 38, .black)).foregroundStyle(MM.cream).multilineTextAlignment(.center).lineSpacing(4)
                .frame(maxWidth: 1000).padding(.horizontal, 20)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
            if let opts = w.options {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Array(opts.enumerated()), id: \.element.id) { i, o in
                        OptionTile(index: i, option: o, correct: w.correctIndex == o.id, revealed: w.revealed, count: o.count, players: revealed ? players.filter { w.answersByPlayer[$0.id] == o.id } : [])
                    }
                }
                .frame(maxWidth: 1000)
            }
            if revealed, let e = w.erklaerung, !e.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Text("🚀").font(.system(size: 26))
                    Text(e).font(.poppins(17)).foregroundStyle(MM.cream).lineSpacing(3)
                }
                .padding(16).frame(maxWidth: 1000)
                .background(RoundedRectangle(cornerRadius: 16).fill(MM.cream.opacity(0.08)).overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MM.gold.opacity(0.35))))
                .bouncy(delay: 0.3)
            } else if let t = w.tipp {
                Text("💡 \(t)").font(.poppins(16, .semibold)).foregroundStyle(MM.gold)
            }
            if !revealed, w.options != nil {
                HStack(spacing: 6) {
                    ForEach(players) { p in
                        Circle().fill(w.answered.contains(p.id) ? MM.green : Color.black.opacity(0.4)).frame(width: 14, height: 14)
                            .overlay(Circle().strokeBorder(MM.playerColor(Avatar(wire: p.avatar).farbe), lineWidth: 2))
                    }
                    Text("\(w.answered.count)/\(players.count) geantwortet").font(.poppins(12, .semibold)).foregroundStyle(MM.cream.opacity(0.75))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [MM.panelDark.opacity(0.95), MM.bgDeep.opacity(0.95)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(revealed ? MM.green.opacity(0.7) : MM.gold.opacity(0.35), lineWidth: 2.5))
                .shadow(color: .black.opacity(0.45), radius: 22, y: 14)
        )
        .overlay(alignment: .topTrailing) {
            if revealed, let ci = w.correctIndex, let opts = w.options, opts.contains(where: { $0.id == ci }) {
                StampView(text: "AUFGELÖST", color: MM.green).offset(x: -30, y: -10)
            }
        }
    }

    @ViewBuilder
    func blackout(_ w: QuestionWall) -> some View {
        VStack(spacing: 14) {
            Text("📺").font(.system(size: 80))
            Text("SENDEAUSFALL").font(.outfit(50, .black)).foregroundStyle(MM.cream)
            Text("Die Frage läuft nur auf den Handys …").font(.poppins(18)).foregroundStyle(MM.cream.opacity(0.7))
            if let dl = w.deadline { CountdownText(deadline: dl) }
        }
        .frame(maxWidth: 1000, minHeight: 300)
        .background(RoundedRectangle(cornerRadius: 26).fill(Color.black).overlay(
            LinearGradient(colors: [MM.red, MM.gold, MM.green, MM.blue, MM.lila, .white, MM.orange], startPoint: .leading, endPoint: .trailing).opacity(0.25).mask(RoundedRectangle(cornerRadius: 26))
        ))
    }

    // MARK: Extras

    var extraView: AnyView {
        switch extra {
        case .none: return AnyView(EmptyView())
        case .sack(let current, let start, let frozen): return AnyView(sackView(current, start, frozen))
        case .bankPot(let pot, let chain, let banked, let lastBanker, let majority, let durchgang): return AnyView(bankView(pot, chain, banked, lastBanker, majority, durchgang))
        case .bomb(let holder, let tension, let passes, let exploded, let durchgang): return AnyView(bombView(holder, tension, passes, exploded, durchgang))
        case .bets(let bets, let teaser, let phase): return AnyView(betsView(bets, teaser, phase))
        case .numberLine(let lo, let hi, let unit, let guesses, let truth, _): return AnyView(NumberLineView(lo: lo, hi: hi, unit: unit, guesses: guesses, truth: truth, players: players).frame(height: 150))
        case .ladder(let items, let correctOrder, let revealedSteps, _, let werte): return AnyView(ladderView(items, correctOrder, revealedSteps, werte))
        case .pixel(_, let level, let maxLevel, let jackpot, let locked): return AnyView(pixelView(level, maxLevel, jackpot, locked))
        case .steal(let thief, let victim, let betrag, let phase, _): return AnyView(stealView(thief, victim, betrag, phase))
        case .lianen(let lengths, let w, let ds): return AnyView(LianenView(lengths: lengths, w: w, deltas: ds, players: players).frame(height: 190))
        case .buzzers(let armed, let order, let lockedOut, let stufe, let wert): return AnyView(buzzersView(armed, order, lockedOut, stufe, wert))
        case .chips(let perOption, let quotes, _): return AnyView(chipsView(perOption, quotes))
        case .auction(let bids, let leader, let endsAt, let phase): return AnyView(auctionView(bids, leader, endsAt, phase))
        case .bluff(let entries, let authors, _, let phase, let truthIndex): return AnyView(bluffView(entries, authors, phase, truthIndex))
        case .duel(let a, let b, let sa, let sb, let maxScore, let bets, let phase, let label): return AnyView(duelView(a, b, sa, sb, maxScore, bets, phase, label))
        case .steps(let labels, let current, let positions, let banked): return AnyView(stepsView(labels, current, positions, banked))
        case .pies(let dirt, let out, let maxDirt): return AnyView(piesView(dirt, out, maxDirt))
        case .telegram(let pairs, let letters, let solved, let wort): return AnyView(telegramView(pairs, letters, solved, wort))
        case .oneVsAll(let solist, let solistCorrect, let crowd, let crowdCorrect, let frage): return AnyView(oneVsAllView(solist, solistCorrect, crowd, crowdCorrect, frage))
        case .song(_, let snippet, _, let songRevealed, let titel, let artist, let video, let hint): return AnyView(songView(snippet, songRevealed, titel, artist, video, hint))
        case .card(let title, let lines): return AnyView(VStack(spacing: 4) { Text(title).font(.outfit(22, .bold)).foregroundStyle(MM.gold); ForEach(lines, id: \.self) { Text($0).font(.poppins(14)).foregroundStyle(MM.cream) } })
        }
    }

    @ViewBuilder
    func sackView(_ current: Int, _ start: Int, _ frozen: [PlayerId: Int]) -> some View {

            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("💰").font(.system(size: CGFloat(40 + 50 * Double(current) / Double(max(1, start)))))
                    Text(Money.format(current)).font(.outfit(30, .black)).foregroundStyle(MM.gold).contentTransition(.numericText())
                    Text("Sack schrumpft …").font(.poppins(12)).foregroundStyle(MM.cream.opacity(0.7))
                }
                ForEach(players.filter { frozen[$0.id] != nil }) { p in
                    VStack(spacing: 2) { Text("🧊").font(.system(size: 26)); Text(p.name).font(.poppins(12, .bold)); Text(Money.format(frozen[p.id] ?? 0)).font(.outfit(16, .black)).foregroundStyle(MM.gold) }.foregroundStyle(MM.cream)
                }
            }.padding(.top, 6)
    }

    @ViewBuilder
    func bankView(_ pot: Int, _ chain: Int, _ banked: [PlayerId: Int], _ lastBanker: PlayerId?, _ majority: Bool?, _ durchgang: Int) -> some View {

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("🏦").font(.system(size: 50))
                    Text("POTT").font(.poppins(11, .bold)).tracking(2).foregroundStyle(MM.gold)
                    Text(Money.format(pot)).font(.outfit(44, .black)).foregroundStyle(MM.gold).contentTransition(.numericText())
                    HStack(spacing: 4) { ForEach(Array(Affenbank.chain.enumerated()), id: \.offset) { i, v in Text("\(v)").font(.poppins(11, .bold)).padding(.horizontal, 6).padding(.vertical, 3).background(Capsule().fill(i <= chain && pot > 0 ? MM.gold : Color.black.opacity(0.3))).foregroundStyle(i <= chain && pot > 0 ? MM.ink : MM.cream.opacity(0.6)) } }
                    Text("Durchgang \(durchgang)/2").font(.poppins(12)).foregroundStyle(MM.cream.opacity(0.7))
                    if let m = majority { Text(m ? "✅ Mehrheit richtig — Pott wächst!" : "❌ Mehrheit falsch — Pott verbrennt!").font(.poppins(14, .bold)).foregroundStyle(m ? MM.green : MM.red) }
                }
                .padding(16).background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.3)))
                if let b = lastBanker, let p = players.first(where: { $0.id == b }) {
                    Text("\(p.name.uppercased()) SICHERT SICH \(Money.format(banked[b] ?? 0))!").font(.outfit(24, .black)).foregroundStyle(MM.gold).bouncy().id(banked[b] ?? 0)
                }
            }
    }

    @ViewBuilder
    func bombView(_ holder: PlayerId?, _ tension: Double, _ passes: Int, _ exploded: PlayerId?, _ durchgang: Int) -> some View {

            HStack(spacing: 24) {
                if let h = holder, let p = players.first(where: { $0.id == h }) {
                    VStack(spacing: 4) {
                        Text(exploded != nil ? "💥" : "💣").font(.system(size: 80 + CGFloat(tension) * 30)).scaleEffect(1 + CGFloat(sin(Date().timeIntervalSince1970 * (4 + tension * 8))) * 0.05 * CGFloat(tension))
                        Text(exploded != nil ? "\(p.name) IST MATSCHIG!" : "\(p.name) hält die Stinkbanane").font(.outfit(26, .black)).foregroundStyle(exploded != nil ? MM.red : MM.cream)
                        Text("Durchgang \(durchgang)/2 · \(passes) Weitergaben").font(.poppins(13)).foregroundStyle(MM.cream.opacity(0.7))
                    }
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.black.opacity(0.35))
                        Capsule().fill(LinearGradient(colors: [MM.green, MM.gold, MM.red], startPoint: .leading, endPoint: .trailing)).frame(width: geo.size.width * tension)
                    }
                }.frame(height: 14).frame(maxWidth: 400)
            }
    }

    @ViewBuilder
    func betsView(_ bets: [Bet], _ teaser: String?, _ phase: String) -> some View {

            VStack(spacing: 10) {
                if let t = teaser, phase == "setzen" || phase == "reveal" { Text(t).font(.outfit(34, .black)).foregroundStyle(MM.gold) }
                Text(phase == "setzen" ? "Alle setzen GEHEIM …" : (phase == "reveal" ? "EINSÄTZE WERDEN AUFGEDECKT" : "Einsätze")).font(.poppins(16, .bold)).foregroundStyle(MM.cream.opacity(0.8))
                HStack(spacing: 18) {
                    ForEach(bets, id: \.playerId) { b in
                        if let p = players.first(where: { $0.id == b.playerId }) {
                            VStack(spacing: 4) {
                                Text(b.revealed ? "💰" : "❓").font(.system(size: 40)).rotation3DEffect(.degrees(b.revealed ? 0 : 180), axis: (x: 0, y: 1, z: 0)).animation(.spring(response: 0.4, dampingFraction: 0.75), value: b.revealed)
                                Text(p.name).font(.poppins(13, .bold)).foregroundStyle(MM.cream)
                                Text(b.revealed ? Money.format(b.betrag) : "· · ·").font(.outfit(20, .black)).foregroundStyle(MM.gold)
                            }
                        }
                    }
                }
            }
    }

    @ViewBuilder
    func ladderView(_ items: [String], _ correctOrder: [Int], _ revealedSteps: Int, _ werte: [String]) -> some View {

            HStack(alignment: .bottom, spacing: 14) {
                ForEach(Array(correctOrder.enumerated()), id: \.offset) { i, idx in
                    VStack(spacing: 4) {
                        Text(revealedSteps > i ? items[idx] : "?").font(.outfit(18, .bold)).foregroundStyle(MM.cream).lineLimit(2).multilineTextAlignment(.center)
                        if revealedSteps > i, werte.indices.contains(i) { Text(werte[i]).font(.poppins(12, .semibold)).foregroundStyle(MM.gold) }
                        RoundedRectangle(cornerRadius: 8).fill(revealedSteps > i ? MM.green : MM.wood).frame(width: 150, height: CGFloat(30 + i * 22)).overlay(Text("\(i + 1)").font(.outfit(22, .black)).foregroundStyle(MM.ink))
                    }
                }
            }
    }

    @ViewBuilder
    func pixelView(_ level: Int, _ maxLevel: Int, _ jackpot: Int, _ locked: [PlayerId]) -> some View {

            HStack(spacing: 14) {
                Chip(text: "Stufe \(level)/\(maxLevel)")
                Text("Jackpot jetzt: \(Money.format(jackpot))").font(.outfit(26, .black)).foregroundStyle(MM.gold).contentTransition(.numericText())
                ForEach(players.filter { locked.contains($0.id) }) { p in Text("🙈 \(p.name)").font(.poppins(13, .bold)).foregroundStyle(MM.cream) }
            }
    }

    @ViewBuilder
    func stealView(_ thief: PlayerId?, _ victim: PlayerId?, _ betrag: Int, _ phase: String) -> some View {

            if let t = thief, let tp = players.first(where: { $0.id == t }) {
                HStack(spacing: 30) {
                    VStack { Text("🦝").font(.system(size: 50)); Text(tp.name).font(.outfit(20, .bold)).foregroundStyle(MM.cream); Text("der Dieb").font(.poppins(12)).foregroundStyle(MM.cream.opacity(0.7)) }
                    if phase == "opferwahl" { Text("wählt ein Opfer …").font(.outfit(24, .bold)).foregroundStyle(MM.gold) }
                    if let v = victim, let vp = players.first(where: { $0.id == v }) {
                        Text("→  \(betrag > 0 ? Money.format(betrag) : "🛡️ geblockt")  →").font(.outfit(28, .black)).foregroundStyle(betrag > 0 ? MM.gold : MM.blue).bouncy()
                        VStack { MonkeyImage(avatar: Avatar(wire: vp.avatar), face: betrag > 0 ? "frust" : "jubel").frame(height: 90); Text(vp.name).font(.outfit(20, .bold)).foregroundStyle(MM.cream) }
                    }
                }
            } else if !revealed { Text("Die SCHNELLSTE richtige Antwort darf klauen!").font(.poppins(16, .bold)).foregroundStyle(MM.gold) }
    }

    @ViewBuilder
    func buzzersView(_ armed: Bool, _ order: [PlayerId], _ lockedOut: [PlayerId], _ stufe: String?, _ wert: Int) -> some View {

            HStack(spacing: 14) {
                Text(armed ? "🔔 BUZZER FREI" : "🔕").font(.outfit(24, .black)).foregroundStyle(armed ? MM.green : MM.cream.opacity(0.6))
                if let s = stufe { Chip(text: s, gold: true) }
                Text(Money.format(wert)).font(.outfit(22, .black)).foregroundStyle(MM.gold)
                ForEach(Array(order.enumerated()), id: \.offset) { i, pid in if let p = players.first(where: { $0.id == pid }) { Chip(text: "\(i + 1). \(p.name)", gold: i == 0) } }
                ForEach(players.filter { lockedOut.contains($0.id) }) { p in Chip(text: "🚫 \(p.name)") }
            }
    }

    @ViewBuilder
    func chipsView(_ perOption: [Int], _ quotes: [Double]?) -> some View {

            HStack(spacing: 18) {
                ForEach(Array(perOption.enumerated()), id: \.offset) { i, n in
                    VStack(spacing: 2) {
                        Text(["A", "B", "C", "D", "E", "F"][min(i, 5)]).font(.outfit(18, .black)).foregroundStyle(MM.ink).frame(width: 34, height: 34).background(RoundedRectangle(cornerRadius: 8).fill(MM.optionColors[i % MM.optionColors.count]))
                        Text("\(n) 🪙").font(.poppins(14, .bold)).foregroundStyle(MM.cream)
                        if let q = quotes, q.indices.contains(i) { Text(String(format: "×%.2f", q[i])).font(.poppins(12, .semibold)).foregroundStyle(MM.gold) }
                    }
                }
            }
    }

    @ViewBuilder
    func auctionView(_ bids: [PlayerId: Int], _ leader: PlayerId?, _ endsAt: Millis?, _ phase: String) -> some View {

            VStack(spacing: 8) {
                Text(phase == "bieten" ? "🔨 VERDECKT BIETEN …" : (leader.flatMap { l in players.first { $0.id == l } }.map { "ZUSCHLAG: \($0.name.uppercased())" } ?? "")).font(.outfit(30, .black)).foregroundStyle(MM.gold)
                if phase == "bieten" { CountdownText(deadline: endsAt) }
                HStack(spacing: 14) { ForEach(players) { p in VStack { Text(p.name).font(.poppins(13, .bold)); Text(bids[p.id].map { Money.format($0) } ?? (phase == "bieten" ? "…" : "—")).font(.outfit(18, .black)).foregroundStyle(MM.gold) }.foregroundStyle(MM.cream) } }
            }
    }

    @ViewBuilder
    func bluffView(_ entries: [ChoiceOption], _ authors: [Int: PlayerId]?, _ phase: String, _ truthIndex: Int?) -> some View {

            VStack(spacing: 8) {
                Text(phase == "luegen" ? "🤥 Alle erfinden eine Lüge …" : (phase == "raten" ? "Welche ist die Wahrheit?" : "Auflösung")).font(.outfit(26, .black)).foregroundStyle(MM.gold)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(entries) { e in
                        VStack(spacing: 4) {
                            Text(e.text).font(.poppins(16, .bold)).foregroundStyle(MM.cream).lineLimit(2)
                            if truthIndex == e.id { Text("✅ WAHRHEIT").font(.poppins(12, .bold)).foregroundStyle(MM.green) }
                            else if let a = authors?[e.id], let p = players.first(where: { $0.id == a }) { Text("Lüge von \(p.name)").font(.poppins(12)).foregroundStyle(MM.red) }
                            if let c = e.count { Text("\(c) Stimmen").font(.poppins(11)).foregroundStyle(MM.cream.opacity(0.7)) }
                        }
                        .padding(10).frame(maxWidth: .infinity).background(RoundedRectangle(cornerRadius: 12).fill(truthIndex == e.id ? MM.green.opacity(0.25) : Color.black.opacity(0.3)))
                    }
                }.frame(maxWidth: 1000)
            }
    }

    @ViewBuilder
    func duelView(_ a: PlayerId, _ b: PlayerId, _ sa: Int, _ sb: Int, _ maxScore: Int, _ bets: [PlayerId: PlayerId], _ phase: String, _ label: String) -> some View {

            HStack(spacing: 30) {
                if let pa = players.first(where: { $0.id == a }) { PodiumPlayer(player: pa, face: sa > sb ? "jubel" : "denk", size: 120, showBalance: false) }
                VStack(spacing: 6) {
                    Text("\(sa) : \(sb)").font(.outfit(56, .black)).foregroundStyle(MM.gold).contentTransition(.numericText())
                    Text(label).font(.poppins(16, .bold)).foregroundStyle(MM.cream)
                    if phase == "wetten" { Text("Zuschauer wetten 50 MM …").font(.poppins(13)).foregroundStyle(MM.cream.opacity(0.7)) }
                    if !bets.isEmpty { Text(bets.map { (k, v) in "\(playerName(k)) → \(playerName(v))" }.joined(separator: " · ")).font(.poppins(12)).foregroundStyle(MM.cream.opacity(0.7)) }
                    Text("Best of \(maxScore * 2 - 1)").font(.poppins(11)).foregroundStyle(MM.cream.opacity(0.5))
                }
                if let pb = players.first(where: { $0.id == b }) { PodiumPlayer(player: pb, face: sb > sa ? "jubel" : "denk", size: 120, showBalance: false) }
            }
    }

    @ViewBuilder
    func stepsView(_ labels: [String], _ current: Int, _ positions: [PlayerId: Int], _ banked: [PlayerId: Int]) -> some View {

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(labels.enumerated()), id: \.offset) { i, l in
                    VStack(spacing: 4) {
                        HStack(spacing: -8) { ForEach(players.filter { positions[$0.id] == i + 1 }) { p in MonkeyImage(avatar: Avatar(wire: p.avatar), face: "denk").frame(height: 40) } }.frame(height: 42)
                        RoundedRectangle(cornerRadius: 6).fill(i + 1 == current ? MM.gold : MM.wood).frame(width: 90, height: CGFloat(24 + i * 14)).overlay(Text(l).font(.poppins(10, .bold)).foregroundStyle(MM.ink))
                    }
                }
                VStack { ForEach(players) { p in Text("\(p.name): \(Money.format(banked[p.id] ?? 0))").font(.poppins(12, .semibold)).foregroundStyle(MM.cream) } }
            }
    }

    @ViewBuilder
    func piesView(_ dirt: [PlayerId: Int], _ out: [PlayerId], _ maxDirt: Int) -> some View {

            HStack(spacing: 18) { ForEach(players) { p in VStack(spacing: 2) { MonkeyImage(avatar: Avatar(wire: p.avatar), face: out.contains(p.id) ? "frust" : "neutral").frame(height: 80).opacity(out.contains(p.id) ? 0.45 : 1); Text(String(repeating: "🥧", count: dirt[p.id] ?? 0) + String(repeating: "○", count: max(0, maxDirt - (dirt[p.id] ?? 0)))).font(.system(size: 16)); Text(p.name).font(.poppins(12, .bold)).foregroundStyle(MM.cream) } } }
    }

    @ViewBuilder
    func telegramView(_ pairs: [[PlayerId]], _ letters: [String], _ solved: [Int], _ wort: String?) -> some View {

            VStack(spacing: 10) {
                if !letters.isEmpty {
                    HStack(spacing: 8) { ForEach(Array(letters.enumerated()), id: \.offset) { _, l in Text(l).font(.outfit(44, .black)).foregroundStyle(l == "_" ? MM.cream.opacity(0.3) : MM.cream).frame(width: 52, height: 64).background(RoundedRectangle(cornerRadius: 10).fill(MM.wood)) } }
                    if let w = wort { Text("Das Wort: \(w)").font(.outfit(24, .bold)).foregroundStyle(MM.gold) }
                }
                HStack(spacing: 16) { ForEach(Array(pairs.enumerated()), id: \.offset) { i, pair in HStack(spacing: -6) { ForEach(pair, id: \.self) { pid in if let p = players.first(where: { $0.id == pid }) { MonkeyImage(avatar: Avatar(wire: p.avatar), face: solved.contains(i) ? "jubel" : "denk").frame(height: 60) } } }.padding(6).background(RoundedRectangle(cornerRadius: 12).fill(solved.contains(i) ? MM.green.opacity(0.3) : Color.black.opacity(0.3))) } }
            }
    }

    @ViewBuilder
    func oneVsAllView(_ solist: PlayerId, _ solistCorrect: Bool?, _ crowd: [PlayerId: Int], _ crowdCorrect: Int, _ frage: Int) -> some View {

            HStack(spacing: 30) {
                if let s = players.first(where: { $0.id == solist }) { VStack { Text("👑").font(.system(size: 30)); PodiumPlayer(player: s, face: solistCorrect == true ? "jubel" : (solistCorrect == false ? "frust" : "denk"), size: 120, showBalance: false) } }
                VStack { Text("VS").font(.outfit(40, .black)).foregroundStyle(MM.gold); Text("Frage \(frage) · Menge: \(crowdCorrect) richtig").font(.poppins(13)).foregroundStyle(MM.cream) }
                HStack(spacing: -10) { ForEach(players.filter { crowd[$0.id] != nil }) { p in MonkeyImage(avatar: Avatar(wire: p.avatar)).frame(height: 70) } }
            }
    }

    @ViewBuilder
    func songView(_ snippet: String, _ songRevealed: Bool, _ titel: String?, _ artist: String?, _ video: Bool, _ hint: [String]?) -> some View {

            VStack(spacing: 8) {
                if video, !songRevealed { Text("🎬 Stummfilm läuft: \(hint?.joined(separator: " ") ?? "")").font(.system(size: 44)) }
                else if !songRevealed { Text("🎧").font(.system(size: 60)).scaleEffect(1.05); Text("Ohren auf! (\(snippet))").font(.poppins(16, .bold)).foregroundStyle(MM.gold) }
                if songRevealed, let t = titel { Text("♫ \(t)").font(.outfit(32, .black)).foregroundStyle(MM.gold); Text(artist ?? "").font(.poppins(18)).foregroundStyle(MM.cream) }
            }
    }

    func playerName(_ id: PlayerId) -> String { players.first { $0.id == id }?.name ?? "?" }

    // MARK: Podiums

    var podiums: some View {
        HStack(alignment: .bottom, spacing: players.count > 5 ? 10 : 22) {
            ForEach(players) { p in
                PodiumPlayer(player: p, face: revealed ? ((deltas[p.id] ?? 0) > 0 ? "jubel" : ((deltas[p.id] ?? 0) < 0 ? "frust" : "neutral")) : (wall?.answered.contains(p.id) == true ? "neutral" : "denk"),
                             delta: revealed ? deltas[p.id] : nil, size: players.count > 5 ? 88 : 110)
                    .overlay(alignment: .top) { if !revealed, wall?.answered.contains(p.id) == true { Text("✓").font(.outfit(22, .black)).foregroundStyle(MM.green).offset(y: -18) } }
            }
        }
        .padding(.bottom, 4)
    }
}

/// One answer tile on the wall (letter badge, emoji, count after reveal).
struct OptionTile: View {
    var index: Int
    var option: ChoiceOption
    var correct: Bool
    var revealed: Bool
    var count: Int?
    var players: [PlayerRef]

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(MM.optionColors[index % MM.optionColors.count]).frame(width: 46, height: 46)
                Text(["A", "B", "C", "D", "E", "F", "G", "H"][index % 8]).font(.outfit(24, .black)).foregroundStyle(MM.ink)
            }
            Text(MM.optionEmojis[index % MM.optionEmojis.count]).font(.system(size: 22))
            Text(option.text).font(.outfit(24, .bold)).foregroundStyle(MM.cream).lineLimit(2).minimumScaleFactor(0.7)
            Spacer()
            if revealed {
                HStack(spacing: -8) { ForEach(players) { p in MonkeyImage(avatar: Avatar(wire: p.avatar), face: correct ? "jubel" : "frust").frame(height: 38) } }
                if correct { Image(systemName: "checkmark.circle.fill").font(.system(size: 28, weight: .black)).foregroundStyle(MM.green) }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(revealed && correct ? MM.green.opacity(0.25) : Color.black.opacity(0.3))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(revealed && correct ? MM.green : Color.white.opacity(0.12), lineWidth: revealed && correct ? 3 : 1))
        )
        .opacity(option.removed || (revealed && !correct) ? 0.45 : 1)
        .scaleEffect(revealed && correct ? 1.03 : 1)
        .animation(.spring(response: 0.4), value: revealed)
    }
}

/// Pixelated image reveal (8 steps) for Pixel-Dschungel.
struct PixelImage: View {
    var name: String
    var level: Int
    var maxLevel: Int

    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: (name as NSString).deletingPathExtension, withExtension: (name as NSString).pathExtension, subdirectory: "Content/pixel"), let ui = UIImage(contentsOfFile: url.path) {
                let block = max(1, 48 - level * 6)
                Image(uiImage: PixelImage.pixelate(ui, block: level >= maxLevel ? 1 : block))
                    .interpolation(.none).resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(MM.gold.opacity(0.5), lineWidth: 3))
                    .animation(.easeInOut(duration: 0.4), value: level)
            } else { Text("🖼️").font(.system(size: 80)) }
        }
    }

    static func pixelate(_ img: UIImage, block: Int) -> UIImage {
        guard block > 1, let cg = img.cgImage else { return img }
        let w = max(1, cg.width / block), h = max(1, cg.height / block)
        let small = UIGraphicsImageRenderer(size: CGSize(width: w, height: h)).image { ctx in
            img.draw(in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return small
    }
}

/// Number line for the estimate round.
struct NumberLineView: View {
    var lo: Double; var hi: Double; var unit: String; var guesses: [Guess]; var truth: Double?; var players: [PlayerRef]
    func x(_ v: Double, _ w: CGFloat) -> CGFloat { CGFloat((v - lo) / max(0.0001, hi - lo)) * (w - 40) + 20 }
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Capsule().fill(MM.wood).frame(height: 10).offset(y: 80)
                Text(fmt(lo)).font(.poppins(12, .bold)).foregroundStyle(MM.cream).position(x: 20, y: 105)
                Text(fmt(hi)).font(.poppins(12, .bold)).foregroundStyle(MM.cream).position(x: geo.size.width - 20, y: 105)
                ForEach(guesses, id: \.playerId) { g in
                    if let p = players.first(where: { $0.id == g.playerId }) {
                        VStack(spacing: 0) {
                            MonkeyImage(avatar: Avatar(wire: p.avatar), face: g.platz == 1 ? "jubel" : "neutral").frame(height: 50)
                            Text(fmt(g.value)).font(.poppins(11, .bold)).foregroundStyle(MM.cream)
                            if let pl = g.platz { Text("#\(pl)").font(.outfit(12, .black)).foregroundStyle(MM.gold) }
                        }.position(x: x(g.value, geo.size.width), y: 40)
                    }
                }
                if let t = truth {
                    VStack(spacing: 0) {
                        Text("▲").font(.system(size: 22)).foregroundStyle(MM.gold)
                        Text("\(fmt(t)) \(unit)").font(.outfit(20, .black)).foregroundStyle(MM.gold)
                    }.position(x: x(t, geo.size.width), y: 130).bouncy()
                }
            }
        }
    }
    func fmt(_ v: Double) -> String { v == v.rounded() ? Money.formatNumber(Int(v)) : String(format: "%.1f", v) }
}

/// Lianen-Finale: everyone hangs on a liana over the crocodile river.
struct LianenView: View {
    var lengths: [PlayerId: Double]; var w: Int; var deltas: [PlayerId: Int]; var players: [PlayerRef]
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Rectangle().fill(LinearGradient(colors: [MM.blue.opacity(0.3), MM.blue.opacity(0.6)], startPoint: .top, endPoint: .bottom)).frame(height: 40).offset(y: geo.size.height / 2 - 20)
                Text("🐊").font(.system(size: 34)).position(x: geo.size.width * 0.5, y: geo.size.height - 18)
                HStack(alignment: .top, spacing: 0) {
                    ForEach(players) { p in
                        let len = lengths[p.id] ?? 0.5
                        VStack(spacing: 0) {
                            Rectangle().fill(MM.green).frame(width: 6, height: max(10, (geo.size.height - 80) * (1 - len)))
                            MonkeyImage(avatar: Avatar(wire: p.avatar), face: (deltas[p.id] ?? 0) < 0 ? "frust" : "jubel").frame(height: 60)
                            Text(p.name).font(.poppins(11, .bold)).foregroundStyle(MM.cream)
                            if let d = deltas[p.id], d != 0 { Text(Money.formatDelta(d)).font(.outfit(14, .black)).foregroundStyle(d > 0 ? MM.green : MM.red) }
                        }.frame(maxWidth: .infinity)
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: len)
                    }
                }
                Text("Jede Frage: ±\(Money.format(w))").font(.poppins(12, .bold)).foregroundStyle(MM.gold).position(x: 110, y: 14)
            }
        }
    }
}
