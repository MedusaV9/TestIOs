import SwiftUI

// Shared native chrome for the game screens (in addition to the scaffolding
// in GameCatalog.swift). Everything here is system components only.

/// Thin round/timer progress bar used under game headers.
struct GameProgressBar: View {
    let progress: Double
    var tint: Color = .accentColor

    var body: some View {
        ProgressView(value: min(max(progress, 0), 1))
            .tint(tint)
    }
}

/// "In den Chat teilen" — the standard post-game share action.
struct GameShareButton: View {
    let sharing: Bool
    let shared: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if sharing {
                    ProgressView()
                } else {
                    Label(L10n.t(shared ? "games.sharedToChat" : "games.shareToChat"),
                          systemImage: shared ? "checkmark" : "paperplane")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(sharing || shared)
    }
}

/// Labelled answer/statement bubble (quiz truth vs. guess, riddle answers …).
struct GameAnswerBubble: View {
    let label: String
    let text: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: Brand.tileRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Big final score "3 : 5" with both avatars.
struct GameFinalScore: View {
    @Environment(AppState.self) private var appState
    let myScore: Int
    let partnerScore: Int
    /// Local pass-and-play without a paired partner ("Team 2").
    var partnerFallbackName: String? = nil

    var body: some View {
        HStack(spacing: 18) {
            column(member: appState.me, score: myScore, leading: myScore > partnerScore, fallback: nil)
            Text(":")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.secondary)
            column(member: appState.partner, score: partnerScore, leading: partnerScore > myScore,
                   fallback: partnerFallbackName)
        }
        .accessibilityElement(children: .combine)
    }

    private func column(member: Member?, score: Int, leading: Bool, fallback: String?) -> some View {
        VStack(spacing: 6) {
            MemberAvatar(member: member, size: 46)
            Text("\(score)")
                .font(.system(size: 44, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(leading ? Color.accentColor : Color.primary)
                .contentTransition(.numericText())
            Text(member?.name ?? fallback ?? "–")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(minWidth: 80)
    }
}

/// Large tappable answer option (quiz duel, this-or-that …).
struct GameChoiceButton: View {
    let title: String
    var subtitle: String? = nil
    var selected = false
    var disabled = false
    var tint: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .multilineTextAlignment(.center)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(selected ? Color.white.opacity(0.85) : Color.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: Brand.tileRadius))
        .tint(selected ? tint : Color.secondary)
        .disabled(disabled)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Emoji / symbol tile with a caption — used for game "cards" (riddles,
/// truth-or-dare prompts …). Neutral card surface, system text styles.
struct GamePromptCard<Content: View>: View {
    var eyebrow: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 14) {
            if let eyebrow {
                Text(eyebrow)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            content
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .cardSurface(padding: 20)
    }
}

/// Small capsule that names whose turn it is / which phase is running.
struct GamePhaseLabel: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = .accentColor

    var body: some View {
        Group {
            if let systemImage {
                Label(text, systemImage: systemImage)
            } else {
                Text(text)
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.14), in: Capsule())
        .lineLimit(1)
    }
}

/// Members' scores in a compact list row (tournament, records).
struct GameMemberScoreRow: View {
    let member: Member?
    let value: String
    var detail: String? = nil
    var highlighted = false

    var body: some View {
        HStack(spacing: 12) {
            MemberAvatar(member: member, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(member?.name ?? "–")
                    .font(.body.weight(.medium))
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(highlighted ? Color.accentColor : Color.primary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
