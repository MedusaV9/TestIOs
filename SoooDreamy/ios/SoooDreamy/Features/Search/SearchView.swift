import SwiftUI

/// The iOS 26 search tab: one field for everything the couple has collected —
/// moments, journal answers, photos & videos, songs, lists, bucket list,
/// coupons and chat. Uses the existing read endpoints, filters on device
/// (case- and diacritic-insensitive, every word must match) and lands each
/// hit in its real destination. Recent searches come back as suggestions.
struct SearchView: View {
    @Environment(AppState.self) private var appState

    @State private var query = ""
    @State private var scope: SearchScope = .all
    @State private var corpus = SearchCorpus()
    @State private var loading = false
    @State private var loadedForCouple: String?
    @AppStorage("sooodreamy.search.recent") private var recentRaw = ""

    private var recent: [String] { recentRaw.split(separator: "\n").map(String.init).filter { !$0.isEmpty } }
    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            List {
                if trimmedQuery.isEmpty {
                    idleContent
                } else {
                    resultSections
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if !trimmedQuery.isEmpty && hits.isEmpty && !loading {
                    ContentUnavailableView.search(text: trimmedQuery)
                }
            }
            .navigationTitle(L10n.t("search.title"))
            .searchable(text: $query, prompt: L10n.t("search.prompt"))
            .searchScopes($scope) {
                ForEach(SearchScope.allCases) { scope in
                    Text(L10n.t(scope.titleKey)).tag(scope)
                }
            }
            .searchSuggestions {
                if trimmedQuery.isEmpty {
                    ForEach(recent, id: \.self) { term in
                        Label(term, systemImage: "clock.arrow.circlepath")
                            .searchCompletion(term)
                    }
                }
            }
            .onSubmit(of: .search) { remember(trimmedQuery) }
            .navigationDestination(for: MemoriesRoute.self) { route in
                MemoriesView.destination(for: route)
            }
            .task(id: appState.couple?.id) { await loadCorpus() }
            .refreshable { await loadCorpus(force: true) }
        }
    }

    // MARK: Idle state

    @ViewBuilder
    private var idleContent: some View {
        Section {
            ForEach(SearchKind.allCases) { kind in
                Label {
                    Text(L10n.t(kind.titleKey))
                } icon: {
                    Image(systemName: kind.symbol)
                        .foregroundStyle(kind.tint)
                }
            }
        } header: {
            Text(L10n.t("search.idle.header"))
        } footer: {
            Text(loading ? L10n.t("search.idle.loading") : L10n.t("search.idle.footer", ["n": String(corpus.count)]))
        }
        if !recent.isEmpty {
            Section {
                ForEach(recent, id: \.self) { term in
                    Button {
                        query = term
                    } label: {
                        Label(term, systemImage: "clock.arrow.circlepath")
                    }
                    .foregroundStyle(.primary)
                }
                .onDelete { offsets in
                    var list = recent
                    list.remove(atOffsets: offsets)
                    recentRaw = list.joined(separator: "\n")
                }
            } header: {
                Text(L10n.t("search.recent"))
            }
        }
    }

    // MARK: Results

    private var hits: [SearchHit] {
        corpus.hits(matching: trimmedQuery, scope: scope)
    }

    @ViewBuilder
    private var resultSections: some View {
        let grouped = Dictionary(grouping: hits, by: \.kind)
        ForEach(SearchKind.allCases.filter { grouped[$0] != nil }) { kind in
            Section {
                ForEach((grouped[kind] ?? []).prefix(20)) { hit in
                    row(hit)
                }
            } header: {
                Text(L10n.t(kind.titleKey))
            }
        }
    }

    @ViewBuilder
    private func row(_ hit: SearchHit) -> some View {
        switch hit.target {
        case .memories(let route):
            NavigationLink(value: route) {
                hitLabel(hit)
            }
        case .chat(let messageId):
            Button {
                remember(trimmedQuery)
                appState.chatJumpTarget = messageId
                appState.activeTab = .chat
            } label: {
                hitLabel(hit)
            }
            .foregroundStyle(.primary)
        }
    }

    private func hitLabel(_ hit: SearchHit) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(hit.title)
                    .lineLimit(2)
                if let subtitle = hit.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let date = hit.date {
                    Text(date, format: .dateTime.day().month().year())
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } icon: {
            Image(systemName: hit.kind.symbol)
                .foregroundStyle(hit.kind.tint)
        }
    }

    // MARK: Data

    private func loadCorpus(force: Bool = false) async {
        guard let api = appState.api, let couple = appState.couple else { return }
        if !force, loadedForCouple == couple.id, !corpus.isEmpty { return }
        loading = true
        defer { loading = false }
        let lang = L10n.lang
        async let daily = try? api.dailyHistory(limit: 365)
        async let photos = try? api.photos()
        async let videos = try? api.videos()
        async let songs = try? api.songs()
        async let lists = try? api.sharedLists()
        async let bucket = try? api.bucket()
        async let coupons = try? api.coupons()
        async let messages = try? api.messages(limit: 200)
        let members = Dictionary(uniqueKeysWithValues: couple.members.map { ($0.id, $0.name) })
        var built = SearchCorpus()
        built.add(events: appState.events)
        built.add(daily: await daily ?? [], couple: couple, lang: lang)
        built.add(photos: await photos ?? [])
        built.add(videos: await videos ?? [])
        built.add(songs: await songs ?? [])
        built.add(lists: await lists ?? [])
        built.add(bucket: await bucket ?? [])
        built.add(coupons: await coupons ?? [], members: members)
        built.add(messages: await messages ?? [], members: members)
        corpus = built
        loadedForCouple = couple.id
    }

    private func remember(_ term: String) {
        guard !term.isEmpty else { return }
        var list = recent.filter { $0.localizedCaseInsensitiveCompare(term) != .orderedSame }
        list.insert(term, at: 0)
        recentRaw = list.prefix(8).joined(separator: "\n")
    }
}

// MARK: - Presentation

extension SearchKind {
    var tint: Color {
        switch self {
        case .moments: return .red
        case .journal: return .orange
        case .photos: return .pink
        case .videos: return .indigo
        case .songs: return .mint
        case .lists: return .blue
        case .bucket: return .purple
        case .coupons: return .yellow
        case .chat: return .green
        }
    }
}

// MARK: - Model adapters (need the API models, hence app-side)

extension SearchCorpus {
    mutating func add(events: [EventItem]) {
        for event in events {
            append(SearchHit(id: "event.\(event.id)", kind: .moments,
                             title: "\(event.emoji) \(event.title)", subtitle: event.date,
                             date: SharedDates.parse(event.date), target: .memories(.events),
                             haystack: event.title))
        }
    }

    mutating func add(daily: [DailyEntry], couple: Couple, lang: String) {
        for entry in daily where entry.myAnswer != nil || entry.partnerAnswer != nil {
            let question = entry.questionId.flatMap { qid in ContentPack.dailyQuestions.first { $0.id == qid } }
                ?? ContentPack.dailyQuestion(dateKey: entry.dateKey, coupleId: couple.id)
            let answers = [entry.myAnswer, entry.partnerAnswer].compactMap { $0 }.joined(separator: " · ")
            append(SearchHit(id: "daily.\(entry.dateKey)", kind: .journal,
                             title: question.text.resolved(lang), subtitle: answers,
                             date: SharedDates.parse(entry.dateKey), target: .memories(.journal),
                             haystack: question.text.resolved(lang) + " " + answers))
        }
    }

    mutating func add(photos: [Photo]) {
        for photo in photos {
            let caption = photo.caption?.trimmingCharacters(in: .whitespaces) ?? ""
            let album = photo.album ?? ""
            guard !caption.isEmpty || !album.isEmpty else { continue }
            append(SearchHit(id: "photo.\(photo.id)", kind: .photos,
                             title: caption.isEmpty ? album : caption, subtitle: caption.isEmpty ? nil : album,
                             date: photo.createdAt, target: .memories(.gallery),
                             haystack: caption + " " + album))
        }
    }

    mutating func add(videos: [Video]) {
        for video in videos {
            guard let caption = video.caption?.trimmingCharacters(in: .whitespaces), !caption.isEmpty else { continue }
            append(SearchHit(id: "video.\(video.id)", kind: .videos, title: caption, subtitle: nil,
                             date: video.createdAt, target: .memories(.videos), haystack: caption))
        }
    }

    mutating func add(songs: [Song]) {
        for song in songs {
            let subtitle = [song.artist, song.note].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
            append(SearchHit(id: "song.\(song.id)", kind: .songs, title: song.title, subtitle: subtitle,
                             date: song.createdAt, target: .memories(.soundtrack),
                             haystack: song.title + " " + subtitle))
        }
    }

    mutating func add(lists: [SharedList]) {
        for list in lists {
            append(SearchHit(id: "list.\(list.id)", kind: .lists,
                             title: [list.emoji, list.name].compactMap { $0 }.joined(separator: " "),
                             subtitle: nil, date: list.createdAt, target: .memories(.lists),
                             haystack: list.name))
            for item in list.items {
                append(SearchHit(id: "listitem.\(item.id)", kind: .lists, title: item.text,
                                 subtitle: list.name, date: item.createdAt, target: .memories(.lists),
                                 haystack: item.text + " " + list.name))
            }
        }
    }

    mutating func add(bucket: [BucketItem]) {
        for item in bucket {
            append(SearchHit(id: "bucket.\(item.id)", kind: .bucket,
                             title: [item.emoji, item.text].compactMap { $0 }.joined(separator: " "),
                             subtitle: nil, date: item.createdAt, target: .memories(.bucket),
                             haystack: item.text))
        }
    }

    mutating func add(coupons: [Coupon], members: [String: String]) {
        for coupon in coupons {
            let by = members[coupon.createdBy] ?? ""
            append(SearchHit(id: "coupon.\(coupon.id)", kind: .coupons,
                             title: "\(coupon.emoji) \(coupon.title)", subtitle: coupon.note ?? by,
                             date: coupon.createdAt, target: .memories(.coupons),
                             haystack: coupon.title + " " + (coupon.note ?? "")))
        }
    }

    mutating func add(messages: [Message], members: [String: String]) {
        for message in messages {
            let text = [message.title, message.text].compactMap { $0 }.joined(separator: " — ")
            guard !text.isEmpty else { continue }
            append(SearchHit(id: "message.\(message.id)", kind: .chat, title: text,
                             subtitle: members[message.senderId], date: message.createdAt,
                             target: .chat(messageId: message.id), haystack: text))
        }
    }
}
