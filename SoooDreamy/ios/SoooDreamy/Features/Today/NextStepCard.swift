import SwiftUI

/// "Jetzt dran" — the single most relevant action right now, derived from
/// real state by `NextStepRules`. One card, one button, done in one tap
/// where possible (check-in, heartbeat); otherwise it takes you straight to
/// the right place. Recomputed every minute so daypart boundaries hold.
struct NextStepCard: View {
    @Environment(AppState.self) private var appState
    @Binding var showMood: Bool

    @State private var busy = false
    @State private var completedKind: NextStepRules.Kind?

    var body: some View {
        TimelineView(.everyMinute) { context in
            let step = nextStep(at: context.date)
            content(for: step)
                .animation(.snappy, value: step)
        }
    }

    // MARK: Card

    @ViewBuilder
    private func content(for step: NextStepRules.Kind) -> some View {
        if step == .allDone {
            Label(L10n.t("today.next.allDone"), systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface(padding: 14)
                .accessibilityElement(children: .combine)
        } else {
            HStack(alignment: .center, spacing: 14) {
                if case .specialDay(let day) = step, !day.emoji.isEmpty {
                    // The couple's own emoji for their day, on the same tile shape.
                    Text(day.emoji)
                        .font(.system(size: 24))
                        .frame(width: 44, height: 44)
                        .background(tint(step).opacity(0.18), in: RoundedRectangle(cornerRadius: 10.5, style: .continuous))
                        .accessibilityHidden(true)
                } else {
                    IconTile(systemImage: symbol(step), tint: tint(step), size: 44)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("today.next.title"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint(step))
                        .textCase(.uppercase)
                    Text(headline(step))
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subline(step))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                actionControl(step)
            }
            .cardSurface(padding: 14)
            .accessibilityElement(children: .combine)
        }
    }

    /// One-tap actions run inline; navigation actions are links.
    @ViewBuilder
    private func actionControl(_ step: NextStepRules.Kind) -> some View {
        switch step {
        case .specialDay:
            NavigationLink(value: TodayRoute.events) {
                actionLabel(L10n.t("today.next.special.open"))
            }
            .buttonStyle(.glassProminent)
            .controlSize(.small)
        case .answerDaily:
            NavigationLink(value: TodayRoute.daily) {
                actionLabel(L10n.t("today.next.answer"))
            }
            .buttonStyle(.glassProminent)
            .controlSize(.small)
        case .gameTurn:
            Button {
                appState.activeTab = .us
            } label: {
                actionLabel(L10n.t("today.next.play"))
            }
            .buttonStyle(.glassProminent)
            .controlSize(.small)
        case .morningCheckin, .nightCheckin:
            Button {
                let kind = step == .morningCheckin ? "morning" : "night"
                busy = true
                Task {
                    if await appState.checkIn(kind: kind) { completedKind = step }
                    busy = false
                }
            } label: {
                if busy {
                    ProgressView()
                } else {
                    actionLabel(L10n.t(step == .morningCheckin ? "today.next.checkinMorning"
                                                                : "today.next.checkinNight"))
                }
            }
            .buttonStyle(.glassProminent)
            .controlSize(.small)
            .disabled(busy)
        case .shareMood:
            Button {
                showMood = true
            } label: {
                actionLabel(L10n.t("today.next.mood"))
            }
            .buttonStyle(.glassProminent)
            .controlSize(.small)
        case .sendLove:
            Button {
                appState.sendTouch(.heartbeat)
                completedKind = step
            } label: {
                actionLabel(L10n.t("today.next.heartbeat"))
            }
            .buttonStyle(.glassProminent)
            .controlSize(.small)
            .sensoryFeedback(.success, trigger: completedKind) { _, new in new == .sendLove }
        case .allDone:
            EmptyView()
        }
    }

    private func actionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
    }

    // MARK: State → step

    private func nextStep(at date: Date) -> NextStepRules.Kind {
        let hour = Calendar.current.component(.hour, from: date)
        var input = NextStepRules.Input(hour: hour)
        input.hasPartner = appState.partner != nil
        input.gamesAwaiting = appState.gamesAwaitingMe.count
        input.questionAvailable = appState.dailyEntry != nil
        input.myAnswered = appState.dailyEntry?.myAnswer != nil
        input.partnerAnswered = appState.dailyEntry?.partnerAnswer != nil
            || (appState.dailyEntry?.bothAnswered ?? false)
        input.morningDone = appState.todayCheckin?.checkedIn(appState.memberId, kind: "morning") ?? false
        input.nightDone = appState.todayCheckin?.checkedIn(appState.memberId, kind: "night") ?? false
        input.myMoodAge = appState.me?.moodUpdatedAt.map { date.timeIntervalSince($0) }
        input.receivedTouchToday = appState.lastTouchAt.map { Calendar.current.isDateInToday($0) } ?? false
        input.nextSpecialDay = appState.nextEvent.map {
            NextStepRules.SpecialDay(title: $0.event.title, emoji: $0.event.emoji, daysUntil: $0.days)
        }
        var step = NextStepRules.nextStep(input)
        // A heartbeat just sent counts as "done" until the next refresh.
        if completedKind == .sendLove, step == .sendLove { step = .allDone }
        return step
    }

    // MARK: Copy

    private func headline(_ step: NextStepRules.Kind) -> String {
        let partner = appState.partnerName
        switch step {
        case .specialDay(let day):
            let key = day.daysUntil == 0 ? "today.next.special.today" : "today.next.special.tomorrow"
            return L10n.t(key, ["title": day.title])
        case .gameTurn(let count):
            return count == 1 ? L10n.t("today.next.game.one", ["name": partner])
                              : L10n.t("today.next.game.many", ["n": String(count)])
        case .answerDaily(let partnerAnswered):
            return partnerAnswered ? L10n.t("today.next.daily.partnerAnswered", ["name": partner])
                                   : L10n.t("today.next.daily.open")
        case .morningCheckin: return L10n.t("today.next.morning.title")
        case .nightCheckin: return L10n.t("today.next.night.title")
        case .shareMood: return L10n.t("today.next.mood.title", ["name": partner])
        case .sendLove: return L10n.t("today.next.love.title", ["name": partner])
        case .allDone: return L10n.t("today.next.allDone")
        }
    }

    private func subline(_ step: NextStepRules.Kind) -> String {
        switch step {
        case .specialDay(let day):
            return L10n.t(day.daysUntil == 0 ? "today.next.special.today.sub" : "today.next.special.tomorrow.sub")
        case .gameTurn: return L10n.t("today.next.game.sub")
        case .answerDaily(let partnerAnswered):
            return partnerAnswered ? L10n.t("today.next.daily.partnerAnswered.sub") : L10n.t("today.next.daily.open.sub")
        case .morningCheckin: return L10n.t("today.next.morning.sub")
        case .nightCheckin: return L10n.t("today.next.night.sub")
        case .shareMood: return L10n.t("today.next.mood.sub")
        case .sendLove: return L10n.t("today.next.love.sub")
        case .allDone: return ""
        }
    }

    private func symbol(_ step: NextStepRules.Kind) -> String {
        switch step {
        case .specialDay: return "party.popper.fill"
        case .gameTurn: return "gamecontroller.fill"
        case .answerDaily: return "questionmark.bubble.fill"
        case .morningCheckin: return "sun.max.fill"
        case .nightCheckin: return "moon.stars.fill"
        case .shareMood: return "face.smiling.fill"
        case .sendLove: return "heart.fill"
        case .allDone: return "checkmark.seal.fill"
        }
    }

    private func tint(_ step: NextStepRules.Kind) -> Color {
        switch step {
        case .specialDay: return .pink
        case .gameTurn: return .purple
        case .answerDaily: return .blue
        case .morningCheckin: return .orange
        case .nightCheckin: return .indigo
        case .shareMood: return .teal
        case .sendLove: return .accentColor
        case .allDone: return .green
        }
    }
}
