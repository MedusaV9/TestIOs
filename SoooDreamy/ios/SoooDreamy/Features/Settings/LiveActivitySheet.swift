import SwiftUI

/// Live Activities (countdown & Couple Pulse): colour scheme, live ticker and
/// which elements are visible. The config lives in the app group and is
/// pushed INTO running activities immediately via the ContentState.
struct LiveActivityView: View {
    @Environment(AppState.self) private var appState

    @State private var config = SharedStore.readLiveActivityConfig()
    @State private var pulseRunning = CouplePulseController.isRunning

    private var themeSelection: Binding<String?> {
        Binding(get: { config.themeId }, set: { config.themeId = $0 ?? "night" })
    }

    var body: some View {
        List {
            Section(L10n.t("la.section.preview")) {
                LiveActivityPreview(config: config, partnerName: appState.partnerName)
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    .listRowBackground(Color.clear)
            }

            Section(L10n.t("la.theme")) {
                ThemeSwatchRow(selection: themeSelection)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section(L10n.t("la.elements")) {
                Toggle(isOn: $config.liveTimer) { Label(L10n.t("la.liveTimer"), systemImage: "timer") }
                Toggle(isOn: $config.showProgress) { Label(L10n.t("la.progress"), systemImage: "chart.bar.horizontal.page") }
                Toggle(isOn: $config.showPresence) { Label(L10n.t("la.presence"), systemImage: "dot.radiowaves.left.and.right") }
                Toggle(isOn: $config.showMood) { Label(L10n.t("la.mood"), systemImage: "face.smiling") }
                Toggle(isOn: $config.showTouch) { Label(L10n.t("la.touch"), systemImage: "hand.tap.fill") }
                Toggle(isOn: $config.showStreak) { Label(L10n.t("la.streak"), systemImage: "flame.fill") }
                Toggle(isOn: $config.showDaysTogether) { Label(L10n.t("la.days"), systemImage: "heart.circle.fill") }
            }

            Section {
                Toggle(isOn: pulseBinding) {
                    Label(L10n.t("settings.pulse"), systemImage: "heart.text.square.fill")
                }
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.t("settings.pulseHint"))
                    Text(L10n.t("la.limitHint"))
                }
            }

            Section {
                Label(L10n.t("la.countdownHintTitle"), systemImage: "calendar.badge.clock")
            } footer: {
                Text(L10n.t("la.countdownHint"))
            }
        }
        .navigationTitle(L10n.t("la.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, newValue in
            SharedStore.writeLiveActivityConfig(newValue)
            CouplePulseController.pushConfig()
            CountdownActivityController.pushConfig()
        }
    }

    /// Start/stop the Couple Pulse activity; the toggle snaps back when iOS
    /// refuses (permission off, activities disabled).
    private var pulseBinding: Binding<Bool> {
        Binding(
            get: { pulseRunning },
            set: { on in
                CouplePulseController.isEnabled = on
                if on {
                    if CouplePulseController.start(from: appState) {
                        pulseRunning = true
                        appState.notify(L10n.t("settings.pulseStarted"), style: .success)
                    } else {
                        pulseRunning = false
                        CouplePulseController.isEnabled = false
                        appState.notify(L10n.t("memories.events.liveFailed"), style: .error)
                    }
                } else {
                    CouplePulseController.stop()
                    pulseRunning = false
                }
            }
        )
    }
}
