import SwiftUI

/// Month grid of the daily-question streak: days both answered, and —
/// dimmer — the days only I did. Pushed from the daily question screen.
struct StreakCalendarView: View {
    @Environment(AppState.self) private var appState

    @State private var loading = true
    @State private var bothKeys: Set<String> = []
    @State private var mineOnlyKeys: Set<String> = []
    @State private var displayedMonth = Self.startOfMonth(Date())

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if loading {
                    ProgressView()
                        .padding(.top, 40)
                } else {
                    monthNav
                    calendarCard
                    legend
                    summary
                }
            }
            .padding(Brand.screenInset)
        }
        .groupedScreenBackground()
        .navigationTitle(L10n.t("home.streakCalendar.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadEntries() }
    }

    // MARK: Calendar math

    private var calendar: Calendar {
        var c = SharedDates.calendar
        c.firstWeekday = L10n.isGerman ? 2 : 1
        return c
    }

    private static func startOfMonth(_ date: Date) -> Date {
        let cal = SharedDates.calendar
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps) ?? date
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    private var monthKeyPrefix: String {
        let comps = SharedDates.calendar.dateComponents([.year, .month], from: displayedMonth)
        return String(format: "%04d-%02d-", comps.year ?? 0, comps.month ?? 0)
    }

    private struct DayCell: Identifiable {
        let id: Int
        let day: Int?
        let key: String?
    }

    private var dayCells: [DayCell] {
        let cal = calendar
        guard let range = cal.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let firstWeekday = cal.component(.weekday, from: displayedMonth)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        var cells: [DayCell] = (0..<leading).map { DayCell(id: $0, day: nil, key: nil) }
        for day in range {
            cells.append(DayCell(id: leading + day, day: day, key: monthKeyPrefix + String(format: "%02d", day)))
        }
        return cells
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: L10n.isGerman ? "de_DE" : "en_US")
        let symbols = formatter.veryShortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: L10n.isGerman ? "de_DE" : "en_US")
        formatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return formatter.string(from: displayedMonth)
    }

    // MARK: Views

    private var monthNav: some View {
        HStack {
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel(L10n.t("home.streakCalendar.prevMonth"))
            Spacer()
            Text(monthTitle)
                .font(.headline)
                .contentTransition(.numericText())
            Spacer()
            Button {
                shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(isCurrentMonth)
            .accessibilityLabel(L10n.t("home.streakCalendar.nextMonth"))
        }
        .buttonStyle(.glass)
    }

    private func shiftMonth(_ delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        withAnimation(.snappy) { displayedMonth = Self.startOfMonth(next) }
    }

    private var calendarCard: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(dayCells) { cell in
                    dayView(cell)
                }
            }
        }
        .cardSurface()
    }

    @ViewBuilder
    private func dayView(_ cell: DayCell) -> some View {
        if let day = cell.day, let key = cell.key {
            let both = bothKeys.contains(key)
            let mine = mineOnlyKeys.contains(key)
            let isToday = key == SharedDates.todayKey()
            Text("\(day)")
                .font(.subheadline.weight(both ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(both ? Color.white : (mine ? Color.accentColor : Color.primary))
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(
                    both ? Color.accentColor : (mine ? Color.accentColor.opacity(0.15) : Color.clear),
                    in: Circle())
                .overlay {
                    if isToday {
                        Circle().strokeBorder(Color.accentColor, lineWidth: 1.5)
                    }
                }
                .accessibilityLabel(both ? "\(day): " + L10n.t("home.streakCalendar.legendBoth")
                                    : mine ? "\(day): " + L10n.t("home.streakCalendar.legendMine")
                                    : "\(day)")
        } else {
            Color.clear.frame(minHeight: 36)
        }
    }

    private var legend: some View {
        HStack(spacing: 18) {
            Label {
                Text(L10n.t("home.streakCalendar.legendBoth"))
            } icon: {
                Circle().fill(Color.accentColor).frame(width: 12, height: 12)
            }
            Label {
                Text(L10n.t("home.streakCalendar.legendMine"))
            } icon: {
                Circle().fill(Color.accentColor.opacity(0.2)).frame(width: 12, height: 12)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var monthBothCount: Int {
        bothKeys.filter { $0.hasPrefix(monthKeyPrefix) }.count
    }

    @ViewBuilder
    private var summary: some View {
        if bothKeys.isEmpty {
            Text(L10n.t("home.streakCalendar.empty"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        } else {
            VStack(spacing: 6) {
                if let streak = appState.dailyEntry?.streak, streak > 1 {
                    Label(L10n.t("home.streak", ["n": String(streak)]), systemImage: "flame.fill")
                        .font(.headline)
                        .foregroundStyle(Color.orange)
                }
                Text(L10n.t("home.streakCalendar.monthCount", ["n": String(monthBothCount)]))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func loadEntries() async {
        guard let api = appState.api else {
            loading = false
            return
        }
        if let entries = try? await api.dailyHistory(limit: 400) {
            bothKeys = Set(entries.filter(\.bothAnswered).map(\.dateKey))
            mineOnlyKeys = Set(entries.filter { !$0.bothAnswered && $0.myAnswer != nil }.map(\.dateKey))
        }
        loading = false
    }
}
