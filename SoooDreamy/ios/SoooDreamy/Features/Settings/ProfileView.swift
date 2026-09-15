import SwiftUI

/// Profile & settings — the sheet behind the avatar (and
/// `sooodreamy://tab/settings`). Apple-Account style: photo cover, the two
/// names, four numbers, then inset-grouped sections. Every detail screen is
/// a push inside the sheet's own navigation stack; nothing nests sheets.
struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    @State private var path: [ProfileRoute] = []
    @State private var appLockOn = AppLock.isEnabled
    @State private var hapticsOn = Haptics.enabled
    @State private var soundsOn = SoundEngine.enabled
    @State private var confirmSignOut = false
    @State private var confirmDissolve = false
    @State private var serverVersion: String?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                heroSection
                coupleSection
                appSection
                securitySection
                homeScreenSection
                connectionSection
                aboutSection
                accountSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L10n.t("common.profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.done")) { dismiss() }
                }
            }
            .navigationDestination(for: ProfileRoute.self) { route in
                route.destination
            }
            .confirmationDialog(L10n.t("profile.signOut.confirm"), isPresented: $confirmSignOut,
                                titleVisibility: .visible) {
                Button(L10n.t("settings.leaveDevice"), role: .destructive) {
                    appState.leaveDevice()
                    dismiss()
                }
            } message: {
                Text(L10n.t("settings.leaveDeviceHint"))
            }
            .confirmationDialog(L10n.t("settings.unpair"), isPresented: $confirmDissolve,
                                titleVisibility: .visible) {
                Button(L10n.t("settings.unpair"), role: .destructive) {
                    Task {
                        await appState.dissolveCouple()
                        dismiss()
                    }
                }
            } message: {
                Text(L10n.t("settings.unpairConfirm"))
            }
        }
        .task(id: appState.servers.activeProfileID) { await loadServerVersion() }
        .onChange(of: path) { _, newPath in
            // Sub-screens write static preferences; refresh the value labels
            // when the user comes back to the overview.
            if newPath.isEmpty { syncPreferenceLabels() }
        }
    }

    // MARK: Hero

    private var heroSection: some View {
        Section {
            ProfileHero()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        } footer: {
            if appState.widgetPhoto == nil {
                Text(L10n.t("profile.hero.hint"))
            }
        }
        .listSectionSeparator(.hidden)
    }

    // MARK: Sections

    private var coupleSection: some View {
        Section {
            NavigationLink(value: ProfileRoute.coupleProfile) {
                SettingsLabel(title: L10n.t("profile.couple.title"),
                              subtitle: L10n.t("profile.couple.subtitle"),
                              systemImage: "person.2.fill", tint: .accentColor)
            }
            if appState.couple?.code != nil {
                NavigationLink(value: ProfileRoute.pairingCode) {
                    SettingsLabel(title: L10n.t("profile.code.title"),
                                  subtitle: L10n.t("profile.code.subtitle"),
                                  systemImage: "qrcode", tint: .indigo)
                }
            }
        }
    }

    private var appSection: some View {
        Section(L10n.t("profile.section.app")) {
            NavigationLink(value: ProfileRoute.notifications) {
                SettingsLabel(title: L10n.t("notif.section"), systemImage: "bell.badge.fill", tint: .red)
            }
            NavigationLink(value: ProfileRoute.appearance) {
                LabeledContent {
                    Text(L10n.t(appearanceMode.titleKey))
                } label: {
                    SettingsLabel(title: L10n.t("appearance.title"),
                                  systemImage: "circle.lefthalf.filled", tint: .gray)
                }
            }
            NavigationLink(value: ProfileRoute.haptics) {
                LabeledContent {
                    Text(L10n.t(hapticsOn ? "touchstudio.title" : "common.off"))
                } label: {
                    SettingsLabel(title: L10n.t("settings.haptics"), systemImage: "hand.tap.fill", tint: .purple)
                }
            }
            NavigationLink(value: ProfileRoute.sounds) {
                LabeledContent {
                    Text(L10n.t(soundsOn ? "common.on" : "common.off"))
                } label: {
                    SettingsLabel(title: L10n.t("settings.sounds"), systemImage: "speaker.wave.2.fill", tint: .pink)
                }
            }
            Picker(selection: languageBinding) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(L10n.t(lang.displayNameKey)).tag(lang)
                }
            } label: {
                SettingsLabel(title: L10n.t("settings.language"), systemImage: "globe", tint: .blue)
            }
            .pickerStyle(.menu)
        }
    }

    private var securitySection: some View {
        Section(L10n.t("profile.section.security")) {
            if AppLock.isAvailable {
                Toggle(isOn: $appLockOn) {
                    SettingsLabel(title: L10n.t("settings.appLock"),
                                  subtitle: L10n.t("settings.appLockHint"),
                                  systemImage: "faceid", tint: .green)
                }
                .onChange(of: appLockOn) { _, on in AppLock.isEnabled = on }
            }
            NavigationLink(value: ProfileRoute.icloud) {
                SettingsLabel(title: L10n.t("icloud.title"), systemImage: "icloud.fill", tint: .blue)
            }
        }
    }

    private var homeScreenSection: some View {
        Section(L10n.t("profile.section.homescreen")) {
            NavigationLink(value: ProfileRoute.widgetStudio) {
                SettingsLabel(title: L10n.t("studio.title"), systemImage: "square.grid.2x2.fill", tint: .orange)
            }
            NavigationLink(value: ProfileRoute.liveActivity) {
                SettingsLabel(title: L10n.t("la.title"), systemImage: "bolt.badge.clock.fill", tint: .yellow)
            }
            NavigationLink(value: ProfileRoute.appIcon) {
                SettingsLabel(title: L10n.t("icongift.section"), systemImage: "app.gift.fill", tint: .teal)
            }
        }
    }

    private var connectionSection: some View {
        Section {
            NavigationLink(value: ProfileRoute.servers) {
                LabeledContent {
                    connectionStatus
                } label: {
                    SettingsLabel(title: appState.servers.activeProfile?.name ?? L10n.t("server.manage"),
                                  subtitle: appState.servers.activeProfile?.urlString,
                                  systemImage: "server.rack", tint: .gray)
                }
            }
        } header: {
            Text(L10n.t("profile.section.connection"))
        } footer: {
            if let serverVersion {
                Text(L10n.t("settings.serverVersion", ["version": serverVersion]))
            }
        }
    }

    private var connectionStatus: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusTint)
                .frame(width: 8, height: 8)
            Text(statusText)
        }
        .accessibilityElement(children: .combine)
    }

    private var statusTint: Color {
        switch appState.socket.state {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .red
        }
    }

    private var statusText: String {
        switch appState.socket.state {
        case .connected: return L10n.t("conn.connected")
        case .connecting: return L10n.t("conn.connecting")
        case .disconnected: return L10n.t("presence.offline")
        }
    }

    private var aboutSection: some View {
        Section {
            NavigationLink(value: ProfileRoute.about) {
                SettingsLabel(title: L10n.t("settings.about"), systemImage: "heart.text.square.fill", tint: .accentColor)
            }
        } footer: {
            Text(L10n.t("profile.about.footer", ["version": Self.appVersion]))
        }
    }

    private var accountSection: some View {
        Section {
            Button(role: .destructive) {
                confirmSignOut = true
            } label: {
                Label(L10n.t("settings.leaveDevice"), systemImage: "rectangle.portrait.and.arrow.right")
            }
            Button(role: .destructive) {
                confirmDissolve = true
            } label: {
                Label(L10n.t("settings.unpair"), systemImage: "heart.slash.fill")
            }
        } header: {
            Text(L10n.t("profile.section.account"))
        } footer: {
            Text(L10n.t("settings.leaveDeviceHint"))
        }
    }

    // MARK: Helpers

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { L10n.language },
            set: { lang in
                guard lang != L10n.language else { return }
                L10n.language = lang
                appState.uiRefresh += 1
            }
        )
    }

    private func syncPreferenceLabels() {
        appLockOn = AppLock.isEnabled
        hapticsOn = Haptics.enabled
        soundsOn = SoundEngine.enabled
    }

    private func loadServerVersion() async {
        serverVersion = nil
        guard let api = appState.api else { return }
        serverVersion = try? await api.health().version
    }

    static var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "5.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "\(short) (\(build))"
    }
}

// MARK: - Routes

/// Push destinations inside the profile sheet.
enum ProfileRoute: Hashable {
    case coupleProfile
    case pairingCode
    case notifications
    case appearance
    case haptics
    case sounds
    case icloud
    case widgetStudio
    case liveActivity
    case appIcon
    case servers
    case about

    @ViewBuilder
    var destination: some View {
        switch self {
        case .coupleProfile: CoupleProfileView()
        case .pairingCode: PairingCodeView()
        case .notifications: NotificationSettingsView()
        case .appearance: AppearanceSettingsView()
        case .haptics: HapticsSettingsView()
        case .sounds: SoundsSettingsView()
        case .icloud: ICloudView()
        case .widgetStudio: WidgetStudioView()
        case .liveActivity: LiveActivityView()
        case .appIcon: IconGiftView()
        case .servers: ServerListView()
        case .about: AboutView()
        }
    }
}

// MARK: - Hero

/// Cover photo (favourite gallery photo or the couple's colours), both
/// names, "together since" and four numbers — the top of the profile.
struct ProfileHero: View {
    @Environment(AppState.self) private var appState

    private var names: String {
        let me = appState.me?.name ?? L10n.t("common.you")
        let partner = appState.partner?.name ?? L10n.t("common.partner")
        return "\(me) & \(partner)"
    }

    var body: some View {
        VStack(spacing: 16) {
            cover
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))

            VStack(spacing: 4) {
                Text(names)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                if let key = appState.couple?.anniversary, let start = SharedDates.parse(key) {
                    Text(L10n.t("profile.together.since",
                                ["date": start.formatted(date: .long, time: .omitted)]))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(L10n.t("home.sinceHint"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            CoupleStatsRow()
        }
        .padding(.bottom, 4)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var cover: some View {
        if let photo = appState.widgetPhoto {
            RemotePhoto(api: appState.api, path: photo.thumbUrl ?? photo.url)
                .overlay(alignment: .bottomLeading) {
                    CouplePairView(me: appState.me, partner: appState.partner, size: 44, showNames: false)
                        .padding(10)
                        .glassEffect(.regular, in: .capsule)
                        .padding(14)
                }
        } else {
            ZStack {
                LinearGradient(colors: [Color.accentColor, .purple, .indigo],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                CouplePairView(me: appState.me, partner: appState.partner, size: 72, showNames: false)
                    .padding(16)
                    .glassEffect(.regular, in: .capsule)
            }
        }
    }
}

/// "500 Tage · 128 Nachrichten · 47 Momente · 26 Spiele".
struct CoupleStatsRow: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            stat(appState.daysTogether ?? 0, L10n.t("profile.stat.days"))
            divider
            stat(appState.stats?.messages ?? 0, L10n.t("profile.stat.messages"))
            divider
            stat(appState.events.count, L10n.t("profile.stat.moments"))
            divider
            stat(appState.stats?.gamesPlayed ?? 0, L10n.t("profile.stat.games"))
        }
        .padding(.vertical, 12)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Brand.tileRadius, style: .continuous))
    }

    private var divider: some View {
        Divider()
            .frame(height: 28)
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Row label

/// Settings-style row content: coloured icon tile, title, optional subtitle.
/// Use as the label of `NavigationLink`, `Toggle`, `Picker` or `LabeledContent`.
struct SettingsLabel: View {
    let title: String
    var subtitle: String? = nil
    let systemImage: String
    var tint: Color = .accentColor

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } icon: {
            IconTile(systemImage: systemImage, tint: tint, size: 30)
        }
    }
}
