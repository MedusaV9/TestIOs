import SwiftUI
import Combine

/// "Berühr mich" — record a vibration on the big heart pad (tap = knock,
/// hold = tremble), feel it, send it, or save it to the shared library.
/// Presets and the history of received vibes live below the pad.
struct TouchStudioView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var builder = HapticRecordingBuilder()
    @State private var padPressed = false
    @State private var patterns: [HapticPatternModel] = []
    @State private var received: [HapticSend] = []
    @State private var showSave = false
    @State private var busy = false
    @State private var renameTarget: HapticPatternModel?
    @State private var renameText = ""
    @State private var deleteTarget: HapticPatternModel?
    @State private var sentCount = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    padSection
                    presetsSection
                    librarySection
                    historySection
                    if !Haptics.deviceSupportsHaptics {
                        Label(L10n.t("haptic.deviceHint"), systemImage: "iphone.radiowaves.left.and.right")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardSurface(padding: 14)
                    }
                }
                .padding(Brand.screenInset)
                .padding(.bottom, 80)
            }
            .groupedScreenBackground()
            .navigationTitle(L10n.t("touchstudio.title"))
            .navigationSubtitle(L10n.t("touchstudio.subtitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.done")) { dismiss() }
                }
            }
            .safeAreaBar(edge: .bottom) {
                if !builder.isEmpty {
                    HStack(spacing: 10) {
                        Button {
                            Haptics.shared.play(events: builder.events)
                        } label: {
                            Image(systemName: "waveform")
                                .frame(width: 24)
                        }
                        .buttonStyle(.glass)
                        .accessibilityLabel(L10n.t("haptic.feel"))

                        Button {
                            Task { await sendRecording() }
                        } label: {
                            HStack {
                                if busy { ProgressView().tint(.white) }
                                Text(L10n.t("needs.sendTo", ["name": appState.partnerName]))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(busy || appState.partner == nil)

                        Button {
                            showSave = true
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                                .frame(width: 24)
                        }
                        .buttonStyle(.glass)
                        .accessibilityLabel(L10n.t("common.save"))
                    }
                    .controlSize(.large)
                    .padding(.horizontal, Brand.screenInset)
                    .padding(.bottom, 8)
                }
            }
        }
        .task { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent else { return }
            handleServerEvent(event)
        }
        .sheet(isPresented: $showSave) {
            HapticSaveSheet(events: builder.events) { name, emoji in
                Task { await savePattern(name: name, emoji: emoji) }
            }
        }
        .alert(L10n.t("haptic.rename"), isPresented: renameAlertBinding, presenting: renameTarget) { pattern in
            TextField("", text: $renameText)
            Button(L10n.t("common.save")) { Task { await rename(pattern, to: renameText) } }
            Button(L10n.t("common.cancel"), role: .cancel) {}
        } message: { _ in EmptyView() }
        .alert(L10n.t("haptic.deleteConfirm"), isPresented: deleteAlertBinding, presenting: deleteTarget) { pattern in
            Button(L10n.t("common.delete"), role: .destructive) { Task { await delete(pattern) } }
            Button(L10n.t("common.cancel"), role: .cancel) {}
        } message: { _ in EmptyView() }
        .sensoryFeedback(.success, trigger: sentCount)
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } })
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })
    }

    // MARK: Pad

    private var padSection: some View {
        VStack(spacing: 16) {
            ZStack {
                ForEach(0..<2, id: \.self) { ring in
                    Circle()
                        .strokeBorder(Color.accentColor.opacity(padPressed ? 0.35 - Double(ring) * 0.12 : 0.12), lineWidth: 2)
                        .frame(width: 200 + CGFloat(ring) * 44, height: 200 + CGFloat(ring) * 44)
                        .scaleEffect(padPressed ? 1.06 : 1)
                }
                Circle()
                    .fill(Color.accentColor.gradient)
                    .frame(width: 176, height: 176)
                    .scaleEffect(padPressed ? 0.94 : 1)
                    .shadow(color: Color.accentColor.opacity(padPressed ? 0.5 : 0.25), radius: padPressed ? 30 : 16)
                Image(systemName: "heart.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
                    .scaleEffect(padPressed ? 1.12 : 1)
            }
            .frame(width: 260, height: 260)
            .animation(.spring(response: 0.25), value: padPressed)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !padPressed else { return }
                        padPressed = true
                        builder.press(at: Date.timeIntervalSinceReferenceDate)
                        Haptics.shared.composerTick(intensity: 0.75)
                    }
                    .onEnded { _ in
                        padPressed = false
                        if let event = builder.release(at: Date.timeIntervalSinceReferenceDate), event.d > 0 {
                            Haptics.shared.composerTick(intensity: event.i)
                        }
                    }
            )
            .accessibilityLabel(L10n.t("touchstudio.title"))
            .accessibilityHint(L10n.t("haptic.pad.idle"))

            VStack(spacing: 6) {
                Text(L10n.t(builder.isEmpty && !padPressed ? "haptic.pad.idle" : "haptic.pad.active"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if builder.timelineStart != nil {
                    TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                        let elapsed = builder.elapsed(now: Date.timeIntervalSinceReferenceDate)
                        ProgressView(value: min(elapsed, HapticTimeline.maxSeconds), total: HapticTimeline.maxSeconds)
                            .frame(width: 160)
                    }
                }
            }

            if !builder.isEmpty {
                VStack(spacing: 8) {
                    HapticTimelineBars(events: builder.events)
                        .frame(height: 44)
                    HStack {
                        Text(L10n.t("haptic.events.count", ["n": String(builder.events.count)]))
                        Spacer()
                        Text(String(format: "%.1f s", builder.recordedDuration))
                            .monospacedDigit()
                        Button(role: .destructive) {
                            withAnimation(.snappy) { builder.reset() }
                        } label: {
                            Label(L10n.t("haptic.clear"), systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.borderless)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .cardSurface(padding: 14)
            }
        }
    }

    // MARK: Presets

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("haptic.presets.title"))
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(HapticPresets.all) { preset in
                        Button {
                            Haptics.shared.play(events: preset.events)
                        } label: {
                            VStack(spacing: 8) {
                                Text(preset.emoji).font(.title)
                                Text(L10n.t(preset.nameKey))
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                            }
                            .frame(width: 92, height: 92)
                            .background(Color.cardBackground,
                                        in: RoundedRectangle(cornerRadius: Brand.tileRadius, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                Task { await send(events: preset.events, name: L10n.t(preset.nameKey), emoji: preset.emoji) }
                            } label: {
                                Label(L10n.t("haptic.send"), systemImage: "paperplane")
                            }
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 0, for: .scrollContent)
        }
    }

    // MARK: Library

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("haptic.library.title"))
            if patterns.isEmpty {
                Text(L10n.t("haptic.library.empty"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface(padding: 14)
            } else {
                VStack(spacing: 0) {
                    ForEach(patterns) { pattern in
                        libraryRow(pattern)
                        if pattern.id != patterns.last?.id { Divider().padding(.leading, 56) }
                    }
                }
                .cardSurface(padding: 0)
            }
        }
    }

    private func libraryRow(_ pattern: HapticPatternModel) -> some View {
        HStack(spacing: 12) {
            Text(pattern.emoji ?? "💜")
                .font(.title2)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(pattern.name)
                    .font(.body.weight(.medium))
                HStack(spacing: 8) {
                    HapticTimelineBars(events: pattern.events)
                        .frame(width: 70, height: 14)
                        .opacity(0.7)
                    if let sent = pattern.sentCount, sent > 0 {
                        Text(L10n.t("haptic.sentCount", ["n": String(sent)]))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Button {
                Haptics.shared.play(events: pattern.events)
            } label: {
                Image(systemName: "waveform")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel(L10n.t("haptic.feel"))
            Button {
                Task { await send(pattern: pattern) }
            } label: {
                Image(systemName: "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(busy || appState.partner == nil)
            .accessibilityLabel(L10n.t("haptic.send"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contextMenu {
            Button {
                renameText = pattern.name
                renameTarget = pattern
            } label: {
                Label(L10n.t("haptic.rename"), systemImage: "pencil")
            }
            Button(role: .destructive) {
                deleteTarget = pattern
            } label: {
                Label(L10n.t("common.delete"), systemImage: "trash")
            }
        }
    }

    // MARK: History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("haptic.history.title"))
            if received.isEmpty {
                Text(L10n.t("haptic.history.empty"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface(padding: 14)
            } else {
                VStack(spacing: 0) {
                    ForEach(received.prefix(10)) { send in
                        HStack(spacing: 12) {
                            Text(send.emoji ?? "💜")
                                .font(.title3)
                                .frame(width: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(send.name ?? L10n.t("haptic.adhoc"))
                                    .font(.subheadline.weight(.medium))
                                Text(historySubtitle(send))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                Haptics.shared.play(events: send.events)
                            } label: {
                                Image(systemName: "waveform")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityLabel(L10n.t("haptic.replay"))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        if send.id != received.prefix(10).last?.id { Divider().padding(.leading, 56) }
                    }
                }
                .cardSurface(padding: 0)
            }
        }
    }

    private func historySubtitle(_ send: HapticSend) -> String {
        let who = send.senderId == appState.memberId
            ? L10n.t("haptic.fromYou")
            : L10n.t("haptic.fromPartner", ["name": appState.partnerName])
        return "\(who) · \(L10n.relativeShort(send.createdAt))"
    }

    // MARK: Server ops

    private func reload() async {
        guard let api = appState.api else { return }
        async let libraryTask = api.hapticPatterns()
        async let recentTask = api.recentHaptics()
        patterns = (try? await libraryTask) ?? patterns
        received = (try? await recentTask) ?? received
    }

    private func sendRecording() async {
        guard !builder.isEmpty else { return }
        await send(events: builder.events, name: nil, emoji: nil)
    }

    private func send(events: [HapticEventSpec], name: String?, emoji: String?) async {
        guard let api = appState.api, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            _ = try await api.sendHaptic(name: name, emoji: emoji, events: events)
            sentCount += 1
            SoundEngine.shared.play(.vibe)
            appState.notify(L10n.t("haptic.sent.toast", ["name": appState.partnerName]), style: .love)
        } catch {
            appState.handleAPIError(error)
        }
    }

    private func send(pattern: HapticPatternModel) async {
        guard let api = appState.api, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            _ = try await api.sendHapticPattern(id: pattern.id)
            sentCount += 1
            SoundEngine.shared.play(.vibe)
            appState.notify(L10n.t("haptic.sent.toast", ["name": appState.partnerName]), style: .love)
        } catch {
            appState.handleAPIError(error)
        }
    }

    private func savePattern(name: String, emoji: String?) async {
        guard let api = appState.api, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let pattern = try await api.saveHapticPattern(name: name, emoji: emoji, events: builder.events)
            upsert(pattern)
            withAnimation(.snappy) { builder.reset() }
            appState.notify(L10n.t("haptic.saved.toast"), style: .success)
        } catch {
            appState.handleAPIError(error)
        }
    }

    private func rename(_ pattern: HapticPatternModel, to name: String) async {
        guard let api = appState.api else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let updated = try await api.renameHapticPattern(id: pattern.id, name: trimmed, emoji: pattern.emoji)
            upsert(updated)
        } catch {
            appState.handleAPIError(error)
        }
    }

    private func delete(_ pattern: HapticPatternModel) async {
        guard let api = appState.api else { return }
        do {
            try await api.deleteHapticPattern(id: pattern.id)
            withAnimation(.snappy) { patterns.removeAll { $0.id == pattern.id } }
        } catch {
            appState.handleAPIError(error)
        }
    }

    private func upsert(_ pattern: HapticPatternModel) {
        if let idx = patterns.firstIndex(where: { $0.id == pattern.id }) {
            patterns[idx] = pattern
        } else {
            patterns.insert(pattern, at: 0)
        }
    }

    private func handleServerEvent(_ event: ServerEvent) {
        switch event.type {
        case .hapticPatternAdded, .hapticPatternUpdated:
            if let pattern = event.decode(HapticPatternResponse.self)?.pattern {
                withAnimation(.snappy) { upsert(pattern) }
            }
        case .hapticPatternDeleted:
            if let payload = event.decode(IdPayload.self) {
                withAnimation(.snappy) { patterns.removeAll { $0.id == payload.id } }
            }
        case .haptic:
            if let haptic = event.decode(HapticSendResponse.self)?.haptic {
                withAnimation(.snappy) { received.insert(haptic, at: 0) }
            }
        default:
            break
        }
    }
}

/// Name + emoji for a recording that goes into the shared library.
struct HapticSaveSheet: View {
    @Environment(\.dismiss) private var dismiss
    let events: [HapticEventSpec]
    let onSave: (String, String?) -> Void

    private static let emojis = ["💜", "💓", "🦋", "🌧️", "😘", "🌊", "✨", "🔥", "🌙", "🎵", "🫶", "⚡️"]

    @State private var name = ""
    @State private var emoji = "💜"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.t("haptic.save.nameField"), text: $name)
                    EmojiPickerGrid(emojis: Self.emojis, selection: $emoji, columns: 6)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }
                Section {
                    HapticTimelineBars(events: events)
                        .frame(height: 36)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(L10n.t("haptic.save.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.save")) {
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), emoji)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
