import SwiftUI

/// Push destinations inside the "Wir" tab.
enum UsRoute: String, Hashable, Identifiable {
    // Games
    case wordle, quiz, thisorthat, wouldyourather, truthordare, questions36, emojiriddle
    case connectfour, photomemory, quizduel
    case battleship, pictionary, kniffel, movieroulette, stadtlandfluss, twotruths
    case dailyquests, season, replay, record
    // Rituals & activities
    case dateNight, daymemo, capsules, goals, weekplan, needsHistory, magazine, badges

    var id: String { rawValue }
}

/// Static catalog metadata for every game: symbol, tint, whether it needs
/// both partners live, and the hub destination.
struct GameInfo: Identifiable, Hashable {
    let kind: GameKind
    let route: UsRoute
    let systemImage: String
    let tint: Color
    let multiplayer: Bool

    var id: GameKind { kind }
    var title: String { L10n.t("games.card.\(route.rawValue).title") }
    var teaser: String { L10n.t("games.card.\(route.rawValue).teaser") }
}

enum GameCatalog {
    static let all: [GameInfo] = [
        GameInfo(kind: .quiz, route: .quiz, systemImage: "brain.head.profile", tint: .pink, multiplayer: true),
        GameInfo(kind: .quizduel, route: .quizduel, systemImage: "bolt.fill", tint: .orange, multiplayer: true),
        GameInfo(kind: .photomemory, route: .photomemory, systemImage: "square.grid.2x2.fill", tint: .mint, multiplayer: true),
        GameInfo(kind: .connectfour, route: .connectfour, systemImage: "circle.grid.3x3.fill", tint: .red, multiplayer: true),
        GameInfo(kind: .battleship, route: .battleship, systemImage: "ferry.fill", tint: .blue, multiplayer: true),
        GameInfo(kind: .pictionary, route: .pictionary, systemImage: "paintbrush.pointed.fill", tint: .yellow, multiplayer: true),
        GameInfo(kind: .kniffel, route: .kniffel, systemImage: "dice.fill", tint: .purple, multiplayer: true),
        GameInfo(kind: .movieroulette, route: .movieroulette, systemImage: "popcorn.fill", tint: .pink, multiplayer: true),
        GameInfo(kind: .stadtlandfluss, route: .stadtlandfluss, systemImage: "globe.europe.africa.fill", tint: .teal, multiplayer: true),
        GameInfo(kind: .twotruths, route: .twotruths, systemImage: "theatermask.and.paintbrush.fill", tint: .indigo, multiplayer: true),
        GameInfo(kind: .dailyquests, route: .dailyquests, systemImage: "flag.checkered", tint: .orange, multiplayer: true),
        GameInfo(kind: .thisorthat, route: .thisorthat, systemImage: "arrow.left.arrow.right", tint: .purple, multiplayer: true),
        GameInfo(kind: .wouldyourather, route: .wouldyourather, systemImage: "questionmark.bubble.fill", tint: .indigo, multiplayer: true),
        GameInfo(kind: .truthordare, route: .truthordare, systemImage: "theatermasks.fill", tint: .red, multiplayer: true),
        GameInfo(kind: .questions36, route: .questions36, systemImage: "sparkles", tint: .blue, multiplayer: false),
        GameInfo(kind: .emojiriddle, route: .emojiriddle, systemImage: "puzzlepiece.fill", tint: .yellow, multiplayer: true),
    ]

    /// "Beliebte Spiele" strip on the hub.
    static let popular: [GameInfo] = [
        info(.photomemory), info(.quizduel), info(.connectfour), info(.quiz)
    ].compactMap { $0 }

    /// "Gemeinsame Momente" strip (activities rather than duels).
    static let moments: [GameInfo] = [
        info(.dailyquests), info(.stadtlandfluss), info(.truthordare), info(.twotruths)
    ].compactMap { $0 }

    static func info(_ kind: GameKind) -> GameInfo? {
        all.first { $0.kind == kind }
    }

    static func route(for kind: GameKind) -> UsRoute? {
        info(kind)?.route
    }

    /// Localized display name of a game type.
    static func title(for kind: GameKind) -> String {
        L10n.t("games.card.\(kind.rawValue).title")
    }

    /// Emoji of a game type (recap lines, replay rows, shared texts).
    static func emoji(for kind: GameKind) -> String {
        switch kind {
        case .quiz: return "🧠"
        case .thisorthat: return "⚡️"
        case .wouldyourather: return "🤯"
        case .truthordare: return "🎭"
        case .questions36: return "💫"
        case .emojiriddle: return "🧩"
        case .connectfour: return "🔴"
        case .photomemory: return "🖼️"
        case .quizduel: return "⚡️"
        case .battleship: return "🚢"
        case .pictionary: return "🎨"
        case .kniffel: return "🎲"
        case .movieroulette: return "🍿"
        case .stadtlandfluss: return "🗺️"
        case .twotruths: return "🤥"
        case .dailyquests: return "⚔️"
        }
    }
}

// MARK: - Shared game scaffolding

/// The realtime games need both partners.
struct GameNeedsPartnerView: View {
    var body: some View {
        ContentUnavailableView(L10n.t("games.needPartner.title"),
                               systemImage: "person.2.slash",
                               description: Text(L10n.t("games.needPartner.body")))
    }
}

/// Lobby: waiting for the partner to join (I created the session) or a big
/// join button (the partner invited me).
struct GameLobbyView: View {
    @Environment(AppState.self) private var appState
    let engine: GameEngine
    var accent: Color = .accentColor

    private var isMine: Bool { engine.session?.createdBy == appState.memberId }

    var body: some View {
        VStack(spacing: 16) {
            if isMine {
                MemberAvatar(member: appState.partner, size: 64, showPresence: true)
                Text(L10n.t("games.waitingFor", ["name": appState.partnerName]))
                    .font(.title3.weight(.semibold))
                Text(appState.partner?.online == true
                     ? L10n.t("games.invite.waitingBody", ["name": appState.partnerName])
                     : L10n.t("games.invite.offline", ["name": appState.partnerName]))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProgressView()
                Button(L10n.t("games.invite.cancel"), role: .cancel) {
                    Task { await engine.end(api: appState.api, result: nil) }
                }
                .buttonStyle(.bordered)
                .disabled(engine.busy)
            } else {
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(accent)
                Text(L10n.t("games.lobby.joinTitle", ["name": appState.partnerName]))
                    .font(.title3.weight(.semibold))
                Text(L10n.t("games.lobby.joinBody"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    Task {
                        if await engine.join(api: appState.api) {
                            SoundEngine.shared.play(.pop)
                        }
                    }
                } label: {
                    Text(L10n.t("games.invite.join"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(engine.busy)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .cardSurface(padding: 22)
    }
}

/// Caption while waiting for the partner's move; mentions when the partner
/// is offline so nobody stares at a frozen screen.
struct GameWaitingHint: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                ProgressView()
                Text(L10n.t("games.waitingFor", ["name": appState.partnerName]))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            if appState.partner?.online != true {
                Text(L10n.t("games.partnerOffline", ["name": appState.partnerName]))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}

/// Header shown at the top of a game screen while a session is running:
/// round/score line and an optional progress bar.
struct GameHeaderBar: View {
    let title: String
    var subtitle: String? = nil
    var progress: Double? = nil
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            if let progress {
                ProgressView(value: min(max(progress, 0), 1))
                    .tint(tint)
            }
        }
        .cardSurface(padding: 14)
    }
}

/// Score strip: both members with their points, the leader highlighted.
struct GameScoreStrip: View {
    @Environment(AppState.self) private var appState
    let myScore: Int
    let partnerScore: Int
    /// Local pass-and-play without a paired partner ("Team 2").
    var partnerFallbackName: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            scoreCell(member: appState.me, score: myScore, leading: myScore > partnerScore, fallback: nil)
            Text(":")
                .font(.title2.weight(.bold))
                .foregroundStyle(.secondary)
            scoreCell(member: appState.partner, score: partnerScore, leading: partnerScore > myScore,
                      fallback: partnerFallbackName)
        }
        .frame(maxWidth: .infinity)
        .cardSurface(padding: 12)
        .accessibilityElement(children: .combine)
    }

    private func scoreCell(member: Member?, score: Int, leading: Bool, fallback: String?) -> some View {
        HStack(spacing: 10) {
            MemberAvatar(member: member, size: 36)
            VStack(alignment: .leading, spacing: 0) {
                Text(member?.name ?? fallback ?? "–")
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
                Text("\(score)")
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(leading ? Color.accentColor : Color.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Result card at the end of a game (winner / tie), with actions.
struct GameResultCard<Actions: View>: View {
    let title: String
    var subtitle: String? = nil
    var emoji: String = "🏆"
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(spacing: 14) {
            Text(emoji)
                .font(.system(size: 52))
                .accessibilityHidden(true)
            Text(title)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            actions
        }
        .frame(maxWidth: .infinity)
        .cardSurface(padding: 22)
    }
}

/// Start screen for a game: hero, rules, start button.
struct GameStartCard<Options: View>: View {
    let info: GameInfo
    let rules: String
    let starting: Bool
    let onStart: () -> Void
    @ViewBuilder let options: Options

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                IconTile(systemImage: info.systemImage, tint: info.tint, size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.title)
                        .font(.title3.weight(.bold))
                    Text(L10n.t(info.multiplayer ? "games.badge.multiplayer" : "games.badge.local"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            Text(rules)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            options
            Button {
                onStart()
            } label: {
                HStack {
                    if starting { ProgressView().tint(.white) }
                    Text(L10n.t("games.start"))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(starting)
        }
        .cardSurface()
    }
}
