import SwiftUI

/// "Wie geht's dir?" — mood emoji, optional note and the now-playing status.
struct MoodSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private static let moods = ["🥰", "😊", "😌", "🥳", "😴", "🤒", "😢", "😤",
                                "🥺", "😩", "💪", "🤗", "🫠", "🤍", "😇", "🤪"]

    @State private var selected = ""
    @State private var note = ""
    @State private var songTitle = ""
    @State private var songArtist = ""
    @State private var savingSong = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    EmojiPickerGrid(emojis: Self.moods, selection: $selected, columns: 8)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                    TextField(L10n.t("home.moodNote"), text: $note, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text(L10n.t("today.mood.title"))
                } footer: {
                    Text(L10n.t("today.mood.footer", ["name": appState.partnerName]))
                }

                Section {
                    TextField(L10n.t("nowplaying.songField"), text: $songTitle)
                    TextField(L10n.t("nowplaying.artistField"), text: $songArtist)
                    Button {
                        setNowPlaying()
                    } label: {
                        HStack {
                            Label(L10n.t("nowplaying.set"), systemImage: "music.note")
                            if savingSong { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(savingSong || songTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    if appState.me?.nowPlaying != nil {
                        Button(L10n.t("nowplaying.clear"), role: .destructive) { clearNowPlaying() }
                            .disabled(savingSong)
                    }
                } header: {
                    Text(L10n.t("nowplaying.title"))
                } footer: {
                    Text(L10n.t("nowplaying.hint"))
                }

                if appState.me?.mood != nil {
                    Section {
                        Button(L10n.t("today.mood.clear"), role: .destructive) {
                            appState.setMood(nil, note: nil)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(L10n.t("home.setMood"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.save")) {
                        let trimmed = note.trimmingCharacters(in: .whitespaces)
                        appState.setMood(selected.isEmpty ? nil : selected, note: trimmed.isEmpty ? nil : trimmed)
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            selected = appState.me?.mood ?? ""
            note = appState.me?.moodNote ?? ""
            songTitle = appState.me?.nowPlaying?.title ?? ""
            songArtist = appState.me?.nowPlaying?.artist ?? ""
        }
    }

    private func setNowPlaying() {
        guard let api = appState.api, !savingSong else { return }
        let title = songTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = songArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        savingSong = true
        Task {
            do {
                _ = try await api.setNowPlaying(title: title, artist: artist.isEmpty ? nil : artist)
                SoundEngine.shared.play(.pop)
                appState.notify(L10n.t("nowplaying.setToast"), style: .success)
            } catch {
                appState.handleAPIError(error)
            }
            savingSong = false
        }
    }

    private func clearNowPlaying() {
        guard let api = appState.api, !savingSong else { return }
        savingSong = true
        Task {
            do {
                try await api.clearNowPlaying()
                songTitle = ""
                songArtist = ""
            } catch {
                appState.handleAPIError(error)
            }
            savingSong = false
        }
    }
}

/// Everything that happened while you were away (v1.6 inbox digest).
struct InboxSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let inbox = appState.missedInbox, !inbox.isEmpty {
                    List {
                        Section {
                            inboxRow("home.missed.messages", systemImage: "bubble.left.fill", tint: .blue,
                                     count: inbox.messageCount, tab: .chat)
                            inboxRow("home.missed.touches", systemImage: "heart.fill", tint: .accentColor,
                                     count: inbox.touchCount, tab: .home)
                            inboxRow("home.missed.photos", systemImage: "photo.fill", tint: .green,
                                     count: inbox.photoCount, tab: .memories)
                            inboxRow("home.missed.coupons", systemImage: "ticket.fill", tint: .orange,
                                     count: inbox.couponCount, tab: .memories)
                            inboxRow("home.missed.songs", systemImage: "music.note", tint: .purple,
                                     count: inbox.songCount, tab: .memories)
                            inboxRow("home.missed.canvas", systemImage: "paintpalette.fill", tint: .teal,
                                     count: inbox.canvasCount, tab: .memories)
                            inboxRow("home.missed.games", systemImage: "gamecontroller.fill", tint: .indigo,
                                     count: inbox.gamesCount, tab: .us)
                            inboxRow("home.missed.daily", systemImage: "text.bubble.fill", tint: .pink,
                                     count: inbox.partnerAnsweredDaily ? 1 : 0, tab: .home)
                        } footer: {
                            Text(L10n.t("home.missedBody"))
                        }
                        if let last = inbox.messages?.last, last.senderId != appState.memberId,
                           let text = last.text, !text.isEmpty {
                            Section(L10n.t("today.partnerSent", ["name": appState.partnerName])) {
                                Text("„\(text)“")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(L10n.t("today.inbox.emptyTitle"),
                                           systemImage: "bell.slash",
                                           description: Text(L10n.t("today.inbox.emptyBody")))
                }
            }
            .navigationTitle(L10n.t("today.inbox"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.done")) {
                        appState.missedInbox = nil
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func inboxRow(_ key: String, systemImage: String, tint: Color, count: Int, tab: AppTab) -> some View {
        if count > 0 {
            Button {
                appState.missedInbox = nil
                appState.activeTab = tab
                dismiss()
            } label: {
                HStack {
                    Label {
                        Text(L10n.t(key))
                            .foregroundStyle(.primary)
                    } icon: {
                        IconTile(systemImage: systemImage, tint: tint)
                    }
                    Spacer()
                    Text("\(count)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    DisclosureChevron()
                }
            }
        }
    }
}
