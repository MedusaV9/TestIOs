import SwiftUI

// MARK: - Duell-Bilanz — the couple's running Wordle duel record

/// Pushed from `WordleView`. Loads the duel history (per-member views, newest
/// first, anti-spoiler already applied server-side) and shows the W·U·N
/// record, an optional play-streak line and a day-by-day list with
/// expandable emoji grids (`DisclosureGroup`).
struct WordleRecordView: View {
    @Environment(AppState.self) private var appState

    @State private var days: [WordleDayResponse] = []
    @State private var loading = true
    @State private var expandedKeys: Set<String> = []

    private var lang: String { L10n.lang }

    private var myName: String { appState.me?.name ?? L10n.t("common.you") }

    var body: some View {
        List {
            if loading && days.isEmpty {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if days.isEmpty {
                ContentUnavailableView {
                    Label(L10n.t("games.wordle.record.emptyTitle"), systemImage: "textformat.abc")
                } description: {
                    Text(L10n.t("games.wordle.record.emptyBody"))
                }
                .listRowBackground(Color.clear)
            } else {
                recordSection
                Section {
                    ForEach(days, id: \.dateKey) { day in
                        dayRow(day)
                    }
                }
            }
        }
        .navigationTitle(L10n.t("games.wordle.record.title"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    // MARK: Loading

    private func load() async {
        guard let api = appState.api else {
            loading = false
            return
        }
        let requestedLang = lang
        if let response = try? await api.wordleHistory(limit: 30, lang: requestedLang) {
            days = response
                .filter { ($0.lang ?? requestedLang) == requestedLang }
                .sorted { $0.dateKey > $1.dateKey }
        }
        loading = false
    }

    // MARK: Record (only days where BOTH results are visible count)

    private var record: (mine: Int, ties: Int, partner: Int) {
        var mine = 0, ties = 0, partner = 0
        for day in days {
            guard let myResult = day.mine, let partnerResult = day.partner else { continue }
            switch WordleDaily.duelOutcome(mine: myResult, partner: partnerResult) {
            case .meWin: mine += 1
            case .partnerWin: partner += 1
            case .tie: ties += 1
            }
        }
        return (mine, ties, partner)
    }

    @ViewBuilder
    private var recordSection: some View {
        let record = record
        let total = record.mine + record.ties + record.partner
        Section {
            GameMemberScoreRow(member: appState.me, value: "\(record.mine)",
                               highlighted: record.mine > record.partner)
            GameMemberScoreRow(member: appState.partner, value: "\(record.partner)",
                               highlighted: record.partner > record.mine)
            LabeledContent(L10n.t("games.wordle.record.ties"), value: "\(record.ties)")
            if playStreak >= 2 {
                Label(L10n.t("games.wordle.record.streak", ["n": "\(playStreak)"]), systemImage: "flame.fill")
                    .foregroundStyle(Color.orange)
            }
        } footer: {
            if total > 0 {
                Text(leaderLine(record) + " · " + L10n.t("games.wordle.record.subtitle", ["n": "\(total)"]))
            }
        }
    }

    private func leaderLine(_ record: (mine: Int, ties: Int, partner: Int)) -> String {
        if record.mine > record.partner {
            return L10n.t("games.wordle.record.leaderMe")
        }
        if record.partner > record.mine {
            return L10n.t("games.wordle.record.leaderPartner", ["name": appState.partnerName])
        }
        return L10n.t("games.wordle.record.leaderTie")
    }

    // MARK: Streak (consecutive calendar days from the newest where I finished)

    private var playStreak: Int {
        let calendar = SharedDates.calendar
        let played = Set(days.filter { $0.mine != nil }.map { $0.dateKey })
        var expected = calendar.startOfDay(for: Date())
        // The streak is still alive when today isn't played yet but
        // yesterday is — start walking from yesterday in that case.
        if !played.contains(SharedDates.todayKey(expected)),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: expected) {
            expected = yesterday
        }
        var streak = 0
        while played.contains(SharedDates.todayKey(expected)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: expected) else {
                break
            }
            expected = previous
        }
        return streak
    }

    // MARK: Day list

    @ViewBuilder
    private func dayRow(_ day: WordleDayResponse) -> some View {
        if let mine = day.mine, let partner = day.partner {
            DisclosureGroup(isExpanded: Binding(
                get: { expandedKeys.contains(day.dateKey) },
                set: { open in
                    if open { expandedKeys.insert(day.dateKey) } else { expandedKeys.remove(day.dateKey) }
                }
            )) {
                HStack(alignment: .top, spacing: 14) {
                    gridColumn(name: myName, result: mine)
                    Divider()
                    gridColumn(name: appState.partnerName, result: partner)
                }
                .padding(.vertical, 6)
            } label: {
                dayHeader(day)
            }
        } else {
            dayHeader(day)
        }
    }

    private func dayHeader(_ day: WordleDayResponse) -> some View {
        HStack(spacing: 10) {
            Text(dayString(day.dateKey))
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
            scoreText(day.mine)
            Text(":")
                .font(.caption)
                .foregroundStyle(.secondary)
            scoreText(day.partner)
            outcomeIcon(day)
                .frame(width: 22)
        }
        .accessibilityElement(children: .combine)
    }

    private func scoreText(_ result: WordleResult?) -> some View {
        let text: String
        let color: Color
        if let result {
            text = result.win ? "\(result.rows)/6" : "✗"
            color = result.win ? Color.green : Color.secondary
        } else {
            text = "—"
            color = Color.secondary
        }
        return Text(text)
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(color)
            .frame(width: 34)
    }

    /// Trophy: I won · flag: partner won · heart: tie · eye: partner played
    /// but stays hidden because I didn't — blank when only my result exists.
    @ViewBuilder
    private func outcomeIcon(_ day: WordleDayResponse) -> some View {
        if let mine = day.mine, let partner = day.partner {
            switch WordleDaily.duelOutcome(mine: mine, partner: partner) {
            case .meWin:
                Image(systemName: "trophy.fill").foregroundStyle(Color.yellow)
            case .partnerWin:
                Image(systemName: "flag.fill").foregroundStyle(.secondary)
            case .tie:
                Image(systemName: "heart.fill").foregroundStyle(Color.accentColor)
            }
        } else if day.mine == nil && day.partnerFinished {
            Image(systemName: "eye").foregroundStyle(.secondary)
        } else {
            Color.clear
        }
    }

    private func gridColumn(name: String, result: WordleResult) -> some View {
        VStack(spacing: 6) {
            Text(name)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            VStack(spacing: 2) {
                ForEach(Array(result.grid.split(separator: "\n").enumerated()), id: \.offset) { _, line in
                    Text(String(line))
                        .font(.footnote)
                        .kerning(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func dayString(_ dateKey: String) -> String {
        guard let date = SharedDates.parse(dateKey) else { return dateKey }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
