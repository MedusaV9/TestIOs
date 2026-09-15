import SwiftUI
import Combine

/// Momente — countdowns & special dates with Live Activity countdowns.
/// Calendar-style list: upcoming and past sections, swipe to delete,
/// context menu to share, editor as a Form sheet.
struct EventsView: View {
    @Environment(AppState.self) private var appState

    @State private var editorTarget: EditorTarget?
    @State private var activityRefresh = 0
    @State private var filter: EventFilter = .all

    private struct EditorTarget: Identifiable {
        let id: String
        let event: EventItem?
    }

    /// Upcoming = today or later (incl. yearly repeats); past = already over.
    private enum EventFilter: String, CaseIterable, Identifiable {
        case all, upcoming, past
        var id: String { rawValue }
        var labelKey: String { "memories.events.filter.\(rawValue)" }
    }

    private struct EventEntry: Identifiable {
        let event: EventItem
        let days: Int?
        var id: String { event.id }
    }

    var body: some View {
        List {
            if appState.events.isEmpty {
                ContentUnavailableView {
                    Label(L10n.t("memories.events.empty.title"), systemImage: "calendar.badge.plus")
                } description: {
                    Text(L10n.t("memories.events.empty.subtitle"))
                } actions: {
                    Button(L10n.t("memories.events.add")) {
                        editorTarget = EditorTarget(id: "new", event: nil)
                    }
                    .buttonStyle(.glassProminent)
                }
                .listRowBackground(Color.clear)
                if let suggestion = monthiversarySuggestion {
                    Section { monthiversaryRow(suggestion) }
                }
            } else {
                Section {
                    Picker(L10n.t("memories.events.title"), selection: $filter.animation(.snappy)) {
                        ForEach(EventFilter.allCases) { f in
                            Text(L10n.t(f.labelKey)).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }

                // The suggestion is always an upcoming event — hide it under "past".
                if filter != .past, let suggestion = monthiversarySuggestion {
                    Section { monthiversaryRow(suggestion) }
                }

                if filteredEvents.isEmpty {
                    Text(L10n.t(filter == .upcoming ? "memories.events.emptyUpcoming" : "memories.events.emptyPast"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .listRowBackground(Color.clear)
                }

                if filter != .past, !upcomingEvents.isEmpty {
                    Section(L10n.t("memories.events.filter.upcoming")) {
                        ForEach(upcomingEvents) { entry in row(entry.event, days: entry.days) }
                    }
                }
                if filter != .upcoming, !pastEvents.isEmpty {
                    Section(L10n.t("memories.events.filter.past")) {
                        ForEach(pastEvents) { entry in row(entry.event, days: entry.days) }
                    }
                }
            }
        }
        .navigationTitle(L10n.t("memories.events.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorTarget = EditorTarget(id: "new", event: nil)
                } label: {
                    Label(L10n.t("memories.events.add"), systemImage: "plus")
                }
            }
        }
        .refreshable { await appState.refreshEvents() }
        .task { await appState.refreshEvents() }
        .sheet(item: $editorTarget) { target in
            EventEditorSheet(event: target.event)
        }
    }

    // MARK: Sorting & filtering

    private var sortedEvents: [EventEntry] {
        appState.events
            .map { EventEntry(event: $0, days: SharedDates.daysUntil($0.date, repeatsYearly: $0.repeatsYearly)) }
            .sorted { sortRank($0.days) < sortRank($1.days) }
    }

    /// Upcoming first (soonest at top), past events afterwards (most recent first).
    private func sortRank(_ days: Int?) -> Int {
        guard let days else { return Int.max }
        return days >= 0 ? days : 100_000 - days
    }

    private var upcomingEvents: [EventEntry] { sortedEvents.filter { ($0.days ?? -1) >= 0 } }
    private var pastEvents: [EventEntry] { sortedEvents.filter { ($0.days ?? -1) < 0 } }

    private var filteredEvents: [EventEntry] {
        switch filter {
        case .all: return sortedEvents
        case .upcoming: return upcomingEvents
        case .past: return pastEvents
        }
    }

    // MARK: Monthiversary helper

    private struct MonthiversarySuggestion {
        let months: Int
        let dateKey: String
        var title: String {
            L10n.t("memories.events.monthiversaryTitle", ["n": String(months)])
        }
    }

    /// The next monthiversary (anniversary day-of-month, ≥ today) — nil while
    /// no anniversary is set, or once the suggested event already exists.
    private var monthiversarySuggestion: MonthiversarySuggestion? {
        guard let key = appState.couple?.anniversary,
              let anniversary = SharedDates.parse(key) else { return nil }
        let calendar = SharedDates.calendar
        let annDay = calendar.startOfDay(for: anniversary)
        let today = calendar.startOfDay(for: Date())
        var months = max(calendar.dateComponents([.month], from: annDay, to: today).month ?? 0, 1)
        var candidate = calendar.date(byAdding: .month, value: months, to: annDay)
        while let c = candidate, calendar.startOfDay(for: c) < today {
            months += 1
            candidate = calendar.date(byAdding: .month, value: months, to: annDay)
        }
        guard let date = candidate else { return nil }
        let suggestion = MonthiversarySuggestion(months: months, dateKey: SharedDates.todayKey(date))
        guard !appState.events.contains(where: { $0.date == suggestion.dateKey && $0.title == suggestion.title }) else {
            return nil
        }
        return suggestion
    }

    private func monthiversaryRow(_ suggestion: MonthiversarySuggestion) -> some View {
        Button {
            addMonthiversary(suggestion)
        } label: {
            HStack(spacing: 12) {
                Text("💞")
                    .font(.title2)
                    .frame(width: 36)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("memories.events.addMonthiversary"))
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.primary)
                    Text(L10n.t("memories.events.monthiversarySub",
                                ["n": String(suggestion.months), "date": eventDateString(suggestion.dateKey)]))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private func addMonthiversary(_ suggestion: MonthiversarySuggestion) {
        guard let api = appState.api else { return }
        guard !appState.events.contains(where: { $0.date == suggestion.dateKey && $0.title == suggestion.title }) else {
            appState.notify(L10n.t("memories.events.monthiversaryExists"), style: .info)
            return
        }
        Task {
            do {
                _ = try await api.addEvent(title: suggestion.title, emoji: "💞",
                                           date: suggestion.dateKey, repeatsYearly: false)
                await appState.refreshEvents()
                appState.updateWidgetSnapshot()
                SoundEngine.shared.play(.chime)
                Haptics.shared.success()
                appState.notify(L10n.t("memories.events.saved"), style: .success)
            } catch {
                appState.handleAPIError(error)
            }
        }
    }

    // MARK: Row

    private func row(_ event: EventItem, days: Int?) -> some View {
        Button {
            editorTarget = EditorTarget(id: event.id, event: event)
        } label: {
            HStack(spacing: 14) {
                Text(event.emoji)
                    .font(.title)
                    .frame(width: 44, height: 44)
                    .background(Color.tertiaryCardBackground,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(eventDateString(event.date))
                        if event.repeatsYearly {
                            Image(systemName: "repeat")
                                .accessibilityLabel(L10n.t("memories.events.yearlyBadge"))
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 6) {
                    countdownText(days: days)
                    liveActivityButton(event, days: days)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deleteEvent(event)
            } label: {
                Label(L10n.t("common.delete"), systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                editorTarget = EditorTarget(id: event.id, event: event)
            } label: {
                Label(L10n.t("common.edit"), systemImage: "pencil")
            }
            Button {
                shareToChat(event, days: days)
            } label: {
                Label(L10n.t("memories.events.share"), systemImage: "paperplane")
            }
        }
    }

    @ViewBuilder
    private func countdownText(days: Int?) -> some View {
        if let days {
            Group {
                if days == 0 {
                    Text(L10n.t("memories.countdown.today")).foregroundStyle(Color.accentColor)
                } else if days == 1 {
                    Text(L10n.t("memories.countdown.tomorrow")).foregroundStyle(Color.orange)
                } else if days > 1 {
                    Text(L10n.t("memories.countdown.inDays", ["n": String(days)])).foregroundStyle(Color.orange)
                } else {
                    Text(L10n.t("memories.countdown.daysAgo", ["n": String(-days)])).foregroundStyle(.secondary)
                }
            }
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
        }
    }

    @ViewBuilder
    private func liveActivityButton(_ event: EventItem, days: Int?) -> some View {
        let running = isRunningActivity(event)
        if CountdownActivityController.isSupported && (running || (days ?? -1) > 0) {
            Button {
                toggleActivity(event)
            } label: {
                Label(L10n.t(running ? "memories.events.liveStop" : "memories.events.liveStart"),
                      systemImage: running ? "stop.circle.fill" : "timer")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .tint(running ? .red : .accentColor)
        }
    }

    // MARK: Live Activity

    private func isRunningActivity(_ event: EventItem) -> Bool {
        _ = activityRefresh
        return CountdownActivityController.activeEventTitle == event.title
    }

    private func toggleActivity(_ event: EventItem) {
        Haptics.shared.tap()
        if isRunningActivity(event) {
            CountdownActivityController.stopAll()
            appState.notify(L10n.t("memories.events.liveStopped"), style: .info)
        } else if CountdownActivityController.start(for: event, partnerName: appState.partner?.name) {
            SoundEngine.shared.play(.chime)
            appState.notify(L10n.t("memories.events.liveStarted"), style: .success)
        } else {
            appState.notify(L10n.t("memories.events.liveFailed"), style: .error)
        }
        activityRefresh += 1
    }

    // MARK: Actions

    /// Posts a pretty two-line countdown message into the couple chat.
    private func shareToChat(_ event: EventItem, days: Int?) {
        guard let api = appState.api else { return }
        let text = shareText(event, days: days)
        Task {
            do {
                try await api.sendMessage(type: .text, text: text)
                Haptics.shared.success()
                SoundEngine.shared.play(.pop)
                appState.notify(L10n.t("memories.events.shareSent"), style: .success)
            } catch {
                appState.handleAPIError(error)
            }
        }
    }

    private func shareText(_ event: EventItem, days: Int?) -> String {
        let header = L10n.t("memories.events.shareHeader", ["emoji": event.emoji, "title": event.title])
        let date = eventDateString(event.date)
        let line: String
        switch days {
        case .some(0):
            line = L10n.t("memories.events.shareToday", ["date": date])
        case .some(1):
            line = L10n.t("memories.events.shareOneDay", ["date": date])
        case .some(let n) where n > 1:
            line = L10n.t("memories.events.shareInDays", ["n": String(n), "date": date])
        default:
            // Past non-repeating (or unparseable) events get a plain date line.
            line = date
        }
        return header + "\n" + line
    }

    private func deleteEvent(_ event: EventItem) {
        guard let api = appState.api else { return }
        Task {
            do {
                try await api.deleteEvent(id: event.id)
                if isRunningActivity(event) {
                    CountdownActivityController.stop(matchingTitle: event.title)
                    activityRefresh += 1
                }
                await appState.refreshEvents()
                appState.updateWidgetSnapshot()
                appState.notify(L10n.t("memories.events.deleted"), style: .info)
            } catch {
                appState.handleAPIError(error)
            }
        }
    }
}

/// Long date in the app language for a `YYYY-MM-DD` key.
func eventDateString(_ key: String) -> String {
    guard let date = SharedDates.parse(key) else { return key }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: L10n.isGerman ? "de_DE" : "en_US")
    formatter.dateStyle = .long
    return formatter.string(from: date)
}

// MARK: - Editor sheet

private struct EventEditorSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let event: EventItem?

    @State private var title: String
    @State private var emoji: String
    @State private var date: Date
    @State private var repeatsYearly: Bool
    @State private var saving = false

    private static let emojis = [
        "🎂", "💍", "✈️", "🎄", "🎉", "💞", "🌙", "🎓",
        "🏝️", "🎁", "🥂", "🎃", "🐣", "❤️", "🗓️", "⭐️",
        "🎆", "🏡"
    ]

    init(event: EventItem?) {
        self.event = event
        _title = State(initialValue: event?.title ?? "")
        _emoji = State(initialValue: event?.emoji ?? "🎉")
        _date = State(initialValue: SharedDates.parse(event?.date) ?? Date())
        _repeatsYearly = State(initialValue: event?.repeatsYearly ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.t("memories.events.titleField"), text: $title)
                        .submitLabel(.done)
                }
                Section(L10n.t("memories.events.emoji")) {
                    EmojiPickerGrid(emojis: Self.emojis, selection: $emoji)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }
                Section {
                    DatePicker(L10n.t("memories.events.date"), selection: $date, displayedComponents: .date)
                    Toggle(L10n.t("memories.events.yearly"), isOn: $repeatsYearly)
                }
            }
            .navigationTitle(L10n.t(event == nil ? "memories.events.add" : "memories.events.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if saving { ProgressView() } else { Text(L10n.t("common.save")) }
                    }
                    .disabled(saving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        guard let api = appState.api, !saving else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        saving = true
        let dateKey = SharedDates.todayKey(date)
        Task {
            do {
                if let event {
                    _ = try await api.updateEvent(id: event.id, title: trimmed, emoji: emoji,
                                                  date: dateKey, repeatsYearly: repeatsYearly)
                } else {
                    _ = try await api.addEvent(title: trimmed, emoji: emoji,
                                               date: dateKey, repeatsYearly: repeatsYearly)
                }
                await appState.refreshEvents()
                appState.updateWidgetSnapshot()
                Haptics.shared.success()
                SoundEngine.shared.play(.chime)
                appState.notify(L10n.t("memories.events.saved"), style: .success)
                dismiss()
            } catch {
                appState.handleAPIError(error)
            }
            saving = false
        }
    }
}
