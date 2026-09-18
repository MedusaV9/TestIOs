import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// QR code rendered with CoreImage (join URL / GM URL).
struct QRCodeView: View {
    var text: String
    var size: CGFloat = 220

    var body: some View {
        Group {
            if let img = QRCodeView.make(text) {
                Image(uiImage: img).interpolation(.none).resizable().scaledToFit()
            } else {
                Color.white
            }
        }
        .frame(width: size, height: size)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
        .shadow(color: .black.opacity(0.4), radius: 12, y: 8)
    }

    static func make(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let out = filter.outputImage else { return nil }
        let scaled = out.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// Lobby: QR join, room code, Show-Master code (toggleable), player podiums,
/// start button — and the board game cards for the Spiele-Abend.
struct LobbyView: View {
    @EnvironmentObject var host: HostModel
    @State private var showSettings = false
    @State private var localSeatDraft = ""
    @State private var pendingBoardgame: BoardgameCard?
    @State private var variante = "kurz"

    var lobby: LobbyInfo? {
        if case .lobby(let info)? = host.stage?.scene { return info }
        return nil
    }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= 1000
            ZStack(alignment: .topLeading) {
                LeafCluster(flip: false).frame(width: geo.size.width * 0.17, height: geo.size.height * 0.3).position(x: geo.size.width * 0.05, y: geo.size.height * 0.86).opacity(0.85).allowsHitTesting(false)
                LeafCluster(flip: true).frame(width: geo.size.width * 0.17, height: geo.size.height * 0.3).position(x: geo.size.width * 0.95, y: geo.size.height * 0.86).opacity(0.85).allowsHitTesting(false)
                if wide {
                    SpotlightHead(pointsRight: true).position(x: geo.size.width * 0.12, y: 60).allowsHitTesting(false)
                    SpotlightHead(pointsRight: false).position(x: geo.size.width * 0.88, y: 60).allowsHitTesting(false)
                    HangingSign(lines: ["Good", "Questions", "Bigger", "Wins!"], tilt: -5).frame(width: 118).position(x: 84, y: geo.size.height * 0.32).allowsHitTesting(false)
                    SloganCrate(lines: ["PLAY", "TOGETHER", "♡"]).frame(width: 104, height: 96).position(x: geo.size.width - 70, y: geo.size.height * 0.86).allowsHitTesting(false)
                }
                lobbyContent.padding(.leading, wide ? 132 : 0)
            }
        }
    }

    var lobbyContent: some View {
        VStack(spacing: 0) {
            HostTopBar()
            if let error = host.serverError {
                Text(error).font(.poppins(14, .bold)).foregroundStyle(.white).padding(10).background(Capsule().fill(MM.red)).padding(.top, 8)
            }
            HStack(alignment: .top, spacing: 26) {
                // Left: join panel
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 18) {
                        Button { host.showQrLarge = true } label: { QRCodeView(text: host.joinURL, size: 200) }.buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Handy-Kamera drauf oder tippen:").font(.poppins(13, .semibold)).foregroundStyle(MM.cream.opacity(0.85))
                            Text(host.joinURL).font(.poppins(15, .bold)).foregroundStyle(MM.cream)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("RAUM-CODE").font(.poppins(10, .bold)).tracking(2).foregroundStyle(MM.gold)
                                HStack(spacing: 10) {
                                    Text(host.roomCode.map(String.init).joined(separator: " ")).font(.outfit(44, .black)).foregroundStyle(MM.cream)
                                    Button { UIPasteboard.general.string = host.joinURL; host.toast = "Link kopiert" } label: {
                                        Image(systemName: "doc.on.doc").font(.system(size: 16, weight: .bold)).foregroundStyle(MM.gold).frame(width: 40, height: 40).background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.3)))
                                    }.buttonStyle(.plain)
                                }
                            }
                            .padding(12).background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.28)).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(MM.gold.opacity(0.3))))
                            Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { host.showGmCode.toggle() } } label: {
                                HStack(spacing: 6) {
                                    Text("🎬").font(.system(size: 13))
                                    Text("Show-Master-PIN:").font(.poppins(13, .semibold))
                                    Text(host.showGmCode ? host.gmPin : "••••").font(.outfit(15, .black)).foregroundStyle(MM.gold)
                                    Image(systemName: host.showGmCode ? "eye.slash" : "eye").font(.system(size: 12, weight: .bold)).padding(.leading, 4)
                                }.foregroundStyle(MM.cream.opacity(0.9))
                            }.buttonStyle(.plain)
                        }
                    }
                    if host.showGmCode {
                        HStack(spacing: 16) {
                            QRCodeView(text: host.gmURL, size: 120)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("🎬 Show-Master (optional)").font(.outfit(18, .bold)).foregroundStyle(MM.gold)
                                Text("Scannen → Regiepult auf dem Handy.").font(.poppins(13)).foregroundStyle(MM.cream.opacity(0.85))
                                Text("PIN: \(host.gmPin)").font(.outfit(26, .black)).foregroundStyle(MM.cream)
                                Text(host.gmURL).font(.poppins(11)).foregroundStyle(MM.cream.opacity(0.7))
                            }
                        }
                        .padding(14).background(RoundedRectangle(cornerRadius: 16).fill(MM.lila.opacity(0.18)).overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MM.lila.opacity(0.5))))
                        .transition(.scale.combined(with: .opacity))
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill").foregroundStyle(MM.cream)
                        Text("\(host.stage?.players.count ?? 0) / \(lobby?.maxPlayers ?? 8) Spieler").font(.poppins(15, .bold)).foregroundStyle(MM.cream)
                    }
                    Text(lobby?.startHint ?? "").font(.poppins(13)).foregroundStyle(MM.cream.opacity(0.8))
                    Text("🎯 Solo üben ohne Raum: \(host.joinURL.replacingOccurrences(of: "/j/\(host.roomCode)", with: "/uebung"))").font(.poppins(11)).foregroundStyle(MM.cream.opacity(0.6))
                    HStack(spacing: 10) {
                        ShareLink(item: URL(string: host.joinURL) ?? URL(string: "http://localhost")!) { Label("Raum teilen", systemImage: "square.and.arrow.up").font(.poppins(13, .semibold)) }
                            .buttonStyle(.plain).foregroundStyle(MM.cream).padding(.horizontal, 12).padding(.vertical, 9).background(Capsule().fill(Color.black.opacity(0.3)).overlay(Capsule().strokeBorder(Color.white.opacity(0.1))))
                        GoldButton(title: "QR vergrößern", icon: "arrow.up.left.and.arrow.down.right", style: .ghost, compact: true) { host.showQrLarge = true }
                        GoldButton(title: "Link kopieren", icon: "link", style: .ghost, compact: true) { UIPasteboard.general.string = host.joinURL; host.toast = "Link kopiert" }
                    }
                    HStack(spacing: 10) {
                        GoldButton(title: "Bot hinzufügen", icon: "cpu", style: .ghost, compact: true) { host.addBot() }
                        GoldButton(title: "Einstellungen", icon: "slider.horizontal.3", style: .ghost, compact: true) { showSettings = true }
                    }
                }
                .frame(maxWidth: 560, alignment: .leading)

                // Right: logo + podiums
                VStack(spacing: 10) {
                    LogoView(size: 0.62)
                    if let stage = host.stage {
                        if stage.players.isEmpty {
                            VStack(spacing: 6) {
                                MonkeyImage(avatar: Avatar(affe: "schnarch-schorsch", farbe: "gelb"), face: "denk").frame(height: 150)
                                Text("Noch niemand da — scannt den QR-Code!").font(.poppins(15, .semibold)).foregroundStyle(MM.cream.opacity(0.85))
                            }
                        } else {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: min(4, max(2, stage.players.count))), spacing: 14) {
                                ForEach(stage.players) { p in
                                    PodiumPlayer(player: p, face: p.connected ? "jubel" : "denk", size: stage.players.count > 4 ? 90 : 120)
                                        .contextMenu {
                                            Button("Rauswerfen", role: .destructive) { host.command(.kick(p.id)) }
                                        }
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: stage.players.count)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 26).padding(.top, 16)

            Spacer(minLength: 8)

            if let lobby = lobby {
                if lobby.settings.spielModus == .spieleabend {
                    boardgamePicker(lobby)
                } else {
                    GoldButton(title: lobby.canStart ? "Starten, wenn alle da sind!" : "Mindestens 2 Affen …", icon: "play.fill") {
                        host.command(.flowNext)
                    }
                    .disabled(!lobby.canStart).opacity(lobby.canStart ? 1 : 0.6)
                    .frame(width: 560).padding(.bottom, 20)
                }
            }
            Text("SAME WIFI · REAL FUN · NO SERVER NEEDED").font(.poppins(10, .semibold)).tracking(3).foregroundStyle(MM.cream.opacity(0.5)).padding(.bottom, 10)
        }
        .sheet(isPresented: $showSettings) { LobbySettingsSheet() }
        .sheet(isPresented: $host.showQrLarge) {
            VStack(spacing: 18) {
                Text("Scannen & mitspielen").font(.outfit(34, .black)).foregroundStyle(MM.cream)
                QRCodeView(text: host.joinURL, size: 420)
                Text(host.joinURL).font(.poppins(20, .bold)).foregroundStyle(MM.cream)
                Text("Raum-Code \(host.roomCode)").font(.outfit(28, .black)).foregroundStyle(MM.gold)
                GoldButton(title: "Schließen", style: .ghost, compact: true) { host.showQrLarge = false }
            }
            .padding(40).frame(maxWidth: .infinity, maxHeight: .infinity).background(MM.bg)
        }
        .sheet(item: $pendingBoardgame) { card in boardgameStartSheet(card) }
    }

    @ViewBuilder
    func boardgamePicker(_ lobby: LobbyInfo) -> some View {
        VStack(spacing: 10) {
            Text("🎲 Spiele-Abend — welches Spiel?").font(.outfit(24, .black)).foregroundStyle(MM.cream)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(lobby.boardgames) { card in
                        Button { pendingBoardgame = card } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(card.emoji).font(.system(size: 34))
                                Text(card.name).font(.outfit(17, .bold)).lineLimit(1)
                                Text(card.untertitel).font(.poppins(11)).opacity(0.8).lineLimit(2)
                                Text(card.hinweis).font(.poppins(11, .semibold)).foregroundStyle(card.startbar ? MM.green : MM.orange)
                            }
                            .padding(14).frame(width: 220, height: 150, alignment: .topLeading).foregroundStyle(MM.cream)
                            .background(RoundedRectangle(cornerRadius: 16).fill(MM.panelDark.opacity(0.9)).overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(card.startbar ? MM.gold.opacity(0.6) : Color.white.opacity(0.1))))
                        }.buttonStyle(PressStyle())
                    }
                }.padding(.horizontal, 26)
            }
            HStack {
                GoldButton(title: "Zur Quiz-Show wechseln", icon: "questionmark.circle", style: .ghost, compact: true) { host.command(.settingsSet(["spielModus": .string("quiz")])) }
            }.padding(.bottom, 12)
        }
    }

    @ViewBuilder
    func boardgameStartSheet(_ card: BoardgameCard) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(card.emoji) \(card.name)").font(.outfit(34, .black)).foregroundStyle(MM.cream)
            ForEach(Array(card.howto.enumerated()), id: \.offset) { i, line in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(i + 1)").font(.outfit(18, .black)).foregroundStyle(MM.ink).frame(width: 30, height: 30).background(Circle().fill(MM.gold))
                    Text(line).font(.poppins(15)).foregroundStyle(MM.cream)
                }
            }
            if !card.varianten.isEmpty {
                SettingPicker(title: "Variante", options: card.varianten.map { ($0, $0 == "kurz" ? "Kurze Partie (2 Affen)" : "Klassisch (4 Affen)") }, selection: $variante)
            }
            if !card.phonesOnly {
                VStack(alignment: .leading, spacing: 6) {
                    Text("iPad-Sitze (Pass-and-Play, Name + Enter)").font(.poppins(13, .bold)).foregroundStyle(MM.gold)
                    HStack {
                        TextField("Name", text: $localSeatDraft).textFieldStyle(.roundedBorder).frame(width: 220)
                        Button("Hinzufügen") { let n = localSeatDraft.trimmingCharacters(in: .whitespaces); if !n.isEmpty { host.localSeatNames.append(n); localSeatDraft = "" } }.tint(MM.gold)
                        ForEach(host.localSeatNames, id: \.self) { n in Chip(text: n, icon: "ipad") .onTapGesture { host.localSeatNames.removeAll { $0 == n } } }
                    }
                }
            }
            Text(card.hinweis).font(.poppins(13)).foregroundStyle(MM.cream.opacity(0.8))
            HStack {
                GoldButton(title: "Los geht's!", icon: "play.fill") {
                    var opts: [String: JSONValue] = ["variante": .string(variante)]
                    if !card.phonesOnly { opts["lokaleSitze"] = .array(host.localSeatNames.map { .string($0) }) }
                    host.command(.boardgameStart(id: card.id, optionen: opts))
                    pendingBoardgame = nil
                }
                GoldButton(title: "Abbrechen", style: .ghost) { pendingBoardgame = nil }
            }
        }
        .padding(34).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).background(MM.bg)
    }
}

/// Live lobby settings (patched through the engine's whitelist).
struct LobbySettingsSheet: View {
    @EnvironmentObject var host: HostModel
    @Environment(\.dismiss) var dismiss
    var settings: MatchSettings { host.stage.flatMap { if case .lobby(let l) = $0.scene { return l.settings } else { return nil } } ?? host.settingsDraft }

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 18) {
            Text("Lobby-Einstellungen").font(.outfit(30, .black)).foregroundStyle(MM.cream)
            QuestionSetPicker(sets: host.catalog.questionSetInfos(activePool: settings.kategorienPool, kidSafe: settings.familienModus),
                              kategorien: host.catalog.categoryInfos(activePool: settings.kategorienPool, kidSafe: settings.familienModus),
                              pool: settings.kategorienPool, poolInfo: host.poolInfo(settings), compact: true,
                              onSet: { host.command(.settingsSet(["fragenSet": .string($0)])) },
                              onPool: { host.command(.settingsSet(["kategorienPool": .array($0.map { .string($0) })])) })
            Group {
                SettingPicker(title: "Modus", options: Modus.allCases.map { ($0.rawValue, $0.title) }, selection: Binding(get: { settings.modus.rawValue }, set: { host.command(.settingsSet(["modus": .string($0)])) }))
                SettingPicker(title: "Tempo", options: Tempo.allCases.map { ($0.rawValue, $0.label) }, selection: Binding(get: { settings.tempo.rawValue }, set: { host.command(.settingsSet(["tempo": .string($0)])) }))
                SettingPicker(title: "Fragen-Mix", options: FragenMix.allCases.map { ($0.rawValue, $0.label) }, selection: Binding(get: { settings.fragenMix.rawValue }, set: { host.command(.settingsSet(["fragenMix": .string($0)])) }))
                SettingPicker(title: "Teams", options: [("aus", "Einzeln"), ("2er", "2er-Teams"), ("2v2v2v2", "4 Lager")], selection: Binding(get: { settings.teams.rawValue }, set: { host.command(.settingsSet(["teams": .string($0)])); host.command(.teamsShuffle) }))
            }
            HStack(spacing: 14) {
                ToggleChip(title: "⏱️ Timer aus", on: Binding(get: { settings.timerAus }, set: { host.command(.settingsSet(["timerAus": .bool($0)])) }))
                SettingPicker(title: "", options: [("0", "Zeit: Auto"), ("15", "15 s"), ("20", "20 s"), ("30", "30 s"), ("60", "60 s"), ("120", "2 min")], selection: Binding(get: { String(settings.fragenZeit ?? 0) }, set: { host.command(.settingsSet(["fragenZeit": .number(Double($0) ?? 0)])) }))
            }
            HStack(spacing: 14) {
                ToggleChip(title: "Joker", on: Binding(get: { settings.jokerAn }, set: { host.command(.settingsSet(["jokerAn": .bool($0)])) }))
                ToggleChip(title: "Glücksrad", on: Binding(get: { settings.radAn }, set: { host.command(.settingsSet(["radAn": .bool($0)])) }))
                ToggleChip(title: "Musik", on: Binding(get: { settings.musik }, set: { host.command(.settingsSet(["musik": .bool($0)])) }))
                ToggleChip(title: "Ohne Game Master", on: Binding(get: { settings.gmLos }, set: { host.command(.settingsSet(["gmLos": .bool($0)])) }))
            }
            HStack(spacing: 14) {
                ToggleChip(title: "👨‍👩‍👧 Familien-Modus", on: Binding(get: { settings.familienModus }, set: { host.command(.settingsSet(["familienModus": .bool($0)])) }))
                SettingPicker(title: "", options: [("voting", "🗳️ Kategorien: Voting"), ("gm", "🎬 Show-Master wählt"), ("aus", "Kategorien-Wahl aus")], selection: Binding(get: { settings.kategorienWahl }, set: { host.command(.settingsSet(["kategorienWahl": .string($0)])) }))
            }
            HStack(spacing: 14) {
                GoldButton(title: "Bots entfernen", icon: "cpu", style: .ghost, compact: true) { host.removeBots() }
                GoldButton(title: "Teams neu mischen", icon: "shuffle", style: .ghost, compact: true) { host.command(.teamsShuffle) }
                GoldButton(title: "Spielstand speichern", icon: "externaldrive", style: .ghost, compact: true) { host.writeSlot(1) }
            }
            GoldButton(title: "Fertig", style: .gold) { dismiss() }
        }
        .padding(34).frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(MM.bg)
    }
}
