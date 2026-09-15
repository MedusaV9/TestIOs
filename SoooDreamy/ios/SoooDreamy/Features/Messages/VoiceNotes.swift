import SwiftUI
import AVFoundation
import Observation

/// "m:ss" for voice note durations and the recorder timer.
func chatDurationString(_ seconds: Double) -> String {
    let total = max(0, Int(seconds.rounded()))
    return String(format: "%d:%02d", total / 60, total % 60)
}

// MARK: - Shared voice message player

/// One app-wide player for voice messages: starting a new message pauses the
/// previous one. Publishes which message is playing plus playback progress.
@MainActor
@Observable
final class VoicePlayer {
    static let shared = VoicePlayer()

    /// Cycled by the speed button: 1× → 1.5× → 2× → 1×.
    static let playbackRates: [Double] = [1.0, 1.5, 2.0]

    private(set) var playingId: String?
    private(set) var isPlaying = false
    /// 0…1 for the currently playing message.
    private(set) var progress: Double = 0
    /// Total duration (seconds) of the current message, 0 when unknown.
    private(set) var duration: Double = 0
    /// Playback speed; kept across messages so the preference sticks.
    private(set) var rate: Double = 1.0

    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var fallbackDuration: Double = 0

    private init() {}

    /// "1×", "1.5×", "2×" — literal labels, deliberately not localized.
    var rateLabel: String {
        rate == rate.rounded() ? "\(Int(rate))×" : String(format: "%.1f×", rate)
    }

    /// Seconds left in the current message at the current progress.
    var remainingSeconds: Double { max(0, duration * (1 - progress)) }

    func toggle(message: Message, api: API?) {
        if playingId == message.id {
            if isPlaying { pause() } else { resume() }
            return
        }
        guard let api,
              let path = message.audioUrl,
              let request = api.mediaRequest(path),
              let url = request.url else { return }
        stop()
        activatePlaybackSession()
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": request.allHTTPHeaderFields ?? [:]
        ])
        let item = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer
        playingId = message.id
        progress = 0
        fallbackDuration = message.durationSec ?? 0
        duration = fallbackDuration
        newPlayer.defaultRate = Float(rate)
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stop()
            }
        }
        timeObserver = newPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.updateProgress(time)
            }
        }
        newPlayer.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func resume() {
        activatePlaybackSession()
        player?.play()
        isPlaying = true
    }

    func stop() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        player?.pause()
        player = nil
        playingId = nil
        isPlaying = false
        progress = 0
        duration = 0
        restoreAmbientSession()
    }

    /// Jump to a position (0…1) in the current message — works while paused too.
    func seek(toProgress target: Double) {
        let clamped = min(1, max(0, target))
        progress = clamped
        guard let player, duration > 0 else { return }
        let time = CMTime(seconds: clamped * duration, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// Advance to the next playback speed (1× → 1.5× → 2× → 1×).
    func cycleRate() {
        let rates = Self.playbackRates
        let index = rates.firstIndex(of: rate) ?? 0
        rate = rates[(index + 1) % rates.count]
        player?.defaultRate = Float(rate)
        if isPlaying { player?.rate = Float(rate) }
    }

    private func updateProgress(_ time: CMTime) {
        guard let player else { return }
        var total = player.currentItem.map { $0.duration.seconds } ?? 0
        if !total.isFinite || total <= 0 { total = fallbackDuration }
        duration = total
        guard total > 0 else {
            progress = 0
            return
        }
        progress = min(1, max(0, time.seconds / total))
    }

    private func activatePlaybackSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// The app's SoundEngine depends on the ambient/mix-with-others session.
    private func restoreAmbientSession() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

// MARK: - Recorder model

@MainActor
@Observable
final class VoiceRecorderModel {
    enum Phase: Equatable {
        case idle, denied, failed, recording, recorded
    }

    static let maxDuration: Double = 120

    private(set) var phase: Phase = .idle
    private(set) var elapsed: Double = 0
    /// Rolling window of normalized (0…1) meter levels for the live bars.
    private(set) var levels: [Double] = []
    private(set) var recordedDuration: Double = 0

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var meterTimer: Timer?
    @ObservationIgnored private var fileURL: URL?

    func start() async {
        guard phase != .recording else { return }
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            phase = .denied
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("voice-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.isMeteringEnabled = true
            rec.prepareToRecord()
            rec.record()
            recorder = rec
            fileURL = url
            elapsed = 0
            levels = []
            recordedDuration = 0
            phase = .recording
            startMeterTimer()
        } catch {
            restoreAmbientSession()
            phase = .failed
        }
    }

    /// Stops the recording, keeps the file, restores the audio session.
    func finishRecording() {
        guard phase == .recording, let recorder else { return }
        recordedDuration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        meterTimer?.invalidate()
        meterTimer = nil
        elapsed = recordedDuration
        restoreAmbientSession()
        phase = .recorded
    }

    /// Discards everything (also safe to call after a successful send).
    func cancel() {
        meterTimer?.invalidate()
        meterTimer = nil
        recorder?.stop()
        recorder = nil
        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        fileURL = nil
        restoreAmbientSession()
        phase = .idle
    }

    func recordedData() -> Data? {
        guard let fileURL else { return nil }
        return try? Data(contentsOf: fileURL)
    }

    // MARK: Internals

    private func startMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard phase == .recording, let recorder else { return }
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)       // -160…0 dB
        let level = pow(10.0, Double(power) / 20.0)            // → 0…1
        levels.append(min(1, max(0.04, level * 1.6)))
        if levels.count > 40 {
            levels.removeFirst(levels.count - 40)
        }
        elapsed = recorder.currentTime
        if elapsed >= Self.maxDuration {
            finishRecording()
        }
    }

    /// The app's SoundEngine depends on the ambient/mix-with-others session.
    private func restoreAmbientSession() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

// MARK: - Voice bubble (playback UI in the chat list)

struct ChatVoiceBubble: View {
    @Environment(AppState.self) private var appState
    let message: Message
    let isMine: Bool
    let onReact: (String) -> Void
    var onDelete: (() -> Void)? = nil

    /// Non-nil while the user drags the scrub slider; the seek happens on release.
    @State private var scrubProgress: Double?

    private var player: VoicePlayer { VoicePlayer.shared }
    private var isCurrent: Bool { player.playingId == message.id }

    private var displayedProgress: Double {
        guard isCurrent else { return 0 }
        return scrubProgress ?? player.progress
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                player.toggle(message: message, api: appState.api)
            } label: {
                Image(systemName: isCurrent && player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.body.weight(.bold))
                    .foregroundStyle(isMine ? Color.accentColor : Color.white)
                    .frame(width: 36, height: 36)
                    .background(isMine ? Color.white : Color.accentColor, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("chat.voiceMessage"))

            VStack(alignment: .leading, spacing: 5) {
                ChatWaveformBars(seed: message.id,
                                 progress: displayedProgress,
                                 activeTint: isMine ? .white : Color.accentColor,
                                 inactiveTint: isMine ? .white.opacity(0.4) : Color.secondary.opacity(0.35))
                if isCurrent {
                    Slider(value: Binding(get: { scrubProgress ?? player.progress },
                                          set: { scrubProgress = $0 }),
                           in: 0...1) { editing in
                        if !editing {
                            if let target = scrubProgress { player.seek(toProgress: target) }
                            scrubProgress = nil
                        }
                    }
                    .tint(isMine ? .white : Color.accentColor)
                    .frame(height: 20)
                }
                HStack(spacing: 8) {
                    Text(timeText)
                        .font(.caption2.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(ChatBubbleShape.secondaryText(isMine: isMine))
                    if isCurrent {
                        Button {
                            player.cycleRate()
                        } label: {
                            Text(player.rateLabel)
                                .font(.caption2.weight(.bold))
                                .monospacedDigit()
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(isMine ? Color.white.opacity(0.9) : Color.accentColor, in: Capsule())
                                .foregroundStyle(isMine ? Color.accentColor : Color.white)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: player.rateLabel))
                    }
                    ChatTimestampText(date: message.createdAt, isMine: isMine,
                                      read: chatReadReceipt(for: message, isMine: isMine, partner: appState.partner))
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: 300)
        .background(ChatBubbleShape.fill(isMine: isMine), in: ChatBubbleShape.shape)
        .onTapGesture(count: 2) { onReact(ChatReactions.quick) }
        .contextMenu {
            ChatReactMenu(onReact: onReact)
            ChatPinButton(message: message)
            if let onDelete { ChatDeleteButton(onDelete: onDelete) }
        }
    }

    /// Remaining time ("-m:ss") while this message is loaded, total duration otherwise.
    private var timeText: String {
        if isCurrent, player.duration > 0 {
            return "-" + chatDurationString(max(0, player.duration * (1 - displayedProgress)))
        }
        return chatDurationString(message.durationSec ?? 0)
    }
}

/// Static waveform: bar heights derived deterministically from the message
/// id, tinted up to the current playback progress.
struct ChatWaveformBars: View {
    let heights: [CGFloat]
    let progress: Double
    let activeTint: Color
    let inactiveTint: Color

    private static let barCount = 24

    init(seed: String, progress: Double, activeTint: Color, inactiveTint: Color) {
        self.heights = Self.makeHeights(seed: seed)
        self.progress = progress
        self.activeTint = activeTint
        self.inactiveTint = inactiveTint
    }

    var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(0..<Self.barCount, id: \.self) { i in
                Capsule()
                    .fill(i < activeCount ? activeTint : inactiveTint)
                    .frame(width: 3, height: 6 + heights[i] * 20)
            }
        }
        .frame(height: 28)
        .accessibilityHidden(true)
    }

    private var activeCount: Int { Int(progress * Double(Self.barCount)) }

    private static func makeHeights(seed: String) -> [CGFloat] {
        var state: UInt64 = 0x9E3779B97F4A7C15
        for byte in seed.utf8 {
            state = (state ^ UInt64(byte)) &* 0x100000001B3
        }
        func rnd() -> CGFloat {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((state >> 33) & 0xFFFFFF) / CGFloat(0xFFFFFF)
        }
        return (0..<barCount).map { _ in 0.15 + rnd() * 0.85 }
    }
}

// MARK: - Recorder sheet

struct VoiceRecorderSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var model = VoiceRecorderModel()
    @State private var sending = false
    let onSent: (Message) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 0)
                stage
                Spacer(minLength: 0)
                buttons
            }
            .padding(24)
            .navigationTitle(L10n.t("chat.voiceTitle"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(sending)
        .task { await model.start() }
        .onDisappear { model.cancel() }
    }

    @ViewBuilder private var stage: some View {
        switch model.phase {
        case .idle:
            ProgressView()
        case .denied:
            ContentUnavailableView(L10n.t("chat.voiceDeniedTitle"), systemImage: "mic.slash",
                                   description: Text(L10n.t("chat.voiceDeniedSubtitle")))
        case .failed:
            ContentUnavailableView(L10n.t("chat.voiceFailedTitle"), systemImage: "exclamationmark.triangle",
                                   description: Text(L10n.t("chat.voiceFailedSubtitle")))
        case .recording, .recorded:
            VStack(spacing: 14) {
                ChatRecorderLevelBars(levels: model.levels, live: model.phase == .recording)
                Text(timeLabel)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Label(L10n.t(model.phase == .recording ? "chat.voiceRecording" : "chat.voiceReady"),
                      systemImage: model.phase == .recording ? "record.circle" : "checkmark.circle")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(model.phase == .recording ? Color.red : Color.green)
                    .symbolEffect(.pulse, isActive: model.phase == .recording)
                Text(L10n.t("chat.voiceMaxHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var timeLabel: String {
        let current = model.phase == .recorded ? model.recordedDuration : model.elapsed
        return "\(chatDurationString(current)) / \(chatDurationString(VoiceRecorderModel.maxDuration))"
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button(L10n.t("chat.cancel"), role: .cancel) {
                model.cancel()
                dismiss()
            }
            .buttonStyle(.glass)
            .disabled(sending)

            Button {
                primaryAction()
            } label: {
                HStack {
                    if sending { ProgressView().tint(.white) }
                    Text(primaryLabel)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .disabled(sending || model.phase == .idle)
        }
        .controlSize(.large)
    }

    private var primaryLabel: String {
        if sending { return L10n.t("chat.voiceSending") }
        switch model.phase {
        case .recording: return L10n.t("chat.voiceStopSend")
        case .recorded: return L10n.t("chat.voiceSend")
        case .idle, .denied, .failed: return L10n.t("chat.voiceRetry")
        }
    }

    private func primaryAction() {
        switch model.phase {
        case .recording, .recorded:
            stopAndSend()
        case .idle, .denied, .failed:
            Task { await model.start() }
        }
    }

    private func stopAndSend() {
        guard !sending else { return }
        if model.phase == .recording { model.finishRecording() }
        guard model.phase == .recorded else { return }
        if model.recordedDuration < 0.5 {
            appState.notify(L10n.t("chat.voiceTooShort"), style: .info)
            model.cancel()
            Task { await model.start() }
            return
        }
        guard let data = model.recordedData(), let api = appState.api else { return }
        sending = true
        Task {
            do {
                let message = try await api.sendVoice(data: data, durationSec: model.recordedDuration)
                SoundEngine.shared.play(.pop)
                appState.notify(L10n.t("chat.voiceSent"), style: .love)
                onSent(message)
                dismiss()
            } catch {
                sending = false
                appState.handleAPIError(error)
            }
        }
    }
}

/// Live input level bars while recording.
struct ChatRecorderLevelBars: View {
    let levels: [Double]
    var live: Bool = true

    private static let barCount = 36

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<Self.barCount, id: \.self) { i in
                let offset = levels.count - Self.barCount + i
                let level = (offset >= 0 && offset < levels.count) ? levels[offset] : 0.04
                Capsule()
                    .fill(Color.accentColor.gradient)
                    .opacity(live ? 0.45 + 0.55 * level : 0.5)
                    .frame(width: 4, height: 8 + CGFloat(level) * 54)
            }
        }
        .frame(height: 64)
        .accessibilityHidden(true)
    }
}
