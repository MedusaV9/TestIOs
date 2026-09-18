import SwiftUI

struct HostRootView: View {
    @EnvironmentObject var host: HostModel

    var body: some View {
        ZStack {
            JungleBackground()
            StageCanvas {
                ZStack {
                    screen
                        .id(host.screen)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.97)), removal: .opacity))
                    if let t = host.toast {
                        VStack { Spacer(); Chip(text: t, gold: true).padding(.bottom, 30) }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { withAnimation { host.toast = nil } } }
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: host.screen)
            }
        }
        .onAppear { host.audio.playMusic("theme_main") }
    }

    @ViewBuilder
    var screen: some View {
        switch host.screen {
        case .menu: MainMenuView()
        case .modes: ModeSelectView()
        case .lobby: LobbyView()
        case .stage: StageRootView()
        case .profiles: ProfilesView()
        case .shop: ShopView()
        case .boards: BoardsView()
        case .settings: HostSettingsView()
        case .saves: SavesView()
        case .howto: HowToView()
        }
    }
}

/// Top bar shown on every host screen: brand, server address, device count, settings.
struct HostTopBar: View {
    @EnvironmentObject var host: HostModel
    var showBack = true
    var body: some View {
        HStack(spacing: 12) {
            if showBack {
                Button { host.screen = host.screen == .lobby || host.screen == .stage ? .menu : .menu } label: {
                    Label("Zurück", systemImage: "chevron.left").font(.poppins(15, .semibold))
                }
                .buttonStyle(.plain).foregroundStyle(MM.cream)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(Color.black.opacity(0.3)))
            }
            HStack(spacing: 8) {
                Text(Edition.isLeague ? "⚔️" : "🐵").font(.system(size: 20))
                Text("MONKEY MONEY").font(.outfit(17, .black)).foregroundStyle(MM.gold).tracking(1.5)
                if Edition.isLeague { Chip(text: "LEAGUE EDITION", gold: true) }
            }
            if host.server != nil {
                Chip(text: "iPad ist der Server", icon: "wifi")
                Chip(text: "http://\(host.lanIP):\(host.port)")
            }
            Spacer()
            if let stage = host.stage, host.server != nil {
                HStack(spacing: 6) {
                    Circle().fill(MM.green).frame(width: 10, height: 10).shadow(color: MM.green, radius: 6)
                    Text("\(stage.players.filter { $0.connected }.count + 1) Geräte").font(.poppins(14, .semibold)).foregroundStyle(MM.cream)
                }
            }
            Button { host.screen = .settings } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(MM.cream)
                    .frame(width: 40, height: 40).background(Circle().fill(Color.black.opacity(0.3)))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 22).padding(.top, 14)
    }
}

/// Main menu — the iPad is the game hub (design: logo, spotlights, wooden signs).
struct MainMenuView: View {
    @EnvironmentObject var host: HostModel

    var body: some View {
        VStack(spacing: 0) {
            HostTopBar(showBack: false)
            Spacer(minLength: 0)
            HStack(alignment: .center, spacing: 40) {
                WoodSign(lines: ["Good", "Questions", "Bigger", "Wins! 👑"], tilt: -5).frame(width: 190)
                VStack(spacing: 18) {
                    LogoView(size: 1.0)
                    if let auto = host.autosaveAvailable {
                        Button { host.loadSlotAndStart(auto) } label: {
                            HStack {
                                Text("▶").font(.outfit(22, .black))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Weiterspielen?").font(.outfit(20, .bold))
                                    Text(auto.label).font(.poppins(13)).opacity(0.85)
                                }
                                Spacer()
                                HStack(spacing: -10) {
                                    ForEach(auto.state.players.prefix(4)) { p in MonkeyImage(avatar: p.avatar).frame(height: 44) }
                                }
                            }
                            .padding(14).foregroundStyle(MM.cream)
                            .background(RoundedRectangle(cornerRadius: 16).fill(MM.panel).overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MM.gold, lineWidth: 2)))
                        }.buttonStyle(PressStyle()).frame(width: 520)
                    }
                    GoldButton(title: "Neue Show starten", icon: "play.fill") { host.settingsDraft = Edition.defaultSettings(); host.screen = .modes }
                        .frame(width: 520)
                    HStack(spacing: 12) {
                        GoldButton(title: "Spiele-Abend", icon: "dice.fill", style: .green) {
                            var s = Edition.defaultSettings(modus: .quick)
                            s.spielModus = .spieleabend
                            host.startShow(settings: s)
                        }
                        GoldButton(title: "Profile & Shop", icon: "person.2.fill", style: .green) { host.screen = .profiles }
                    }.frame(width: 520)
                    HStack(spacing: 12) {
                        GoldButton(title: "Bestenlisten", icon: "trophy.fill", style: .ghost, compact: true) { host.screen = .boards }
                        GoldButton(title: "Spielstände", icon: "externaldrive.fill", style: .ghost, compact: true) { host.screen = .saves }
                        GoldButton(title: "So funktioniert's", icon: "questionmark.circle.fill", style: .ghost, compact: true) { host.screen = .howto }
                    }
                }
                WoodSign(lines: ["Same", "WiFi.", "Real", "Fun."], tilt: 4).frame(width: 190)
            }
            Spacer(minLength: 0)
            HStack(spacing: 30) {
                MonkeyImage(avatar: Avatar(affe: "don-bananas", farbe: "gelb"), face: "jubel").frame(height: 150)
                Text(Edition.isLeague ? "\(host.catalog.questions.count.formatted()) League-of-Legends-Fragen · Champions, Lore, Items, Esports · \(host.meta.profiles.count) Profile" : "\(host.catalog.questions.count.formatted()) Fragen · 27 Formate · 6 Brettspiele · \(host.meta.profiles.count) Profile")
                    .font(.poppins(14, .semibold)).foregroundStyle(MM.cream.opacity(0.8))
                MonkeyImage(avatar: Avatar(affe: "kiki-krawall", farbe: "gruen"), face: "jubel").frame(height: 150)
            }
            .padding(.bottom, 8)
            Text("SAME WIFI · REAL FUN · NO SERVER NEEDED").font(.poppins(11, .semibold)).tracking(3).foregroundStyle(MM.cream.opacity(0.5)).padding(.bottom, 14)
        }
    }
}

/// The MONKEY MONEY logo lock-up (title, banana underline, tagline plaque).
struct LogoView: View {
    var size: CGFloat = 1
    var body: some View {
        VStack(spacing: -6 * size) {
            Text("🎩").font(.system(size: 40 * size)).offset(y: 10 * size)
            Text("MONKEY").font(.outfit(64 * size, .black)).foregroundStyle(MM.cream)
                .shadow(color: Color(hex: "#A67C1A"), radius: 0, y: 4 * size).shadow(color: .black.opacity(0.5), radius: 16, y: 10)
            Text("MONEY").font(.outfit(64 * size, .black)).foregroundStyle(MM.gold)
                .shadow(color: Color(hex: "#A67C1A"), radius: 0, y: 4 * size).shadow(color: .black.opacity(0.5), radius: 16, y: 10)
            Text(Edition.isLeague ? "⚔️ LEAGUE EDITION" : "QUIZ · PLAY · WIN").font(.poppins(14 * size, .bold)).tracking(3).foregroundStyle(Edition.isLeague ? MM.ink : MM.cream)
                .padding(.horizontal, 18 * size).padding(.vertical, 6 * size)
                .background(RoundedRectangle(cornerRadius: 6).fill(Edition.isLeague ? MM.gold : MM.wood)).overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Edition.isLeague ? MM.goldDark : Color(hex: "#5A3A1C"), lineWidth: 2))
                .offset(y: 10 * size)
        }
    }
}
