import SwiftUI
import Combine

// MARK: - Emoji-Rätsel (local pass-and-play party game + live mode)
// Both partners look at the same screen, shout their guess, and whoever
// was first taps their own name to claim the point. Works solo-with-friends
// too: without a partner the second player is a generic "Team 2".
// With a paired partner the setup also offers the LIVE two-phone mode
// (EmojiRiddleLiveView) played via the game-session relay.

struct EmojiRiddleView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let engine: GameEngine

    private enum Stage {
        case setup, playing, finished
    }

    private static let categories = EmojiRiddleLive.categories
    static let categoryEmoji: [String: String] = [
        "movie": "🎬", "song": "🎵", "place": "🌍",
        "food": "🍕", "couple": "💞", "activity": "🎯"
    ]
    private static let roundOptions = [10, 15, 20]

    @State private var stage = Stage.setup
    @State private var roundCount = 15
    @State private var selectedCategories = Set(EmojiRiddleLive.categories)
    @State private var deck: [EmojiRiddle] = []
    @State private var cursor = 0
    @State private var scores = [0, 0]
    @State private var revealed = false
    @State private var lastWinner: Int?
    @State private var celebrate = false
    @State private var sharing = false
    @State private var shared = false

    private var info: GameInfo? { GameCatalog.info(.emojiriddle) }
    private var accent: Color { info?.tint ?? .orange }

    // MARK: Players (index 0 = me, 1 = partner or generic team 2)

    private var playerNames: [String] {
        [appState.me?.name ?? L10n.t("common.you"),
         appState.partner?.name ?? L10n.t("games.emoji.teamTwo")]
    }

    private var playerColors: [String?] {
        [appState.me?.color, appState.partner?.color]
    }

    private var playerAvatars: [String?] {
        [appState.me?.avatar, appState.partner?.avatar ?? "🎲"]
    }

    private var currentRiddle: EmojiRiddle? {
        deck.indices.contains(cursor) ? deck[cursor] : nil
    }

    // MARK: Body

    var body: some View {
        Group {
            if isLive {
                EmojiRiddleLiveView(engine: engine)
            } else {
                ScrollView {
                    localContent
                        .padding(Brand.screenInset)
                }
                .groupedScreenBackground()
                .overlay {
                    if celebrate {
                        FloatingHeartsView(emojis: ["🧩", "🎉", "💖", "✨", "🏆"])
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .navigationTitle(L10n.t("games.emoji.title"))
        .navigationBarTitleDisplayMode(.inline)
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
        }
    }

    /// Live sessions take over the screen; ended sessions only keep it when
    /// they actually finished (their end screen) — a cancelled invitation
    /// falls back to the local pass-and-play mode.
    private var isLive: Bool {
        guard let session = engine.session, session.kind == .emojiriddle else { return false }
        if session.state == "ended" {
            return EmojiRiddleLive.finished(engine: engine,
                                            memberIds: (appState.couple?.members.map(\.id) ?? []).sorted())
        }
        return true
    }

    @ViewBuilder
    private var localContent: some View {
        switch stage {
        case .setup: setupScreen
        case .playing: playScreen
        case .finished: endScreen
        }
    }

    // MARK: Setup

    @ViewBuilder
    private var setupScreen: some View {
        if let info {
            VStack(spacing: 14) {
                GameStartCard(info: info, rules: L10n.t("games.emoji.howto"),
                              starting: engine.busy,
                              onStart: { appState.partner != nil ? startLive() : start() }) {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker(L10n.t("games.emoji.rounds"), selection: $roundCount) {
                            ForEach(Self.roundOptions, id: \.self) { option in
                                Text("\(option)").tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        categoriesGrid
                    }
                    .sensoryFeedback(.selection, trigger: roundCount)
                }
                .disabled(selectedCategories.isEmpty)
                if appState.partner != nil {
                    Button(action: start) {
                        Label(L10n.t("games.emoji.playLocal"), systemImage: "iphone")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .disabled(selectedCategories.isEmpty)
                }
            }
        }
    }

    /// Creates a live two-phone session over the game relay; the seed +
    /// options in the payload let both clients derive the identical deck.
    private func startLive() {
        guard !engine.busy else { return }
        let options = ["rounds": roundCount,
                       "cats": EmojiRiddleLive.categoryMask(for: selectedCategories)]
        Task {
            let payload = GameEngine.makePayload(options: options)
            if await engine.create(api: appState.api, type: .emojiriddle, payload: payload) {
                SoundEngine.shared.play(.pop)
                Haptics.shared.tap()
            }
        }
    }

    private var categoriesGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("games.emoji.categories"))
                .font(.subheadline.weight(.medium))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(Self.categories, id: \.self) { category in
                    let selected = selectedCategories.contains(category)
                    Toggle(isOn: Binding(
                        get: { selected },
                        set: { on in
                            if on { selectedCategories.insert(category) } else { selectedCategories.remove(category) }
                        }
                    )) {
                        VStack(spacing: 4) {
                            Text(Self.categoryEmoji[category] ?? "❓")
                                .font(.title3)
                            Text(L10n.t("games.emoji.cat.\(category)"))
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .toggleStyle(.button)
                    .buttonBorderShape(.roundedRectangle(radius: Brand.tileRadius))
                    .tint(accent)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectedCategories)
    }

    private func start() {
        let pool = ContentPack.emojiRiddles.filter { selectedCategories.contains($0.category) }
        deck = Array(pool.seededShuffled(seed: Int.random(in: 0..<Int.max)).prefix(roundCount))
        cursor = 0
        scores = [0, 0]
        revealed = false
        lastWinner = nil
        sharing = false
        shared = false
        stage = .playing
        SoundEngine.shared.play(.whoosh)
        Haptics.shared.tap()
    }

    // MARK: Playing

    private var playScreen: some View {
        VStack(spacing: 14) {
            GameScoreStrip(myScore: scores[0], partnerScore: scores[1],
                           partnerFallbackName: L10n.t("games.emoji.teamTwo"))
            GameHeaderBar(title: L10n.t("games.emoji.round", ["n": String(cursor + 1), "total": String(deck.count)]),
                          progress: Double(cursor) / Double(max(deck.count, 1)),
                          tint: accent)
            if let riddle = currentRiddle {
                riddleCard(riddle)
            }
            controls
        }
    }

    // MARK: Riddle card (flip reveal)

    private func riddleCard(_ riddle: EmojiRiddle) -> some View {
        ZStack {
            riddleFront(riddle)
                .rotation3DEffect(.degrees(revealed ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
                .opacity(revealed ? 0 : 1)
            riddleBack(riddle)
                .rotation3DEffect(.degrees(revealed ? 0 : -180), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
                .opacity(revealed ? 1 : 0)
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.75), value: revealed)
        .id(cursor)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)))
    }

    private func riddleFront(_ riddle: EmojiRiddle) -> some View {
        GamePromptCard(eyebrow: categoryTitle(riddle.category)) {
            Text(riddle.emojis)
                .font(.system(size: 54))
                .lineSpacing(8)
                .minimumScaleFactor(0.6)
            Text(L10n.t("games.emoji.shout"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 240)
    }

    private func riddleBack(_ riddle: EmojiRiddle) -> some View {
        GamePromptCard {
            Text(riddle.emojis)
                .font(.title2)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(riddle.answer.resolved(L10n.lang))
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            Text(revealLine)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(lastWinner == nil ? Color.secondary : accent)
        }
        .frame(minHeight: 240)
    }

    private var revealLine: String {
        if let winner = lastWinner {
            return L10n.t("games.emoji.gotIt", ["name": playerNames[winner]])
        }
        return L10n.t("games.emoji.noOneKnew")
    }

    private func categoryTitle(_ category: String) -> String {
        (Self.categoryEmoji[category] ?? "") + " " + L10n.t("games.emoji.cat.\(category)")
    }

    // MARK: Controls

    @ViewBuilder
    private var controls: some View {
        if revealed {
            Button(action: advance) {
                Text(L10n.t(cursor + 1 >= deck.count ? "games.emoji.results" : "games.emoji.next"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        } else {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    pointButton(0)
                    pointButton(1)
                }
                Button {
                    award(nil)
                } label: {
                    Text(L10n.t("games.emoji.nobody"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    private func pointButton(_ index: Int) -> some View {
        Button {
            award(index)
        } label: {
            HStack(spacing: 8) {
                MemberAvatar(emoji: playerAvatars[index], colorHex: playerColors[index], size: 26)
                Text(L10n.t("games.emoji.point", ["name": playerNames[index]]))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Color(hex: playerColors[index] ?? "A855F7"))
    }

    // MARK: Round flow

    /// The tap first flips the card open (and awards the point), the
    /// "Weiter" button then advances to the next riddle.
    private func award(_ index: Int?) {
        guard !revealed else { return }
        lastWinner = index
        revealed = true
        if let index {
            scores[index] += 1
            Haptics.shared.success()
            SoundEngine.shared.play(.pop)
        } else {
            Haptics.shared.tap()
            SoundEngine.shared.play(.whoosh)
        }
    }

    private func advance() {
        if cursor + 1 >= deck.count {
            finishGame()
            return
        }
        withAnimation(.snappy) {
            cursor += 1
            revealed = false
            lastWinner = nil
        }
        Haptics.shared.tap()
    }

    private func finishGame() {
        stage = .finished
        if scores[0] == scores[1] {
            SoundEngine.shared.play(.chime)
        } else {
            SoundEngine.shared.play(.tada)
        }
        Haptics.shared.success()
        celebrate = true
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            withAnimation(.easeOut(duration: 0.6)) {
                celebrate = false
            }
        }
    }

    // MARK: End screen

    private var isTie: Bool { scores[0] == scores[1] }

    private var winnerIndex: Int { scores[0] >= scores[1] ? 0 : 1 }

    private var endScreen: some View {
        GameResultCard(title: isTie ? L10n.t("games.emoji.tie")
                                    : L10n.t("games.emoji.winner", ["name": playerNames[winnerIndex]]),
                       subtitle: L10n.t("games.emoji.finalScore"),
                       emoji: isTie ? "💞" : "🏆") {
            GameFinalScore(myScore: scores[0], partnerScore: scores[1],
                           partnerFallbackName: L10n.t("games.emoji.teamTwo"))
            if appState.api != nil {
                GameShareButton(sharing: sharing, shared: shared) { shareToChat() }
            }
            Button(action: start) {
                Text(L10n.t("games.emoji.rematch"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            Button(L10n.t("games.emoji.backToHub")) { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Share to chat

    /// Posts the final score into the couple chat.
    private var shareText: String {
        let header = L10n.t("games.share.header", ["game": "🧩 " + L10n.t("games.emoji.title")])
        let scoreLine = "\(playerNames[0]) \(scores[0]) : \(scores[1]) \(playerNames[1])"
        let verdict = isTie
            ? L10n.t("games.emoji.tie")
            : L10n.t("games.emoji.winner", ["name": playerNames[winnerIndex]])
        return header + "\n" + scoreLine + "\n" + verdict
    }

    private func shareToChat() {
        guard let api = appState.api, !sharing, !shared else { return }
        sharing = true
        let text = shareText
        Task {
            do {
                try await api.sendMessage(type: .text, text: text)
                shared = true
                SoundEngine.shared.play(.pop)
                Haptics.shared.success()
                appState.notify(L10n.t("games.sharedToChat"), style: .success)
            } catch {
                appState.handleAPIError(error)
            }
            sharing = false
        }
    }
}
