import Charts
import SwiftUI

/// Love statistics — six numbers, sent-vs-received touches and the last
/// week as Swift Charts, plus the mood timeline. Health-app style list.
struct LoveStatsView: View {
    @Environment(AppState.self) private var appState

    @State private var moods: [MoodEntry] = []
    @State private var touches: [Touch] = []
    @State private var sharingMoods = false
    @State private var sharedMoods = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private struct MoodDay: Identifiable {
        let id: String
        let date: Date
        let entries: [MoodEntry]
    }

    private struct MoodCount: Identifiable {
        let mood: String
        let count: Int
        var id: String { mood }
    }

    /// One bar of the touch comparison / weekly chart.
    private struct TouchBar: Identifiable {
        let id: String
        let category: String
        let who: String
        let count: Int
    }

    private var meLabel: String { L10n.t("common.you") }
    private var partnerLabel: String {
        appState.partnerName == meLabel ? appState.partnerName + " " : appState.partnerName
    }
    private var myColor: Color { Color(hex: appState.me?.color ?? "FF5C8A") }
    private var partnerColor: Color { Color(hex: appState.partner?.color ?? "A855F7") }

    var body: some View {
        List {
            if let stats = appState.stats {
                Section {
                    heroTiles(stats)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    touchChart(stats)
                } header: {
                    Text(L10n.t("memories.stats.touchTitle"))
                } footer: {
                    Text(L10n.t("memories.stats.touchSubtitle"))
                }

                Section {
                    weeklyChart
                } header: {
                    Text(L10n.t("memories.stats.weekTitle"))
                } footer: {
                    Text(L10n.t("memories.stats.weekSubtitle"))
                }

                moodSections

                Section {
                    caption(stats)
                        .listRowBackground(Color.clear)
                }
            } else {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(L10n.t("memories.stats.title"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await reload() }
        .task { await reload() }
    }

    private func reload() async {
        await appState.refreshStats()
        await loadMoods()
        await loadTouches()
    }

    // MARK: Hero tiles

    private func heroTiles(_ stats: Stats) -> some View {
        LazyVGrid(columns: columns, spacing: 12) {
            StatTile(systemImage: "heart.fill",
                     value: String(stats.daysTogether ?? appState.daysTogether ?? 0),
                     label: L10n.t("memories.stats.daysTogether"), tint: .accentColor)
            StatTile(systemImage: "flame.fill", value: String(stats.dailyStreak),
                     label: L10n.t("memories.stats.streak"), tint: .orange)
            StatTile(systemImage: "bubble.left.and.bubble.right.fill", value: String(stats.messages),
                     label: L10n.t("memories.stats.messages"), tint: .blue)
            StatTile(systemImage: "photo.fill", value: String(stats.photos),
                     label: L10n.t("memories.stats.photos"), tint: .purple)
            StatTile(systemImage: "gamecontroller.fill", value: String(stats.gamesPlayed),
                     label: L10n.t("memories.stats.games"), tint: .indigo)
            StatTile(systemImage: "sparkles", value: "\(stats.bucketDone)/\(stats.bucketTotal)",
                     label: L10n.t("memories.stats.bucket"), tint: .mint)
        }
    }

    // MARK: Touch comparison chart

    private func touchBars(_ stats: Stats) -> [TouchBar] {
        TouchKind.allCases.flatMap { kind -> [TouchBar] in
            let title = "\(kind.emoji) \(L10n.t(kind.titleKey))"
            return [
                TouchBar(id: "\(kind.rawValue)-me", category: title, who: meLabel,
                         count: stats.touchesSent.byType[kind.rawValue] ?? 0),
                TouchBar(id: "\(kind.rawValue)-partner", category: title, who: partnerLabel,
                         count: stats.touchesReceived.byType[kind.rawValue] ?? 0)
            ]
        }
    }

    @ViewBuilder
    private func touchChart(_ stats: Stats) -> some View {
        let bars = touchBars(stats)
        if bars.allSatisfy({ $0.count == 0 }) {
            ContentUnavailableView {
                Label(L10n.t("memories.stats.emptyTitle"), systemImage: "hand.tap")
            } description: {
                Text(L10n.t("memories.stats.empty"))
            }
        } else {
            Chart(bars) { bar in
                BarMark(x: .value(L10n.t("memories.stats.touchTitle"), bar.count),
                        y: .value(L10n.t("memories.stats.touchTitle"), bar.category))
                    .foregroundStyle(by: .value(L10n.t("common.partner"), bar.who))
                    .position(by: .value(L10n.t("common.partner"), bar.who))
                    .cornerRadius(3)
            }
            .chartForegroundStyleScale([meLabel: myColor, partnerLabel: partnerColor])
            .chartLegend(position: .bottom, alignment: .leading)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4))
            }
            .frame(height: CGFloat(TouchKind.allCases.count) * 44 + 40)
            .padding(.vertical, 8)
            .accessibilityLabel(L10n.t("memories.stats.touchTitle"))
        }
    }

    // MARK: Weekly chart

    private struct WeekDay: Identifiable {
        let id: String
        let date: Date
        let mine: Int
        let partners: Int
        var total: Int { mine + partners }
    }

    /// Last 7 calendar days (oldest → today), touches split by sender.
    private var weekDays: [WeekDay] {
        let calendar = SharedDates.calendar
        let today = calendar.startOfDay(for: Date())
        let myId = appState.me?.id
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let dayTouches = touches.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }
            let mine = dayTouches.filter { $0.senderId == myId }.count
            return WeekDay(id: SharedDates.todayKey(day), date: day,
                           mine: mine, partners: dayTouches.count - mine)
        }
    }

    private var weekBars: [TouchBar] {
        weekDays.flatMap { day -> [TouchBar] in
            let label = weekdayLetter(day.date)
            return [
                TouchBar(id: "\(day.id)-me", category: label, who: meLabel, count: day.mine),
                TouchBar(id: "\(day.id)-partner", category: label, who: partnerLabel, count: day.partners)
            ]
        }
    }

    @ViewBuilder
    private var weeklyChart: some View {
        let bars = weekBars
        if bars.allSatisfy({ $0.count == 0 }) {
            Text(L10n.t("memories.stats.weekEmpty"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
        } else {
            Chart(bars) { bar in
                BarMark(x: .value(L10n.t("common.day"), bar.category),
                        y: .value(L10n.t("memories.stats.weekTitle"), bar.count))
                    .foregroundStyle(by: .value(L10n.t("common.partner"), bar.who))
                    .cornerRadius(3)
            }
            .chartForegroundStyleScale([meLabel: myColor, partnerLabel: partnerColor])
            .chartXScale(domain: weekDays.map { weekdayLetter($0.date) })
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 180)
            .padding(.vertical, 8)
            .accessibilityLabel(L10n.t("memories.stats.weekTitle"))
        }
    }

    private func weekdayLetter(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: L10n.isGerman ? "de_DE" : "en_US")
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }

    // MARK: Mood timeline

    /// Moods grouped by calendar day, newest day (and newest entry) first.
    private var moodDays: [MoodDay] {
        let calendar = SharedDates.calendar
        let grouped = Dictionary(grouping: moods) { calendar.startOfDay(for: $0.createdAt) }
        return grouped.keys.sorted(by: >).map { day in
            MoodDay(id: SharedDates.todayKey(day), date: day,
                    entries: (grouped[day] ?? []).sorted { $0.createdAt > $1.createdAt })
        }
    }

    /// The 3 most frequent moods across BOTH members in the last 30 days —
    /// hidden while there are fewer than 3 entries to aggregate.
    private var topMoods: [MoodCount] {
        let calendar = SharedDates.calendar
        guard let cutoff = calendar.date(byAdding: .day, value: -30, to: Date()) else { return [] }
        let recent = moods.filter { $0.createdAt >= cutoff }
        guard recent.count >= 3 else { return [] }
        let counts = Dictionary(grouping: recent) { $0.mood }.mapValues { $0.count }
        return counts
            .sorted { lhs, rhs in lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key < rhs.key }
            .prefix(3)
            .map { MoodCount(mood: $0.key, count: $0.value) }
    }

    @ViewBuilder
    private var moodSections: some View {
        Section {
            if !topMoods.isEmpty {
                HStack(spacing: 8) {
                    ForEach(topMoods) { item in
                        HStack(spacing: 5) {
                            Text(item.mood)
                                .font(.title3)
                            Text(L10n.t("memories.stats.topMoodCount", ["n": String(item.count)]))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.tertiaryCardBackground, in: Capsule())
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
                Button {
                    shareTopMoods()
                } label: {
                    HStack {
                        Label(L10n.t(sharedMoods ? "memories.stats.moodShared" : "memories.stats.moodShare"),
                              systemImage: sharedMoods ? "checkmark" : "paperplane")
                        if sharingMoods {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(sharingMoods || sharedMoods)
            }
            if moods.isEmpty {
                Text(L10n.t("memories.stats.moodEmpty"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(L10n.t("memories.stats.moodTitle"))
        } footer: {
            if !topMoods.isEmpty {
                Text(L10n.t("memories.stats.topMoods"))
            }
        }

        ForEach(moodDays) { day in
            Section(prettyDay(day.date)) {
                ForEach(day.entries) { entry in
                    moodRow(entry)
                }
            }
        }
    }

    private func moodRow(_ entry: MoodEntry) -> some View {
        let author = member(of: entry)
        return HStack(spacing: 12) {
            MemberAvatar(emoji: author?.avatar, colorHex: author?.color, size: 34)
            Text(entry.mood)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                if let note = entry.moodNote, !note.isEmpty {
                    Text(note)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func member(of entry: MoodEntry) -> Member? {
        appState.couple?.members.first { $0.id == entry.memberId }
    }

    private func prettyDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: L10n.isGerman ? "de_DE" : "en_US")
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private func shareTopMoods() {
        guard let api = appState.api, !sharingMoods, !sharedMoods else { return }
        let top = topMoods
        guard !top.isEmpty else { return }
        sharingMoods = true
        let summary = top
            .map { "\($0.mood) \(L10n.t("memories.stats.topMoodCount", ["n": String($0.count)]))" }
            .joined(separator: "  ·  ")
        let text = L10n.t("memories.stats.moodShareHeader") + "\n" + summary
        Task {
            do {
                try await api.sendMessage(type: .text, text: text)
                sharedMoods = true
                SoundEngine.shared.play(.pop)
                Haptics.shared.success()
                appState.notify(L10n.t("memories.stats.moodShareSent"), style: .success)
            } catch {
                appState.handleAPIError(error)
            }
            sharingMoods = false
        }
    }

    // MARK: Caption

    private func caption(_ stats: Stats) -> some View {
        let total = stats.touchesSent.total + stats.touchesReceived.total
        return Text(total > 0
                    ? L10n.t("memories.stats.caption", ["n": String(total)])
                    : L10n.t("memories.stats.empty"))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: Data

    private func loadMoods() async {
        guard let api = appState.api else { return }
        if let list = try? await api.moods() { moods = list }
    }

    private func loadTouches() async {
        guard let api = appState.api else { return }
        if let list = try? await api.recentTouches(limit: 200) { touches = list }
    }
}

// MARK: - Stat tile

private struct StatTile: View {
    let systemImage: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            IconTile(systemImage: systemImage, tint: tint, size: 30)
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(padding: 14)
        .accessibilityElement(children: .combine)
    }
}
