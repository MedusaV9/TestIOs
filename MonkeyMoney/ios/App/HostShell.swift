import SwiftUI
import AVFoundation

/// Owns the embedded show host for the app's lifetime.
@MainActor
final class HostController: ObservableObject {
    @Published var stageURL: URL?
    @Published var error: String?
    private var host: ShowHost?

    init() { start() }

    static var storage: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("MonkeyMoney", isDirectory: true)
    }

    private static func resource(_ name: String) -> URL {
        Bundle.main.url(forResource: name, withExtension: nil) ?? Bundle.main.bundleURL.appendingPathComponent(name)
    }

    func start() {
        // Stage audio (Web Audio in the web view) plays through the speaker even with the mute switch on.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        UIApplication.shared.isIdleTimerDisabled = true
        let catalog = Edition.catalog((try? ContentCatalog.load(from: Self.resource("Content"))) ?? .empty)
        let roots = ShowServer.Roots(web: Self.resource("Web"), fonts: Self.resource("Fonts"), content: Self.resource("Content"), audio: Self.resource("Audio"))
        let h = ShowHost(config: .init(storage: Self.storage, roots: roots, catalog: catalog, edition: Edition.name, editionQuestionSet: Edition.defaultSet))
        do {
            try h.start()
            host = h
            stageURL = URL(string: h.localStageURL)
            error = nil
        } catch {
            self.error = "Der Show-Server konnte nicht starten: \(error.localizedDescription)"
        }
    }
}

struct HostShellView: View {
    @EnvironmentObject var host: HostController

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.03, blue: 0.13).ignoresSafeArea()
            if let url = host.stageURL {
                WebView(url: url).ignoresSafeArea()
            } else if let e = host.error {
                VStack(spacing: 16) {
                    Text("🙈").font(.system(size: 80))
                    Text(e).foregroundStyle(.white).multilineTextAlignment(.center)
                    Button("Nochmal versuchen") { host.start() }
                }
                .padding(40)
            }
        }
    }
}
