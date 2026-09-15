import SwiftUI

// Detail screens pushed from ProfileView. Each one is a plain `Form`/`List`
// with system rows — the navigation chrome (inline title, Liquid Glass bar,
// back button) comes from the sheet's NavigationStack.

// MARK: - Our profile (you + couple)

/// Name, emoji and colour of the signed-in member plus the couple's name and
/// anniversary. One "Save" in the toolbar writes everything that changed.
struct CoupleProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var avatar = Brand.avatarEmojis[0]
    @State private var colorHex = Brand.memberColors[0]
    @State private var coupleName = ""
    @State private var anniversary = Date()
    @State private var anniversaryTouched = false
    @State private var saving = false

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var trimmedCoupleName: String { coupleName.trimmingCharacters(in: .whitespaces) }

    private var memberChanged: Bool {
        trimmedName != (appState.me?.name ?? "")
            || avatar != (appState.me?.avatar ?? "")
            || colorHex != currentColorHex
    }

    private var coupleChanged: Bool {
        trimmedCoupleName != (appState.couple?.name ?? "") || anniversaryTouched
    }

    private var canSave: Bool {
        !saving && !trimmedName.isEmpty && (memberChanged || coupleChanged)
    }

    var body: some View {
        Form {
            Section(L10n.t("profile.section.you")) {
                HStack(spacing: 14) {
                    MemberAvatar(emoji: avatar, colorHex: colorHex, size: 56)
                    TextField(L10n.t("pairing.yourName"), text: $name)
                        .textContentType(.name)
                        .submitLabel(.done)
                }
                .padding(.vertical, 4)
            }

            Section(L10n.t("pairing.avatar")) {
                EmojiPickerGrid(emojis: Brand.avatarEmojis, selection: $avatar)
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            }

            Section(L10n.t("pairing.color")) {
                MemberColorPicker(selection: $colorHex)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }

            Section {
                TextField(L10n.t("settings.coupleName"), text: $coupleName)
                    .submitLabel(.done)
                DatePicker(L10n.t("settings.anniversary"),
                           selection: $anniversary,
                           in: ...Date(),
                           displayedComponents: .date)
                    .onChange(of: anniversary) { anniversaryTouched = true }
            } header: {
                Text(L10n.t("settings.couple"))
            } footer: {
                Text(L10n.t(appState.couple?.anniversary == nil ? "home.sinceHint" : "settings.anniversaryHint"))
            }
        }
        .navigationTitle(L10n.t("profile.couple.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await save() }
                } label: {
                    if saving {
                        ProgressView()
                    } else {
                        Text(L10n.t("common.save"))
                    }
                }
                .disabled(!canSave)
            }
        }
        .onAppear(perform: load)
    }

    private var currentColorHex: String {
        appState.me?.color.replacingOccurrences(of: "#", with: "") ?? Brand.memberColors[0]
    }

    private func load() {
        name = appState.me?.name ?? ""
        avatar = appState.me?.avatar ?? Brand.avatarEmojis[0]
        colorHex = currentColorHex
        coupleName = appState.couple?.name ?? ""
        if let key = appState.couple?.anniversary, let date = SharedDates.parse(key) {
            anniversary = date
        }
        anniversaryTouched = false
    }

    private func save() async {
        guard let api = appState.api, canSave else { return }
        saving = true
        defer { saving = false }
        do {
            if memberChanged {
                _ = try await api.updateMe(name: trimmedName, avatar: avatar, color: "#" + colorHex)
            }
            if coupleChanged {
                let couple = try await api.updateCouple(
                    name: trimmedCoupleName != (appState.couple?.name ?? "") ? trimmedCoupleName : nil,
                    anniversary: anniversaryTouched ? SharedDates.todayKey(anniversary) : nil)
                appState.couple = couple
            }
            await appState.refreshCouple()
            appState.updateWidgetSnapshot()
            Haptics.shared.success()
            appState.notify(L10n.t("profile.saved"), style: .success)
            dismiss()
        } catch {
            appState.handleAPIError(error)
        }
    }
}

// MARK: - Couple code & QR

/// The couple code + pairing QR again — for a new device or when the partner
/// needs the code once more.
struct PairingCodeView: View {
    @Environment(AppState.self) private var appState
    @State private var copied = false

    var body: some View {
        List {
            if let code = appState.couple?.code {
                Section {
                    VStack(spacing: 16) {
                        Text(code.map(String.init).joined(separator: " "))
                            .font(.system(.largeTitle, design: .monospaced).weight(.bold))
                            .kerning(2)
                            .accessibilityLabel(L10n.t("pairing.codeA11y", ["code": code]))

                        HStack(spacing: 10) {
                            Button {
                                UIPasteboard.general.string = code
                                copied = true
                                Task {
                                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                                    copied = false
                                }
                            } label: {
                                Label(L10n.t(copied ? "common.copied" : "common.copy"),
                                      systemImage: copied ? "checkmark" : "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .sensoryFeedback(.success, trigger: copied) { _, new in new }

                            ShareLink(item: appState.inviteURL ?? URL(string: "sooodreamy://pair")!,
                                      subject: Text(L10n.t("invite.subject")),
                                      message: Text(appState.inviteURL == nil ? shareText(code: code)
                                                                              : L10n.t("invite.message", ["code": code]))) {
                                Label(L10n.t("invite.share"), systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        .controlSize(.large)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } header: {
                    Text(L10n.t("pairing.yourCode"))
                } footer: {
                    Text(L10n.t("settings.pairingHint"))
                }

                if let server = appState.servers.activeProfile?.urlString,
                   let qr = QRGenerator.image(for: PairQRPayload.encode(server: server, code: code)) {
                    Section {
                        Image(uiImage: qr)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 220, height: 220)
                            .padding(12)
                            .background(.white, in: RoundedRectangle(cornerRadius: Brand.tileRadius, style: .continuous))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .accessibilityLabel(L10n.t("pairing.showQR"))
                    } header: {
                        Text(L10n.t("pairing.showQR"))
                    } footer: {
                        Text(L10n.t("pairing.qrHint"))
                    }
                }
            } else {
                ContentUnavailableView(L10n.t("profile.code.title"), systemImage: "qrcode")
            }
        }
        .navigationTitle(L10n.t("profile.code.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func shareText(code: String) -> String {
        let server = appState.servers.activeProfile?.urlString ?? ""
        return L10n.t("pairing.shareText", ["server": server, "code": code])
    }
}

// MARK: - Appearance

struct AppearanceSettingsView: View {
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    var body: some View {
        Form {
            Section {
                Picker(L10n.t("appearance.title"), selection: $appearanceRaw) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Label(L10n.t(mode.titleKey), systemImage: mode.systemImage)
                            .tag(mode.rawValue)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } footer: {
                Text(L10n.t("appearance.footer"))
            }
        }
        .navigationTitle(L10n.t("appearance.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: appearanceRaw)
    }
}

// MARK: - Sounds

struct SoundsSettingsView: View {
    @State private var soundsOn = SoundEngine.enabled

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $soundsOn) {
                    Label(L10n.t("settings.sounds"), systemImage: "speaker.wave.2.fill")
                }
                .onChange(of: soundsOn) { _, on in
                    SoundEngine.enabled = on
                    if on { SoundEngine.shared.play(.chime) }
                }
            } footer: {
                Text(L10n.t("sounds.footer"))
            }

            if soundsOn {
                Section(L10n.t("settings.soundvol.title")) {
                    ForEach(SoundEngine.Category.allCases) { category in
                        SoundVolumeRow(category: category)
                    }
                }
            }
        }
        .navigationTitle(L10n.t("settings.sounds"))
        .navigationBarTitleDisplayMode(.inline)
        .animation(.snappy, value: soundsOn)
    }
}

/// One per-category volume slider — releasing the thumb plays a preview at
/// the new level so tuning is immediate.
private struct SoundVolumeRow: View {
    let category: SoundEngine.Category
    @State private var volume: Double

    init(category: SoundEngine.Category) {
        self.category = category
        _volume = State(initialValue: SoundEngine.volume(for: category))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L10n.t(category.titleKey), systemImage: category.icon)
            Slider(value: $volume, in: 0...1) {
                Text(L10n.t(category.titleKey))
            } minimumValueLabel: {
                Image(systemName: "speaker.fill")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
            } maximumValueLabel: {
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
            } onEditingChanged: { editing in
                if !editing {
                    SoundEngine.setVolume(volume, for: category)
                    SoundEngine.shared.play(category.previewSound)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Haptics

struct HapticsSettingsView: View {
    @State private var hapticsOn = Haptics.enabled
    @State private var showStudio = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $hapticsOn) {
                    Label(L10n.t("settings.haptics"), systemImage: "iphone.radiowaves.left.and.right")
                }
                .onChange(of: hapticsOn) { _, on in
                    Haptics.enabled = on
                    if on { Haptics.shared.play(.heartbeat) }
                }
            } footer: {
                Text(Haptics.deviceSupportsHaptics ? L10n.t("haptics.footer") : L10n.t("haptics.unsupported"))
            }

            if hapticsOn {
                Section {
                    ForEach(TouchKind.allCases) { kind in
                        Button {
                            Haptics.shared.play(kind)
                        } label: {
                            LabeledContent {
                                Image(systemName: "waveform")
                                    .foregroundStyle(Color.accentColor)
                            } label: {
                                Label {
                                    Text(L10n.t(kind.titleKey))
                                } icon: {
                                    Text(kind.emoji)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                } header: {
                    Text(L10n.t("haptics.preview"))
                } footer: {
                    Text(L10n.t("haptics.previewHint"))
                }

                Section {
                    Button {
                        showStudio = true
                    } label: {
                        SettingsLabel(title: L10n.t("touchstudio.title"),
                                      subtitle: L10n.t("touchstudio.tileHint"),
                                      systemImage: "hand.tap.fill", tint: .accentColor)
                    }
                    .tint(.primary)
                }
            }
        }
        .navigationTitle(L10n.t("settings.haptics"))
        .navigationBarTitleDisplayMode(.inline)
        .animation(.snappy, value: hapticsOn)
        .sheet(isPresented: $showStudio) { TouchStudioView() }
    }
}

// MARK: - About

struct AboutView: View {
    @Environment(AppState.self) private var appState
    @State private var showWhatsNew = false
    @State private var showIntro = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.accentColor.gradient)
                        .accessibilityHidden(true)
                    Text("SoooDreamy")
                        .font(.title.weight(.bold))
                    Text(L10n.t("settings.madeWith"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .listRowBackground(Color.clear)
            }
            Section {
                LabeledContent(L10n.t("settings.version"), value: ProfileView.appVersion)
                LabeledContent("iOS", value: UIDevice.current.systemVersion)
            }
            Section {
                Button {
                    showWhatsNew = true
                } label: {
                    Label(L10n.t("about.whatsNew"), systemImage: "sparkles")
                }
                Button {
                    showIntro = true
                } label: {
                    Label(L10n.t("about.replayIntro"), systemImage: "play.circle")
                }
            }
        }
        .navigationTitle(L10n.t("settings.about"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView()
        }
        .fullScreenCover(isPresented: $showIntro) {
            IntroCutsceneView(me: appState.me, partner: appState.partner) { showIntro = false }
        }
    }
}
