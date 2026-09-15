import WidgetKit
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit

// v3.0 Date-Night Live Activity (Agent C): evening countdown with phases
// (Vorfreude ✨ → Los geht's 💞 → Ausklang 🌙). The "Weiter" button is a
// LiveActivityIntent (DateNightAdvanceIntent, Shared/) — it flips the phase
// locally AND tells the server so the partner's activity follows.

private func dnPalette(_ config: LiveActivityConfig?) -> WidgetPalette {
    WidgetPalette(spec: WidgetThemes.spec(id: config?.themeId ?? "night"))
}

private enum DNText {
    static func phaseLabel(_ phase: String) -> String {
        switch phase {
        case DateNightPhaseID.live: return WText.t("Los geht's!", "It's on!")
        case DateNightPhaseID.afterglow: return WText.t("Ausklang", "Afterglow")
        default: return WText.t("Vorfreude", "Anticipation")
        }
    }
}

struct DateNightLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DateNightActivityAttributes.self) { context in
            DateNightLockScreenView(attributes: context.attributes, state: context.state)
        } dynamicIsland: { context in
            let palette = dnPalette(context.state.config)
            let emoji = context.state.emoji ?? DateNightPhaseID.emoji(context.state.phase)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(emoji)
                        .font(.system(size: 30))
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.title ?? WText.t("Date-Night", "Date night"))
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        DateNightPhaseLine(state: context.state, palette: palette)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(DateNightPhaseID.emoji(context.state.phase))
                        .font(.system(size: 24))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DateNightControlsRow(state: context.state, palette: palette)
                }
            } compactLeading: {
                Text(emoji)
            } compactTrailing: {
                if context.state.phase == DateNightPhaseID.anticipation,
                   context.state.startsAt > Date() {
                    Text(timerInterval: Date()...context.state.startsAt, countsDown: true)
                        .monospacedDigit()
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .foregroundStyle(palette.accent)
                        .frame(maxWidth: 56)
                } else {
                    Text(DateNightPhaseID.emoji(context.state.phase))
                }
            } minimal: {
                Text(DateNightPhaseID.emoji(context.state.phase))
            }
            .keylineTint(palette.accent)
        }
    }
}

// MARK: - Lock screen banner

struct DateNightLockScreenView: View {
    let attributes: DateNightActivityAttributes
    let state: DateNightActivityAttributes.ContentState

    private var palette: WidgetPalette { dnPalette(state.config) }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                Text(state.emoji ?? DateNightPhaseID.emoji(state.phase))
                    .font(.system(size: 38))
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title ?? WText.t("Date-Night", "Date night"))
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    DateNightPhaseLine(state: state, palette: palette)
                    if let partner = attributes.partnerName, !partner.isEmpty {
                        Text(WText.t("mit \(partner) 💞", "with \(partner) 💞"))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(WTheme.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                phaseBadge
            }
            DateNightControlsRow(state: state, palette: palette)
        }
        .padding(16)
        .activityBackgroundTint(Color(hexString: WidgetThemes.spec(
            id: state.config?.themeId ?? "night").backgroundHexes.first ?? "17062A")
            .opacity(0.92))
        .activitySystemActionForegroundColor(palette.accent)
    }

    private var phaseBadge: some View {
        VStack(spacing: 2) {
            Text(DateNightPhaseID.emoji(state.phase))
                .font(.system(size: 24))
            Text(DNText.phaseLabel(state.phase))
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(palette.accentSecondary)
        }
    }
}

// MARK: - Shared pieces

/// The activity's "pulse line": countdown while waiting, cheer when live,
/// a soft echo during the afterglow.
struct DateNightPhaseLine: View {
    let state: DateNightActivityAttributes.ContentState
    let palette: WidgetPalette

    var body: some View {
        switch state.phase {
        case DateNightPhaseID.live:
            Text(WText.t("Es läuft — genießt es! 💞", "It's on — enjoy! 💞"))
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .foregroundStyle(palette.heroGradient)
        case DateNightPhaseID.afterglow:
            Text(WText.t("Was für ein Abend 🌙", "What an evening 🌙"))
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .foregroundStyle(palette.heroGradient)
        default:
            if state.startsAt > Date() {
                Text(timerInterval: Date()...state.startsAt, countsDown: true)
                    .monospacedDigit()
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(palette.heroGradient)
            } else {
                Text(WText.t("Gleich geht's los ✨", "About to start ✨"))
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .foregroundStyle(palette.heroGradient)
            }
        }
    }
}

/// Phase progress dots + the "Weiter" intent button (hidden in afterglow —
/// the evening fades out by itself).
struct DateNightControlsRow: View {
    let state: DateNightActivityAttributes.ContentState
    let palette: WidgetPalette

    private var phaseIndex: Int {
        switch state.phase {
        case DateNightPhaseID.live: return 1
        case DateNightPhaseID.afterglow: return 2
        default: return 0
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index <= phaseIndex ? palette.accent : Color.white.opacity(0.18))
                        .frame(width: index == phaseIndex ? 22 : 12, height: 5)
                }
            }
            Spacer(minLength: 0)
            if DateNightPhaseID.next(state.phase) != nil {
                Button(intent: DateNightAdvanceIntent()) {
                    HStack(spacing: 4) {
                        Text(WText.t("Weiter", "Next"))
                            .font(.system(.caption, design: .rounded).weight(.bold))
                        Image(systemName: "chevron.right.2")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Capsule().fill(palette.accent.opacity(0.28)))
                    .overlay(Capsule().strokeBorder(palette.accent.opacity(0.6), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            }
        }
    }
}
#endif
