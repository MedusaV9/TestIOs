import SwiftUI

/// Full-screen moment for an incoming touch (heartbeat, kiss, hug …):
/// dimmed backdrop, rising emoji, one Liquid Glass card. Tap to dismiss.
struct TouchMomentView: View {
    @Environment(AppState.self) private var appState
    let touch: Touch

    @State private var pulse = false

    private var hearts: [String] {
        switch touch.type {
        case .heartbeat: return ["💓", "💗", "💖"]
        case .kiss: return ["💋", "😘", "💖"]
        case .hug: return ["🫂", "🤗", "💞"]
        case .missyou: return ["🥺", "💌", "💜"]
        case .tickle: return ["🪶", "😂", "✨"]
        case .thinking: return ["💭", "💜", "✨"]
        }
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.45))
                .ignoresSafeArea()

            FloatingHeartsView(emojis: hearts, count: 22)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text(touch.type.emoji)
                    .font(.system(size: 96))
                    .scaleEffect(pulse ? 1.1 : 0.92)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulse)
                    .accessibilityHidden(true)

                Text(L10n.t("touch.received.\(touch.type.rawValue)", ["name": appState.partnerName]))
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(L10n.t("moment.tapToClose"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .frame(maxWidth: 340)
            .glassEffect(.regular, in: .rect(cornerRadius: 32))
            .padding(.horizontal, 24)
        }
        .contentShape(Rectangle())
        .onTapGesture { appState.incomingTouch = nil }
        .onAppear { pulse = true }
        .accessibilityAddTraits(.isModal)
    }
}

/// Full-screen moment for a custom vibration from the partner.
struct HapticMomentView: View {
    @Environment(AppState.self) private var appState
    let haptic: HapticSend

    @State private var pulse = false
    @State private var replays = 0

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.45))
                .ignoresSafeArea()

            FloatingHeartsView(emojis: [haptic.emoji ?? "💜", "💫", "✨"], count: 18)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    ForEach(0..<3, id: \.self) { ring in
                        Circle()
                            .strokeBorder(Color.accentColor.opacity(0.5 - Double(ring) * 0.14), lineWidth: 2)
                            .frame(width: 120 + CGFloat(ring) * 40, height: 120 + CGFloat(ring) * 40)
                            .scaleEffect(pulse ? 1.1 : 0.94)
                            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                                .delay(Double(ring) * 0.12), value: pulse)
                    }
                    Text(haptic.emoji ?? "💜")
                        .font(.system(size: 72))
                        .scaleEffect(pulse ? 1.1 : 0.92)
                        .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: pulse)
                }
                .frame(height: 210)
                .accessibilityHidden(true)

                VStack(spacing: 4) {
                    Text(haptic.name ?? L10n.t("haptic.received.title"))
                        .font(.title2.weight(.bold))
                    Text(L10n.t("haptic.received.overlay", ["name": appState.partnerName]))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)

                HapticTimelineBars(events: haptic.events)
                    .frame(width: 190, height: 30)

                Button {
                    replays += 1
                    Haptics.shared.play(events: haptic.events)
                } label: {
                    Label(L10n.t("haptic.replay"), systemImage: "waveform")
                }
                .buttonStyle(.glassProminent)
                .sensoryFeedback(.impact(weight: .light), trigger: replays)
            }
            .padding(28)
            .frame(maxWidth: 340)
            .glassEffect(.regular, in: .rect(cornerRadius: 32))
            .padding(.horizontal, 24)
        }
        .contentShape(Rectangle())
        .onTapGesture { appState.incomingHaptic = nil }
        .onAppear { pulse = true }
        .accessibilityAddTraits(.isModal)
    }
}

/// Compact bar chart of a haptic timeline (one bar per event, height =
/// intensity). Shared by the haptic moment, the studio and the chat.
struct HapticTimelineBars: View {
    let events: [HapticEventSpec]

    var body: some View {
        let total = max(0.6, HapticTimeline.duration(of: events))
        Canvas { context, size in
            for event in events {
                let x = CGFloat(event.t / total) * size.width
                let width = max(3, CGFloat(max(0.05, event.d) / total) * size.width)
                let height = max(4, CGFloat(event.i) * size.height)
                let rect = CGRect(x: x, y: (size.height - height) / 2, width: width, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(.accentColor))
            }
        }
        .accessibilityLabel(L10n.t("haptic.timeline.a11y", ["n": String(events.count)]))
    }
}
