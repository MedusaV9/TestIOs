import SwiftUI

/// The stage: header (progress, section, jackpot jar), the current scene,
/// player podiums and the stage controls (▶ Weiter in gmLos mode).
struct StageRootView: View {
    @EnvironmentObject var host: HostModel
    @State private var confirmEnd = false

    var body: some View {
        GeometryReader { geo in
            stageBody(width: geo.size.width)
        }
    }

    /// Side padding that keeps the wall clear of the hanging boards (wide iPads
    /// get the full dressing, narrower ones a slimmer one).
    func sidePadding(width: CGFloat, phase: Phase) -> CGFloat {
        if phase == .lobby || phase == .brettspiel { return 0 }
        return width >= 1000 ? 150 : 118
    }

    @ViewBuilder
    func stageBody(width: CGFloat) -> some View {
        ZStack {
            if let stage = host.stage {
                if stage.phase != .lobby && stage.phase != .brettspiel {
                    StageDecor(jackpot: stage.jackpotAktiv ? stage.jackpotGlas : nil,
                               showCrowd: [.frage, .aufloesung, .siegerehrung, .highlights].contains(stage.phase),
                               showCrates: stage.phase != .rad && stage.phase != .brettspiel)
                        .transition(.opacity)
                }
                VStack(spacing: 0) {
                    stageHeader(stage)
                    ZStack {
                        sceneView(stage)
                            .id(sceneKey(stage))
                            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96)).combined(with: .offset(y: 14)), removal: .opacity))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, sidePadding(width: width, phase: stage.phase))
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: sceneKey(stage))
                    stageFooter(stage)
                }
                momentsBanner(stage)
                if stage.paused, stage.phase != .lobby { pauseOverlay(stage) }
            } else {
                ProgressView().tint(MM.gold)
            }
        }
        .sheet(isPresented: $host.gmPanelOpen) { GmPanelView() }
        .alert("Show wirklich beenden?", isPresented: $confirmEnd) {
            Button("Beenden", role: .destructive) { host.command(.ende) }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    func sceneKey(_ s: StageView) -> String {
        switch s.scene {
        case .frage(_, _, let id, _, _): return "frage-\(id)-\(host.server?.withHub { $0.state.questionIndex } ?? 0)"
        case .aufloesung(_, _, _, let id, _): return "aufloesung-\(id)-\(host.server?.withHub { $0.state.questionIndex } ?? 0)"
        default: return s.phase.rawValue
        }
    }

    // MARK: Header / footer

    @ViewBuilder
    func stageHeader(_ stage: StageView) -> some View {
        VStack(spacing: 6) {
            HostTopBar(showBack: false)
            HStack(spacing: 14) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.black.opacity(0.35))
                        Capsule().fill(MM.gold).frame(width: max(8, geo.size.width * stage.progress))
                            .animation(.easeInOut(duration: 0.6), value: stage.progress)
                    }
                }.frame(height: 6).frame(maxWidth: 260)
                Spacer()
                HStack(spacing: 10) {
                    if let q = questionCounter(stage) { Text(q).font(.poppins(14, .bold)).foregroundStyle(MM.cream) }
                    Text(stage.sectionLabel).font(.poppins(14, .medium)).foregroundStyle(MM.cream.opacity(0.75))
                }
                if !stage.specialRules.isEmpty { Chip(text: stage.specialRules.joined(separator: " · "), icon: "sparkles") }
                if stage.timerAus { Chip(text: "Timer aus", icon: "timer") } else if let z = stage.fragenZeit { Chip(text: "\(z) s pro Frage", icon: "timer") }
                Spacer()
                if stage.affensteuerKiste > 0 { Chip(text: "📦 Kiste \(Money.format(stage.affensteuerKiste))") }
            }
            .padding(.horizontal, 26)
        }
    }

    func questionCounter(_ stage: StageView) -> String? {
        switch stage.scene {
        case .frage(let wall?, _, _, _, _), .aufloesung(let wall?, _, _, _, _):
            return wall.gesamt > 0 ? "Frage \(wall.nummer) / \(wall.gesamt)" : "Frage \(wall.nummer)"
        default: return nil
        }
    }

    @ViewBuilder
    func stageFooter(_ stage: StageView) -> some View {
        ZStack {
            VStack(spacing: 4) {
                Rectangle().fill(MM.cream.opacity(0.12)).frame(height: 1).frame(maxWidth: 560)
                Text("SAME WIFI · REAL FUN · NO SERVER NEEDED").font(.poppins(10, .semibold)).tracking(3).foregroundStyle(MM.cream.opacity(0.45))
            }
            HStack(spacing: 12) {
                if stage.phase == .ende || stage.phase == .siegerehrung {
                    GoldButton(title: "Zur Lobby", icon: "house.fill", style: .ghost, compact: true) { host.command(.revanche) }
                    GoldButton(title: "Spiele-Abend", icon: "dice.fill", style: .ghost, compact: true) { host.command(.settingsSet(["spielModus": .string("spieleabend")])); host.command(.revanche) }
                } else {
                    GoldButton(title: "Einstellungen", icon: "gearshape.fill", style: .ghost, compact: true) { host.gmPanelOpen = true }
                    Button { host.command(stage.paused ? .resume : .pause(text: "🍌 Bananen-Pause", dauerMs: nil)) } label: {
                        Image(systemName: stage.paused ? "play.fill" : "pause.fill").font(.system(size: 15, weight: .black)).foregroundStyle(MM.cream).frame(width: 42, height: 42).background(Circle().fill(Color.black.opacity(0.28)))
                    }.buttonStyle(PressStyle())
                    Button { confirmEnd = true } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .black)).foregroundStyle(MM.cream.opacity(0.8)).frame(width: 42, height: 42).background(Circle().fill(Color.black.opacity(0.28)))
                    }.buttonStyle(PressStyle())
                }
                Spacer()
                if let label = stage.advanceLabel, stage.gmLos || !stage.gmOnline || stage.phase == .lobby {
                    GoldButton(title: label, icon: "play.fill", compact: true) { host.command(.flowNext) }
                        .id(label)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: stage.advanceLabel)
        }
        .padding(.horizontal, 26).padding(.vertical, 12)
    }

    @ViewBuilder
    func momentsBanner(_ stage: StageView) -> some View {
        if let m = stage.moments.last, ServerClock.now() - m.at < 4500, !["sound"].contains(m.art) {
            VStack {
                Spacer()
                HStack(spacing: 10) {
                    if let pid = m.playerId, let p = stage.players.first(where: { $0.id == pid }) { MonkeyImage(avatar: Avatar(wire: p.avatar), face: (m.betrag ?? 0) < 0 ? "frust" : "jubel").frame(height: 54) }
                    Text(m.text).font(.outfit(20, .bold)).foregroundStyle(MM.ink).lineLimit(2)
                }
                .padding(.horizontal, 22).padding(.vertical, 12)
                .background(Capsule().fill(MM.gold).shadow(color: .black.opacity(0.4), radius: 12, y: 8))
                .padding(.bottom, 74)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .id(m.id)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: m.id)
        }
    }

    @ViewBuilder
    func pauseOverlay(_ stage: StageView) -> some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("🍌").font(.system(size: 80)).bouncy()
                Text(stage.paused ? (host.server?.withHub { $0.state.pauseText } ?? "Pause") : "Pause").font(.outfit(48, .black)).foregroundStyle(MM.gold)
                if case .pause(_, let endsAt, let standings) = stage.scene {
                    if let e = endsAt { CountdownText(deadline: e, font: .outfit(40, .black)) }
                    HStack(spacing: 20) { ForEach(standings.prefix(8), id: \.player.id) { e in PodiumPlayer(player: e.player, size: 90) } }
                }
                GoldButton(title: "Weiter geht's", icon: "play.fill") { host.command(.resume) }.frame(width: 320)
            }
        }
    }

    // MARK: Scenes

    @ViewBuilder
    func sceneView(_ stage: StageView) -> some View {
        switch stage.scene {
        case .lobby: LobbyView()
        case .intro(let headline, let rules, _): IntroScene(headline: headline, rules: rules, players: stage.players)
        case .kategorieWahl(let optionen, let letzter, let deadline, _, let gewinner): KategorieScene(optionen: optionen, letzter: letzter, deadline: deadline, gewinner: gewinner, players: stage.players)
        case .erklaerkarte(let card): ExplainScene(card: card, players: stage.players)
        case .frage(let wall, let extra, let minigameId, let kind, let title): QuestionStage(wall: wall, extra: extra, minigameId: minigameId, kind: kind, title: title, players: stage.players, revealed: false, deltas: [:])
        case .aufloesung(let wall, let extra, let deltas, let minigameId, let kind): QuestionStage(wall: wall, extra: extra, minigameId: minigameId, kind: kind, title: "", players: stage.players, revealed: true, deltas: deltas)
        case .zwischenstand(let entries, let r, let total, _, let halbzeit): StandingsScene(entries: entries, runde: r, total: total, halbzeit: halbzeit)
        case .rad(let wheel): WheelScene(wheel: wheel, players: stage.players)
        case .pause: EmptyView()
        case .highlights(let entries, _): HighlightsScene(entries: entries, players: stage.players)
        case .siegerehrung(let podium, let awards, _, _, let abend): CeremonyScene(podium: podium, awards: awards, abend: abend)
        case .ende(let podium): EndScene(podium: podium)
        case .brettspiel(let view): BoardgameStage(view: view, players: stage.players)
        }
    }
}

// MARK: - Intro

struct IntroScene: View {
    var headline: String
    var rules: [String]
    var players: [PlayerRef]
    @State private var lights = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            LogoView(size: 1.3).bouncy()
            Text(headline).font(.poppins(20, .semibold)).foregroundStyle(MM.cream).bouncy(delay: 0.3)
            if !rules.isEmpty {
                HStack { ForEach(rules, id: \.self) { Chip(text: $0, gold: true) } }.bouncy(delay: 0.5)
            }
            Spacer()
            HStack(spacing: 24) {
                ForEach(Array(players.enumerated()), id: \.element.id) { i, p in
                    PodiumPlayer(player: p, face: "jubel", size: players.count > 5 ? 100 : 130, showBalance: false).bouncy(delay: 0.6 + Double(i) * 0.15)
                }
            }
            Text("Die Show beginnt …").font(.outfit(24, .bold)).foregroundStyle(MM.gold).padding(.bottom, 10)
        }
        .overlay(ParticleRain(kind: .confetti, count: 60, duration: 5))
    }
}

// MARK: - Category vote

struct KategorieScene: View {
    var optionen: [VoteOption]
    var letzter: PlayerRef?
    var deadline: Millis?
    var gewinner: String?
    var players: [PlayerRef]

    var body: some View {
        VStack(spacing: 18) {
            Text(letzter.map { "🎯 \($0.name) wählt die Kategorie!" } ?? "WELCHE KATEGORIE?").font(.outfit(40, .black)).foregroundStyle(MM.cream).bouncy()
            CountdownText(deadline: deadline)
            HStack(spacing: 18) {
                ForEach(optionen) { o in
                    VStack(spacing: 10) {
                        Text(o.emoji ?? "❓").font(.system(size: 64))
                        Text(o.label).font(.outfit(24, .bold)).foregroundStyle(MM.cream).multilineTextAlignment(.center)
                        HStack(spacing: 4) { ForEach(0..<o.count, id: \.self) { _ in Text("🐒").font(.system(size: 20)) } }.frame(height: 26)
                        Text("\(o.count) Stimmen").font(.poppins(13, .semibold)).foregroundStyle(MM.gold)
                    }
                    .padding(20).frame(width: 220, height: 240)
                    .background(kategorieBackground(selected: gewinner == o.id))
                    .scaleEffect(gewinner == o.id ? 1.08 : 1)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: gewinner)
                }
            }
            Text("Stimmt auf euren Handys ab!").font(.poppins(16)).foregroundStyle(MM.cream.opacity(0.8))
        }
    }

    func kategorieBackground(selected: Bool) -> some View {
        let fill: Color = selected ? MM.gold.opacity(0.35) : MM.panelDark.opacity(0.9)
        let stroke: Color = selected ? MM.gold : MM.gold.opacity(0.25)
        return RoundedRectangle(cornerRadius: 22).fill(fill).overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(stroke, lineWidth: selected ? 4 : 1.5))
    }
}

// MARK: - Explain card

struct ExplainScene: View {
    var card: ExplainCardView
    var players: [PlayerRef]

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Chip(text: "Runde \(card.rundenNummer)/\(card.rundenGesamt)", gold: true)
                if let k = card.kategorie { Chip(text: "📚 \(k)") }
                Chip(text: card.slot.rawValue.uppercased())
            }
            Text(card.emoji).font(.system(size: 90)).bouncy()
            Text(card.name.uppercased()).font(.outfit(52, .black)).foregroundStyle(MM.gold).bouncy(delay: 0.1)
            Text(card.text).font(.poppins(21)).foregroundStyle(MM.cream).multilineTextAlignment(.center).lineSpacing(5)
                .frame(maxWidth: 900).padding(24)
                .background(RoundedRectangle(cornerRadius: 22).fill(Color.black.opacity(0.3)).overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(MM.gold.opacity(0.3))))
                .bouncy(delay: 0.2)
            HStack(spacing: 18) {
                ForEach(players) { p in
                    VStack(spacing: 2) {
                        MonkeyImage(avatar: Avatar(wire: p.avatar), face: card.bereit.contains(p.id) ? "jubel" : "denk").frame(height: 80)
                        Text(card.bereit.contains(p.id) ? "✅ bereit" : (card.streik.contains(p.id) ? "✊ Streik" : "…")).font(.poppins(12, .semibold)).foregroundStyle(MM.cream)
                    }
                }
            }
            CountdownText(deadline: card.deadline)
        }
    }
}

// MARK: - Standings

struct StandingsScene: View {
    var entries: [StandingEntry]
    var runde: Int
    var total: Int
    var halbzeit: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text(halbzeit ? "🍕 HALBZEIT" : "ZWISCHENSTAND").font(.outfit(46, .black)).foregroundStyle(MM.cream).bouncy()
            Text("nach Runde \(runde) von \(total)").font(.poppins(16, .semibold)).foregroundStyle(MM.gold)
            HStack(alignment: .bottom, spacing: 18) {
                ForEach(Array(entries.enumerated()), id: \.element.player.id) { i, e in
                    VStack(spacing: 6) {
                        if e.rueckenwind > 1 { Text("🌬️ ×\(String(format: "%.2g", e.rueckenwind))").font(.poppins(12, .bold)).foregroundStyle(MM.blue) }
                        PodiumPlayer(player: e.player, face: e.delta >= 0 ? "jubel" : "frust", delta: e.delta, size: entries.count > 5 ? 100 : 130, highlight: i == 0)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(i == 0 ? MM.gold : MM.panelDark)
                            .frame(width: entries.count > 5 ? 100 : 130, height: CGFloat(20 + max(0, 140 - i * 25)))
                            .overlay(Text("\(i + 1)").font(.outfit(30, .black)).foregroundStyle(i == 0 ? MM.ink : MM.cream))
                    }
                    .bouncy(delay: Double(i) * 0.12)
                }
            }
        }
    }
}

// MARK: - Wheel

struct WheelScene: View {
    var wheel: WheelView
    var players: [PlayerRef]

    var body: some View {
        HStack(spacing: 40) {
            VStack(spacing: -30) {
                WheelSpinView(segments: wheel.face, resultIndex: wheel.resultIndex, spinStartedAt: wheel.spinStartedAt, spinDurationMs: wheel.spinDurationMs, landed: wheel.subphase != "dreht")
                    .frame(width: 500, height: 500)
                    .zIndex(1)
                // stand
                VStack(spacing: -6) {
                    RoundedRectangle(cornerRadius: 6).fill(LinearGradient(colors: [MM.goldDark, Color(hex: "#9A7418")], startPoint: .top, endPoint: .bottom)).frame(width: 70, height: 60)
                    Ellipse().fill(LinearGradient(colors: [Color(hex: "#2A8A4A"), MM.panelDark], startPoint: .top, endPoint: .bottom)).frame(width: 420, height: 70)
                        .overlay(Ellipse().strokeBorder(MM.gold.opacity(0.35), lineWidth: 2))
                        .overlay(HStack(spacing: 60) { ForEach(0..<5, id: \.self) { _ in Circle().fill(MM.gold).frame(width: 10, height: 10).shadow(color: MM.gold, radius: 6) } }.offset(y: 8))
                }
            }
            .padding(.leading, 10)
            VStack(alignment: .leading, spacing: 14) {
                Text(wheel.subphase == "dreht" ? "DAS RAD DREHT …" : (wheel.resultIndex.map { wheel.face[$0].name.uppercased() } ?? "")).font(.outfit(46, .black)).foregroundStyle(MM.cream).shadow(color: .black.opacity(0.5), radius: 6, y: 4).id(wheel.subphase).bouncy()
                Swoosh().frame(width: 260, height: 22)
                if wheel.subphase == "dreht" {
                    Text("Wo bleibt es stehen?!").font(.poppins(22)).foregroundStyle(MM.cream.opacity(0.85))
                } else if let e = wheel.erklaerung {
                    Text(e).font(.poppins(20)).foregroundStyle(MM.cream).frame(maxWidth: 520).padding(18)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.3)).overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(MM.gold.opacity(0.4))))
                        .bouncy()
                    if !wheel.betroffene.isEmpty {
                        HStack { ForEach(players.filter { wheel.betroffene.contains($0.id) }) { p in PodiumPlayer(player: p, face: "denk", size: 90, showBalance: false) } }
                    }
                    if wheel.subphase == "interaktion" {
                        HStack { Text("📱 Auf die Handys schauen!").font(.poppins(18, .bold)).foregroundStyle(MM.gold); CountdownText(deadline: wheel.interactionEndsAt) }
                    }
                }
                Spacer()
                HStack(spacing: 14) { ForEach(players.prefix(6)) { p in PodiumPlayer(player: p, size: 90) } }
            }
            .padding(.vertical, 20)
        }
        .overlay(alignment: .top) {
            if wheel.subphase != "dreht", let i = wheel.resultIndex, wheel.face[i].klasse == .gold { ParticleRain(kind: .confetti, count: 70, duration: 4) }
        }
    }
}

// MARK: - Highlights / ceremony / end

struct HighlightsScene: View {
    var entries: [HighlightEntry]
    var players: [PlayerRef]
    var body: some View {
        VStack(spacing: 18) {
            Text("🎞️ HIGHLIGHTS DES ABENDS").font(.outfit(44, .black)).foregroundStyle(MM.cream).bouncy()
            ForEach(Array(entries.enumerated()), id: \.offset) { i, h in
                HStack(spacing: 16) {
                    Text(h.emoji).font(.system(size: 40))
                    Text(h.text).font(.poppins(22, .semibold)).foregroundStyle(MM.cream)
                    Spacer()
                    if let pid = h.playerId, let p = players.first(where: { $0.id == pid }) { MonkeyImage(avatar: Avatar(wire: p.avatar), face: "jubel").frame(height: 70) }
                }
                .padding(.horizontal, 24).padding(.vertical, 12).frame(maxWidth: 900)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.3)))
                .bouncy(delay: Double(i) * 0.4)
            }
        }
    }
}

struct CeremonyScene: View {
    var podium: [PodiumEntry]
    var awards: [Award]
    var abend: AbendStats
    var body: some View {
        ZStack {
            ParticleRain(kind: .money, count: 90, duration: 6)
            VStack(spacing: 10) {
                Text("👑").font(.system(size: 50)).bouncy()
                HStack(spacing: 14) {
                    Laurel(flip: false).frame(width: 60, height: 110)
                    Text("SIEGEREHRUNG").font(.outfit(58, .black)).foregroundStyle(MM.gold).shadow(color: .black.opacity(0.5), radius: 10, y: 6)
                    Laurel(flip: true).frame(width: 60, height: 110)
                }
                .bouncy(delay: 0.1)
                Text("Starke Runde!").font(.custom("Poppins-SemiBold", size: 18)).italic().foregroundStyle(MM.cream)
                Swoosh().frame(width: 120, height: 12).opacity(0.9)
                HStack(alignment: .bottom, spacing: 26) {
                    ForEach(podiumOrder(), id: \.player.id) { e in
                        VStack(spacing: 8) {
                            PodiumPlayer(player: e.player, face: e.platz == 1 ? "jubel" : (e.platz == podium.count ? "frust" : "neutral"), size: e.platz == 1 ? 170 : 130, showBalance: false)
                            VStack(spacing: 2) {
                                Text("\(e.platz)").font(.outfit(44, .black)).foregroundStyle(e.platz == 1 ? MM.ink : MM.cream)
                                Text(Money.format(e.mm)).font(.outfit(20, .bold)).foregroundStyle(e.platz == 1 ? MM.ink : MM.gold)
                                Text("+\(e.at) All-Time").font(.poppins(12, .semibold)).foregroundStyle(e.platz == 1 ? MM.ink.opacity(0.8) : MM.cream.opacity(0.8))
                            }
                            .frame(width: e.platz == 1 ? 170 : 130, height: CGFloat(e.platz == 1 ? 150 : (e.platz == 2 ? 115 : 90)))
                            .background(RoundedRectangle(cornerRadius: 10).fill(e.platz == 1 ? MM.gold : (e.platz == 2 ? Color(hex: "#C0C0C0").opacity(0.7) : MM.wood)))
                        }
                        .bouncy(delay: 0.3 + Double(e.platz) * 0.15)
                    }
                }
                HStack(spacing: 12) {
                    ForEach(awards, id: \.titel) { a in
                        HStack(spacing: 6) {
                            Text(a.emoji)
                            Text("\(a.titel): \(podium.first { $0.player.id == a.playerId }?.player.name ?? "?") (\(a.detail))").font(.poppins(13, .semibold))
                        }.padding(.horizontal, 12).padding(.vertical, 8).background(Capsule().fill(Color.black.opacity(0.35))).foregroundStyle(MM.cream)
                    }
                }
                if abend.spiele > 0 {
                    Text("🍌 Zusammen verdient: \(abend.atGesamt) AT · \(abend.spiele) Spiel\(abend.spiele == 1 ? "" : "e")").font(.poppins(14, .semibold)).foregroundStyle(MM.gold)
                }
            }
        }
    }

    /// 2 – 1 – 3 – 4 … layout.
    func podiumOrder() -> [PodiumEntry] {
        var out: [PodiumEntry] = []
        if podium.count > 1 { out.append(podium[1]) }
        if podium.count > 0 { out.append(podium[0]) }
        if podium.count > 2 { out.append(contentsOf: podium[2...]) }
        return out
    }
}

struct EndScene: View {
    var podium: [PodiumEntry]
    var body: some View {
        VStack(spacing: 20) {
            Text("ABSPANN").font(.outfit(50, .black)).foregroundStyle(MM.cream)
            Text("Danke fürs Spielen! Feedback läuft auf den Handys …").font(.poppins(18)).foregroundStyle(MM.cream.opacity(0.85))
            HStack(spacing: 20) { ForEach(podium, id: \.player.id) { e in PodiumPlayer(player: e.player, face: e.platz == 1 ? "jubel" : "neutral", size: 110) } }
            Text("🔁 REVANCHE über den Knopf unten rechts — gleiche Affen, neues Geld.").font(.poppins(16, .semibold)).foregroundStyle(MM.gold)
        }
    }
}
