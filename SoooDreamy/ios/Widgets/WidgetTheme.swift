import SwiftUI
import WidgetKit
import UIKit
import ImageIO

// MARK: - Color helper

extension Color {
    /// "#FF5C8A" / "FF5C8A" → Color.
    /// Named `init(hexString:)` on purpose: `Shared/` is compiled into both
    /// targets and the app target already defines `Color(hex:)` — keeping a
    /// distinct name avoids any clash if files ever move between targets.
    init(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r: Double
        let g: Double
        let b: Double
        if s.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        } else {
            r = 1; g = 0.36; b = 0.54
        }
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Resolved palette (theme spec → SwiftUI)

/// A `WidgetThemeSpec` resolved into SwiftUI colors/gradients for rendering.
struct WidgetPalette {
    let spec: WidgetThemeSpec

    var accent: Color { Color(hexString: spec.accentHex) }
    var accentSecondary: Color { Color(hexString: spec.accentSecondaryHex) }
    var textPrimary: Color { spec.isLight ? Color(hexString: "26102E") : .white }
    var textSecondary: Color { textPrimary.opacity(0.65) }
    var chipFill: Color { spec.isLight ? Color.black.opacity(0.07) : Color.white.opacity(0.1) }

    var background: LinearGradient {
        LinearGradient(colors: spec.backgroundHexes.map { Color(hexString: $0) },
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var heroGradient: LinearGradient {
        LinearGradient(colors: [accent, accentSecondary],
                       startPoint: .leading, endPoint: .trailing)
    }

    /// Palette for a widget kind: per-widget/intent override → studio default.
    static func resolve(kind: String, intentThemeId: String? = nil) -> WidgetPalette {
        let studio = SharedStore.readStudioConfig()
        if let intentThemeId, intentThemeId != "studio",
           WidgetThemes.all.contains(where: { $0.id == intentThemeId }) {
            return WidgetPalette(spec: WidgetThemes.spec(id: intentThemeId))
        }
        return WidgetPalette(spec: studio.theme(for: kind))
    }
}

// MARK: - Legacy palette shorthands (pre-2.0 look, still used as defaults)

enum WTheme {
    static let bgTop = Color(hexString: "17062A")
    static let bgBottom = Color(hexString: "2B0F4A")
    static let pink = Color(hexString: "FF5C8A")
    static let purple = Color(hexString: "A855F7")
    static let gold = Color(hexString: "FFD166")
    static let mint = Color(hexString: "6EE7B7")
    static let textSecondary = Color.white.opacity(0.65)

    static let heroGradient = LinearGradient(
        colors: [pink, purple],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let countGradient = LinearGradient(
        colors: [pink, gold],
        startPoint: .leading, endPoint: .trailing)
}

// MARK: - Widget chrome (studio-driven container background)

/// Container background resolved from the Widget Studio config: the widget's
/// theme gradient, or — for photo-friendly widgets with photo chrome on —
/// the cached showcase photo, dimmed enough to keep text legible.
struct WidgetChromeBackground: View {
    let palette: WidgetPalette
    /// Photo/canvas widgets pass `true` so the photo-chrome pref applies.
    var photoFriendly = false

    var body: some View {
        if photoFriendly,
           SharedStore.readStudioConfig().usePhotoChrome,
           let data = SharedStore.readCachedPhotoJPEG(),
           let image = WidgetImages.decode(data, maxDimension: 700) {
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                LinearGradient(
                    colors: [Color.black.opacity(0.38), Color.black.opacity(0.62)],
                    startPoint: .top, endPoint: .bottom)
            }
        } else {
            ZStack {
                palette.background
                // Liquid-glass sheen: a soft specular highlight sweeping the top.
                LinearGradient(
                    colors: [Color.white.opacity(palette.spec.isLight ? 0.35 : 0.14),
                             .clear, .clear],
                    startPoint: .topLeading, endPoint: .center)
            }
        }
    }
}

/// Applies the palette-driven container background to a widget view.
struct WidgetChrome: ViewModifier {
    let palette: WidgetPalette
    var photoFriendly = false

    func body(content: Content) -> some View {
        content.containerBackground(for: .widget) {
            WidgetChromeBackground(palette: palette, photoFriendly: photoFriendly)
        }
    }
}

extension View {
    /// Container background from the resolved widget palette.
    func widgetChrome(_ palette: WidgetPalette, photoFriendly: Bool = false) -> some View {
        modifier(WidgetChrome(palette: palette, photoFriendly: photoFriendly))
    }
}

// MARK: - App-group diagnostics

enum WidgetDiagnostics {
    /// True when the widget can actually read data the app wrote. When the
    /// app group is unavailable (sideload without the group entitlement) the
    /// snapshot is always nil — the widgets show a targeted hint instead of
    /// an eternal placeholder.
    static var hasAppGroup: Bool { SharedStore.appGroupAvailable }

    static var hasSnapshot: Bool { SharedStore.readSnapshot() != nil }
}

/// Friendly hint replacing the eternal-placeholder failure mode: explains
/// whether data is simply missing (open the app) or the app group is not
/// signed into the sideload (re-sign with app-group entitlement).
struct WidgetSetupHint: View {
    let palette: WidgetPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("💜")
                .font(.system(size: 28))
            if WidgetDiagnostics.hasAppGroup {
                Text(WText.t("Öffne SoooDreamy einmal, dann füllen sich die Widgets.",
                             "Open SoooDreamy once and the widgets fill up."))
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
            } else {
                Text(WText.t("App-Group fehlt: Sideload-Tool muss group.app.sooodreamy.shared mitsignieren.",
                             "App group missing: your sideload tool must sign group.app.sooodreamy.shared."))
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Image decoding

enum WidgetImages {
    /// Memory-safe decode: `CGImageSourceCreateThumbnailAtIndex` never
    /// materializes the full-resolution bitmap, so even a huge photo stays
    /// within the widget's tight memory budget.
    static func decode(_ data: Data, maxDimension: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let thumbOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Tiny bilingual string helper (German first)

enum WText {
    static func t(_ de: String, _ en: String) -> String {
        SharedStore.resolvedLanguage == "de" ? de : en
    }
}
