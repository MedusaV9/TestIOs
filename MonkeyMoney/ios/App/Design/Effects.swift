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

/// The Glücksrad as a fairground light board: the ten fields sit on a ring, a
/// running light races around them and slows to a crawl (`Wheel.chaseStep`,
/// the same deterministic model that drives the tick sounds) until it settles
/// on the result, which then pulses while the others dim.
struct LightChaseWheel: View {
    var segments: [WheelSegment]
    var resultIndex: Int?
    var spinStartedAt: Millis?
    var spinDurationMs: Int
    var landed: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let n = max(1, segments.count)
                let state = chase()
                let lit = state.lit
                let done = state.done
                let t = timeline.date.timeIntervalSince1970
                let ring = size * 0.36
                let tileW = size * 0.24, tileH = size * 0.19
                ZStack {
                    // Board plate + bulbs
                    Circle().fill(LinearGradient(colors: [Color(hex: "#2A8A4A"), MM.panelDark], startPoint: .top, endPoint: .bottom))
                        .frame(width: size * 0.98, height: size * 0.98)
                        .overlay(Circle().strokeBorder(MM.goldDark, lineWidth: 8))
                        .shadow(color: .black.opacity(0.5), radius: 20, y: 12)
                    ForEach(0..<24, id: \.self) { i in
                        let a = Double(i) / 24 * 2 * .pi
                        let on = done ? (Int(t * 6) + i) % 2 == 0 : (i % 3 == state.step % 3)
                        Circle().fill(on ? MM.cream : MM.gold.opacity(0.35)).frame(width: 9, height: 9)
                            .shadow(color: on ? MM.gold : .clear, radius: 6)
                            .offset(x: cos(a) * size * 0.47, y: sin(a) * size * 0.47)
                    }
                    // Fields on the ring
                    ForEach(Array(segments.enumerated()), id: \.offset) { i, seg in
                        let a = Double(i) / Double(n) * 2 * .pi - .pi / 2
                        let isLit = i == lit
                        let isPrev = !done && i == (lit + n - 1) % n
                        WheelTile(segment: seg, lit: isLit, trail: isPrev, dimmed: done && !isLit, won: done && isLit)
                            .frame(width: tileW, height: tileH)
                            .scaleEffect(isLit ? (done ? 1.14 + 0.03 * sin(t * 5) : 1.1) : 1)
                            .offset(x: cos(a) * ring, y: sin(a) * ring)
                    }
                    // Hub
                    ZStack {
                        Circle().fill(LinearGradient(colors: [MM.gold, MM.goldDark], startPoint: .top, endPoint: .bottom)).frame(width: size * 0.3, height: size * 0.3)
                            .overlay(Circle().strokeBorder(Color(hex: "#9A7418"), lineWidth: 4))
                            .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
                        if done, let r = resultIndex, segments.indices.contains(r) {
                            VStack(spacing: 0) {
                                Text(segments[r].emoji).font(.system(size: size * 0.09))
                                Text(segments[r].name.uppercased()).font(.outfit(size * 0.032, .black)).foregroundStyle(MM.ink).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.6)
                            }.frame(width: size * 0.26)
                        } else {
                            Text("🍌").font(.system(size: size * 0.12)).rotationEffect(.degrees(sin(t * 8) * 8))
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    /// Running-light state from the server clock (deterministic, never snaps).
    func chase() -> (lit: Int, step: Int, done: Bool) {
        let n = max(1, segments.count)
        let result = resultIndex ?? 0
        let total = Wheel.chaseSteps(segments: n, resultIndex: result)
        guard let start = spinStartedAt, spinDurationMs > 0 else { return (result, total, true) }
        let step = Wheel.chaseStep(elapsedMs: ServerClock.now() - start, durationMs: spinDurationMs, segments: n, resultIndex: result)
        let done = landed || step >= total
        return (done ? result : Wheel.chaseIndex(step: step, segments: n), step, done)
    }
}

/// One field of the light board.
struct WheelTile: View {
    var segment: WheelSegment
    var lit: Bool
    var trail: Bool
    var dimmed: Bool
    var won: Bool

    var tint: Color {
        switch segment.klasse {
        case .gruen: return MM.green
        case .blau: return MM.blue
        case .gold: return MM.gold
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(segment.emoji).font(.system(size: 26))
            Text(segment.name).font(.outfit(13, .black)).foregroundStyle(segment.klasse == .gold || lit ? MM.ink : .white)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.65)
        }
        .padding(.horizontal, 6).padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(lit ? Color(hex: "#FFF3B0") : (trail ? tint.opacity(0.95) : tint.opacity(dimmed ? 0.35 : 0.8)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(lit ? .white : MM.goldDark.opacity(0.8), lineWidth: lit ? 4 : 2))
                .shadow(color: lit ? MM.gold.opacity(0.95) : .black.opacity(0.35), radius: lit ? 22 : 6, y: 4)
        )
        .opacity(dimmed ? 0.55 : 1)
        .overlay(alignment: .topTrailing) { if won { Text("✨").font(.system(size: 20)).offset(x: 8, y: -10) } }
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
