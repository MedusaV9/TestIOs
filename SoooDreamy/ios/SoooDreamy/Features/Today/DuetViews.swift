import SwiftUI
import Combine

/// Synchronized haptic duet — both iPhones play the same pattern at the
/// same server instant — plus the live heartbeat pad.
struct DuetSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPreset: HapticPreset? = HapticPresets.all.first
    @State private var starting = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(HapticPresets.all) { preset in
                        Button {
                            selectedPreset = preset
                            Haptics.shared.play(events: preset.events)
                        } label: {
                            HStack(spacing: 12) {
                                Text(preset.emoji).font(.title2)
                                Text(L10n.t(preset.nameKey))
                                    .foregroundStyle(.primary)
                                Spacer()
                                HapticTimelineBars(events: preset.events)
                                    .frame(width: 70, height: 18)
                                    .opacity(0.7)
                                if selectedPreset == preset {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                } header: {
                    Text(L10n.t("duet.pickPattern"))
                } footer: {
                    Text(L10n.t("duet.subtitle"))
                }

                Section {
                    Button {
                        startDuet()
                    } label: {
                        HStack {
                            Label(L10n.t("duet.start"), systemImage: "waveform.path.ecg")
                            if starting { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(starting || selectedPreset == nil || appState.partner == nil)
                } footer: {
                    if appState.partner?.online != true {
                        Text(L10n.t("duet.hint", ["name": appState.partnerName]))
                    }
                }

                Section(L10n.t("heartbeat.live.title")) {
                    LiveHeartbeatPad()
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }
            }
            .navigationTitle(L10n.t("duet.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.done")) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            ClockSync.shared.sample(via: appState.socket)
        }
    }

    private func startDuet() {
        guard let preset = selectedPreset, !starting else { return }
        starting = true
        Task {
            await appState.startDuet(events: preset.events, name: L10n.t(preset.nameKey))
            starting = false
            dismiss()
        }
    }
}

/// Tap the heart — the partner's phone pulses instantly (and vice versa).
struct LiveHeartbeatPad: View {
    @Environment(AppState.self) private var appState

    @State private var myPulse = false
    @State private var partnerPulse = false
    @State private var taps = 0

    var body: some View {
        VStack(spacing: 12) {
            Text(L10n.t(appState.partner?.online == true ? "heartbeat.live.hint" : "heartbeat.live.offline",
                        ["name": appState.partnerName]))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            ZStack {
                Circle()
                    .stroke(Color(hex: appState.partner?.color ?? "A855F7"), lineWidth: 3)
                    .scaleEffect(partnerPulse ? 1.25 : 1)
                    .opacity(partnerPulse ? 0 : 0.6)
                Circle()
                    .fill(Color.accentColor.gradient)
                    .scaleEffect(myPulse ? 1.08 : 1)
                Image(systemName: "heart.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: taps)
            }
            .frame(width: 120, height: 120)
            .contentShape(Circle())
            .onTapGesture { tap() }
            .accessibilityLabel(L10n.t("heartbeat.live.title"))
            .accessibilityAddTraits(.isButton)
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.impact(weight: .heavy), trigger: taps)
        .onChange(of: appState.partnerTapCount) { _, _ in
            withAnimation(.easeOut(duration: 0.5)) { partnerPulse = true }
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                partnerPulse = false
            }
        }
    }

    private func tap() {
        taps += 1
        appState.sendHeartbeatTap(intensity: 0.8)
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { myPulse = true }
        Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            withAnimation(.spring(response: 0.3)) { myPulse = false }
        }
    }
}

/// Full-screen moment while a duet counts down and plays (both phones).
struct DuetOverlayView: View {
    @Environment(AppState.self) private var appState
    let duet: DuetSession

    @State private var now = Date()
    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var fireAt: Date {
        ClockSync.shared.localDate(forServerMs: duet.startAtMs, fallbackServerNowMs: duet.serverNowMs)
    }

    private var playing: Bool { now >= fireAt }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.5))
                .ignoresSafeArea()
            if playing {
                FloatingHeartsView(emojis: ["💓", "💗", "✨"], count: 16)
                    .ignoresSafeArea()
            }

            VStack(spacing: 18) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 88))
                    .foregroundStyle(Color.accentColor)
                    .scaleEffect(playing ? 1.15 : 0.96)
                    .animation(.easeInOut(duration: playing ? 0.4 : 0.8).repeatForever(autoreverses: true), value: playing)
                    .accessibilityHidden(true)

                if let name = duet.name, !name.isEmpty {
                    Text(name)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                if playing {
                    Text(L10n.t("duet.playing"))
                        .font(.title2.weight(.bold))
                } else {
                    Text(duet.startedBy == appState.memberId
                         ? L10n.t("duet.countdown")
                         : L10n.t("duet.startedBy", ["name": appState.partnerName]))
                        .font(.title3.weight(.semibold))
                    Text(String(format: "%.1f", max(0, fireAt.timeIntervalSince(now))))
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .multilineTextAlignment(.center)
            .padding(30)
            .frame(maxWidth: 340)
            .glassEffect(.regular, in: .rect(cornerRadius: 32))
            .padding(.horizontal, 24)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Dismisses only the overlay; the scheduled playback continues.
            withAnimation(.spring(response: 0.35)) { appState.activeDuet = nil }
        }
        .onReceive(ticker) { date in now = date }
    }
}
