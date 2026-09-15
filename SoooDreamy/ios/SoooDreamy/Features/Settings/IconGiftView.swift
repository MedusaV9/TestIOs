import SwiftUI

// App-icon variants & icon gifts: 9 procedurally rendered icons
// (GenerateIcon.swift paints the PNGs in CI; the previews below redraw the
// same palettes in SwiftUI so the repo stays binary-free). A partner can gift
// an icon — the unwrap ceremony is a sheet on the receiver's next app-open.

/// Client metadata for every icon variant. `assetName` must match the
/// appiconset names in Assets.xcassets + ASSETCATALOG_COMPILER_ALTERNATE_-
/// APPICON_NAMES in project.yml; ids mirror the server's ICON_IDS.
enum AppIconKit {
    struct Variant: Identifiable, Equatable {
        let id: String
        /// nil = primary icon (classic).
        let assetName: String?
        let bg: [Color]
        let heart: Color
    }

    // Palettes mirror GenerateIcon.swift — they describe the icon artwork,
    // not app chrome, so hex literals are intentional here.
    static let variants: [Variant] = [
        Variant(id: "classic", assetName: nil,
                bg: [Color(hex: "0E0421"), Color(hex: "210B45"), Color(hex: "4D1766")],
                heart: Color(hex: "FF548C")),
        Variant(id: "sunset", assetName: "AppIcon-sunset",
                bg: [Color(hex: "24081A"), Color(hex: "591424"), Color(hex: "A63821")],
                heart: Color(hex: "FF7359")),
        Variant(id: "midnight", assetName: "AppIcon-midnight",
                bg: [Color(hex: "03030D"), Color(hex: "080D24"), Color(hex: "121A40")],
                heart: Color(hex: "6B8CF2")),
        Variant(id: "mint", assetName: "AppIcon-mint",
                bg: [Color(hex: "031A1A"), Color(hex: "053330"), Color(hex: "0D5447")],
                heart: Color(hex: "59E6B8")),
        Variant(id: "rose", assetName: "AppIcon-rose",
                bg: [Color(hex: "290D17"), Color(hex: "4D1729"), Color(hex: "7A2940")],
                heart: Color(hex: "FF80A3")),
        Variant(id: "ocean", assetName: "AppIcon-ocean",
                bg: [Color(hex: "030A1F"), Color(hex: "051A3D"), Color(hex: "083361")],
                heart: Color(hex: "4DB3F2")),
        Variant(id: "gold", assetName: "AppIcon-gold",
                bg: [Color(hex: "1A0D05"), Color(hex: "381F0A"), Color(hex: "663D14")],
                heart: Color(hex: "FFB859")),
        Variant(id: "lavender", assetName: "AppIcon-lavender",
                bg: [Color(hex: "141024"), Color(hex: "291F47"), Color(hex: "473870")],
                heart: Color(hex: "B88CF2")),
        Variant(id: "blossom", assetName: "AppIcon-blossom",
                bg: [Color(hex: "1F051A"), Color(hex: "3D0D33"), Color(hex: "6B1F4D")],
                heart: Color(hex: "FF8CBF")),
    ]

    static func variant(_ id: String) -> Variant {
        variants.first { $0.id == id } ?? variants[0]
    }

    static var currentId: String {
        guard let name = UIApplication.shared.alternateIconName else { return "classic" }
        return variants.first { $0.assetName == name }?.id ?? "classic"
    }

    /// Switches the home-screen icon; completion(false) when iOS refuses
    /// (e.g. sideload signing stripped the alternate icons).
    static func apply(_ id: String, completion: @escaping (Bool) -> Void) {
        let variant = variant(id)
        guard UIApplication.shared.supportsAlternateIcons else {
            completion(false)
            return
        }
        UIApplication.shared.setAlternateIconName(variant.assetName) { error in
            completion(error == nil)
        }
    }
}

// MARK: - Procedural preview (mirrors GenerateIcon palettes)

/// Miniature of an icon variant — same night gradient + glass heart the CI
/// renderer paints, redrawn live so no PNGs are bundled for the picker.
struct IconVariantPreview: View {
    let variant: AppIconKit.Variant
    var size: CGFloat = 58

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(LinearGradient(colors: variant.bg,
                                     startPoint: .bottomLeading, endPoint: .topTrailing))
            HeartGlyph()
                .fill(LinearGradient(colors: [variant.heart.opacity(0.95), variant.heart.opacity(0.55)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(HeartGlyph().stroke(Color.white.opacity(0.65), lineWidth: max(1, size * 0.02)))
                .frame(width: size * 0.56, height: size * 0.52)
                .shadow(color: variant.heart.opacity(0.7), radius: size * 0.09)
            // Specular sweep so the mini reads as glass (part of the artwork).
            Ellipse()
                .fill(LinearGradient(colors: [Color.white.opacity(0.30), .clear],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.62, height: size * 0.26)
                .offset(y: -size * 0.24)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Classic parametric heart (matches the icon renderer's silhouette).
struct HeartGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 120
        for i in 0...steps {
            let t = Double(i) / Double(steps) * 2 * .pi
            let x = 16 * pow(sin(t), 3)
            let y = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
            let point = CGPoint(x: rect.midX + CGFloat(x) / 34 * rect.width,
                                y: rect.midY - CGFloat(y - 1.5) / 31 * rect.height)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Icon picker & gifting

/// Pick your own app icon or gift one to your partner.
struct IconGiftView: View {
    @Environment(AppState.self) private var appState

    @State private var selected: String = AppIconKit.currentId
    @State private var current: String = AppIconKit.currentId
    @State private var note = ""
    @State private var sending = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        List {
            Section {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(AppIconKit.variants) { variant in
                        variantCell(variant)
                    }
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } header: {
                Text(L10n.t("icongift.section.choose"))
            } footer: {
                if current == selected {
                    Text(L10n.t("icongift.applied"))
                }
            }

            Section {
                Button {
                    applySelected()
                } label: {
                    Label(L10n.t("icongift.apply"), systemImage: "checkmark.circle")
                }
                .disabled(current == selected)
            }

            if appState.partner != nil {
                Section {
                    TextField(L10n.t("icongift.notePlaceholder"), text: $note, axis: .vertical)
                        .lineLimit(1...3)
                    Button {
                        sendGift()
                    } label: {
                        HStack {
                            Label(L10n.t("icongift.send"), systemImage: "gift")
                            if sending {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(sending)
                } header: {
                    Text(L10n.t("icongift.giftTitle", ["name": appState.partnerName]))
                }
            }
        }
        .navigationTitle(L10n.t("icongift.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func variantCell(_ variant: AppIconKit.Variant) -> some View {
        Button {
            withAnimation(.snappy) { selected = variant.id }
        } label: {
            VStack(spacing: 8) {
                IconVariantPreview(variant: variant, size: 64)
                    .overlay {
                        if selected == variant.id {
                            RoundedRectangle(cornerRadius: 64 * 0.22 + 3, style: .continuous)
                                .strokeBorder(Color.accentColor, lineWidth: 2.5)
                                .padding(-4)
                        }
                    }
                Text(L10n.t("icon.name.\(variant.id)"))
                    .font(.caption.weight(selected == variant.id ? .semibold : .regular))
                    .foregroundStyle(selected == variant.id ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if current == variant.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.green)
                        .accessibilityLabel(L10n.t("icongift.current"))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.t("icon.name.\(variant.id)"))
        .accessibilityAddTraits(selected == variant.id ? .isSelected : [])
    }

    private func applySelected() {
        AppIconKit.apply(selected) { ok in
            if ok {
                current = selected
                SoundEngine.shared.play(.success)
                Haptics.shared.success()
                appState.notify(L10n.t("icongift.appliedToast"), style: .success)
            } else {
                appState.notify(L10n.t("icongift.applyFailed"), style: .error)
            }
        }
    }

    private func sendGift() {
        guard !sending else { return }
        sending = true
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            let ok = await appState.giftIcon(selected, note: trimmed.isEmpty ? nil : trimmed)
            sending = false
            if ok { note = "" }
        }
    }
}

// MARK: - Unwrap ceremony (sheet)

struct IconGiftUnwrapView: View {
    @Environment(AppState.self) private var appState
    let gift: IconGift

    @State private var unwrapped = false
    @State private var shaking = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var variant: AppIconKit.Variant { AppIconKit.variant(gift.icon) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 0)

                if unwrapped {
                    IconVariantPreview(variant: variant, size: 140)
                        .shadow(color: variant.heart.opacity(0.5), radius: 30)
                        .transition(.scale(scale: 0.35).combined(with: .opacity))

                    VStack(spacing: 8) {
                        Text(L10n.t("icon.name.\(variant.id)"))
                            .font(.title2.weight(.bold))
                        if let note = gift.note, !note.isEmpty {
                            Text("„\(note)“")
                                .font(.body.italic())
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    VStack(spacing: 12) {
                        Button(L10n.t("icongift.unwrap.apply")) { applyAndClose() }
                            .buttonStyle(.glassProminent)
                            .controlSize(.large)
                        Button(L10n.t("icongift.unwrap.later")) { close() }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        unwrap()
                    } label: {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 120))
                            .foregroundStyle(Color.accentColor.gradient)
                            .rotationEffect(.degrees(shaking ? 4 : -4))
                            .animation(reduceMotion ? nil
                                       : .easeInOut(duration: 0.18).repeatForever(autoreverses: true),
                                       value: shaking)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("icongift.unwrap.hint"))

                    Text(L10n.t("icongift.unwrap.hint"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(30)
            .frame(maxWidth: .infinity)
            .overlay {
                if unwrapped {
                    FloatingHeartsView(emojis: ["🎁", "✨", "💜", "🌟"], count: 20)
                        .ignoresSafeArea()
                }
            }
            .navigationTitle(L10n.t("icongift.unwrap.title", ["name": appState.partnerName]))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.close")) { close() }
                }
            }
        }
        .onAppear { shaking = true }
        .interactiveDismissDisabled(!unwrapped)
    }

    private func unwrap() {
        SoundEngine.shared.play(.unlock)
        Haptics.shared.success()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) {
            unwrapped = true
        }
        Delight.celebrate(.medium, theme: .confetti)
        // Tell the server (and the sender) the surprise landed.
        Task { _ = await appState.unwrapIconGift() }
    }

    private func applyAndClose() {
        AppIconKit.apply(variant.id) { ok in
            if ok {
                SoundEngine.shared.play(.success)
                appState.notify(L10n.t("icongift.appliedToast"), style: .success)
            } else {
                appState.notify(L10n.t("icongift.applyFailed"), style: .error)
            }
        }
        close()
    }

    private func close() {
        appState.dismissPendingIconGift()
    }
}
