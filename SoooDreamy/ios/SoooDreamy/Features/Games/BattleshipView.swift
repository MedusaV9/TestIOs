import SwiftUI
import Combine

// Schiffe versenken — commit-reveal battleship over the game relay.
//
// Flow: both partners lock a hidden fleet in (`commit` = SHA-256 of
// layout+salt, see Core/CommitReveal.swift), then fire alternating 2-shot
// salvos. The DEFENDER's device answers every salvo truthfully from its
// local board (`report`), and after the win both boards are opened
// (`reveal`) — the relay certifies the hash and `Battleship.honest` replays
// all reports, so cheating is provably visible. Reducer:
// Content/BattleshipLogic.swift (pinned by Linux logic tests).

// MARK: - Fleet vault

/// The own layout + salt are the commit-reveal SECRET: they must survive app
/// restarts (reporting and revealing need them) and must never leave the
/// device before the reveal. Persisted per gameId.
enum BattleshipVault {
    private static func key(_ gameId: String) -> String { "battleship.secret.\(gameId)" }

    static func save(gameId: String, layout: String, salt: String) {
        UserDefaults.standard.set("\(salt)#\(layout)", forKey: key(gameId))
    }

    static func load(gameId: String) -> (layout: String, salt: String)? {
        guard let raw = UserDefaults.standard.string(forKey: key(gameId)),
              let separator = raw.firstIndex(of: "#") else { return nil }
        return (String(raw[raw.index(after: separator)...]), String(raw[..<separator]))
    }
}

// MARK: - View

struct BattleshipView: View {
    @Environment(AppState.self) private var appState

    let engine: GameEngine

    @State private var placementSeed = Int.random(in: 1...999_999_999)
    @State private var targetCells: [Int] = []
    @State private var sending = false
    @State private var didSendEnd = false
    @State private var didReveal = false
    @State private var celebrated = false
    @State private var sentReports: Set<Int> = []
    @State private var shared = false

    private var info: GameInfo? { GameCatalog.info(.battleship) }
    private var accent: Color { info?.tint ?? .blue }

    var body: some View {
        ScrollView {
            content
                .padding(Brand.screenInset)
        }
        .groupedScreenBackground()
        .navigationTitle(L10n.t("games.card.battleship.title"))
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
            autoRespond()
        }
        .onChange(of: engine.session?.id) { _, _ in
            resetLocalState()
            autoRespond()
        }
        .onChange(of: gameState.salvos.count) { old, new in
            if new > old {
                SoundEngine.shared.play(.pop)
                Haptics.shared.tap()
            }
            autoRespond()
        }
        .onChange(of: gameState.reports.count) { _, _ in
            autoRespond()
        }
        .onChange(of: gameState.committed.count) { _, _ in
            autoRespond()
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
        guard let current = engine.session, current.kind == .battleship else { return nil }
        return current
    }

    private var starterId: String { session?.createdBy ?? "" }

    private var otherId: String {
        appState.couple?.members.map(\.id).first { $0 != starterId } ?? ""
    }

    private var myId: String { appState.memberId ?? "" }

    private var partnerId: String { appState.partner?.id ?? "" }

    /// Relay moves → typed reducer events (unknown shapes are dropped).
    private var events: [BattleshipEvent] {
        engine.orderedMoves.compactMap { move in
            switch move.data["kind"]?.stringValue {
            case "commit":
                guard move.data["commit"]?.stringValue != nil else { return nil }
                return .commit(member: move.memberId)
            case "salvo":
                guard let cells = move.data["cells"]?.arrayValue?.compactMap(\.intValue) else { return nil }
                return .salvo(member: move.memberId, cells: cells)
            case "report":
                guard let index = move.data["index"]?.intValue else { return nil }
                return .report(member: move.memberId, index: index,
                               hits: move.data["hits"]?.arrayValue?.compactMap(\.intValue) ?? [],
                               sunk: move.data["sunk"]?.arrayValue?.compactMap(\.intValue) ?? [])
            case "reveal":
                guard let layout = move.data["reveal"]?.stringValue,
                      let salt = move.data["salt"]?.stringValue else { return nil }
                return .reveal(member: move.memberId, layout: layout, salt: salt,
                               serverVerified: move.data["verified"]?.boolValue ?? false)
            default:
                return nil
            }
        }
    }

    private var gameState: BattleshipState {
        Battleship.reduce(events: events, starter: starterId, partner: otherId)
    }

    private var myTurn: Bool {
        Battleship.turn(state: gameState, starter: starterId, partner: otherId) == myId
    }

    private var finished: Bool {
        guard session?.state == "active" || session?.state == "ended" else { return false }
        return gameState.phase == .finished
    }

    private var myFleet: [[Int]]? {
        guard let id = session?.id, let secret = BattleshipVault.load(gameId: id) else { return nil }
        return Battleship.decodeLayout(secret.layout)
    }

    private var iWon: Bool { gameState.winner == myId }

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
                if gameState.phase == .setup {
                    placementScreen
                } else {
                    battleScreen
                }
            } else {
                startScreen
            }
        } else {
            startScreen
        }
    }

    // MARK: Start

    @ViewBuilder
    private var startScreen: some View {
        if let info {
            GameStartCard(info: info, rules: L10n.t("games.bs.setup.body"), starting: engine.busy, onStart: startGame) {
                EmptyView()
            }
        }
    }

    private func startGame() {
        guard !engine.busy else { return }
        Task {
            resetLocalState()
            if await engine.create(api: appState.api, type: .battleship, payload: GameEngine.makePayload()) {
                SoundEngine.shared.play(.pop)
                Haptics.shared.tap()
            }
        }
    }

    private func resetLocalState() {
        placementSeed = Int.random(in: 1...999_999_999)
        targetCells = []
        sending = false
        didSendEnd = false
        didReveal = false
        celebrated = false
        sentReports = []
        shared = false
    }

    // MARK: Placement (commit phase)

    @ViewBuilder
    private var placementScreen: some View {
        if gameState.committed.contains(myId) {
            committedCard
        } else {
            placementCard
        }
    }

    private var placementCard: some View {
        let ships = Battleship.randomLayout(seed: placementSeed)
        return VStack(spacing: 14) {
            Text(L10n.t("games.bs.place.title"))
                .font(.title3.weight(.semibold))
            Text(L10n.t("games.bs.place.body"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            boardGrid(shipCells: Set(ships.flatMap { $0 }), marks: [:], tappable: false)
            HStack(spacing: 12) {
                Button {
                    placementSeed = Int.random(in: 1...999_999_999)
                    SoundEngine.shared.play(.pop)
                    Haptics.shared.tap()
                } label: {
                    Label(L10n.t("games.bs.shuffle"), systemImage: "shuffle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                Button {
                    commitFleet(ships)
                } label: {
                    Label(L10n.t("games.bs.ready"), systemImage: "lock.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .disabled(sending)
            }
            .controlSize(.large)
            Text(L10n.t("games.bs.commit.sealed"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .cardSurface(padding: 16)
    }

    private var committedCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundStyle(accent)
            Text(L10n.t("games.bs.commit.done", ["name": appState.partnerName]))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let fleet = myFleet {
                boardGrid(shipCells: Set(fleet.flatMap { $0 }), marks: [:], tappable: false)
            }
            ProgressView()
        }
        .frame(maxWidth: .infinity)
        .cardSurface(padding: 16)
    }

    private func commitFleet(_ ships: [[Int]]) {
        guard let id = session?.id, !sending else { return }
        sending = true
        let layout = Battleship.encodeLayout(ships)
        let salt = CommitReveal.newSalt()
        BattleshipVault.save(gameId: id, layout: layout, salt: salt)
        Task {
            let data = JSONValue.object([
                "kind": .string("commit"),
                "commit": .string(CommitReveal.commit(secret: layout, salt: salt))
            ])
            if await engine.sendMove(api: appState.api, data: data) {
                SoundEngine.shared.play(.chime)
                Haptics.shared.success()
            }
            sending = false
        }
    }

    // MARK: Battle

    private var battleScreen: some View {
        VStack(spacing: 14) {
            GameHeaderBar(title: myTurn ? L10n.t("games.bs.yourTurn")
                                        : L10n.t("games.bs.partnerTurn", ["name": appState.partnerName]),
                          subtitle: L10n.t("games.bs.hits", ["n": "\(gameState.hitCount(by: myId))",
                                                             "total": "\(Battleship.fleetCellCount)"]),
                          progress: Double(gameState.hitCount(by: myId)) / Double(max(Battleship.fleetCellCount, 1)),
                          tint: accent)
            enemyWatersCard
            if myTurn {
                fireButton
            } else {
                GameWaitingHint()
            }
            myBoardCard
            if myFleet == nil {
                boardLostCard
            }
        }
    }

    private var enemyWatersCard: some View {
        let results = gameState.shotResults(by: myId)
        return VStack(spacing: 10) {
            HStack {
                Text(L10n.t("games.bs.enemy", ["name": appState.partnerName]))
                    .font(.headline)
                Spacer()
                fleetChips(sunk: gameState.sunkSizes(by: myId))
            }
            boardGrid(shipCells: [], marks: marks(from: results), tappable: myTurn && !sending)
            if myTurn {
                Text(L10n.t("games.bs.target.hint", ["n": "\(salvoTarget)"]))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .cardSurface(padding: 14)
    }

    /// Shots this salvo may fire (fewer only when the board is nearly full).
    private var salvoTarget: Int {
        let unshot = Battleship.cellCount - gameState.shotCells(by: myId).count
        return min(Battleship.salvoSize, max(unshot, 0))
    }

    private var fireButton: some View {
        Button {
            fireSalvo()
        } label: {
            Label(L10n.t("games.bs.fire", ["n": "\(targetCells.count)", "total": "\(salvoTarget)"]),
                  systemImage: "scope")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .disabled(targetCells.count != salvoTarget || sending)
    }

    private var myBoardCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text(L10n.t("games.bs.mine"))
                    .font(.headline)
                Spacer()
                fleetChips(sunk: gameState.sunkSizes(by: partnerId))
            }
            boardGrid(shipCells: Set((myFleet ?? []).flatMap { $0 }),
                      marks: marks(from: gameState.shotResults(by: partnerId)),
                      tappable: false, compact: true)
        }
        .cardSurface(padding: 14)
    }

    private var boardLostCard: some View {
        VStack(spacing: 10) {
            Label(L10n.t("games.bs.lost.title"), systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.orange)
            Text(L10n.t("games.bs.lost.body"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(role: .destructive) {
                Task { await engine.end(api: appState.api, result: nil) }
            } label: {
                Text(L10n.t("games.bs.lost.abandon"))
            }
            .buttonStyle(.bordered)
            .disabled(engine.busy)
        }
        .frame(maxWidth: .infinity)
        .cardSurface(padding: 14)
    }

    /// Sizes of the fleet, greyed + struck through once sunk.
    private func fleetChips(sunk: [Int]) -> some View {
        var remaining = sunk
        let chips: [(length: Int, isSunk: Bool)] = Battleship.fleet.map { length in
            if let at = remaining.firstIndex(of: length) {
                remaining.remove(at: at)
                return (length, true)
            }
            return (length, false)
        }
        return HStack(spacing: 5) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                Text("\(chip.length)")
                    .font(.caption2.weight(.semibold))
                    .strikethrough(chip.isSunk)
                    .foregroundStyle(chip.isSunk ? Color.secondary : accent)
                    .frame(width: 20, height: 20)
                    .background(chip.isSunk ? Color.tertiaryCardBackground : accent.opacity(0.16), in: Circle())
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Grid rendering

    private enum CellMark {
        case hit, miss, pending
    }

    private func marks(from results: [Int: Bool?]) -> [Int: CellMark] {
        var marks: [Int: CellMark] = [:]
        for (cell, hit) in results {
            switch hit {
            case .some(true): marks[cell] = .hit
            case .some(false): marks[cell] = .miss
            case .none: marks[cell] = .pending
            }
        }
        return marks
    }

    /// The sea — game content: tinted water, ship cells in the game tint,
    /// hits in the accent colour.
    private func boardGrid(shipCells: Set<Int>, marks: [Int: CellMark],
                           tappable: Bool, compact: Bool = false) -> some View {
        VStack(spacing: compact ? 3 : 4) {
            ForEach(0..<Battleship.size, id: \.self) { row in
                HStack(spacing: compact ? 3 : 4) {
                    ForEach(0..<Battleship.size, id: \.self) { column in
                        cellView(cell: row * Battleship.size + column,
                                 isShip: shipCells.contains(row * Battleship.size + column),
                                 mark: marks[row * Battleship.size + column],
                                 tappable: tappable)
                    }
                }
            }
        }
        .padding(compact ? 6 : 8)
        .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: Brand.tileRadius, style: .continuous))
    }

    @ViewBuilder
    private func cellView(cell: Int, isShip: Bool, mark: CellMark?, tappable: Bool) -> some View {
        let selected = targetCells.contains(cell)
        Button {
            toggleTarget(cell)
        } label: {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(cellFill(isShip: isShip, mark: mark, selected: selected))
                .overlay {
                    if selected {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Color.orange, lineWidth: 2)
                    }
                }
                .overlay(cellGlyph(isShip: isShip, mark: mark, selected: selected))
                .aspectRatio(1, contentMode: .fit)
                .animation(.snappy, value: mark != nil)
        }
        .buttonStyle(.plain)
        .disabled(!tappable || mark != nil)
        .accessibilityLabel("\(cell % Battleship.size + 1), \(cell / Battleship.size + 1)")
    }

    private func cellFill(isShip: Bool, mark: CellMark?, selected: Bool) -> Color {
        switch mark {
        case .hit: return Color.accentColor
        case .miss: return Color.secondary.opacity(0.25)
        case .pending: return Color.orange.opacity(0.35)
        case nil:
            if selected { return Color.orange.opacity(0.35) }
            return isShip ? accent.opacity(0.55) : Color.tertiaryCardBackground
        }
    }

    @ViewBuilder
    private func cellGlyph(isShip: Bool, mark: CellMark?, selected: Bool) -> some View {
        switch mark {
        case .hit:
            Image(systemName: "flame.fill").font(.caption2).foregroundStyle(.white)
        case .miss:
            Circle().fill(Color.secondary).frame(width: 5, height: 5)
        case .pending:
            Image(systemName: "scope").font(.caption2).foregroundStyle(Color.orange)
        case nil:
            if selected {
                Image(systemName: "scope").font(.caption2).foregroundStyle(Color.orange)
            } else if isShip {
                Image(systemName: "ferry.fill").font(.caption2).foregroundStyle(.white)
            }
        }
    }

    // MARK: Actions

    private func toggleTarget(_ cell: Int) {
        guard myTurn, !sending else { return }
        if let at = targetCells.firstIndex(of: cell) {
            targetCells.remove(at: at)
        } else if targetCells.count < salvoTarget {
            targetCells.append(cell)
            Haptics.shared.tap()
        }
    }

    private func fireSalvo() {
        guard myTurn, !sending, targetCells.count == salvoTarget, !targetCells.isEmpty else { return }
        sending = true
        let cells = targetCells
        Task {
            let data = JSONValue.object([
                "kind": .string("salvo"),
                "cells": .array(cells.map { .number(Double($0)) })
            ])
            if await engine.sendMove(api: appState.api, data: data) {
                targetCells = []
                SoundEngine.shared.play(.whoosh)
            }
            sending = false
        }
    }

    /// The defender side runs itself: answer the partner's newest salvo
    /// truthfully from the local fleet, and open the board once the game is
    /// decided. Both are idempotent (reducer keeps the FIRST report/reveal).
    private func autoRespond() {
        guard let session, session.state == "active" || session.state == "ended" else { return }
        let state = gameState
        // 1. Pending report on me?
        if session.state == "active",
           let index = state.pendingReportIndex(defender: myId),
           !sentReports.contains(index),
           let fleet = myFleet {
            sentReports.insert(index)
            let alreadyHit = Set(state.shotResults(by: partnerId).filter { $0.value == true }.map(\.key))
            let salvo = state.salvos[index]
            let answer = Battleship.report(cells: salvo.cells, layout: fleet, alreadyHit: alreadyHit)
            Task {
                let data = JSONValue.object([
                    "kind": .string("report"),
                    "index": .number(Double(index)),
                    "hits": .array(answer.hits.map { .number(Double($0)) }),
                    "sunk": .array(answer.sunk.map { .number(Double($0)) })
                ])
                _ = await engine.sendMove(api: appState.api, data: data)
                if !answer.sunk.isEmpty {
                    SoundEngine.shared.play(.lose)
                    Haptics.shared.warning()
                } else if !answer.hits.isEmpty {
                    Haptics.shared.tap()
                }
            }
        }
        // 2. Game decided → open my board (commit-reveal proof).
        if state.phase == .finished, !didReveal, state.reveals[myId] == nil,
           let secret = BattleshipVault.load(gameId: session.id) {
            didReveal = true
            let commitId = engine.orderedMoves.first {
                $0.memberId == myId && $0.data["commit"]?.stringValue != nil
            }?.id
            Task {
                var object: [String: JSONValue] = [
                    "kind": .string("reveal"),
                    "reveal": .string(secret.layout),
                    "salt": .string(secret.salt)
                ]
                if let commitId {
                    object["commitId"] = .string(commitId)
                }
                _ = await engine.sendMove(api: appState.api, data: .object(object))
            }
        }
    }

    private func handleFinish() {
        guard session != nil else { return }
        autoRespond()
        if !celebrated {
            celebrated = true
            if iWon {
                Delight.celebrate(.epic, theme: .stars)
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
                scores[id] = .number(gameState.winner == id ? 1 : 0)
            }
            await engine.end(api: appState.api, result: .object(["scores": .object(scores)]))
        }
    }

    // MARK: End screen

    private var endScreen: some View {
        let results = gameState.shotResults(by: myId)
        return VStack(spacing: 14) {
            GameResultCard(title: iWon ? L10n.t("games.bs.win.you")
                                       : L10n.t("games.bs.win.partner", ["name": appState.partnerName]),
                           emoji: iWon ? "🏆" : "💔") {
                fairPlayBadge
                if appState.api != nil {
                    GameShareButton(sharing: false, shared: shared) { shareToChat(results: results) }
                }
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
            enemyWatersCard
            myBoardCard
        }
    }

    /// Post-game verdict of the partner's reveal: relay hash certification +
    /// local hash check + legal layout + truthful reports.
    private var fairPlayBadge: some View {
        let verdict = fairPlayVerdict
        return Label(verdict.text, systemImage: verdict.systemImage)
            .font(.footnote.weight(.medium))
            .foregroundStyle(verdict.tint)
            .multilineTextAlignment(.leading)
    }

    private var fairPlayVerdict: (systemImage: String, tint: Color, text: String) {
        guard let reveal = gameState.reveals[partnerId] else {
            return ("hourglass", .secondary, L10n.t("games.bs.fair.wait", ["name": appState.partnerName]))
        }
        let commit = engine.orderedMoves.first {
            $0.memberId == partnerId && $0.data["commit"]?.stringValue != nil
        }?.data["commit"]?.stringValue
        let hashOk = reveal.serverVerified
            || commit.map { CommitReveal.verify(reveal: reveal.layout, salt: reveal.salt, commit: $0) } == true
        let layout = Battleship.decodeLayout(reveal.layout)
        let legal = layout.map(Battleship.isValidLayout) == true
        let honest = layout.map { Battleship.honest(state: gameState, defender: partnerId, layout: $0) } == true
        if hashOk && legal && honest {
            return ("checkmark.shield.fill", .green, L10n.t("games.bs.fair.ok"))
        }
        return ("exclamationmark.shield.fill", .orange, L10n.t("games.bs.fair.bad", ["name": appState.partnerName]))
    }

    // MARK: Share to chat

    private func shareToChat(results: [Int: Bool?]) {
        guard let api = appState.api, !shared else { return }
        let winnerName = iWon ? (appState.me?.name ?? L10n.t("common.you")) : appState.partnerName
        let salvoCount = gameState.salvos.filter { $0.member == gameState.winner }.count
        let text = L10n.t("games.bs.share.line", ["name": winnerName, "n": "\(salvoCount)"])
            + "\n" + Battleship.shareGrid(results: results)
        Task {
            do {
                _ = try await api.sendMessage(type: .text, text: text)
                shared = true
                SoundEngine.shared.play(.chime)
                Haptics.shared.success()
            } catch {
                appState.handleAPIError(error)
            }
        }
    }
}
