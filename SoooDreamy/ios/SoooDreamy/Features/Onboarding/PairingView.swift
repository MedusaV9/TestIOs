import SwiftUI

/// Create or join a couple on the active server (incl. profile setup + QR).
/// A plain Form under a large title; the primary action sits in a Liquid
/// Glass button pinned above the home indicator.
struct PairingView: View {
    @Environment(AppState.self) private var appState

    enum Mode: Hashable, CaseIterable { case create, join }

    @State private var mode: Mode = .create
    @State private var name = ""
    @State private var avatar = Brand.avatarEmojis[0]
    @State private var colorHex = Brand.memberColors[0]
    @State private var code = ""
    @State private var busy = false
    @State private var showScanner = false
    @State private var showServerPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L10n.t("pairing.title"), selection: $mode.animation(.snappy)) {
                        Text(L10n.t("pairing.create")).tag(Mode.create)
                        Text(L10n.t("pairing.join")).tag(Mode.join)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                } footer: {
                    Text(L10n.t("pairing.subtitle"))
                }

                if mode == .join {
                    Section {
                        TextField(L10n.t("pairing.codePlaceholder"), text: $code)
                            .font(.body.monospaced())
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .textContentType(.oneTimeCode)
                            .onChange(of: code) { _, newValue in
                                code = String(newValue.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
                            }
                        Button {
                            showScanner = true
                        } label: {
                            Label(L10n.t("pairing.scanQR"), systemImage: "qrcode.viewfinder")
                        }
                    } header: {
                        Text(L10n.t("pairing.join"))
                    } footer: {
                        Text(L10n.t("pairing.qrHint"))
                    }
                }

                Section(L10n.t("pairing.profileTitle")) {
                    HStack(spacing: 14) {
                        MemberAvatar(emoji: avatar, colorHex: colorHex, size: 56)
                        TextField(L10n.t("pairing.yourName"), text: $name)
                            .textContentType(.givenName)
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
            }
            .navigationTitle(L10n.t("pairing.title"))
            .navigationSubtitle(appState.servers.activeProfile?.name ?? "")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showServerPicker = true
                    } label: {
                        Label(L10n.t("server.manage"), systemImage: "server.rack")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task { await submit() }
                } label: {
                    Group {
                        if busy {
                            ProgressView()
                        } else {
                            Text(mode == .create ? L10n.t("pairing.create") : L10n.t("pairing.join"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(busy || !isValid)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
        }
        .onAppear { consumePendingInvite() }
        .onChange(of: appState.pendingInviteCode) { _, _ in consumePendingInvite() }
        .sheet(isPresented: $showScanner) {
            NavigationStack {
                QRScannerView { text in
                    handleScan(text)
                }
                .ignoresSafeArea()
                .navigationTitle(L10n.t("pairing.scanQR"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.t("common.cancel")) { showScanner = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showServerPicker) {
            ServerListSheet()
        }
    }

    private var isValid: Bool {
        let nameOK = !name.trimmingCharacters(in: .whitespaces).isEmpty
        return mode == .create ? nameOK : (nameOK && code.count == 6)
    }

    private func handleScan(_ text: String) {
        showScanner = false
        if let payload = PairQRPayload.decode(text) {
            // Server + code in one — same path as an invitation link.
            appState.applyPairingInvite(server: payload.server, code: payload.code)
        } else {
            appState.applyPairingInvite(server: nil, code: text)
        }
        consumePendingInvite()
        Haptics.shared.success()
    }

    /// An invitation (link or QR) switches to join mode with the code filled in.
    private func consumePendingInvite() {
        guard let pending = appState.pendingInviteCode else { return }
        withAnimation(.snappy) {
            mode = .join
            code = pending
        }
        appState.pendingInviteCode = nil
    }

    private func submit() async {
        guard let profile = appState.servers.activeProfile,
              let url = profile.baseURL else { return }
        busy = true
        defer { busy = false }
        let api = API(baseURL: url, token: nil)
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        do {
            let auth: AuthResponse
            if mode == .create {
                auth = try await api.createCouple(name: trimmedName, avatar: avatar, color: "#" + colorHex)
            } else {
                auth = try await api.joinCouple(code: code, name: trimmedName, avatar: avatar, color: "#" + colorHex)
            }
            SoundEngine.shared.play(.tada)
            Haptics.shared.success()
            appState.completeAuth(profileID: profile.id, auth: auth)
        } catch let error as APIError {
            if case .http(let status, let codeStr, _) = error {
                if status == 404 || codeStr == "unknown_code" {
                    appState.notify(L10n.t("pairing.unknownCode"), style: .error)
                } else if status == 409 || codeStr == "couple_full" {
                    appState.notify(L10n.t("pairing.coupleFull"), style: .error)
                } else {
                    appState.notify(error.localizedDescription, style: .error)
                }
            } else {
                appState.notify(error.localizedDescription, style: .error)
            }
            Haptics.shared.warning()
        } catch {
            appState.notify(error.localizedDescription, style: .error)
            Haptics.shared.warning()
        }
    }
}
