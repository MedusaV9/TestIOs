import SwiftUI
import UIKit

// In-app replicas of the widget & Live Activity renders (Widget Studio and
// the Live Activity screen). These intentionally mirror the WidgetKit code:
// theme palettes come from `WidgetThemes` (hex specs shared with the
// extension) and numbers use the rounded design the widgets themselves use.
// Nothing here is app chrome — the surrounding screens stay fully native.

// MARK: - Palette

/// App-side mirror of the widget palette for a `WidgetThemeSpec`.
struct WidgetPreviewPalette {
    let spec: WidgetThemeSpec

    var backgroundColors: [Color] { spec.backgroundHexes.map { Color(hex: $0) } }
    var accent: Color { Color(hex: spec.accentHex) }
    var accentSecondary: Color { Color(hex: spec.accentSecondaryHex) }
    var textPrimary: Color { spec.isLight ? Color(hex: "26102E") : .white }
    var textSecondary: Color { textPrimary.opacity(0.65) }
    var chipFill: Color { textPrimary.opacity(spec.isLight ? 0.07 : 0.1) }

    var heroGradient: LinearGradient {
        LinearGradient(colors: [accent, accentSecondary], startPoint: .leading, endPoint: .trailing)
    }

    var backgroundGradient: LinearGradient {
        LinearGradient(colors: backgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Theme swatches

/// Horizontal row of theme swatches. `nil` = "Studio default" (only offered
/// when `allowsDefault`). Selection is marked with the accent ring.
struct ThemeSwatchRow: View {
    @Binding var selection: String?
    var allowsDefault = false

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                if allowsDefault {
                    swatch(spec: nil, label: L10n.t("studio.themeDefault"), selected: selection == nil) {
                        selection = nil
                    }
                }
                ForEach(WidgetThemes.all) { spec in
                    swatch(spec: spec, label: spec.name(lang: L10n.lang), selected: selection == spec.id) {
                        selection = spec.id
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func swatch(spec: WidgetThemeSpec?, label: String, selected: Bool,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    if let spec {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(WidgetPreviewPalette(spec: spec).backgroundGradient)
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.tertiaryCardBackground)
                        Image(systemName: "sparkles")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 46, height: 46)
                .overlay {
                    if selected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.accentColor, lineWidth: 2.5)
                    }
                }
                Text(label)
                    .font(.caption2.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Widget frame

/// 150 pt small-widget canvas with the theme gradient behind `content`.
struct WidgetPreviewFrame<Content: View>: View {
    let palette: WidgetPreviewPalette
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(width: 150, height: 150)
            .background(palette.backgroundGradient)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}

// MARK: - Live Activity replica

/// Lock-screen replica of the Couple Pulse / countdown Live Activity.
struct LiveActivityPreview: View {
    let config: LiveActivityConfig
    let partnerName: String

    private var palette: WidgetPreviewPalette {
        WidgetPreviewPalette(spec: WidgetThemes.spec(id: config.themeId))
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text("💞")
                    .font(.system(size: 34))
                VStack(alignment: .leading, spacing: 2) {
                    Text(partnerName)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                    Text(config.liveTimer ? "12:34:56" : (L10n.isGerman ? "in 3 Tagen" : "in 3 days"))
                        .font(.system(.title3, design: .rounded).weight(.heavy))
                        .monospacedDigit()
                        .foregroundStyle(palette.heroGradient)
                    HStack(spacing: 8) {
                        if config.showPresence {
                            HStack(spacing: 4) {
                                Circle().fill(Color.mint).frame(width: 7, height: 7)
                                Text("online")
                                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                                    .foregroundStyle(Color.mint)
                            }
                        }
                        if config.showMood { Text("🥰").font(.system(size: 12)) }
                        if config.showTouch { Text("💓").font(.system(size: 12)) }
                        if config.showStreak {
                            Text("🔥 12")
                                .font(.system(.caption2, design: .rounded).weight(.bold))
                                .foregroundStyle(palette.accentSecondary)
                        }
                    }
                }
                Spacer(minLength: 0)
                if config.showDaysTogether {
                    VStack(spacing: 0) {
                        Text("847")
                            .font(.system(.title3, design: .rounded).weight(.heavy))
                            .foregroundStyle(palette.accentSecondary)
                        Text(L10n.isGerman ? "Tage 💜" : "days 💜")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(palette.textSecondary)
                    }
                }
            }
            if config.showProgress {
                ProgressView(value: 0.62)
                    .tint(palette.accent)
            }
        }
        .padding(14)
        .background(palette.backgroundGradient,
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - Small-widget replicas

struct DaysPreview: View {
    let palette: WidgetPreviewPalette
    let snapshot: WidgetSnapshot?
    let layout: String?

    private var days: Int {
        SharedDates.daysSince(snapshot?.anniversary) ?? snapshot?.daysTogether ?? 1002
    }

    var body: some View {
        Group {
            if layout == "hero" {
                VStack(spacing: 2) {
                    Text("\(days)")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(palette.heroGradient)
                        .minimumScaleFactor(0.4)
                    Text(L10n.isGerman ? "Tage 💜" : "days 💜")
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .foregroundStyle(palette.accent)
                }
            } else if layout == "minimal" {
                VStack(alignment: .leading, spacing: 3) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.accent)
                    Spacer(minLength: 0)
                    Text("\(days)")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                    Text(L10n.isGerman ? "Tage" : "days")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(snapshot?.partnerAvatar ?? "💜")
                            .font(.system(size: 12))
                        Text(snapshot?.partnerName ?? "Schatz")
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(palette.accent)
                    }
                    Spacer(minLength: 0)
                    Text("\(days)")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(palette.heroGradient)
                        .minimumScaleFactor(0.5)
                    Text(L10n.isGerman ? "Tage zusammen" : "days together")
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .foregroundStyle(palette.accent)
                }
                .padding(12)
            }
        }
    }
}

struct CountdownPreview: View {
    let palette: WidgetPreviewPalette
    let snapshot: WidgetSnapshot?
    let pinnedEventId: String?
    let events: [EventItem]

    private var eventInfo: (title: String, emoji: String, days: Int)? {
        if let pinnedEventId,
           let event = events.first(where: { $0.id == pinnedEventId }),
           let days = SharedDates.daysUntil(event.date, repeatsYearly: event.repeatsYearly),
           days >= 0 {
            return (event.title, event.emoji, days)
        }
        if let title = snapshot?.nextEventTitle,
           let days = SharedDates.daysUntil(snapshot?.nextEventDate), days >= 0 {
            return (title, snapshot?.nextEventEmoji ?? "💫", days)
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let info = eventInfo {
                Text(info.emoji)
                    .font(.system(size: 24))
                Spacer(minLength: 0)
                Text(info.title)
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(2)
                Text(L10n.isGerman ? "in \(info.days) Tagen" : "in \(info.days) days")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(palette.heroGradient)
            } else {
                Text("✨")
                    .font(.system(size: 24))
                Spacer(minLength: 0)
                Text(L10n.isGerman ? "Kein Moment geplant" : "No moment planned")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(palette.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(12)
    }
}

struct MoodPreview: View {
    let palette: WidgetPreviewPalette
    let snapshot: WidgetSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(snapshot?.partnerAvatar ?? "💜")
                    .font(.system(size: 12))
                Text(snapshot?.partnerName ?? "Schatz")
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            Text(snapshot?.partnerMood ?? "🥰")
                .font(.system(size: 32))
            if let note = snapshot?.partnerMoodNote, !note.isEmpty {
                Text(note)
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(12)
    }
}

struct DailyPreview: View {
    let palette: WidgetPreviewPalette
    let snapshot: WidgetSnapshot?

    private var question: String {
        (L10n.isGerman ? snapshot?.dailyQuestionDE : snapshot?.dailyQuestionEN)
            ?? (L10n.isGerman ? "Eure Frage des Tages" : "Your daily question")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("💌")
                    .font(.system(size: 12))
                Spacer(minLength: 0)
                if let streak = snapshot?.streak, streak > 1 {
                    Text("🔥 \(streak)")
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .foregroundStyle(palette.accentSecondary)
                }
            }
            Text(question)
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(4)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(12)
    }
}

struct StreakPreview: View {
    let palette: WidgetPreviewPalette
    let snapshot: WidgetSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text("🔥")
                    .font(.system(size: 12))
                Text(L10n.isGerman ? "Antwort-Serie" : "Answer streak")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(palette.accent)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            Text("\(snapshot?.streak ?? 5)")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(palette.heroGradient)
            Text(L10n.isGerman ? "Tage in Folge" : "days in a row")
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(palette.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(12)
    }
}

struct PhotoPreview: View {
    let palette: WidgetPreviewPalette

    var body: some View {
        Group {
            if let data = SharedStore.readCachedPhotoJPEG(), let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                VStack(spacing: 4) {
                    Text("📸")
                        .font(.system(size: 26))
                    Text(L10n.isGerman ? "Noch kein Foto" : "No photo yet")
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(palette.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct SendLovePreview: View {
    let palette: WidgetPreviewPalette
    let snapshot: WidgetSnapshot?

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text(snapshot?.partnerAvatar ?? "💜")
                    .font(.system(size: 12))
                Text(snapshot?.partnerName ?? "Schatz")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(palette.textSecondary)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(["💓", "😘", "🫂", "💭"], id: \.self) { emoji in
                    Text(emoji)
                        .font(.system(size: 16))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(palette.chipFill))
                        .overlay(Circle().strokeBorder(palette.accent.opacity(0.4), lineWidth: 1))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
    }
}
