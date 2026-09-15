import SwiftUI

/// The partner at a glance: presence, mood, energy light, now playing.
struct PartnerCard: View {
    @Environment(AppState.self) private var appState
    @Binding var showMood: Bool

    private var partner: Member? { appState.partner }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            MemberAvatar(member: partner, size: 56, showPresence: true)

            VStack(alignment: .leading, spacing: 6) {
                Text(partner?.name ?? "–")
                    .font(.headline)
                Text(presenceText)
                    .font(.subheadline)
                    .foregroundStyle(partner?.online == true ? Color.green : Color.secondary)

                if let mood = partner?.mood {
                    Label {
                        Text(moodText(note: partner?.moodNote))
                            .lineLimit(2)
                    } icon: {
                        Text(mood)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                if let energy = partner?.energy, let level = EnergyLevel(rawValue: energy.level),
                   energy.setAt > Date().addingTimeInterval(-12 * 3600) {
                    Label {
                        Text(nonEmpty(energy.note) ?? L10n.t(level.titleKey))
                            .lineLimit(1)
                    } icon: {
                        Text(level.emoji)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                if let np = nowPlaying {
                    Label(np.artist.map { "\(np.title) · \($0)" } ?? np.title, systemImage: "music.note")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Button {
                showMood = true
            } label: {
                VStack(spacing: 4) {
                    Text(appState.me?.mood ?? "＋")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(Color.tertiaryCardBackground, in: Circle())
                    Text(L10n.t("home.yourMood"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("home.setMood"))
        }
        .cardSurface()
    }

    private func moodText(note: String?) -> String {
        nonEmpty(note) ?? L10n.t("home.moodOf", ["name": partner?.name ?? ""])
    }

    private func nonEmpty(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return text
    }

    private var presenceText: String {
        if partner?.online == true { return L10n.t("presence.online") }
        if let lastSeen = partner?.lastSeenAt {
            return L10n.t("presence.lastSeen", ["time": L10n.relativeShort(lastSeen)])
        }
        return L10n.t("presence.offline")
    }

    /// Fresh (< 60 min) now-playing status — mirrors the server expiry.
    private var nowPlaying: NowPlaying? {
        guard let np = partner?.nowPlaying, np.setAt > Date().addingTimeInterval(-3600) else { return nil }
        return np
    }
}
