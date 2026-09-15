import SwiftUI
import Combine

// Paar-Tagesquests — three small couple missions per day, deterministic
// from coupleId + dateKey. Shared checkboxes (first tap wins) on one relay
// session per day; every check emits a `quest_done` app event (XP hook for
// the platform layer) and full days feed the streak.
// Reducer: Content/DailyQuestsLogic.swift. Rendered as a Reminders-style
// checklist.
struct DailyQuestsView: View {
    @Environment(AppState.self) private var appState

    let engine: GameEngine

    @State private var completedDays: Set<String> = []
    @State private var sendingIndex: Int?
    @State private var didSendEnd = false
    @State private var celebrated = false
    @State private var preparing = false

    var body: some View {
        List {
            if appState.partner == nil {
                GameNeedsPartnerView()
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(L10n.t("games.dq.header"))
                                .font(.headline)
                            Spacer()
                            Label(L10n.t("games.dq.streak", ["n": "\(streak)"]), systemImage: "flame.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.orange)
                        }
                        ProgressView(value: Double(questState.doneCount), total: Double(max(questIndexes.count, 1)))
                            .tint(Color.orange)
                        Text(L10n.t("games.dq.progress", ["n": "\(questState.doneCount)", "total": "\(questIndexes.count)"]))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                if session == nil {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(Array(zip(questIndexes, quests)), id: \.0) { index, quest in
                            questRow(index: index, quest: quest)
                        }
                    } footer: {
                        if !dayComplete {
                            Text(L10n.t("games.dq.hint"))
                        }
                    }

                    if dayComplete {
                        Section {
                            VStack(spacing: 8) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(Color.orange.gradient)
                                Text(L10n.t("games.dq.complete"))
                                    .font(.title3.weight(.semibold))
                                    .multilineTextAlignment(.center)
                                Text(L10n.t("games.dq.complete.streak", ["n": "\(streak)"]))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .listRowBackground(Color.clear)
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.t("games.card.dailyquests.title"))
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
            await ensureTodaySession()
            await loadStreak()
        }
        .onChange(of: questState.doneCount) { _, _ in
            handleProgress()
        }
        .onAppear {
            handleProgress()
        }
    }

    // MARK: Derived state

    private var today: String { SharedDates.todayKey() }

    private var coupleId: String { appState.couple?.id ?? "" }

    /// Today's relay session — sessions of other days are treated as absent.
    private var session: GameSession? {
        guard let current = engine.session, current.kind == .dailyquests,
              current.payload?["dateKey"]?.stringValue == today else { return nil }
        return current
    }

    private var myId: String { appState.memberId ?? "" }

    private var questIndexes: [Int] {
        DailyQuests.questIndexes(coupleId: coupleId, dateKey: today)
    }

    private var quests: [DailyQuestItem] {
        DailyQuests.quests(coupleId: coupleId, dateKey: today)
    }

    private var events: [DailyQuestsEvent] {
        engine.orderedMoves.compactMap { move in
            guard move.data["kind"]?.stringValue == "quest_done",
                  let index = move.data["questIndex"]?.intValue else { return nil }
            return .done(member: move.memberId, questIndex: index)
        }
    }

    private var questState: DailyQuestsState {
        guard session != nil else { return DailyQuestsState(doneBy: [:]) }
        return DailyQuests.reduce(events: events, validIndexes: questIndexes)
    }

    private var dayComplete: Bool {
        questState.doneCount >= questIndexes.count && !questIndexes.isEmpty
    }

    private var streak: Int {
        var days = completedDays
        if dayComplete {
            days.insert(today)
        }
        return DailyQuests.streak(completedDays: days, today: today)
    }

    // MARK: Rows

    private func questRow(index: Int, quest: DailyQuestItem) -> some View {
        let checkedBy = questState.doneBy[index]
        return Button {
            check(index: index)
        } label: {
            HStack(spacing: 12) {
                if sendingIndex == index {
                    ProgressView()
                        .frame(width: 24)
                } else {
                    Image(systemName: checkedBy != nil ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(checkedBy != nil ? Color.accentColor : Color.secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                Text(quest.emoji)
                    .font(.title2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(quest.text.resolved(L10n.lang))
                        .font(.body)
                        .foregroundStyle(checkedBy != nil ? Color.secondary : Color.primary)
                        .strikethrough(checkedBy != nil, color: .secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let checkedBy {
                        Text(L10n.t("games.dq.checkedBy", ["name": memberName(checkedBy)]))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .disabled(checkedBy != nil || sendingIndex != nil || session?.state != "active")
    }

    private func memberName(_ id: String) -> String {
        if id == myId {
            return appState.me?.name ?? L10n.t("common.you")
        }
        return appState.couple?.members.first { $0.id == id }?.name ?? appState.partnerName
    }

    // MARK: Session lifecycle (auto — quests have no lobby ceremony)

    /// Finds or creates today's session and activates it. Anyone may
    /// activate (`join`) — a checklist has no turn order to protect.
    private func ensureTodaySession() async {
        guard appState.partner != nil, !preparing else { return }
        preparing = true
        defer { preparing = false }
        if engine.session == nil {
            await engine.resume(api: appState.api)
        }
        if let current = engine.session, current.kind == .dailyquests,
           current.state != "ended",
           current.payload?["dateKey"]?.stringValue == today {
            if current.state == "lobby" {
                await engine.join(api: appState.api)
            }
            return
        }
        // No usable session (yesterday's or none) → today's replaces it
        // (the relay auto-ends the previous dailyquests session).
        if await engine.create(api: appState.api, type: .dailyquests, payload: .object([
            "dateKey": .string(today)
        ])) {
            await engine.join(api: appState.api)
        }
    }

    private func check(index: Int) {
        guard sendingIndex == nil, questState.doneBy[index] == nil,
              session?.state == "active" else { return }
        sendingIndex = index
        SoundEngine.shared.play(.pop)
        Haptics.shared.tap()
        Task {
            _ = await engine.sendMove(api: appState.api, data: .object([
                "kind": .string("quest_done"),
                "questIndex": .number(Double(index))
            ]))
            sendingIndex = nil
        }
    }

    /// All three done → celebrate once and close the day's session with a
    /// result summary (streak sources read it from the history).
    private func handleProgress() {
        guard dayComplete, session != nil else { return }
        if !celebrated {
            celebrated = true
            Delight.celebrate(.epic, theme: .stars)
        }
        guard let current = session, current.state == "active", !didSendEnd else { return }
        didSendEnd = true
        Task {
            await engine.end(api: appState.api, result: .object([
                "done": .number(Double(questState.doneCount)),
                "total": .number(Double(questIndexes.count)),
                "dateKey": .string(today)
            ]))
        }
    }

    // MARK: Streak history

    /// Rebuilds the completed-days set from the session history — a day
    /// counts when all of its quests were checked (result or move count).
    private func loadStreak() async {
        guard let api = appState.api, !coupleId.isEmpty else { return }
        guard let history = try? await api.games(limit: 100) else { return }
        var completed: Set<String> = []
        for game in history where game.kind == .dailyquests {
            guard let dateKey = game.payload?["dateKey"]?.stringValue else { continue }
            let valid = DailyQuests.questIndexes(coupleId: coupleId, dateKey: dateKey)
            let done = Set(game.moves.compactMap { move -> Int? in
                guard move.data["kind"]?.stringValue == "quest_done",
                      let index = move.data["questIndex"]?.intValue,
                      valid.contains(index) else { return nil }
                return index
            })
            if done.count >= valid.count, !valid.isEmpty {
                completed.insert(dateKey)
            }
        }
        completedDays = completed
    }
}
