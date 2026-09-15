import SwiftUI

/// Rising emoji particles for celebrations (partner joined, milestones,
/// incoming touches). Drawn in one Canvas pass; respects Reduce Motion by
/// rendering a single static frame.
struct FloatingHeartsView: View {
    var emojis: [String] = ["💜", "💖", "💗", "✨", "💞"]
    var count: Int = 18
    var startedAt = Date()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Particle {
        let x: CGFloat
        let delay: Double
        let speed: Double
        let size: CGFloat
        let sway: CGFloat
        let emojiIndex: Int
    }

    private var particles: [Particle] {
        var seed: UInt64 = 0xC0FFEE
        func rnd() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((seed >> 33) & 0xFFFFFF) / CGFloat(0xFFFFFF)
        }
        return (0..<count).map { i in
            Particle(x: 0.05 + rnd() * 0.9,
                     delay: Double(rnd()) * 1.4,
                     speed: 0.55 + Double(rnd()) * 0.8,
                     size: 18 + rnd() * 22,
                     sway: 14 + rnd() * 26,
                     emojiIndex: i % emojis.count)
        }
    }

    var body: some View {
        if reduceMotion {
            Color.clear
        } else {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSince(startedAt)
                    for p in particles {
                        let life = (t - p.delay) * p.speed
                        guard life > 0 else { continue }
                        let progress = life.truncatingRemainder(dividingBy: 1.0)
                        let y = size.height * (1.05 - CGFloat(progress) * 1.15)
                        let x = p.x * size.width + sin(life * 4) * p.sway
                        let alpha = progress < 0.15 ? progress / 0.15 : (1 - progress)
                        let resolved = context.resolve(Text(emojis[p.emojiIndex]).font(.system(size: p.size)))
                        context.opacity = alpha
                        context.draw(resolved, at: CGPoint(x: x, y: y))
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}
