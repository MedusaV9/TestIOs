import SwiftUI

/// A full-screen moment for the two milestones that deserve more than a
/// toast: the day the couple becomes connected, and round day counters.
struct CoupleCutscene: Identifiable, Equatable {
    enum Kind: Equatable {
        case paired
        case milestone(days: Int)
    }

    let id = UUID()
    let kind: Kind
    let me: Member?
    let partner: Member?

    /// Day counters worth a cutscene (once each, see `AppState`).
    static let milestoneDays: Set<Int> = [100, 200, 300, 365, 500, 730, 1000, 1095, 1500, 2000, 3650]
}

/// Choreographed like the intro: the two real avatars fly in from the edges
/// and settle together, a heart draws itself above them, then the headline
/// and a line of text. Tap anywhere to jump to the end; Reduce Motion shows
/// the final frame immediately.
struct CoupleCutsceneView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    let cutscene: CoupleCutscene

    @State private var step: Step = .start
    @State private var burstAt: Date?
    @State private var runner: Task<Void, Never>?

    private enum Step: Int, Comparable {
        case start, avatars, heart, text, ready
        static func < (lhs: Step, rhs: Step) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    var body: some View {
        ZStack {
            background
            if let burstAt {
                FloatingHeartsView(emojis: burstEmojis, count: 28, startedAt: burstAt)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 28) {
                        Spacer(minLength: 0)
                        avatars
                        textBlock
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { skip() }
        .safeAreaInset(edge: .bottom) {
            if step >= .ready {
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
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.6, bounce: 0.18), value: step)
        .interactiveDismissDisabled(step < .ready)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(headline + ". " + subline)
        .task { await run() }
        .onDisappear { runner?.cancel() }
    }

    // MARK: Scenes

    /// Soft glow in the couple's own colors behind everything.
    private var background: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            RadialGradient(colors: [tint(cutscene.me).opacity(0.28), .clear],
                           center: .init(x: 0.3, y: 0.35), startRadius: 0, endRadius: 360)
            RadialGradient(colors: [tint(cutscene.partner).opacity(0.28), .clear],
                           center: .init(x: 0.7, y: 0.45), startRadius: 0, endRadius: 360)
        }
        .ignoresSafeArea()
    }

    private var avatars: some View {
        ZStack {
            MemberAvatar(member: cutscene.me, size: 104)
                .offset(x: step >= .avatars ? -44 : -260)
                .opacity(step >= .avatars ? 1 : 0)
                .zIndex(1)
            MemberAvatar(member: cutscene.partner, size: 104)
                .offset(x: step >= .avatars ? 44 : 260)
                .opacity(step >= .avatars ? 1 : 0)
            if step >= .heart {
                Image(systemName: "heart.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Color.accentColor.gradient)
                    .symbolEffect(.pulse, options: .repeating, isActive: step >= .ready && !reduceMotion)
                    .offset(y: -74)
                    .transition(reduceMotion ? .opacity : .symbolEffect(.drawOn))
                    .zIndex(2)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: 190)
        .animation(.spring(duration: 0.95, bounce: 0.3), value: step)
    }

    private var textBlock: some View {
        VStack(spacing: 12) {
            if step >= .text {
                Text(headline)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText())
                    .transition(.blurReplace)
                Text(subline)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .transition(.blurReplace.combined(with: .offset(y: 8)))
            }
        }
        .frame(minHeight: 110)
    }

    // MARK: Copy

    private var headline: String {
        switch cutscene.kind {
        case .paired:
            return L10n.t("cutscene.paired.title")
        case .milestone(let days):
            return L10n.t("cutscene.milestone.title", ["n": String(days)])
        }
    }

    private var subline: String {
        let a = cutscene.me?.name ?? L10n.t("common.you")
        let b = cutscene.partner?.name ?? L10n.t("common.partner")
        switch cutscene.kind {
        case .paired:
            return L10n.t("cutscene.paired.subtitle", ["a": a, "b": b])
        case .milestone(let days):
            return L10n.t("cutscene.milestone.subtitle", ["n": String(days), "a": a, "b": b])
        }
    }

    private var burstEmojis: [String] {
        switch cutscene.kind {
        case .paired: return ["💜", "💖", "💞", "✨"]
        case .milestone: return ["🎉", "✨", "💜", "🩷", "💫"]
        }
    }

    private func tint(_ member: Member?) -> Color {
        Color(hex: member?.color ?? "A855F7")
    }

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
                (.avatars, 300_000_000),
                (.heart, 1_100_000_000),
                (.text, 900_000_000),
                (.ready, 1_100_000_000),
            ]
            for (next, delay) in script {
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled, step < next else { return }
                step = next
                if next == .heart {
                    burstAt = Date()
                    SoundEngine.shared.play(cutscene.kind == .paired ? .tada : .win)
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
