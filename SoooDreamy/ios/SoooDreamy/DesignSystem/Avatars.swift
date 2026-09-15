import SwiftUI

/// Member avatar: emoji on the member's color, optional presence dot.
struct MemberAvatar: View {
    let emoji: String?
    let colorHex: String?
    var size: CGFloat = 44
    var online: Bool? = nil

    private var tint: Color { Color(hex: colorHex ?? "A855F7") }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(tint.gradient)
                .frame(width: size, height: size)
                .overlay {
                    Text(emoji ?? "💜")
                        .font(.system(size: size * 0.5))
                }
            if let online {
                Circle()
                    .fill(online ? Color.green : Color.gray)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .overlay(Circle().strokeBorder(Color.cardBackground, lineWidth: 2))
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(online == true ? L10n.t("presence.online") : "")
    }
}

/// Convenience initialiser from a server `Member`.
extension MemberAvatar {
    init(member: Member?, size: CGFloat = 44, showPresence: Bool = false) {
        self.init(emoji: member?.avatar, colorHex: member?.color, size: size,
                  online: showPresence ? (member?.online ?? false) : nil)
    }
}

/// Two avatars joined by a heart — "Mia ❤️ Ben".
struct CouplePairView: View {
    let me: Member?
    let partner: Member?
    var size: CGFloat = 56
    var showNames = true

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            person(me, fallback: L10n.t("common.you"))
            Image(systemName: "heart.fill")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(height: size)
                .accessibilityHidden(true)
            person(partner, fallback: L10n.t("common.partner"))
        }
    }

    private func person(_ member: Member?, fallback: String) -> some View {
        VStack(spacing: 6) {
            MemberAvatar(member: member, size: size, showPresence: member != nil && member?.id != me?.id)
            if showNames {
                Text(member?.name ?? fallback)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(minWidth: size)
    }
}
