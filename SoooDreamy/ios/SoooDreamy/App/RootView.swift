import SwiftUI

/// App root: onboarding → pairing → main tabs, plus the few full-screen
/// "moments" (incoming touch, duet, ceremonies) and the app lock.
struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppLock.self) private var appLock

    var body: some View {
        @Bindable var state = appState
        ZStack {
            switch appState.phase {
            case .welcome:
                OnboardingFlowView()
                    .transition(.opacity)
            case .pairing:
                PairingView()
                    .transition(.opacity)
            case .main:
                MainTabView()
                    .transition(.opacity)
            }

            if let touch = appState.incomingTouch {
                TouchMomentView(touch: touch)
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
                    .zIndex(10)
            }

            if let haptic = appState.incomingHaptic {
                HapticMomentView(haptic: haptic)
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
                    .zIndex(10)
            }

            if appState.celebrate {
                FloatingHeartsView(count: 26)
                    .ignoresSafeArea()
                    .zIndex(11)
            }

            if let duet = appState.activeDuet {
                DuetOverlayView(duet: duet)
                    .transition(.opacity)
                    .zIndex(9)
            }

            DelightOverlayHost()
                .zIndex(11)

            if let notice = appState.notice {
                VStack {
                    StatusNoticeView(notice: notice)
                        .padding(.top, 4)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(12)
            }

            if appLock.locked {
                LockScreenView()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .animation(.spring(response: 0.4), value: appState.phase)
        .animation(.spring(response: 0.4), value: appState.incomingTouch != nil)
        .animation(.spring(response: 0.4), value: appState.incomingHaptic != nil)
        .animation(.spring(response: 0.4), value: appState.notice)
        .animation(.spring(response: 0.4), value: appState.activeDuet != nil)
        .animation(.easeOut(duration: 0.3), value: appLock.locked)
        // Level-up / badge / icon-gift ceremonies are proper sheets; the FIFO
        // queue in AppStatePlatform advances when one is dismissed.
        // Presented covers sit above the lock overlay, so both moments wait
        // until the app is unlocked (the pending state survives the wait).
        .fullScreenCover(item: Binding(
            get: { appLock.locked ? nil : appState.coupleCutscene },
            set: { if $0 == nil { appState.coupleCutscene = nil } }
        ), onDismiss: { appState.presentWhatsNewIfNeeded() }) { cutscene in
            CoupleCutsceneView(cutscene: cutscene)
        }
        .sheet(isPresented: Binding(
            get: { !appLock.locked && appState.showWhatsNew },
            set: { appState.showWhatsNew = $0 }
        ), onDismiss: { appState.markWhatsNewSeen() }) {
            WhatsNewView()
        }
        .sheet(item: $state.levelUpCeremony, onDismiss: { appState.dismissActiveCelebration() }) { ceremony in
            LevelUpCeremonyView(ceremony: ceremony)
        }
        .sheet(item: $state.badgeCeremony, onDismiss: { appState.dismissActiveCelebration() }) { badge in
            BadgeCeremonyView(badge: badge)
        }
        .sheet(isPresented: Binding(
            get: { appState.phase == .main && appState.pendingIconGift != nil && appState.levelUpCeremony == nil && appState.badgeCeremony == nil },
            set: { if !$0 { appState.dismissPendingIconGift() } }
        )) {
            if let gift = appState.pendingIconGift {
                IconGiftUnwrapView(gift: gift)
            }
        }
        .alert(L10n.t("common.error"), isPresented: Binding(
            get: { appState.alertMessage != nil },
            set: { if !$0 { appState.alertMessage = nil } }
        )) {
            Button(L10n.t("common.ok"), role: .cancel) { appState.alertMessage = nil }
        } message: {
            Text(appState.alertMessage ?? "")
        }
        .id(appState.uiRefresh)   // full rebuild on in-app language switch
    }
}

/// The four Liquid Glass tabs — Heute · Nachrichten · Wir · Erinnerungen —
/// plus the iOS 26 search tab (rendered by the system as the separate
/// search button with the field in the tab bar).
struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        TabView(selection: $state.activeTab) {
            Tab(L10n.t("tab.today"), systemImage: "house.fill", value: AppTab.home) {
                TodayView()
            }
            .accessibilityLabel(L10n.t("tab.today"))

            Tab(L10n.t("tab.messages"), systemImage: "bubble.left.and.bubble.right.fill", value: AppTab.chat) {
                ChatView()
            }
            .badge(appState.unreadChat)
            .accessibilityLabel(chatTabA11yLabel)

            Tab(L10n.t("tab.us"), systemImage: "heart.fill", value: AppTab.us) {
                UsView()
            }
            .badge(appState.gamesAwaitingMe.count)

            Tab(L10n.t("tab.memories"), systemImage: "photo.on.rectangle.angled", value: AppTab.memories) {
                MemoriesView()
            }

            Tab(value: AppTab.search, role: .search) {
                SearchView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(isPresented: $state.showProfile) {
            ProfileView()
        }
        .onChange(of: appState.activeTab) { _, newTab in
            if newTab == .chat { appState.unreadChat = 0 }
        }
    }

    private var chatTabA11yLabel: String {
        appState.unreadChat > 0
            ? L10n.t("tab.chat.unreadA11y", ["n": String(appState.unreadChat)])
            : L10n.t("tab.messages")
    }
}
