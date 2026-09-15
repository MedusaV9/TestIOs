import SwiftUI
import Combine

// Montagsmaler — draw & guess with a shared deadline, roles swap every
// round. Reuses the canvas realtime pipeline idea (normalized stroke points
// rendered in a SwiftUI `Canvas`), but ships strokes as GAME MOVES so the
// whole match — drawing included — lives in one replayable move list.
// Reducer: Content/PictionaryLogic.swift (deadline from server timestamps).
struct PictionaryView: View {
    @Environment(AppState.self) private var appState

    let engine: GameEngine

    @State private var now = Date()
    @State private var guessText = ""
    @State private var currentPoints: [[Double]] = []
    @State private var localStrokes: [PictionaryStroke] = []
    @State private var selectedColor = PictionaryView.palette[0]
    @State private var sending = false
    @State private var didSendEnd = false
    @State private var celebrated = false

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Stroke colors on the light board — drawing content, shared by both
    /// phones and the replay, therefore fixed hex values.
    static let palette = ["#2D2A32", "#E8467C", "#2D7FF9", "#1FA97C", "#F59E0B", "#8B5CF6"]
    private static let boardHex = "#FDF7FF"

    private var info: GameInfo? { GameCatalog.info(.pictionary) }
    private var accent: Color { info?.tint ?? .orange }

    var body: some View {
        ScrollView {
            content
                .padding(Brand.screenInset)
        }
        .scrollDismissesKeyboard(.interactively)
        .groupedScreenBackground()
        .navigationTitle(L10n.t("games.card.pictionary.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            if let event = note.object as? ServerEvent {
                engine.handle(event)
            }
        }
        .onReceive(clock) { date in
            now = date
        }
        .task {
            engine.onError = { [weak appState] error in
                appState?.handleAPIError(error)
            }
            if engine.session == nil {
                await engine.resume(api: appState.api)
            }
        }
        .onChange(of: engine.session?.id) { _, _ in
            resetLocalState()
        }
        .onChange(of: phaseIsFinished) { _, isDone in
            if isDone { handleFinish() }
        }
        .onAppear {
            if phaseIsFinished { handleFinish() }
        }
    }

    // MARK: Derived state

    private var session: GameSession? {
        guard let current = engine.session, current.kind == .pictionary else { return nil }
        return current
    }

    private var starterId: String { session?.createdBy ?? "" }

    private var otherId: String {
        appState.couple?.members.map(\.id).first { $0 != starterId } ?? ""
    }

    private var myId: String { appState.memberId ?? "" }

    /// The other member's id from MY perspective (starter or not).
    private var theirId: String { myId == starterId ? otherId : starterId }

    private var deckLang: String { session?.payload?["lang"]?.stringValue ?? L10n.lang }

    private var roundCount: Int { engine.payloadInt("rounds", default: Pictionary.defaultRounds) }

    private var secs: Int { engine.payloadInt("secs", default: Pictionary.defaultSecs) }

    private var deck: [String] {
        Pictionary.deck(seed: engine.seed, rounds: roundCount, lang: deckLang)
    }

    private var events: [PictionaryEvent] {
        engine.orderedMoves.compactMap { move in
            switch move.data["kind"]?.stringValue {
            case "round_start":
                guard let round = move.data["round"]?.intValue else { return nil }
                return .roundStart(member: move.memberId, round: round, at: move.createdAt)
            case "guess":
                guard let round = move.data["round"]?.intValue,
                      let text = move.data["text"]?.stringValue else { return nil }
                return .guess(member: move.memberId, round: round, text: text, at: move.createdAt)
            default:
                return nil
            }
        }
    }

    private var gameState: PictionaryState {
        Pictionary.reduce(events: events, deck: deck, starter: starterId,
                          partner: otherId, secs: secs, now: now)
    }

    private var phaseIsFinished: Bool {
        guard session?.state == "active" || session?.state == "ended" else { return false }
        return gameState.phase == .finished
    }

    private func artist(of round: Int) -> String {
        Pictionary.artist(round: round, starter: starterId, partner: otherId)
    }

    private func name(of memberId: String) -> String {
        memberId == myId ? (appState.me?.name ?? L10n.t("common.you")) : appState.partnerName
    }

    // MARK: Strokes (from the move list, round-scoped, clear-aware)

    private struct PictionaryStroke: Identifiable {
        let id: String
        let color: String
        let width: Double
        let points: [[Double]]
    }

    private func strokes(round: Int) -> [PictionaryStroke] {
        var result: [PictionaryStroke] = []
        for move in engine.orderedMoves {
            guard move.data["round"]?.intValue == round else { continue }
            switch move.data["kind"]?.stringValue {
            case "clear":
                result.removeAll()
            case "stroke":
                guard let raw = move.data["points"]?.arrayValue else { continue }
                let points = raw.compactMap { $0.arrayValue?.compactMap(\.numberValue) }
                    .filter { $0.count >= 2 }
                guard !points.isEmpty else { continue }
                result.append(PictionaryStroke(
                    id: move.id,
                    color: move.data["color"]?.stringValue ?? Self.palette[0],
                    width: move.data["width"]?.numberValue ?? 4,
                    points: points))
            default:
                break
            }
        }
        return result
    }

    // MARK: Content switch

    @ViewBuilder
    private var content: some View {
        if appState.partner == nil {
            GameNeedsPartnerView()
        } else if let session {
            if session.state == "lobby" {
                GameLobbyView(engine: engine, accent: accent)
            } else if phaseIsFinished {
                endScreen
            } else if session.state == "active" {
                activeScreen
            } else {
                startScreen
            }
        } else {
            startScreen
        }
    }

    @ViewBuilder
    private var activeScreen: some View {
        switch gameState.phase {
        case .waitingStart(let round):
            waitingStartScreen(round: round, previous: nil)
        case .drawing(let round, let deadline):
            drawingScreen(round: round, deadline: deadline)
        case .roundOver(let round, let solved):
            waitingStartScreen(round: round + 1, previous: (round, solved))
        case .finished:
            endScreen
        }
    }

    // MARK: Start

    @ViewBuilder
    private var startScreen: some View {
        if let info {
            GameStartCard(info: info, rules: L10n.t("games.pict.setup.body", ["secs": "\(Pictionary.defaultSecs)"]),
                          starting: engine.busy, onStart: startGame) {
                EmptyView()
            }
        }
    }

    private func startGame() {
        guard !engine.busy else { return }
        Task {
            resetLocalState()
            if await engine.create(api: appState.api, type: .pictionary, payload: makePayload()) {
                SoundEngine.shared.play(.pop)
                Haptics.shared.tap()
            }
        }
    }

    private func makePayload() -> JSONValue {
        // The seed comes from the server (v3.0.1 fairness contract).
        .object([
            "rounds": .number(Double(Pictionary.defaultRounds)),
            "secs": .number(Double(Pictionary.defaultSecs)),
            "lang": .string(L10n.lang)
        ])
    }

    private func resetLocalState() {
        guessText = ""
        currentPoints = []
        localStrokes = []
        sending = false
        didSendEnd = false
        celebrated = false
    }

    // MARK: Waiting for round start (+ previous-round interstitial)

    private func waitingStartScreen(round: Int, previous: (round: Int, solved: Bool)?) -> some View {
        let iAmArtist = artist(of: round) == myId
        return VStack(spacing: 14) {
            scoreHeader
            if let previous {
                roundResultCard(round: previous.round, solved: previous.solved)
            }
            GamePromptCard(eyebrow: L10n.t("games.pict.round.header", ["n": "\(round + 1)", "total": "\(roundCount)"])) {
                Image(systemName: iAmArtist ? "paintbrush.pointed.fill" : "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(accent)
                Text(iAmArtist
                     ? L10n.t("games.pict.youDraw")
                     : L10n.t("games.pict.partnerDraws", ["name": appState.partnerName]))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if iAmArtist {
                    Button {
                        startRound(round)
                    } label: {
                        Text(L10n.t("games.pict.startRound"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(sending)
                } else {
                    ProgressView()
                }
            }
        }
    }

    private func roundResultCard(round: Int, solved: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: solved ? "checkmark.circle.fill" : "hourglass")
                .font(.title2)
                .foregroundStyle(solved ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(solved
                     ? L10n.t("games.pict.solvedBy", ["name": name(of: gameState.rounds[round].solvedBy ?? "")])
                     : L10n.t("games.pict.timeUp"))
                    .font(.subheadline.weight(.semibold))
                Text(L10n.t("games.pict.wordWas", ["word": deck[round]]))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .cardSurface(padding: 14)
        .accessibilityElement(children: .combine)
    }

    private func startRound(_ round: Int) {
        guard !sending else { return }
        sending = true
        localStrokes = []
        currentPoints = []
        Task {
            let data = JSONValue.object([
                "kind": .string("round_start"),
                "round": .number(Double(round))
            ])
            if await engine.sendMove(api: appState.api, data: data) {
                SoundEngine.shared.play(.chime)
                Haptics.shared.tap()
            }
            sending = false
        }
    }

    // MARK: Drawing round

    private func drawingScreen(round: Int, deadline: Date) -> some View {
        let iAmArtist = artist(of: round) == myId
        return VStack(spacing: 12) {
            scoreHeader
            timerBar(deadline: deadline)
            if iAmArtist {
                wordBanner(word: deck[round])
            } else {
                Text(L10n.t("games.pict.guessHint", ["name": appState.partnerName]))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            boardCard(round: round, drawable: iAmArtist)
            if iAmArtist {
                artistTools(round: round)
            } else {
                guessInput(round: round)
            }
            guessList(round: round)
        }
    }

    private var scoreHeader: some View {
        VStack(spacing: 8) {
            GameScoreStrip(myScore: gameState.score(of: myId), partnerScore: gameState.score(of: theirId))
            Text(L10n.t("games.pict.solvedCount", ["n": "\(gameState.solvedCount)", "total": "\(roundCount)"]))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func timerBar(deadline: Date) -> some View {
        let remaining = max(0, deadline.timeIntervalSince(now))
        return HStack(spacing: 12) {
            Image(systemName: "timer")
                .foregroundStyle(remaining < 15 ? Color.red : Color.secondary)
            ProgressView(value: remaining / Double(max(secs, 1)))
                .tint(remaining < 15 ? Color.red : accent)
            Text("\(Int(remaining)) s")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(remaining < 15 ? Color.red : Color.secondary)
                .frame(width: 44, alignment: .trailing)
                .contentTransition(.numericText())
        }
        .cardSurface(padding: 12)
        .accessibilityElement(children: .combine)
    }

    private func wordBanner(word: String) -> some View {
        VStack(spacing: 4) {
            Text(L10n.t("games.pict.yourWord"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(word)
                .font(.title3.weight(.bold))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity)
        .cardSurface(padding: 12)
    }

    // MARK: Board

    /// The paper is drawing content (light, identical on both phones).
    private func boardCard(round: Int, drawable: Bool) -> some View {
        GeometryReader { geo in
            let board = ZStack {
                Color(hex: Self.boardHex)
                Canvas { context, size in
                    for stroke in strokes(round: round) {
                        draw(points: stroke.points, colorHex: stroke.color,
                             width: stroke.width, context: &context, size: size)
                    }
                    for stroke in localStrokes {
                        draw(points: stroke.points, colorHex: stroke.color,
                             width: stroke.width, context: &context, size: size)
                    }
                    if !currentPoints.isEmpty {
                        draw(points: currentPoints, colorHex: selectedColor,
                             width: 4, context: &context, size: size)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous)
                    .strokeBorder(Color.separator, lineWidth: 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))
            if drawable {
                board.gesture(drawGesture(round: round, size: geo.size))
            } else {
                board
            }
        }
        .aspectRatio(1.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(L10n.t("games.card.pictionary.title"))
    }

    private func draw(points: [[Double]], colorHex: String, width: Double,
                      context: inout GraphicsContext, size: CGSize) {
        let cgPoints = points.compactMap { pair -> CGPoint? in
            guard pair.count >= 2 else { return nil }
            return CGPoint(x: pair[0] * size.width, y: pair[1] * size.height)
        }
        guard let first = cgPoints.first else { return }
        var path = Path()
        path.move(to: first)
        if cgPoints.count == 1 {
            path.addLine(to: first)
        } else {
            for point in cgPoints.dropFirst() {
                path.addLine(to: point)
            }
        }
        context.stroke(path, with: .color(Color(hex: colorHex)),
                       style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private func drawGesture(round: Int, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let x = min(max(value.location.x / size.width, 0), 1)
                let y = min(max(value.location.y / size.height, 0), 1)
                currentPoints.append([Double(x), Double(y)])
                if currentPoints.count >= 300 {
                    let segment = currentPoints
                    currentPoints = [segment[segment.count - 1]]
                    submitStroke(round: round, points: segment)
                }
            }
            .onEnded { _ in
                let segment = currentPoints
                currentPoints = []
                guard !segment.isEmpty else { return }
                submitStroke(round: round, points: segment)
            }
    }

    private func submitStroke(round: Int, points: [[Double]]) {
        // Optimistic local echo — the server copy replaces it on arrival.
        let local = PictionaryStroke(id: "local-\(UUID().uuidString)", color: selectedColor, width: 4, points: points)
        localStrokes.append(local)
        Task {
            let data = JSONValue.object([
                "kind": .string("stroke"),
                "round": .number(Double(round)),
                "color": .string(selectedColor),
                "width": .number(4),
                "points": .array(points.map { pair in .array(pair.map { .number($0) }) })
            ])
            if await engine.sendMove(api: appState.api, data: data) {
                localStrokes.removeAll { $0.id == local.id }
            }
        }
    }

    private func artistTools(round: Int) -> some View {
        HStack(spacing: 12) {
            ForEach(Self.palette, id: \.self) { hex in
                Button {
                    selectedColor = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 28, height: 28)
                        .overlay {
                            if selectedColor == hex {
                                Circle()
                                    .strokeBorder(Color.primary, lineWidth: 2.5)
                                    .padding(-4)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hex)
                .accessibilityAddTraits(selectedColor == hex ? .isSelected : [])
            }
            Spacer(minLength: 0)
            Button(role: .destructive) {
                clearBoard(round: round)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .accessibilityLabel(L10n.t("memories.canvas.clear"))
        }
        .cardSurface(padding: 12)
        .sensoryFeedback(.selection, trigger: selectedColor)
    }

    private func clearBoard(round: Int) {
        localStrokes = []
        currentPoints = []
        Task {
            let data = JSONValue.object([
                "kind": .string("clear"),
                "round": .number(Double(round))
            ])
            _ = await engine.sendMove(api: appState.api, data: data)
        }
    }

    // MARK: Guessing

    private func guessInput(round: Int) -> some View {
        HStack(spacing: 10) {
            TextField(L10n.t("games.pict.guessPlaceholder"), text: $guessText)
                .submitLabel(.send)
                .onSubmit { sendGuess(round: round) }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.tertiaryCardBackground, in: Capsule())
            Button {
                sendGuess(round: round)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.body.weight(.bold))
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .disabled(guessText.trimmingCharacters(in: .whitespaces).isEmpty || sending)
            .accessibilityLabel(L10n.t("common.send"))
        }
    }

    private func sendGuess(round: Int) {
        let text = guessText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !sending else { return }
        sending = true
        guessText = ""
        Task {
            let data = JSONValue.object([
                "kind": .string("guess"),
                "round": .number(Double(round)),
                "text": .string(text)
            ])
            _ = await engine.sendMove(api: appState.api, data: data)
            sending = false
        }
    }

    @ViewBuilder
    private func guessList(round: Int) -> some View {
        let guesses: [PictionaryGuess] = gameState.rounds.indices.contains(round)
            ? Array(gameState.rounds[round].guesses.suffix(4))
            : []
        if !guesses.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(guesses.enumerated()), id: \.offset) { _, guess in
                    Label {
                        Text("\(name(of: guess.member)): \(guess.text)")
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: guess.correct ? "checkmark.circle.fill" : "bubble.left")
                    }
                    .font(.footnote)
                    .foregroundStyle(guess.correct ? Color.green : Color.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Finish

    private func handleFinish() {
        guard session != nil else { return }
        if !celebrated {
            celebrated = true
            let mine = gameState.score(of: myId)
            let theirs = gameState.score(of: theirId)
            if mine > theirs {
                Delight.celebrate(.epic, theme: .confetti)
            } else if mine == theirs {
                Delight.celebrate(.medium, theme: .hearts)
            } else {
                SoundEngine.shared.play(.lose)
                Haptics.shared.warning()
            }
        }
        guard let current = session, current.state == "active", !didSendEnd else { return }
        didSendEnd = true
        Task {
            var scores: [String: JSONValue] = [:]
            for id in [starterId, otherId] where !id.isEmpty {
                scores[id] = .number(Double(gameState.score(of: id)))
            }
            await engine.end(api: appState.api, result: .object(["scores": .object(scores)]))
        }
    }

    private var endScreen: some View {
        let mine = gameState.score(of: myId)
        let theirs = gameState.score(of: theirId)
        return GameResultCard(title: endLine(mine: mine, theirs: theirs),
                              subtitle: L10n.t("games.pict.solvedTotal", ["n": "\(gameState.solvedCount)", "total": "\(roundCount)"]),
                              emoji: mine > theirs ? "🏆" : (mine == theirs ? "💞" : "🎨")) {
            GameFinalScore(myScore: mine, partnerScore: theirs)
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
    }

    private func endLine(mine: Int, theirs: Int) -> String {
        if mine > theirs { return L10n.t("games.pict.win.you") }
        if mine < theirs { return L10n.t("games.pict.win.partner", ["name": appState.partnerName]) }
        return L10n.t("games.pict.tie")
    }
}
