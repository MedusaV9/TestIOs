import SwiftUI

// MARK: - First-week quest

struct QuestCard: View {
    @Environment(AppState.self) private var appState
    @State private var expanded = true

    /// Step id → (symbol, tab to jump to). Steps mirror the server's list.
    private static let stepMeta: [String: (systemImage: String, tab: AppTab)] = [
        "touch": ("heart.fill", .home),
        "message": ("bubble.left.fill", .chat),
        "daily": ("text.bubble.fill", .home),
        "photo": ("photo.fill", .memories),
        "canvas": ("paintpalette.fill", .memories),
        "checkin": ("sunrise.fill", .home),
        "game": ("gamecontroller.fill", .us),
    ]

    var body: some View {
        if let quest = appState.quest, quest.isNewCouple, !quest.done {
            card(quest)
        }
    }

    private func card(_ quest: QuestState) -> some View {
        let doneCount = quest.steps.filter(\.done).count
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.snappy) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    IconTile(systemImage: "map.fill", tint: .orange, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("quest.card.title"))
                            .font(.headline)
                        Text(L10n.t("quest.card.subtitle"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Text(L10n.t("quest.progress", ["done": String(doneCount), "total": String(quest.steps.count)]))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)

            ProgressView(value: Double(doneCount), total: Double(max(1, quest.steps.count)))
                .tint(.orange)

            if expanded {
                VStack(spacing: 0) {
                    ForEach(quest.steps) { step in
                        stepRow(step)
                        if step.id != quest.steps.last?.id { Divider() }
                    }
                }
                Text(L10n.t("quest.bonus", ["xp": String(quest.bonusXp)]))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .cardSurface()
    }

    private func stepRow(_ step: QuestStep) -> some View {
        let meta = Self.stepMeta[step.id] ?? ("sparkles", .home)
        return Button {
            guard !step.done else { return }
            appState.activeTab = meta.tab
        } label: {
            HStack(spacing: 12) {
                Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(step.done ? Color.green : Color.secondary)
                Image(systemName: meta.systemImage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(L10n.t("quest.step.\(step.id)"))
                    .font(.subheadline)
                    .foregroundStyle(step.done ? .secondary : .primary)
                    .strikethrough(step.done)
                Spacer(minLength: 0)
                if !step.done { DisclosureChevron() }
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .disabled(step.done)
    }
}

// MARK: - Relationship level

struct LevelCard: View {
    @Environment(AppState.self) private var appState
    @State private var showShelf = false

    var body: some View {
        if let level = appState.levelState {
            Button {
                showShelf = true
            } label: {
                HStack(spacing: 14) {
                    LevelRing(level: level.level, progress: level.progress, size: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.t("level.card.title"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(level.title.resolved)
                            .font(.headline)
                        Text(progressLine(level))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    let unlocked = appState.badges.filter(\.unlocked).count
                    if unlocked > 0 {
                        Label("\(unlocked)", systemImage: "medal.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                            .monospacedDigit()
                    }
                    DisclosureChevron()
                }
                .multilineTextAlignment(.leading)
                .cardSurface(padding: 14)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("level.card.level", ["n": String(level.level)]) + ", " + level.title.resolved)
            .sheet(isPresented: $showShelf) {
                BadgeShelfView()
            }
        }
    }

    private func progressLine(_ level: LevelState) -> String {
        if level.level >= level.maxTitleLevel { return L10n.t("level.card.max") }
        let remaining = max(0, level.nextLevelXp - level.levelXp)
        return L10n.t("level.card.toNext", ["xp": String(remaining), "n": String(level.level + 1)])
    }
}

/// Circular XP ring with the level number.
struct LevelRing: View {
    let level: Int
    let progress: Double
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.tertiaryCardBackground, lineWidth: size * 0.11)
            Circle()
                .trim(from: 0, to: max(0.02, min(1, progress)))
                .stroke(Color.accentColor.gradient,
                        style: StrokeStyle(lineWidth: size * 0.11, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(level)")
                .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.6), value: progress)
        .accessibilityLabel(L10n.t("level.card.level", ["n": String(level)]))
    }
}

// MARK: - Ceremonies (sheets)

struct LevelUpCeremonyView: View {
    @Environment(\.dismiss) private var dismiss
    let ceremony: LevelUpPayload
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            LevelRing(level: ceremony.level, progress: 1, size: 130)
                .scaleEffect(appeared ? 1 : 0.4)
            VStack(spacing: 8) {
                Text(L10n.t("level.up.title"))
                    .font(.largeTitle.weight(.bold))
                Text(L10n.t("level.up.subtitle", ["n": String(ceremony.level)]))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(ceremony.title.resolved)
                    .font(.headline)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 18)
                    .background(Color.accentColor.opacity(0.14), in: Capsule())
                    .foregroundStyle(Color.accentColor)
            }
            .multilineTextAlignment(.center)
            Spacer()
            Button(L10n.t("level.up.continue")) { dismiss() }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .padding(.bottom, 24)
        }
        .padding(30)
        .overlay {
            FloatingHeartsView(emojis: ["🎉", "💜", "✨", "🌟", "🩷"], count: 26)
                .allowsHitTesting(false)
        }
        .presentationDetents([.large])
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { appeared = true }
        }
    }
}

struct BadgeCeremonyView: View {
    @Environment(\.dismiss) private var dismiss
    let badge: BadgeState
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            MedalView(badge: badge, revealSecret: true, size: 140)
                .scaleEffect(appeared ? 1 : 0.3)
                .rotationEffect(.degrees(appeared ? 0 : -18))
            VStack(spacing: 8) {
                Text(L10n.t("badges.awarded.title"))
                    .font(.title.weight(.bold))
                Text(BadgeCatalog.name(badge.id))
                    .font(.title3.weight(.semibold))
                Text(BadgeCatalog.desc(badge.id))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if badge.secret {
                    Label(L10n.t("badges.secret"), systemImage: "eye.slash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.purple)
                }
            }
            .multilineTextAlignment(.center)
            Spacer()
            Button(L10n.t("level.up.continue")) { dismiss() }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .padding(.bottom, 24)
        }
        .padding(30)
        .overlay {
            FloatingHeartsView(emojis: ["🏅", "✨", "🌟", "💜"], count: 18)
                .allowsHitTesting(false)
        }
        .presentationDetents([.large])
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) { appeared = true }
        }
    }
}

// MARK: - Badges

/// Client-side display metadata per badge id. Names/descriptions live in
/// PlatformL10n; unknown ids (future server versions) degrade gracefully.
enum BadgeCatalog {
    struct Meta {
        let emoji: String
        let tint: Color
    }

    static let metas: [String: Meta] = [
        "first_touch": Meta(emoji: "💓", tint: .pink),
        "touches_500": Meta(emoji: "⚡️", tint: .yellow),
        "hundred_kisses": Meta(emoji: "💋", tint: .red),
        "hug_marathon": Meta(emoji: "🫂", tint: .purple),
        "streak_week": Meta(emoji: "🔥", tint: .orange),
        "streak_month": Meta(emoji: "🌋", tint: .red),
        "checkin_month": Meta(emoji: "☀️", tint: .yellow),
        "wordle_ten": Meta(emoji: "🔤", tint: .mint),
        "gamer_25": Meta(emoji: "🎲", tint: .indigo),
        "photographers": Meta(emoji: "📸", tint: .blue),
        "picasso": Meta(emoji: "🎨", tint: .purple),
        "bucket_10": Meta(emoji: "🪄", tint: .mint),
        "songbirds": Meta(emoji: "🎶", tint: .blue),
        "level_5": Meta(emoji: "🌟", tint: .yellow),
        "level_10": Meta(emoji: "👑", tint: .yellow),
        "night_owls": Meta(emoji: "🦉", tint: .indigo),
        "early_birds": Meta(emoji: "🐦", tint: .mint),
        "icon_gifted": Meta(emoji: "🎁", tint: .pink),
        "duet_partners": Meta(emoji: "🫀", tint: .red),
        "quest_complete": Meta(emoji: "🗺️", tint: .orange),
    ]

    static func meta(_ id: String) -> Meta {
        metas[id] ?? Meta(emoji: "🏅", tint: .yellow)
    }

    static func name(_ id: String) -> String {
        let key = "badge.name.\(id)"
        let text = L10n.t(key)
        return text == key ? id : text
    }

    static func desc(_ id: String) -> String {
        let key = "badge.desc.\(id)"
        let text = L10n.t(key)
        return text == key ? "" : text
    }
}

/// Medal: tinted disc with the badge emoji; locked medals are dimmed,
/// secret + locked ones hide their identity.
struct MedalView: View {
    let badge: BadgeState
    var revealSecret = false
    var size: CGFloat = 64

    private var disguised: Bool { badge.secret && !badge.unlocked && !revealSecret }
    private var meta: BadgeCatalog.Meta { BadgeCatalog.meta(badge.id) }

    var body: some View {
        ZStack {
            Circle()
                .fill(badge.unlocked || revealSecret ? meta.tint.gradient : Color.tertiaryCardBackground.gradient)
            Circle()
                .strokeBorder(.white.opacity(badge.unlocked ? 0.35 : 0.12), lineWidth: size * 0.05)
            Text(disguised ? "?" : meta.emoji)
                .font(.system(size: size * 0.46, weight: .bold))
                .foregroundStyle(disguised ? Color.secondary : Color.primary)
                .opacity(badge.unlocked || revealSecret ? 1 : 0.45)
        }
        .frame(width: size, height: size)
        .saturation(badge.unlocked || revealSecret ? 1 : 0)
        .accessibilityLabel(disguised ? L10n.t("badges.secret") : BadgeCatalog.name(badge.id))
    }
}

/// Trophy shelf: level details + all medals with progress.
struct BadgeShelfView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private var unlockedCount: Int { appState.badges.filter(\.unlocked).count }

    var body: some View {
        NavigationStack {
            List {
                if let level = appState.levelState {
                    Section {
                        HStack(spacing: 16) {
                            LevelRing(level: level.level, progress: level.progress, size: 84)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(level.title.resolved)
                                    .font(.title3.weight(.bold))
                                Text(L10n.t("level.card.xp", ["xp": String(level.xp)]))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if level.level < level.maxTitleLevel {
                                    Text(L10n.t("level.card.toNext",
                                                ["xp": String(max(0, level.nextLevelXp - level.levelXp)),
                                                 "n": String(level.level + 1)]))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(L10n.t("level.card.max"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                Section {
                    ForEach(appState.badges) { badge in
                        badgeRow(badge)
                    }
                } header: {
                    Text(L10n.t("badges.title"))
                } footer: {
                    Text(L10n.t("badges.shelf.subtitle",
                                ["n": String(unlockedCount), "total": String(appState.badges.count)]))
                }
            }
            .navigationTitle(L10n.t("badges.shelf.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.done")) { dismiss() }
                }
            }
        }
    }

    private func badgeRow(_ badge: BadgeState) -> some View {
        let disguised = badge.secret && !badge.unlocked
        return HStack(spacing: 14) {
            MedalView(badge: badge, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(disguised ? L10n.t("badges.secret") : BadgeCatalog.name(badge.id))
                    .font(.body.weight(.medium))
                Text(disguised ? L10n.t("badges.secretHint") : BadgeCatalog.desc(badge.id))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if badge.unlocked, let at = badge.unlockedAt {
                    Text(L10n.t("badges.unlockedAt", ["date": at.formatted(date: .abbreviated, time: .omitted)]))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !disguised, badge.progress.target > 1 {
                    ProgressView(value: Double(min(badge.progress.current, badge.progress.target)),
                                 total: Double(max(1, badge.progress.target)))
                        .tint(BadgeCatalog.meta(badge.id).tint)
                    Text("\(min(badge.progress.current, badge.progress.target))/\(badge.progress.target)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else if !badge.unlocked {
                    Text(L10n.t("badges.locked"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
