import Foundation
import Observation
import SwiftUI
import WidgetKit

enum AppPhase: Equatable {
    case welcome      // no server configured yet
    case pairing      // server active, but not paired into a couple
    case main         // paired
}

/// The root tabs (5.0): Heute · Nachrichten · Wir · Erinnerungen, plus the
/// iOS 26 search tab. Raw values double as deep-link paths
/// (`sooodreamy://tab/<raw>`).
enum AppTab: String, Hashable, CaseIterable {
    case home, chat, us, memories, search
}

enum QueuedCelebration {
    case level(LevelUpPayload)
    case badge(BadgeState)
}

/// Central app state: active server session, couple data, socket events.
@MainActor
@Observable
final class AppState {
    let servers = ServerStore()
    let socket = SocketClient()

    // Session data (per active server)
    var couple: Couple?
    var events: [EventItem] = []
    var dailyEntry: DailyEntry? {
        didSet {
            // Keep the "streak at risk" evening nudge in sync with every
            // change (fetch, own answer, partner's socket event, sign-out).
            let entry = dailyEntry
            Task { await ReminderManager.syncStreakGuard(entry: entry) }
        }
    }
    var stats: Stats?
    var sessionLoading = false
    /// Showcase photo for the photo widget (newest favorite, else newest).
    var widgetPhoto: Photo?

    /// Stroke count last mirrored to the widgets (see refreshWidgetCanvas).
    @ObservationIgnored private var widgetCanvasStrokeCount = 0
    /// Photo id whose bytes are currently in the shared widget cache.
    @ObservationIgnored private var cachedWidgetPhotoId: String?
    /// Compact active goal from the authenticated widget endpoint.
    var widgetGoal: WidgetSnapshotResponse.GoalSummary?

    // UI state
    var activeTab: AppTab = .home {
        didSet {
            if activeTab == .chat, oldValue != .chat {
                markChatRead()
            }
        }
    }
    /// Transient status capsule (see StatusNoticeView).
    var notice: StatusNotice?
    /// Blocking error message (system alert) for flows that need one.
    var alertMessage: String?
    /// Profile & settings sheet (avatar button / `sooodreamy://tab/settings`).
    var showProfile = false
    var incomingTouch: Touch?
    /// Custom vibration relayed by the partner — drives the full-screen
    /// haptic moment overlay (v2.0 haptics composer).
    var incomingHaptic: HapticSend?
    var partnerTyping = false
    var unreadChat = 0 {
        didSet { persistUnreadChat() }
    }
    var celebrate = false
    var uiRefresh = 0

    /// Full-screen moment for the two milestones that deserve more than a
    /// toast — the couple becoming connected and round day counters.
    /// Presented by RootView as a full-screen cover (see CoupleCutsceneView).
    var coupleCutscene: CoupleCutscene?
    /// "What's new" sheet, shown once per major version after an update.
    var showWhatsNew = false
    /// Couple code carried by an invitation link (`sooodreamy://pair`) or QR
    /// scan, waiting for PairingView to pick it up in join mode.
    var pendingInviteCode: String?
    /// Message to scroll to once the chat tab is showing (search results).
    var chatJumpTarget: String?

    /// Aggregated activity missed since the last inbox check (v1.6
    /// `GET /api/inbox`) — non-nil drives the "While you were away" card
    /// on the dashboard; cleared when the user taps or dismisses it.
    var missedInbox: InboxResponse?

    /// v3.0 "Du bist dran!" — open games awaiting my action (inbox `games`
    /// bucket, current state). Drives the Play-tab badge and the hub hint.
    var gamesAwaitingMe: [InboxResponse.GamesBucket.AwaitingGame] = []

    /// Today's morning/good-night check-ins for both members — feeds the
    /// "Jetzt dran" card; refreshed with everything else and on `checkin` events.
    var todayCheckin: CheckinDay?

    /// Last touch received from the partner — feeds widgets & live activities.
    /// Seeded from the shared snapshot so it survives app relaunches.
    var lastTouchType: String?
    var lastTouchAt: Date?

    // v3.0 Level, Badges & Platform (Agent C) — logic in AppStatePlatform.swift
    var levelState: LevelState?
    var badges: [BadgeState] = []
    var quest: QuestState?
    var pendingIconGift: IconGift?
    var dateNight: DateNight?
    /// Duet currently counting down / playing (full-screen overlay).
    var activeDuet: DuetSession?
    /// Level-up ceremony queued for full-screen presentation.
    var levelUpCeremony: LevelUpPayload?
    /// Freshly unlocked badge (award ceremony overlay).
    var badgeCeremony: BadgeState?
    @ObservationIgnored var celebrationQueue = FIFOQueue<QueuedCelebration>()
    /// Last live heartbeat tap from the partner (3D heart + duet view pulse).
    var partnerHeartbeatTap: HeartbeatTapPayload?
    var partnerTapCount = 0
    @ObservationIgnored var duetPlayTask: Task<Void, Never>?

    @ObservationIgnored private var noticeTask: Task<Void, Never>?
    @ObservationIgnored private var touchTask: Task<Void, Never>?
    @ObservationIgnored private var hapticTask: Task<Void, Never>?
    @ObservationIgnored private var typingTask: Task<Void, Never>?
    @ObservationIgnored private var eventObserver: NSObjectProtocol?
    /// Rate limit for "partner is online" alerts (max once per 10 min).
    @ObservationIgnored private var lastOnlineAlertAt: Date?

    init() {
        let snapshot = SharedStore.readSnapshot()
        lastTouchType = snapshot?.lastTouchType
        lastTouchAt = snapshot?.lastTouchAt
        restoreCoreColdCache()
        eventObserver = NotificationCenter.default.addObserver(
            forName: .serverEvent, object: nil, queue: .main
        ) { [weak self] note in
            guard let event = note.object as? ServerEvent else { return }
            Task { @MainActor [weak self] in
                self?.handle(event)
            }
        }
    }

    // MARK: Derived state

    var phase: AppPhase {
        guard let profile = servers.activeProfile else { return .welcome }
        return profile.isPaired ? .main : .pairing
    }

    var memberId: String? { servers.activeProfile?.memberId }

    var api: API? {
        guard let profile = servers.activeProfile, let url = profile.baseURL else { return nil }
        return API(baseURL: url, token: profile.token)
    }

    var me: Member? {
        guard let couple, let memberId else { return nil }
        return couple.members.first { $0.id == memberId }
    }

    var partner: Member? {
        guard let couple, let memberId else { return nil }
        return couple.members.first { $0.id != memberId }
    }

    var partnerName: String { partner?.name ?? L10n.t("misc.partnerDefault") }

    var daysTogether: Int? {
        guard let couple else { return nil }
        return SharedDates.daysSince(couple.anniversary) ?? SharedDates.daysSince(
            SharedDates.todayKey(couple.createdAt))
    }

    /// Next upcoming event (with days remaining).
    var nextEvent: (event: EventItem, days: Int)? {
        events
            .compactMap { ev -> (EventItem, Int)? in
                guard let d = SharedDates.daysUntil(ev.date, repeatsYearly: ev.repeatsYearly), d >= 0 else { return nil }
                return (ev, d)
            }
            .min { $0.1 < $1.1 }
            .map { (event: $0.0, days: $0.1) }
    }

    // MARK: Lifecycle

    func bootstrap() async {
        L10n.language = L10n.language          // trigger shared-language mirror
        Haptics.shared.prepare()
        SoundEngine.shared.prepare()
        guard phase == .main else { return }
        restoreUnreadChat()
        await refreshAll()
        connectSocket()
        CouplePulseController.startIfEnabled(from: self)
        presentWhatsNewIfNeeded()
    }

    /// Switch to another saved server (its own pairing/session context).
    func activateProfile(_ id: UUID) async {
        guard id != servers.activeProfileID else { return }
        socket.disconnect()
        couple = nil
        events = []
        dailyEntry = nil
        stats = nil
        widgetGoal = nil
        missedInbox = nil
        gamesAwaitingMe = []
        servers.setActive(id: id)
        restoreCoreColdCache()
        restoreUnreadChat()
        if let profile = servers.activeProfile {
            notify(L10n.t("server.switched", ["name": profile.name]), style: .success)
        }
        if phase == .main {
            await refreshAll()
            connectSocket()
            CouplePulseController.startIfEnabled(from: self)
        }
    }

    /// Called after successful create/join on a profile.
    func completeAuth(profileID: UUID, auth: AuthResponse) {
        servers.attachSession(profileID: profileID, token: auth.token,
                              coupleId: auth.coupleId, memberId: auth.memberId,
                              sessionId: auth.sessionId, expiresAt: auth.expiresAt)
        servers.setActive(id: profileID)
        couple = auth.couple
        connectSocket()
        celebrateNow()
        // A freshly paired install already sees the current design — no
        // "what's new" on top of the pairing moment.
        markWhatsNewSeen()
        presentPairedCutsceneIfNeeded()
        Task {
            await refreshAll()
            CouplePulseController.startIfEnabled(from: self)
            if NotificationPrefs.enabled {
                _ = await RemotePushRegistration.requestIfAuthorized()
            }
        }
    }

    func registerPushToken(_ token: String) async {
        guard NotificationPrefs.enabled,
              let api,
              let bundleId = Bundle.main.bundleIdentifier else { return }
        _ = try? await api.registerPushDevice(
            apnsToken: token,
            environment: RemotePushRegistration.environment,
            bundleId: bundleId,
            language: L10n.lang
        )
    }

    func unregisterPushDevice() async {
        guard let api else { return }
        try? await api.unregisterPushDevice()
    }

    func connectSocket() {
        guard let profile = servers.activeProfile,
              let url = profile.baseURL,
              let token = profile.token else { return }
        socket.connect(baseURL: url, token: token)
    }

    /// v2.0 iCloud restore: the server list just got replaced — drop the
    /// old session state and reconnect to the (new) active profile.
    func reloadAfterRestore() async {
        socket.disconnect()
        couple = nil
        events = []
        dailyEntry = nil
        stats = nil
        widgetGoal = nil
        missedInbox = nil
        gamesAwaitingMe = []
        restoreCoreColdCache()
        restoreUnreadChat()
        if phase == .main {
            await refreshAll()
            connectSocket()
            CouplePulseController.startIfEnabled(from: self)
        }
    }

    // MARK: Data refresh

    func refreshAll() async {
        sessionLoading = couple == nil
        defer { sessionLoading = false }
        await refreshCouple()
        async let e: Void = refreshEvents()
        async let d: Void = refreshDaily()
        async let s: Void = refreshStats()
        async let p: Void = refreshWidgetPhoto()
        async let c: Void = refreshWidgetCanvas()
        async let i: Void = refreshInbox()
        async let g: Void = refreshGamification()   // v3.0 level/badges/quest (Agent C)
        async let w: Void = refreshWidgetCore()
        async let k: Void = refreshTodayCheckin()
        _ = await (e, d, s, p, c, i, g, w, k)
        updateWidgetSnapshot()
        presentMilestoneCutsceneIfNeeded()
    }

    func refreshTodayCheckin() async {
        guard let api else { return }
        if let response = try? await api.checkins(limit: 1) {
            todayCheckin = response.days.first { $0.dateKey == SharedDates.todayKey() }
        }
    }

    /// One-tap check-in from the "Jetzt dran" card. Returns false on failure
    /// (the card stays, the user can retry).
    @discardableResult
    func checkIn(kind: String) async -> Bool {
        guard let api else { return false }
        do {
            let response = try await api.checkin(kind: kind)
            todayCheckin = response.day
            SoundEngine.shared.play(.success)
            Haptics.shared.success()
            return true
        } catch {
            handleAPIError(error)
            return false
        }
    }

    func refreshWidgetCore() async {
        guard let remote = try? await api?.widgetSnapshot() else { return }
        widgetGoal = remote.goal
    }

    // MARK: Missed inbox (v1.6)

    /// UserDefaults key for the last inbox check, scoped per couple so
    /// switching servers/couples never leaks another couple's window.
    private var lastInboxKey: String? {
        servers.activeProfile?.coupleId.map { "inbox.lastAt.\($0)" }
    }

    /// Fetch everything missed since the last check and surface it as the
    /// "While you were away" card. Best effort: pre-v1.6 servers 404 here,
    /// which stays silent; the window only advances after a successful fetch
    /// (or on the very first run, which just seeds the timestamp).
    func refreshInbox() async {
        guard let api, let key = lastInboxKey else { return }
        let defaults = UserDefaults.standard
        guard let stored = defaults.object(forKey: key) as? Double else {
            defaults.set(Date().timeIntervalSince1970, forKey: key)
            return
        }
        guard let inbox = try? await api.inbox(since: Date(timeIntervalSince1970: stored)) else {
            return
        }
        defaults.set(Date().timeIntervalSince1970, forKey: key)
        // The games bucket is current-state (not since-filtered) — always
        // mirror it so the Play-tab badge is fresh on every app open.
        gamesAwaitingMe = inbox.games?.awaitingMe ?? []
        if !inbox.isEmpty {
            missedInbox = inbox
        }
    }

    // MARK: Chat read state

    /// Zero the unread badge and tell the server the chat was read (v1.6
    /// read receipts). Older servers 404 the POST — silently ignored.
    func markChatRead() {
        unreadChat = 0
        guard let api else { return }
        Task { _ = try? await api.markMessagesRead() }
    }

    /// The unread-chat badge survives app restarts (persisted per couple).
    private var unreadChatKey: String? {
        servers.activeProfile?.coupleId.map { "chat.unread.\($0)" }
    }

    private func persistUnreadChat() {
        guard let key = unreadChatKey else { return }
        UserDefaults.standard.set(unreadChat, forKey: key)
    }

    private func restoreUnreadChat() {
        guard let key = unreadChatKey else {
            unreadChat = 0
            return
        }
        unreadChat = UserDefaults.standard.integer(forKey: key)
    }

    func refreshWidgetPhoto() async {
        guard let api else { return }
        if let photos = try? await api.photos() {
            // The Widget Studio can pin the showcase to "newest" instead of
            // the default "newest favorite, else newest".
            let source = SharedStore.readStudioConfig()
                .config(for: WidgetKindID.photo).photoSource
            if source == "newest" {
                widgetPhoto = photos.first
            } else {
                widgetPhoto = photos.first { !($0.favorites ?? []).isEmpty } ?? photos.first
            }
            await cacheWidgetPhotoBytes()
        }
    }

    /// Downloads the showcase photo's thumb bytes into the shared app-group
    /// cache so the widgets stay pretty when the server is unreachable.
    private func cacheWidgetPhotoBytes() async {
        guard let api, let photo = widgetPhoto else { return }
        guard photo.id != cachedWidgetPhotoId else { return }
        guard let data = try? await api.mediaData(photo.thumbUrl ?? photo.url),
              !data.isEmpty else { return }
        SharedStore.writeCachedPhotoJPEG(data)
        cachedWidgetPhotoId = photo.id
    }

    /// Mirrors the shared canvas into the app group for the canvas widget:
    /// last 400 strokes, each downsampled to ≤ 80 points.
    func refreshWidgetCanvas() async {
        guard let api else { return }
        guard let strokes = try? await api.canvasStrokes() else { return }
        let compact = strokes.suffix(400).map { stroke in
            WidgetCanvasStroke(id: stroke.id,
                               color: stroke.color,
                               width: stroke.width,
                               tool: stroke.tool,
                               points: Self.downsample(stroke.points, maxCount: 80))
        }
        SharedStore.writeCanvasStrokes(compact)
        widgetCanvasStrokeCount = compact.count
    }

    /// Evenly-spaced point subsample that always keeps the first & last point.
    private static func downsample(_ points: [[Double]], maxCount: Int) -> [[Double]] {
        guard points.count > maxCount, maxCount >= 2 else { return points }
        let step = Double(points.count - 1) / Double(maxCount - 1)
        return (0..<maxCount).map { points[Int((Double($0) * step).rounded())] }
    }

    func refreshCouple() async {
        guard let api else { return }
        do {
            let resp = try await api.getCouple()
            couple = resp.couple
        } catch {
            handleAPIError(error)
        }
    }

    func refreshEvents() async {
        guard let api else { return }
        if let list = try? await api.events() {
            events = list.sorted { $0.date < $1.date }
        }
    }

    func refreshDaily() async {
        guard let api else { return }
        dailyEntry = try? await api.daily(dateKey: SharedDates.todayKey())
    }

    func refreshStats() async {
        guard let api else { return }
        stats = try? await api.stats()
    }

    func handleAPIError(_ error: Error) {
        if let apiErr = error as? APIError, apiErr.isUnauthorized {
            if let profile = servers.activeProfile {
                servers.clearSession(profileID: profile.id)
            }
            couple = nil
            socket.disconnect()
            notify(L10n.t("error.unauthorized"), style: .error)
        } else {
            notify(error.localizedDescription, style: .error)
        }
    }

    // MARK: Actions

    func sendTouch(_ kind: TouchKind) {
        guard let api else { return }
        Haptics.shared.play(kind)
        SoundEngine.shared.play(for: kind)
        Task {
            do {
                try await api.sendTouch(kind)
                notify(L10n.t("home.touchSent", ["emoji": kind.emoji]), style: .love)
            } catch {
                handleAPIError(error)
            }
        }
    }

    func setMood(_ mood: String?, note: String?) {
        guard let api else { return }
        Task {
            do {
                let member = try await api.updateMe(mood: .some(mood), moodNote: .some(note))
                applyMemberUpdate(member)
                Haptics.shared.success()
                updateWidgetSnapshot()
            } catch {
                handleAPIError(error)
            }
        }
    }

    func leaveDevice() {
        guard let profile = servers.activeProfile else { return }
        if let api {
            Task { try? await api.unregisterPushDevice() }
        }
        socket.disconnect()
        CoreColdCacheStore.shared.remove(profileID: profile.id)
        servers.clearSession(profileID: profile.id)
        couple = nil
        events = []
        dailyEntry = nil
        stats = nil
        widgetGoal = nil
        unreadChat = 0
        missedInbox = nil
        gamesAwaitingMe = []
        resetPlatformState()   // v3.0 level/badges/platform (Agent C)
        CouplePulseController.stop()
        CountdownActivityController.stopAll()
        updateWidgetSnapshot()
    }

    func dissolveCouple() async {
        guard let api else { return }
        do {
            try await api.dissolveCouple()
            leaveDevice()
        } catch {
            handleAPIError(error)
        }
    }

    // MARK: Socket events

    private func handle(_ event: ServerEvent) {
        switch event.type {
        case .welcome:
            if let payload = event.decode(WelcomePayload.self) {
                setPartnerOnline(payload.partnerOnline, lastSeen: nil)
                pushLiveActivityUpdates()
                // Socket (re)connected — check what happened while offline.
                Task { await refreshInbox() }
            }
        case .presence:
            if let p = event.decode(PresencePayload.self), p.memberId != memberId {
                let wasOnline = partner?.online ?? false
                setPartnerOnline(p.online, lastSeen: p.lastSeenAt)
                if p.online && !wasOnline { notifyPartnerOnline() }
                pushLiveActivityUpdates()
            }
        case .touch:
            if let payload = event.decode(TouchResponse.self) {
                receiveTouch(payload.touch)
                pushLiveActivityUpdates()
            }
        case .haptic:
            if let payload = event.decode(HapticSendResponse.self) {
                receiveHaptic(payload.haptic)
            }
        case .message:
            if let payload = event.decode(MessageResponse.self) {
                if payload.message.senderId != memberId {
                    if activeTab != .chat {
                        unreadChat += 1
                        notifyMessage(payload.message)
                    } else {
                        // Chat is on screen — the message is read right away.
                        markChatRead()
                    }
                    SoundEngine.shared.play(.pop)
                }
            }
        case .messageRead:
            // Partner (or my other device) marked the chat as read — feeds
            // the read-receipt checkmarks on own bubbles.
            if let payload = event.decode(MessageReadPayload.self) {
                applyLastReadAt(memberId: payload.memberId, at: payload.at)
            }
        case .memberUpdated:
            if let payload = event.decode(MemberResponse.self) {
                applyMemberUpdate(payload.member)
                pushLiveActivityUpdates()
            }
        case .coupleUpdated:
            if let payload = event.decode(CoupleOnlyResponse.self) {
                couple = payload.couple
                updateWidgetSnapshot()
            }
        case .partnerJoined:
            if let payload = event.decode(MemberResponse.self) {
                Task {
                    await refreshCouple()
                    presentPairedCutsceneIfNeeded()
                }
                notify(L10n.t("misc.partnerJoinedToast", ["name": payload.member.name]), style: .love)
                SoundEngine.shared.play(.tada)
                Haptics.shared.success()
                celebrateNow()
            }
        case .coupleDissolved:
            leaveDevice()
            notify(L10n.t("misc.dissolvedTitle"), style: .info)
        case .dailyAnswer:
            if let entry = event.decode(DailyEntry.self), entry.dateKey == SharedDates.todayKey() {
                let wasBothAnswered = dailyEntry?.bothAnswered ?? false
                dailyEntry = entry
                if entry.bothAnswered {
                    SoundEngine.shared.play(.sparkle)
                    if !wasBothAnswered {
                        CoupleNotify.alert(.dailyReveal,
                                           title: L10n.t("home.bothAnswered"),
                                           body: L10n.t("notif.daily.body"),
                                           link: "sooodreamy://daily")
                    }
                }
                pushLiveActivityUpdates()
            }
        case .eventAdded, .eventUpdated, .eventDeleted:
            Task {
                await refreshEvents()
                if event.type == .eventDeleted {
                    // A running countdown whose event vanished should end too.
                    CountdownActivityController.stopIfEventMissing(events: events)
                }
                updateWidgetSnapshot()
            }
        case .photoAdded, .photoUpdated, .photoDeleted:
            if event.type == .photoAdded,
               let photo = event.decode(PhotoResponse.self)?.photo,
               photo.uploaderId != memberId {
                CoupleNotify.alert(.photo,
                                   title: L10n.t("notif.photo.title"),
                                   body: L10n.t("notif.photo.body", ["name": partnerName]),
                                   link: "sooodreamy://tab/memories")
            }
            Task {
                await refreshWidgetPhoto()
                updateWidgetSnapshot()
            }
        case .canvasStroke, .canvasStrokeDeleted, .canvasClear:
            // CanvasView keeps its own live copy; this mirrors the strokes
            // into the app group so the canvas widget stays current.
            Task {
                await refreshWidgetCanvas()
                updateWidgetSnapshot()
            }
        case .couponAdded:
            if let coupon = event.decode(CouponResponse.self)?.coupon, coupon.forMember == memberId {
                notify(L10n.t("coupon.receivedToast"), style: .love)
                SoundEngine.shared.play(.sparkle)
                CoupleNotify.alert(.coupon,
                                   title: L10n.t("notif.coupon.title"),
                                   body: L10n.t("notif.coupon.body",
                                                ["name": partnerName, "title": coupon.title]),
                                   link: "sooodreamy://tab/memories")
            }
        case .couponRedeemed:
            if let coupon = event.decode(CouponResponse.self)?.coupon, coupon.createdBy == memberId {
                notify(L10n.t("coupon.redeemedToast", ["title": coupon.title]), style: .love)
                SoundEngine.shared.play(.tada)
            }
        case .checkin:
            if let payload = event.decode(CheckinEventPayload.self) {
                if payload.day.dateKey == SharedDates.todayKey() { todayCheckin = payload.day }
                if payload.memberId != memberId {
                    let key = payload.kind == "morning" ? "checkin.toast.morning" : "checkin.toast.night"
                    notify(L10n.t(key, ["name": partnerName]), style: .love)
                    SoundEngine.shared.play(.pop)
                }
            }
        case .hugQueued:
            if let hug = event.decode(HugResponse.self)?.hug, hug.to == memberId {
                notify(L10n.t("hug.receivedToast", ["name": partnerName]), style: .love)
                SoundEngine.shared.play(.sparkle)
                CoupleNotify.alert(.touch,
                                   title: L10n.t("notif.hug.title"),
                                   body: L10n.t("notif.hug.body", ["name": partnerName]),
                                   link: "sooodreamy://tab/home")
            }
        case .hugOpened:
            if let hug = event.decode(HugResponse.self)?.hug, hug.from == memberId {
                notify(L10n.t("hug.openedToast", ["name": partnerName]), style: .love)
                SoundEngine.shared.play(.success)
                Haptics.shared.success()
            }
        case .nowPlayingChanged:
            if let payload = event.decode(NowPlayingEventPayload.self) {
                applyNowPlaying(memberId: payload.memberId, nowPlaying: payload.nowPlaying)
                if payload.memberId != memberId, let np = payload.nowPlaying {
                    notify(L10n.t("nowplaying.toast", ["name": partnerName, "title": np.title]),
                              style: .info)
                }
            }
        case .potdSubmitted:
            if let payload = event.decode(PotdEventPayload.self), payload.memberId != memberId {
                notify(L10n.t("potd.partnerToast", ["name": partnerName]), style: .love)
                SoundEngine.shared.play(.pop)
            }
        case .typing:
            if let p = event.decode(TypingPayload.self), p.memberId != memberId {
                partnerTyping = p.isTyping
                typingTask?.cancel()
                if p.isTyping {
                    typingTask = Task { [weak self] in
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        if !Task.isCancelled { self?.partnerTyping = false }
                    }
                }
            }
        case .need, .needAcked, .capsuleSealed, .capsuleOpened, .energy,
             .goalAdded, .goalUpdated, .goalDeleted, .daymemo:
            // v3.0 rituals (Agent A) — global toasts/notifications/confetti
            // live in RitualsAppState.swift; feature views keep their own state.
            handleRitualEvent(event)
        default:
            // v3.0 level/badges/platform events (Agent C) — remaining types
            // are consumed by feature views observing .serverEvent themselves.
            handlePlatformEvent(event)
        }
    }

    private func applyNowPlaying(memberId: String, nowPlaying: NowPlaying?) {
        guard var couple else { return }
        if let idx = couple.members.firstIndex(where: { $0.id == memberId }) {
            couple.members[idx].nowPlaying = nowPlaying
            self.couple = couple
        }
    }

    private func setPartnerOnline(_ online: Bool, lastSeen: Date?) {
        guard var couple, let memberId else { return }
        for i in couple.members.indices where couple.members[i].id != memberId {
            couple.members[i].online = online
            if let lastSeen { couple.members[i].lastSeenAt = lastSeen }
        }
        self.couple = couple
    }

    private func applyMemberUpdate(_ member: Member) {
        guard var couple else { return }
        if let idx = couple.members.firstIndex(where: { $0.id == member.id }) {
            let wasOnline = couple.members[idx].online
            couple.members[idx] = member
            couple.members[idx].online = member.online ?? wasOnline
        }
        self.couple = couple
    }

    /// Advance a member's `lastReadAt` (never backwards — events may race).
    private func applyLastReadAt(memberId id: String, at: Date) {
        guard var couple else { return }
        guard let idx = couple.members.firstIndex(where: { $0.id == id }) else { return }
        if let current = couple.members[idx].lastReadAt, current >= at { return }
        couple.members[idx].lastReadAt = at
        self.couple = couple
    }

    private func receiveTouch(_ touch: Touch) {
        incomingTouch = touch
        Haptics.shared.play(touch.type)
        SoundEngine.shared.play(for: touch.type)
        if touch.senderId != memberId {
            lastTouchType = touch.type.rawValue
            lastTouchAt = touch.createdAt
            CoupleNotify.alert(.touch,
                               title: "\(touch.type.emoji) \(L10n.t(touch.type.titleKey))",
                               body: L10n.t("touch.received.\(touch.type.rawValue)", ["name": partnerName]),
                               sound: NotificationPrefs.soundOverride(for: .touch)
                                   ?? .mapped(for: touch.type),
                               link: "sooodreamy://tab/home")
        }
        touchTask?.cancel()
        touchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_200_000_000)
            if !Task.isCancelled { self?.incomingTouch = nil }
        }
    }

    /// Custom vibration from the partner: full-screen moment + the pattern
    /// itself. Auto-dismisses after the pattern finished playing.
    private func receiveHaptic(_ haptic: HapticSend) {
        incomingHaptic = haptic
        Haptics.shared.play(events: haptic.events)
        SoundEngine.shared.play(.vibe)
        if haptic.senderId != memberId {
            CoupleNotify.alert(.touch,
                               title: "\(haptic.emoji ?? "💜") \(haptic.name ?? L10n.t("haptic.received.title"))",
                               body: L10n.t("haptic.received.body", ["name": partnerName]),
                               link: "sooodreamy://tab/home")
        }
        let linger = HapticTimeline.duration(of: haptic.events) + 3.5
        hapticTask?.cancel()
        hapticTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(4.5, linger) * 1_000_000_000))
            if !Task.isCancelled { self?.incomingHaptic = nil }
        }
    }

    // MARK: Couple notifications

    private func notifyMessage(_ message: Message) {
        let body: String
        switch message.type {
        case .text:
            body = Self.preview(of: message.text ?? "")
        case .letter:
            body = L10n.t("notif.message.letter")
        case .voice:
            body = L10n.t("notif.message.voice")
        case .photo:
            body = L10n.t("notif.message.photo")
        }
        guard !body.isEmpty else { return }
        CoupleNotify.alert(.message,
                           title: L10n.t("notif.message.title", ["name": partnerName]),
                           body: body,
                           link: "sooodreamy://tab/chat")
    }

    private func notifyPartnerOnline() {
        if let last = lastOnlineAlertAt, Date().timeIntervalSince(last) < 600 { return }
        lastOnlineAlertAt = Date()
        CoupleNotify.alert(.partnerOnline,
                           title: L10n.t("notif.online.title", ["name": partnerName]),
                           body: L10n.t("notif.online.body"),
                           link: "sooodreamy://tab/home")
    }

    private static func preview(of text: String, limit: Int = 120) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count <= limit ? trimmed : String(trimmed.prefix(limit)) + "…"
    }

    private func celebrateNow() {
        celebrate = true
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            self?.celebrate = false
        }
    }

    // MARK: Cutscenes & what's new

    private static let pairedCutsceneKey = "sooodreamy.cutscene.paired."
    private static let milestoneCutsceneKey = "sooodreamy.cutscene.milestone."
    private static let whatsNewSeenKey = "sooodreamy.whatsNew.seenMajor"

    /// Once per couple, as soon as both members are present — either right
    /// after joining or when the partner's `partner_joined` event arrives.
    func presentPairedCutsceneIfNeeded() {
        guard let couple, couple.members.count >= 2 else { return }
        let key = Self.pairedCutsceneKey + couple.id
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        coupleCutscene = CoupleCutscene(kind: .paired, me: me, partner: partner)
    }

    /// Round day counters (100, 365, 500, …) once each; skipped while another
    /// full-screen moment is up.
    func presentMilestoneCutsceneIfNeeded() {
        guard phase == .main, coupleCutscene == nil,
              let couple, couple.members.count >= 2,
              let days = daysTogether, CoupleCutscene.milestoneDays.contains(days) else { return }
        let key = Self.milestoneCutsceneKey + couple.id + ".\(days)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        coupleCutscene = CoupleCutscene(kind: .milestone(days: days), me: me, partner: partner)
    }

    /// The "what's new" sheet waits for cutscenes and ceremonies so two
    /// presentations never compete.
    func presentWhatsNewIfNeeded() {
        guard phase == .main, coupleCutscene == nil, levelUpCeremony == nil,
              badgeCeremony == nil, pendingIconGift == nil else { return }
        guard UserDefaults.standard.string(forKey: Self.whatsNewSeenKey) != WhatsNewView.majorVersion else { return }
        showWhatsNew = true
    }

    func markWhatsNewSeen() {
        UserDefaults.standard.set(WhatsNewView.majorVersion, forKey: Self.whatsNewSeenKey)
    }

    // MARK: Status notices

    /// Shows a transient glass status capsule for ~3 s.
    func notify(_ text: String, style: StatusNotice.Style = .info) {
        withAnimation(.spring(response: 0.35)) {
            notice = StatusNotice(text: text, style: style)
        }
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                self?.notice = nil
            }
        }
    }

    /// Drops a pending icon gift locally (the sheet was swiped away); the
    /// next refresh re-surfaces it as long as it is unopened on the server.
    func dismissPendingIconGift() {
        pendingIconGift = nil
    }

    // MARK: Invitations

    /// Tappable invitation: `https://<server>/invite?code=…` — the server
    /// renders a page whose button deep-links back here with server + code.
    var inviteURL: URL? {
        guard let base = servers.activeProfile?.baseURL, let code = couple?.code else { return nil }
        return Invitation.pageURL(server: base, code: code)
    }

    /// Server + code from a QR payload or invitation link: activates (or adds)
    /// that server and queues the code for PairingView. Refuses to touch an
    /// existing pairing. Returns false when nothing usable was found.
    @discardableResult
    func applyPairingInvite(server: String?, code rawCode: String) -> Bool {
        guard let code = Invitation.normalizeCode(rawCode) else { return false }
        // Never switch a couple that is already paired — the invite is for a
        // new install (welcome) or an unpaired server (pairing).
        guard phase != .main else {
            notify(L10n.t("invite.alreadyPaired"), style: .info)
            return false
        }
        if let server, let normalized = ServerProfile.normalize(server) {
            if let existing = servers.profiles.first(where: { $0.urlString == normalized }) {
                guard !existing.isPaired else {
                    notify(L10n.t("invite.alreadyPaired"), style: .info)
                    return false
                }
                servers.setActive(id: existing.id)
            } else if let profile = servers.add(name: normalized, urlString: normalized) {
                servers.setActive(id: profile.id)
            }
        }
        pendingInviteCode = code
        return true
    }

    // MARK: Deep links (sooodreamy://…)

    func handleURL(_ url: URL) {
        guard url.scheme == "sooodreamy" else { return }
        let host = url.host() ?? ""
        let path = url.pathComponents.dropFirst().first ?? ""
        switch host {
        case "pair":
            if let payload = Invitation.parse(url),
               applyPairingInvite(server: payload.server, code: payload.code) {
                Haptics.shared.success()
            }
        case "tab":
            switch path {
            case "settings", "more", "profile":
                showProfile = true
            case "play", "games":
                activeTab = .us
            default:
                if let tab = AppTab(rawValue: path) { activeTab = tab }
            }
        case "daily", "streak", "need":
            // Daily question, streak and the need button live on Today.
            showProfile = false
            activeTab = .home
        case "coupons", "events", "photos", "canvas":
            // Feature-specific widget/notification links — these features live
            // in the Memories tab. Kept as distinct hosts so future sub-navigation
            // can route deeper without touching the widgets again.
            activeTab = .memories
        case "action":
            if path == "sendlove" {
                let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
                let raw = comps?.queryItems?.first(where: { $0.name == "type" })?.value ?? "heartbeat"
                sendTouch(TouchKind(rawValue: raw) ?? .heartbeat)
            }
        default:
            break
        }
    }

    // MARK: Live Activities

    /// Pushes fresh couple context into widgets + all running live activities
    /// (countdown & couple pulse) — called on relevant socket events. Updates
    /// happen locally while the app is open; no APNs involved.
    private func pushLiveActivityUpdates() {
        updateWidgetSnapshot()
        CountdownActivityController.updateFromSnapshot()
        CouplePulseController.updateFrom(self)
    }

    // MARK: Widgets

    func updateWidgetSnapshot() {
        let daily = couple.map { ContentPack.dailyQuestion(dateKey: SharedDates.todayKey(), coupleId: $0.id) }
        var snapshot = WidgetSnapshot()
        snapshot.partnerName = partner?.name
        snapshot.partnerAvatar = partner?.avatar
        snapshot.partnerColorHex = partner?.color
        snapshot.partnerMood = partner?.mood
        snapshot.partnerMoodNote = partner?.moodNote
        snapshot.partnerMoodUpdatedAt = partner?.moodUpdatedAt
        snapshot.partnerEnergyLevel = partner?.energy?.level
        snapshot.partnerEnergyNote = partner?.energy?.note
        snapshot.partnerEnergySetAt = partner?.energy?.setAt
        snapshot.partnerOnline = partner?.online
        snapshot.lastTouchType = lastTouchType
        snapshot.lastTouchAt = lastTouchAt
        snapshot.myName = me?.name
        snapshot.anniversary = couple?.anniversary
        snapshot.daysTogether = daysTogether
        if let next = nextEvent {
            snapshot.nextEventTitle = next.event.title
            snapshot.nextEventEmoji = next.event.emoji
            snapshot.nextEventDate = next.event.date
        }
        snapshot.dailyQuestionDE = daily?.text.de
        snapshot.dailyQuestionEN = daily?.text.en
        snapshot.dailyAnsweredByMe = dailyEntry?.myAnswer != nil
        snapshot.dailyBothAnswered = dailyEntry?.bothAnswered ?? false
        snapshot.streak = dailyEntry?.streak ?? 0
        snapshot.canvasStrokeCount = widgetCanvasStrokeCount
        snapshot.goalTitle = widgetGoal?.title
        snapshot.goalEmoji = widgetGoal?.emoji
        snapshot.goalPercent = widgetGoal?.percent
        // All upcoming moments (soonest first) — the countdown widget can be
        // pinned to any of them via its edit-widget configuration.
        snapshot.allEvents = events
            .compactMap { ev -> (EventItem, Int)? in
                guard let d = SharedDates.daysUntil(ev.date, repeatsYearly: ev.repeatsYearly),
                      d >= 0 else { return nil }
                return (ev, d)
            }
            .sorted { $0.1 < $1.1 }
            .map { WidgetEventLite(id: $0.0.id, title: $0.0.title, emoji: $0.0.emoji,
                                   date: $0.0.date, repeatsYearly: $0.0.repeatsYearly) }
        if let photo = widgetPhoto {
            snapshot.photoURLString = api?.mediaURL(photo.thumbUrl ?? photo.url)?.absoluteString
            snapshot.photoCaption = photo.caption
        }
        // v3.0 relationship level (Agent C) — level ring on widgets.
        if let level = levelState {
            snapshot.levelNumber = level.level
            snapshot.levelTitleDE = level.title.de
            snapshot.levelTitleEN = level.title.en
            snapshot.levelProgress = level.progress
        }
        snapshot.updatedAt = Date()
        SharedStore.writeSnapshot(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        persistCoreColdCache()
    }

    // MARK: Cold-start core cache

    /// Restores enough authenticated state to render the dashboard immediately
    /// while the first network refresh is in flight. Cache records never carry
    /// tokens and are accepted only for the active profile's exact couple id.
    private func restoreCoreColdCache() {
        guard let profile = servers.activeProfile, profile.isPaired,
              let coupleID = profile.coupleId,
              let record = CoreColdCacheStore.shared.record(profileID: profile.id,
                                                            coupleID: coupleID),
              let cachedCouple = try? API.decoder.decode(Couple.self, from: record.couple),
              cachedCouple.id == coupleID else { return }
        couple = cachedCouple
        events = (try? API.decoder.decode([EventItem].self, from: record.events)) ?? []
        dailyEntry = record.daily.flatMap { try? API.decoder.decode(DailyEntry.self, from: $0) }
        stats = record.stats.flatMap { try? API.decoder.decode(Stats.self, from: $0) }
        levelState = record.level.flatMap { try? API.decoder.decode(LevelState.self, from: $0) }
    }

    private func persistCoreColdCache() {
        guard let profile = servers.activeProfile, profile.isPaired,
              let coupleID = profile.coupleId, let couple,
              couple.id == coupleID,
              let coupleData = try? API.encoder.encode(couple),
              let eventsData = try? API.encoder.encode(events) else { return }
        CoreColdCacheStore.shared.save(
            CoreColdCacheRecord(
                profileID: profile.id,
                coupleID: coupleID,
                savedAt: Date(),
                couple: coupleData,
                events: eventsData,
                daily: dailyEntry.flatMap { try? API.encoder.encode($0) },
                stats: stats.flatMap { try? API.encoder.encode($0) },
                level: levelState.flatMap { try? API.encoder.encode($0) }))
    }
}
