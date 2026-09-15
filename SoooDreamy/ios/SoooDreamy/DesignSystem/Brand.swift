import SwiftUI
import UIKit

// SoooDreamy 5.0 design language
//
// The app leans on the system: semantic colors (light + dark for free),
// Dynamic Type text styles, SF Symbols and the real Liquid Glass surfaces of
// iOS 26 (system navigation/tab bars, `glassEffect`, `.glass` buttons).
// Nothing here re-implements a system component — this file only holds the
// few brand constants the system cannot know about.

extension Color {
    /// "#FF5C8A" / "FF5C8A" → Color
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r, g, b: Double
        if s.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        } else {
            r = 0.96; g = 0.35; b = 0.50
        }
        self.init(red: r, green: g, blue: b)
    }

    // Semantic surfaces — resolve to the right value in light and dark mode.
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let tertiaryCardBackground = Color(uiColor: .tertiarySystemGroupedBackground)
    static let systemBackground = Color(uiColor: .systemBackground)
    static let secondarySystemBackground = Color(uiColor: .secondarySystemBackground)
    static let separator = Color(uiColor: .separator)
}

enum Brand {
    /// Accent (AccentColor asset) — rose, like the mockups.
    static let rose = Color.accentColor

    /// Card corner radius used app-wide (system-like continuous curve).
    static let cardRadius: CGFloat = 20
    /// Small tiles / thumbnails.
    static let tileRadius: CGFloat = 14
    /// Horizontal screen inset.
    static let screenInset: CGFloat = 16

    /// Avatar color choices during profile setup.
    static let memberColors: [String] = [
        "F4587F", "A855F7", "6366F1", "3B82F6", "10B981", "F59E0B", "F97316", "EF4444"
    ]

    /// Avatar emoji choices.
    static let avatarEmojis: [String] = [
        "🦊", "🐰", "🐻", "🐼", "🐨", "🦁", "🐯", "🐸", "🐙", "🦄", "🐝", "🦋",
        "🌸", "🌙", "⭐️", "🍓", "🍑", "🌈", "💫", "🔥", "🌊", "🍀", "🎀", "👑"
    ]
}

// MARK: - Surfaces

/// Standard grouped card (the Fitness/Health card look): secondary grouped
/// background on a continuous rounded rectangle.
struct CardSurface: ViewModifier {
    var padding: CGFloat = 16
    var radius: CGFloat = Brand.cardRadius

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.cardBackground,
                        in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    /// Grouped card surface. Use inside `ScrollView` content on
    /// `Color.groupedBackground`; inside a `List` prefer plain rows.
    func cardSurface(padding: CGFloat = 16, radius: CGFloat = Brand.cardRadius) -> some View {
        modifier(CardSurface(padding: padding, radius: radius))
    }

    /// Full-screen grouped background (matches `.insetGrouped` lists).
    func groupedScreenBackground() -> some View {
        background(Color.groupedBackground.ignoresSafeArea())
    }
}

// MARK: - Section title (App Store / Fitness style)

/// Bold section title with an optional trailing "Alle anzeigen ›" link —
/// used in scroll-based dashboards (Lists use native `Section` headers).
struct SectionTitle: View {
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.bold))
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if let trailing, let action {
                Button(action: action) {
                    HStack(spacing: 2) {
                        Text(trailing)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                    .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Row chevron

/// Trailing disclosure chevron in the system's tertiary color.
struct DisclosureChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
    }
}

// MARK: - Streak badge

/// Streak counter the way Fitness shows it: flame symbol + monospaced digits.
/// `.capsule` adds the tinted pill used on cards; `.inline` is plain text for
/// toolbars and row subtitles.
struct StreakBadge: View {
    enum Style { case inline, capsule }

    let streak: Int
    var style: Style = .inline

    var body: some View {
        Label {
            Text(streak, format: .number)
                .monospacedDigit()
        } icon: {
            Image(systemName: "flame.fill")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.orange)
        .padding(.vertical, style == .capsule ? 4 : 0)
        .padding(.horizontal, style == .capsule ? 9 : 0)
        .background(style == .capsule ? Color.orange.opacity(0.16) : Color.clear, in: Capsule())
        .accessibilityLabel(L10n.t("home.streak", ["n": String(streak)]))
    }
}

// MARK: - Icon tile

/// Rounded icon tile as used in Settings rows (SF Symbol on a colored square).
struct IconTile: View {
    let systemImage: String
    var tint: Color = .accentColor
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.53, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .accessibilityHidden(true)
    }
}
