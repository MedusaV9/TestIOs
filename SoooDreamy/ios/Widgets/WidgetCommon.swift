import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Shared timeline entry (snapshot + resolved style)

struct StudioEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let palette: WidgetPalette
    let layout: String
    let animated: Bool

    static func now(kind: String,
                    intentThemeId: String? = nil,
                    layoutChoice: WidgetLayoutChoice = .auto,
                    animated: Bool? = nil,
                    date: Date = Date()) -> StudioEntry {
        let studio = SharedStore.readStudioConfig()
        let kindConfig = studio.config(for: kind)
        return StudioEntry(
            date: date,
            snapshot: SharedStore.readSnapshot(),
            palette: WidgetPalette.resolve(kind: kind, intentThemeId: intentThemeId),
            layout: WidgetLayoutResolver.resolve(kind: kind, intent: layoutChoice),
            animated: animated ?? kindConfig.animated ?? true)
    }
}

// MARK: - Generic provider (theme + layout intent, day-fresh timeline)

/// One provider for all snapshot-driven widgets: resolves the per-widget
/// intent + studio config and emits entries for now plus the next three
/// midnights so day-based counts stay fresh without the app running.
struct StudioProvider: AppIntentTimelineProvider {
    let kind: String

    func placeholder(in context: Context) -> StudioEntry {
        .now(kind: kind)
    }

    func snapshot(for configuration: CoupleWidgetConfigIntent, in context: Context) async -> StudioEntry {
        .now(kind: kind, intentThemeId: configuration.theme.themeId,
             layoutChoice: configuration.layout)
    }

    func timeline(for configuration: CoupleWidgetConfigIntent, in context: Context) async -> Timeline<StudioEntry> {
        var entries = [StudioEntry.now(kind: kind,
                                       intentThemeId: configuration.theme.themeId,
                                       layoutChoice: configuration.layout)]
        let calendar = SharedDates.calendar
        var day = calendar.startOfDay(for: Date())
        for _ in 0..<3 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
            entries.append(StudioEntry.now(kind: kind,
                                           intentThemeId: configuration.theme.themeId,
                                           layoutChoice: configuration.layout,
                                           date: day))
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

// MARK: - Shared view pieces

/// Pill chip used across widget layouts.
struct WChip: View {
    let text: String
    let palette: WidgetPalette

    var body: some View {
        Text(text)
            .font(.system(.caption2, design: .rounded).weight(.bold))
            .foregroundStyle(palette.textPrimary)
            .lineLimit(1)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(Capsule().fill(palette.chipFill))
    }
}

/// Partner avatar bubble with online dot.
struct WAvatarBadge: View {
    let snapshot: WidgetSnapshot?
    var size: CGFloat = 44

    private var color: Color {
        Color(hexString: snapshot?.partnerColorHex ?? "FF5C8A")
    }

    var body: some View {
        Text(snapshot?.partnerAvatar ?? "💜")
            .font(.system(size: size * 0.48))
            .frame(width: size, height: size)
            .background(Circle().fill(color.opacity(0.28)))
            .overlay(Circle().strokeBorder(color.opacity(0.55), lineWidth: 1.5))
            .overlay(alignment: .bottomTrailing) {
                if snapshot?.partnerOnline == true {
                    Circle()
                        .fill(Color(hexString: "6EE7B7"))
                        .frame(width: size * 0.2, height: size * 0.2)
                        .overlay(Circle().strokeBorder(.black.opacity(0.4), lineWidth: 1))
                }
            }
    }
}

/// Glowing accent heart.
struct WHeart: View {
    let palette: WidgetPalette
    var size: CGFloat = 16

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: size))
            .foregroundStyle(palette.accent)
            .shadow(color: palette.accent.opacity(0.8), radius: 6)
    }
}

/// Live ticking countdown clamped to a celebration once the date passed.
/// `Text(timerInterval:)` keeps ticking without any timeline reloads.
struct WLiveTimer: View {
    let target: Date

    var body: some View {
        if target > Date() {
            Text(timerInterval: Date()...target, countsDown: true)
                .monospacedDigit()
        } else {
            Text("🎉")
        }
    }
}

/// Auto-filling progress bar towards a target date (animates on its own).
struct WLiveProgress: View {
    let start: Date
    let target: Date
    let palette: WidgetPalette

    var body: some View {
        if target > Date() {
            ProgressView(timerInterval: start...target, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(palette.accent)
        }
    }
}

// MARK: - Midnight helper (streak/daily deadline tickers)

enum WidgetClock {
    static func nextMidnight(after date: Date = Date()) -> Date {
        let calendar = SharedDates.calendar
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? date.addingTimeInterval(86400)
    }
}
