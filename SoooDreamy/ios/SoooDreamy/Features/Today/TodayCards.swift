import SwiftUI

// MARK: - Send love (touch grid)

/// 3×2 grid of the six touches (heartbeat, kiss, hug, miss you, tickle,
/// thinking of you). Tapping plays the haptic locally and relays it.
struct SendLoveGrid: View {
    @Environment(AppState.self) private var appState
    @State private var lastSent: TouchKind?
    @State private var sendCount = 0

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(TouchKind.allCases) { kind in
                Button {
                    lastSent = kind
                    sendCount += 1
                    appState.sendTouch(kind)
                } label: {
                    VStack(spacing: 8) {
                        Text(kind.emoji)
                            .font(.system(size: 30))
                            .scaleEffect(lastSent == kind ? 1.15 : 1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: sendCount)
                        Text(L10n.t(kind.titleKey))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.cardBackground,
                                in: RoundedRectangle(cornerRadius: Brand.tileRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.t(kind.titleKey))
                .accessibilityHint(L10n.t("home.touchHint"))
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: sendCount)
    }
}

// MARK: - Latest partner message

struct LatestMessageRow: View {
    @Environment(AppState.self) private var appState
    let message: Message
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                MemberAvatar(member: appState.partner, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(preview)
                        .font(.subheadline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(L10n.relativeShort(message.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                DisclosureChevron()
            }
            .cardSurface(padding: 14)
        }
        .buttonStyle(.plain)
    }

    private var preview: String {
        switch message.type {
        case .text: return message.text ?? ""
        case .letter: return "💌 " + (message.title ?? L10n.t("notif.message.letter"))
        case .voice: return "🎙️ " + L10n.t("notif.message.voice")
        case .photo: return "📷 " + (message.text ?? L10n.t("notif.message.photo"))
        }
    }
}

// MARK: - While you were away

struct MissedInboxCard: View {
    @Environment(AppState.self) private var appState
    let inbox: InboxResponse
    let action: () -> Void

    private var entries: [(key: String, emoji: String, count: Int)] {
        [(key: "home.missed.messages", emoji: "💬", count: inbox.messageCount),
         (key: "home.missed.touches", emoji: "💓", count: inbox.touchCount),
         (key: "home.missed.photos", emoji: "📸", count: inbox.photoCount),
         (key: "home.missed.coupons", emoji: "🎟️", count: inbox.couponCount),
         (key: "home.missed.songs", emoji: "🎶", count: inbox.songCount),
         (key: "home.missed.canvas", emoji: "🎨", count: inbox.canvasCount),
         (key: "home.missed.games", emoji: "🎲", count: inbox.gamesCount),
         (key: "home.missed.daily", emoji: "❓", count: inbox.partnerAnsweredDaily ? 1 : 0)]
            .filter { $0.count > 0 }
    }

    private var teaser: String? {
        guard let last = inbox.messages?.last, last.senderId != appState.memberId,
              let text = last.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        return text
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(L10n.t("home.missedTitle"), systemImage: "moon.zzz.fill")
                        .font(.headline)
                    Spacer()
                    DisclosureChevron()
                }
                HStack(spacing: 6) {
                    ForEach(entries, id: \.key) { entry in
                        Text("\(entry.emoji) \(entry.count)")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .padding(.vertical, 4)
                            .padding(.horizontal, 9)
                            .background(Color.tertiaryCardBackground, in: Capsule())
                            .accessibilityLabel("\(L10n.t(entry.key)): \(entry.count)")
                    }
                }
                if let teaser {
                    Text("„\(teaser)“")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface(padding: 14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Next moment

struct NextEventRow: View {
    @Environment(AppState.self) private var appState
    let event: EventItem
    let days: Int

    var body: some View {
        Button {
            appState.activeTab = .memories
        } label: {
            HStack(spacing: 14) {
                Text(event.emoji)
                    .font(.system(size: 32))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("home.nextEvent"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(event.title)
                        .font(.headline)
                }
                Spacer()
                Text(days == 0 ? L10n.t("home.todayBang")
                     : days == 1 ? L10n.t("home.tomorrow")
                     : L10n.t("home.inDays", ["n": String(days)]))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(days <= 1 ? Color.orange : Color.accentColor)
                    .monospacedDigit()
            }
            .cardSurface()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flashback ("memory of the day")

struct FlashbackCard: View {
    @Environment(AppState.self) private var appState
    let item: TodayModel.Flashback
    @State private var shared = false

    var body: some View {
        Button {
            appState.activeTab = .memories
        } label: {
            HStack(spacing: 12) {
                switch item {
                case .photo(let photo, let daysAgo):
                    RemotePhoto(api: appState.api, path: photo.thumbUrl ?? photo.url)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: Brand.tileRadius, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Label(L10n.t("home.flashback"), systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                        if let caption = photo.caption, !caption.isEmpty {
                            Text(caption)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(2)
                        }
                        Text(L10n.t("home.flashbackDaysAgo", ["n": String(daysAgo)]))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                case .daily(_, let question, let daysAgo):
                    IconTile(systemImage: "text.bubble.fill", tint: .indigo, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Label(L10n.t("home.flashbackQuestion"), systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                        Text(question.text.filled(partner: appState.partnerName, lang: L10n.lang))
                            .font(.subheadline.weight(.medium))
                            .lineLimit(2)
                        Text(L10n.t("home.flashbackDaysAgo", ["n": String(daysAgo)]))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                DisclosureChevron()
            }
            .multilineTextAlignment(.leading)
            .cardSurface(padding: 14)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                share()
            } label: {
                Label(L10n.t("home.flashbackShare"), systemImage: "paperplane")
            }
            .disabled(shared)
        }
    }

    /// Re-posts the memory into the chat — photos as a real photo bubble,
    /// daily questions as text with both answers of back then.
    private func share() {
        guard let api = appState.api else { return }
        Task {
            do {
                switch item {
                case .photo(let photo, let daysAgo):
                    var text = L10n.t("home.flashbackShareHeader", ["n": String(daysAgo)])
                    if let caption = photo.caption, !caption.isEmpty { text += " " + caption }
                    _ = try await api.sendPhotoMessage(photoId: photo.id, text: text)
                case .daily(let entry, let question, let daysAgo):
                    var lines = [L10n.t("home.flashbackShareHeader", ["n": String(daysAgo)]),
                                 question.text.filled(partner: appState.partnerName, lang: L10n.lang)]
                    let myName = appState.me?.name ?? L10n.t("common.you")
                    if let mine = entry.myAnswer, !mine.isEmpty { lines.append("\(myName): \(mine)") }
                    if let theirs = entry.partnerAnswer, !theirs.isEmpty { lines.append("\(appState.partnerName): \(theirs)") }
                    _ = try await api.sendMessage(type: .text, text: lines.joined(separator: "\n"))
                }
                shared = true
                SoundEngine.shared.play(.pop)
                appState.notify(L10n.t("home.flashbackShared"), style: .success)
            } catch {
                appState.handleAPIError(error)
            }
        }
    }
}

// MARK: - Discover (idea of the day)

struct DiscoverIdeaCard: View {
    @Environment(AppState.self) private var appState
    let idea: DateIdea
    @State private var sent = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(idea.emoji)
                .font(.system(size: 34))
                .frame(width: 56, height: 56)
                .background(Color.tertiaryCardBackground,
                            in: RoundedRectangle(cornerRadius: Brand.tileRadius, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(idea.title.resolved(L10n.lang))
                    .font(.headline)
                Text(idea.details.resolved(L10n.lang))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
            Button {
                send()
            } label: {
                Image(systemName: sent ? "checkmark" : "paperplane.fill")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
            .disabled(sent)
            .accessibilityLabel(L10n.t("today.discover.send"))
        }
        .cardSurface()
        .sensoryFeedback(.success, trigger: sent)
    }

    private func send() {
        guard let api = appState.api else { return }
        Task {
            do {
                let text = "\(idea.emoji) \(idea.title.resolved(L10n.lang))\n\(idea.details.resolved(L10n.lang))"
                _ = try await api.sendMessage(type: .text, text: text)
                sent = true
                appState.notify(L10n.t("games.sharedToChat"), style: .success)
            } catch {
                appState.handleAPIError(error)
            }
        }
    }
}

// MARK: - Energy light tile

/// 🟢🟡🔴 after-work energy — my current light, tap to set.
struct EnergyTile: View {
    @Environment(AppState.self) private var appState
    @State private var showSheet = false

    private var current: EnergyLevel? {
        guard let energy = appState.me?.energy,
              energy.setAt > Date().addingTimeInterval(-12 * 3600) else { return nil }
        return EnergyLevel(rawValue: energy.level)
    }

    var body: some View {
        FeatureTile(title: L10n.t("energy.title"),
                    subtitle: current.map { "\($0.emoji) " + L10n.t($0.titleKey) } ?? L10n.t("energy.tile.hint"),
                    systemImage: "bolt.heart.fill",
                    tint: .teal) {
            showSheet = true
        }
        .sheet(isPresented: $showSheet) {
            EnergySheet()
        }
    }
}
