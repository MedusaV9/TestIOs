import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline (own provider: pinned event + live ticker)

struct CountdownEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let palette: WidgetPalette
    let layout: String
    let animated: Bool
    /// Pinned event (from the intent), else nil → next upcoming.
    let pinnedEventId: String?
}

struct CountdownProvider: AppIntentTimelineProvider {
    private func entry(for configuration: CountdownWidgetConfigIntent, date: Date) -> CountdownEntry {
        let kind = WidgetKindID.countdown
        let studio = SharedStore.readStudioConfig()
        let kindConfig = studio.config(for: kind)
        return CountdownEntry(
            date: date,
            snapshot: SharedStore.readSnapshot(),
            palette: WidgetPalette.resolve(kind: kind, intentThemeId: configuration.theme.themeId),
            layout: WidgetLayoutResolver.resolve(kind: kind, intent: configuration.layout),
            animated: configuration.animated,
            pinnedEventId: configuration.event?.id ?? kindConfig.eventId)
    }

    func placeholder(in context: Context) -> CountdownEntry {
        entry(for: CountdownWidgetConfigIntent(), date: Date())
    }

    func snapshot(for configuration: CountdownWidgetConfigIntent, in context: Context) async -> CountdownEntry {
        entry(for: configuration, date: Date())
    }

    func timeline(for configuration: CountdownWidgetConfigIntent, in context: Context) async -> Timeline<CountdownEntry> {
        var entries = [entry(for: configuration, date: Date())]
        let calendar = SharedDates.calendar
        var day = calendar.startOfDay(for: Date())
        for _ in 0..<3 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
            entries.append(entry(for: configuration, date: day))
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

// MARK: - Views

struct CountdownWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CountdownEntry

    private var palette: WidgetPalette { entry.palette }

    private struct EventInfo {
        let title: String
        let emoji: String
        let date: Date
        let days: Int
    }

    /// Pinned event when set (and still in the snapshot), else the next one.
    private var event: EventInfo? {
        if let pinned = entry.pinnedEventId,
           let lite = entry.snapshot?.allEvents?.first(where: { $0.id == pinned }),
           let date = SharedDates.nextOccurrence(lite.date, repeatsYearly: lite.repeatsYearly),
           let days = SharedDates.daysUntil(lite.date, repeatsYearly: lite.repeatsYearly,
                                            now: entry.date),
           days >= 0 {
            return EventInfo(title: lite.title, emoji: lite.emoji, date: date, days: days)
        }
        guard let snapshot = entry.snapshot,
              let title = snapshot.nextEventTitle, !title.isEmpty,
              let date = SharedDates.parse(snapshot.nextEventDate),
              let days = SharedDates.daysUntil(snapshot.nextEventDate, now: entry.date),
              days >= 0 else { return nil }
        return EventInfo(title: title, emoji: snapshot.nextEventEmoji ?? "💫",
                         date: date, days: days)
    }

    /// Live ticking when enabled and the moment is close (< 49 h away).
    private func showsLiveTimer(_ event: EventInfo) -> Bool {
        entry.animated && event.date > Date()
            && event.date.timeIntervalSince(Date()) < 49 * 3600
    }

    private func daysText(_ days: Int) -> String {
        if days == 0 { return WText.t("HEUTE! 🎉", "TODAY! 🎉") }
        if days == 1 { return WText.t("in 1 Tag", "in 1 day") }
        return WText.t("in \(days) Tagen", "in \(days) days")
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular: rectangular
            case .accessoryInline: inline
            case .accessoryCircular: circular
            case .systemMedium: medium
            case .systemLarge, .systemExtraLarge: large
            default: small
            }
        }
        .widgetChrome(palette)
        .widgetURL(URL(string: "sooodreamy://events"))
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let event {
                Text(event.emoji)
                    .font(.system(size: 30))
                Spacer(minLength: 0)
                Text(event.title)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if showsLiveTimer(event) {
                    WLiveTimer(target: event.date)
                        .font(.system(.title3, design: .rounded).weight(.heavy))
                        .foregroundStyle(palette.heroGradient)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                } else {
                    Text(daysText(event.days))
                        .font(.system(.title3, design: .rounded).weight(.heavy))
                        .foregroundStyle(palette.heroGradient)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Text(event.date, format: .dateTime.day().month())
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
            } else {
                emptyState
            }
        }
    }

    private var medium: some View {
        VStack(spacing: 6) {
            if let event {
                HStack(spacing: 14) {
                    emojiBadge(event.emoji)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Text(event.date, format: .dateTime.weekday(.wide).day().month())
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(palette.textSecondary)
                        if showsLiveTimer(event) {
                            WLiveTimer(target: event.date)
                                .font(.system(.title3, design: .rounded).weight(.heavy))
                                .foregroundStyle(palette.accent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    Spacer(minLength: 8)
                    trailingCount(event.days)
                }
                if entry.animated, event.days > 0, event.days <= 30 {
                    // Auto-filling anticipation bar over the final 30 days.
                    WLiveProgress(start: event.date.addingTimeInterval(-30 * 86400),
                                  target: event.date, palette: palette)
                        .frame(height: 4)
                }
            } else {
                HStack {
                    emptyState
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var large: some View {
        VStack(spacing: 6) {
            if let event {
                Spacer(minLength: 0)
                emojiBadge(event.emoji, size: 96)
                Text(event.title)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(event.date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
                Spacer(minLength: 0)
                if event.days == 0 {
                    Text("🎉")
                        .font(.system(size: 44))
                    Text(WText.t("HEUTE!", "TODAY!"))
                        .font(.system(.title, design: .rounded).weight(.heavy))
                        .foregroundStyle(palette.accentSecondary)
                } else if showsLiveTimer(event) {
                    WLiveTimer(target: event.date)
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(palette.heroGradient)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(WText.t("bis zu eurem Moment", "until your moment"))
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(palette.accent)
                } else {
                    Text("\(event.days)")
                        .font(.system(size: 72, weight: .heavy, design: .rounded))
                        .foregroundStyle(palette.heroGradient)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                    Text(event.days == 1
                         ? WText.t("Tag bis zu eurem Moment", "day until your moment")
                         : WText.t("Tage bis zu eurem Moment", "days until your moment"))
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(palette.accent)
                }
                if entry.animated, event.days > 0, event.days <= 30 {
                    WLiveProgress(start: event.date.addingTimeInterval(-30 * 86400),
                                  target: event.date, palette: palette)
                        .frame(height: 4)
                        .padding(.horizontal, 24)
                }
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                emptyState
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func emojiBadge(_ emoji: String, size: CGFloat = 62) -> some View {
        Text(emoji)
            .font(.system(size: size * 0.58))
            .frame(width: size, height: size)
            .background(Circle().fill(palette.chipFill))
            .overlay(Circle().strokeBorder(palette.heroGradient, lineWidth: 1.5))
    }

    private func trailingCount(_ days: Int) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            if days == 0 {
                Text("🎉")
                    .font(.system(size: 30))
                Text(WText.t("HEUTE!", "TODAY!"))
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(palette.accentSecondary)
            } else {
                Text("\(days)")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(palette.heroGradient)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                Text(days == 1 ? WText.t("Tag", "day") : WText.t("Tage", "days"))
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if entry.snapshot == nil {
            WidgetSetupHint(palette: palette)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("✨")
                    .font(.system(size: 30))
                Spacer(minLength: 0)
                Text(WText.t("Kein Moment geplant", "No moment planned"))
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Text(WText.t("Füge in der App einen Moment hinzu", "Add a moment in the app"))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private var inline: some View {
        Group {
            if let event {
                Text("\(event.emoji) \(event.title): \(daysText(event.days))")
            } else {
                Text(WText.t("✨ Kein Moment geplant", "✨ No moment planned"))
            }
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let event {
                Gauge(value: min(max(1 - Double(event.days) / 30.0, 0), 1)) {
                    Text(event.emoji)
                        .font(.system(size: 11))
                } currentValueLabel: {
                    Text("\(event.days)")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                }
                .gaugeStyle(.accessoryCircular)
                .widgetAccentable()
            } else {
                Text("✨")
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let event {
                Text("\(event.emoji) \(event.title)")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .lineLimit(1)
                    .widgetAccentable()
                if showsLiveTimer(event) {
                    WLiveTimer(target: event.date)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .lineLimit(1)
                } else {
                    Text(daysText(event.days))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .lineLimit(1)
                }
                Text(event.date, format: .dateTime.day().month())
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                Text(WText.t("Kein Moment geplant", "No moment planned"))
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .lineLimit(1)
                Text(WText.t("Plant etwas Schönes ✨", "Plan something lovely ✨"))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Widget

struct CountdownWidget: Widget {
    let kind = WidgetKindID.countdown

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind,
                               intent: CountdownWidgetConfigIntent.self,
                               provider: CountdownProvider()) { entry in
            CountdownWidgetView(entry: entry)
        }
        .configurationDisplayName(WText.t("Countdown", "Countdown"))
        .description(WText.t("Zählt die Tage bis zu eurem nächsten Moment — auf Wunsch tickend.",
                             "Counts down to your next moment — live ticking if you like."))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
