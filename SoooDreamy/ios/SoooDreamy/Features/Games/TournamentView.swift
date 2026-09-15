import SwiftUI
import Combine

/// One season per month — lets the ceremony present as `.sheet(item:)`.
extension SeasonTable: Identifiable {
    var id: String { monthKey }
}

// Turnier-Modus & Saison-Trophäen — monthly seasons across ALL games.
// No new realtime protocol: both clients aggregate GET /api/games into the
// same deterministic tables (Content/TournamentLogic.swift). A closed
// season triggers a one-time ceremony sheet; past seasons live on the shelf.
struct TournamentView: View {
    @Environment(AppState.self) private var appState

    @State private var games: [GameSession] = []
    @State private var loading = true
    @State private var ceremonyTable: SeasonTable?

    var body: some View {
        List {
            if loading && games.isEmpty {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else {
                seasonSection(currentTable, isCurrent: true)
                if pastTables.isEmpty {
                    Section(L10n.t("games.season.shelf")) {
                        Text(L10n.t("games.season.shelf.empty"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(pastTables, id: \.monthKey) { table in
                        seasonSection(table, isCurrent: false)
                    }
                }
            }
        }
        .navigationTitle(L10n.t("games.season.title"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent, event.type == .gameEnded else { return }
            Task { await load() }
        }
        .sheet(item: $ceremonyTable, onDismiss: { markCeremonySeen() }) { table in
            ceremonySheet(table)
        }
    }

    // MARK: Data

    private func load() async {
        guard let api = appState.api else {
            loading = false
            return
        }
        if let sessions = try? await api.games(limit: 100) {
            games = sessions
        }
        loading = false
        checkCeremony()
    }

    /// Finished competitive sessions → season matches. Sessions without a
    /// `result.scores` head-to-head (quests, movie roulette, local games)
    /// stay off the season account.
    private var matches: [SeasonMatch] {
        games.compactMap { game in
            guard game.state == "ended", let kind = game.kind,
                  let scores = game.result?["scores"]?.objectValue,
                  let myId = appState.memberId else { return nil }
            let mine = scores[myId]?.intValue ?? 0
            guard let theirs = scores.first(where: { $0.key != myId })?.value.intValue else {
                return nil
            }
            return SeasonMatch(type: kind.rawValue,
                               monthKey: Tournament.monthKey(of: SharedDates.todayKey(game.createdAt)),
                               mine: mine, theirs: theirs)
        }
    }

    private var currentMonth: String { Tournament.monthKey(of: SharedDates.todayKey()) }

    private var currentTable: SeasonTable {
        Tournament.table(matches: matches, month: currentMonth)
    }

    /// Closed seasons (past months with games), newest first.
    private var pastTables: [SeasonTable] {
        Tournament.tables(matches: matches).filter {
            $0.monthKey < currentMonth && $0.games > 0
        }
    }

    // MARK: Ceremony (one-time per closed season)

    private func ceremonyKey(_ month: String) -> String {
        "season.ceremony.\(appState.couple?.id ?? "?").\(month)"
    }

    private func checkCeremony() {
        guard let latest = pastTables.first,
              !UserDefaults.standard.bool(forKey: ceremonyKey(latest.monthKey)) else { return }
        ceremonyTable = latest
        SoundEngine.shared.play(.win)
        Delight.celebrate(.epic, theme: .confetti)
    }

    private func markCeremonySeen() {
        // `ceremonyTable` is already nil here — remember the newest closed season.
        if let latest = pastTables.first {
            UserDefaults.standard.set(true, forKey: ceremonyKey(latest.monthKey))
        }
    }

    private func ceremonySheet(_ table: SeasonTable) -> some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 10) {
                        Text("🏆")
                            .font(.system(size: 64))
                        Text(L10n.t("games.season.ceremony.title", ["month": monthName(table.monthKey)]))
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                        Text(leaderLine(table))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(Tournament.trophies(for: table)) { trophy in
                        trophyRow(trophy, table: table)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("games.season.ceremony.dismiss")) { ceremonyTable = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: Sections

    @ViewBuilder
    private func seasonSection(_ table: SeasonTable, isCurrent: Bool) -> some View {
        Section {
            if table.games == 0 {
                Text(L10n.t("games.season.empty"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                GameMemberScoreRow(member: appState.me, value: "\(table.myPoints)",
                                   detail: L10n.t("games.season.wins", ["a": "\(table.myWins)", "b": "\(table.theirWins)"]),
                                   highlighted: table.leader == .me)
                GameMemberScoreRow(member: appState.partner, value: "\(table.theirPoints)",
                                   detail: L10n.t("games.season.wins", ["a": "\(table.theirWins)", "b": "\(table.myWins)"]),
                                   highlighted: table.leader == .partner)
                LabeledContent(L10n.t("games.season.games", ["n": "\(table.games)"]),
                               value: L10n.t("games.season.ties", ["n": "\(table.ties)"]) + " · "
                               + L10n.t("games.season.types", ["n": "\(table.types.count)"]))
                    .font(.subheadline)
                if !isCurrent {
                    ForEach(Tournament.trophies(for: table)) { trophy in
                        trophyRow(trophy, table: table)
                    }
                }
            }
        } header: {
            HStack {
                Label(isCurrent
                      ? L10n.t("games.season.current", ["month": monthName(table.monthKey)])
                      : monthName(table.monthKey),
                      systemImage: isCurrent ? "flame.fill" : "calendar")
                if isCurrent {
                    Spacer()
                    Text(L10n.t("games.season.daysLeft", ["n": "\(daysLeftInMonth)"]))
                }
            }
        }
    }

    private func trophyRow(_ trophy: SeasonTrophy, table: SeasonTable) -> some View {
        Label {
            Text(trophyLabel(trophy.kind, table: table))
                .font(.body)
        } icon: {
            Image(systemName: trophySymbol(trophy.kind))
                .foregroundStyle(trophy.kind.isCoop ? Color.accentColor : Color.yellow)
        }
    }

    private func trophySymbol(_ kind: SeasonTrophyKind) -> String {
        switch kind {
        case .goldMe, .goldPartner: return "trophy.fill"
        case .shared: return "hands.sparkles.fill"
        case .marathon: return "medal.fill"
        case .explorers: return "safari.fill"
        }
    }

    private func trophyLabel(_ kind: SeasonTrophyKind, table: SeasonTable) -> String {
        switch kind {
        case .goldMe:
            return L10n.t("games.season.trophy.gold", ["name": appState.me?.name ?? L10n.t("common.you")])
        case .goldPartner:
            return L10n.t("games.season.trophy.gold", ["name": appState.partnerName])
        case .shared:
            return L10n.t("games.season.trophy.shared")
        case .marathon:
            return L10n.t("games.season.trophy.marathon", ["n": "\(table.games)"])
        case .explorers:
            return L10n.t("games.season.trophy.explorers", ["n": "\(table.types.count)"])
        }
    }

    private func leaderLine(_ table: SeasonTable) -> String {
        switch table.leader {
        case .me:
            return L10n.t("games.season.leader.me",
                          ["points": "\(table.myPoints)", "theirs": "\(table.theirPoints)"])
        case .partner:
            return L10n.t("games.season.leader.partner",
                          ["name": appState.partnerName,
                           "points": "\(table.theirPoints)", "mine": "\(table.myPoints)"])
        case .tie:
            return L10n.t("games.season.leader.tie", ["points": "\(table.myPoints)"])
        }
    }

    // MARK: Date helpers

    private var daysLeftInMonth: Int {
        let calendar = SharedDates.calendar
        let now = Date()
        guard let range = calendar.range(of: .day, in: .month, for: now) else { return 0 }
        let day = calendar.component(.day, from: now)
        return Swift.max(0, range.count - day)
    }

    /// "2026-08" → localized "August 2026".
    private func monthName(_ monthKey: String) -> String {
        let parts = monthKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return monthKey }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = 1
        guard let date = SharedDates.calendar.date(from: components) else { return monthKey }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: L10n.isGerman ? "de_DE" : "en_US")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
}
