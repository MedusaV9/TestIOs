import SwiftUI
import Combine

// Kniffel-Liebesedition — async-friendly seeded Yahtzee.
//
// The dice pips are a pure function of (seed, turn, roll) — see
// Content/KniffelLogic.swift — so a "roll" move carries only the held dice
// and both phones derive identical values. Turns alternate; each turn is up
// to 3 rolls plus one category pick on the love-styled scorecard.
struct KniffelView: View {
    @Environment(AppState.self) private var appState

    let engine: GameEngine

    @State private var heldDice: Set<Int> = []
    @State private var sending = false
    @State private var didSendEnd = false
    @State private var celebrated = false
    @State private var bounce = 0

    private var info: GameInfo? { GameCatalog.info(.kniffel) }
    private var accent: Color { info?.tint ?? .purple }

    var body: some View {
        ScrollView {
            content
                .padding(Brand.screenInset)
        }
        .groupedScreenBackground()
        .navigationTitle(L10n.t("games.card.kniffel.title"))
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
        .onChange(of: engine.session?.id) { _, _ in
            resetLocalState()
        }
        .onChange(of: gameState.rollCount) { old, new in
            if new > old {
                bounce += 1
                SoundEngine.shared.play(.pop)
                Haptics.shared.tap()
            }
            if new == 0 {
                heldDice = []
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
        guard let current = engine.session, current.kind == .kniffel else { return nil }
        return current
    }

    private var starterId: String { session?.createdBy ?? "" }

    private var otherId: String {
        appState.couple?.members.map(\.id).first { $0 != starterId } ?? ""
    }

    private var myId: String { appState.memberId ?? "" }

    private var theirId: String { myId == starterId ? otherId : starterId }

    private var events: [KniffelEvent] {
        engine.orderedMoves.compactMap { move in
            switch move.data["kind"]?.stringValue {
            case "roll":
                let held = move.data["held"]?.arrayValue?.compactMap(\.intValue) ?? []
                return .roll(member: move.memberId, held: held)
            case "score":
                guard let category = move.data["category"]?.stringValue else { return nil }
                return .score(member: move.memberId, category: category)
            default:
                return nil
            }
        }
    }

    private var gameState: KniffelState {
        Kniffel.reduce(events: events, seed: engine.seed, starter: starterId, partner: otherId)
    }

    private var currentPlayer: String {
        Kniffel.player(turn: gameState.turnIndex, starter: starterId, partner: otherId)
    }

    private var myTurn: Bool { currentPlayer == myId && !gameState.finished }

    private var finished: Bool {
        guard session?.state == "active" || session?.state == "ended" else { return false }
        return gameState.finished
    }

    private func name(of memberId: String) -> String {
        memberId == myId ? (appState.me?.name ?? L10n.t("common.you")) : appState.partnerName
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
            GameStartCard(info: info, rules: L10n.t("games.kn.setup.body"), starting: engine.busy, onStart: startGame) {
                EmptyView()
            }
        }
    }

    private func startGame() {
        guard !engine.busy else { return }
        Task {
            resetLocalState()
            if await engine.create(api: appState.api, type: .kniffel, payload: GameEngine.makePayload()) {
                SoundEngine.shared.play(.pop)
                Haptics.shared.tap()
            }
        }
    }

    private func resetLocalState() {
        heldDice = []
        sending = false
        didSendEnd = false
        celebrated = false
    }

    // MARK: Play

    private var playScreen: some View {
        VStack(spacing: 12) {
            GameHeaderBar(title: myTurn ? L10n.t("games.kn.yourTurn")
                                        : L10n.t("games.kn.partnerTurn", ["name": appState.partnerName]),
                          subtitle: L10n.t("games.kn.turnMeta",
                                           ["n": "\(gameState.turnIndex / 2 + 1)",
                                            "total": "\(Kniffel.turnsPerPlayer)",
                                            "rolls": "\(gameState.rollCount)",
                                            "max": "\(Kniffel.maxRolls)"]),
                          progress: Double(gameState.turnIndex) / Double(max(Kniffel.turnsPerPlayer * 2, 1)),
                          tint: accent)
            diceCard
            if !myTurn {
                GameWaitingHint()
            }
            scoreboard
        }
    }

    private var diceCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ForEach(0..<Kniffel.diceCount, id: \.self) { index in
                    dieView(index: index)
                }
            }
            if myTurn {
                if gameState.rollCount > 0 && gameState.rollCount < Kniffel.maxRolls {
                    Text(L10n.t("games.kn.holdHint"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if gameState.rollCount < Kniffel.maxRolls {
                    Button {
                        roll()
                    } label: {
                        Label(L10n.t("games.kn.roll", ["n": "\(gameState.rollCount + 1)", "max": "\(Kniffel.maxRolls)"]),
                              systemImage: "dice")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(sending)
                }
                if gameState.rollCount > 0 {
                    Text(L10n.t("games.kn.pickHint"))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(accent)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .cardSurface(padding: 16)
    }

    @ViewBuilder
    private func dieView(index: Int) -> some View {
        let rolled = gameState.dice.indices.contains(index)
        let value = rolled ? gameState.dice[index] : 0
        let held = heldDice.contains(index)
        let canHold = myTurn && gameState.rollCount > 0 && gameState.rollCount < Kniffel.maxRolls
        Button {
            guard canHold else { return }
            if held {
                heldDice.remove(index)
            } else {
                heldDice.insert(index)
            }
            Haptics.shared.tap()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(held ? accent.opacity(0.18) : Color.tertiaryCardBackground)
                    .overlay {
                        if held {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(accent, lineWidth: 2)
                        }
                    }
                if rolled {
                    Image(systemName: "die.face.\(value).fill")
                        .font(.system(size: 30))
                        .foregroundStyle(held ? accent : Color.primary)
                        .symbolEffect(.bounce, value: bounce)
                } else {
                    Image(systemName: "questionmark")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .rotation3DEffect(.degrees(held ? 0 : Double(bounce % 2) * 360), axis: (x: 0, y: 0, z: 1))
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: bounce)
        }
        .buttonStyle(.plain)
        .disabled(!canHold)
        .accessibilityLabel(rolled ? "\(value)" : "?")
        .accessibilityAddTraits(held ? .isSelected : [])
    }

    private func roll() {
        guard myTurn, !sending, gameState.rollCount < Kniffel.maxRolls else { return }
        sending = true
        let held = gameState.rollCount > 0 ? Array(heldDice).sorted() : []
        Task {
            let data = JSONValue.object([
                "kind": .string("roll"),
                "held": .array(held.map { .number(Double($0)) })
            ])
            _ = await engine.sendMove(api: appState.api, data: data)
            sending = false
        }
    }

    // MARK: Scoreboard

    private static let categoryEmoji: [KniffelCategory: String] = [
        .ones: "💌", .twos: "💐", .threes: "🥂", .fours: "🕯️", .fives: "💋", .sixes: "💍",
        .threeOfAKind: "🎯", .fourOfAKind: "🎪", .fullHouse: "🏡",
        .smallStraight: "🌈", .largeStraight: "🌠", .kniffel: "💘", .chance: "🎁",
    ]

    private var scoreboard: some View {
        let myCard = gameState.scorecard(of: myId)
        let theirCard = gameState.scorecard(of: theirId)
        return VStack(spacing: 0) {
            scoreboardHeader
            Divider()
            ForEach(KniffelCategory.allCases, id: \.rawValue) { category in
                categoryRow(category, myCard: myCard, theirCard: theirCard)
            }
            Divider()
            summaryRow(label: L10n.t("games.kn.bonusRow"), mine: bonusText(myCard), theirs: bonusText(theirCard))
            summaryRow(label: L10n.t("games.kn.totalRow"),
                       mine: "\(Kniffel.total(myCard))", theirs: "\(Kniffel.total(theirCard))", bold: true)
        }
        .padding(.vertical, 6)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))
    }

    private var scoreboardHeader: some View {
        HStack {
            Text(L10n.t("games.kn.categories"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(appState.me?.name ?? L10n.t("common.you"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 56, alignment: .trailing)
                .lineLimit(1)
            Text(appState.partnerName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func categoryRow(_ category: KniffelCategory,
                             myCard: [KniffelCategory: Int],
                             theirCard: [KniffelCategory: Int]) -> some View {
        let banked = myCard[category]
        let pickable = myTurn && gameState.rollCount > 0 && banked == nil
        let potential = pickable ? category.score(dice: gameState.dice) : nil
        Button {
            if pickable { score(category) }
        } label: {
            HStack {
                Text("\(Self.categoryEmoji[category] ?? "") \(L10n.t("games.kn.cat.\(category.rawValue)"))")
                    .font(.subheadline)
                    .foregroundStyle(pickable ? Color.primary : Color.secondary)
                    .lineLimit(1)
                Spacer()
                Group {
                    if let banked {
                        Text("\(banked)")
                            .foregroundStyle(Color.primary)
                    } else if let potential {
                        Text("+\(potential)")
                            .foregroundStyle(accent)
                    } else {
                        Text("–")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .frame(width: 56, alignment: .trailing)
                Text(theirCard[category].map { "\($0)" } ?? "–")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(theirCard[category] == nil ? Color.secondary : Color.primary)
                    .frame(width: 56, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(potential != nil ? accent.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!pickable || sending)
        .accessibilityElement(children: .combine)
    }

    private func summaryRow(label: String, mine: String, theirs: String, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.subheadline.weight(bold ? .semibold : .regular))
                .foregroundStyle(bold ? Color.primary : Color.secondary)
            Spacer()
            Text(mine)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.accentColor)
                .frame(width: 56, alignment: .trailing)
            Text(theirs)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private func bonusText(_ card: [KniffelCategory: Int]) -> String {
        let upper = Kniffel.upperSum(card)
        return upper >= Kniffel.upperBonusThreshold
            ? "+\(Kniffel.upperBonus)"
            : "\(upper)/\(Kniffel.upperBonusThreshold)"
    }

    private func score(_ category: KniffelCategory) {
        guard myTurn, !sending, gameState.rollCount > 0 else { return }
        sending = true
        Task {
            let data = JSONValue.object([
                "kind": .string("score"),
                "category": .string(category.rawValue)
            ])
            if await engine.sendMove(api: appState.api, data: data) {
                heldDice = []
                SoundEngine.shared.play(.success)
                Haptics.shared.success()
            }
            sending = false
        }
    }

    // MARK: Finish

    private func handleFinish() {
        guard session != nil else { return }
        let winner = Kniffel.winner(state: gameState, starter: starterId, partner: otherId)
        if !celebrated {
            celebrated = true
            if winner == myId {
                Delight.celebrate(.epic, theme: .confetti)
            } else if winner == nil {
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
                scores[id] = .number(Double(Kniffel.total(gameState.scorecard(of: id))))
            }
            await engine.end(api: appState.api, result: .object(["scores": .object(scores)]))
        }
    }

    private var endScreen: some View {
        let winner = Kniffel.winner(state: gameState, starter: starterId, partner: otherId)
        return VStack(spacing: 14) {
            GameResultCard(title: endLine(winner: winner), emoji: winner == myId ? "🏆" : (winner == nil ? "💞" : "🎲")) {
                GameFinalScore(myScore: Kniffel.total(gameState.scorecard(of: myId)),
                               partnerScore: Kniffel.total(gameState.scorecard(of: theirId)))
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
            scoreboard
        }
    }

    private func endLine(winner: String?) -> String {
        guard let winner else { return L10n.t("games.kn.tie") }
        if winner == myId { return L10n.t("games.kn.win.you") }
        return L10n.t("games.kn.win.partner", ["name": name(of: winner)])
    }
}
