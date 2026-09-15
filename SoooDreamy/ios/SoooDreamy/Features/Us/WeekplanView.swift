import SwiftUI
import Combine

/// "Unsere Woche": availability board for the next seven days (free / busy /
/// call / date), overlap highlights, one-off and weekly slots, and the
/// movie-match suggestion from Film-Roulette.
struct WeekplanView: View {
    @Environment(AppState.self) private var appState

    @State private var plan: WeekplanResponse?
    @State private var showCompose = false
    @State private var composeDateKey: String?
    @State private var movieSuggestion: MovieNight.Match?
    @State private var planningMovie = false
    @State private var deleteTarget: WeekplanSlot?
    @AppStorage("weekplan.dismissedMovieMatches") private var dismissedMatchesRaw = ""

    private var dismissedMatchIds: Set<String> {
        Set(dismissedMatchesRaw.split(separator: ",").map(String.init))
    }

    var body: some View {
        List {
            if let suggestion = movieSuggestion {
                Section {
                    movieBanner(suggestion)
                }
            }
            if let plan {
                Section {
                    ForEach(plan.days, id: \.dateKey) { day in
                        WeekplanDayRow(day: day,
                                       onSetStatus: { status in setAvailability(day, status: status) },
                                       onAddSlot: { composeDateKey = day.dateKey; showCompose = true },
                                       onDeleteSlot: { slot in deleteTarget = slot })
                    }
                } header: {
                    Text(L10n.t("weekplan.subtitle"))
                }
                let weekly = plan.slots.filter { $0.weekday != nil }
                Section(L10n.t("weekplan.slots") + " · " + L10n.t("weekplan.slot.weekly")) {
                    if weekly.isEmpty {
                        Text(L10n.t("weekplan.empty.slots"))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(weekly) { slot in
                        HStack {
                            Text(slot.emoji ?? "💜")
                            Text(weeklyLine(slot))
                            Spacer()
                            Image(systemName: "repeat")
                                .foregroundStyle(.tertiary)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { deleteTarget = slot } label: {
                                Label(L10n.t("common.delete"), systemImage: "trash")
                            }
                        }
                    }
                }
            } else {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(L10n.t("weekplan.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    composeDateKey = nil
                    showCompose = true
                } label: {
                    Label(L10n.t("weekplan.newSlot"), systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showCompose) {
            WeekplanSlotComposeSheet(initialDateKey: composeDateKey) {
                Task { await reload() }
            }
        }
        .confirmationDialog(L10n.t("common.delete"), isPresented: Binding(
            get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }), titleVisibility: .visible) {
            Button(L10n.t("common.delete"), role: .destructive) {
                if let target = deleteTarget { deleteSlot(target) }
            }
        }
        .task(id: appState.couple?.id) { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent else { return }
            switch event.type {
            case .weekplanAvailability, .weekplanSlotAdded, .weekplanSlotUpdated, .weekplanSlotDeleted, .appEvent:
                Task { await reload() }
            default:
                break
            }
        }
    }

    // MARK: Data

    private func reload() async {
        guard let api = appState.api else { return }
        if let response = try? await api.weekplan() {
            plan = response
            await refreshMovieSuggestion(plan: response)
        }
    }

    private func refreshMovieSuggestion(plan: WeekplanResponse) async {
        guard let api = appState.api else { return }
        let events = (try? await api.appEvents(type: "movie_match", limit: 10)) ?? []
        let matches = events.map { MovieNight.Match(id: $0.id, title: $0.dataString("title"), createdAt: $0.createdAt) }
        let movieSlots = plan.slots.filter { $0.kind == "movie" }.map(\.createdAt)
        movieSuggestion = MovieNight.suggestion(matches: matches, movieSlotCreations: movieSlots,
                                                dismissedIds: dismissedMatchIds)
    }

    private func weeklyLine(_ slot: WeekplanSlot) -> String {
        var parts = [slot.title]
        if let weekday = slot.weekday { parts.append(L10n.t("weekday.\(weekday)")) }
        if let time = slot.time { parts.append(time) }
        return parts.joined(separator: " · ")
    }

    // MARK: Movie match banner

    private func movieBanner(_ suggestion: MovieNight.Match) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                IconTile(systemImage: "popcorn.fill", tint: .pink, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("weekplan.movieBanner.title"))
                        .font(.subheadline.weight(.semibold))
                    Text(suggestion.title ?? L10n.t("weekplan.movieBanner.fallbackTitle"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    dismissMovieSuggestion(suggestion)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(L10n.t("common.close"))
            }
            Button {
                planMovieNight(suggestion)
            } label: {
                HStack {
                    if planningMovie { ProgressView() }
                    Text(L10n.t("weekplan.movieBanner.cta"))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(planningMovie)
        }
        .padding(.vertical, 4)
    }

    private func planMovieNight(_ suggestion: MovieNight.Match) {
        guard let api = appState.api, !planningMovie else { return }
        planningMovie = true
        Task {
            defer { planningMovie = false }
            do {
                let overlapDays = plan?.days.filter(\.overlap).map(\.dateKey) ?? []
                let dateKey = MovieNight.slotDateKey(overlapDateKeys: overlapDays)
                let title = suggestion.title ?? L10n.t("weekplan.movieBanner.fallbackTitle")
                _ = try await api.addWeekplanSlot(title: title, emoji: "🍿", kind: "movie",
                                                  dateKey: dateKey, weekday: nil, time: nil)
                SoundEngine.shared.play(.sparkle)
                appState.notify(L10n.t("weekplan.addedToast"), style: .success)
                withAnimation(.snappy) { movieSuggestion = nil }
                await reload()
            } catch {
                appState.handleAPIError(error)
            }
        }
    }

    private func dismissMovieSuggestion(_ suggestion: MovieNight.Match) {
        var ids = dismissedMatchIds
        ids.insert(suggestion.id)
        dismissedMatchesRaw = ids.suffix(30).joined(separator: ",")
        withAnimation(.snappy) { movieSuggestion = nil }
    }

    // MARK: Mutations

    private func setAvailability(_ day: WeekplanDay, status: String?) {
        guard let api = appState.api else { return }
        Task {
            do {
                let updated = try await api.setAvailability(dateKey: day.dateKey, status: status)
                if let idx = plan?.days.firstIndex(where: { $0.dateKey == day.dateKey }) {
                    plan?.days[idx] = updated
                }
                if updated.overlap && !day.overlap { Delight.celebrate(.small, theme: .stars) }
            } catch {
                appState.handleAPIError(error)
            }
        }
    }

    private func deleteSlot(_ slot: WeekplanSlot) {
        guard let api = appState.api else { return }
        Task {
            do {
                try await api.deleteWeekplanSlot(id: slot.id)
                await reload()
            } catch {
                appState.handleAPIError(error)
            }
        }
    }
}

// MARK: - Day row

private struct WeekplanDayRow: View {
    @Environment(AppState.self) private var appState
    let day: WeekplanDay
    let onSetStatus: (String?) -> Void
    let onAddSlot: () -> Void
    let onDeleteSlot: (WeekplanSlot) -> Void

    static let statuses: [(status: String, systemImage: String, tint: Color)] = [
        ("free", "hand.thumbsup.fill", .green), ("busy", "hand.raised.fill", .gray),
        ("call", "phone.fill", .blue), ("date", "heart.fill", .pink)
    ]

    private var isToday: Bool { day.dateKey == SharedDates.todayKey() }
    private var myStatus: String? { appState.memberId.flatMap { day.availability[$0]?.status } }
    private var partnerStatus: String? { appState.partner.flatMap { day.availability[$0.id]?.status } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(L10n.t("weekday.\(day.weekday)"))
                    .font(.headline)
                    .foregroundStyle(isToday ? Color.accentColor : Color.primary)
                Text(shortDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if isToday {
                    Text(L10n.t("common.today"))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.16), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
                if day.overlap {
                    Label(L10n.t("weekplan.overlap"), systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.green)
                }
                if let partner = appState.partner, let partnerStatus,
                   let entry = Self.statuses.first(where: { $0.status == partnerStatus }) {
                    HStack(spacing: 3) {
                        Text(partner.avatar).font(.caption)
                        Image(systemName: entry.systemImage)
                            .font(.caption2)
                            .foregroundStyle(entry.tint)
                    }
                    .accessibilityLabel("\(partner.name): \(L10n.t("weekplan.status.\(partnerStatus)"))")
                }
            }

            HStack(spacing: 8) {
                ForEach(Self.statuses, id: \.status) { entry in
                    let selected = myStatus == entry.status
                    Button {
                        onSetStatus(selected ? nil : entry.status)
                    } label: {
                        Label(L10n.t("weekplan.status.\(entry.status)"), systemImage: entry.systemImage)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(selected ? entry.tint : Color.secondary)
                    .controlSize(.small)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .accessibilityLabel(L10n.t("weekplan.myDay"))

            ForEach(day.slots) { slot in
                HStack(spacing: 8) {
                    Text(slot.emoji ?? "💜")
                    Text(slot.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    if slot.weekday != nil {
                        Image(systemName: "repeat")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    if let time = slot.time {
                        Text(time)
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        onDeleteSlot(slot)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("common.delete"))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.tertiaryCardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Button(L10n.t("weekplan.newSlot"), systemImage: "plus", action: onAddSlot)
                .font(.footnote.weight(.medium))
                .buttonStyle(.borderless)
        }
        .padding(.vertical, 6)
    }

    private var shortDate: String {
        guard let date = SharedDates.parse(day.dateKey) else { return day.dateKey }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: L10n.isGerman ? "de_DE" : "en_US")
        formatter.setLocalizedDateFormatFromTemplate("d.M.")
        return formatter.string(from: date)
    }
}

// MARK: - Compose

private struct WeekplanSlotComposeSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    var initialDateKey: String?
    let onAdded: () -> Void

    private static let kinds: [(kind: String, emoji: String)] = [
        ("call", "📞"), ("movie", "🍿"), ("date", "💘"), ("custom", "💜")
    ]

    @State private var title = ""
    @State private var kind = "call"
    @State private var repeatWeekly = false
    @State private var date = Date()
    @State private var weekday = 5
    @State private var useTime = false
    @State private var time = SharedDates.calendar.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var adding = false

    private var timeString: String? {
        guard useTime else { return nil }
        let parts = SharedDates.calendar.dateComponents([.hour, .minute], from: time)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L10n.t("weekplan.compose.title"), selection: $kind) {
                        ForEach(Self.kinds, id: \.kind) { entry in
                            Text("\(entry.emoji) \(L10n.t("weekplan.slot.kind.\(entry.kind)"))").tag(entry.kind)
                        }
                    }
                    .pickerStyle(.menu)
                    TextField(L10n.t("weekplan.compose.titleField"), text: $title)
                }
                Section {
                    Toggle(L10n.t("weekplan.compose.repeat"), isOn: $repeatWeekly.animation())
                    if repeatWeekly {
                        Picker(L10n.t("weekplan.compose.day"), selection: $weekday) {
                            ForEach([1, 2, 3, 4, 5, 6, 0], id: \.self) { day in
                                Text(L10n.t("weekday.\(day)")).tag(day)
                            }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        DatePicker(L10n.t("weekplan.compose.day"), selection: $date, in: Date()..., displayedComponents: [.date])
                    }
                    Toggle(L10n.t("weekplan.compose.time"), isOn: $useTime.animation())
                    if useTime {
                        DatePicker(L10n.t("weekplan.compose.time"), selection: $time, displayedComponents: [.hourAndMinute])
                    }
                }
            }
            .navigationTitle(L10n.t("weekplan.compose.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        add()
                    } label: {
                        if adding { ProgressView() } else { Text(L10n.t("common.add")) }
                    }
                    .disabled(adding || title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            if title.isEmpty { title = L10n.t("weekplan.slot.kind.\(kind)") }
            if let initialDateKey, let parsed = SharedDates.parse(initialDateKey) { date = parsed }
        }
        .onChange(of: kind) { old, new in
            if title == L10n.t("weekplan.slot.kind.\(old)") { title = L10n.t("weekplan.slot.kind.\(new)") }
        }
    }

    private func add() {
        guard let api = appState.api, !adding else { return }
        adding = true
        let emoji = Self.kinds.first { $0.kind == kind }?.emoji
        Task {
            do {
                _ = try await api.addWeekplanSlot(title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                                  emoji: emoji, kind: kind,
                                                  dateKey: repeatWeekly ? nil : SharedDates.todayKey(date),
                                                  weekday: repeatWeekly ? weekday : nil,
                                                  time: timeString)
                SoundEngine.shared.play(.pop)
                appState.notify(L10n.t("weekplan.addedToast"), style: .success)
                onAdded()
                dismiss()
            } catch {
                adding = false
                appState.handleAPIError(error)
            }
        }
    }
}
