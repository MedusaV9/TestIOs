import SwiftUI
import Combine

// MARK: - Spiele-Bilanz — recent couple games & winners

/// Pushed from the Wir hub. Loads past sessions (`GET /api/games`), shows
/// the win/tie record for the competitive games plus a list of recent
/// games: score rows carry the result and the winner, the cooperative
/// choice games (This or That / Would You Rather) show their match rate.
struct GamesRecordView: View {
    @Environment(AppState.self) private var appState

    @State private var games: [GameSession] = []
    @State private var loading = true

    var body: some View {
        List {
            if loading && games.isEmpty {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if games.isEmpty {
                ContentUnavailableView {
                    Label(L10n.t("games.record.emptyTitle"), systemImage: "trophy")
                } description: {
                    Text(L10n.t("games.record.emptyBody"))
                }
                .listRowBackground(Color.clear)
            } else {
                recordSection
                Section(L10n.t("games.record.recent")) {
                    ForEach(games) { game in
                        gameRow(game)
                    }
                }
            }
        }
        .navigationTitle(L10n.t("games.record.title"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            // A game just finished — the scoreboard is stale.
            guard let event = note.object as? ServerEvent, event.type == .gameEnded else { return }
            Task { await load() }
        }
    }

    // MARK: Loading

    private func load() async {
        guard let api = appState.api else {
            loading = false
            return
        }
        // Pre-v1.6 servers 404 the list — the empty state stays up quietly.
        if let sessions = try? await api.games(limit: 30) {
            games = sessions
                .filter { $0.state == "ended" && outcome(of: $0) != nil }
                .sorted { $0.createdAt > $1.createdAt }
        }
        loading = false
    }

    // MARK: Outcomes

    /// What a finished session amounted to on the scoreboard.
    private enum Outcome {
        /// Competitive game: my points vs. the partner's.
        case score(mine: Int, partner: Int)
        /// Cooperative choice games: how often the picks matched.
        case matches(n: Int, total: Int)
    }

    private func outcome(of game: GameSession) -> Outcome? {
        guard let kind = game.kind, let result = game.result else { return nil }
        switch kind {
        case .quiz, .emojiriddle, .connectfour, .photomemory, .quizduel,
             .battleship, .pictionary, .kniffel, .stadtlandfluss, .twotruths:
            // Competitive games store `result.scores`; sessions without one
            // quietly stay off the record.
            guard let scores = result["scores"]?.objectValue else { return nil }
            let mine = appState.memberId.flatMap { scores[$0]?.intValue } ?? 0
            let partner = scores.first { $0.key != appState.memberId }?.value.intValue ?? 0
            return .score(mine: mine, partner: partner)
        case .thisorthat, .wouldyourather:
            guard let n = result["matches"]?.intValue,
                  let total = result["rounds"]?.intValue, total > 0 else { return nil }
            return .matches(n: n, total: total)
        case .truthordare, .questions36:
            return nil   // local pass-the-phone games never store results
        case .movieroulette, .dailyquests:
            return nil   // matching/quest sessions — no head-to-head score
        }
    }

    // MARK: Record (competitive games only)

    private var record: (mine: Int, ties: Int, partner: Int) {
        var mine = 0, ties = 0, partner = 0
        for game in games {
            guard case .score(let m, let p)? = outcome(of: game) else { continue }
            if m > p { mine += 1 } else if p > m { partner += 1 } else { ties += 1 }
        }
        return (mine, ties, partner)
    }

    @ViewBuilder
    private var recordSection: some View {
        let record = record
        let total = record.mine + record.ties + record.partner
        Section {
            GameMemberScoreRow(member: appState.me, value: "\(record.mine)",
                               highlighted: record.mine > record.partner)
            GameMemberScoreRow(member: appState.partner, value: "\(record.partner)",
                               highlighted: record.partner > record.mine)
            LabeledContent(L10n.t("games.record.ties"), value: "\(record.ties)")
        } header: {
            Text(L10n.t("games.record.title"))
        } footer: {
            if total > 0 {
                Text(leaderLine(record) + " · " + L10n.t("games.record.subtitle", ["n": "\(total)"]))
            }
        }
    }

    private func leaderLine(_ record: (mine: Int, ties: Int, partner: Int)) -> String {
        if record.mine > record.partner {
            return L10n.t("games.record.leaderMe")
        }
        if record.partner > record.mine {
            return L10n.t("games.record.leaderPartner", ["name": appState.partnerName])
        }
        return L10n.t("games.record.leaderTie")
    }

    // MARK: Game list

    @ViewBuilder
    private func gameRow(_ game: GameSession) -> some View {
        if let kind = game.kind, let outcome = outcome(of: game), let info = GameCatalog.info(kind) {
            HStack(spacing: 12) {
                IconTile(systemImage: info.systemImage, tint: info.tint, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Text(game.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                outcomeView(outcome)
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private func outcomeView(_ outcome: Outcome) -> some View {
        switch outcome {
        case .score(let mine, let partner):
            HStack(spacing: 8) {
                Text("\(mine) : \(partner)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(mine >= partner ? Color.primary : Color.secondary)
                Image(systemName: mine > partner ? "trophy.fill" : (partner > mine ? "flag.fill" : "heart.fill"))
                    .foregroundStyle(mine > partner ? Color.yellow : (partner > mine ? Color.secondary : Color.accentColor))
                    .font(.subheadline)
            }
        case .matches(let n, let total):
            HStack(spacing: 8) {
                Text(L10n.t("games.record.matches", ["n": "\(n)", "total": "\(total)"]))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
                Image(systemName: total > 0 && n * 2 >= total ? "heart.fill" : "sparkles")
                    .foregroundStyle(Color.accentColor)
                    .font(.subheadline)
            }
        }
    }
}
