import SwiftUI
import Combine

/// "Wir" — rituals, games, date night and challenges in one hub.
/// Large title with subtitle, glass filter chips, horizontally scrolling
/// game strips and grouped rows; every destination is a push.
struct UsView: View {
    @Environment(AppState.self) private var appState

    enum Segment: String, CaseIterable, Identifiable {
        case rituals, games, dateNight, challenges
        var id: String { rawValue }
        var titleKey: String { "us.segment.\(rawValue)" }
    }

    @State private var segment: Segment = .rituals
    @State private var coordinator = GamesCoordinator()
    @State private var path: [UsRoute] = []
    @State private var searchQuery = ""
    @State private var wordleDoneToday = false
    @State private var wordleDuelBadge: String?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if isSearching {
                        searchResults
                    } else {
                        FilterChips(items: Segment.allCases, selection: $segment) { L10n.t($0.titleKey) }
                            .padding(.horizontal, -Brand.screenInset)
                        switch segment {
                        case .rituals: ritualsContent
                        case .games: gamesContent
                        case .dateNight: dateNightContent
                        case .challenges: challengesContent
                        }
                    }
                }
                .padding(.horizontal, Brand.screenInset)
                .padding(.bottom, 24)
            }
            .groupedScreenBackground()
            .navigationTitle(L10n.t("tab.us"))
            .navigationSubtitle(L10n.t("us.subtitle"))
            .searchable(text: $searchQuery, prompt: L10n.t("us.searchPrompt"))
            .searchToolbarBehavior(.minimize)
            .navigationDestination(for: UsRoute.self) { route in
                destination(for: route)
            }
        }
        .task {
            coordinator.onError = { [weak appState] error in appState?.handleAPIError(error) }
            refreshWordleDone()
            await coordinator.refresh(api: appState.api)
        }
        .onChange(of: path) { _, newPath in
            if newPath.isEmpty { refreshWordleDone() }
        }
        .onChange(of: appState.couple?.id) { refreshWordleDone() }
        .onChange(of: appState.servers.activeProfileID) {
            coordinator.reset()
            path = []
            Task { await coordinator.refresh(api: appState.api) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent else { return }
            receive(event)
        }
    }

    // MARK: Search

    private var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var searchResults: some View {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        let games = GameCatalog.all.filter { $0.title.localizedCaseInsensitiveContains(query) }
        let rituals = ritualRows.filter { $0.title.localizedCaseInsensitiveContains(query) }
        return VStack(alignment: .leading, spacing: 20) {
            if games.isEmpty && rituals.isEmpty {
                ContentUnavailableView.search(text: query)
            }
            if !rituals.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: L10n.t("us.segment.rituals"))
                    rowList(rituals)
                }
            }
            if !games.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: L10n.t("us.segment.games"))
                    gameGrid(games)
                }
            }
        }
    }

    // MARK: Rituals

    private struct RitualRow: Identifiable {
        let route: UsRoute
        let title: String
        let subtitle: String
        let systemImage: String
        let tint: Color
        var id: UsRoute { route }
    }

    private var ritualRows: [RitualRow] {
        [
            RitualRow(route: .daymemo, title: L10n.t("daymemo.title"), subtitle: L10n.t("daymemo.subtitle"),
                      systemImage: "mic.fill", tint: .purple),
            RitualRow(route: .capsules, title: L10n.t("capsules.title"), subtitle: L10n.t("capsules.subtitle"),
                      systemImage: "hourglass", tint: .indigo),
            RitualRow(route: .goals, title: L10n.t("goals.title"), subtitle: L10n.t("goals.subtitle"),
                      systemImage: "target", tint: .green),
            RitualRow(route: .weekplan, title: L10n.t("weekplan.title"), subtitle: L10n.t("weekplan.subtitle"),
                      systemImage: "calendar", tint: .red),
            RitualRow(route: .needsHistory, title: L10n.t("needs.title"), subtitle: L10n.t("needs.subtitle"),
                      systemImage: "hand.raised.fill", tint: .accentColor),
            RitualRow(route: .magazine, title: L10n.t("magazine.title"), subtitle: L10n.t("magazine.subtitle"),
                      systemImage: "book.pages.fill", tint: .brown),
        ]
    }

    @ViewBuilder
    private var ritualsContent: some View {
        dateNightHero
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("us.rituals.title"), subtitle: L10n.t("us.rituals.subtitle"))
            rowList(ritualRows)
        }
    }

    private func rowList(_ rows: [RitualRow]) -> some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                NavigationLink(value: row.route) {
                    HStack(spacing: 14) {
                        IconTile(systemImage: row.systemImage, tint: row.tint, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                                .font(.body.weight(.medium))
                            Text(row.subtitle)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 0)
                        DisclosureChevron()
                    }
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if row.id != rows.last?.id {
                    Divider().padding(.leading, 64)
                }
            }
        }
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))
    }

    // MARK: Date night

    private var dateNightHero: some View {
        NavigationLink(value: UsRoute.dateNight) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [Color.accentColor, .purple, .indigo],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 110))
                    .foregroundStyle(.white.opacity(0.14))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(16)
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.t("datenight.title"))
                        .font(.title.weight(.bold))
                    Text(appState.dateNight.map { plannedLine($0) } ?? L10n.t("us.datenight.hero.subtitle"))
                        .font(.subheadline)
                        .opacity(0.9)
                    Text(L10n.t("us.datenight.hero.cta"))
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .padding(.top, 4)
                }
                .foregroundStyle(.white)
                .padding(20)
            }
            .frame(height: 210)
            .clipShape(RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.t("datenight.title"))
    }

    private func plannedLine(_ night: DateNight) -> String {
        let title = night.title ?? L10n.t("datenight.card.title")
        return "\(night.emoji ?? "🌙") \(title) · \(night.startsAt.formatted(date: .abbreviated, time: .shortened))"
    }

    @ViewBuilder
    private var dateNightContent: some View {
        if let night = appState.dateNight {
            PlannedNightCard(night: night)
        }
        dateNightHero
        if let couple = appState.couple, let idea = TodayModel.dailyIdea(coupleId: couple.id) {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: L10n.t("today.discover"))
                DiscoverIdeaCard(idea: idea)
            }
        }
    }

    // MARK: Games

    @ViewBuilder
    private var gamesContent: some View {
        let sessions = coordinator.openSessions.filter { $0.kind != nil }
        if !sessions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: L10n.t("us.games.open"))
                VStack(spacing: 10) {
                    ForEach(sessions) { session in
                        sessionRow(session)
                    }
                }
            }
        }
        wordleCard
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("us.games.popular"))
            gameStrip(GameCatalog.popular)
        }
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("us.games.moments"))
            gameStrip(GameCatalog.moments)
        }
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("us.games.all"))
            gameGrid(GameCatalog.all)
        }
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("us.games.more"))
            rowList([
                RitualRow(route: .season, title: L10n.t("games.season.title"), subtitle: L10n.t("games.season.teaser"),
                          systemImage: "trophy.fill", tint: .yellow),
                RitualRow(route: .replay, title: L10n.t("games.replay.title"), subtitle: L10n.t("games.replay.teaser"),
                          systemImage: "film.fill", tint: .indigo),
                RitualRow(route: .record, title: L10n.t("games.card.record.title"), subtitle: L10n.t("games.card.record.teaser"),
                          systemImage: "chart.bar.fill", tint: .blue),
            ])
        }
    }

    private func gameStrip(_ games: [GameInfo]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(games) { info in
                    NavigationLink(value: info.route) {
                        GameTile(info: info)
                            .frame(width: 150)
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .padding(.horizontal, -Brand.screenInset)
        .contentMargins(.horizontal, Brand.screenInset, for: .scrollContent)
    }

    private func gameGrid(_ games: [GameInfo]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(games) { info in
                NavigationLink(value: info.route) {
                    GameTile(info: info)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var wordleCard: some View {
        NavigationLink(value: UsRoute.wordle) {
            HStack(spacing: 14) {
                IconTile(systemImage: "textformat.abc", tint: .green, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(L10n.t("games.wordle.title"))
                            .font(.headline)
                        Text(L10n.t("games.wordle.daily"))
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.16), in: Capsule())
                            .foregroundStyle(Color.green)
                        if let badge = wordleDuelBadge { Text(badge) }
                    }
                    Text(L10n.t(wordleDoneToday ? "games.wordle.done" : "games.wordle.teaser"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                if wordleDoneToday {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.green)
                } else {
                    DisclosureChevron()
                }
            }
            .multilineTextAlignment(.leading)
            .cardSurface(padding: 14)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sessionRow(_ session: GameSession) -> some View {
        if let kind = session.kind, let info = GameCatalog.info(kind) {
            let awaiting = coordinator.awaitingMe(session, myId: appState.memberId)
            let invited = session.state == "lobby" && session.createdBy != appState.memberId
            HStack(spacing: 12) {
                IconTile(systemImage: info.systemImage, tint: info.tint, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(info.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        if awaiting {
                            Text(L10n.t("games.turn.badge"))
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.18), in: Capsule())
                                .foregroundStyle(Color.orange)
                        }
                    }
                    Text(sessionSubtitle(session, invited: invited))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Button(L10n.t(invited ? "games.invite.join" : "games.continue.button")) {
                    if invited {
                        joinAndOpen(session, route: info.route)
                    } else {
                        path.append(info.route)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(invited || awaiting ? Color.accentColor : Color.secondary)
                .disabled(coordinator.engine(for: kind).busy)
            }
            .cardSurface(padding: 14)
        }
    }

    private func sessionSubtitle(_ session: GameSession, invited: Bool) -> String {
        if invited { return L10n.t("games.invite.short", ["name": appState.partnerName]) }
        if session.state == "lobby" {
            return appState.partner?.online == true
                ? L10n.t("games.invite.waitingBody", ["name": appState.partnerName])
                : L10n.t("games.invite.offline", ["name": appState.partnerName])
        }
        return coordinator.awaitingMe(session, myId: appState.memberId)
            ? L10n.t("games.turn.yours")
            : L10n.t("games.turn.partner", ["name": appState.partnerName])
    }

    private func joinAndOpen(_ session: GameSession, route: UsRoute) {
        guard let kind = session.kind else { return }
        let engine = coordinator.engine(for: kind)
        Task {
            if engine.session?.id != session.id { engine.adopt(session) }
            if await engine.join(api: appState.api) {
                SoundEngine.shared.play(.pop)
                path.append(route)
            }
        }
    }

    // MARK: Challenges

    @ViewBuilder
    private var challengesContent: some View {
        QuestCard()
        LevelCard()
        if let info = GameCatalog.info(.dailyquests) {
            NavigationLink(value: UsRoute.dailyquests) {
                HStack(spacing: 14) {
                    IconTile(systemImage: info.systemImage, tint: info.tint, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(info.title).font(.headline)
                        Text(info.teaser).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer()
                    DisclosureChevron()
                }
                .multilineTextAlignment(.leading)
                .cardSurface(padding: 14)
            }
            .buttonStyle(.plain)
        }
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("us.challenges.streaks"))
            HStack(spacing: 12) {
                streakTile(title: L10n.t("home.dailyQuestion"), value: appState.dailyEntry?.streak ?? 0,
                           systemImage: "text.bubble.fill", tint: .accentColor)
                streakTile(title: L10n.t("stats.games"), value: appState.stats?.gamesPlayed ?? 0,
                           systemImage: "gamecontroller.fill", tint: .indigo)
            }
        }
        rowList([
            RitualRow(route: .season, title: L10n.t("games.season.title"), subtitle: L10n.t("games.season.teaser"),
                      systemImage: "trophy.fill", tint: .yellow),
            RitualRow(route: .badges, title: L10n.t("badges.title"), subtitle: L10n.t("badges.shelf.subtitle",
                      ["n": String(appState.badges.filter(\.unlocked).count), "total": String(appState.badges.count)]),
                      systemImage: "medal.fill", tint: .orange),
        ])
    }

    private func streakTile(title: String, value: Int, systemImage: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            IconTile(systemImage: systemImage, tint: tint, size: 32)
            Text("\(value)")
                .font(.title.weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(padding: 14)
        .accessibilityElement(children: .combine)
    }

    // MARK: Destinations

    @ViewBuilder
    private func destination(for route: UsRoute) -> some View {
        switch route {
        case .wordle: WordleView()
        case .quiz: QuizGameView(engine: coordinator.engine(for: .quiz))
        case .thisorthat: ChoiceGamesView(engine: coordinator.engine(for: .thisorthat), kind: .thisorthat)
        case .wouldyourather: ChoiceGamesView(engine: coordinator.engine(for: .wouldyourather), kind: .wouldyourather)
        case .truthordare: TruthOrDareView(engine: coordinator.engine(for: .truthordare))
        case .questions36: Questions36View()
        case .emojiriddle: EmojiRiddleView(engine: coordinator.engine(for: .emojiriddle))
        case .connectfour: ConnectFourView(engine: coordinator.engine(for: .connectfour))
        case .photomemory: PhotoMemoryView(engine: coordinator.engine(for: .photomemory))
        case .quizduel: QuizDuelView(engine: coordinator.engine(for: .quizduel))
        case .battleship: BattleshipView(engine: coordinator.engine(for: .battleship))
        case .pictionary: PictionaryView(engine: coordinator.engine(for: .pictionary))
        case .kniffel: KniffelView(engine: coordinator.engine(for: .kniffel))
        case .movieroulette: MovieRouletteView(engine: coordinator.engine(for: .movieroulette))
        case .stadtlandfluss: StadtLandFlussView(engine: coordinator.engine(for: .stadtlandfluss))
        case .twotruths: TwoTruthsView(engine: coordinator.engine(for: .twotruths))
        case .dailyquests: DailyQuestsView(engine: coordinator.engine(for: .dailyquests))
        case .season: TournamentView()
        case .replay: ReplayHubView()
        case .record: GamesRecordView()
        case .dateNight: DateNightView()
        case .daymemo: DaymemoView()
        case .capsules: CapsulesView()
        case .goals: GoalsView()
        case .weekplan: WeekplanView()
        case .needsHistory: NeedsHistoryView()
        case .magazine: MagazineView()
        case .badges: BadgeShelfPage()
        }
    }

    // MARK: Events

    private func receive(_ event: ServerEvent) {
        if event.type == .wordleResult {
            if let response = event.decode(WordleDayResponse.self) { applyWordleDuel(response) }
            return
        }
        let knownIds = Set(coordinator.openSessions.map(\.id))
        coordinator.handle(event)
        guard event.type == .gameCreated,
              let session = coordinator.openSessions.first,
              !knownIds.contains(session.id),
              session.state == "lobby",
              session.createdBy != appState.memberId else { return }
        SoundEngine.shared.play(.chime)
    }

    private func refreshWordleDone() {
        guard let couple = appState.couple else {
            wordleDoneToday = false
            wordleDuelBadge = nil
            return
        }
        wordleDoneToday = WordleDaily.isFinished(coupleId: couple.id, dateKey: SharedDates.todayKey(), lang: L10n.lang)
        guard wordleDoneToday, let api = appState.api else {
            wordleDuelBadge = nil
            return
        }
        Task {
            if let response = try? await api.wordleDay(dateKey: SharedDates.todayKey(), lang: L10n.lang) {
                applyWordleDuel(response)
            }
        }
    }

    private func applyWordleDuel(_ response: WordleDayResponse) {
        guard response.dateKey == SharedDates.todayKey(), (response.lang ?? L10n.lang) == L10n.lang else { return }
        guard let mine = response.mine, let partner = response.partner else {
            wordleDuelBadge = nil
            return
        }
        let decided = mine.win != partner.win || (mine.win && partner.win && mine.rows != partner.rows)
        wordleDuelBadge = decided ? "🏆" : "💞"
    }
}

/// Square game tile (strips + grid).
struct GameTile: View {
    let info: GameInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            IconTile(systemImage: info.systemImage, tint: info.tint, size: 44)
            Text(info.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.85)
            Text(info.teaser)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Text(L10n.t(info.multiplayer ? "games.badge.multiplayer" : "games.badge.local"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(info.multiplayer ? Color.accentColor : Color.green)
        }
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .cardSurface(padding: 14)
        .accessibilityElement(children: .combine)
    }
}

/// Pushed variant of the trophy shelf (the sheet version lives in LevelCard).
struct BadgeShelfPage: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            ForEach(appState.badges) { badge in
                HStack(spacing: 14) {
                    MedalView(badge: badge, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(badge.secret && !badge.unlocked ? L10n.t("badges.secret") : BadgeCatalog.name(badge.id))
                            .font(.body.weight(.medium))
                        Text(badge.secret && !badge.unlocked ? L10n.t("badges.secretHint") : BadgeCatalog.desc(badge.id))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(L10n.t("badges.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
