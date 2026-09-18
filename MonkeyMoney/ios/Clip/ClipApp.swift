import SwiftUI

/// App Clip: the phone controller launched from the QR code on the iPad.
/// The invocation URL (https://<domain>/j/CODE?host=<ip:port>) carries the
/// room code and the iPad's LAN address, so the clip connects without typing.
/// Note: App Clip invocation requires App Store / TestFlight distribution
/// with the associated domain registered; for sideloaded builds the same
/// screens ship inside the main app (monkeymoney:// links + QR scanner).
@main
struct MonkeyMoneyClipApp: App {
    @StateObject private var player = PlayerModel()

    var body: some Scene {
        WindowGroup {
            PlayerRootView()
                .environmentObject(player)
                .preferredColorScheme(.dark)
                .onContinueUserActivity("NSUserActivityTypeBrowsingWeb") { activity in
                    if let url = activity.webpageURL { player.handle(url: url) }
                }
                .onOpenURL { url in player.handle(url: url) }
                .onAppear {
                    // Xcode scheme testing: _XCAppClipURL environment variable.
                    if let s = ProcessInfo.processInfo.environment["_XCAppClipURL"], let url = URL(string: s) { player.handle(url: url) }
                }
        }
    }
}
