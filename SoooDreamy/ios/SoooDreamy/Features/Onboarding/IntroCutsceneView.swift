import SwiftUI

/// First-launch intro in the spirit of Apple's own first-run sequences: a
/// short, choreographed reveal — two silhouettes drift together, a heart
/// draws itself between them, the name and tagline fade in, then three
/// promises — followed by a single call to action. Every step is a system
/// animation (springs, `blurReplace`, symbol draw-on); a tap anywhere or
/// "Skip" jumps to the final frame, and Reduce Motion shows that frame
/// straight away.
struct IntroCutsceneView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Real members when replayed by a paired couple; generic silhouettes otherwise.
    var me: Member? = nil
    var partner: Member? = nil
    var onFinish: () -> Void

    @State private var step: Step = .start
    @State private var burstAt: Date?
    @State private var runner: Task<Void, Never>?

    private enum Step: Int, Comparable {
        case start, avatars, heart, title, features, ready
        static func < (lhs: Step, rhs: Step) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            if let burstAt {
                FloatingHeartsView(emojis: ["💜", "💖", "✨", "💞"], count: 18, startedAt: burstAt)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // Scrolls only when accessibility text sizes outgrow the screen.
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        coupleGlyph
                            .padding(.bottom, 36)
                        titleBlock
                            .padding(.bottom, 32)
                        featureList
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 32)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { skip() }
        .overlay(alignment: .topTrailing) {
            if step < .ready {
                Button(L10n.t("intro.skip")) { skip() }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .padding(20)
                    .transition(.opacity)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if step >= .ready {
                VStack(spacing: 14) {
                    Label(L10n.t("intro.privacy"), systemImage: "lock.shield")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                    Button {
                        SoundEngine.shared.play(.chime)
                        onFinish()
                    } label: {
                        Text(L10n.t("common.continue"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.55, bounce: 0.15), value: step)
        .sensoryFeedback(.impact(weight: .light), trigger: step) { _, new in new == .avatars || new == .features }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.t("intro.a11y"))
        .task { await run() }
        .onDisappear { runner?.cancel() }
    }

    // MARK: Scenes

    /// Two silhouettes meeting, a heart appearing between them.
    private var coupleGlyph: some View {
        ZStack {
            person(me, fallbackTint: .accentColor)
                .offset(x: step >= .avatars ? -34 : -220, y: 0)
                .opacity(step >= .avatars ? 1 : 0)
                .zIndex(1)
            person(partner, fallbackTint: .purple)
                .offset(x: step >= .avatars ? 34 : 220, y: 0)
                .opacity(step >= .avatars ? 1 : 0)
            if step >= .heart {
                Image(systemName: "heart.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Color.accentColor.gradient)
                    .symbolEffect(.pulse, options: .repeating, isActive: step >= .ready && !reduceMotion)
                    .offset(y: -58)
                    .transition(.opacity.combined(with: .scale))
                    .accessibilityHidden(true)
            }
        }
        .frame(height: 150)
        .animation(.spring(duration: 0.9, bounce: 0.28), value: step)
    }

    @ViewBuilder
    private func person(_ member: Member?, fallbackTint: Color) -> some View {
        if let member {
            MemberAvatar(member: member, size: 84)
                .shadow(color: Color(hex: member.color).opacity(0.25), radius: 18, y: 8)
        } else {
            silhouette(tint: fallbackTint, symbol: "person.fill")
        }
    }

    private func silhouette(tint: Color, symbol: String) -> some View {
        Circle()
            .fill(tint.gradient)
            .frame(width: 84, height: 84)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
            }
            .shadow(color: tint.opacity(0.25), radius: 18, y: 8)
            .accessibilityHidden(true)
    }

    private var titleBlock: some View {
        VStack(spacing: 10) {
            if step >= .title {
                Text(L10n.t("onboarding.title"))
                    .font(.largeTitle.weight(.bold))
                    .transition(.blurReplace)
                Text(L10n.t("intro.tagline"))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .transition(.blurReplace.combined(with: .offset(y: 8)))
            }
        }
        .frame(minHeight: 96)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 18) {
            if step >= .features {
                ForEach(Array(Self.promises.enumerated()), id: \.offset) { index, promise in
                    Label {
                        Text(L10n.t(promise.key))
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: promise.symbol)
                            .font(.title2)
                            .foregroundStyle(promise.tint)
                            .frame(width: 36)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(duration: 0.6, bounce: 0.15).delay(Double(index) * 0.12), value: step)
                }
            }
        }
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 220 : 130, alignment: .top)
    }

    private static let promises: [(key: String, symbol: String, tint: Color)] = [
        ("intro.promise1", "sun.max.fill", .orange),
        ("intro.promise2", "bubble.left.and.bubble.right.fill", .blue),
        ("intro.promise3", "photo.on.rectangle.angled", .pink),
    ]

    // MARK: Choreography

    private func run() async {
        if reduceMotion {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { step = .ready }
            return
        }
        runner?.cancel()
        let task = Task { @MainActor in
            let script: [(Step, UInt64)] = [
                (.avatars, 350_000_000),
                (.heart, 1_050_000_000),
                (.title, 950_000_000),
                (.features, 850_000_000),
                (.ready, 1_000_000_000),
            ]
            for (next, delay) in script {
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled, step < next else { return }
                step = next
                if next == .heart {
                    burstAt = Date()
                    SoundEngine.shared.play(.sparkle)
                    Haptics.shared.success()
                }
            }
        }
        runner = task
        await task.value
    }

    private func skip() {
        guard step < .ready else { return }
        runner?.cancel()
        withAnimation(.spring(duration: 0.45)) {
            step = .ready
        }
    }
}
