import SwiftUI
import Combine

/// 4 Gewinnt live — realtime Connect Four over the game-session relay.
///
/// The creator drops first, then strict alternation. Both clients reduce
/// the identical board from the ordered move list via `ConnectFour.reduce`
/// (Content/CoupleGamesLogic.swift, pinned by the Linux logic tests).
///
/// Move protocol: `{"kind": "drop", "column": 0…6}`.
struct ConnectFourView: View {
    @Environment(AppState.self) private var appState

    let engine: GameEngine

    @State private var sending = false
    @State private var didSendEnd = false
    @State private var celebrate = false
    @State private var lastCount = 0

    private var info: GameInfo? { GameCatalog.info(.connectfour) }

    var body: some View {
        ScrollView {
            content
                .padding(Brand.screenInset)
        }
        .groupedScreenBackground()
        .overlay {
            if celebrate {
                FloatingHeartsView(emojis: ["🏆", "🔴", "🟡", "✨", "🎉"], count: 22)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .navigationTitle(L10n.t("games.card.connectfour.title"))
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
            lastCount = boardState.moveCount
        }
        .onChange(of: engine.session?.id) { _, _ in
            resetLocalState()
        }
        .onChange(of: boardState.moveCount) { old, new in
            if new > old {
                SoundEngine.shared.play(.pop)
                Haptics.shared.tap()
            }
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
        guard let current = engine.session, current.kind == .connectfour else { return nil }
        return current
    }

    /// Creator drops first; the partner id is the other couple member.
    private var starterId: String { session?.createdBy ?? "" }

    private var otherId: String {
        appState.couple?.members.map(\.id).first { $0 != starterId } ?? ""
    }

    private var drops: [(memberId: String, column: Int)] {
        engine.moves(kind: "drop").compactMap { move in
            guard let column = move.data["column"]?.intValue else { return nil }
            return (move.memberId, column)
        }
    }

    private var boardState: ConnectFourState {
        ConnectFour.reduce(drops: drops, starter: starterId, partner: otherId)
    }

    private var turnId: String {
        ConnectFour.turn(state: boardState, starter: starterId, partner: otherId)
    }

    private var myTurn: Bool { turnId == appState.memberId }

    private var finished: Bool {
        guard session?.state == "active" || session?.state == "ended" else { return false }
        let state = boardState
        return state.winner != nil || state.isDraw
    }

    /// Disc colours follow the members' own avatar colours.
    private func discColor(of memberId: String) -> Color {
        let member = appState.couple?.members.first { $0.id == memberId }
        if let hex = member?.color { return Color(hex: hex) }
        return memberId == appState.memberId ? Color.accentColor : Color.orange
    }

    private func name(of memberId: String) -> String {
        if memberId == appState.memberId {
            return appState.me?.name ?? L10n.t("common.you")
        }
        return appState.partnerName
    }

    // MARK: Content switch

    @ViewBuilder
    private var content: some View {
        if appState.partner == nil {
            GameNeedsPartnerView()
        } else if let session {
            if session.state == "lobby" {
                GameLobbyView(engine: engine, accent: info?.tint ?? .accentColor)
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
            GameStartCard(info: info, rules: L10n.t("games.c4.setup.body"), starting: engine.busy, onStart: startGame) {
                EmptyView()
            }
        }
    }

    private func startGame() {
        guard !engine.busy else { return }
        Task {
            resetLocalState()
            if await engine.create(api: appState.api, type: .connectfour, payload: GameEngine.makePayload()) {
                SoundEngine.shared.play(.pop)
                Haptics.shared.tap()
            }
        }
    }

    private func resetLocalState() {
        sending = false
        didSendEnd = false
        celebrate = false
        lastCount = 0
    }

    // MARK: Play

    private var playScreen: some View {
        VStack(spacing: 14) {
            turnHeader
            boardView
            colorLegend
            if !myTurn {
                GameWaitingHint()
            }
        }
    }

    private var turnHeader: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(discColor(of: turnId))
                .frame(width: 20, height: 20)
            Text(myTurn
                 ? L10n.t("games.c4.yourTurn")
                 : L10n.t("games.c4.partnerTurn", ["name": appState.partnerName]))
                .font(.headline)
            Spacer(minLength: 0)
        }
        .cardSurface(padding: 14)
        .accessibilityElement(children: .combine)
    }

    /// The board is game content: a neutral inset surface with empty slots
    /// in the tertiary fill, discs in the members' colours.
    private var boardView: some View {
        let state = boardState
        return VStack(spacing: 6) {
            ForEach((0..<ConnectFour.rows).reversed(), id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<ConnectFour.columns, id: \.self) { column in
                        cell(state: state, column: column, row: row)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))
    }

    private func cell(state: ConnectFourState, column: Int, row: Int) -> some View {
        let owner = state.owner(column: column, row: row)
        let winning = state.winningCells.contains(ConnectFourCell(column: column, row: row))
        return Button {
            drop(column: column)
        } label: {
            Circle()
                .fill(owner.map(discColor(of:)) ?? Color.tertiaryCardBackground)
                .overlay {
                    if winning {
                        Circle().strokeBorder(Color.primary, lineWidth: 2.5)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .animation(.snappy, value: owner)
        }
        .buttonStyle(.plain)
        .disabled(!myTurn || sending || owner != nil)
        .accessibilityLabel(owner.map(name(of:)) ?? "\(column + 1)")
    }

    private var colorLegend: some View {
        HStack(spacing: 14) {
            legendEntry(memberId: appState.memberId ?? "", label: L10n.t("games.c4.discs"))
            Spacer()
            legendEntry(memberId: appState.partner?.id ?? "", label: appState.partnerName)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
    }

    private func legendEntry(memberId: String, label: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(discColor(of: memberId))
                .frame(width: 14, height: 14)
            Text(label)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Actions

    private func drop(column: Int) {
        guard myTurn, !sending, boardState.height(column) < ConnectFour.rows else { return }
        sending = true
        Task {
            let data = JSONValue.object([
                "kind": .string("drop"),
                "column": .number(Double(column))
            ])
            _ = await engine.sendMove(api: appState.api, data: data)
            sending = false
        }
    }

    private func handleFinish() {
        guard session != nil else { return }
        if !celebrate {
            celebrate = true
            let state = boardState
            if state.winner == appState.memberId {
                SoundEngine.shared.play(.win)
            } else if state.winner != nil {
                SoundEngine.shared.play(.lose)
            } else {
                SoundEngine.shared.play(.chime)
            }
            Haptics.shared.success()
        }
        guard let current = session, current.state == "active", !didSendEnd else { return }
        didSendEnd = true
        Task {
            await engine.end(api: appState.api, result: resultJSON)
        }
    }

    /// `{"scores": {winner: 1, loser: 0}}` — same shape as the quiz so the
    /// scoreboard (GamesRecordView) picks it up without special-casing.
    private var resultJSON: JSONValue {
        let state = boardState
        var scores: [String: JSONValue] = [:]
        for id in [starterId, otherId] where !id.isEmpty {
            scores[id] = .number(state.winner == id ? 1 : 0)
        }
        return .object(["scores": .object(scores)])
    }

    // MARK: End screen

    private var endScreen: some View {
        let state = boardState
        return VStack(spacing: 14) {
            GameResultCard(title: endLine(state: state), emoji: state.winner == nil ? "🤝" : "🏆") {
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
            boardView
        }
    }

    private func endLine(state: ConnectFourState) -> String {
        guard let winner = state.winner else { return L10n.t("games.c4.draw") }
        if winner == appState.memberId {
            return L10n.t("games.c4.win.you")
        }
        return L10n.t("games.c4.win.partner", ["name": name(of: winner)])
    }
}
