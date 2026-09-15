import SwiftUI

/// The daily question: answer, wait for the partner, reveal both answers,
/// share the reveal to the chat, jump to the streak calendar and journal.
struct DailyQuestionView: View {
    @Environment(AppState.self) private var appState

    @State private var answer = ""
    @State private var sending = false
    @State private var sharing = false
    @State private var shared = false
    @FocusState private var answerFocused: Bool

    private var question: DailyQuestion? {
        appState.couple.map { ContentPack.dailyQuestion(dateKey: SharedDates.todayKey(), coupleId: $0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let question {
                    questionCard(question)
                    stateSection(question)
                }
                journalLink
            }
            .padding(Brand.screenInset)
        }
        .groupedScreenBackground()
        .navigationTitle(L10n.t("home.dailyQuestion"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let streak = appState.dailyEntry?.streak, streak > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: TodayRoute.streak) {
                        StreakBadge(streak: streak)
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
        }
        .sensoryFeedback(.success, trigger: appState.dailyEntry?.bothAnswered ?? false) { _, new in new }
    }

    private func questionCard(_ question: DailyQuestion) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.t("common.today").uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            Text(question.text.filled(partner: appState.partnerName, lang: L10n.lang))
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(Date().formatted(date: .complete, time: .omitted))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(padding: 20)
    }

    @ViewBuilder
    private func stateSection(_ question: DailyQuestion) -> some View {
        let entry = appState.dailyEntry
        if entry?.bothAnswered == true {
            VStack(alignment: .leading, spacing: 12) {
                answerBubble(name: appState.me?.name ?? L10n.t("common.you"),
                             member: appState.me, text: entry?.myAnswer ?? "")
                answerBubble(name: appState.partnerName, member: appState.partner,
                             text: entry?.partnerAnswer ?? "")
                Label(L10n.t("home.bothAnswered"), systemImage: "checkmark.seal.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.green)
                Button {
                    share(question)
                } label: {
                    HStack {
                        if sharing { ProgressView() }
                        Label(L10n.t(shared ? "games.sharedToChat" : "home.shareAnswers"),
                              systemImage: shared ? "checkmark" : "paperplane")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(sharing || shared)
            }
        } else if entry?.myAnswer != nil {
            VStack(alignment: .leading, spacing: 12) {
                answerBubble(name: appState.me?.name ?? L10n.t("common.you"),
                             member: appState.me, text: entry?.myAnswer ?? "")
                HStack(spacing: 8) {
                    ProgressView()
                    Text(L10n.t("home.waitingPartnerAnswer", ["name": appState.partnerName]))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                if entry?.partnerAnswer != nil {
                    Label(L10n.t("today.daily.partnerAnswered"), systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                HStack(alignment: .bottom, spacing: 10) {
                    TextField(L10n.t("home.answerNow"), text: $answer, axis: .vertical)
                        .lineLimit(1...5)
                        .focused($answerFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    Button {
                        Task { await submit(question) }
                    } label: {
                        Group {
                            if sending {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "arrow.up")
                                    .font(.body.weight(.bold))
                            }
                        }
                        .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(sending || answer.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel(L10n.t("common.send"))
                }
                Text(L10n.t("today.daily.quote"))
                    .font(.footnote.italic())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }
        }
    }

    private func answerBubble(name: String, member: Member?, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            MemberAvatar(member: member, size: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .cardSurface(padding: 14)
    }

    private var journalLink: some View {
        NavigationLink {
            JournalView()
        } label: {
            HStack(spacing: 14) {
                IconTile(systemImage: "book.closed.fill", tint: .brown, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("memories.journal.title"))
                        .font(.headline)
                    Text(L10n.t("today.journal.subtitle"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                DisclosureChevron()
            }
            .multilineTextAlignment(.leading)
            .cardSurface(padding: 14)
        }
        .buttonStyle(.plain)
    }

    private func submit(_ question: DailyQuestion) async {
        guard let api = appState.api else { return }
        let text = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        sending = true
        defer { sending = false }
        do {
            let entry = try await api.answerDaily(dateKey: SharedDates.todayKey(),
                                                  questionId: question.id, text: text)
            appState.dailyEntry = entry
            answer = ""
            answerFocused = false
            SoundEngine.shared.play(.chime)
            appState.updateWidgetSnapshot()
        } catch {
            appState.handleAPIError(error)
        }
    }

    private func share(_ question: DailyQuestion) {
        guard let api = appState.api, let entry = appState.dailyEntry, entry.bothAnswered,
              !sharing, !shared else { return }
        sharing = true
        let myName = appState.me?.name ?? L10n.t("common.you")
        let text = L10n.t("home.dailyShareHeader") + " "
            + question.text.filled(partner: appState.partnerName, lang: L10n.lang) + "\n"
            + "\(myName): \(entry.myAnswer ?? "")" + "\n"
            + "\(appState.partnerName): \(entry.partnerAnswer ?? "")"
        Task {
            do {
                _ = try await api.sendMessage(type: .text, text: text)
                shared = true
                SoundEngine.shared.play(.pop)
                appState.notify(L10n.t("games.sharedToChat"), style: .success)
            } catch {
                appState.handleAPIError(error)
            }
            sharing = false
        }
    }
}
