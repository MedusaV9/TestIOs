import AppIntents
import SwiftUI
import WidgetKit

// v3.0 iOS-18 controls (Agent C): Control Center / Lock Screen / Action
// Button shortcuts. Both reuse the widget-process plumbing that already
// exists (WidgetSendTouchIntent + app-group server credentials), so they
// work without launching the app. Included in the bundle behind
// #available(iOS 18) — iOS 17 users simply don't see them.

/// "Herzklopfen senden": one tap anywhere → the partner's phone pulses.
struct HeartbeatControlWidget: ControlWidget {
    static let kind = "app.sooodreamy.control.heartbeat"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: WidgetSendTouchIntent(type: .heartbeat)) {
                Label("Herzklopfen senden · Send heartbeat", systemImage: "heart.fill")
            }
        }
        .displayName("Herzklopfen · Heartbeat")
        .description("Sendet deinem Schatz sofort ein Herzklopfen · instantly sends your love a heartbeat")
    }
}

/// Opens the app right on the dashboard where the need button lives.
struct OpenNeedButtonControlWidget: ControlWidget {
    static let kind = "app.sooodreamy.control.need"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenNeedButtonIntent()) {
                Label("Bedürfnis-Knopf · Need button", systemImage: "hand.raised.fill")
            }
        }
        .displayName("Bedürfnis-Knopf · Need button")
        .description("Öffnet SoooDreamy beim Bedürfnis-Knopf · opens SoooDreamy at the need button")
    }
}

/// Launches the app via deep link (controls run in the widget process).
struct OpenNeedButtonIntent: AppIntent {
    static var title: LocalizedStringResource = "Bedürfnis-Knopf öffnen · Open need button"
    static var description = IntentDescription(
        "Öffnet SoooDreamy beim Bedürfnis-Knopf · opens SoooDreamy at the need button")
    static var openAppWhenRun: Bool = true

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "sooodreamy://need")!))
    }
}
