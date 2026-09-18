import SwiftUI

/// Particle field: confetti, banknotes or coins raining on the stage.
struct ParticleRain: View {
    enum Kind { case confetti, money, coins, mud }
    var kind: Kind
    var count = 80
    var duration: Double = 4

    struct Particle {
        var x: Double; var delay: Double; var speed: Double; var drift: Double; var spin: Double; var size: Double; var hue: Double
    }

    let particles: [Particle]
    let start = Date()

    init(kind: Kind, count: Int = 80, duration: Double = 4) {
        self.kind = kind
        self.count = count
        self.duration = duration
        var rng = SeededRandom(seed: UInt32(count * 7919 + Int(Date().timeIntervalSince1970) % 1000))
        particles = (0..<count).map { _ in
            Particle(x: rng.next(), delay: rng.next() * 1.2, speed: 0.6 + rng.next() * 0.8, drift: (rng.next() - 0.5) * 0.3, spin: rng.next() * 6, size: 0.7 + rng.next() * 0.8, hue: rng.next())
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSince(start)
                for p in particles {
                    let life = (t - p.delay) / (duration * (1.2 - p.speed * 0.5))
                    guard life > 0, life < 1.1 else { continue }
                    let y = -40 + (size.height + 80) * life
                    let x = p.x * size.width + sin(t * 2 + p.spin) * 24 + p.drift * size.width * life
                    let s = 14.0 * p.size
                    var c = ctx
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(t * (1.5 + p.spin / 3) + p.spin))
                    switch kind {
                    case .confetti:
                        let colors = [MM.gold, MM.green, MM.red, MM.blue, MM.lila, MM.orange, MM.cream]
                        c.fill(Path(CGRect(x: -s / 2, y: -s / 4, width: s, height: s / 2)), with: .color(colors[Int(p.hue * Double(colors.count)) % colors.count]))
                    case .money:
                        let note = Path(roundedRect: CGRect(x: -s, y: -s / 2, width: s * 2, height: s), cornerRadius: 2)
                        c.fill(note, with: .color(MM.green))
                        c.stroke(note, with: .color(Color(hex: "#2E7D32")), lineWidth: 1)
                        c.fill(Path(ellipseIn: CGRect(x: -s * 0.35, y: -s * 0.35, width: s * 0.7, height: s * 0.7)), with: .color(Color(hex: "#A5D6A7")))
                    case .coins:
                        c.fill(Path(ellipseIn: CGRect(x: -s / 2, y: -s / 2, width: s, height: s)), with: .color(MM.gold))
                        c.stroke(Path(ellipseIn: CGRect(x: -s / 2, y: -s / 2, width: s, height: s)), with: .color(MM.goldDark), lineWidth: 2)
                    case .mud:
                        c.fill(Path(ellipseIn: CGRect(x: -s / 2, y: -s / 3, width: s, height: s * 0.66)), with: .color(Color(hex: "#5A3A1C").opacity(0.8)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Sparkle burst used for “RICHTIG!” and jackpot moments.
struct Burst: View {
    var color: Color = MM.gold
    @State private var scale: CGFloat = 0.2
    @State private var opacity: Double = 1
    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                Capsule()
                    .fill(color)
                    .frame(width: 6, height: 40)
                    .offset(y: -60)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { scale = 1.6; opacity = 0 }
        }
        .allowsHitTesting(false)
    }
}

/// Rubber stamp (“RICHTIG!” / “FALSCH!”) slapping onto the wall.
struct StampView: View {
    var text: String
    var color: Color
    @State private var shown = false
    var body: some View {
        Text(text)
            .font(.outfit(46, .black))
            .foregroundStyle(color)
            .padding(.horizontal, 26).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14).fill(MM.bgDeep.opacity(0.8)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(color, lineWidth: 5))
            .rotationEffect(.degrees(-8))
            .scaleEffect(shown ? 1 : 2.4)
            .opacity(shown ? 1 : 0)
            .onAppear { withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { shown = true } }
    }
}

/// The Glücksrad — segments drawn with Canvas, rotation animated to the result.
struct WheelSpinView: View {
    var segments: [WheelSegment]
    var resultIndex: Int?
    var spinStartedAt: Millis?
    var spinDurationMs: Int
    var landed: Bool

    var body: some View {
        TimelineView(.animation) { _ in
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let angle = currentAngle()
                ZStack {
                    Circle().fill(MM.goldDark).frame(width: size, height: size).shadow(color: .black.opacity(0.5), radius: 20, y: 12)
                    Canvas { ctx, sz in
                        let n = max(1, segments.count)
                        let r = sz.width / 2 - 8
                        let center = CGPoint(x: sz.width / 2, y: sz.height / 2)
                        for (i, seg) in segments.enumerated() {
                            let a0 = Angle.degrees(Double(i) / Double(n) * 360 - 90 + angle)
                            let a1 = Angle.degrees(Double(i + 1) / Double(n) * 360 - 90 + angle)
                            var p = Path()
                            p.move(to: center)
                            p.addArc(center: center, radius: r, startAngle: a0, endAngle: a1, clockwise: false)
                            p.closeSubpath()
                            ctx.fill(p, with: .color(segmentColor(seg, i)))
                            ctx.stroke(p, with: .color(MM.goldDark), lineWidth: 3)
                            let mid = (a0.radians + a1.radians) / 2
                            let tx = center.x + cos(mid) * r * 0.62
                            let ty = center.y + sin(mid) * r * 0.62
                            var text = ctx
                            text.translateBy(x: tx, y: ty)
                            text.rotate(by: .radians(mid + .pi / 2))
                            text.draw(Text(seg.emoji).font(.system(size: r * 0.14)), at: CGPoint(x: 0, y: -r * 0.12))
                            text.draw(Text(seg.name).font(.outfit(r * 0.07, .bold)).foregroundColor(.white), at: CGPoint(x: 0, y: r * 0.06))
                        }
                        // Hub
                        ctx.fill(Path(ellipseIn: CGRect(x: center.x - r * 0.14, y: center.y - r * 0.14, width: r * 0.28, height: r * 0.28)), with: .color(MM.gold))
                        ctx.draw(Text("🍌").font(.system(size: r * 0.16)), at: center)
                        // Bulbs
                        for i in 0..<16 {
                            let a = Double(i) / 16 * 2 * .pi
                            let bx = center.x + cos(a) * (r + 4), by = center.y + sin(a) * (r + 4)
                            ctx.fill(Path(ellipseIn: CGRect(x: bx - 4, y: by - 4, width: 8, height: 8)), with: .color(i % 2 == 0 ? MM.cream : MM.gold))
                        }
                    }
                    .frame(width: size, height: size)
                    // Pointer
                    Triangle().fill(Color(hex: "#FF4FA3")).frame(width: 34, height: 40).overlay(Triangle().stroke(MM.ink, lineWidth: 3)).offset(y: -size / 2 + 6)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    func segmentColor(_ s: WheelSegment, _ i: Int) -> Color {
        switch s.klasse {
        case .gruen: return i % 2 == 0 ? MM.green : Color(hex: "#3AA655")
        case .blau: return i % 2 == 0 ? MM.blue : Color(hex: "#6A8DFF")
        case .gold: return i % 2 == 0 ? MM.gold : MM.orange
        }
    }

    /// Ease-out spin: 4 full turns + land with the result under the pointer (top).
    func currentAngle() -> Double {
        let n = max(1, segments.count)
        let segAngle = 360.0 / Double(n)
        let target = resultIndex.map { -(Double($0) * segAngle + segAngle / 2) } ?? 0
        guard let start = spinStartedAt, spinDurationMs > 0 else { return landed ? target : 0 }
        let elapsed = Double(ServerClock.now() - start) / Double(spinDurationMs)
        if elapsed >= 1 { return target }
        let e = max(0, min(1, elapsed))
        let eased = 1 - pow(1 - e, 3)
        return (target - 360 * 4) + (360 * 4) * eased
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

/// Pulsing glow ring (used behind the current player / active elements).
struct GlowRing: View {
    var color: Color = MM.gold
    @State private var on = false
    var body: some View {
        Circle()
            .strokeBorder(color.opacity(on ? 0.15 : 0.6), lineWidth: 6)
            .scaleEffect(on ? 1.25 : 0.9)
            .onAppear { withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { on = true } }
    }
}

/// Bouncing entrance for stage titles.
struct Bouncy: ViewModifier {
    @State private var shown = false
    var delay: Double = 0
    func body(content: Content) -> some View {
        content
            .scaleEffect(shown ? 1 : 0.4)
            .opacity(shown ? 1 : 0)
            .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(delay)) { shown = true } }
    }
}

extension View {
    func bouncy(delay: Double = 0) -> some View { modifier(Bouncy(delay: delay)) }
}
