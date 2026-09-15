import SwiftUI
import Combine
import PhotosUI
import UIKit

/// Grid filter: everything, favorites, or one named album (dynamic —
/// album chips are derived from the photos themselves).
private enum GalleryFilter: Hashable, Identifiable {
    case all, favorites
    case album(String)

    var id: String {
        switch self {
        case .all: return "all"
        case .favorites: return "favorites"
        case .album(let name): return "album:\(name)"
        }
    }

    var title: String {
        switch self {
        case .all: return L10n.t("memories.gallery.filterAll")
        case .favorites: return L10n.t("memories.gallery.filterFavorites")
        case .album(let name): return name
        }
    }

    func matches(_ photo: Photo) -> Bool {
        switch self {
        case .all: return true
        case .favorites: return !(photo.favorites ?? []).isEmpty
        case .album(let name): return photo.album == name
        }
    }
}

/// Shared photo gallery — Photos-app style: edge-to-edge square grid,
/// glass filter chips, "Select" mode with a bottom toolbar, PhotosPicker
/// upload with caption + album, fullscreen pager.
struct GalleryView: View {
    @Environment(AppState.self) private var appState

    @State private var photos: [Photo] = []
    @State private var loading = true
    @State private var pickerItem: PhotosPickerItem?
    @State private var pendingUpload: PendingUpload?
    @State private var uploading = false
    @State private var pagerTarget: Photo?
    @State private var celebrationDate: Date?
    @State private var celebrationTask: Task<Void, Never>?
    @State private var filter: GalleryFilter = .all
    @State private var albumPromptPhoto: Photo?
    @State private var newAlbumName = ""
    /// Album currently being renamed (drives the rename prompt).
    @State private var renameAlbumTarget: String?
    @State private var renameAlbumName = ""
    /// Multi-select mode: pick several photos, then move/favorite them at once.
    @State private var selecting = false
    @State private var selectedIds = Set<String>()
    /// "New album…" prompt for the multi-select move menu.
    @State private var bulkNewAlbumPrompt = false
    /// Grid density (2 = big tiles, 3 = classic) — survives app restarts.
    @AppStorage("sooodreamy.gallery.columns") private var storedColumnCount = 3

    private var columnCount: Int { storedColumnCount == 2 ? 2 : 3 }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: columnCount)
    }

    var body: some View {
        Group {
            if loading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if photos.isEmpty {
                ContentUnavailableView {
                    Label(L10n.t("memories.gallery.empty.title"), systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text(L10n.t("memories.gallery.empty.subtitle"))
                } actions: {
                    PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                        Label(L10n.t("memories.gallery.add"), systemImage: "plus")
                    }
                    .buttonStyle(.glassProminent)
                }
            } else {
                gridArea
            }
        }
        .navigationTitle(L10n.t("memories.gallery.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) {
            if uploading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(L10n.t("memories.gallery.upload"))
                        .font(.subheadline.weight(.medium))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 18)
                .glassEffect(.regular, in: .capsule)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: uploading)
        .animation(.snappy, value: selecting)
        .overlay {
            if let started = celebrationDate {
                FloatingHeartsView(emojis: ["📸", "💜", "✨", "💖"], count: 14, startedAt: started)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .task { await loadPhotos() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            pickerItem = nil
            Task { await preparePhoto(item) }
        }
        .sheet(item: $pendingUpload) { pending in
            CaptionSheet(pending: pending, albumSuggestions: albums) { caption, album in
                upload(pending, caption: caption, album: album)
            }
        }
        .fullScreenCover(item: $pagerTarget) { photo in
            PhotoPagerView(photos: $photos, startId: photo.id, filter: filter)
        }
        .alert(L10n.t("memories.gallery.newAlbumTitle"),
               isPresented: Binding(get: { albumPromptPhoto != nil },
                                    set: { if !$0 { albumPromptPhoto = nil } }),
               presenting: albumPromptPhoto) { photo in
            TextField(L10n.t("memories.gallery.albumName"), text: $newAlbumName)
            Button(L10n.t("common.save")) { move(photo, toAlbum: newAlbumName) }
            Button(L10n.t("common.cancel"), role: .cancel) {}
        }
        .alert(L10n.t("memories.gallery.renameAlbumTitle"),
               isPresented: Binding(get: { renameAlbumTarget != nil },
                                    set: { if !$0 { renameAlbumTarget = nil } }),
               presenting: renameAlbumTarget) { name in
            TextField(L10n.t("memories.gallery.albumName"), text: $renameAlbumName)
            Button(L10n.t("common.save")) { renameAlbum(name, to: renameAlbumName) }
            Button(L10n.t("common.cancel"), role: .cancel) {}
        }
        .alert(L10n.t("memories.gallery.newAlbumTitle"), isPresented: $bulkNewAlbumPrompt) {
            TextField(L10n.t("memories.gallery.albumName"), text: $newAlbumName)
            Button(L10n.t("common.save")) { moveSelected(toAlbum: newAlbumName) }
            Button(L10n.t("common.cancel"), role: .cancel) {}
        }
        .onChange(of: photos) { _, _ in
            // The chip for an album disappears with its last photo — fall back.
            if case .album(let name) = filter, !albums.contains(name) {
                filter = .all
            }
            // Photos deleted elsewhere (partner, other device) leave the selection.
            selectedIds.formIntersection(photos.map(\.id))
        }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent else { return }
            handleServerEvent(event)
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if selecting {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L10n.t("common.done")) { finishSelection() }
                    .fontWeight(.semibold)
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Text(selectedIds.isEmpty
                     ? L10n.t("memories.gallery.selectHint")
                     : L10n.t("memories.gallery.selectedCount", ["n": String(selectedIds.count)]))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                bulkAlbumMenu
                Button {
                    favoriteSelected()
                } label: {
                    Label(L10n.t("memories.gallery.favoriteSelected"), systemImage: "heart")
                }
                .disabled(selectedIds.isEmpty)
            }
        } else {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !photos.isEmpty {
                    Button(L10n.t("memories.gallery.select")) {
                        selecting = true
                    }
                }
                Menu {
                    Picker(L10n.t("memories.gallery.density"), selection: $storedColumnCount) {
                        Label(L10n.t("memories.gallery.density"), systemImage: "square.grid.2x2").tag(2)
                        Label(L10n.t("memories.gallery.density"), systemImage: "square.grid.3x3").tag(3)
                    }
                } label: {
                    Label(L10n.t("common.more"), systemImage: "ellipsis.circle")
                }
                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    Label(L10n.t("memories.gallery.add"), systemImage: "plus")
                }
                .disabled(uploading)
            }
        }
    }

    // MARK: Grid

    /// Photos matching the active filter (favorites = liked by either member).
    private var displayedPhotos: [Photo] {
        photos.filter { filter.matches($0) }
    }

    /// Distinct album names across all photos, alphabetical.
    private var albums: [String] {
        var seen = Set<String>()
        var names: [String] = []
        for photo in photos {
            guard let album = photo.album, !album.isEmpty, seen.insert(album).inserted else { continue }
            names.append(album)
        }
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var allFilters: [GalleryFilter] {
        [.all, .favorites] + albums.map { GalleryFilter.album($0) }
    }

    private var gridArea: some View {
        ScrollView {
            LazyVStack(spacing: 12, pinnedViews: []) {
                filterChips
                if filter == .favorites && displayedPhotos.isEmpty {
                    ContentUnavailableView {
                        Label(L10n.t("memories.gallery.favEmpty.title"), systemImage: "heart")
                    } description: {
                        Text(L10n.t("memories.gallery.favEmpty.subtitle"))
                    }
                    .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(displayedPhotos) { photo in
                            Button {
                                if selecting {
                                    toggleSelection(photo)
                                } else {
                                    pagerTarget = photo
                                }
                            } label: {
                                GalleryCell(photo: photo, api: appState.api, memberId: appState.memberId,
                                            selected: selecting ? selectedIds.contains(photo.id) : nil)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(photo.caption ?? L10n.t("memories.gallery.title"))
                            .contextMenu {
                                if !selecting {
                                    sendToChatButton(photo)
                                    albumMenu(photo)
                                }
                            }
                        }
                    }
                    .sensoryFeedback(.selection, trigger: selectedIds)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .refreshable { await loadPhotos() }
    }

    private var filterChips: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(allFilters) { candidate in
                        GlassChip(title: chipTitle(candidate), selected: filter == candidate) {
                            withAnimation(.snappy) { filter = candidate }
                        }
                        .contextMenu {
                            if case .album(let name) = candidate {
                                Button {
                                    renameAlbumName = name
                                    renameAlbumTarget = name
                                } label: {
                                    Label(L10n.t("memories.gallery.renameAlbum"), systemImage: "pencil")
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, Brand.screenInset, for: .scrollContent)
        .sensoryFeedback(.selection, trigger: filter)
    }

    /// Album chips carry their photo count, e.g. "Urlaub · 12".
    private func chipTitle(_ candidate: GalleryFilter) -> String {
        guard case .album = candidate else { return candidate.title }
        let count = photos.filter { candidate.matches($0) }.count
        return "\(candidate.title) · \(count)"
    }

    /// "Send to chat" context-menu row: posts a photo message that references
    /// this gallery photo (the photo itself is not re-uploaded).
    private func sendToChatButton(_ photo: Photo) -> some View {
        Button {
            sendToChat(photo)
        } label: {
            Label(L10n.t("gallery.sendToChat"), systemImage: "paperplane")
        }
    }

    private func sendToChat(_ photo: Photo) {
        guard let api = appState.api else { return }
        Task {
            do {
                _ = try await api.sendPhotoMessage(photoId: photo.id)
                Haptics.shared.success()
                SoundEngine.shared.play(.pop)
                appState.notify(L10n.t("gallery.sentToChat"), style: .love)
            } catch {
                appState.handleAPIError(error)
            }
        }
    }

    /// "Move to album…" context menu: pick an existing album, create a new
    /// one, or take the photo out of its album.
    @ViewBuilder
    private func albumMenu(_ photo: Photo) -> some View {
        Menu {
            ForEach(albums, id: \.self) { name in
                Button {
                    move(photo, toAlbum: name)
                } label: {
                    if photo.album == name {
                        Label(name, systemImage: "checkmark")
                    } else {
                        Text(name)
                    }
                }
            }
            if !albums.isEmpty { Divider() }
            Button {
                newAlbumName = ""
                albumPromptPhoto = photo
            } label: {
                Label(L10n.t("memories.gallery.newAlbum"), systemImage: "plus")
            }
        } label: {
            Label(L10n.t("memories.gallery.moveToAlbum"), systemImage: "folder")
        }
        if photo.album != nil {
            Button(role: .destructive) {
                move(photo, toAlbum: nil)
            } label: {
                Label(L10n.t("memories.gallery.removeFromAlbum"), systemImage: "folder.badge.minus")
            }
        }
    }

    // MARK: Multi-select

    private func toggleSelection(_ photo: Photo) {
        if selectedIds.remove(photo.id) == nil {
            selectedIds.insert(photo.id)
        }
    }

    private func finishSelection() {
        selecting = false
        selectedIds.removeAll()
    }

    /// Bulk "Move to album…" menu: existing albums, a new one, or none.
    private var bulkAlbumMenu: some View {
        Menu {
            ForEach(albums, id: \.self) { name in
                Button {
                    moveSelected(toAlbum: name)
                } label: {
                    Text(name)
                }
            }
            if !albums.isEmpty { Divider() }
            Button {
                newAlbumName = ""
                bulkNewAlbumPrompt = true
            } label: {
                Label(L10n.t("memories.gallery.newAlbum"), systemImage: "plus")
            }
            Button(role: .destructive) {
                moveSelected(toAlbum: nil)
            } label: {
                Label(L10n.t("memories.gallery.removeFromAlbum"), systemImage: "folder.badge.minus")
            }
        } label: {
            Label(L10n.t("memories.gallery.moveToAlbum"), systemImage: "folder")
        }
        .disabled(selectedIds.isEmpty)
    }

    /// Move every selected photo into `album` (nil / empty = out of its album),
    /// one PATCH per photo. Photos already there are skipped.
    private func moveSelected(toAlbum album: String?) {
        guard let api = appState.api, !selectedIds.isEmpty else { return }
        let trimmed = album?.trimmingCharacters(in: .whitespacesAndNewlines)
        let target: String? = (trimmed?.isEmpty ?? true) ? nil : trimmed
        let targets = photos.filter { selectedIds.contains($0.id) && $0.album != target }
        let count = selectedIds.count
        finishSelection()
        Task {
            do {
                for photo in targets {
                    let updated = try await api.patchPhoto(id: photo.id, album: .some(target))
                    apply(updated)
                }
                Haptics.shared.success()
                if let name = target {
                    appState.notify(count == 1
                                       ? L10n.t("memories.gallery.moved", ["name": name])
                                       : L10n.t("memories.gallery.movedCount", ["n": String(count), "name": name]),
                                       style: .success)
                } else {
                    appState.notify(L10n.t("memories.gallery.removedFromAlbum"), style: .info)
                }
            } catch {
                appState.handleAPIError(error)
            }
        }
    }

    /// Mark every selected photo as one of MY favorites. The server endpoint
    /// is a toggle, so photos I already favorited are skipped (never unhearted).
    private func favoriteSelected() {
        guard let api = appState.api, let myId = appState.memberId, !selectedIds.isEmpty else { return }
        let targets = photos.filter { selectedIds.contains($0.id) && !$0.isFavorite(of: myId) }
        let count = selectedIds.count
        finishSelection()
        Task {
            do {
                for photo in targets {
                    let updated = try await api.togglePhotoFavorite(id: photo.id)
                    apply(updated)
                }
                Haptics.shared.success()
                appState.notify(count == 1
                                   ? L10n.t("memories.gallery.favoritedOne")
                                   : L10n.t("memories.gallery.favoritedCount", ["n": String(count)]),
                                   style: .love)
            } catch {
                appState.handleAPIError(error)
            }
        }
    }

    /// Rename a whole album: PATCH every photo filed in it to the new name
    /// (renaming onto an existing album merges the two). The active filter
    /// follows the rename so the grid keeps showing the same photos.
    private func renameAlbum(_ oldName: String, to rawNewName: String) {
        guard let api = appState.api else { return }
        let newName = rawNewName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != oldName else { return }
        let targets = photos.filter { $0.album == oldName }
        guard !targets.isEmpty else { return }
        if filter == .album(oldName) {
            filter = .album(newName)
        }
        Task {
            do {
                for photo in targets {
                    let updated = try await api.patchPhoto(id: photo.id, album: .some(newName))
                    apply(updated)
                }
                Haptics.shared.success()
                appState.notify(L10n.t("memories.gallery.renamed", ["name": newName]), style: .success)
            } catch {
                appState.handleAPIError(error)
            }
        }
    }

    // MARK: Data

    private func loadPhotos() async {
        guard let api = appState.api else { return }
        do {
            let list = try await api.photos()
            photos = list.sorted { $0.createdAt > $1.createdAt }
        } catch {
            appState.handleAPIError(error)
        }
        loading = false
    }

    private func insert(_ photo: Photo) {
        guard !photos.contains(where: { $0.id == photo.id }) else { return }
        withAnimation(.snappy) {
            photos.append(photo)
            photos.sort { $0.createdAt > $1.createdAt }
        }
    }

    /// Replace an existing photo (id match) or insert it.
    private func apply(_ photo: Photo) {
        if let idx = photos.firstIndex(where: { $0.id == photo.id }) {
            photos[idx] = photo
        } else {
            insert(photo)
        }
    }

    // MARK: Upload flow

    private func preparePhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                appState.notify(L10n.t("memories.gallery.readFailed"), style: .error)
                return
            }
            let scaled = ImageScaler.downscaled(image, maxDimension: 2048)
            guard let jpeg = scaled.jpegData(compressionQuality: 0.85) else {
                appState.notify(L10n.t("memories.gallery.readFailed"), style: .error)
                return
            }
            pendingUpload = PendingUpload(jpeg: jpeg, image: scaled)
        } catch {
            appState.notify(L10n.t("memories.gallery.readFailed"), style: .error)
        }
    }

    private func upload(_ pending: PendingUpload, caption: String, album: String) {
        guard let api = appState.api else { return }
        uploading = true
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAlbum = album.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                let photo = try await api.uploadPhoto(jpeg: pending.jpeg,
                                                      caption: trimmed.isEmpty ? nil : trimmed,
                                                      width: Int(pending.image.size.width),
                                                      height: Int(pending.image.size.height))
                insert(photo)
                SoundEngine.shared.play(.sparkle)
                Haptics.shared.success()
                appState.notify(L10n.t("memories.gallery.uploaded"), style: .love)
                celebrate()
                // Album is a follow-up PATCH (upload itself is a raw JPEG POST).
                // Best effort — the photo is already safely uploaded.
                if !trimmedAlbum.isEmpty,
                   let filed = try? await api.patchPhoto(id: photo.id, album: .some(trimmedAlbum)) {
                    apply(filed)
                }
                await uploadThumbnail(for: photo, from: pending.image, api: api)
            } catch {
                appState.handleAPIError(error)
            }
            uploading = false
        }
    }

    /// PATCH the album (nil / empty = remove from its album, via explicit null).
    private func move(_ photo: Photo, toAlbum album: String?) {
        guard let api = appState.api else { return }
        let trimmed = album?.trimmingCharacters(in: .whitespacesAndNewlines)
        let target: String? = (trimmed?.isEmpty ?? true) ? nil : trimmed
        guard photo.album != target else { return }
        Task {
            do {
                let updated = try await api.patchPhoto(id: photo.id, album: .some(target))
                apply(updated)
                Haptics.shared.success()
                if let name = updated.album, !name.isEmpty {
                    appState.notify(L10n.t("memories.gallery.moved", ["name": name]), style: .success)
                } else {
                    appState.notify(L10n.t("memories.gallery.removedFromAlbum"), style: .info)
                }
            } catch {
                appState.handleAPIError(error)
            }
        }
    }

    /// Best-effort grid thumbnail — the grid falls back to the full url if it fails.
    private func uploadThumbnail(for photo: Photo, from image: UIImage, api: API) async {
        let thumb = ImageScaler.downscaled(image, maxDimension: 320)
        guard let jpeg = thumb.jpegData(compressionQuality: 0.7) else { return }
        if let updated = try? await api.uploadPhotoThumb(photoId: photo.id, jpeg: jpeg) {
            apply(updated)
        }
    }

    private func celebrate() {
        celebrationDate = Date()
        celebrationTask?.cancel()
        celebrationTask = Task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            if !Task.isCancelled { celebrationDate = nil }
        }
    }

    // MARK: Realtime

    private func handleServerEvent(_ event: ServerEvent) {
        switch event.type {
        case .photoAdded:
            guard let photo = event.decode(PhotoResponse.self)?.photo else { return }
            let isNew = !photos.contains(where: { $0.id == photo.id })
            insert(photo)
            if isNew && photo.uploaderId != appState.memberId {
                SoundEngine.shared.play(.pop)
            }
        case .photoUpdated:
            guard let photo = event.decode(PhotoResponse.self)?.photo else { return }
            apply(photo)
        case .photoDeleted:
            guard let id = event.decode(IdPayload.self)?.id else { return }
            withAnimation(.snappy) { photos.removeAll { $0.id == id } }
        default:
            break
        }
    }
}

// MARK: - Pending upload

private struct PendingUpload: Identifiable {
    let id = UUID()
    let jpeg: Data
    let image: UIImage
}

// MARK: - Grid cell

private struct GalleryCell: View {
    let photo: Photo
    let api: API?
    let memberId: String?
    /// nil = multi-select off; true/false = this cell's selection state.
    var selected: Bool? = nil

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(RemotePhoto(api: api, path: photo.thumbUrl ?? photo.url))
            .clipped()
            .overlay {
                if selected == true {
                    Color.white.opacity(0.25)
                }
            }
            .overlay(alignment: .topTrailing) { favoriteBadge }
            .overlay(alignment: .bottomTrailing) { selectionBadge }
            .accessibilityAddTraits(selected == true ? .isSelected : [])
    }

    /// Selection circle in multi-select mode (filled when selected) — the
    /// same badge Photos uses.
    @ViewBuilder
    private var selectionBadge: some View {
        if let selected {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, selected ? Color.accentColor : Color.clear)
                .background(.ultraThinMaterial, in: Circle())
                .environment(\.colorScheme, .dark)
                .padding(6)
        }
    }

    /// Accent heart when I favorited, white heart when only the partner did.
    @ViewBuilder
    private var favoriteBadge: some View {
        if !(photo.favorites ?? []).isEmpty {
            Image(systemName: "heart.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(photo.isFavorite(of: memberId) ? Color.accentColor : .white)
                .padding(5)
                .background(.ultraThinMaterial, in: Circle())
                .environment(\.colorScheme, .dark)
                .padding(4)
                .accessibilityLabel(L10n.t("memories.gallery.favorite"))
        }
    }
}

// MARK: - Caption sheet

private struct CaptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let pending: PendingUpload
    let albumSuggestions: [String]
    let onUpload: (String, String) -> Void

    @State private var caption = ""
    @State private var album = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Image(uiImage: pending.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 280)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .accessibilityHidden(true)
                }
                Section {
                    TextField(L10n.t("memories.gallery.captionPlaceholder"), text: $caption, axis: .vertical)
                        .lineLimit(1...3)
                }
                Section {
                    TextField(L10n.t("memories.gallery.albumField"), text: $album)
                        .submitLabel(.done)
                    if !albumSuggestions.isEmpty {
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(albumSuggestions, id: \.self) { name in
                                    GlassChip(title: name, selected: album == name) { album = name }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .scrollIndicators(.hidden)
                    }
                } header: {
                    Text(L10n.t("memories.gallery.moveToAlbum"))
                }
            }
            .navigationTitle(L10n.t("memories.gallery.captionTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("memories.gallery.upload")) {
                        dismiss()
                        onUpload(caption, album)
                    }
                }
            }
        }
    }
}

// MARK: - Fullscreen pager

/// Black media stage with dark chrome, like the Photos app's detail view.
private struct PhotoPagerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @Binding var photos: [Photo]
    let startId: String
    let filter: GalleryFilter

    @State private var currentId = ""
    /// Last known position of `currentId` within the visible slice — used to
    /// clamp to a neighbor when the current photo drops out of the slice.
    @State private var lastVisibleIndex = 0
    @State private var confirmDelete = false
    @State private var editingCaption = false
    @State private var captionDraft = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            TabView(selection: $currentId) {
                ForEach(visiblePhotos) { photo in
                    pageContent(photo)
                        .tag(photo.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(Color.black.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                if let photo = currentPhoto {
                    captionBar(photo)
                }
            }
            .navigationTitle(pagerTitle)
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
                                captionDraft = currentPhoto?.caption ?? ""
                                editingCaption = true
                            } label: {
                                Label(L10n.t("memories.gallery.editCaption"), systemImage: "pencil")
                            }
                            Button {
                                saveCurrent()
                            } label: {
                                Label(L10n.t("memories.gallery.saveToLibrary"), systemImage: "square.and.arrow.down")
                            }
                            if currentPhoto?.uploaderId == appState.memberId {
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
        .onAppear {
            currentId = startId
            lastVisibleIndex = visiblePhotos.firstIndex { $0.id == startId } ?? 0
        }
        .onChange(of: currentId) { _, newId in
            if let idx = visiblePhotos.firstIndex(where: { $0.id == newId }) {
                lastVisibleIndex = idx
            }
        }
        .onChange(of: visibleIds) { _, ids in
            guard !ids.contains(currentId) else { return }
            guard !ids.isEmpty else {
                dismiss()
                return
            }
            currentId = ids[min(lastVisibleIndex, ids.count - 1)]
        }
        .confirmationDialog(L10n.t("memories.gallery.deleteConfirm"),
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L10n.t("common.delete"), role: .destructive) { deleteCurrent() }
        }
        .alert(L10n.t("memories.gallery.editCaption"), isPresented: $editingCaption) {
            TextField(L10n.t("memories.gallery.captionPlaceholder"), text: $captionDraft)
            Button(L10n.t("common.save")) { saveCaption() }
            Button(L10n.t("common.cancel"), role: .cancel) {}
        }
    }

    /// "3 von 12" position indicator as the title.
    private var pagerTitle: String {
        guard visiblePhotos.count > 1,
              let idx = visiblePhotos.firstIndex(where: { $0.id == currentId }) else { return "" }
        return "\(idx + 1) / \(visiblePhotos.count)"
    }

    /// The slice the pager pages over — mirrors the grid filter. Derived from
    /// the master array so mutations (favorites, deletes) flow straight back.
    private var visiblePhotos: [Photo] {
        photos.filter { filter.matches($0) }
    }

    private var visibleIds: [String] {
        visiblePhotos.map(\.id)
    }

    private var currentPhoto: Photo? {
        photos.first { $0.id == currentId }
    }

    private func pageContent(_ photo: Photo) -> some View {
        AuthenticatedAsyncImage(api: appState.api, path: photo.url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .failure:
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            default:
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(photo.caption ?? L10n.t("memories.gallery.title"))
    }

    private func captionBar(_ photo: Photo) -> some View {
        HStack(alignment: .center, spacing: 12) {
            MemberAvatar(emoji: uploader(of: photo)?.avatar, colorHex: uploader(of: photo)?.color, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                if let caption = photo.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(3)
                }
                Text(uploadInfo(photo))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let album = photo.album, !album.isEmpty {
                    Label(album, systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: Brand.cardRadius))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var currentIsFavorite: Bool {
        currentPhoto?.isFavorite(of: appState.memberId) ?? false
    }

    private func uploader(of photo: Photo) -> Member? {
        appState.couple?.members.first { $0.id == photo.uploaderId }
    }

    private func uploadInfo(_ photo: Photo) -> String {
        let name = photo.uploaderId == appState.memberId
            ? L10n.t("common.you")
            : (uploader(of: photo)?.name ?? appState.partnerName)
        let date = photo.createdAt.formatted(date: .abbreviated, time: .shortened)
        return L10n.t("memories.gallery.by", ["name": name]) + " · " + date
    }

    // MARK: Actions

    private func toggleFavorite() {
        guard let photo = currentPhoto, let api = appState.api, let myId = appState.memberId else { return }
        let wasFavorite = photo.isFavorite(of: myId)
        setMyFavorite(!wasFavorite, on: photo.id, myId: myId)
        Haptics.shared.success()
        Task {
            do {
                let updated = try await api.togglePhotoFavorite(id: photo.id)
                merge(updated)
            } catch {
                // Revert by inverting only MY op on the CURRENT array — a partner's
                // concurrent photo_updated (their heart) stays intact.
                setMyFavorite(wasFavorite, on: photo.id, myId: myId)
                appState.handleAPIError(error)
            }
        }
    }

    /// Adds/removes only MY member id in the photo's current favorites array.
    private func setMyFavorite(_ favorite: Bool, on photoId: String, myId: String) {
        guard let idx = photos.firstIndex(where: { $0.id == photoId }) else { return }
        var favorites = photos[idx].favorites ?? []
        if favorite {
            if !favorites.contains(myId) { favorites.append(myId) }
        } else {
            favorites.removeAll { $0 == myId }
        }
        photos[idx].favorites = favorites
    }

    private func merge(_ photo: Photo) {
        guard let idx = photos.firstIndex(where: { $0.id == photo.id }) else { return }
        photos[idx] = photo
    }

    /// PATCH the caption (empty draft = clear it via explicit null).
    private func saveCaption() {
        guard let photo = currentPhoto, let api = appState.api else { return }
        let trimmed = captionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let target: String? = trimmed.isEmpty ? nil : trimmed
        guard (photo.caption ?? "") != (target ?? "") else { return }
        busy = true
        Task {
            do {
                let updated = try await api.patchPhoto(id: photo.id, caption: .some(target))
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
        guard let photo = currentPhoto, let api = appState.api else { return }
        busy = true
        Task {
            do {
                try await api.deletePhoto(id: photo.id)
                photos.removeAll { $0.id == photo.id }
                appState.notify(L10n.t("memories.gallery.deleted"), style: .info)
                if photos.isEmpty { dismiss() }
            } catch {
                appState.handleAPIError(error)
            }
            busy = false
        }
    }

    private func saveCurrent() {
        guard let photo = currentPhoto, let api = appState.api else { return }
        busy = true
        Task {
            do {
                let data = try await api.mediaData(photo.url)
                guard let image = UIImage(data: data) else {
                    throw URLError(.cannotDecodeContentData)
                }
                PhotoLibrarySaver.saveImage(image) { ok in
                    if ok {
                        Haptics.shared.success()
                        appState.notify(L10n.t("memories.gallery.savedToLibrary"), style: .success)
                    } else {
                        appState.notify(L10n.t("memories.gallery.saveFailed"), style: .error)
                    }
                }
            } catch {
                appState.notify(L10n.t("memories.gallery.saveFailed"), style: .error)
            }
            busy = false
        }
    }
}
