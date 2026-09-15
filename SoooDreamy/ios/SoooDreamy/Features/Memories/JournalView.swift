import SwiftUI

/// „Unser Tagebuch" — the history of past daily questions with both answers.
/// A searchable list grouped by month; entries share to chat via context menu.
struct JournalView: View {
    @Environment(AppState.self) private var appState

    @State private var entries: [DailyEntry] = []
    @State private var loading = true
    @State private var searchQuery = ""

    var body: some View {
        List {
            if loading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if entries.isEmpty {
                ContentUnavailableView {
                    Label(L10n.t("memories.journal.empty.title"), systemImage: "book.closed")
                } description: {
                    Text(L10n.t("memories.journal.empty.subtitle"))
                }
                .listRowBackground(Color.clear)
            } else if isFiltering && monthGroups.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(monthGroups) { group in
                    Section(group.title) {
                        ForEach(group.entries, id: \.dateKey) { entry in
                            JournalEntryRow(entry: entry, question: questionText(entry))
                                .contextMenu {
                                    if entry.myAnswer != nil {
                                        Button {
                                            shareToChat(entry)
                                        } label: {
                                            Label(L10n.t("memories.journal.share"), systemImage: "paperplane")
                                        }
                                    }
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.t("memories.journal.title"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchQuery, prompt: L10n.t("memories.journal.searchPlaceholder"))
        .refreshable { await loadEntries() }
        .task { await loadEntries() }
    }

    // MARK: Search

    private var searchText: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isFiltering: Bool { !searchText.isEmpty }

    private var filteredEntries: [DailyEntry] {
        guard isFiltering else { return entries }
        let query = searchText
        return entries.filter { entry in
            questionText(entry).localizedCaseInsensitiveContains(query)
                || (entry.myAnswer?.localizedCaseInsensitiveContains(query) ?? false)
                || (entry.partnerAnswer?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    // MARK: Month groups

    private struct MonthGroup: Identifiable {
        let id: String      // "YYYY-MM"
        let title: String
        var entries: [DailyEntry]
    }

    /// Filtered entries grouped by calendar month, preserving the API's
    /// newest-first order (dateKeys sort chronologically as strings).
    private var monthGroups: [MonthGroup] {
        var groups: [MonthGroup] = []
        for entry in filteredEntries {
            let key = String(entry.dateKey.prefix(7))
            if let last = groups.indices.last, groups[last].id == key {
                groups[last].entries.append(entry)
            } else {
                groups.append(MonthGroup(id: key, title: monthTitle(key), entries: [entry]))
            }
        }
        return groups
    }

    /// "2026-08" → "August 2026" in the app language.
    private func monthTitle(_ monthKey: String) -> String {
        guard let date = SharedDates.parse(monthKey + "-01") else { return monthKey }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: L10n.isGerman ? "de_DE" : "en_US")
        formatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return formatter.string(from: date)
    }

    // MARK: Sharing

    /// Posts a past daily question with the visible answers into the couple
    /// chat (the partner's answer is only included once both answered).
    private func shareToChat(_ entry: DailyEntry) {
        guard let api = appState.api else { return }
        var lines = [L10n.t("memories.journal.shareHeader", ["date": journalDateString(entry.dateKey)])]
        let question = questionText(entry)
        if !question.isEmpty { lines.append(question) }
        if let mine = entry.myAnswer {
            lines.append("\(appState.me?.name ?? L10n.t("common.you")): \(mine)")
        }
        if let partner = entry.partnerAnswer {
            lines.append("\(appState.partnerName): \(partner)")
        }
        let text = lines.joined(separator: "\n")
        Task {
            do {
                try await api.sendMessage(type: .text, text: text)
                Haptics.shared.success()
                SoundEngine.shared.play(.pop)
                appState.notify(L10n.t("memories.journal.shareSent"), style: .success)
            } catch {
                appState.handleAPIError(error)
            }
        }
    }

    // MARK: Helpers

    private func questionText(_ entry: DailyEntry) -> String {
        var question: DailyQuestion?
        if let qid = entry.questionId {
            question = ContentPack.dailyQuestions.first { $0.id == qid }
        }
        if question == nil, let couple = appState.couple {
            question = ContentPack.dailyQuestion(dateKey: entry.dateKey, coupleId: couple.id)
        }
        guard let question else { return "" }
        return question.text.filled(partner: appState.partnerName, lang: L10n.lang)
    }

    private func loadEntries() async {
        guard let api = appState.api else { return }
        do {
            entries = try await api.dailyHistory()
        } catch {
            appState.handleAPIError(error)
        }
        loading = false
    }
}

/// Long date in the app language ("14. September 2026").
func journalDateString(_ key: String) -> String {
    guard let date = SharedDates.parse(key) else { return key }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: L10n.isGerman ? "de_DE" : "en_US")
    formatter.dateStyle = .long
    return formatter.string(from: date)
}

/// One past daily question: date, question, both answers (or the waiting hint).
private struct JournalEntryRow: View {
    @Environment(AppState.self) private var appState
    let entry: DailyEntry
    let question: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(journalDateString(entry.dateKey))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(question)
                .font(.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            answers
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var answers: some View {
        if entry.bothAnswered {
            VStack(alignment: .leading, spacing: 8) {
                answerBubble(name: appState.me?.name ?? L10n.t("common.you"),
                             text: entry.myAnswer ?? "", tint: .purple)
                answerBubble(name: appState.partnerName,
                             text: entry.partnerAnswer ?? "", tint: .accentColor)
            }
        } else if let mine = entry.myAnswer {
            VStack(alignment: .leading, spacing: 8) {
                answerBubble(name: appState.me?.name ?? L10n.t("common.you"), text: mine, tint: .purple)
                Text(L10n.t("memories.journal.waiting", ["name": appState.partnerName]))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            // Either only the partner answered (answers stay hidden until both did)
            // or nobody answered — a neutral hint covers both.
            Text(L10n.t("memories.journal.noAnswer"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func answerBubble(name: String, text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: Brand.tileRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
