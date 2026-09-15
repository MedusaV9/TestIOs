import SwiftUI

/// "Unser Monat" — a monthly issue of the couple's moments: photos, the
/// daily answer with the most heart, the shared song and the numbers.
struct MagazineView: View {
    @Environment(AppState.self) private var appState

    @State private var months: [String] = []
    @State private var selectedMonth: String?
    @State private var issue: MagazineIssue?
    @State private var loading = true

    var body: some View {
        Group {
            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if months.isEmpty {
                ContentUnavailableView(L10n.t("magazine.empty.title"), systemImage: "book.pages",
                                       description: Text(L10n.t("magazine.empty.subtitle")))
            } else if let issue {
                MagazinePages(issue: issue)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .groupedScreenBackground()
        .navigationTitle(selectedMonth.map(magazineMonthName) ?? L10n.t("magazine.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if months.count > 1 {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker(L10n.t("magazine.archive"), selection: $selectedMonth) {
                            ForEach(months, id: \.self) { month in
                                Text(magazineMonthName(month)).tag(Optional(month))
                            }
                        }
                    } label: {
                        Label(L10n.t("magazine.archive"), systemImage: "calendar")
                    }
                }
            }
        }
        .task(id: appState.couple?.id) { await loadMonths() }
        .onChange(of: selectedMonth) { Task { await loadIssue() } }
    }

    private func loadMonths() async {
        guard let api = appState.api else { loading = false; return }
        if let list = try? await api.magazineMonths() {
            months = list
            if selectedMonth == nil || !list.contains(selectedMonth ?? "") {
                selectedMonth = list.first
            }
        }
        loading = false
        if issue == nil { await loadIssue() }
    }

    private func loadIssue() async {
        guard let api = appState.api, let month = selectedMonth else { return }
        if let loaded = try? await api.magazine(month: month) {
            issue = loaded
            _ = try? await api.markMagazineSeen(month: month)
        }
    }
}

/// "September 2026" for a "YYYY-MM" key.
func magazineMonthName(_ month: String) -> String {
    let parts = month.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 2,
          let date = SharedDates.calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: 15))
    else { return month }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: L10n.isGerman ? "de_DE" : "en_US")
    formatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")
    return formatter.string(from: date)
}

// MARK: - Pages

private struct MagazinePages: View {
    @Environment(AppState.self) private var appState
    let issue: MagazineIssue

    var body: some View {
        TabView {
            coverPage
            if !issue.photos.isEmpty { photosPage }
            if let quote = issue.quote { quotePage(quote) }
            if let song = issue.song { songPage(song) }
            statsPage
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    private var seenByBoth: Bool {
        guard let members = appState.couple?.members, members.count == 2 else { return false }
        return members.allSatisfy { issue.seen[$0.id] != nil }
    }

    private var coverPage: some View {
        MagazinePage {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
                Text(L10n.t("magazine.title"))
                    .font(.largeTitle.weight(.bold))
                Text(magazineMonthName(issue.month))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(L10n.t("magazine.issue") + " " + issue.month)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.tertiaryCardBackground, in: Capsule())
                if seenByBoth {
                    Label(L10n.t("magazine.seenBoth"), systemImage: "checkmark.seal.fill")
                        .font(.footnote)
                        .foregroundStyle(Color.green)
                }
                Spacer()
                Label(L10n.t("magazine.swipeHint"), systemImage: "hand.draw")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var photosPage: some View {
        MagazinePage {
            VStack(alignment: .leading, spacing: 12) {
                pageTitle("photo.on.rectangle.angled", L10n.t("magazine.photos"))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                    ForEach(issue.photos.prefix(6)) { photo in
                        RemotePhoto(api: appState.api, path: photo.thumbUrl ?? photo.url)
                            .aspectRatio(1, contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(alignment: .bottomLeading) {
                                if !photo.favorites.isEmpty {
                                    Image(systemName: "heart.fill")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                        .padding(6)
                                }
                            }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func quotePage(_ quote: MagazineQuote) -> some View {
        MagazinePage {
            VStack(alignment: .leading, spacing: 16) {
                pageTitle("quote.bubble.fill", L10n.t("magazine.quote"))
                if let question = questionText(quote) {
                    Text(question)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(sortedAnswers(quote), id: \.0) { memberId, answer in
                    let member = appState.couple?.members.first { $0.id == memberId }
                    HStack(alignment: .top, spacing: 10) {
                        MemberAvatar(member: member, size: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member?.name ?? "–")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(answer)
                                .font(.body)
                                .fontDesign(.serif)
                        }
                    }
                }
                if let date = SharedDates.parse(quote.dateKey) {
                    Text(ritualDateString(date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func questionText(_ quote: MagazineQuote) -> String? {
        guard let couple = appState.couple else { return nil }
        let question = ContentPack.dailyQuestions.first { $0.id == quote.questionId }
            ?? ContentPack.dailyQuestion(dateKey: quote.dateKey, coupleId: couple.id)
        return question.text.filled(partner: appState.partnerName, lang: L10n.lang)
    }

    private func sortedAnswers(_ quote: MagazineQuote) -> [(String, String)] {
        quote.answers.sorted { lhs, _ in lhs.key == appState.memberId }.map { ($0.key, $0.value) }
    }

    private func songPage(_ song: MagazineSong) -> some View {
        MagazinePage {
            VStack(spacing: 16) {
                pageTitle("music.note", L10n.t("magazine.song"))
                Spacer()
                Image(systemName: "music.note.list")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
                Text(song.title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                if let artist = song.artist {
                    Text(artist)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                if !song.heartedBy.isEmpty {
                    Label("\(song.heartedBy.count)", systemImage: "heart.fill")
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var statsPage: some View {
        let stats = issue.stats
        let rows: [(key: String, systemImage: String, value: Int)] = [
            ("magazine.stat.messages", "bubble.left.fill", stats.messages),
            ("magazine.stat.touches", "heart.fill", stats.touches),
            ("magazine.stat.photos", "photo.fill", stats.photosAdded),
            ("magazine.stat.videos", "video.fill", stats.videosAdded),
            ("magazine.stat.games", "gamecontroller.fill", stats.gamesPlayed),
            ("magazine.stat.wordle", "textformat.abc", stats.wordleDays),
            ("magazine.stat.daily", "text.bubble.fill", stats.dailyBothAnswered),
            ("magazine.stat.checkins", "sunrise.fill", stats.checkinDaysBoth),
            ("magazine.stat.daymemos", "mic.fill", stats.daymemoDays),
            ("magazine.stat.hugs", "gift.fill", stats.hugsSent),
            ("magazine.stat.potd", "camera.fill", stats.potdDays),
            ("magazine.stat.goals", "target", stats.goalsCompleted),
        ]
        return MagazinePage {
            VStack(alignment: .leading, spacing: 12) {
                pageTitle("chart.bar.fill", L10n.t("magazine.stats"))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(rows.filter { $0.value > 0 }, id: \.key) { row in
                        HStack(spacing: 10) {
                            Image(systemName: row.systemImage)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 0) {
                                Text("\(row.value)")
                                    .font(.headline.monospacedDigit())
                                Text(L10n.t(row.key))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(Color.tertiaryCardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func pageTitle(_ systemImage: String, _ title: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.title3.weight(.bold))
            .foregroundStyle(Color.accentColor)
    }
}

/// One magazine page: a full-height card with generous padding.
private struct MagazinePage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, Brand.screenInset)
            .padding(.vertical, 12)
            .padding(.bottom, 28)
    }
}
