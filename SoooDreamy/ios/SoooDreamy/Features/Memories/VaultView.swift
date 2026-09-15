import AVKit
import PhotosUI
import SwiftUI
import UIKit

// Spicy Vault — a separately locked, end-to-end encrypted space for private
// couple content (photos, videos, notes).
//
// Security properties (see VaultCrypto.swift for the format):
// - Own PIN, independent of the app lock; Face ID as convenience unlock.
// - Every blob is AES-GCM sealed ON-DEVICE; the server stores ciphertext.
// - Decrypted bytes live in memory only and are wiped on lock. (Exception:
//   video playback needs a short-lived temp file — written with complete
//   file protection and deleted the moment the player closes.)
// - Vault content NEVER appears in widgets, the shared snapshot, notifications
//   or the iCloud/file backup (those code paths simply don't know the vault).
// - Panic hide: shaking the device instantly locks the vault (optional).

struct VaultView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    @State private var vault = VaultSession()

    var body: some View {
        Group {
            switch vault.phase {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .needsSetup:
                VaultSetupView(vault: vault)
            case .locked:
                VaultLockView(vault: vault)
            case .unlocked:
                VaultGridView(vault: vault)
            }
        }
        .navigationTitle(L10n.t("vault.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await vault.loadConfig(api: appState.api) }
        .onChange(of: scenePhase) { _, phase in
            // Leaving the app always relocks — no spicy content in the
            // app switcher or after handing the phone over.
            if phase != .active { vault.lock() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            if UserDefaults.standard.object(forKey: "sooodreamy.vault.panicShake") as? Bool ?? true {
                vault.lock()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent else { return }
            vault.handle(event)
        }
    }
}

// MARK: - Setup

private struct VaultSetupView: View {
    @Environment(AppState.self) private var appState
    let vault: VaultSession

    @State private var pin = ""
    @State private var confirm = ""
    @State private var working = false
    @State private var mismatch = false

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentColor.gradient)
                        .accessibilityHidden(true)
                    Text(L10n.t("vault.setup.title"))
                        .font(.title2.weight(.bold))
                    Text(L10n.t("vault.setup.explain"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }

            Section {
                SecureField(L10n.t("vault.setup.pinField"), text: $pin)
                    .keyboardType(.numberPad)
                    .textContentType(.newPassword)
                SecureField(L10n.t("vault.setup.confirmField"), text: $confirm)
                    .keyboardType(.numberPad)
                    .textContentType(.newPassword)
            } footer: {
                if mismatch {
                    Text(L10n.t("vault.setup.mismatch"))
                        .foregroundStyle(Color.red)
                } else {
                    Text(L10n.t("vault.setup.shareHint"))
                }
            }

            Section {
                Button {
                    createVault()
                } label: {
                    HStack {
                        Label(L10n.t("vault.setup.create"), systemImage: "lock.fill")
                        if working {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(working || pin.count < 4)
            }
        }
    }

    private func createVault() {
        guard pin == confirm else {
            mismatch = true
            Haptics.shared.warning()
            return
        }
        mismatch = false
        working = true
        Task {
            let ok = await vault.setup(pin: pin, api: appState.api)
            if ok {
                Haptics.shared.success()
                SoundEngine.shared.play(.sparkle)
            } else {
                appState.notify(vault.errorMessage ?? L10n.t("vault.setup.failed"), style: .error)
            }
            working = false
        }
    }
}

// MARK: - Lock screen

private struct VaultLockView: View {
    @Environment(AppState.self) private var appState
    let vault: VaultSession

    @State private var pin = ""
    @State private var working = false
    @State private var wrongPin = false
    @State private var confirmReset = false
    @FocusState private var pinFocused: Bool

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.accentColor.gradient)
                        .symbolEffect(.bounce, value: wrongPin)
                        .accessibilityHidden(true)
                    Text(L10n.t("vault.locked.title"))
                        .font(.title3.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }

            Section {
                SecureField(L10n.t("vault.locked.pinField"), text: $pin)
                    .keyboardType(.numberPad)
                    .focused($pinFocused)
                    .onSubmit { unlockWithPin() }
                Button {
                    unlockWithPin()
                } label: {
                    HStack {
                        Label(L10n.t("vault.locked.unlock"), systemImage: "lock.open")
                        if working {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(working || pin.count < 4)
                if vault.biometricsAvailable {
                    Button {
                        unlockWithBiometrics()
                    } label: {
                        Label(L10n.t("vault.locked.faceId"), systemImage: "faceid")
                    }
                    .disabled(working)
                }
            } footer: {
                if wrongPin {
                    Text(L10n.t("vault.locked.wrongPin"))
                        .foregroundStyle(Color.red)
                }
            }

            Section {
                Button(role: .destructive) {
                    confirmReset = true
                } label: {
                    Text(L10n.t("vault.locked.forgot"))
                }
            }
        }
        .task {
            // Offer Face ID right away when a stored key exists.
            if vault.biometricsAvailable {
                unlockWithBiometrics()
            } else {
                pinFocused = true
            }
        }
        .confirmationDialog(L10n.t("vault.reset.title"),
                            isPresented: $confirmReset, titleVisibility: .visible) {
            Button(L10n.t("vault.reset.confirm"), role: .destructive) { resetVault() }
        } message: {
            Text(L10n.t("vault.reset.message"))
        }
    }

    private func unlockWithPin() {
        guard pin.count >= 4, !working else { return }
        working = true
        wrongPin = false
        Task {
            let ok = await vault.unlock(pin: pin, api: appState.api)
            if ok {
                Haptics.shared.success()
                SoundEngine.shared.play(.unlock)
            } else {
                wrongPin = true
                pin = ""
                Haptics.shared.warning()
            }
            working = false
        }
    }

    private func unlockWithBiometrics() {
        guard !working else { return }
        working = true
        Task {
            let ok = await vault.unlockWithBiometrics(api: appState.api)
            if ok {
                Haptics.shared.success()
                SoundEngine.shared.play(.unlock)
            } else {
                pinFocused = true
            }
            working = false
        }
    }

    private func resetVault() {
        working = true
        Task {
            do {
                try await vault.reset(api: appState.api)
                appState.notify(L10n.t("vault.reset.done"), style: .info)
            } catch {
                appState.handleAPIError(error)
            }
            working = false
        }
    }
}

// MARK: - Unlocked grid

private struct VaultGridView: View {
    @Environment(AppState.self) private var appState
    let vault: VaultSession

    @State private var photoItem: PhotosPickerItem?
    @State private var videoItem: PhotosPickerItem?
    @State private var showNoteComposer = false
    @State private var showPhotoPicker = false
    @State private var showVideoPicker = false
    @State private var processing: String?
    @State private var viewerTarget: VaultItem?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        Group {
            if vault.items.isEmpty {
                ContentUnavailableView {
                    Label(L10n.t("vault.empty.title"), systemImage: "lock.open.fill")
                } description: {
                    Text(L10n.t("vault.empty.subtitle"))
                } actions: {
                    addMenu {
                        Label(L10n.t("common.add"), systemImage: "plus")
                    }
                    .buttonStyle(.glassProminent)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(vault.items) { item in
                            Button {
                                viewerTarget = item
                            } label: {
                                VaultItemCell(vault: vault, item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text(L10n.t("vault.shakeHint"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(16)
                }
                .refreshable {
                    if let api = appState.api { await vault.refreshItems(api: api) }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                addMenu {
                    Label(L10n.t("common.add"), systemImage: "plus")
                }
                .disabled(processing != nil)
                Button {
                    vault.lock()
                } label: {
                    Label(L10n.t("vault.lockNow"), systemImage: "lock.fill")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let processing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(processing)
                        .font(.subheadline.weight(.medium))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 18)
                .glassEffect(.regular, in: .capsule)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: processing)
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .photosPicker(isPresented: $showVideoPicker, selection: $videoItem, matching: .videos)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            Task { await addPhoto(item) }
        }
        .onChange(of: videoItem) { _, item in
            guard let item else { return }
            videoItem = nil
            Task { await addVideo(item) }
        }
        .sheet(isPresented: $showNoteComposer) {
            VaultNoteComposer { title, text in
                addNote(title: title, text: text)
            }
        }
        .fullScreenCover(item: $viewerTarget) { item in
            VaultItemViewer(vault: vault, item: item)
        }
    }

    /// PhotosPicker can't live inside Menu — route via presentation flags.
    private func addMenu<Content: View>(@ViewBuilder label: () -> Content) -> some View {
        Menu {
            Button {
                showPhotoPicker = true
            } label: {
                Label(L10n.t("vault.add.photo"), systemImage: "photo")
            }
            Button {
                showVideoPicker = true
            } label: {
                Label(L10n.t("vault.add.video"), systemImage: "video")
            }
            Button {
                showNoteComposer = true
            } label: {
                Label(L10n.t("vault.add.note"), systemImage: "note.text")
            }
        } label: {
            label()
        }
    }

    // MARK: Add flows

    private func addPhoto(_ item: PhotosPickerItem) async {
        processing = L10n.t("vault.encrypting")
        defer { processing = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            appState.notify(L10n.t("memories.gallery.readFailed"), style: .error)
            return
        }
        let scaled = ImageScaler.downscaled(image, maxDimension: 2048)
        guard let jpeg = scaled.jpegData(compressionQuality: 0.85) else { return }
        let poster = ImageScaler.downscaled(image, maxDimension: 240).jpegData(compressionQuality: 0.5)
        let meta = VaultMeta(kind: "photo", caption: nil, poster: poster, duration: nil,
                             width: Int(scaled.size.width), height: Int(scaled.size.height))
        await sealAndUpload(meta: meta, content: jpeg)
    }

    private func addVideo(_ item: PhotosPickerItem) async {
        processing = L10n.t("memories.videos.compressing")
        defer { processing = nil }
        do {
            guard let picked = try await item.loadTransferable(type: PickedVaultVideo.self) else {
                appState.notify(L10n.t("memories.videos.readFailed"), style: .error)
                return
            }
            let result = try await VideoTranscoder.compress(sourceURL: picked.url)
            try? FileManager.default.removeItem(at: picked.url)
            defer { try? FileManager.default.removeItem(at: result.fileURL) }
            guard result.data.count <= 55 * 1024 * 1024 else {
                appState.notify(L10n.t("vault.tooBig"), style: .error)
                return
            }
            processing = L10n.t("vault.encrypting")
            let poster = result.poster.flatMap {
                ImageScaler.downscaled($0, maxDimension: 240).jpegData(compressionQuality: 0.5)
            }
            let meta = VaultMeta(kind: "video", caption: nil, poster: poster,
                                 duration: result.duration, width: result.width, height: result.height)
            await sealAndUpload(meta: meta, content: result.data)
        } catch {
            appState.notify(L10n.t("memories.videos.readFailed"), style: .error)
        }
    }

    private func addNote(title: String, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        processing = L10n.t("vault.encrypting")
        let meta = VaultMeta(kind: "note", caption: title.trimmingCharacters(in: .whitespacesAndNewlines),
                             poster: nil, duration: nil, width: nil, height: nil)
        Task {
            await sealAndUpload(meta: meta, content: Data(trimmed.utf8))
            processing = nil
        }
    }

    private func sealAndUpload(meta: VaultMeta, content: Data) async {
        do {
            processing = L10n.t("vault.uploading")
            _ = try await vault.upload(meta: meta, content: content, api: appState.api)
            Haptics.shared.success()
            SoundEngine.shared.play(.sparkle)
            appState.notify(L10n.t("vault.uploaded"), style: .love)
        } catch {
            appState.handleAPIError(error)
        }
    }
}

/// Vault-private movie transfer (same tmp-copy trick as the gallery's).
private struct PickedVaultVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("vault-picked-\(UUID().uuidString).mov")
            try FileManager.default.copyItem(at: received.file, to: dest)
            return PickedVaultVideo(url: dest)
        }
    }
}

// MARK: - Grid cell

private struct VaultItemCell: View {
    @Environment(AppState.self) private var appState
    let vault: VaultSession
    let item: VaultItem

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(preview)
            .clipped()
            .overlay(alignment: .bottomTrailing) { kindBadge }
            .task(id: item.id) {
                // Fetch + decrypt lazily; the tiny poster inside the meta
                // makes this cheap even for videos.
                if vault.cached(item.id) == nil {
                    _ = await vault.decrypt(item, api: appState.api)
                }
            }
            .accessibilityLabel(L10n.t("vault.add.\(item.kind)"))
    }

    @ViewBuilder
    private var preview: some View {
        let _ = vault.cacheVersion // observe cache updates
        if let decrypted = vault.cached(item.id) {
            if let poster = decrypted.posterImage ?? decrypted.image {
                Image(uiImage: poster)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let note = decrypted.noteText {
                notePreview(title: decrypted.meta.caption, text: note)
            } else {
                placeholder
            }
        } else {
            placeholder
        }
    }

    private func notePreview(title: String?, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(4)
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.cardBackground)
    }

    private var placeholder: some View {
        ZStack {
            Color.tertiaryCardBackground
            ProgressView()
        }
    }

    @ViewBuilder
    private var kindBadge: some View {
        let icon = switch item.kind {
        case "video": "video.fill"
        case "note": "note.text"
        default: "photo.fill"
        }
        Image(systemName: icon)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(5)
            .background(.ultraThinMaterial, in: Circle())
            .environment(\.colorScheme, .dark)
            .padding(4)
            .accessibilityHidden(true)
    }
}

// MARK: - Note composer

private struct VaultNoteComposer: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, String) -> Void

    @State private var title = ""
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.t("vault.note.titleField"), text: $title)
                    TextField(L10n.t("vault.note.textField"), text: $text, axis: .vertical)
                        .lineLimit(6...14)
                        .focused($focused)
                }
            }
            .navigationTitle(L10n.t("vault.add.note"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("vault.note.save")) {
                        dismiss()
                        onSave(title, text)
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
    }
}

// MARK: - Fullscreen viewer

/// Black media stage with dark chrome; decrypted bytes stay in memory.
private struct VaultItemViewer: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let vault: VaultSession
    let item: VaultItem

    @State private var decrypted: DecryptedVaultItem?
    @State private var player: AVPlayer?
    @State private var tempVideoURL: URL?
    @State private var confirmDelete = false
    @State private var busy = false

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.ignoresSafeArea())
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.t("common.close"), systemImage: "xmark") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        if busy {
                            ProgressView()
                        } else {
                            Button(role: .destructive) {
                                confirmDelete = true
                            } label: {
                                Label(L10n.t("common.delete"), systemImage: "trash")
                            }
                        }
                    }
                }
                .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .environment(\.colorScheme, .dark)
        .task { await load() }
        .onDisappear { cleanupVideo() }
        .confirmationDialog(L10n.t("vault.deleteConfirm"),
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L10n.t("common.delete"), role: .destructive) { deleteItem() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let decrypted {
            switch decrypted.meta.kind {
            case "photo":
                if let image = decrypted.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            case "video":
                if let player {
                    VideoPlayer(player: player)
                } else {
                    ProgressView()
                }
            default:
                noteView(decrypted)
            }
        } else {
            VStack(spacing: 10) {
                ProgressView()
                Text(L10n.t("vault.decrypting"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func noteView(_ decrypted: DecryptedVaultItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let title = decrypted.meta.caption, !title.isEmpty {
                    Text(title)
                        .font(.title2.weight(.bold))
                }
                Text(decrypted.noteText ?? "")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    private func load() async {
        decrypted = await vault.decrypt(item, api: appState.api)
        guard let decrypted, decrypted.meta.kind == "video" else { return }
        // AVPlayer needs a file — short-lived, protected, deleted on close.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vault-play-\(item.id).mp4")
        do {
            try decrypted.content.write(to: url, options: [.atomic, .completeFileProtection])
            tempVideoURL = url
            let avPlayer = AVPlayer(url: url)
            player = avPlayer
            avPlayer.play()
        } catch {
            appState.notify(L10n.t("vault.decryptFailed"), style: .error)
        }
    }

    private func cleanupVideo() {
        player?.pause()
        player = nil
        if let tempVideoURL {
            try? FileManager.default.removeItem(at: tempVideoURL)
        }
        tempVideoURL = nil
    }

    private func deleteItem() {
        busy = true
        Task {
            do {
                try await vault.delete(item, api: appState.api)
                appState.notify(L10n.t("vault.deleted"), style: .info)
                dismiss()
            } catch {
                appState.handleAPIError(error)
            }
            busy = false
        }
    }
}

// MARK: - Shake detection (panic hide)

extension Notification.Name {
    /// Posted by UIWindow when the user shakes the device.
    static let deviceDidShake = Notification.Name("sooodreamy.deviceDidShake")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
    }
}
