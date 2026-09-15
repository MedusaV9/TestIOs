import WidgetKit
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit

// MARK: - Live Activity (lock screen + Dynamic Island)
// Styling + visible elements come from `state.config` (set by the in-app
// Live-Activity sheet) — updating the state restyles the running activity.

/// Palette helper for live activities: config theme → WidgetPalette.
private func laPalette(_ config: LiveActivityConfig?) -> WidgetPalette {
    WidgetPalette(spec: WidgetThemes.spec(id: config?.themeId ?? "night"))
}

struct CountdownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CountdownActivityAttributes.self) { context in
            CountdownLockScreenView(attributes: context.attributes, state: context.state)
        } dynamicIsland: { context in
            let palette = laPalette(context.state.config)
            let celebrating = context.state.celebration == true
                || context.attributes.targetDate <= Date()
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.emoji)
                        .font(.system(size: 30))
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.attributes.title)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if celebrating {
                            Text(WText.t("Es ist so weit! 🎉", "It's time! 🎉"))
                                .font(.system(.title3, design: .rounded).weight(.heavy))
                                .foregroundStyle(palette.accent)
                        } else {
                            CountdownTimerText(targetDate: context.attributes.targetDate,
                                               live: context.state.config?.liveTimer ?? true)
                                .font(.system(.title2, design: .rounded).weight(.heavy))
                                .foregroundStyle(palette.accent)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !celebrating {
                        CountdownDaysView(targetDate: context.attributes.targetDate,
                                          palette: palette)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 5) {
                        if !celebrating, context.state.config?.showProgress != false {
                            CountdownProgressBar(state: context.state,
                                                 targetDate: context.attributes.targetDate,
                                                 palette: palette)
                        }
                        CountdownPulseStrip(state: context.state, palette: palette)
                    }
                }
            } compactLeading: {
                Text(context.attributes.emoji)
            } compactTrailing: {
                if celebrating {
                    Text("🎉")
                } else {
                    CountdownTimerText(targetDate: context.attributes.targetDate,
                                       live: context.state.config?.liveTimer ?? true)
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .foregroundStyle(laPalette(context.state.config).accent)
                        .frame(maxWidth: 56)
                }
            } minimal: {
                Text(context.attributes.emoji)
            }
            .keylineTint(palette.accent)
        }
    }
}

// MARK: - Lock screen banner

struct CountdownLockScreenView: View {
    let attributes: CountdownActivityAttributes
    let state: CountdownActivityAttributes.ContentState

    private var palette: WidgetPalette { laPalette(state.config) }

    private var celebrating: Bool {
        state.celebration == true || attributes.targetDate <= Date()
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                Text(attributes.emoji)
                    .font(.system(size: 38))
                VStack(alignment: .leading, spacing: 2) {
                    Text(attributes.title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if celebrating {
                        Text(WText.t("Es ist so weit! 🎉", "It's time! 🎉"))
                            .font(.system(.title2, design: .rounded).weight(.heavy))
                            .foregroundStyle(palette.heroGradient)
                    } else {
                        CountdownTimerText(targetDate: attributes.targetDate,
                                           live: state.config?.liveTimer ?? true)
                            .font(.system(.title, design: .rounded).weight(.heavy))
                            .foregroundStyle(palette.heroGradient)
                    }
                    if let partnerName = attributes.partnerName, !partnerName.isEmpty {
                        Text(WText.t("mit \(partnerName) 💞", "with \(partnerName) 💞"))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(WTheme.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                if celebrating {
                    Text("🎉")
                        .font(.system(size: 34))
                } else {
                    CountdownDaysView(targetDate: attributes.targetDate, palette: palette)
                }
            }
            if !celebrating, state.config?.showProgress != false {
                CountdownProgressBar(state: state, targetDate: attributes.targetDate,
                                     palette: palette)
            }
            CountdownPulseStrip(state: state, palette: palette)
        }
        .padding(16)
        .activityBackgroundTint(Color(hexString: WidgetThemes.spec(
            id: state.config?.themeId ?? "night").backgroundHexes.first ?? "17062A")
            .opacity(0.92))
        .activitySystemActionForegroundColor(palette.accent)
    }
}

/// Auto-filling anticipation bar over the final 48 h (animates on its own —
/// `ProgressView(timerInterval:)` needs no updates from the app).
struct CountdownProgressBar: View {
    let state: CountdownActivityAttributes.ContentState
    let targetDate: Date
    let palette: WidgetPalette

    var body: some View {
        if targetDate > Date(), targetDate.timeIntervalSince(Date()) < 48 * 3600 {
            ProgressView(timerInterval: targetDate.addingTimeInterval(-48 * 3600)...targetDate,
                         countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(palette.accent)
            .frame(height: 4)
        }
    }
}

/// Compact live couple context under the countdown: online dot, mood,
/// last touch and streak — element visibility follows the user's config.
struct CountdownPulseStrip: View {
    let state: CountdownActivityAttributes.ContentState
    let palette: WidgetPalette

    private var config: LiveActivityConfig { state.config ?? LiveActivityConfig() }

    private var hasContent: Bool {
        (config.showPresence && state.partnerOnline != nil)
            || (config.showMood && state.partnerMood != nil)
            || (config.showTouch && state.lastTouchEmoji != nil)
            || (config.showStreak && (state.streak ?? 0) > 0)
    }

    var body: some View {
        if hasContent {
            HStack(spacing: 8) {
                if config.showPresence, let online = state.partnerOnline {
                    Circle()
                        .fill(online ? WTheme.mint : Color.white.opacity(0.35))
                        .frame(width: 7, height: 7)
                }
                if config.showMood, let mood = state.partnerMood, !mood.isEmpty {
                    Text(mood)
                        .font(.system(size: 12))
                }
                if config.showTouch, let touch = state.lastTouchEmoji, !touch.isEmpty {
                    Text(touch)
                        .font(.system(size: 12))
                }
                if config.showStreak, let streak = state.streak, streak > 0 {
                    Text("🔥 \(streak)")
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.orange)
                }
                if config.showMood, let note = state.note, !note.isEmpty {
                    Text("“\(note)”")
                        .font(.system(.caption2, design: .rounded).italic())
                        .foregroundStyle(WTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 2)
        }
    }
}

// MARK: - Shared pieces

/// Live countdown; clamps to a celebration once the target date has passed.
/// With `live` off it shows a static "in N Tagen" instead of ticking.
struct CountdownTimerText: View {
    let targetDate: Date
    var live = true

    var body: some View {
        if targetDate <= Date() {
            Text("🎉")
        } else if live {
            Text(timerInterval: Date()...targetDate, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.leading)
        } else {
            Text(staticText)
        }
    }

    private var staticText: String {
        let days = max(SharedDates.calendar.dateComponents(
            [.day],
            from: SharedDates.calendar.startOfDay(for: Date()),
            to: SharedDates.calendar.startOfDay(for: targetDate)).day ?? 0, 0)
        if days == 0 { return WText.t("heute!", "today!") }
        if days == 1 { return WText.t("morgen", "tomorrow") }
        return WText.t("in \(days) Tagen", "in \(days) days")
    }
}

/// Remaining whole days, e.g. "12 Tage" in the trailing island region.
struct CountdownDaysView: View {
    let targetDate: Date
    var palette: WidgetPalette = WidgetPalette(spec: WidgetThemes.spec(id: "night"))

    private var days: Int {
        let calendar = SharedDates.calendar
        let remaining = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: targetDate)).day ?? 0
        return max(remaining, 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("\(days)")
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .foregroundStyle(palette.accentSecondary)
                .contentTransition(.numericText())
            Text(days == 1 ? WText.t("Tag", "day") : WText.t("Tage", "days"))
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(WTheme.textSecondary)
        }
    }
}
#endif
