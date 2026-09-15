import SwiftUI
import UserNotifications

@main
struct SoooDreamyApp: App {
    @UIApplicationDelegateAdaptor(RemotePushAppDelegate.self) private var pushDelegate
    @State private var appState = AppState()
    @State private var appLock = AppLock()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    init() {
        // Foreground banners + notification-tap deep links.
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(appLock)
                .preferredColorScheme(appearance.colorScheme)
                .task {
                    NotificationDelegate.shared.onOpenLink = { url in
                        appState.handleURL(url)
                    }
                    await appState.bootstrap()
                    // Ask for permission up-front only when paired and couple
                    // alerts are on. APNs registration then either produces a
                    // token or honestly fails on entitlement-less sideloads.
                    if NotificationPrefs.enabled && appState.phase == .main {
                        _ = await RemotePushRegistration.requestIfAuthorized()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .remotePushToken)) { note in
                    guard let token = note.object as? String else { return }
                    Task { await appState.registerPushToken(token) }
                }
                .onOpenURL { url in
                    appState.handleURL(url)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        if appState.phase == .main {
                            appState.connectSocket()
                            Task { await appState.refreshAll() }
                        }
                        if appLock.locked {
                            Task { await appLock.unlock() }
                        }
                    case .background:
                        appState.updateWidgetSnapshot()
                        appLock.lockIfNeeded()
                        // Ask iOS for a periodic background refresh so the
                        // widgets stay fresh without the app being opened.
                        BackgroundRefresh.schedule()
                    default:
                        break
                    }
                }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.taskId)) {
            // Headless refresh: pull partner status/moments/daily state,
            // rewrite the app-group snapshot, reload widget timelines —
            // then immediately queue the next run.
            await BackgroundRefresh.refreshNow()
            BackgroundRefresh.schedule()
        }
    }
}
