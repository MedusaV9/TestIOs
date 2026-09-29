import SwiftUI

/// Universal app. On the iPad it is the whole show: the embedded ShowHost
/// (HTTP + WebSocket server, engine, saves, profiles, bots) plus a full-screen
/// web view on `http://127.0.0.1:<port>/stage` — the stage UI is the same web
/// app the browser tests drive. On the iPhone it is a thin controller shell
/// that opens the iPad's player page.
@main
struct MonkeyMoneyApp: App {
    @StateObject private var host = HostController()
    @StateObject private var phone = PhoneController()

    var body: some Scene {
        WindowGroup {
            Group {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    HostShellView().environmentObject(host)
                } else {
                    PhoneShellView().environmentObject(phone)
                }
            }
            .preferredColorScheme(.dark)
            .statusBarHidden(true)
            .onOpenURL { url in phone.handle(url: url) }
            .onContinueUserActivity("NSUserActivityTypeBrowsingWeb") { activity in
                if let url = activity.webpageURL { phone.handle(url: url) }
            }
        }
    }
}
