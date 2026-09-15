import SwiftUI

/// „Unser Jahr" — aggregated year in review from `GET /api/yearreview`:
/// big numbers, per-member splits and a share-to-chat summary. Early-year
/// counts can be lower bounds because capped server lists roll off.
struct YearReviewView: View {
    @Environment(AppState.self) private var appState

    @State private var review: YearReview?
    @State private var loading = true
    @State private var failed = false
    @State private var year = SharedDates.calendar.component(.year, from: Date())
    @State private var sharing = false
    @State private var shared = false

    private var currentYear: Int { SharedDates.calendar.component(.year, from: Date()) }

    private var earliestYear: Int {
        guard let created = appState.couple?.createdAt else { return currentYear }
        return min(currentYear, SharedDates.calendar.component(.year, from: created))
    }

    var body: some View {
        List {
            if loading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if failed {
                ContentUnavailableView {
                    Label(L10n.t("yearreview.loadError"), systemImage: "cloud.fog")
                } actions: {
                    Button(L10n.t("common.retry")) { Task { await load() } }
                        .buttonStyle(.bordered)
                }
                .listRowBackground(Color.clear)
            } else if let review {
                Section {
                    statGrid(review)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } header: {
                    Text(L10n.t("yearreview.subtitle", ["year": String(year)]))
                        .textCase(nil)
                }

                memberSection(review)

                Section {
                    Button {
                        share(review)
                    } label: {
                        HStack {
                            Label(L10n.t(shared ? "yearreview.shareSent" : "yearreview.share"),
                                  systemImage: shared ? "checkmark" : "paperplane")
                            if sharing {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(sharing || shared)
                } footer: {
                    Text(L10n.t("yearreview.footnote"))
                }
            }
        }
        .navigationTitle("\(L10n.t("yearreview.title")) \(String(year))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Picker(L10n.t("yearreview.title"), selection: $year) {
                    ForEach(Array(stride(from: currentYear, through: earliestYear, by: -1)), id: \.self) { value in
                        Text(String(value)).tag(value)
                    }
                }
                .pickerStyle(.menu)
                .disabled(earliestYear == currentYear)
            }
        }
        .task(id: year) { await load() }
        .sensoryFeedback(.selection, trigger: year)
    }

    // MARK: Stat grid

    private func statGrid(_ review: YearReview) -> some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        // ViewBuilder accepts at most ten children per block — split the
        // fourteen tiles into two Groups (LazyVGrid flattens them).
        return LazyVGrid(columns: columns, spacing: 12) {
            Group {
                StatTile(systemImage: "photo.fill", value: review.photosAdded,
                         label: L10n.t("yearreview.stat.photos"), tint: .pink)
                StatTile(systemImage: "film.fill", value: review.videosAdded,
                         label: L10n.t("yearreview.stat.videos"), tint: .blue)
                StatTile(systemImage: "bubble.left.and.bubble.right.fill",
                         value: review.messagesByMember.values.reduce(0, +),
                         label: L10n.t("yearreview.stat.messages"), tint: .purple)
                StatTile(systemImage: "heart.fill", value: review.touchesByMember.values.reduce(0, +),
                         label: L10n.t("yearreview.stat.touches"), tint: .accentColor)
                StatTile(systemImage: "gamecontroller.fill", value: review.gamesPlayed,
                         label: L10n.t("yearreview.stat.games"), tint: .indigo)
                StatTile(systemImage: "textformat.abc", value: review.wordleDaysPlayed,
                         label: L10n.t("yearreview.stat.wordle"), tint: .green)
                StatTile(systemImage: "questionmark.bubble.fill", value: review.dailyBothAnswered,
                         label: L10n.t("yearreview.stat.daily"), tint: .orange)
                StatTile(systemImage: "sun.max.fill", value: review.checkinDaysBoth,
                         label: L10n.t("yearreview.stat.checkins"), tint: .yellow,
                         sub: review.checkinStreak > 1
                            ? L10n.t("yearreview.stat.checkinStreak", ["n": String(review.checkinStreak)])
                            : nil)
            }
            Group {
                StatTile(systemImage: "figure.2.arms.open", value: review.hugsSent,
                         label: L10n.t("yearreview.stat.hugs"), tint: .accentColor,
                         sub: review.hugsOpened > 0
                            ? L10n.t("yearreview.stat.hugsOpened", ["n": String(review.hugsOpened)])
                            : nil)
                StatTile(systemImage: "ticket.fill", value: review.couponsRedeemed,
                         label: L10n.t("yearreview.stat.coupons"), tint: .orange)
                StatTile(systemImage: "music.note", value: review.songsAdded,
                         label: L10n.t("yearreview.stat.songs"), tint: .mint)
                StatTile(systemImage: "sparkles", value: review.bucketDone,
                         label: L10n.t("yearreview.stat.bucket"), tint: .indigo)
                StatTile(systemImage: "calendar", value: review.eventsCreated,
                         label: L10n.t("yearreview.stat.events"), tint: .red)
                StatTile(systemImage: "camera.fill", value: review.potdDays,
                         label: L10n.t("yearreview.stat.potd"), tint: .teal)
            }
        }
    }

    // MARK: Per-member splits

    @ViewBuilder
    private func memberSection(_ review: YearReview) -> some View {
        let members = appState.couple?.members ?? []
        if !members.isEmpty,
           review.touchesByMember.values.reduce(0, +) > 0
            || review.gamesPlayed > 0 || review.wordleDaysPlayed > 0 {
            Section {
                ForEach(members) { member in
                    memberRow(member, review: review)
                }
            }
        }
    }

    private func memberRow(_ member: Member, review: YearReview) -> some View {
        HStack(spacing: 12) {
            MemberAvatar(emoji: member.avatar, colorHex: member.color, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(member.name)
                    .font(.body.weight(.medium))
                HStack(spacing: 10) {
                    if let top = review.topTouchType[member.id] ?? nil,
                       let kind = TouchKind(rawValue: top) {
                        Text("\(L10n.t("yearreview.topTouch")): \(kind.emoji)")
                    }
                    let wins = (review.gameWins[member.id] ?? 0) + (review.wordleWins[member.id] ?? 0)
                    if wins > 0 {
                        Label("\(wins) \(L10n.t("yearreview.wins"))", systemImage: "trophy.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Label("\(review.touchesByMember[member.id] ?? 0)", systemImage: "heart.fill")
                    .foregroundStyle(Color.accentColor)
                Label("\(review.messagesByMember[member.id] ?? 0)", systemImage: "bubble.left.fill")
                    .foregroundStyle(Color.purple)
            }
            .font(.caption.weight(.semibold))
            .monospacedDigit()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    // MARK: Share

    private func share(_ review: YearReview) {
        guard let api = appState.api, !sharing else { return }
        sharing = true
        let lines = [
            L10n.t("yearreview.shareHeader", ["year": String(review.year)]),
            "📸 " + L10n.t("yearreview.shareLine.photos", ["n": String(review.photosAdded)]),
            "💬 " + L10n.t("yearreview.shareLine.messages",
                           ["n": String(review.messagesByMember.values.reduce(0, +))]),
            "💓 " + L10n.t("yearreview.shareLine.touches",
                           ["n": String(review.touchesByMember.values.reduce(0, +))]),
            "🎮 " + L10n.t("yearreview.shareLine.games", ["n": String(review.gamesPlayed)])
        ]
        Task {
            do {
                _ = try await api.sendMessage(type: .text, text: lines.joined(separator: "\n"))
                shared = true
                SoundEngine.shared.play(.pop)
                Haptics.shared.success()
                appState.notify(L10n.t("yearreview.shareSent"), style: .success)
            } catch {
                appState.handleAPIError(error)
            }
            sharing = false
        }
    }

    // MARK: Data

    private func load() async {
        guard let api = appState.api else { return }
        loading = true
        failed = false
        shared = false
        do {
            review = try await api.yearReview(year: year)
        } catch {
            failed = true
        }
        loading = false
    }
}

// MARK: - Stat tile

private struct StatTile: View {
    let systemImage: String
    let value: Int
    let label: String
    let tint: Color
    var sub: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                IconTile(systemImage: systemImage, tint: tint, size: 30)
                Spacer()
                Text("\(value)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(value > 0 ? Color.primary : Color.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if let sub {
                Text(sub)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(padding: 14)
        .accessibilityElement(children: .combine)
    }
}
