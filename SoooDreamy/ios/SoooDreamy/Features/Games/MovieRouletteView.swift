import SwiftUI
import Combine

// Film-Roulette — both partners swipe the same seeded movie deck; a card
// you BOTH like becomes a match. The relay derives the `movie_match` app
// event SERVER-SIDE from the stored likes (v3.0.1) — the completing swipe's
// `match: {cardIndex, title}` annotation only contributes the deck title.
// The match sheet and end screen turn matches into REAL week-plan slots
// via the 1-tap "Filmabend planen" CTA (MovieNightLogic.swift).
// Reducer: Content/MovieRouletteLogic.swift.
struct MovieRouletteView: View {
    @Environment(AppState.self) private var appState

    let engine: GameEngine

    @State private var customTitles: [String] = []
    @State private var customInput = ""
    @State private var dragOffset: CGSize = .zero
    @State private var sending = false
    @State private var didSendEnd = false
    @State private var celebrated = false
    @State private var seenMatches = 0
    @State private var matchBanner: MatchBanner?
    /// Film→Wochenplan (v3.0.1): titles already turned into a week-plan slot
    /// this session (drives the "geplant ✓" state) + in-flight guard.
    @State private var plannedTitles: Set<String> = []
    @State private var planningTitle: String?

    private struct MatchBanner: Identifiable {
        let id = UUID()
        let title: String
    }

    private var info: GameInfo? { GameCatalog.info(.movieroulette) }
    private var accent: Color { info?.tint ?? .accentColor }

    var body: some View {
        ScrollView {
            content
                .padding(Brand.screenInset)
        }
        .scrollDismissesKeyboard(.interactively)
        .groupedScreenBackground()
        .navigationTitle(L10n.t("games.card.movieroulette.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $matchBanner) { banner in
            matchSheet(title: banner.title)
        }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            if let event = note.object as? ServerEvent {
                engine.handle(event)
            }
        }
        .task {
            engine.onError = { [weak appState] error in
                appState?.handleAPIError(error)
            }
            if engine.session == nil {
                await engine.resume(api: appState.api)
            }
            seenMatches = gameState.matches.count
        }
        .onChange(of: engine.session?.id) { _, _ in
            resetLocalState()
            seenMatches = gameState.matches.count
        }
        .onChange(of: gameState.matches.count) { old, new in
            if new > old, let index = gameState.matches.last {
                announceMatch(index: index)
            }
            seenMatches = new
        }
        .onChange(of: finished) { _, isDone in
            if isDone { handleFinish() }
        }
        .onAppear {
            if finished { handleFinish() }
        }
    }

    // MARK: Derived state

    private var session: GameSession? {
        guard let current = engine.session, current.kind == .movieroulette else { return nil }
        return current
    }

    private var starterId: String { session?.createdBy ?? "" }

    private var otherId: String {
        appState.couple?.members.map(\.id).first { $0 != starterId } ?? ""
    }

    private var myId: String { appState.memberId ?? "" }

    private var theirId: String { myId == starterId ? otherId : starterId }

    private var payloadCustom: [String] {
        session?.payload?["custom"]?.arrayValue?.compactMap(\.stringValue) ?? []
    }

    private var deck: [MovieCard] {
        MovieRoulette.deck(seed: engine.seed,
                           size: engine.payloadInt("size", default: MovieRoulette.defaultDeckSize),
                           custom: payloadCustom)
    }

    private var events: [MovieRouletteEvent] {
        engine.orderedMoves.compactMap { move in
            guard move.data["kind"]?.stringValue == "swipe",
                  let index = move.data["index"]?.intValue,
                  let like = move.data["like"]?.boolValue else { return nil }
            return .swipe(member: move.memberId, index: index, like: like)
        }
    }

    private var gameState: MovieRouletteState {
        MovieRoulette.reduce(events: events, deckSize: deck.count)
    }

    private var finished: Bool {
        guard session?.state == "active" || session?.state == "ended" else { return false }
        return gameState.finished(deckSize: deck.count, members: [starterId, otherId])
    }

    // MARK: Content switch

    @ViewBuilder
    private var content: some View {
        if appState.partner == nil {
            GameNeedsPartnerView()
        } else if let session {
            if session.state == "lobby" {
                GameLobbyView(engine: engine, accent: accent)
            } else if finished {
                endScreen
            } else if session.state == "active" {
                swipeScreen
            } else {
                setupScreen
            }
        } else {
            setupScreen
        }
    }

    // MARK: Setup (custom entries live here)

    @ViewBuilder
    private var setupScreen: some View {
        if let info {
            GameStartCard(info: info, rules: L10n.t("games.mr.setup.body"), starting: engine.busy, onStart: startGame) {
                customEntryEditor
            }
        }
    }

    private var customEntryEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TextField(L10n.t("games.mr.custom.placeholder"), text: $customInput)
                    .submitLabel(.done)
                    .onSubmit(addCustomTitle)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.tertiaryCardBackground, in: Capsule())
                Button {
                    addCustomTitle()
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.bold))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .disabled(customInput.trimmingCharacters(in: .whitespaces).isEmpty || customTitles.count >= 5)
                .accessibilityLabel(L10n.t("common.add"))
            }
            if !customTitles.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], spacing: 6) {
                    ForEach(customTitles, id: \.self) { title in
                        HStack(spacing: 4) {
                            Text(title)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            Button {
                                customTitles.removeAll { $0 == title }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(L10n.t("common.delete"))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.tertiaryCardBackground, in: Capsule())
                    }
                }
            }
            Text(L10n.t("games.mr.custom.hint"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func addCustomTitle() {
        let title = customInput.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, customTitles.count < 5, !customTitles.contains(title) else { return }
        customTitles.append(title)
        customInput = ""
        Haptics.shared.tap()
    }

    private func startGame() {
        guard !engine.busy else { return }
        let custom = customTitles
        Task {
            resetLocalState()
            // The seed comes from the server (v3.0.1 fairness contract).
            var payload: [String: JSONValue] = [
                "size": .number(Double(MovieRoulette.defaultDeckSize))
            ]
            if !custom.isEmpty {
                payload["custom"] = .array(custom.map { .string($0) })
            }
            if await engine.create(api: appState.api, type: .movieroulette, payload: .object(payload)) {
                SoundEngine.shared.play(.pop)
                Haptics.shared.tap()
            }
        }
    }

    private func resetLocalState() {
        dragOffset = .zero
        sending = false
        didSendEnd = false
        celebrated = false
        matchBanner = nil
        plannedTitles = []
        planningTitle = nil
    }

    // MARK: Swiping

    private var swipeScreen: some View {
        VStack(spacing: 14) {
            GameHeaderBar(title: L10n.t("games.mr.progress",
                                        ["n": "\(gameState.swipeCount(of: myId))", "total": "\(deck.count)"]),
                          subtitle: L10n.t("games.mr.matches", ["n": "\(gameState.matches.count)"]),
                          progress: Double(gameState.swipeCount(of: myId)) / Double(max(deck.count, 1)),
                          tint: accent)
            Text(L10n.t("games.mr.partnerProgress",
                        ["name": appState.partnerName,
                         "n": "\(gameState.swipeCount(of: theirId))",
                         "total": "\(deck.count)"]))
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let index = gameState.nextIndex(of: myId, deckSize: deck.count) {
                cardStack(topIndex: index)
                swipeButtons(index: index)
            } else {
                doneWaitingCard
            }
        }
    }

    private func cardStack(topIndex: Int) -> some View {
        ZStack {
            // A peek of the next card underneath.
            if topIndex + 1 < deck.count {
                movieCardView(deck[topIndex + 1])
                    .scaleEffect(0.94)
                    .offset(y: 12)
                    .opacity(0.6)
            }
            movieCardView(deck[topIndex])
                .offset(dragOffset)
                .rotationEffect(.degrees(Double(dragOffset.width) / 18))
                .overlay(swipeHintOverlay)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            if value.translation.width > 90 {
                                swipe(index: topIndex, like: true)
                            } else if value.translation.width < -90 {
                                swipe(index: topIndex, like: false)
                            } else {
                                withAnimation(.snappy) { dragOffset = .zero }
                            }
                        }
                )
        }
        .animation(.snappy, value: dragOffset == .zero)
    }

    @ViewBuilder
    private var swipeHintOverlay: some View {
        if dragOffset.width > 40 {
            swipeStamp(systemImage: "heart.fill", tint: .green, angle: -12)
        } else if dragOffset.width < -40 {
            swipeStamp(systemImage: "hand.wave.fill", tint: .secondary, angle: 12)
        }
    }

    private func swipeStamp(systemImage: String, tint: Color, angle: Double) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 44, weight: .bold))
            .foregroundStyle(tint)
            .padding(18)
            .background(.thinMaterial, in: Circle())
            .rotationEffect(.degrees(angle))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func movieCardView(_ card: MovieCard) -> some View {
        GamePromptCard(eyebrow: L10n.t("games.mr.genre.\(card.genre)")) {
            Text(card.emoji)
                .font(.system(size: 84))
                .accessibilityHidden(true)
            Text(card.title(lang: L10n.lang))
                .font(.title2.weight(.bold))
                .minimumScaleFactor(0.7)
        }
        .frame(minHeight: 320)
    }

    private func swipeButtons(index: Int) -> some View {
        HStack(spacing: 40) {
            Button {
                swipe(index: index, like: false)
            } label: {
                Image(systemName: "hand.wave.fill")
                    .font(.title2)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(L10n.t("games.replay.step.nope"))
            Button {
                swipe(index: index, like: true)
            } label: {
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .accessibilityLabel(L10n.t("games.replay.step.like"))
        }
        .controlSize(.large)
        .disabled(sending)
    }

    private var doneWaitingCard: some View {
        GamePromptCard {
            Image(systemName: "film.stack")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(L10n.t("games.mr.doneWaiting", ["name": appState.partnerName]))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView()
        }
    }

    private func swipe(index: Int, like: Bool) {
        guard !sending else { return }
        sending = true
        withAnimation(.snappy) {
            dragOffset = CGSize(width: like ? 500 : -500, height: -40)
        }
        SoundEngine.shared.play(like ? .pop : .click)
        Haptics.shared.tap()
        let completes = like && MovieRoulette.completesMatch(state: gameState, index: index, partner: theirId)
        Task {
            var data: [String: JSONValue] = [
                "kind": .string("swipe"),
                "index": .number(Double(index)),
                "like": .bool(like)
            ]
            if completes, deck.indices.contains(index) {
                // The completing client annotates the match → the relay
                // emits the movie_match app event (weekly-plan hook).
                data["match"] = .object([
                    "cardIndex": .number(Double(index)),
                    "title": .string(deck[index].title(lang: L10n.lang))
                ])
            }
            _ = await engine.sendMove(api: appState.api, data: .object(data))
            dragOffset = .zero
            sending = false
        }
    }

    // MARK: Match announcement

    private func announceMatch(index: Int) {
        guard deck.indices.contains(index) else { return }
        matchBanner = MatchBanner(title: deck[index].title(lang: L10n.lang))
        Delight.celebrate(.medium, theme: .hearts)
    }

    /// The match celebration sheet with a REAL "plan movie night" CTA
    /// (v3.0.1): one tap creates a week-plan slot — "saved" only appears
    /// after the server confirmed it.
    private func matchSheet(title: String) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer(minLength: 0)
                Text("🍿")
                    .font(.system(size: 64))
                    .accessibilityHidden(true)
                Text(L10n.t("games.mr.match.banner"))
                    .font(.title2.weight(.bold))
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
                if plannedTitles.contains(title) {
                    Label(L10n.t("games.mr.plan.done"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                } else {
                    Button {
                        planMovieNight(title: title)
                    } label: {
                        HStack {
                            if planningTitle == title { ProgressView() }
                            Text(L10n.t("games.mr.plan.cta"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(planningTitle != nil)
                }
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("games.mr.plan.later")) { matchBanner = nil }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: Film → Wochenplan (v3.0.1, EVAL-3.0 P0-3)

    /// 1-tap movie night: creates a REAL week-plan slot (kind `movie`) on the
    /// first day both have time (else next Saturday). Success is only shown
    /// AFTER the server confirmed the slot.
    private func planMovieNight(title: String) {
        guard let api = appState.api, planningTitle == nil else { return }
        planningTitle = title
        Haptics.shared.tap()
        Task {
            defer { planningTitle = nil }
            do {
                let overlapDays = (try? await api.weekplan())?.days.filter(\.overlap).map(\.dateKey) ?? []
                let dateKey = MovieNight.slotDateKey(overlapDateKeys: overlapDays)
                _ = try await api.addWeekplanSlot(title: title, emoji: "🍿", kind: "movie",
                                                  dateKey: dateKey, weekday: nil, time: nil)
                plannedTitles.insert(title)
                SoundEngine.shared.play(.sparkle)
                Haptics.shared.success()
                appState.notify(L10n.t("games.mr.plan.toast", ["day": Self.dayLabel(dateKey)]), style: .success)
                matchBanner = nil
            } catch {
                appState.handleAPIError(error)
            }
        }
    }

    /// "Sa, 15.8." — how the plan toast names the chosen day.
    private static func dayLabel(_ dateKey: String) -> String {
        guard let date = SharedDates.parse(dateKey) else { return dateKey }
        let weekday = SharedDates.calendar.component(.weekday, from: date) - 1 // L10n keys: 0=Su…6=Sa
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: L10n.isGerman ? "de_DE" : "en_US")
        formatter.setLocalizedDateFormatFromTemplate("d.M.")
        return L10n.t("weekday.\(weekday)") + ", " + formatter.string(from: date)
    }

    // MARK: Finish

    private func handleFinish() {
        guard session != nil else { return }
        if !celebrated {
            celebrated = true
            if gameState.matches.isEmpty {
                SoundEngine.shared.play(.chime)
            } else {
                Delight.celebrate(.epic, theme: .hearts)
            }
        }
        guard let current = session, current.state == "active", !didSendEnd else { return }
        didSendEnd = true
        Task {
            let titles = gameState.matches.compactMap { index in
                deck.indices.contains(index) ? deck[index].title(lang: L10n.lang) : nil
            }
            await engine.end(api: appState.api, result: .object([
                "matches": .array(titles.map { .string($0) })
            ]))
        }
    }

    private var endScreen: some View {
        VStack(spacing: 14) {
            GameResultCard(title: gameState.matches.isEmpty
                           ? L10n.t("games.mr.end.none")
                           : L10n.t("games.mr.end.some", ["n": "\(gameState.matches.count)"]),
                           subtitle: gameState.matches.isEmpty ? nil : L10n.t("games.mr.end.planHint"),
                           emoji: gameState.matches.isEmpty ? "🤷" : "🍿") {
                Button {
                    startGame()
                } label: {
                    Text(L10n.t("games.rematch"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(engine.busy)
            }
            if !gameState.matches.isEmpty {
                matchList
            }
        }
    }

    private var matchList: some View {
        VStack(spacing: 0) {
            ForEach(Array(gameState.matches.enumerated()), id: \.element) { position, index in
                if deck.indices.contains(index) {
                    let title = deck[index].title(lang: L10n.lang)
                    HStack(spacing: 12) {
                        Text(deck[index].emoji)
                            .font(.title2)
                            .frame(width: 32)
                            .accessibilityHidden(true)
                        Text(title)
                            .font(.body.weight(.medium))
                            .lineLimit(2)
                        Spacer(minLength: 0)
                        if plannedTitles.contains(title) {
                            Label(L10n.t("games.mr.plan.done"), systemImage: "checkmark.circle.fill")
                                .labelStyle(.iconOnly)
                                .foregroundStyle(Color.green)
                        } else if planningTitle == title {
                            ProgressView()
                        } else {
                            // 1-tap week-plan slot for THIS match.
                            Button {
                                planMovieNight(title: title)
                            } label: {
                                Label(L10n.t("games.mr.plan.short"), systemImage: "calendar.badge.plus")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(planningTitle != nil)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    if position < gameState.matches.count - 1 {
                        Divider().padding(.leading, 58)
                    }
                }
            }
        }
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))
    }
}
