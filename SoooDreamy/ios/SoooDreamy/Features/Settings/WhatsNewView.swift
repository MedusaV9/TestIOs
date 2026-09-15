import SwiftUI

/// "What's new" in the shape Apple's own apps use after an update: a centred
/// title with the version, a short list of features with large tinted
/// symbols, one prominent button. Shown once per major version (see
/// `AppState.showWhatsNew`) and replayable from About.
struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var revealed = false

    private static let features: [(symbol: String, tint: Color, title: String, body: String)] = [
        ("sparkles.rectangle.stack.fill", .accentColor, "whatsnew.f1.title", "whatsnew.f1.body"),
        ("photo.on.rectangle.angled", .pink, "whatsnew.f2.title", "whatsnew.f2.body"),
        ("gamecontroller.fill", .purple, "whatsnew.f3.title", "whatsnew.f3.body"),
        ("chart.bar.xaxis", .blue, "whatsnew.f4.title", "whatsnew.f4.body"),
        ("qrcode.viewfinder", .teal, "whatsnew.f5.title", "whatsnew.f5.body"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        Text(L10n.t("whatsnew.title"))
                            .font(.largeTitle.weight(.bold))
                            .multilineTextAlignment(.center)
                        Text(L10n.t("whatsnew.version", ["v": WhatsNewView.marketingVersion]))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 36)

                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(Array(Self.features.enumerated()), id: \.offset) { index, feature in
                            featureRow(feature)
                                .opacity(revealed ? 1 : 0)
                                .offset(y: revealed ? 0 : 16)
                                .animation(reduceMotion ? nil
                                           : .spring(duration: 0.6, bounce: 0.15).delay(0.15 + Double(index) * 0.08),
                                           value: revealed)
                        }
                    }
                    .padding(.horizontal, 28)
                }
                .padding(.bottom, 24)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.done")) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                } label: {
                    Text(L10n.t("common.continue"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
        }
        .onAppear { revealed = true }
    }

    private func featureRow(_ feature: (symbol: String, tint: Color, title: String, body: String)) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: feature.symbol)
                .font(.title)
                .foregroundStyle(feature.tint)
                .frame(width: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.t(feature.title))
                    .font(.headline)
                Text(L10n.t(feature.body))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// "5.0" from the bundle — falls back to the 5.0 line this sheet describes.
    static var marketingVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "5.0"
    }

    /// Major version that gates the one-time presentation ("5" for 5.0.x).
    static var majorVersion: String {
        String(marketingVersion.split(separator: ".").first ?? "5")
    }
}
