import SwiftUI
import Combine

/// Foto-Memory — realtime pairs with the couple's OWN gallery photos.
///
/// The creator picks the pair count; the create payload carries the chosen
/// `photoIds` plus a seed, so both phones derive the identical shuffled
/// board (`PhotoMemory.tiles`). One move = one full turn (two flipped
/// tiles): `{"kind": "flip", "first": i, "second": j}`. Match → point and
/// the same player goes again; miss → turn switches (reducer in
/// Content/CoupleGamesLogic.swift, pinned by the Linux logic tests).
struct PhotoMemoryView: View {
    @Environment(AppState.self) private var appState

    let engine: GameEngine

    @State private var photos: [Photo] = []
    @State private var photosLoaded = false
    @State private var setupPairs = 6
    @State private var pendingFirst: Int?
    @State private var revealed: Set<Int> = []
    @State private var revealTask: Task<Void, Never>?
    @State private var sending = false
    @State private var didSendEnd = false
    @State private var celebrate = false

    private static let pairOptions = [4, 6, 8]
    private static let minPairs = 4
    private var info: GameInfo? { GameCatalog.info(.photomemory) }
    private var accent: Color { info?.tint ?? .mint }

    var body: some View {
        ScrollView {
            content
                .padding(Brand.screenInset)
        }
        .groupedScreenBackground()
        .overlay {
            if celebrate {
                FloatingHeartsView(emojis: ["🖼️", "💞", "🏆", "✨", "📸"], count: 22)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .navigationTitle(L10n.t("games.card.photomemory.title"))
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
            await loadPhotos()
        }
        .onChange(of: engine.session?.id) { _, _ in
            resetLocalState()
        }
        .onChange(of: flips.count) { old, new in
            if new > old { revealLatestFlip() }
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
        guard let current = engine.session, current.kind == .photomemory else { return nil }
        return current
    }

    private var starterId: String { session?.createdBy ?? "" }

    private var otherId: String {
        appState.couple?.members.map(\.id).first { $0 != starterId } ?? ""
    }

    private var photoIds: [String] {
        session?.payload?["photoIds"]?.arrayValue?.compactMap(\.stringValue) ?? []
    }

    private var pairCount: Int { max(2, min(photoIds.count, PhotoMemory.maxPairs)) }

    private var tiles: [Int] {
        guard session != nil, !photoIds.isEmpty else { return [] }
        return PhotoMemory.tiles(pairCount: pairCount, seed: engine.seed)
    }

    private var flips: [(memberId: String, first: Int, second: Int)] {
        engine.moves(kind: "flip").compactMap { move in
            guard let first = move.data["first"]?.intValue,
                  let second = move.data["second"]?.intValue else { return nil }
            return (move.memberId, first, second)
        }
    }

    private var boardState: PhotoMemoryState {
        PhotoMemory.reduce(flips: flips, tiles: tiles, starter: starterId, partner: otherId)
    }

    private var myTurn: Bool { boardState.turn == appState.memberId }

    private var finished: Bool {
        guard session?.state == "active" || session?.state == "ended", !tiles.isEmpty else { return false }
        return PhotoMemory.finished(state: boardState, tiles: tiles)
    }

    private var myScore: Int { boardState.score(of: appState.memberId ?? "") }
    private var partnerScore: Int { boardState.score(of: appState.partner?.id ?? "") }

    private func photo(forPair pairIndex: Int) -> Photo? {
        guard photoIds.indices.contains(pairIndex) else { return nil }
        let id = photoIds[pairIndex]
        return photos.first { $0.id == id }
    }

    private func name(of memberId: String) -> String {
        if memberId == appState.memberId {
            return appState.me?.name ?? L10n.t("common.you")
        }
        return appState.partnerName
    }

    // MARK: Photos

    private func loadPhotos() async {
        guard let api = appState.api else { return }
        if let loaded = try? await api.photos() {
            photos = loaded
        }
        photosLoaded = true
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
                playScreen
            } else {
                setupScreen
            }
        } else {
            setupScreen
        }
    }

    // MARK: Setup

    @ViewBuilder
    private var setupScreen: some View {
        if let info {
            if !photosLoaded {
                GameStartCard(info: info, rules: L10n.t("games.memory.setup.body"), starting: true, onStart: {}) {
                    EmptyView()
                }
            } else if photos.count < Self.minPairs {
                VStack(spacing: 14) {
                    GameStartCard(info: info, rules: L10n.t("games.memory.setup.body"), starting: false, onStart: {}) {
                        Label(L10n.t("games.memory.needPhotos", ["n": String(Self.minPairs)]),
                              systemImage: "photo.badge.exclamationmark")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.orange)
                    }
                    .disabled(true)
                }
            } else {
                GameStartCard(info: info, rules: L10n.t("games.memory.setup.body"),
                              starting: engine.busy, onStart: { startGame(pairs: setupPairs) }) {
                    Picker(L10n.t("games.memory.setup.pairs"), selection: $setupPairs) {
                        ForEach(Self.pairOptions.filter { $0 <= photos.count }, id: \.self) { option in
                            Text("\(option)").tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .sensoryFeedback(.selection, trigger: setupPairs)
                }
            }
        }
    }

    private func startGame(pairs: Int) {
        guard !engine.busy, photos.count >= Self.minPairs else { return }
        let count = min(pairs, photos.count, PhotoMemory.maxPairs)
        let picked = photos.shuffled().prefix(count).map(\.id)
        Task {
            resetLocalState()
            // The seed comes from the server (v3.0.1 fairness contract).
            let payload = JSONValue.object([
                "pairs": .number(Double(count)),
                "photoIds": .array(picked.map { .string($0) })
            ])
            if await engine.create(api: appState.api, type: .photomemory, payload: payload) {
                SoundEngine.shared.play(.pop)
                Haptics.shared.tap()
            }
        }
    }

    private func resetLocalState() {
        pendingFirst = nil
        revealed = []
        revealTask?.cancel()
        sending = false
        didSendEnd = false
        celebrate = false
    }

    // MARK: Play

    private var playScreen: some View {
        VStack(spacing: 14) {
            GameScoreStrip(myScore: myScore, partnerScore: partnerScore)
            HStack {
                GamePhaseLabel(text: myTurn
                               ? L10n.t("games.memory.yourTurn")
                               : L10n.t("games.memory.partnerTurn", ["name": appState.partnerName]),
                               systemImage: myTurn ? "hand.tap.fill" : "hourglass",
                               tint: myTurn ? .green : .secondary)
                Spacer()
                lastFlipBanner
            }
            boardGrid
            if !myTurn {
                GameWaitingHint()
            }
        }
    }

    @ViewBuilder
    private var lastFlipBanner: some View {
        if let flip = flips.last {
            let isMatch = tiles.indices.contains(flip.first)
                && tiles.indices.contains(flip.second)
                && tiles[flip.first] == tiles[flip.second]
            GamePhaseLabel(text: isMatch
                           ? L10n.t("games.memory.match")
                           : L10n.t("games.memory.noMatch", ["name": name(of: boardState.turn)]),
                           systemImage: isMatch ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath",
                           tint: isMatch ? .green : .orange)
        }
    }

    private var boardGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(tiles.indices, id: \.self) { index in
                tileView(index: index)
            }
        }
        .cardSurface(padding: 12)
    }

    @ViewBuilder
    private func tileView(index: Int) -> some View {
        let pairIndex = tiles[index]
        let matchedBy = boardState.matched[pairIndex]
        let faceUp = matchedBy != nil || pendingFirst == index || revealed.contains(index)
        Button {
            tap(index: index)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(faceUp ? Color.tertiaryCardBackground : accent.opacity(0.35))
                if faceUp {
                    tileImage(pairIndex: pairIndex)
                } else {
                    Image(systemName: "heart.fill")
                        .font(.title3)
                        .foregroundStyle(accent)
                }
                if let matchedBy {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(discColor(of: matchedBy), lineWidth: 2.5)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .rotation3DEffect(.degrees(faceUp ? 0 : 180), axis: (x: 0, y: 1, z: 0))
            .animation(.snappy, value: faceUp)
        }
        .buttonStyle(.plain)
        .disabled(!myTurn || sending || faceUp)
        .accessibilityLabel(faceUp ? L10n.t("memories.gallery.title") : "\(index + 1)")
    }

    /// Members' avatar colours mark who found a pair.
    private func discColor(of memberId: String) -> Color {
        if let hex = appState.couple?.members.first(where: { $0.id == memberId })?.color {
            return Color(hex: hex)
        }
        return memberId == appState.memberId ? Color.accentColor : Color.orange
    }

    @ViewBuilder
    private func tileImage(pairIndex: Int) -> some View {
        if let photo = photo(forPair: pairIndex) {
            RemotePhoto(api: appState.api, path: photo.thumbUrl ?? photo.url)
        } else {
            // Photo deleted meanwhile — the pair index still identifies it.
            Image(systemName: "photo")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Actions

    private func tap(index: Int) {
        guard myTurn, !sending else { return }
        Haptics.shared.tap()
        if pendingFirst == nil {
            pendingFirst = index
            SoundEngine.shared.play(.click)
            return
        }
        guard let first = pendingFirst, first != index else { return }
        sending = true
        Task {
            let data = JSONValue.object([
                "kind": .string("flip"),
                "first": .number(Double(first)),
                "second": .number(Double(index))
            ])
            _ = await engine.sendMove(api: appState.api, data: data)
            pendingFirst = nil
            sending = false
        }
    }

    /// Show the two tiles of the newest flip briefly; matches stay face-up
    /// via the reducer, misses flip back after a beat.
    private func revealLatestFlip() {
        guard let flip = flips.last else { return }
        let isMatch = tiles.indices.contains(flip.first)
            && tiles.indices.contains(flip.second)
            && tiles[flip.first] == tiles[flip.second]
        revealed = [flip.first, flip.second]
        if isMatch {
            SoundEngine.shared.play(.success)
            Haptics.shared.success()
        } else {
            SoundEngine.shared.play(.pop)
        }
        revealTask?.cancel()
        revealTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            revealed = []
        }
    }

    private func handleFinish() {
        guard session != nil else { return }
        if !celebrate {
            celebrate = true
            SoundEngine.shared.play(myScore >= partnerScore ? .win : .lose)
            Haptics.shared.success()
        }
        guard let current = session, current.state == "active", !didSendEnd else { return }
        didSendEnd = true
        Task {
            await engine.end(api: appState.api, result: resultJSON)
        }
    }

    private var resultJSON: JSONValue {
        let state = boardState
        var scores: [String: JSONValue] = [:]
        for id in [starterId, otherId] where !id.isEmpty {
            scores[id] = .number(Double(state.score(of: id)))
        }
        return .object(["scores": .object(scores)])
    }

    // MARK: End screen

    private var endScreen: some View {
        GameResultCard(title: endLine(mine: myScore, theirs: partnerScore),
                       emoji: myScore == partnerScore ? "💞" : "🏆") {
            GameFinalScore(myScore: myScore, partnerScore: partnerScore)
            Button {
                startGame(pairs: pairCount)
            } label: {
                Text(L10n.t("games.rematch"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(engine.busy || photos.count < Self.minPairs)
        }
    }

    private func endLine(mine: Int, theirs: Int) -> String {
        if mine == theirs { return L10n.t("games.memory.tie") }
        if mine > theirs { return L10n.t("games.memory.win.you") }
        return L10n.t("games.memory.win.partner", ["name": appState.partnerName])
    }
}
