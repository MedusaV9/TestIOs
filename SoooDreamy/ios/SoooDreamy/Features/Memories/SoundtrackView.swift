import SwiftUI
import Combine

/// Music provider detected from a song's link — names the listen button.
private enum MusicProvider {
    case spotify, appleMusic, youtube, soundcloud, other

    /// Brand display name; nil = use the generic localized "Listen" label.
    var name: String? {
        switch self {
        case .spotify: return "Spotify"
        case .appleMusic: return "Apple Music"
        case .youtube: return "YouTube"
        case .soundcloud: return "SoundCloud"
        case .other: return nil
        }
    }

    static func detect(from url: URL) -> MusicProvider {
        let host = (url.host ?? "").lowercased()
        func matches(_ domain: String) -> Bool {
            host == domain || host.hasSuffix("." + domain)
        }
        if matches("spotify.com") || matches("spotify.link") { return .spotify }
        if matches("music.apple.com") || matches("itunes.apple.com") { return .appleMusic }
        if matches("youtube.com") || matches("youtu.be") { return .youtube }
        if matches("soundcloud.com") { return .soundcloud }
        return .other
    }
}

/// "Unser Soundtrack" — the couple's shared song list with hearts, listen
/// links and a random pick. Music-app style rows, editor as a Form sheet.
struct SoundtrackView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL

    @State private var songs: [Song] = []
    @State private var loading = true
    @State private var editorTarget: EditorTarget?
    @State private var deleteTarget: Song?
    @State private var highlightedId: String?
    @State private var highlightTask: Task<Void, Never>?

    private struct EditorTarget: Identifiable {
        let id: String
        let song: Song?
    }

    /// Newest first, independent of insertion order.
    private var sortedSongs: [Song] {
        songs.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if loading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .listRowBackground(Color.clear)
                } else if songs.isEmpty {
                    ContentUnavailableView {
                        Label(L10n.t("memories.soundtrack.empty.title"), systemImage: "music.note.list")
                    } description: {
                        Text(L10n.t("memories.soundtrack.empty.subtitle"))
                    } actions: {
                        Button(L10n.t("memories.soundtrack.add")) {
                            editorTarget = EditorTarget(id: "new", song: nil)
                        }
                        .buttonStyle(.glassProminent)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(sortedSongs) { song in
                            row(song)
                                .id(song.id)
                        }
                    } footer: {
                        Text(countText)
                    }
                }
            }
            .navigationTitle(L10n.t("memories.soundtrack.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        shuffle(proxy)
                    } label: {
                        Label(L10n.t("memories.soundtrack.shuffle"), systemImage: "shuffle")
                    }
                    .disabled(songs.isEmpty)
                    Button {
                        editorTarget = EditorTarget(id: "new", song: nil)
                    } label: {
                        Label(L10n.t("memories.soundtrack.add"), systemImage: "plus")
                    }
                }
            }
            .refreshable { await loadSongs() }
        }
        .task { await loadSongs() }
        .sheet(item: $editorTarget) { target in
            SongEditorSheet(song: target.song) { saved in apply(saved) }
        }
        .confirmationDialog(L10n.t("memories.soundtrack.deleteConfirm"),
                            isPresented: Binding(get: { deleteTarget != nil },
                                                 set: { if !$0 { deleteTarget = nil } }),
                            titleVisibility: .visible) {
            Button(L10n.t("common.delete"), role: .destructive) {
                if let song = deleteTarget { delete(song) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent else { return }
            handleServerEvent(event)
        }
        .onDisappear { highlightTask?.cancel() }
    }

    private var countText: String {
        songs.count == 1
            ? L10n.t("memories.soundtrack.countOne")
            : L10n.t("memories.soundtrack.count", ["n": String(songs.count)])
    }

    /// Picks a random song, scrolls to it and highlights its row briefly.
    private func shuffle(_ proxy: ScrollViewProxy) {
        guard let song = sortedSongs.randomElement() else { return }
        Haptics.shared.tap()
        SoundEngine.shared.play(.pop)
        withAnimation(.snappy) {
            proxy.scrollTo(song.id, anchor: .center)
            highlightedId = song.id
        }
        highlightTask?.cancel()
        highlightTask = Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.4)) { highlightedId = nil }
        }
    }

    // MARK: Row

    private func isMine(_ song: Song) -> Bool {
        song.addedBy == appState.memberId
    }

    private func row(_ song: Song) -> some View {
        let mine = isMine(song)
        return HStack(alignment: .center, spacing: 12) {
            IconTile(systemImage: "music.note", tint: .mint, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                if let artist = song.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let note = song.note, !note.isEmpty {
                    Text(note)
                        .font(.footnote.italic())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(addedInfo(song))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            heartButton(song)
            if let url = listenURL(song.link) {
                Button {
                    openURL(url)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(listenLabel(url))
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(highlightedId == song.id ? Color.accentColor.opacity(0.12) : nil)
        .contextMenu {
            Button {
                shareToChat(song)
            } label: {
                Label(L10n.t("memories.soundtrack.share"), systemImage: "paperplane")
            }
            if let url = listenURL(song.link) {
                Button {
                    openURL(url)
                } label: {
                    Label(listenLabel(url), systemImage: "play.circle")
                }
            }
            if mine {
                Button {
                    editorTarget = EditorTarget(id: song.id, song: song)
                } label: {
                    Label(L10n.t("common.edit"), systemImage: "pencil")
                }
                Button(role: .destructive) {
                    deleteTarget = song
                } label: {
                    Label(L10n.t("common.delete"), systemImage: "trash")
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if mine {
                Button(role: .destructive) {
                    deleteTarget = song
                } label: {
                    Label(L10n.t("common.delete"), systemImage: "trash")
                }
                Button {
                    editorTarget = EditorTarget(id: song.id, song: song)
                } label: {
                    Label(L10n.t("common.edit"), systemImage: "pencil")
                }
                .tint(.orange)
            }
            Button {
                shareToChat(song)
            } label: {
                Label(L10n.t("memories.soundtrack.share"), systemImage: "paperplane")
            }
            .tint(.blue)
        }
    }

    private func adder(of song: Song) -> Member? {
        appState.couple?.members.first { $0.id == song.addedBy }
    }

    private func addedInfo(_ song: Song) -> String {
        let name = isMine(song) ? L10n.t("common.you") : (adder(of: song)?.name ?? appState.partnerName)
        let date = song.createdAt.formatted(date: .abbreviated, time: .omitted)
        return L10n.t("memories.soundtrack.by", ["name": name]) + " · " + date
    }

    private func listenLabel(_ url: URL) -> String {
        MusicProvider.detect(from: url).name ?? L10n.t("memories.soundtrack.listen")
    }

    // MARK: Heart

    private func heartButton(_ song: Song) -> some View {
        let mine = song.isHearted(by: appState.memberId)
        let count = song.heartedBy?.count ?? 0
        return Button {
            toggleHeart(song)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: mine ? "heart.fill" : "heart")
                    .contentTransition(.symbolEffect(.replace))
                if count > 0 {
                    Text(String(count))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
            }
            .font(.title3)
            .foregroundStyle(mine || count >= 2 ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(L10n.t("memories.soundtrack.heart"))
        .accessibilityValue(String(count))
    }

    private func toggleHeart(_ song: Song) {
        guard let api = appState.api, let myId = appState.memberId else { return }
        let wasHearted = song.isHearted(by: myId)
        setMyHeart(!wasHearted, on: song.id, myId: myId)
        Haptics.shared.tap()
        Task {
            do {
                let updated = try await api.toggleSongHeart(id: song.id)
                apply(updated)
            } catch {
                // Revert by inverting only MY op on the CURRENT array — a
                // partner's concurrent song_updated heart stays intact.
                setMyHeart(wasHearted, on: song.id, myId: myId)
                appState.handleAPIError(error)
            }
        }
    }

    /// Adds/removes only MY member id in the song's current heartedBy array.
    private func setMyHeart(_ hearted: Bool, on songId: String, myId: String) {
        guard let idx = songs.firstIndex(where: { $0.id == songId }) else { return }
        var hearts = songs[idx].heartedBy ?? []
        if hearted {
            if !hearts.contains(myId) { hearts.append(myId) }
        } else {
            hearts.removeAll { $0 == myId }
        }
        songs[idx].heartedBy = hearts
    }

    // MARK: Share to chat

    /// Posts the song (title, artist, note, link) as a chat message.
    private func shareToChat(_ song: Song) {
        guard let api = appState.api else { return }
        let text = shareText(song)
        Task {
            do {
                _ = try await api.sendMessage(type: .text, text: text)
                Haptics.shared.success()
                SoundEngine.shared.play(.pop)
                appState.notify(L10n.t("memories.soundtrack.shareSent"), style: .success)
            } catch {
                appState.handleAPIError(error)
            }
        }
    }

    private func shareText(_ song: Song) -> String {
        var titleLine = song.title
        if let artist = song.artist, !artist.isEmpty { titleLine += " — " + artist }
        var lines = [L10n.t("memories.soundtrack.shareHeader"), titleLine]
        if let note = song.note, !note.isEmpty { lines.append("„" + note + "“") }
        if let url = listenURL(song.link) { lines.append(url.absoluteString) }
        return lines.joined(separator: "\n")
    }

    /// Builds a tappable URL — prepends https:// when the link has no scheme.
    private func listenURL(_ link: String?) -> URL? {
        guard let link else { return nil }
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://" + trimmed
        return URL(string: candidate)
    }

    // MARK: Data

    private func loadSongs() async {
        guard let api = appState.api else { return }
        do {
            songs = try await api.songs()
        } catch {
            appState.handleAPIError(error)
        }
        loading = false
    }

    private func delete(_ song: Song) {
        guard let api = appState.api else { return }
        withAnimation(.snappy) { songs.removeAll { $0.id == song.id } }
        Task {
            do {
                try await api.deleteSong(id: song.id)
                appState.notify(L10n.t("memories.soundtrack.deleted"), style: .info)
            } catch {
                insert(song)
                appState.handleAPIError(error)
            }
        }
    }

    private func insert(_ song: Song) {
        guard !songs.contains(where: { $0.id == song.id }) else { return }
        withAnimation(.snappy) { songs.append(song) }
    }

    private func apply(_ song: Song) {
        if let idx = songs.firstIndex(where: { $0.id == song.id }) {
            songs[idx] = song
        } else {
            insert(song)
        }
    }

    private func handleServerEvent(_ event: ServerEvent) {
        switch event.type {
        case .songAdded:
            if let song = event.decode(SongResponse.self)?.song { insert(song) }
        case .songUpdated:
            if let song = event.decode(SongResponse.self)?.song { apply(song) }
        case .songDeleted:
            if let id = event.decode(IdPayload.self)?.id {
                withAnimation(.snappy) { songs.removeAll { $0.id == id } }
            }
        default:
            break
        }
    }
}

// MARK: - Add / edit sheet

private struct SongEditorSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// nil = add a new song, non-nil = edit my existing song.
    let song: Song?
    let onSaved: (Song) -> Void

    @State private var title: String
    @State private var artist: String
    @State private var note: String
    @State private var link: String
    @State private var saving = false

    init(song: Song?, onSaved: @escaping (Song) -> Void) {
        self.song = song
        self.onSaved = onSaved
        _title = State(initialValue: song?.title ?? "")
        _artist = State(initialValue: song?.artist ?? "")
        _note = State(initialValue: song?.note ?? "")
        _link = State(initialValue: song?.link ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.t("memories.soundtrack.titleField"), text: $title)
                        .submitLabel(.next)
                    TextField(L10n.t("memories.soundtrack.artistField"), text: $artist)
                        .submitLabel(.next)
                }
                Section {
                    TextField(L10n.t("memories.soundtrack.noteField"), text: $note, axis: .vertical)
                        .lineLimit(1...3)
                    TextField(L10n.t("memories.soundtrack.linkField"), text: $link)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                }
            }
            .navigationTitle(L10n.t(song == nil ? "memories.soundtrack.addTitle" : "memories.soundtrack.editTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if saving { ProgressView() } else { Text(L10n.t("common.save")) }
                    }
                    .disabled(saving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        guard let api = appState.api, !saving else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
        saving = true
        Task {
            do {
                if let song {
                    try await update(song, api: api, title: trimmedTitle,
                                     artist: trimmedArtist, note: trimmedNote, link: trimmedLink)
                } else {
                    let created = try await api.addSong(title: trimmedTitle,
                                                        artist: trimmedArtist.isEmpty ? nil : trimmedArtist,
                                                        note: trimmedNote.isEmpty ? nil : trimmedNote,
                                                        link: trimmedLink.isEmpty ? nil : trimmedLink)
                    onSaved(created)
                    SoundEngine.shared.play(.pop)
                    Haptics.shared.success()
                    appState.notify(L10n.t("memories.soundtrack.added"), style: .love)
                    dismiss()
                }
            } catch {
                appState.handleAPIError(error)
            }
            saving = false
        }
    }

    /// PATCHes only changed fields. Emptying an optional field CLEARS it on
    /// the server via an explicit JSON null (double-optional `.some(nil)`,
    /// serialized by `API.encodeNulls`); unchanged fields are omitted and
    /// keep their server value.
    private func update(_ song: Song, api: API, title: String,
                        artist: String, note: String, link: String) async throws {
        let newTitle: String? = title != song.title ? title : nil

        /// `.none` = unchanged (omit), `.some(nil)` = cleared, `.some(v)` = replaced.
        func delta(_ current: String?, _ edited: String) -> String?? {
            let normalizedCurrent = (current?.isEmpty ?? true) ? nil : current
            let normalizedEdited = edited.isEmpty ? nil : edited
            return normalizedCurrent == normalizedEdited ? String??.none : .some(normalizedEdited)
        }

        let newArtist = delta(song.artist, artist)
        let newNote = delta(song.note, note)
        let newLink = delta(song.link, link)
        if newTitle == nil && newArtist == nil && newNote == nil && newLink == nil {
            dismiss()
            return
        }
        let updated = try await api.updateSong(id: song.id, title: newTitle, artist: newArtist,
                                               note: newNote, link: newLink)
        onSaved(updated)
        Haptics.shared.success()
        appState.notify(L10n.t("memories.soundtrack.updated"), style: .success)
        dismiss()
    }
}
