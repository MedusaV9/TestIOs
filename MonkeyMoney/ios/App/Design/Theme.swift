import SwiftUI
import UIKit

/// Design tokens from the Monkey Money concept: jungle night greens, banana
/// gold, cream ink — Outfit for headlines, Poppins for body copy.
enum MM {
    static let bg = Color(hex: "#0E2F24")
    static let bgDeep = Color(hex: "#071A13")
    static let panel = Color(hex: "#1F6B3A")
    static let panelDark = Color(hex: "#17452C")
    static let gold = Color(hex: "#FFD34E")
    static let goldDark = Color(hex: "#E0B12C")
    static let cream = Color(hex: "#FFF6D6")
    static let wood = Color(hex: "#8B5E34")
    static let ink = Color(hex: "#1A1A1A")
    static let red = Color(hex: "#E53950")
    static let green = Color(hex: "#7ED957")
    static let blue = Color(hex: "#3D7BFF")
    static let lila = Color(hex: "#8E5BFF")
    static let orange = Color(hex: "#FF8A3D")

    static func playerColor(_ token: String) -> Color { Color(hex: Monkeys.hex(for: token)) }

    static let optionColors: [Color] = [gold, Color(hex: "#C98A4B"), Color(hex: "#FF6B8B"), green, blue, lila, Color(hex: "#2ED3C6"), orange]
    static let optionEmojis = ["🍌", "🥥", "🐒", "🌴", "💎", "🎩", "🌊", "🔥"]
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var n: UInt64 = 0
        Scanner(string: s).scanHexInt64(&n)
        let r, g, b: Double
        if s.count == 6 {
            r = Double((n >> 16) & 0xFF) / 255
            g = Double((n >> 8) & 0xFF) / 255
            b = Double(n & 0xFF) / 255
        } else { r = 1; g = 0.83; b = 0.31 }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

extension Font {
    static func outfit(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        let name: String
        switch weight {
        case .black, .heavy: name = "Outfit-Black"
        case .bold: name = "Outfit-Bold"
        case .semibold: name = "Outfit-SemiBold"
        case .medium: name = "Outfit-Medium"
        default: name = "Outfit-Regular"
        }
        return .custom(name, size: size)
    }

    static func poppins(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "Poppins-Bold"
        case .semibold: name = "Poppins-SemiBold"
        case .medium: name = "Poppins-Medium"
        default: name = "Poppins-Regular"
        }
        return .custom(name, size: size)
    }
}

// MARK: - Backgrounds

/// Jungle stage backdrop: deep green radial, spotlights and leaf silhouettes.
struct JungleBackground: View {
    var spotlights = true
    var body: some View {
        ZStack {
            RadialGradient(colors: [MM.panel, MM.bg, MM.bgDeep], center: UnitPoint(x: 0.5, y: -0.1), startRadius: 0, endRadius: 1400)
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                Canvas { ctx, _ in
                    var leaf = Path()
                    leaf.move(to: CGPoint(x: -40, y: h * 0.72))
                    leaf.addCurve(to: CGPoint(x: w * 0.28, y: h * 0.98), control1: CGPoint(x: w * 0.12, y: h * 0.6), control2: CGPoint(x: w * 0.26, y: h * 0.7))
                    leaf.addLine(to: CGPoint(x: -40, y: h + 40))
                    leaf.closeSubpath()
                    ctx.fill(leaf, with: .color(MM.panelDark.opacity(0.9)))
                    var leaf2 = Path()
                    leaf2.move(to: CGPoint(x: w + 40, y: h * 0.7))
                    leaf2.addCurve(to: CGPoint(x: w * 0.72, y: h * 0.98), control1: CGPoint(x: w * 0.88, y: h * 0.58), control2: CGPoint(x: w * 0.74, y: h * 0.68))
                    leaf2.addLine(to: CGPoint(x: w + 40, y: h + 40))
                    leaf2.closeSubpath()
                    ctx.fill(leaf2, with: .color(MM.panelDark.opacity(0.9)))
                    var top = Path()
                    top.move(to: CGPoint(x: 0, y: 0))
                    top.addCurve(to: CGPoint(x: w * 0.22, y: 0), control1: CGPoint(x: w * 0.02, y: h * 0.22), control2: CGPoint(x: w * 0.2, y: h * 0.18))
                    top.closeSubpath()
                    ctx.fill(top, with: .color(MM.panel.opacity(0.35)))
                    var top2 = Path()
                    top2.move(to: CGPoint(x: w, y: 0))
                    top2.addCurve(to: CGPoint(x: w * 0.78, y: 0), control1: CGPoint(x: w * 0.98, y: h * 0.22), control2: CGPoint(x: w * 0.8, y: h * 0.18))
                    top2.closeSubpath()
                    ctx.fill(top2, with: .color(MM.panel.opacity(0.35)))
                    if spotlights {
                        for x in [w * 0.18, w * 0.82] {
                            var cone = Path()
                            cone.move(to: CGPoint(x: x, y: -10))
                            cone.addLine(to: CGPoint(x: x - w * 0.22, y: h * 0.9))
                            cone.addLine(to: CGPoint(x: x + w * 0.22, y: h * 0.9))
                            cone.closeSubpath()
                            ctx.fill(cone, with: .linearGradient(Gradient(colors: [MM.gold.opacity(0.18), .clear]), startPoint: CGPoint(x: x, y: 0), endPoint: CGPoint(x: x, y: h * 0.9)))
                        }
                    }
                    // Stage floor
                    let floor = Path(CGRect(x: 0, y: h * 0.86, width: w, height: h * 0.14))
                    ctx.fill(floor, with: .linearGradient(Gradient(colors: [MM.bgDeep.opacity(0.0), MM.bgDeep.opacity(0.85)]), startPoint: CGPoint(x: 0, y: h * 0.86), endPoint: CGPoint(x: 0, y: h)))
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Components

struct GoldButton: View {
    var title: String
    var icon: String? = nil
    var style: Style = .gold
    var compact = false
    var action: () -> Void

    enum Style { case gold, green, red, ghost }

    var body: some View {
        Button(action: { Haptics.tap(); action() }) {
            HStack(spacing: 10) {
                if let icon = icon { Image(systemName: icon).font(.system(size: compact ? 15 : 19, weight: .black)) }
                Text(title).font(.outfit(compact ? 16 : 22, .bold))
            }
            .padding(.horizontal, compact ? 18 : 30)
            .padding(.vertical, compact ? 10 : 16)
            .frame(maxWidth: compact ? nil : .infinity)
            .foregroundStyle(fg)
            .background(
                RoundedRectangle(cornerRadius: compact ? 14 : 20, style: .continuous)
                    .fill(bg)
                    .overlay(RoundedRectangle(cornerRadius: compact ? 14 : 20, style: .continuous).strokeBorder(border, lineWidth: 1.5))
                    .shadow(color: shadow, radius: 0, y: compact ? 4 : 6)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 10)
            )
        }
        .buttonStyle(PressStyle())
    }

    var fg: Color { style == .ghost || style == .green ? MM.cream : (style == .red ? .white : MM.ink) }
    var bg: Color {
        switch style {
        case .gold: return MM.gold
        case .green: return MM.panel
        case .red: return MM.red
        case .ghost: return Color.black.opacity(0.28)
        }
    }
    var border: Color { style == .gold ? MM.goldDark : Color.white.opacity(0.12) }
    var shadow: Color {
        switch style {
        case .gold: return MM.goldDark
        case .green: return Color(hex: "#0F3A22")
        case .red: return Color(hex: "#9E1F31")
        case .ghost: return .clear
        }
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct PanelCard<Content: View>: View {
    var padding: CGFloat = 18
    var highlight = false
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [MM.panel.opacity(0.55), MM.panelDark.opacity(0.9)], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(highlight ? MM.gold : MM.gold.opacity(0.25), lineWidth: highlight ? 3 : 1.2))
                    .shadow(color: .black.opacity(0.35), radius: 18, y: 12)
            )
    }
}

struct Chip: View {
    var text: String
    var icon: String? = nil
    var gold = false
    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon { Image(systemName: icon).font(.system(size: 12, weight: .bold)) }
            Text(text).font(.poppins(13, .semibold))
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill(gold ? MM.gold : Color.black.opacity(0.3)).overlay(Capsule().strokeBorder(gold ? MM.goldDark : Color.white.opacity(0.1))))
        .foregroundStyle(gold ? MM.ink : MM.cream)
    }
}

/// Wooden sign (design concept: “Good Questions · Bigger Wins!” boards).
struct WoodSign: View {
    var lines: [String]
    var tilt: Double = -4
    var body: some View {
        VStack(spacing: 2) {
            ForEach(lines, id: \.self) { l in Text(l).font(.custom("Poppins-SemiBold", size: 17)).italic() }
        }
        .foregroundStyle(MM.cream.opacity(0.9))
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 10).fill(MM.wood).shadow(color: .black.opacity(0.4), radius: 8, y: 6))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(hex: "#5A3A1C"), lineWidth: 3))
        .rotationEffect(.degrees(tilt))
    }
}

/// The 14 monkey puppets rendered from the pre-baked PNGs (palette × face).
struct MonkeyImage: View {
    var avatar: Avatar
    var face: String = "neutral"

    var body: some View {
        Group {
            if let img = MonkeyImage.image(for: avatar, face: face) {
                Image(uiImage: img).resizable().aspectRatio(contentMode: .fit)
            } else {
                Text("🐵").font(.system(size: 60))
            }
        }
    }

    nonisolated(unsafe) static var cache: [String: UIImage] = [:]

    static func image(for avatar: Avatar, face: String) -> UIImage? {
        let farbe = Monkeys.colors.contains { $0.id == avatar.farbe } ? avatar.farbe : nearestColor(avatar.farbe)
        let affe = Monkeys.all.contains { $0.id == avatar.affe } ? avatar.affe : "don-bananas"
        let key = "\(affe)_\(farbe)_\(face)"
        if let c = cache[key] { return c }
        guard let url = Bundle.main.url(forResource: key, withExtension: "png", subdirectory: "Monkeys") ?? Bundle.main.url(forResource: key, withExtension: "png"),
              let img = UIImage(contentsOfFile: url.path) else { return nil }
        cache[key] = img
        return img
    }

    /// Free hex colours snap to the closest catalogue colour for the baked puppets.
    static func nearestColor(_ token: String) -> String {
        guard token.hasPrefix("hex"), token.count == 9, let n = UInt32(token.dropFirst(3), radix: 16) else { return "gelb" }
        let r = Double((n >> 16) & 0xFF), g = Double((n >> 8) & 0xFF), b = Double(n & 0xFF)
        var best = "gelb"
        var bestD = Double.infinity
        for c in Monkeys.colors {
            guard let m = UInt32(c.hex.dropFirst(), radix: 16) else { continue }
            let dr = r - Double((m >> 16) & 0xFF), dg = g - Double((m >> 8) & 0xFF), db = b - Double(m & 0xFF)
            let d = dr * dr + dg * dg + db * db
            if d < bestD { bestD = d; best = c.id }
        }
        return best
    }
}

/// A player standing on a podium block with name plate and balance.
struct PodiumPlayer: View {
    var player: PlayerRef
    var face: String = "neutral"
    var delta: Int? = nil
    var size: CGFloat = 120
    var showBalance = true
    var highlight = false

    var body: some View {
        VStack(spacing: -6) {
            MonkeyImage(avatar: Avatar(wire: player.avatar), face: face)
                .frame(height: size)
                .shadow(color: .black.opacity(0.5), radius: 10, y: 8)
                .overlay(alignment: .topTrailing) {
                    if player.matsch { Text("💩").font(.system(size: size * 0.22)).offset(x: 6, y: -4) }
                    if player.clown { Text("🤡").font(.system(size: size * 0.22)).offset(x: 6, y: -4) }
                }
                .overlay(alignment: .topLeading) {
                    if player.streak >= 3 { Text("🔥").font(.system(size: size * 0.2)) }
                    if !player.connected { Text("💤").font(.system(size: size * 0.2)) }
                }
            VStack(spacing: 3) {
                Text(player.name)
                    .font(.outfit(size * 0.13, .bold))
                    .foregroundStyle(MM.ink)
                    .lineLimit(1)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 8).fill(MM.playerColor(Avatar(wire: player.avatar).farbe)))
                if showBalance {
                    Text(Money.format(player.balance))
                        .font(.outfit(size * 0.15, .black))
                        .foregroundStyle(MM.gold)
                }
                if let d = delta, d != 0 {
                    Text(Money.formatDelta(d))
                        .font(.outfit(size * 0.12, .bold))
                        .foregroundStyle(d > 0 ? MM.green : MM.red)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .frame(minWidth: size * 0.9)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [MM.panelDark, MM.bgDeep], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(highlight ? MM.gold : Color.white.opacity(0.1), lineWidth: highlight ? 2 : 1))
            )
        }
    }
}

/// Shrinking banana timer bar driven by the server deadline.
struct TimerBar: View {
    var deadline: Millis?
    var totalMs: Int
    var height: CGFloat = 10

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
            GeometryReader { geo in
                let remain = deadline.map { max(0, Double($0 - ServerClock.now())) } ?? 0
                let frac = deadline == nil ? 1 : min(1, remain / Double(max(1, totalMs)))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.35))
                    Capsule()
                        .fill(LinearGradient(colors: remain < 5000 && deadline != nil ? [MM.red, MM.orange] : [MM.gold, Color(hex: "#FFEA9A")], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(height, geo.size.width * frac))
                    if deadline != nil {
                        Text("🍌").font(.system(size: height * 1.9)).offset(x: max(0, geo.size.width * frac - height * 1.2), y: -height * 0.5)
                    }
                }
            }
            .frame(height: height)
        }
    }
}

/// Server clock shared by every view (offset-corrected on the phone, exact on the iPad).
enum ServerClock {
    nonisolated(unsafe) static var offset: Millis = 0
    static func now() -> Millis { Int(Date().timeIntervalSince1970 * 1000) + offset }
}

/// Countdown label "0:12".
struct CountdownText: View {
    var deadline: Millis?
    var font: Font = .outfit(28, .black)
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            let remain = deadline.map { max(0, ($0 - ServerClock.now() + 999) / 1000) } ?? 0
            Text(deadline == nil ? "" : String(remain))
                .font(font)
                .foregroundStyle(remain <= 5 ? MM.red : MM.gold)
                .monospacedDigit()
        }
    }
}

enum Haptics {
    static func tap() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
    static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
    static func error() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}

// MARK: - Settings controls (shared by host, phone GM and App Clip)

struct SettingPicker: View {
    var title: String
    var options: [(String, String)]
    @Binding var selection: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !title.isEmpty { Text(title).font(.poppins(13, .bold)).foregroundStyle(MM.gold) }
            HStack(spacing: 6) {
                ForEach(options, id: \.0) { o in
                    Button { selection = o.0 } label: {
                        Text(o.1).font(.poppins(13, .semibold)).lineLimit(1)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Capsule().fill(selection == o.0 ? MM.gold : Color.black.opacity(0.3)))
                            .foregroundStyle(selection == o.0 ? MM.ink : MM.cream)
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}

struct ToggleChip: View {
    var title: String
    @Binding var on: Bool
    var body: some View {
        Button { on.toggle(); Haptics.tap() } label: {
            HStack(spacing: 8) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle").foregroundStyle(on ? MM.gold : MM.cream.opacity(0.5))
                Text(title).font(.poppins(14, .semibold))
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Capsule().fill(Color.black.opacity(on ? 0.45 : 0.22)))
            .foregroundStyle(MM.cream)
        }.buttonStyle(.plain)
    }
}
