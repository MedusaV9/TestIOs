import Foundation
import SwiftUI

// MARK: - App-wide reactions to ritual events (v3.0 — Agent A)
//
// Feature views keep their own live state; this extension only covers the
// GLOBAL reactions: toasts, local notifications, the partner's energy light
// on the member object and milestone confetti. Wired into AppState.handle
// via one `case … : handleRitualEvent(event)` line.

extension AppState {
    /// Mirrors an `energy` WS event (or my own PUT/DELETE) into the couple.
    func applyEnergy(memberId: String, energy: MemberEnergy?) {
        guard var couple else { return }
        if let idx = couple.members.firstIndex(where: { $0.id == memberId }) {
            couple.members[idx].energy = energy
            self.couple = couple
        }
    }

    func handleRitualEvent(_ event: ServerEvent) {
        switch event.type {
        case .need:
            if let need = event.decode(NeedEventPayload.self)?.need,
               need.forMember == memberId, let type = need.needType {
                SoundEngine.shared.play(.chime)
                Haptics.shared.tap()
                CoupleNotify.alert(.touch,
                                   title: L10n.t("needs.notif.title", ["name": partnerName]),
                                   body: "\(type.emoji) \(L10n.t(type.titleKey))",
                                   link: "sooodreamy://tab/home")
            }
        case .needAcked:
            if let need = event.decode(NeedEventPayload.self)?.need, need.senderId == memberId {
                notify(L10n.t("needs.ackedToast", ["name": partnerName]), style: .love)
                SoundEngine.shared.play(.sparkle)
            }
        case .capsuleSealed:
            if let capsule = event.decode(CapsuleEventPayload.self)?.capsule,
               capsule.forMember == memberId {
                notify(L10n.t("capsules.toast.sealedForYou", ["name": partnerName]), style: .love)
                SoundEngine.shared.play(.sparkle)
                CoupleNotify.alert(.message,
                                   title: L10n.t("capsules.notif.title"),
                                   body: L10n.t("capsules.notif.body", ["name": partnerName]),
                                   link: "sooodreamy://tab/memories")
            }
        case .capsuleOpened:
            if let capsule = event.decode(CapsuleEventPayload.self)?.capsule,
               capsule.createdBy == memberId {
                notify(L10n.t("capsules.toast.openedByPartner", ["name": partnerName]), style: .love)
                SoundEngine.shared.play(.tada)
            }
        case .energy:
            if let payload = event.decode(EnergyEventPayload.self) {
                applyEnergy(memberId: payload.memberId, energy: payload.energy)
                updateWidgetSnapshot()
                if payload.memberId != memberId,
                   let energy = payload.energy,
                   let level = EnergyLevel(rawValue: energy.level) {
                    notify(L10n.t("energy.toast.partner",
                                     ["name": partnerName,
                                      "level": "\(level.emoji) \(L10n.t(level.titleKey))"]),
                              style: .info)
                }
            }
        case .goalAdded, .goalUpdated:
            // Milestone crossings celebrate on BOTH phones, wherever they are.
            if let payload = event.decode(GoalEventPayload.self) {
                widgetGoal = payload.goal.completedAt == nil
                    ? WidgetSnapshotResponse.GoalSummary(
                        id: payload.goal.id, title: payload.goal.title, emoji: payload.goal.emoji,
                        targetValue: payload.goal.targetValue, unit: payload.goal.unit,
                        targetDate: payload.goal.targetDate, total: payload.goal.total,
                        percent: payload.goal.percent)
                    : nil
                updateWidgetSnapshot()
                guard let milestone = payload.milestone else { break }
                if milestone >= 100 {
                    Delight.celebrate(.epic, theme: .confetti)
                    notify(L10n.t("goals.toast.reached", ["title": payload.goal.title]), style: .love)
                } else {
                    Delight.celebrate(.medium, theme: .stars)
                    notify(L10n.t("goals.toast.milestone",
                                     ["percent": String(milestone), "title": payload.goal.title]),
                              style: .success)
                }
            }
        case .goalDeleted:
            Task {
                await refreshWidgetCore()
                updateWidgetSnapshot()
            }
        case .daymemo:
            // The reveal moment: my partner completed the pair for today.
            if let day = event.decode(DaymemoDay.self),
               day.dateKey == SharedDates.todayKey(),
               day.bothRecorded, day.partner != nil {
                SoundEngine.shared.play(.sparkle)
                CoupleNotify.alert(.dailyReveal,
                                   title: L10n.t("daymemo.notif.title"),
                                   body: L10n.t("daymemo.notif.body"),
                                   link: "sooodreamy://tab/home")
            }
        default:
            break
        }
    }
}
