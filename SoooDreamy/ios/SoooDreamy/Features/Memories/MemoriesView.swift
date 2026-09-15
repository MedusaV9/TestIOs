import SwiftUI
import Combine

/// Erinnerungen — native hub: filter chips, highlights hero, timeline,
/// then the rest of the collections as grouped rows.
struct MemoriesView: View {
    @Environment(AppState.self) private var appState

    enum Segment: String, CaseIterable, Identifiable {
        case all, photos, videos, moments, journal
        var id: String { rawValue }
        var titleKey: String { "memories.segment.\(rawValue)" }
    }

    @State private var segment: Segment = .all
    @State private var path: [MemoriesRoute] = []

    @State private var openCouponCount: Int?
    @State private var songCount: Int?
    @State private var latestPhoto: Photo?
    @State private var latestSong: Song?
    @State private var latestCoupon: Coupon?
    @State private var openListItems: Int?
    @State private var potdToday: PotdDay?
    @State private var capsulesReady: Int?
    @State private var capsulesSealed: Int?
    @State private var activeGoals: Int?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    FilterChips(items: Segment.allCases, selection: $segment) { L10n.t($0.titleKey) }
                        .padding(.horizontal, -Brand.screenInset)

                    switch segment {
                    case .all:
                        highlightsHero
                        timelineSection
                        collectionsSection
                    case .photos:
                        highlightsHero
                        photosSection
                    case .videos:
                        videosSection
                    case .moments:
                        momentsSection
                    case .journal:
                        journalSection
                    }
                }
                .padding(.horizontal, Brand.screenInset)
                .padding(.bottom, 24)
            }
            .groupedScreenBackground()
            .navigationTitle(L10n.t("memories.title"))
            .navigationSubtitle(L10n.t("memories.subtitle"))
            .navigationDestination(for: MemoriesRoute.self) { route in
                Self.destination(for: route)
            }
            .refreshable { await reload() }
        }
        .task { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent else { return }
            handleServerEvent(event)
        }
    }

    // MARK: Highlights

    @ViewBuilder
    private var highlightsHero: some View {
        if let photo = latestPhoto {
            Button { path.append(.gallery) } label: {
                ZStack(alignment: .bottomLeading) {
                    RemotePhoto(api: appState.api, path: photo.thumbUrl ?? photo.url)
                        .frame(height: 220)
                        .clipped()
                    LinearGradient(colors: [.clear, .black.opacity(0.55)],
                                   startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t("memories.highlights"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text(photoChipText(photo))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text(L10n.relativeShort(photo.createdAt))
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(16)
                }
                .clipShape(RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("memories.highlights"))
        } else if let next = appState.nextEvent {
            Button { path.append(.events) } label: {
                HStack(spacing: 14) {
                    Text(next.event.emoji)
                        .font(.largeTitle)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t("memories.highlights"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(next.event.title)
                            .font(.headline)
                        Text(countdownText(days: next.days))
                            .font(.subheadline)
                            .foregroundStyle(Color.accentColor)
                    }
                    Spacer()
                    DisclosureChevron()
                }
                .cardSurface()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("memories.timeline"))
            if timelineRows.isEmpty {
                Text(L10n.t("memories.emptyTimeline"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .cardSurface()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(timelineRows.enumerated()), id: \.element.id) { index, row in
                        Button { path.append(row.route) } label: {
                            HStack(spacing: 12) {
                                timelineLeading(row)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.kind)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.accentColor)
                                    Text(row.text)
                                        .font(.body.weight(.medium))
                                        .lineLimit(1)
                                    Text(row.time)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                DisclosureChevron()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < timelineRows.count - 1 {
                            Divider().padding(.leading, 62)
                        }
                    }
                }
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))
            }
        }
    }

    private struct TimelineRow: Identifiable {
        let id: String
        let kind: String
        let text: String
        let time: String
        let route: MemoriesRoute
        var photo: Photo?
        var emoji: String?
    }

    private var timelineRows: [TimelineRow] {
        var rows: [TimelineRow] = []
        if let photo = latestPhoto {
            rows.append(TimelineRow(id: "photo-\(photo.id)",
                                    kind: L10n.t("memories.recent.photo"),
                                    text: photoChipText(photo),
                                    time: L10n.relativeShort(photo.createdAt),
                                    route: .gallery,
                                    photo: photo))
        }
        if let song = latestSong {
            rows.append(TimelineRow(id: "song-\(song.id)",
                                    kind: L10n.t("memories.recent.song"),
                                    text: songChipText(song),
                                    time: L10n.relativeShort(song.createdAt),
                                    route: .soundtrack,
                                    emoji: "🎶"))
        }
        if let coupon = latestCoupon {
            rows.append(TimelineRow(id: "coupon-\(coupon.id)",
                                    kind: L10n.t("memories.recent.coupon"),
                                    text: coupon.title,
                                    time: L10n.relativeShort(coupon.createdAt),
                                    route: .coupons,
                                    emoji: coupon.emoji))
        }
        if let next = appState.nextEvent {
            rows.append(TimelineRow(id: "event-\(next.event.id)",
                                    kind: L10n.t("memories.card.events"),
                                    text: next.event.title,
                                    time: countdownText(days: next.days),
                                    route: .events,
                                    emoji: next.event.emoji))
        }
        return rows
    }

    @ViewBuilder
    private func timelineLeading(_ row: TimelineRow) -> some View {
        if let photo = row.photo {
            RemotePhoto(api: appState.api, path: photo.thumbUrl ?? photo.url)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            Text(row.emoji ?? "💜")
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(Color.tertiaryCardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: Collections

    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("memories.collections"))
            rowList(allCollectionRows)
        }
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("memories.card.gallery"),
                         subtitle: photoTeaserText,
                         trailing: L10n.t("common.seeAll")) {
                path.append(.gallery)
            }
            Button { path.append(.gallery) } label: {
                Label(L10n.t("memories.openGallery"), systemImage: "photo.on.rectangle.angled")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            rowList([
                collectionRow(.potd, title: L10n.t("memories.card.potd"),
                              subtitle: potdTeaserText, systemImage: "camera.fill", tint: .pink),
                collectionRow(.vault, title: L10n.t("memories.card.vault"),
                              subtitle: L10n.t("memories.card.vaultHint"),
                              systemImage: "lock.fill", tint: .indigo),
                collectionRow(.canvas, title: L10n.t("memories.card.canvas"),
                              subtitle: L10n.t("memories.card.drawTogether"),
                              systemImage: "pencil.tip.crop.circle", tint: .purple),
            ])
        }
    }

    private var videosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("memories.card.videos"), subtitle: videoTeaserText)
            Button { path.append(.videos) } label: {
                Label(L10n.t("memories.openVideos"), systemImage: "film")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
    }

    private var momentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("memories.card.events"), subtitle: eventTeaserText)
            Button { path.append(.events) } label: {
                Label(L10n.t("memories.openMoments"), systemImage: "calendar")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            rowList([
                collectionRow(.bucket, title: L10n.t("memories.card.bucket"),
                              subtitle: bucketTeaserText, systemImage: "sparkles", tint: .indigo),
                collectionRow(.yearReview, title: yearReviewTitle,
                              subtitle: L10n.t("memories.card.yearreviewHint"),
                              systemImage: "sparkle", tint: .orange),
            ])
        }
    }

    private var journalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("memories.card.journal"), subtitle: journalTeaserText)
            Button { path.append(.journal) } label: {
                Label(L10n.t("memories.openJournal"), systemImage: "book.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
    }

    // MARK: Rows

    private struct CollectionRow: Identifiable {
        let route: MemoriesRoute
        let title: String
        let subtitle: String
        let systemImage: String
        let tint: Color
        var id: MemoriesRoute { route }
    }

    private func collectionRow(_ route: MemoriesRoute, title: String, subtitle: String,
                               systemImage: String, tint: Color) -> CollectionRow {
        CollectionRow(route: route, title: title, subtitle: subtitle,
                      systemImage: systemImage, tint: tint)
    }

    private var allCollectionRows: [CollectionRow] {
        [
            collectionRow(.gallery, title: L10n.t("memories.card.gallery"),
                          subtitle: photoTeaserText, systemImage: "photo.on.rectangle.angled", tint: .pink),
            collectionRow(.videos, title: L10n.t("memories.card.videos"),
                          subtitle: videoTeaserText, systemImage: "film", tint: .blue),
            collectionRow(.journal, title: L10n.t("memories.card.journal"),
                          subtitle: journalTeaserText, systemImage: "book.fill", tint: .accentColor),
            collectionRow(.events, title: L10n.t("memories.card.events"),
                          subtitle: eventTeaserText, systemImage: "calendar", tint: .orange),
            collectionRow(.potd, title: L10n.t("memories.card.potd"),
                          subtitle: potdTeaserText, systemImage: "camera.fill", tint: .pink),
            collectionRow(.lists, title: L10n.t("memories.card.lists"),
                          subtitle: listsTeaserText, systemImage: "checklist", tint: .blue),
            collectionRow(.coupons, title: L10n.t("memories.card.coupons"),
                          subtitle: couponTeaserText, systemImage: "ticket.fill", tint: .orange),
            collectionRow(.soundtrack, title: L10n.t("memories.card.soundtrack"),
                          subtitle: soundtrackTeaserText, systemImage: "music.note.list", tint: .mint),
            collectionRow(.canvas, title: L10n.t("memories.card.canvas"),
                          subtitle: L10n.t("memories.card.drawTogether"),
                          systemImage: "pencil.tip.crop.circle", tint: .purple),
            collectionRow(.bucket, title: L10n.t("memories.card.bucket"),
                          subtitle: bucketTeaserText, systemImage: "sparkles", tint: .indigo),
            collectionRow(.stats, title: L10n.t("memories.card.stats"),
                          subtitle: statsTeaserText, systemImage: "chart.bar.fill", tint: .mint),
            collectionRow(.vault, title: L10n.t("memories.card.vault"),
                          subtitle: L10n.t("memories.card.vaultHint"),
                          systemImage: "lock.fill", tint: .indigo),
            collectionRow(.capsules, title: L10n.t("memories.card.capsules"),
                          subtitle: capsulesTeaserText, systemImage: "hourglass", tint: .indigo),
            collectionRow(.goals, title: L10n.t("memories.card.goals"),
                          subtitle: goalsTeaserText, systemImage: "target", tint: .green),
            collectionRow(.weekplan, title: L10n.t("memories.card.weekplan"),
                          subtitle: L10n.t("memories.card.weekplanHint"),
                          systemImage: "calendar.badge.clock", tint: .red),
            collectionRow(.magazine, title: L10n.t("memories.card.magazine"),
                          subtitle: L10n.t("memories.card.magazineHint"),
                          systemImage: "book.pages.fill", tint: .brown),
            collectionRow(.yearReview, title: yearReviewTitle,
                          subtitle: L10n.t("memories.card.yearreviewHint"),
                          systemImage: "sparkle", tint: .orange),
        ]
    }

    private func rowList(_ rows: [CollectionRow]) -> some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                Button { path.append(row.route) } label: {
                    HStack(spacing: 14) {
                        IconTile(systemImage: row.systemImage, tint: row.tint, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                                .font(.body.weight(.medium))
                            Text(row.subtitle)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 0)
                        DisclosureChevron()
                    }
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if row.id != rows.last?.id {
                    Divider().padding(.leading, 64)
                }
            }
        }
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))
    }

    // MARK: Destinations

    /// Shared with the search tab, which lands hits in the same destinations.
    @ViewBuilder
    static func destination(for route: MemoriesRoute) -> some View {
        switch route {
        case .gallery: GalleryView()
        case .videos: VideoGalleryView()
        case .canvas: CanvasView()
        case .bucket: BucketListView()
        case .events: EventsView()
        case .stats: LoveStatsView()
        case .journal: JournalView()
        case .coupons: CouponsView()
        case .soundtrack: SoundtrackView()
        case .lists: SharedListsView()
        case .potd: PotdView()
        case .vault: VaultView()
        case .yearReview: YearReviewView()
        case .capsules: CapsulesView()
        case .goals: GoalsView()
        case .weekplan: WeekplanView()
        case .magazine: MagazineView()
        }
    }

    // MARK: Teasers

    private var photoTeaserText: String {
        guard let count = appState.stats?.photos, count > 0 else {
            return L10n.t("memories.card.noPhotos")
        }
        if count == 1 { return L10n.t("memories.card.photoOne") }
        return L10n.t("memories.card.photoCount", ["n": String(count)])
    }

    private var videoTeaserText: String {
        guard let count = appState.stats?.videos, count > 0 else {
            return L10n.t("memories.card.noVideos")
        }
        if count == 1 { return L10n.t("memories.card.videoOne") }
        return L10n.t("memories.card.videoCount", ["n": String(count)])
    }

    private var bucketTeaserText: String {
        let done = appState.stats?.bucketDone ?? 0
        let total = appState.stats?.bucketTotal ?? 0
        if total > 0 { return "\(done)/\(total) \(L10n.t("memories.card.dreams"))" }
        return L10n.t("memories.card.noBucket")
    }

    private var eventTeaserText: String {
        if let next = appState.nextEvent {
            return "\(next.event.emoji) \(countdownText(days: next.days))"
        }
        return L10n.t("memories.card.noEvent")
    }

    private var statsTeaserText: String {
        if let days = appState.stats?.daysTogether ?? appState.daysTogether, days > 0 {
            return L10n.t("memories.card.daysOfLove", ["n": String(days)])
        }
        return L10n.t("memories.card.statsHint")
    }

    private var journalTeaserText: String {
        if let answered = appState.stats?.dailyAnswered, answered > 0 {
            return L10n.t("memories.card.journalCount", ["n": String(answered)])
        }
        return L10n.t("memories.card.journalHint")
    }

    private var couponTeaserText: String {
        if let count = openCouponCount, count > 0 {
            return L10n.t("memories.card.couponsRedeemable", ["n": String(count)])
        }
        return L10n.t("memories.card.couponsHint")
    }

    private var soundtrackTeaserText: String {
        if let count = songCount, count > 0 {
            return count == 1 ? L10n.t("memories.card.songOne")
                              : L10n.t("memories.card.songCount", ["n": String(count)])
        }
        return L10n.t("memories.card.soundtrackHint")
    }

    private var listsTeaserText: String {
        if let open = openListItems, open > 0 {
            return L10n.t("memories.card.listsOpen", ["n": String(open)])
        }
        return L10n.t("memories.card.listsHint")
    }

    private var potdTeaserText: String {
        if let day = potdToday, day.dateKey == SharedDates.todayKey() {
            if let myId = appState.memberId, day.entries[myId] == nil {
                return L10n.t("memories.card.potdWaiting")
            }
            if let partnerId = appState.partner?.id, day.entries[partnerId] != nil {
                return L10n.t("memories.card.potdBoth")
            }
        }
        return L10n.t("memories.card.potdHint")
    }

    private var capsulesTeaserText: String {
        if let ready = capsulesReady, ready > 0 {
            return L10n.t("memories.card.capsulesReady", ["n": String(ready)])
        }
        if let sealed = capsulesSealed, sealed > 0 {
            return L10n.t("memories.card.capsulesSealed", ["n": String(sealed)])
        }
        return L10n.t("memories.card.capsulesHint")
    }

    private var goalsTeaserText: String {
        if let active = activeGoals, active > 0 {
            return L10n.t("memories.card.goalsActive", ["n": String(active)])
        }
        return L10n.t("memories.card.goalsHint")
    }

    private var yearReviewTitle: String {
        L10n.t("memories.card.yearreview")
            + " " + String(SharedDates.calendar.component(.year, from: Date()))
    }

    private func photoChipText(_ photo: Photo) -> String {
        if let caption = photo.caption, !caption.isEmpty { return caption }
        let uploader = appState.couple?.members.first { $0.id == photo.uploaderId }?.name
        return L10n.t("memories.gallery.by", ["name": uploader ?? "💜"])
    }

    private func songChipText(_ song: Song) -> String {
        if let artist = song.artist, !artist.isEmpty { return "\(song.title) · \(artist)" }
        return song.title
    }

    private func countdownText(days: Int) -> String {
        if days == 0 { return L10n.t("memories.countdown.today") }
        if days == 1 { return L10n.t("memories.countdown.tomorrow") }
        return L10n.t("memories.countdown.inDays", ["n": String(days)])
    }

    // MARK: Data

    private func reload() async {
        await appState.refreshStats()
        await appState.refreshEvents()
        await loadCouponTeaser()
        await loadSongTeaser()
        await loadLatestPhoto()
        await loadV2Teasers()
    }

    private func loadCouponTeaser() async {
        guard let api = appState.api, let myId = appState.memberId else { return }
        if let list = try? await api.coupons() {
            openCouponCount = list.filter { $0.forMember == myId && $0.redeemedAt == nil }.count
            latestCoupon = list.max { $0.createdAt < $1.createdAt }
        }
    }

    private func loadSongTeaser() async {
        guard let api = appState.api else { return }
        if let list = try? await api.songs() {
            songCount = list.count
            latestSong = list.max { $0.createdAt < $1.createdAt }
        }
    }

    private func loadLatestPhoto() async {
        guard let api = appState.api else { return }
        if let list = try? await api.photos() {
            latestPhoto = list.max { $0.createdAt < $1.createdAt }
        }
    }

    private func loadV2Teasers() async {
        guard let api = appState.api else { return }
        if let lists = try? await api.sharedLists() {
            openListItems = lists.reduce(0) { $0 + $1.openCount }
        }
        if let days = try? await api.potdDays(limit: 1) {
            potdToday = days.first { $0.dateKey == SharedDates.todayKey() }
        }
        await loadRitualTeasers()
    }

    private func loadRitualTeasers() async {
        guard let api = appState.api, let myId = appState.memberId else { return }
        if let capsules = try? await api.capsules() {
            capsulesReady = capsules
                .filter { $0.forMember == myId && $0.openedAt == nil && $0.unlocked }.count
            capsulesSealed = capsules.filter { $0.openedAt == nil }.count
        }
        if let goals = try? await api.goals() {
            activeGoals = goals.filter { $0.completedAt == nil }.count
        }
    }

    private func handleServerEvent(_ event: ServerEvent) {
        switch event.type {
        case .photoAdded, .photoDeleted:
            Task {
                await appState.refreshStats()
                await loadLatestPhoto()
            }
        case .videoAdded, .videoDeleted:
            Task { await appState.refreshStats() }
        case .bucketAdded, .bucketUpdated, .bucketDeleted:
            Task { await appState.refreshStats() }
        case .couponAdded, .couponRedeemed, .couponDeleted:
            Task { await loadCouponTeaser() }
        case .songAdded, .songDeleted:
            Task { await loadSongTeaser() }
        case .listAdded, .listUpdated, .listDeleted, .potdSubmitted:
            Task { await loadV2Teasers() }
        case .capsuleSealed, .capsuleOpened, .capsuleDeleted,
             .goalAdded, .goalUpdated, .goalDeleted:
            Task { await loadRitualTeasers() }
        default:
            break
        }
    }
}

// `MemoriesRoute` lives in Core/Routes.swift (Foundation-only) so the search
// index and its tests can reference it.
