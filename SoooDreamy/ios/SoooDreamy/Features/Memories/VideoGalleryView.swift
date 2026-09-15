import AVFoundation
import AVKit
import Combine
import PhotosUI
import SwiftUI
import UIKit

/// Shared video gallery: Photos-style grid with duration badges, PhotosPicker
/// upload with client-side H.264 compression, poster thumbnails and a
/// fullscreen AVPlayer (server streams with Range support).
struct VideoGalleryView: View {
    @Environment(AppState.self) private var appState

    @State private var videos: [Video] = []
    @State private var loading = true
    @State private var pickerItem: PhotosPickerItem?
    @State private var pendingUpload: PendingVideoUpload?
    /// nil = idle, otherwise the current phase label under the spinner.
    @State private var processingPhase: String?
    @State private var playerTarget: Video?
    @State private var favoritesOnly = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    private var displayedVideos: [Video] {
        favoritesOnly ? videos.filter { !($0.favorites ?? []).isEmpty } : videos
    }

    var body: some View {
        Group {
            if loading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if videos.isEmpty {
                ContentUnavailableView {
                    Label(L10n.t("memories.videos.empty.title"), systemImage: "film.stack")
                } description: {
                    Text(L10n.t("memories.videos.empty.subtitle"))
                } actions: {
                    PhotosPicker(selection: $pickerItem, matching: .videos, photoLibrary: .shared()) {
                        Label(L10n.t("memories.videos.add"), systemImage: "video.badge.plus")
                    }
                    .buttonStyle(.glassProminent)
                }
            } else if favoritesOnly && displayedVideos.isEmpty {
                ContentUnavailableView {
                    Label(L10n.t("memories.gallery.favEmpty.title"), systemImage: "heart")
                } description: {
                    Text(L10n.t("memories.videos.favEmpty.subtitle"))
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(displayedVideos) { video in
                            Button {
                                playerTarget = video
                            } label: {
                                VideoCell(video: video, api: appState.api, memberId: appState.memberId)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(video.caption ?? L10n.t("memories.videos.title"))
                        }
                    }
                    .padding(.bottom, 24)
                }
                .refreshable { await loadVideos() }
            }
        }
        .navigationTitle(L10n.t("memories.videos.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    withAnimation(.snappy) { favoritesOnly.toggle() }
                } label: {
                    Label(L10n.t("memories.gallery.filterFavorites"),
                          systemImage: favoritesOnly ? "heart.fill" : "heart")
                }
                .disabled(videos.isEmpty)
                PhotosPicker(selection: $pickerItem, matching: .videos, photoLibrary: .shared()) {
                    Label(L10n.t("memories.videos.add"), systemImage: "video.badge.plus")
                }
                .disabled(processingPhase != nil)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let phase = processingPhase {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(phase)
                        .font(.subheadline.weight(.medium))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 18)
                .glassEffect(.regular, in: .capsule)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: processingPhase)
        .task { await loadVideos() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            pickerItem = nil
            Task { await prepareVideo(item) }
        }
        .sheet(item: $pendingUpload) { pending in
            VideoCaptionSheet(pending: pending) { caption in
                upload(pending, caption: caption)
            }
        }
        .fullScreenCover(item: $playerTarget) { video in
            VideoPlayerScreen(videos: $videos, startId: video.id)
        }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent else { return }
            handleServerEvent(event)
        }
    }

    // MARK: Data

    private func loadVideos() async {
        guard let api = appState.api else { return }
        do {
            let list = try await api.videos()
            videos = list.sorted { $0.createdAt > $1.createdAt }
        } catch {
            appState.handleAPIError(error)
        }
        loading = false
    }

    private func apply(_ video: Video) {
        withAnimation(.snappy) {
            if let idx = videos.firstIndex(where: { $0.id == video.id }) {
                videos[idx] = video
            } else {
                videos.append(video)
                videos.sort { $0.createdAt > $1.createdAt }
            }
        }
    }

    // MARK: Upload flow

    /// Copy the picked movie into a temp file, compress it, grab a poster
    /// frame — then hand off to the caption sheet.
    private func prepareVideo(_ item: PhotosPickerItem) async {
        processingPhase = L10n.t("memories.videos.reading")
        defer { processingPhase = nil }
        do {
            guard let picked = try await item.loadTransferable(type: PickedVideo.self) else {
                appState.notify(L10n.t("memories.videos.readFailed"), style: .error)
                return
            }
            processingPhase = L10n.t("memories.videos.compressing")
            let result = try await VideoTranscoder.compress(sourceURL: picked.url)
            defer { try? FileManager.default.removeItem(at: picked.url) }
            guard result.data.count <= 100 * 1024 * 1024 else {
                appState.notify(L10n.t("memories.videos.tooBig"), style: .error)
                try? FileManager.default.removeItem(at: result.fileURL)
                return
            }
            pendingUpload = PendingVideoUpload(mp4: result.data, fileURL: result.fileURL,
                                               poster: result.poster, width: result.width,
                                               height: result.height, duration: result.duration)
        } catch {
            appState.notify(L10n.t("memories.videos.readFailed"), style: .error)
        }
    }

    private func upload(_ pending: PendingVideoUpload, caption: String) {
        guard let api = appState.api else { return }
        processingPhase = L10n.t("memories.videos.uploading")
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                let video = try await api.uploadVideo(mp4: pending.mp4,
                                                      caption: trimmed.isEmpty ? nil : trimmed,
                                                      width: pending.width,
                                                      height: pending.height,
                                                      duration: pending.duration)
                apply(video)
                SoundEngine.shared.play(.sparkle)
                Haptics.shared.success()
                appState.notify(L10n.t("memories.videos.uploaded"), style: .love)
                // Poster thumbnail is best effort — the grid falls back to a
                // film placeholder until (and unless) it lands.
                if let poster = pending.poster,
                   let jpeg = poster.jpegData(compressionQuality: 0.7),
                   let updated = try? await api.uploadVideoThumb(videoId: video.id, jpeg: jpeg) {
                    apply(updated)
                }
            } catch {
                appState.handleAPIError(error)
            }
            try? FileManager.default.removeItem(at: pending.fileURL)
            processingPhase = nil
        }
    }

    // MARK: Realtime

    private func handleServerEvent(_ event: ServerEvent) {
        switch event.type {
        case .videoAdded:
            guard let video = event.decode(VideoResponse.self)?.video else { return }
            let isNew = !videos.contains(where: { $0.id == video.id })
            apply(video)
            if isNew && video.uploaderId != appState.memberId {
                SoundEngine.shared.play(.pop)
            }
        case .videoUpdated:
            guard let video = event.decode(VideoResponse.self)?.video else { return }
            apply(video)
        case .videoDeleted:
            guard let id = event.decode(IdPayload.self)?.id else { return }
            withAnimation(.snappy) { videos.removeAll { $0.id == id } }
        default:
            break
        }
    }
}

// MARK: - Picked video transfer

/// PhotosPicker hands movies over as files — copy into our tmp dir so the
/// data survives past the transfer callback.
private struct PickedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("picked-\(UUID().uuidString).mov")
            try FileManager.default.copyItem(at: received.file, to: dest)
            return PickedVideo(url: dest)
        }
    }
}

// MARK: - Pending upload

private struct PendingVideoUpload: Identifiable {
    let id = UUID()
    let mp4: Data
    let fileURL: URL
    let poster: UIImage?
    let width: Int?
    let height: Int?
    let duration: Double?
}

// MARK: - Grid cell

private struct VideoCell: View {
    let video: Video
    let api: API?
    let memberId: String?

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(thumbnail)
            .clipped()
            .overlay(alignment: .bottomTrailing) { durationBadge }
            .overlay(alignment: .topTrailing) { favoriteBadge }
            .overlay(alignment: .center) {
                Image(systemName: "play.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(9)
                    .background(.ultraThinMaterial, in: Circle())
                    .environment(\.colorScheme, .dark)
                    .accessibilityHidden(true)
            }
    }

    @ViewBuilder
    private var durationBadge: some View {
        if let label = video.durationLabel {
            Text(label)
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.vertical, 2)
                .padding(.horizontal, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .environment(\.colorScheme, .dark)
                .padding(5)
        }
    }

    @ViewBuilder
    private var favoriteBadge: some View {
        if !(video.favorites ?? []).isEmpty {
            Image(systemName: "heart.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(video.isFavorite(of: memberId) ? Color.accentColor : .white)
                .padding(5)
                .background(.ultraThinMaterial, in: Circle())
                .environment(\.colorScheme, .dark)
                .padding(4)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let thumbUrl = video.thumbUrl, api != nil {
            RemotePhoto(api: api, path: thumbUrl)
        } else {
            ZStack {
                Color.tertiaryCardBackground
                Image(systemName: "film")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Caption sheet

private struct VideoCaptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let pending: PendingVideoUpload
    let onUpload: (String) -> Void

    @State private var caption = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    posterPreview
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section {
                    if let duration = pending.duration, duration > 0 {
                        let total = Int(duration.rounded())
                        LabeledContent(L10n.t("memories.videos.title"),
                                       value: String(format: "%d:%02d", total / 60, total % 60))
                    }
                    LabeledContent("MP4", value: ByteCountFormatter.string(fromByteCount: Int64(pending.mp4.count),
                                                                           countStyle: .file))
                }
                Section {
                    TextField(L10n.t("memories.gallery.captionPlaceholder"), text: $caption, axis: .vertical)
                        .lineLimit(1...3)
                }
            }
            .navigationTitle(L10n.t("memories.videos.captionTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("memories.gallery.upload")) {
                        dismiss()
                        onUpload(caption)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var posterPreview: some View {
        if let poster = pending.poster {
            Image(uiImage: poster)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 280)
                .clipShape(RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))
                .overlay {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
        } else {
            RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous)
                .fill(Color.tertiaryCardBackground)
                .frame(height: 200)
                .overlay {
                    Image(systemName: "film")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
        }
    }
}

// MARK: - Fullscreen player

/// Black media stage with dark chrome (like the Photos video player).
private struct VideoPlayerScreen: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @Binding var videos: [Video]
    let startId: String

    @State private var player: AVPlayer?
    @State private var confirmDelete = false
    @State private var editingCaption = false
    @State private var captionDraft = ""
    @State private var busy = false

    private var currentVideo: Video? {
        videos.first { $0.id == startId }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                if let player {
                    VideoPlayer(player: player)
                        .aspectRatio(aspectRatio, contentMode: .fit)
                } else {
                    ProgressView()
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                if let video = currentVideo {
                    captionBar(video)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.close"), systemImage: "xmark") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if busy {
                        ProgressView()
                    } else {
                        Button {
                            toggleFavorite()
                        } label: {
                            Label(L10n.t("memories.gallery.favorite"),
                                  systemImage: currentIsFavorite ? "heart.fill" : "heart")
                        }
                        .tint(currentIsFavorite ? Color.accentColor : nil)
                        Menu {
                            Button {
                                captionDraft = currentVideo?.caption ?? ""
                                editingCaption = true
                            } label: {
                                Label(L10n.t("memories.gallery.editCaption"), systemImage: "pencil")
                            }
                            Button {
                                saveCurrent()
                            } label: {
                                Label(L10n.t("memories.gallery.saveToLibrary"), systemImage: "square.and.arrow.down")
                            }
                            if currentVideo?.uploaderId == appState.memberId {
                                Button(role: .destructive) {
                                    confirmDelete = true
                                } label: {
                                    Label(L10n.t("common.delete"), systemImage: "trash")
                                }
                            }
                        } label: {
                            Label(L10n.t("common.more"), systemImage: "ellipsis.circle")
                        }
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .environment(\.colorScheme, .dark)
        .onAppear { startPlayback() }
        .onDisappear { player?.pause() }
        .confirmationDialog(L10n.t("memories.videos.deleteConfirm"),
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L10n.t("common.delete"), role: .destructive) { deleteCurrent() }
        }
        .alert(L10n.t("memories.gallery.editCaption"), isPresented: $editingCaption) {
            TextField(L10n.t("memories.gallery.captionPlaceholder"), text: $captionDraft)
            Button(L10n.t("common.save")) { saveCaption() }
            Button(L10n.t("common.cancel"), role: .cancel) {}
        }
        .onChange(of: currentVideo == nil) { _, gone in
            if gone { dismiss() }
        }
    }

    private var aspectRatio: CGFloat {
        guard let video = currentVideo,
              let width = video.width, let height = video.height,
              width > 0, height > 0 else { return 16 / 9 }
        return CGFloat(width) / CGFloat(height)
    }

    private func captionBar(_ video: Video) -> some View {
        HStack(alignment: .center, spacing: 12) {
            MemberAvatar(emoji: uploader(of: video)?.avatar, colorHex: uploader(of: video)?.color, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                if let caption = video.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(3)
                }
                Text(uploadInfo(video))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: Brand.cardRadius))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var currentIsFavorite: Bool {
        currentVideo?.isFavorite(of: appState.memberId) ?? false
    }

    private func uploader(of video: Video) -> Member? {
        appState.couple?.members.first { $0.id == video.uploaderId }
    }

    private func uploadInfo(_ video: Video) -> String {
        let name = video.uploaderId == appState.memberId
            ? L10n.t("common.you")
            : (uploader(of: video)?.name ?? appState.partnerName)
        let date = video.createdAt.formatted(date: .abbreviated, time: .shortened)
        var line = L10n.t("memories.gallery.by", ["name": name]) + " · " + date
        if let bytes = video.bytes, bytes > 0 {
            line += " · " + ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
        }
        return line
    }

    // MARK: Actions

    private func startPlayback() {
        guard let video = currentVideo,
              let api = appState.api,
              let request = api.mediaRequest(video.url),
              let url = request.url else { return }
        let headers = request.allHTTPHeaderFields ?? [:]
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let avPlayer = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        player = avPlayer
        avPlayer.play()
    }

    private func toggleFavorite() {
        guard let video = currentVideo, let api = appState.api else { return }
        Haptics.shared.success()
        Task {
            do {
                let updated = try await api.toggleVideoFavorite(id: video.id)
                merge(updated)
            } catch {
                appState.handleAPIError(error)
            }
        }
    }

    private func merge(_ video: Video) {
        guard let idx = videos.firstIndex(where: { $0.id == video.id }) else { return }
        videos[idx] = video
    }

    private func saveCaption() {
        guard let video = currentVideo, let api = appState.api else { return }
        let trimmed = captionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let target: String? = trimmed.isEmpty ? nil : trimmed
        guard (video.caption ?? "") != (target ?? "") else { return }
        busy = true
        Task {
            do {
                let updated = try await api.patchVideo(id: video.id, caption: .some(target))
                merge(updated)
                Haptics.shared.success()
                appState.notify(L10n.t("memories.gallery.captionSaved"), style: .success)
            } catch {
                appState.handleAPIError(error)
            }
            busy = false
        }
    }

    private func deleteCurrent() {
        guard let video = currentVideo, let api = appState.api else { return }
        busy = true
        player?.pause()
        Task {
            do {
                try await api.deleteVideo(id: video.id)
                videos.removeAll { $0.id == video.id }
                appState.notify(L10n.t("memories.videos.deleted"), style: .info)
                dismiss()
            } catch {
                appState.handleAPIError(error)
            }
            busy = false
        }
    }

    /// Download the MP4 to a temp file, then hand it to the photo library.
    private func saveCurrent() {
        guard let video = currentVideo,
              let request = appState.api?.mediaRequest(video.url) else { return }
        busy = true
        Task {
            do {
                let (tempURL, _) = try await URLSession.shared.download(for: request)
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent("save-\(video.id).mp4")
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.moveItem(at: tempURL, to: dest)
                PhotoLibrarySaver.saveVideo(path: dest.path) { ok in
                    try? FileManager.default.removeItem(at: dest)
                    if ok {
                        Haptics.shared.success()
                        appState.notify(L10n.t("memories.videos.savedToLibrary"), style: .success)
                    } else {
                        appState.notify(L10n.t("memories.videos.saveFailed"), style: .error)
                    }
                }
            } catch {
                appState.notify(L10n.t("memories.videos.saveFailed"), style: .error)
            }
            busy = false
        }
    }
}
