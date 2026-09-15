import SwiftUI

/// "Heute" — the daily home of the couple: days together, today's rituals,
/// the partner, sending love, and what happened while you were away.
/// Large system title with subtitle, Liquid Glass toolbar, grouped cards.
struct TodayView: View {
    @Environment(AppState.self) private var appState
    @State private var model = TodayModel()

    @State private var showMood = false
    @State private var showNeed = false
    @State private var showTouchStudio = false
    @State private var showDuet = false
    @State private var showInbox = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    heroSection

                    if appState.couple != nil, appState.partner != nil {
                        NextStepCard(showMood: $showMood)
                        todayForYouSection
                        latestFromPartnerSection
                        partnerSection
                        sendLoveSection
                        ritualsSection
                        growthSection
                        discoverSection
                    }
                }
                .padding(.horizontal, Brand.screenInset)
                .padding(.bottom, 24)
            }
            .groupedScreenBackground()
            .navigationTitle("SoooDreamy")
            .navigationSubtitle(greeting)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // iOS 26 toolbar items carry system badges — no hand-drawn dot.
                    Button {
                        showInbox = true
                    } label: {
                        Label(L10n.t("today.inbox"), systemImage: "bell")
                    }
                    .badge(appState.missedInbox?.total ?? 0)
                    .accessibilityValue((appState.missedInbox?.total ?? 0) > 0
                                        ? L10n.t("today.inbox.unread", ["n": String(appState.missedInbox?.total ?? 0)])
                                        : "")
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.showProfile = true
                    } label: {
                        MemberAvatar(member: appState.me, size: 30)
                    }
                    .accessibilityLabel(L10n.t("common.profile"))
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .refreshable {
                await appState.refreshAll()
                await model.load(appState: appState)
            }
            .task(id: appState.couple?.id) {
                await model.load(appState: appState)
            }
            .navigationDestination(for: TodayRoute.self) { route in
                route.destination
            }
            .sheet(isPresented: $showMood) { MoodSheet() }
            .sheet(isPresented: $showNeed) { NeedSheet() }
            .sheet(isPresented: $showTouchStudio) { TouchStudioView() }
            .sheet(isPresented: $showDuet) { DuetSheet() }
            .sheet(isPresented: $showInbox) { InboxSheet() }
        }
    }

    /// "Guten Morgen, Mia." — the subtitle follows the time of day and the
    /// person; without a name it falls back to the plain greeting.
    private var greeting: String {
        let key = NextStepRules.greetingKey(hour: Calendar.current.component(.hour, from: Date()))
        if let name = appState.me?.name, !name.isEmpty {
            return L10n.t(key + ".named", ["name": name])
        }
        return L10n.t(key)
    }

    // MARK: Sections

    @ViewBuilder
    private var heroSection: some View {
        if appState.couple == nil {
            SessionStateCard()
        } else if appState.partner == nil {
            WaitingForPartnerCard()
        } else {
            NavigationLink(value: TodayRoute.stats) {
                DaysTogetherHero()
            }
            .buttonStyle(.plain)

            if let milestone = model.monthiversary(for: appState.couple) {
                MilestoneBanner(milestone: milestone)
            }
        }
    }

    private var todayForYouSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("today.forYou"))
            TodayTiles(showMood: $showMood)
        }
    }

    @ViewBuilder
    private var latestFromPartnerSection: some View {
        if let inbox = appState.missedInbox, !inbox.isEmpty {
            MissedInboxCard(inbox: inbox) { showInbox = true }
        } else if let message = model.latestPartnerMessage {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: L10n.t("today.partnerSent", ["name": appState.partnerName]))
                LatestMessageRow(message: message) {
                    appState.activeTab = .chat
                }
            }
        }
    }

    private var partnerSection: some View {
        PartnerCard(showMood: $showMood)
    }

    private var sendLoveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("home.sendLove"))
            SendLoveGrid()
            HStack(spacing: 12) {
                FeatureTile(title: L10n.t("touchstudio.title"),
                            subtitle: L10n.t("touchstudio.tileHint"),
                            systemImage: "hand.tap.fill", tint: .accentColor) {
                    showTouchStudio = true
                }
                FeatureTile(title: L10n.t("duet.title"),
                            subtitle: L10n.t("duet.subtitle"),
                            systemImage: "waveform.path.ecg", tint: .purple) {
                    showDuet = true
                }
            }
        }
    }

    private var ritualsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("today.rituals"),
                         trailing: L10n.t("common.seeAll")) {
                appState.activeTab = .us
            }
            PartnerNeedBanner()
            CheckinCard()
            HStack(spacing: 12) {
                FeatureTile(title: L10n.t("needs.button.title"),
                            subtitle: L10n.t("needs.button.tile"),
                            systemImage: "hand.raised.fill", tint: .indigo) {
                    showNeed = true
                }
                EnergyTile()
            }
            HugQueueCard()
            DaymemoCard()
            WeekplanBanner()
        }
    }

    @ViewBuilder
    private var growthSection: some View {
        QuestCard()
        LevelCard()
        if let next = appState.nextEvent {
            NextEventRow(event: next.event, days: next.days)
        }
        if let flashback = model.flashback {
            FlashbackCard(item: flashback)
        }
    }

    @ViewBuilder
    private var discoverSection: some View {
        if let idea = model.discoverIdea {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: L10n.t("today.discover"))
                DiscoverIdeaCard(idea: idea)
            }
        }
    }
}

// MARK: - Routes

/// Push destinations reachable from Today.
enum TodayRoute: Hashable {
    case stats
    case daily
    case streak
    case dateNight
    case needsHistory
    case events

    @ViewBuilder
    var destination: some View {
        switch self {
        case .events: EventsView()
        case .stats: LoveStatsView()
        case .daily: DailyQuestionView()
        case .streak: StreakCalendarView()
        case .dateNight: DateNightView()
        case .needsHistory: NeedsHistoryView()
        }
    }
}
