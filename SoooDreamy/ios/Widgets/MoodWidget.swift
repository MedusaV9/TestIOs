import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Views

struct MoodWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StudioEntry

    private var palette: WidgetPalette { entry.palette }

    private var partnerName: String {
        entry.snapshot?.partnerName ?? WText.t("Dein Schatz", "Your love")
    }

    private var mood: String? {
        guard let mood = entry.snapshot?.partnerMood, !mood.isEmpty else { return nil }
        return mood
    }

    private var moodNote: String? {
        guard let note = entry.snapshot?.partnerMoodNote, !note.isEmpty else { return nil }
        return note
    }

    private var energyEmoji: String? {
        switch entry.snapshot?.partnerEnergyLevel {
        case "green": return "🟢"
        case "yellow": return "🟡"
        case "red": return "🔴"
        default: return nil
        }
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular: rectangular
            case .accessoryInline: inline
            case .systemMedium: medium
            case .systemLarge: large
            default: small
            }
        }
        .widgetChrome(palette)
        .widgetURL(URL(string: "sooodreamy://tab/home"))
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                WAvatarBadge(snapshot: entry.snapshot, size: 26)
                Text(partnerName)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            if let mood {
                Text(mood)
                    .font(.system(size: 38))
                    .minimumScaleFactor(0.6)
                if let moodNote {
                    Text(moodNote)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                if let updatedAt = entry.snapshot?.partnerMoodUpdatedAt {
                    Text(updatedAt, style: .relative)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                }
            } else {
                emptyState
            }
        }
    }

    private var medium: some View {
        HStack(spacing: 14) {
            WAvatarBadge(snapshot: entry.snapshot, size: 46)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(partnerName)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                    if entry.snapshot?.partnerOnline == true {
                        Text("online")
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .foregroundStyle(Color(hexString: "6EE7B7"))
                    }
                }
                if mood != nil {
                    if let moodNote {
                        Text(moodNote)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(palette.textPrimary.opacity(0.9))
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    if let updatedAt = entry.snapshot?.partnerMoodUpdatedAt {
                        Text(updatedAt, style: .relative)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(palette.textSecondary)
                    }
                    if let energyEmoji {
                        Text("\(energyEmoji) \(entry.snapshot?.partnerEnergyNote ?? WText.t("Energie", "Energy"))")
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(1)
                    }
                } else {
                    Text(WText.t("Noch keine Stimmung geteilt", "No mood shared yet"))
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(palette.textSecondary)
                }
            }
            Spacer(minLength: 8)
            Text(mood ?? "💭")
                .font(.system(size: 54))
                .minimumScaleFactor(0.6)
        }
    }

    /// Large: mood hero + last touch + streak — a little partner dashboard.
    private var large: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                WAvatarBadge(snapshot: entry.snapshot, size: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text(partnerName)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                    Text(entry.snapshot?.partnerOnline == true
                         ? "online" : WText.t("gerade nicht da", "away right now"))
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(entry.snapshot?.partnerOnline == true
                                         ? Color(hexString: "6EE7B7") : palette.textSecondary)
                }
                Spacer(minLength: 0)
                WHeart(palette: palette)
            }
            Spacer(minLength: 0)
            Text(mood ?? "💭")
                .font(.system(size: 92))
                .minimumScaleFactor(0.5)
            if let moodNote {
                Text("“\(moodNote)”")
                    .font(.system(.subheadline, design: .rounded).italic())
                    .foregroundStyle(palette.textPrimary.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            if let updatedAt = entry.snapshot?.partnerMoodUpdatedAt {
                Text(updatedAt, style: .relative)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                if let energyEmoji {
                    WChip(text: energyEmoji + " " + WText.t("Energie", "Energy"), palette: palette)
                }
                if let title = entry.snapshot?.goalTitle,
                   let percent = entry.snapshot?.goalPercent {
                    WChip(text: "\(entry.snapshot?.goalEmoji ?? "🎯") \(Int(percent))% \(title)",
                          palette: palette)
                }
                if let level = entry.snapshot?.levelNumber {
                    WChip(text: "✨ L\(level)", palette: palette)
                }
                if let touchType = entry.snapshot?.lastTouchType {
                    WChip(text: TouchEmoji.map(touchType) + " "
                          + WText.t("zuletzt", "last"), palette: palette)
                }
                if let streak = entry.snapshot?.streak, streak > 0 {
                    WChip(text: "🔥 \(streak)", palette: palette)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if entry.snapshot == nil {
            WidgetSetupHint(palette: palette)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("💭")
                    .font(.system(size: 32))
                Text(WText.t("Noch keine Stimmung", "No mood yet"))
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private var inline: some View {
        Text(mood.map { "\($0) \(partnerName)" }
             ?? WText.t("💭 \(partnerName)", "💭 \(partnerName)"))
    }

    private var rectangular: some View {
        HStack(spacing: 8) {
            Text(mood ?? "💭")
                .font(.system(size: 26))
            VStack(alignment: .leading, spacing: 1) {
                Text(partnerName)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .lineLimit(1)
                    .widgetAccentable()
                if mood != nil {
                    if let moodNote {
                        Text(moodNote)
                            .font(.system(.caption, design: .rounded))
                            .lineLimit(1)
                    }
                    if let updatedAt = entry.snapshot?.partnerMoodUpdatedAt {
                        Text(updatedAt, style: .relative)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(WText.t("Noch keine Stimmung", "No mood yet"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Widget

struct MoodWidget: Widget {
    let kind = WidgetKindID.mood

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind,
                               intent: CoupleWidgetConfigIntent.self,
                               provider: StudioProvider(kind: kind)) { entry in
            MoodWidgetView(entry: entry)
        }
        .configurationDisplayName(WText.t("Stimmung", "Mood"))
        .description(WText.t("Zeigt die aktuelle Stimmung deines Schatzes.",
                             "Shows your partner's current mood."))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryRectangular, .accessoryInline])
    }
}
