import SwiftUI

/// Appearance preference (Profile → Darstellung). Default follows the system,
/// like every native app; light and dark are honest overrides.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "sooodreamy.appearance"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var titleKey: String { "appearance.\(rawValue)" }

    var systemImage: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
}

/// System / Light / Dark segmented control stored in AppStorage.
struct AppearancePicker: View {
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.t("appearance.title"), systemImage: "circle.lefthalf.filled")
                .font(.subheadline.weight(.semibold))
            Picker(L10n.t("appearance.title"), selection: $appearanceRaw) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(L10n.t(mode.titleKey)).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
        .sensoryFeedback(.selection, trigger: appearanceRaw)
    }
}
