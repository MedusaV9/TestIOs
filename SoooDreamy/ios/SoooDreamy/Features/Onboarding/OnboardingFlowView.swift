import SwiftUI

/// First launch: intro cutscene → welcome → add your server. Pairing follows
/// via `phase`. The welcome page is laid out like Apple's own: big symbol,
/// title, a short feature list and one prominent call to action at the bottom.
struct OnboardingFlowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("sooodreamy.intro.seen") private var introSeen = false
    @State private var showServerSetup = false
    @State private var revealed = false

    private static let features: [(symbol: String, key: String, tint: Color)] = [
        ("heart.fill", "onboarding.feature1", .accentColor),
        ("bubble.left.and.bubble.right.fill", "onboarding.feature2", .blue),
        ("gamecontroller.fill", "onboarding.feature3", .purple),
        ("sparkles", "onboarding.feature4", .orange),
    ]

    var body: some View {
        ZStack {
            if introSeen {
                welcome
                    .transition(.opacity)
            } else {
                IntroCutsceneView { introSeen = true }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: introSeen)
    }

    private var welcome: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 12) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.accentColor.gradient)
                            .symbolEffect(.pulse, options: .repeating)
                            .accessibilityHidden(true)
                        Text(L10n.t("onboarding.title"))
                            .font(.largeTitle.weight(.bold))
                        Text(L10n.t("onboarding.tagline"))
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    .padding(.horizontal, 24)

                    // Rows settle in one after another, like the intro before them.
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(Array(Self.features.enumerated()), id: \.offset) { index, feature in
                            featureRow(feature.symbol, feature.key, feature.tint)
                                .opacity(revealed ? 1 : 0)
                                .offset(y: revealed ? 0 : 14)
                                .animation(reduceMotion ? nil
                                           : .spring(duration: 0.6, bounce: 0.15).delay(0.15 + Double(index) * 0.09),
                                           value: revealed)
                        }
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, 24)
            }
            .onAppear { revealed = true }
            .groupedScreenBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker(L10n.t("onboarding.language"), selection: languageBinding) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(L10n.t(lang.displayNameKey)).tag(lang)
                            }
                        }
                    } label: {
                        Label(L10n.t("onboarding.language"), systemImage: "globe")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    SoundEngine.shared.play(.chime)
                    showServerSetup = true
                } label: {
                    Text(L10n.t("onboarding.start"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
        }
        .sheet(isPresented: $showServerSetup) {
            ServerSetupSheet(isOnboarding: true)
        }
    }

    private func featureRow(_ icon: String, _ key: String, _ tint: Color) -> some View {
        Label {
            Text(L10n.t(key))
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 36)
        }
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
}

/// Add/edit a server with live connection testing.
/// Used from onboarding and from Profile → Server.
struct ServerSetupSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var isOnboarding = false
    var existing: ServerProfile? = nil

    @State private var name = ""
    @State private var urlString = ""
    @State private var testing = false
    @State private var testResult: (ok: Bool, text: String)? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.t("server.name"), text: $name)
                        .textContentType(.organizationName)
                    TextField(L10n.t("server.url"), text: $urlString)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: urlString) { testResult = nil }
                } header: {
                    Text(L10n.t("server.setupTitle"))
                } footer: {
                    Text(L10n.t("server.setupSubtitle"))
                }

                Section {
                    Button {
                        Task { await test() }
                    } label: {
                        HStack {
                            Label(L10n.t("server.test"), systemImage: "bolt.horizontal")
                            if testing {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(testing || normalized == nil)

                    if let result = testResult {
                        Label {
                            Text(result.text)
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: result.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result.ok ? Color.green : Color.red)
                        }
                        .font(.footnote)
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.t("server.hint"))
                        Text(L10n.t("server.buildBadge", ["version": appVersionLabel]))
                    }
                }
            }
            .navigationTitle(L10n.t(existing == nil ? "server.add" : "common.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isOnboarding ? L10n.t("server.continue") : L10n.t("common.save")) {
                        save()
                    }
                    .disabled(normalized == nil)
                }
            }
            .animation(.snappy, value: testResult?.ok)
        }
        .onAppear {
            if let existing {
                name = existing.name
                urlString = existing.urlString
            }
        }
    }

    private var appVersionLabel: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    private var normalized: String? {
        ServerProfile.normalize(urlString)
    }

    private func test() async {
        guard let normalized, let url = URL(string: normalized) else {
            testResult = (false, L10n.t("server.invalidURL"))
            return
        }
        testing = true
        defer { testing = false }
        do {
            let health = try await API(baseURL: url, token: nil).health()
            testResult = (true, L10n.t("server.testOK", ["name": health.name, "version": health.version]))
            Haptics.shared.success()
        } catch {
            let raw = error.localizedDescription
            let looksLikeATS = raw.localizedCaseInsensitiveContains("App Transport Security")
                || raw.localizedCaseInsensitiveContains("secure connection")
            testResult = (false, looksLikeATS
                          ? L10n.t("server.testFailATS")
                          : L10n.t("server.testFail", ["error": raw]))
            Haptics.shared.warning()
        }
    }

    private func save() {
        guard let normalized else { return }
        if var existing {
            existing.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? normalized : name
            existing.urlString = normalized
            appState.servers.update(existing)
        } else if let profile = appState.servers.add(name: name, urlString: normalized) {
            appState.servers.setActive(id: profile.id)
        }
        Haptics.shared.success()
        dismiss()
    }
}
