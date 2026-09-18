import SwiftUI

/// Universal app: the iPad is the stage (host/server + save store), the
/// iPhone is the controller (player or Show-Master). The App Clip reuses the
/// player UI (see Clip/).
@main
struct MonkeyMoneyApp: App {
    @StateObject private var host = HostModel()
    @StateObject private var player = PlayerModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    HostRootView().environmentObject(host)
                } else {
                    PlayerRootView().environmentObject(player)
                }
            }
            .preferredColorScheme(.dark)
            .statusBarHidden(true)
            .onOpenURL { url in player.handle(url: url) }
            .onContinueUserActivity("NSUserActivityTypeBrowsingWeb") { activity in
                if let url = activity.webpageURL { player.handle(url: url) }
            }
        }
    }
}
