import SwiftUI
import Combine

// Replay & Zuschauer-Modus — finished matches play back as a movie
// (moves in original order, async pauses time-lapsed, the turning point
// starred), and open sessions can be watched live: the relay broadcasts
// `game_move` to ALL sockets of the couple, so a second device (iPad!)
// renders the same feed read-only. Core: Content/ReplayLogic.swift.

// MARK: - Hub (live sessions + finished games)

struct ReplayHubView: View {
    @Environment(AppState.self) private var appState

    @State private var openSessions: [GameSession] = []
    @State private var finished: [GameSession] = []
    @State private var loading = true

    var body: some View {
        List {
            if loading && finished.isEmpty && openSessions.isEmpty {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if finished.isEmpty && openSessions.isEmpty {
                ContentUnavailableView {
                    Label(L10n.t("games.replay.emptyTitle"), systemImage: "film")
                } description: {
                    Text(L10n.t("games.replay.emptyBody"))
                }
                .listRowBackground(Color.clear)
            } else {
                if !openSessions.isEmpty {
                    Section(L10n.t("games.replay.liveSection")) {
                        ForEach(openSessions) { session in
                            row(session, live: true)
                        }
                    }
                }
                if !finished.isEmpty {
                    Section(L10n.t("games.replay.pastSection")) {
                        ForEach(finished) { session in
                            row(session, live: false)
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.t("games.replay.title"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent,
                  event.type == .gameCreated || event.type == .gameEnded else { return }
            Task { await load() }
        }
    }

    private func load() async {
        guard let api = appState.api else {
            loading = false
            return
        }
        async let open = try? api.openGames()
        async let history = try? api.games(limit: 50)
        openSessions = (await open ?? []).filter { $0.kind != nil }
        finished = (await history ?? []).filter { $0.state == "ended" && !$0.moves.isEmpty && $0.kind != nil }
        loading = false
    }

    @ViewBuilder
    private func row(_ session: GameSession, live: Bool) -> some View {
        if let kind = session.kind, let info = GameCatalog.info(kind) {
            NavigationLink {
                ReplayPlayerView(initial: session)
            } label: {
                HStack(spacing: 12) {
                    IconTile(systemImage: info.systemImage, tint: info.tint, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.title)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                        Text(live
                             ? L10n.t("games.replay.liveMoves", ["n": "\(session.moves.count)"])
                             : session.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if live {
                        GamePhaseLabel(text: L10n.t("games.replay.liveBadge"), systemImage: "dot.radiowaves.left.and.right")
                    } else {
                        Label("\(session.moves.count)", systemImage: "play.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

// MARK: - Player (replay of an ended match / live spectating)

struct ReplayPlayerView: View {
    @Environment(AppState.self) private var appState

    let initial: GameSession

    @State private var session: GameSession
    @State private var playIndex = -1
    @State private var playing = false
    @State private var speed = 1.0
    @State private var shared = false
    @State private var playbackTask: Task<Void, Never>?

    init(initial: GameSession) {
        self.initial = initial
        _session = State(initialValue: initial)
    }

    private var live: Bool { session.state != "ended" }
    private var info: GameInfo? { session.kind.flatMap { GameCatalog.info($0) } }

    var body: some View {
        feed
            .safeAreaInset(edge: .bottom) {
                if !live {
                    controls
                        .padding(.horizontal, Brand.screenInset)
                        .padding(.bottom, 8)
                }
            }
            .groupedScreenBackground()
            .navigationTitle(info?.title ?? L10n.t("games.replay.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if live {
                        GamePhaseLabel(text: L10n.t("games.replay.liveBadge"), systemImage: "dot.radiowaves.left.and.right")
                    } else {
                        Button {
                            shareToChat()
                        } label: {
                            Label(L10n.t("games.shareToChat"), systemImage: shared ? "checkmark" : "paperplane")
                        }
                        .disabled(shared)
                    }
                }
            }
            .task {
                // Fresh copy (spectator may open the hub before the last frames).
                if let latest = try? await appState.api?.game(id: session.id) {
                    session = latest
                }
                if live {
                    playIndex = steps.count - 1
                } else if playIndex < 0 {
                    startPlayback(from: -1)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
                guard let event = note.object as? ServerEvent else { return }
                handleLive(event)
            }
            .onDisappear {
                playbackTask?.cancel()
            }
    }

    // MARK: Steps (moves → feed entries)

    private struct Step: Identifiable {
        let id: String
        let memberId: String
        let emoji: String
        let text: String
        let at: Date
        let highlight: Bool
    }

    private var orderedMoves: [GameMove] {
        session.moves.sorted { a, b in
            if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
            return a.id < b.id
        }
    }

    /// Feed steps — consecutive canvas strokes of one artist collapse into
    /// a single "draws…" entry so Montagsmaler replays stay watchable.
    private var steps: [Step] {
        let type = session.kind?.rawValue ?? "?"
        var result: [Step] = []
        var strokeRun = 0
        var strokeMember = ""
        var strokeId = ""
        var strokeAt = Date()
        func flushStrokes() {
            guard strokeRun > 0 else { return }
            result.append(Step(id: strokeId, memberId: strokeMember,
                               emoji: Replay.stepEmoji(gameType: type, moveKind: "stroke"),
                               text: L10n.t("games.replay.step.strokes", ["n": "\(strokeRun)"]),
                               at: strokeAt, highlight: false))
            strokeRun = 0
        }
        for move in orderedMoves {
            let kind = move.data["kind"]?.stringValue ?? ""
            if kind == "stroke" {
                if strokeRun > 0 && strokeMember != move.memberId {
                    flushStrokes()
                }
                if strokeRun == 0 {
                    strokeMember = move.memberId
                    strokeId = move.id
                    strokeAt = move.createdAt
                }
                strokeRun += 1
                continue
            }
            flushStrokes()
            result.append(step(for: move, type: type, kind: kind))
        }
        flushStrokes()
        return result
    }

    private func step(for move: GameMove, type: String, kind: String) -> Step {
        let (text, magnitude) = describe(move: move, type: type, kind: kind)
        return Step(id: move.id, memberId: move.memberId,
                    emoji: Replay.stepEmoji(gameType: type, moveKind: kind),
                    text: text, at: move.createdAt,
                    highlight: Replay.isHighlight(gameType: type, moveKind: kind, magnitude: magnitude))
    }

    /// Localized feed line + highlight magnitude per move.
    private func describe(move: GameMove, type: String, kind: String) -> (String, Int) {
        let data = move.data
        switch (type, kind) {
        case (_, "commit"):
            return (L10n.t("games.replay.step.commit"), 0)
        case (_, "reveal"):
            let verified = data["verified"]?.boolValue ?? false
            return (L10n.t(verified ? "games.replay.step.revealVerified" : "games.replay.step.reveal"), 0)
        case ("battleship", "salvo"):
            let n = data["cells"]?.arrayValue?.count ?? 0
            return (L10n.t("games.replay.step.salvo", ["n": "\(n)"]), 0)
        case ("battleship", "report"):
            let hits = data["hits"]?.arrayValue?.count ?? 0
            let sunk = data["sunk"]?.arrayValue?.count ?? 0
            if sunk > 0 {
                return (L10n.t("games.replay.step.sunk", ["n": "\(sunk)"]), sunk)
            }
            return (L10n.t("games.replay.step.report", ["n": "\(hits)"]), 0)
        case ("pictionary", "round_start"):
            let round = data["round"]?.intValue ?? 0
            return (L10n.t("games.replay.step.round", ["n": "\(round + 1)"]), 0)
        case ("pictionary", "guess"):
            let text = data["text"]?.stringValue ?? "?"
            return (L10n.t("games.replay.step.pictGuess", ["text": text]), 0)
        case ("kniffel", "roll"):
            return (L10n.t("games.replay.step.roll"), 0)
        case ("kniffel", "score"):
            let category = data["category"]?.stringValue ?? "?"
            return (L10n.t("games.replay.step.score", ["cat": L10n.t("games.kn.cat.\(category)")]), 0)
        case ("movieroulette", "swipe"):
            if let match = data["match"]?.objectValue, let title = match["title"]?.stringValue {
                return (L10n.t("games.replay.step.match", ["title": title]), 1)
            }
            let liked = data["like"]?.boolValue ?? false
            return (L10n.t(liked ? "games.replay.step.like" : "games.replay.step.nope"), 0)
        case ("stadtlandfluss", "rate"):
            return (L10n.t("games.replay.step.rate"), 0)
        case ("twotruths", "statements"):
            return (L10n.t("games.replay.step.statements"), 0)
        case ("twotruths", "guess"):
            return (L10n.t("games.replay.step.ttGuess"), 0)
        case ("dailyquests", "quest_done"):
            return (L10n.t("games.replay.step.quest"), 1)
        default:
            return (L10n.t("games.replay.step.generic"), 0)
        }
    }

    private var turningPointIndex: Int? {
        live ? nil : Replay.turningPoint(highlights: steps.map(\.highlight))
    }

    // MARK: Live spectating

    private func handleLive(_ event: ServerEvent) {
        switch event.type {
        case .gameMove:
            guard let payload = event.decode(GameMovePayload.self),
                  payload.gameId == session.id,
                  !session.moves.contains(where: { $0.id == payload.move.id }) else { return }
            session.moves.append(payload.move)
            if live {
                playIndex = steps.count - 1
                SoundEngine.shared.play(.click)
            }
        case .gameEnded:
            if let game = event.decode(GameOnlyResponse.self)?.game, game.id == session.id {
                session = game
                playIndex = steps.count - 1
            }
        default:
            break
        }
    }

    // MARK: Feed / controls

    private var scoresLine: String? {
        guard let scores = session.result?["scores"]?.objectValue else { return nil }
        let mine = appState.memberId.flatMap { scores[$0]?.intValue } ?? 0
        let theirs = scores.first { $0.key != appState.memberId }?.value.intValue ?? 0
        return L10n.t("games.replay.finalScore", ["a": "\(mine)", "b": "\(theirs)"])
    }

    private var feed: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    ForEach(Array(steps.prefix(playIndex + 1).enumerated()), id: \.element.id) { index, step in
                        stepRow(step, index: index)
                            .id(step.id)
                    }
                } header: {
                    Text(live
                         ? L10n.t("games.replay.watching")
                         : L10n.t("games.replay.movesCount", ["n": "\(steps.count)"]))
                } footer: {
                    if let scores = scoresLine {
                        Text(scores)
                    }
                }
            }
            .onChange(of: playIndex) { _, new in
                guard new >= 0, new < steps.count else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(steps[new].id, anchor: .bottom)
                }
            }
        }
    }

    private func stepRow(_ step: Step, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if index == turningPointIndex {
                Label(L10n.t("games.replay.turningPoint"), systemImage: "star.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.orange)
            }
            HStack(alignment: .top, spacing: 12) {
                Text(step.emoji)
                    .font(.title3)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(memberName(step.memberId))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(step.memberId == appState.memberId ? Color.orange : Color.accentColor)
                    Text(step.text)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(step.at.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if step.highlight {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(Color.orange)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(step.highlight ? Color.orange.opacity(0.10) : nil)
        .accessibilityElement(children: .combine)
    }

    /// Transport bar — Liquid Glass capsule above the home indicator.
    private var controls: some View {
        HStack(spacing: 14) {
            Button {
                togglePlay()
            } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.title3.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(playing ? L10n.t("games.q36.timerPause") : L10n.t("games.q36.timerStart"))
            Slider(value: Binding(
                get: { Double(Swift.max(0, playIndex)) },
                set: { value in
                    pause()
                    playIndex = Int(value.rounded())
                }
            ), in: 0...Double(Swift.max(1, steps.count - 1)), step: 1)
            Button {
                speed = speed >= 4 ? 1 : speed * 2
                if playing { startPlayback(from: playIndex) }
            } label: {
                Text("\(Int(speed))×")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .glassEffect(.regular, in: .capsule)
    }

    // MARK: Playback engine (time-lapse via ReplayLogic)

    private func togglePlay() {
        if playing {
            pause()
        } else {
            let start = playIndex >= steps.count - 1 ? -1 : playIndex
            startPlayback(from: start)
        }
    }

    private func pause() {
        playing = false
        playbackTask?.cancel()
    }

    private func startPlayback(from start: Int) {
        playbackTask?.cancel()
        playing = true
        playIndex = start
        let all = steps
        playbackTask = Task {
            var previous: Date? = start >= 0 && start < all.count ? all[start].at : nil
            for index in (start + 1)..<all.count {
                let gap = previous.map { all[index].at.timeIntervalSince($0) } ?? 0
                let delay = Replay.playbackDelay(forGap: gap, speed: speed)
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                playIndex = index
                previous = all[index].at
                if all[index].highlight {
                    Haptics.shared.tap()
                }
                if index == turningPointIndex {
                    SoundEngine.shared.play(.sparkle)
                }
            }
            playing = false
            if !all.isEmpty {
                SoundEngine.shared.play(.chime)
            }
        }
    }

    // MARK: Share recap to chat

    private func shareToChat() {
        guard let api = appState.api, !shared, let kind = session.kind else { return }
        var lines = [
            L10n.t("games.replay.share.title",
                   ["emoji": GameCatalog.emoji(for: kind),
                    "game": GameCatalog.title(for: kind),
                    "n": "\(steps.count)"])
        ]
        if let scores = scoresLine {
            lines.append(scores)
        }
        if let turn = turningPointIndex {
            lines.append(L10n.t("games.replay.share.turn", ["text": steps[turn].text]))
        }
        Task {
            do {
                _ = try await api.sendMessage(type: .text, text: lines.joined(separator: "\n"))
                shared = true
                SoundEngine.shared.play(.chime)
                Haptics.shared.success()
            } catch {
                appState.handleAPIError(error)
            }
        }
    }

    private func memberName(_ id: String) -> String {
        if id == appState.memberId {
            return appState.me?.name ?? L10n.t("common.you")
        }
        return appState.couple?.members.first { $0.id == id }?.name ?? appState.partnerName
    }
}
