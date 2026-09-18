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

    /// Wall width on the 1180-pt stage canvas (wings are 150 pt each side).
    static let wallWidth: CGFloat = 860

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0).frame(maxHeight: 26)
            if let w = wall, !w.blackout {
                wallView(w)
            } else if let w = wall, w.blackout {
                blackout(w)
            }
            extraView
                .frame(maxWidth: Self.wallWidth)
            Spacer(minLength: 0)
            podiums
        }
        .padding(.horizontal, 8)
        .overlay(alignment: .top) {
            if revealed, deltas.values.contains(where: { $0 > 0 }) { ParticleRain(kind: .money, count: deltas.values.contains(where: { $0 >= 750 }) ? 90 : 36, duration: 3.5) }
            if revealed, deltas.values.contains(where: { $0 >= 750 }) { ParticleRain(kind: .coins, count: 40, duration: 3) }
            if revealed, case .bomb(_, _, _, let exploded, _) = extra, exploded != nil { ParticleRain(kind: .mud, count: 40, duration: 2.5) }
        }
    }

    var correctCount: Int {
        guard let w = wall, let ci = w.correctIndex else { return 0 }
        return w.answersByPlayer.values.filter { $0 == ci }.count
    }

    // MARK: Wall

    @ViewBuilder
    func wallView(_ w: QuestionWall) -> some View {
        VStack(spacing: 10) {
            ZStack {
                HStack(spacing: 8) {
                    Text("\(w.kategorieEmoji) \(w.kategorieName)").font(.poppins(14, .semibold)).foregroundStyle(MM.cream)
                    Text("·").foregroundStyle(MM.cream.opacity(0.5))
                    Text(w.schwierigkeit.label).font(.poppins(13, .medium)).foregroundStyle(MM.cream.opacity(0.8))
                    if w.schwierigkeit == .ultrahard { Image(systemName: "flame.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(MM.orange) }
                    if !title.isEmpty { Text("· \(title)").font(.poppins(13, .medium)).foregroundStyle(MM.cream.opacity(0.8)) }
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.3)).overlay(Capsule().strokeBorder(Color.white.opacity(0.1))))
                HStack {
                    HStack(spacing: 6) {
                        if kind == .jackpot { Text("💰").font(.system(size: 16)) } else { Coin(size: 18) }
                        Text(kind == .jackpot ? "JACKPOT · \(Money.format(w.wert))" : Money.format(w.wert)).font(.outfit(18, .black)).foregroundStyle(MM.ink)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(MM.gold).shadow(color: MM.goldDark, radius: 0, y: 3))
                    Spacer()
                    if !revealed, let dl = w.deadline {
                        ZStack {
                            Circle().fill(MM.bgDeep.opacity(0.85)).frame(width: 64, height: 64)
                            Circle().stroke(Color.black.opacity(0.5), lineWidth: 6).frame(width: 58, height: 58)
                            TimelineView(.animation(minimumInterval: 0.1)) { _ in
                                let remain = max(0, Double(dl - ServerClock.now()))
                                let frac = min(1, remain / Double(max(1, w.timerMs)))
                                Circle().trim(from: 0, to: frac)
                                    .stroke(remain < 5000 ? MM.red : MM.gold, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                    .rotationEffect(.degrees(-90)).frame(width: 58, height: 58)
                                    .shadow(color: (remain < 5000 ? MM.red : MM.gold).opacity(0.6), radius: 6)
                                    .scaleEffect(remain < 5000 && Int(remain / 500) % 2 == 0 ? 1.06 : 1)
                            }
                            Image(systemName: "stopwatch.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(MM.cream.opacity(0.7)).offset(y: -20)
                            CountdownText(deadline: dl, font: .outfit(22, .black)).offset(y: 3)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else if !revealed {
                        Chip(text: "kein Timer", icon: "timer")
                    }
                }
            }
            if let img = w.image, w.pixelLevel != nil || minigameId == "pixel-dschungel" {
                PixelImage(name: img, level: w.pixelLevel ?? 8, maxLevel: 8).frame(height: 230)
            }
            Text(w.text).font(.outfit(w.text.count > 90 ? 32 : 40, .black)).foregroundStyle(MM.cream).multilineTextAlignment(.center).lineSpacing(4)
                .frame(maxWidth: Self.wallWidth).padding(.horizontal, 16)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
            if let opts = w.options {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Array(opts.enumerated()), id: \.element.id) { i, o in
                        OptionTile(index: i, option: o, correct: w.correctIndex == o.id, revealed: w.revealed, count: o.count, players: revealed ? players.filter { w.answersByPlayer[$0.id] == o.id } : [])
                            .bouncy(delay: revealed ? 0 : 0.08 + Double(i) * 0.07)
                    }
                }
                .frame(maxWidth: Self.wallWidth)
            }
            if revealed, let e = w.erklaerung, !e.isEmpty {
                HStack(alignment: .center, spacing: 14) {
                    Text(w.kategorieEmoji).font(.system(size: 26)).frame(width: 48, height: 48).background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.35)))
                    Text(e).font(.poppins(18)).foregroundStyle(MM.cream).lineSpacing(3).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14).frame(maxWidth: Self.wallWidth)
                .background(RoundedRectangle(cornerRadius: 16).fill(MM.cream.opacity(0.08)).overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MM.gold.opacity(0.35))))
                .bouncy(delay: 0.35)
            } else if let t = w.tipp {
                Text("💡 \(t)").font(.poppins(17, .semibold)).foregroundStyle(MM.gold)
            }
            if !revealed, w.options != nil {
                HStack(spacing: 8) {
                    ForEach(players) { p in
                        Circle().fill(w.answered.contains(p.id) ? MM.green : Color.black.opacity(0.4)).frame(width: 16, height: 16)
                            .overlay(Circle().strokeBorder(MM.playerColor(Avatar(wire: p.avatar).farbe), lineWidth: 2))
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: w.answered.contains(p.id))
                    }
                    Text("\(w.answered.count)/\(players.count) geantwortet").font(.poppins(13, .semibold)).foregroundStyle(MM.cream.opacity(0.75))
                }
            }
        }
        .padding(22)
        .frame(maxWidth: Self.wallWidth + 44)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [MM.panelDark.opacity(0.95), MM.bgDeep.opacity(0.95)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(revealed ? MM.green.opacity(0.7) : MM.gold.opacity(0.35), lineWidth: 2.5))
                .shadow(color: .black.opacity(0.45), radius: 22, y: 14)
        )
        .overlay(alignment: .topTrailing) {
            if revealed, let ci = w.correctIndex, let opts = w.options, opts.contains(where: { $0.id == ci }) {
                let n = correctCount
                StampView(text: n == 0 ? "FALSCH!" : (n == players.count ? "ALLE RICHTIG!" : "RICHTIG!"), color: n == 0 ? MM.red : MM.green).offset(x: 24, y: -18)
            } else if revealed, w.options == nil {
                StampView(text: "AUFGELÖST", color: MM.gold).offset(x: 24, y: -18)
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
        .frame(maxWidth: Self.wallWidth + 44, minHeight: 300)
        .background(RoundedRectangle(cornerRadius: 26).fill(Color.black).overlay(
            LinearGradient(colors: [MM.red, MM.gold, MM.green, MM.blue, MM.lila, .white, MM.orange], startPoint: .leading, endPoint: .trailing).opacity(0.25).mask(RoundedRectangle(cornerRadius: 26))
        ))
    }

    // MARK: Extras

    var extraView: AnyView {
        switch extra {
        case .none: return AnyView(EmptyView())
        case .sack(let current, let start, let frozen): return AnyView(sackView(current, start, frozen))
        case .bankPot(let pot, let chain, let step, let banked, let lastBanker, let verdict, let durchgang, let durchgaenge, let runEndsAt, let letzteFrage, let gongFor):
            return AnyView(bankView(pot, chain, step, banked, lastBanker, verdict, durchgang, durchgaenge, runEndsAt, letzteFrage, gongFor))
        case .bomb(let holder, let tension, let passes, let exploded, let durchgang): return AnyView(bombView(holder, tension, passes, exploded, durchgang))
        case .bets(let bets, let teaser, let phase): return AnyView(betsView(bets, teaser, phase))
        case .numberLine(let lo, let hi, let unit, let guesses, let truth, _):
            return AnyView(
                NumberLineView(lo: lo, hi: hi, unit: unit, guesses: guesses, truth: truth, players: players)
                    .frame(height: 176).padding(.horizontal, 24).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.3)).overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(MM.gold.opacity(0.25))))
            )
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
    func bankView(_ pot: Int, _ chain: [Int], _ step: Int, _ banked: [PlayerId: Int], _ lastBanker: PlayerId?, _ verdict: String?,
                  _ durchgang: Int, _ durchgaenge: Int, _ runEndsAt: Millis, _ letzteFrage: Bool, _ gongFor: [PlayerId]) -> some View {
        HStack(spacing: 24) {
            VStack(spacing: 4) {
                HStack(spacing: 10) {
                    Text("🏦").font(.system(size: 44))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("POTT").font(.poppins(11, .bold)).tracking(2).foregroundStyle(MM.gold)
                        Text(Money.format(pot)).font(.outfit(44, .black)).foregroundStyle(MM.gold).contentTransition(.numericText())
                    }
                }
                HStack(spacing: 4) {
                    ForEach(Array(chain.enumerated()), id: \.offset) { i, v in
                        Text("\(v)").font(.poppins(12, .bold)).padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(i <= step && pot > 0 ? MM.gold : Color.black.opacity(0.3)))
                            .foregroundStyle(i <= step && pot > 0 ? MM.ink : MM.cream.opacity(0.6))
                    }
                }
                HStack(spacing: 8) {
                    if durchgaenge > 1 { Text("Durchgang \(durchgang)/\(durchgaenge)").font(.poppins(12)).foregroundStyle(MM.cream.opacity(0.7)) }
                    Text("⏱").font(.system(size: 12)).foregroundStyle(MM.cream.opacity(0.7))
                    CountdownText(deadline: runEndsAt, font: .outfit(16, .black))
                }
                if let v = verdict {
                    Text(v == "waechst" ? "✅ Mehrheit richtig — Pott wächst!" : (v == "haelt" ? "🤝 Unentschieden — Pott hält" : "❌ Mehrheit falsch — Pott verbrennt!"))
                        .font(.poppins(14, .bold)).foregroundStyle(v == "waechst" ? MM.green : (v == "haelt" ? MM.gold : MM.red))
                } else if letzteFrage, pot > 0 {
                    Text("⏳ LETZTE FRAGE — BANK jetzt oder nie!").font(.poppins(14, .bold)).foregroundStyle(MM.orange)
                }
            }
            .padding(16).background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.3)))
            if !gongFor.isEmpty {
                Text("🔔 SCHLUSS-GONG: \(gongFor.compactMap { id in players.first { $0.id == id }?.name }.joined(separator: ", ")) sichern den Pott!").font(.outfit(22, .black)).foregroundStyle(MM.gold).bouncy()
            } else if let b = lastBanker, let p = players.first(where: { $0.id == b }) {
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

    /// Podium row — the monkeys are the stars: 150 pt for up to four, smaller for a full house.
    static func podiumSize(_ count: Int) -> CGFloat { count <= 4 ? 150 : (count <= 6 ? 118 : 94) }

    var podiums: some View {
        let size = Self.podiumSize(players.count)
        return HStack(alignment: .bottom, spacing: players.count > 6 ? 8 : (players.count > 4 ? 14 : 28)) {
            ForEach(players) { p in
                let d = deltas[p.id] ?? 0
                PodiumPlayer(player: p, face: revealed ? (d > 0 ? "jubel" : (d < 0 ? "frust" : "neutral")) : (wall?.answered.contains(p.id) == true ? "neutral" : "denk"),
                             delta: revealed ? deltas[p.id] : nil, size: size, morph: true)
                    .overlay(alignment: .top) {
                        if !revealed, wall?.answered.contains(p.id) == true {
                            Text("✓").font(.outfit(size * 0.18, .black)).foregroundStyle(MM.ink).frame(width: size * 0.24, height: size * 0.24)
                                .background(Circle().fill(MM.green).shadow(color: .black.opacity(0.4), radius: 4, y: 2)).offset(y: -size * 0.12)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.6), value: wall?.answered.contains(p.id) == true)
                    .scaleEffect(revealed && d > 0 ? 1.04 : 1)
                    .animation(.spring(response: 0.4, dampingFraction: 0.65), value: revealed)
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
        let tint = MM.optionColors[index % MM.optionColors.count]
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3).fill(revealed && correct ? MM.green : tint).frame(width: 6).padding(.vertical, 2)
            Text(["A", "B", "C", "D", "E", "F", "G", "H"][index % 8]).font(.outfit(26, .black)).foregroundStyle(revealed && correct ? MM.cream : tint).frame(width: 28)
            Text(MM.optionEmojis[index % MM.optionEmojis.count]).font(.system(size: 24))
            Text(option.text).font(.outfit(26, .bold)).foregroundStyle(MM.cream).lineLimit(2).minimumScaleFactor(0.7).strikethrough(option.removed, color: MM.red)
            Spacer()
            if revealed {
                HStack(spacing: -10) { ForEach(players) { p in MonkeyImage(avatar: Avatar(wire: p.avatar), face: correct ? "jubel" : "frust").frame(height: 44) } }
                if correct { Image(systemName: "checkmark.circle.fill").font(.system(size: 30, weight: .black)).foregroundStyle(MM.cream).background(Circle().fill(MM.green).padding(3)) }
            } else if option.removed {
                Image(systemName: "xmark").font(.system(size: 18, weight: .black)).foregroundStyle(MM.red.opacity(0.8))
            }
        }
        .padding(.leading, 10).padding(.trailing, 14).padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(revealed && correct ? MM.green.opacity(0.32) : Color(hex: "#123D2A").opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(revealed && correct ? MM.green : Color.white.opacity(0.1), lineWidth: revealed && correct ? 3 : 1))
                .shadow(color: revealed && correct ? MM.green.opacity(0.45) : .black.opacity(0.25), radius: revealed && correct ? 16 : 6, y: 4)
        )
        .opacity(option.removed || (revealed && !correct) ? 0.42 : 1)
        .scaleEffect(revealed && correct ? 1.03 : 1)
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: revealed)
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
    func x(_ v: Double, _ w: CGFloat) -> CGFloat { CGFloat((v - lo) / max(0.0001, hi - lo)) * (w - 60) + 30 }
    var body: some View {
        GeometryReader { geo in
            let lineY: CGFloat = 108
            ZStack(alignment: .topLeading) {
                Capsule().fill(LinearGradient(colors: [MM.wood, Color(hex: "#6B4527")], startPoint: .top, endPoint: .bottom)).frame(height: 12).offset(y: lineY - 6)
                    .overlay(alignment: .leading) { Capsule().fill(MM.gold.opacity(0.35)).frame(width: 4, height: 24).offset(x: 28, y: lineY - 12) }
                    .overlay(alignment: .trailing) { Capsule().fill(MM.gold.opacity(0.35)).frame(width: 4, height: 24).offset(x: -28, y: lineY - 12) }
                Text(fmt(lo)).font(.poppins(14, .bold)).foregroundStyle(MM.cream).position(x: 30, y: lineY + 24)
                Text(fmt(hi)).font(.poppins(14, .bold)).foregroundStyle(MM.cream).position(x: geo.size.width - 30, y: lineY + 24)
                if guesses.isEmpty {
                    Text("Alle schätzen geheim …").font(.poppins(16, .semibold)).foregroundStyle(MM.cream.opacity(0.7)).position(x: geo.size.width / 2, y: 50)
                }
                ForEach(Array(guesses.enumerated()), id: \.element.playerId) { i, g in
                    if let p = players.first(where: { $0.id == g.playerId }) {
                        VStack(spacing: 0) {
                            if let pl = g.platz, pl <= 3 { Text(pl == 1 ? "🥇" : (pl == 2 ? "🥈" : "🥉")).font(.system(size: 20)) }
                            MonkeyImage(avatar: Avatar(wire: p.avatar), face: g.platz == 1 ? "jubel" : (g.platz ?? 9) <= 3 ? "neutral" : "denk").frame(height: 58)
                            Text(fmt(g.value)).font(.outfit(15, .black)).foregroundStyle(MM.ink)
                                .padding(.horizontal, 7).padding(.vertical, 1).background(Capsule().fill(MM.playerColor(Avatar(wire: p.avatar).farbe)))
                            Rectangle().fill(MM.cream.opacity(0.7)).frame(width: 2, height: 10)
                        }
                        .position(x: x(g.value, geo.size.width), y: lineY - 58)
                        .bouncy(delay: Double(i) * 0.12)
                    }
                }
                if let t = truth {
                    VStack(spacing: 0) {
                        Text("▲").font(.system(size: 24)).foregroundStyle(MM.gold)
                        Text("\(fmt(t)) \(unit)").font(.outfit(24, .black)).foregroundStyle(MM.gold).shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                    }.position(x: x(t, geo.size.width), y: lineY + 34).bouncy(delay: 0.5)
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
