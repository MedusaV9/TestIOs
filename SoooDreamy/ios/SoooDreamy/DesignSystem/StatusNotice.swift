import SwiftUI

/// Transient in-app status ("Herzklopfen gesendet", partner events).
/// Shown as a small Liquid Glass capsule below the navigation bar; errors
/// that need a decision are alerts instead (see `AppState.alertMessage`).
struct StatusNotice: Equatable, Identifiable {
    enum Style { case info, success, error, love }

    let id = UUID()
    let text: String
    var style: Style = .info

    var tint: Color {
        switch style {
        case .info: return .blue
        case .success: return .green
        case .error: return .red
        case .love: return .accentColor
        }
    }

    var icon: String {
        switch style {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .love: return "heart.fill"
        }
    }
}

struct StatusNoticeView: View {
    let notice: StatusNotice

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: notice.icon)
                .foregroundStyle(notice.tint)
                .symbolEffect(.bounce, value: notice.id)
            Text(notice.text)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 16)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}
