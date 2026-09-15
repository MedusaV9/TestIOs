import SwiftUI

/// Reusable icon + title + subtitle tile (the "Heute für euch" grid, quick
/// actions). Renders as a grouped card with a tinted symbol tile.
struct FeatureTile: View {
    let title: String
    var subtitle: String? = nil
    let systemImage: String
    var tint: Color = .accentColor
    var badge: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                IconTile(systemImage: systemImage, tint: tint, size: 34)
                Spacer(minLength: 0)
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(tint.opacity(0.18), in: Capsule())
                        .foregroundStyle(tint)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(padding: 14)
        .accessibilityElement(children: .combine)
    }
}

/// The three daily tiles: Tagesfrage · Wie geht's dir? · Heute Abend.
struct TodayTiles: View {
    @Environment(AppState.self) private var appState
    @Binding var showMood: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            NavigationLink(value: TodayRoute.daily) {
                FeatureTile(title: L10n.t("home.dailyQuestion"),
                            subtitle: dailySubtitle,
                            systemImage: "text.bubble.fill",
                            tint: .accentColor,
                            badge: dailyBadge)
            }
            .buttonStyle(.plain)

            FeatureTile(title: L10n.t("today.mood.title"),
                        subtitle: appState.me?.mood.map { "\($0) " + L10n.t("today.mood.set") } ?? L10n.t("today.mood.hint"),
                        systemImage: "face.smiling.fill",
                        tint: .green) {
                showMood = true
            }

            NavigationLink(value: TodayRoute.dateNight) {
                FeatureTile(title: L10n.t("today.tonight"),
                            subtitle: tonightSubtitle,
                            systemImage: "moon.stars.fill",
                            tint: .orange,
                            badge: appState.dateNight?.phase == .live ? L10n.t("datenight.live") : nil)
            }
            .buttonStyle(.plain)
        }
    }

    private var dailySubtitle: String {
        guard let entry = appState.dailyEntry else { return L10n.t("today.daily.new") }
        if entry.bothAnswered { return L10n.t("today.daily.revealed") }
        if entry.myAnswer != nil { return L10n.t("today.daily.waiting") }
        if entry.partnerAnswer != nil { return L10n.t("today.daily.partnerAnswered") }
        return L10n.t("today.daily.new")
    }

    private var dailyBadge: String? {
        guard let streak = appState.dailyEntry?.streak, streak > 1 else { return nil }
        return "🔥 \(streak)"
    }

    private var tonightSubtitle: String {
        if let night = appState.dateNight {
            switch night.phase {
            case .anticipation:
                return night.startsAt.formatted(.dateTime.hour().minute())
            case .live:
                return night.title ?? L10n.t("datenight.live")
            case .afterglow:
                return L10n.t("datenight.phase.afterglow")
            }
        }
        return L10n.t("today.tonight.hint")
    }
}
