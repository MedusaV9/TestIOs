import SwiftUI
import Combine

/// Truth or Dare — couple edition. Local pass-and-play on ONE phone
/// (works offline, no server session): you take turns, pick truth or dare,
/// flip the card, do the thing. Spice filter, skips (max 3 each) and a
/// shared streak counter keep it spicy.
/// With a paired partner the setup also offers the LIVE two-phone mode
/// (TruthOrDareLiveView) played via the game-session relay.
struct TruthOrDareView: View {
    @Environment(AppState.self) private var appState

    let engine: GameEngine

    private enum Stage {
        case setup, choosing, card
    }

    /// Last chosen spice level survives app restarts (defaults to Flirty).
    private static let spiceKey = "sooodreamy.tod.spice"

    private static var storedSpice: Int {
        let value = UserDefaults.standard.integer(forKey: spiceKey)
        return (1...3).contains(value) ? value : 2
    }

    @State private var stage: Stage = .setup
    @State private var spice = TruthOrDareView.storedSpice
    @State private var currentPlayer = 0
    @State private var streak = 0
    @State private var skipsLeft = [3, 3]
    @State private var usedTruthIds: Set<Int> = []
    @State private var usedDareIds: Set<Int> = []
    @State private var card: TruthOrDareItem?
    @State private var flipped = false
    @State private var sharing = false
    @State private var heartsVisible = false
    @State private var heartsTask: Task<Void, Never>?

    private var info: GameInfo? { GameCatalog.info(.truthordare) }
    private static let truthTint = Color.indigo
    private static let dareTint = Color.accentColor

    var body: some View {
        Group {
            if isLive {
                TruthOrDareLiveView(engine: engine)
            } else {
                ScrollView {
                    content
                        .padding(Brand.screenInset)
                }
                .groupedScreenBackground()
                .overlay {
                    if heartsVisible {
                        FloatingHeartsView(emojis: ["🔥", "💖", "✨", "😏"], count: 16)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .navigationTitle(L10n.t("games.card.truthordare.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if stage != .setup && !isLive {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        restart()
                    } label: {
                        Label(L10n.t("common.retry"), systemImage: "arrow.counterclockwise")
                    }
                }
            }
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
        }
        .onDisappear {
            heartsTask?.cancel()
        }
    }

    /// Live sessions take over the screen; ended sessions only keep it when
    /// they actually finished (their end screen) — a cancelled invitation
    /// falls back to the local pass-and-play mode.
    private var isLive: Bool {
        guard let session = engine.session, session.kind == .truthordare else { return false }
        if session.state == "ended" {
            return TruthOrDareLive.finished(engine: engine,
                                            memberIds: (appState.couple?.members.map(\.id) ?? []).sorted())
        }
        return true
    }

    // MARK: Players

    private var playerNames: [String] {
        let me = appState.me?.name ?? L10n.t("common.you")
        return [me, appState.partnerName]
    }

    private var currentName: String { playerNames[currentPlayer] }

    private var currentMember: Member? {
        currentPlayer == 0 ? appState.me : appState.partner
    }

    // MARK: Content switch

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .setup: setupScreen
        case .choosing: choosingScreen
        case .card: cardScreen
        }
    }

    // MARK: Setup

    @ViewBuilder
    private var setupScreen: some View {
        if let info {
            VStack(spacing: 14) {
                GameStartCard(info: info, rules: L10n.t("games.tod.setup.body"),
                              starting: engine.busy,
                              onStart: { appState.partner != nil ? startLive() : start() }) {
                    spicePicker
                }
                if appState.partner != nil {
                    Button {
                        start()
                    } label: {
                        Label(L10n.t("games.tod.playLocal"), systemImage: "iphone")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                }
            }
        }
    }

    private var spicePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(L10n.t("games.tod.spiceTitle"), selection: $spice) {
                Text("🍭 " + L10n.t("games.tod.spice1")).tag(1)
                Text("😏 " + L10n.t("games.tod.spice2")).tag(2)
                Text("🌶️ " + L10n.t("games.tod.spice3")).tag(3)
            }
            .pickerStyle(.segmented)
            Text(L10n.t("games.tod.spice\(spice).sub"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .onChange(of: spice) { _, level in
            UserDefaults.standard.set(level, forKey: Self.spiceKey)
        }
        .sensoryFeedback(.selection, trigger: spice)
    }

    /// Creates a live two-phone session over the game relay; seed + spice +
    /// rounds in the payload let both clients derive the identical decks.
    private func startLive() {
        guard !engine.busy else { return }
        let options = ["rounds": TruthOrDareLive.defaultRounds, "spice": spice]
        Task {
            let payload = GameEngine.makePayload(options: options)
            if await engine.create(api: appState.api, type: .truthordare, payload: payload) {
                SoundEngine.shared.play(.pop)
                Haptics.shared.tap()
            }
        }
    }

    private func start() {
        currentPlayer = Int.random(in: 0...1)
        streak = 0
        skipsLeft = [3, 3]
        usedTruthIds = []
        usedDareIds = []
        card = nil
        flipped = false
        stage = .choosing
        SoundEngine.shared.play(.pop)
        Haptics.shared.tap()
    }

    private func restart() {
        stage = .setup
        card = nil
        flipped = false
    }

    // MARK: Status header (streak + skips)

    private var statusHeader: some View {
        GameHeaderBar(title: L10n.t("games.tod.turn", ["name": currentName]),
                      subtitle: "🔥 \(streak) · " + L10n.t("games.tod.skipsLeft", ["n": String(skipsLeft[currentPlayer])]),
                      tint: info?.tint ?? .accentColor)
    }

    // MARK: Choosing (whose turn + truth/dare buttons)

    private var choosingScreen: some View {
        VStack(spacing: 14) {
            statusHeader
            GamePromptCard {
                MemberAvatar(member: currentMember, size: 62)
                Text(L10n.t("games.tod.turn", ["name": currentName]))
                    .font(.title3.weight(.semibold))
                Text(L10n.t("games.tod.pickPrompt"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    choiceButton(isDare: false)
                    choiceButton(isDare: true)
                }
            }
        }
    }

    private func choiceButton(isDare: Bool) -> some View {
        Button {
            draw(isDare: isDare)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: isDare ? "flame.fill" : "text.bubble.fill")
                    .font(.title)
                Text(L10n.t(isDare ? "games.tod.dare" : "games.tod.truth"))
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: Brand.cardRadius))
        .tint(isDare ? Self.dareTint : Self.truthTint)
    }

    private func draw(isDare: Bool) {
        let pool = ContentPack.truthOrDare.filter { $0.isDare == isDare && $0.spice <= spice }
        var used = isDare ? usedDareIds : usedTruthIds
        var available = pool.filter { !used.contains($0.id) }
        if available.isEmpty {
            used = []
            available = pool
            appState.notify(L10n.t("games.tod.reshuffled"), style: .info)
        }
        guard let item = available.randomElement() else { return }
        used.insert(item.id)
        if isDare {
            usedDareIds = used
        } else {
            usedTruthIds = used
        }
        card = item
        flipped = false
        stage = .card
        SoundEngine.shared.play(.whoosh)
        Haptics.shared.tap()
        Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            withAnimation(.spring(response: 0.65, dampingFraction: 0.75)) {
                flipped = true
            }
        }
    }

    // MARK: Card (big flip card + done/skip)

    private var cardScreen: some View {
        VStack(spacing: 14) {
            statusHeader
            flipCard
            if flipped {
                actionButtons
                if appState.api != nil {
                    GameShareButton(sharing: sharing, shared: false) { shareToChat() }
                }
            }
        }
    }

    @ViewBuilder
    private var flipCard: some View {
        if let card {
            ZStack {
                cardBack
                    .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
                    .opacity(flipped ? 0 : 1)
                cardFront(card)
                    .rotation3DEffect(.degrees(flipped ? 0 : -180), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
                    .opacity(flipped ? 1 : 0)
            }
            .accessibilityElement(children: .contain)
        }
    }

    private var cardBack: some View {
        VStack(spacing: 10) {
            Image(systemName: "questionmark")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(.secondary)
            Text(L10n.t("games.tod.pickPrompt"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))
    }

    /// The drawn card — a coloured playing card: indigo truth, accent dare.
    private func cardFront(_ card: TruthOrDareItem) -> some View {
        let tint = card.isDare ? Self.dareTint : Self.truthTint
        return VStack(spacing: 16) {
            HStack {
                Label(L10n.t(card.isDare ? "games.tod.dare" : "games.tod.truth"),
                      systemImage: card.isDare ? "flame.fill" : "text.bubble.fill")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(String(repeating: "🌶️", count: card.spice))
                    .font(.subheadline)
            }
            Spacer()
            Text(card.text.resolved(L10n.lang))
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 300)
        .background(tint.gradient, in: RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                skip()
            } label: {
                Label(L10n.t("games.tod.skip"), systemImage: "forward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .disabled(skipsLeft[currentPlayer] <= 0)
            Button {
                done()
            } label: {
                Label(L10n.t("games.tod.done"), systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
        }
        .controlSize(.large)
    }

    /// Posts the current card into the couple chat ("💋 Dare for Mia: …").
    private func shareToChat() {
        guard let api = appState.api, let card, !sharing else { return }
        sharing = true
        let header = L10n.t(card.isDare ? "games.tod.shareDare" : "games.tod.shareTruth", ["name": currentName])
        let text = header + "\n" + card.text.resolved(L10n.lang)
        Task {
            do {
                try await api.sendMessage(type: .text, text: text)
                SoundEngine.shared.play(.pop)
                Haptics.shared.success()
                appState.notify(L10n.t("games.sharedToChat"), style: .success)
            } catch {
                appState.handleAPIError(error)
            }
            sharing = false
        }
    }

    // MARK: Turn actions

    private func done() {
        streak += 1
        SoundEngine.shared.play(.chime)
        Haptics.shared.success()
        if streak > 0, streak % 5 == 0 {
            SoundEngine.shared.play(.tada)
            flashHearts()
        }
        nextTurn()
    }

    private func skip() {
        guard skipsLeft[currentPlayer] > 0 else { return }
        skipsLeft[currentPlayer] -= 1
        streak = 0
        SoundEngine.shared.play(.pop)
        Haptics.shared.warning()
        nextTurn()
    }

    private func nextTurn() {
        withAnimation(.snappy) {
            currentPlayer = (currentPlayer + 1) % 2
            card = nil
            flipped = false
            stage = .choosing
        }
    }

    private func flashHearts() {
        heartsVisible = true
        heartsTask?.cancel()
        heartsTask = Task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            if !Task.isCancelled {
                heartsVisible = false
            }
        }
    }
}
