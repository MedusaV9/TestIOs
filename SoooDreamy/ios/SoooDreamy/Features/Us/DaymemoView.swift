import SwiftUI
import AVFoundation
import Combine
import Observation

/// "Wie war dein Tag?" — one audio memo per day and partner. The partner's
/// memo unlocks only after you recorded yours (server-enforced); the streak
/// counts days on which both recorded.
struct DaymemoView: View {
    @Environment(AppState.self) private var appState

    @State private var days: [DaymemoDay] = []
    @State private var streak = 0
    @State private var loading = true
    @State private var showRecorder = false

    private var today: DaymemoDay? { days.first { $0.dateKey == SharedDates.todayKey() } }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.t("daymemo.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if streak > 0 {
                        Label("\(streak) · " + L10n.t("daymemo.streakHint"), systemImage: "flame.fill")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.orange)
                    }
                    Button {
                        showRecorder = true
                    } label: {
                        Label(L10n.t(today?.mine == nil ? "daymemo.record" : "daymemo.rerecord"), systemImage: "mic.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(appState.partner == nil)
                }
                .padding(.vertical, 4)
            } header: {
                Text(L10n.t("common.today"))
            } footer: {
                if today?.bothRecorded == true {
                    Text(L10n.t("daymemo.card.ready"))
                }
            }

            if let today {
                Section {
                    DaymemoDayRows(day: today)
                }
            }

            if loading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if days.filter({ $0.dateKey != SharedDates.todayKey() }).isEmpty {
                if today == nil {
                    ContentUnavailableView(L10n.t("daymemo.empty.title"), systemImage: "mic",
                                           description: Text(L10n.t("daymemo.empty.subtitle")))
                        .listRowBackground(Color.clear)
                }
            } else {
                Section(L10n.t("daymemo.history")) {
                    ForEach(days.filter { $0.dateKey != SharedDates.todayKey() }, id: \.dateKey) { day in
                        DisclosureGroup {
                            DaymemoDayRows(day: day)
                        } label: {
                            HStack {
                                Text(dayTitle(day.dateKey))
                                    .font(.body.weight(.medium))
                                Spacer()
                                if day.bothRecorded {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.green)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.t("daymemo.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showRecorder) {
            DaymemoRecorderSheet { day in apply(day) }
        }
        .task(id: appState.couple?.id) { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent, event.type == .daymemo,
                  let day = event.decode(DaymemoDay.self) else { return }
            apply(day)
        }
    }

    private func dayTitle(_ dateKey: String) -> String {
        guard let date = SharedDates.parse(dateKey) else { return dateKey }
        let cal = Calendar.current
        if cal.isDateInYesterday(date) { return L10n.t("chat.yesterday") }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func apply(_ day: DaymemoDay) {
        if let idx = days.firstIndex(where: { $0.dateKey == day.dateKey }) {
            days[idx] = day
        } else {
            days.insert(day, at: 0)
            days.sort { $0.dateKey > $1.dateKey }
        }
        streak = max(streak, day.streak)
        if day.dateKey == SharedDates.todayKey() { streak = day.streak }
    }

    private func reload() async {
        guard let api = appState.api else { loading = false; return }
        if let response = try? await api.daymemos(limit: 30) {
            days = response.days.sorted { $0.dateKey > $1.dateKey }
            streak = response.streak
        }
        loading = false
    }
}

/// Both memos of one day (mine + the partner's, locked until I recorded).
private struct DaymemoDayRows: View {
    @Environment(AppState.self) private var appState
    let day: DaymemoDay

    var body: some View {
        memoRow(title: L10n.t("daymemo.mine"), member: appState.me, memo: day.mine,
                missingText: L10n.t("daymemo.card.hint", ["name": appState.partnerName]))
        memoRow(title: L10n.t("daymemo.theirs", ["name": appState.partnerName]), member: appState.partner,
                memo: day.partner, missingText: partnerMissingText)
    }

    private var partnerMissingText: String {
        if day.partnerRecorded && day.partner == nil {
            return L10n.t("daymemo.locked", ["name": appState.partnerName])
        }
        return L10n.t("daymemo.card.waiting", ["name": appState.partnerName])
    }

    private func memoRow(title: String, member: Member?, memo: Daymemo?, missingText: String) -> some View {
        HStack(spacing: 12) {
            MemberAvatar(member: member, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                if let memo {
                    Text(chatDurationString(memo.durationSec ?? 0) + " · " + L10n.relativeShort(memo.recordedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(missingText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let memo {
                DaymemoPlayButton(memo: memo)
            } else if day.partnerRecorded && memo == nil && member?.id == appState.partner?.id {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Player

/// One app-wide player for day memos (same pattern as VoicePlayer).
@MainActor
@Observable
final class DaymemoPlayer {
    static let shared = DaymemoPlayer()

    private(set) var playingId: String?
    private(set) var isPlaying = false
    private(set) var progress: Double = 0

    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var fallbackDuration: Double = 0

    private init() {}

    func toggle(memo: Daymemo, api: API?) {
        if playingId == memo.id {
            if isPlaying {
                player?.pause()
                isPlaying = false
            } else {
                player?.play()
                isPlaying = true
            }
            return
        }
        guard let api, let request = api.mediaRequest(memo.url), let url = request.url else { return }
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": request.allHTTPHeaderFields ?? [:]
        ])
        let item = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer
        playingId = memo.id
        progress = 0
        fallbackDuration = memo.durationSec ?? 0
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.stop() }
        }
        timeObserver = newPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, let player = self.player else { return }
                var total = player.currentItem.map { $0.duration.seconds } ?? 0
                if !total.isFinite || total <= 0 { total = self.fallbackDuration }
                self.progress = total > 0 ? min(1, max(0, time.seconds / total)) : 0
            }
        }
        newPlayer.play()
        isPlaying = true
    }

    func stop() {
        if let timeObserver, let player { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        player?.pause()
        player = nil
        playingId = nil
        isPlaying = false
        progress = 0
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

private struct DaymemoPlayButton: View {
    @Environment(AppState.self) private var appState
    let memo: Daymemo

    private var player: DaymemoPlayer { DaymemoPlayer.shared }
    private var isCurrent: Bool { player.playingId == memo.id }

    var body: some View {
        Button {
            player.toggle(memo: memo, api: appState.api)
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.tertiaryCardBackground, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: isCurrent ? player.progress : 0)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: isCurrent && player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.footnote.weight(.bold))
            }
            .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .accessibilityLabel(L10n.t("daymemo.title"))
    }
}

// MARK: - Recorder sheet

private struct DaymemoRecorderSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var model = VoiceRecorderModel()
    @State private var sending = false
    let onSaved: (DaymemoDay) -> Void

    private let maxDuration: Double = 60

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 0)
                stage
                Spacer(minLength: 0)
                HStack(spacing: 12) {
                    Button(L10n.t("common.cancel"), role: .cancel) {
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
            .padding(24)
            .navigationTitle(L10n.t("daymemo.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(sending)
        .task { await model.start() }
        .onDisappear { model.cancel() }
        .onChange(of: model.elapsed) { _, elapsed in
            if elapsed >= maxDuration && model.phase == .recording { model.finishRecording() }
        }
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
                Text("\(chatDurationString(model.phase == .recorded ? model.recordedDuration : model.elapsed)) / \(chatDurationString(maxDuration))")
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Label(L10n.t(model.phase == .recording ? "chat.voiceRecording" : "chat.voiceReady"),
                      systemImage: model.phase == .recording ? "record.circle" : "checkmark.circle")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(model.phase == .recording ? Color.red : Color.green)
                Text(L10n.t("daymemo.maxHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var primaryLabel: String {
        if sending { return L10n.t("daymemo.sending") }
        switch model.phase {
        case .recording, .recorded: return L10n.t("daymemo.saveMemo")
        case .idle, .denied, .failed: return L10n.t("chat.voiceRetry")
        }
    }

    private func primaryAction() {
        switch model.phase {
        case .recording, .recorded:
            stopAndSave()
        case .idle, .denied, .failed:
            Task { await model.start() }
        }
    }

    private func stopAndSave() {
        guard !sending else { return }
        if model.phase == .recording { model.finishRecording() }
        guard model.phase == .recorded else { return }
        if model.recordedDuration < 1 {
            appState.notify(L10n.t("daymemo.tooShort"), style: .info)
            model.cancel()
            Task { await model.start() }
            return
        }
        guard let data = model.recordedData(), let api = appState.api else { return }
        sending = true
        Task {
            do {
                let duration = min(model.recordedDuration, maxDuration)
                let day = try await api.uploadDaymemo(dateKey: SharedDates.todayKey(), data: data, durationSec: duration)
                SoundEngine.shared.play(.chime)
                appState.notify(L10n.t("daymemo.savedToast"), style: .love)
                if day.bothRecorded { Delight.celebrate(.medium, theme: .stars) }
                onSaved(day)
                dismiss()
            } catch {
                sending = false
                appState.handleAPIError(error)
            }
        }
    }
}
