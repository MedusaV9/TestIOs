import SwiftUI

/// Notifications: couple alerts (master switch, sound, per-event toggles),
/// the evening reminder, streak guard and coupon-expiry nudge.
struct NotificationSettingsView: View {
    @Environment(AppState.self) private var appState

    @State private var alertsOn = NotificationPrefs.enabled
    @State private var alertSound = NotificationPrefs.globalSound
    @State private var alertKinds: [CoupleAlertKind: Bool] = Dictionary(
        uniqueKeysWithValues: CoupleAlertKind.allCases.map { ($0, NotificationPrefs.isEnabled($0)) })

    @State private var reminderOn = ReminderManager.isEnabled
    @State private var streakGuardOn = ReminderManager.isStreakGuardEnabled
    @State private var couponReminderOn = CouponReminder.isEnabled
    @State private var reminderTime: Date = {
        let t = ReminderManager.time
        return Calendar.current.date(bySettingHour: t.hour, minute: t.minute, second: 0, of: Date()) ?? Date()
    }()

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $alertsOn) {
                    Label(L10n.t("notif.master"), systemImage: "bell.and.waves.left.and.right")
                }
                .onChange(of: alertsOn) { _, on in
                    NotificationPrefs.enabled = on
                    if on {
                        Task {
                            let ok = await RemotePushRegistration.requestIfAuthorized()
                            if !ok {
                                alertsOn = false
                                NotificationPrefs.enabled = false
                            }
                        }
                    } else {
                        Task { await appState.unregisterPushDevice() }
                    }
                }

                if alertsOn {
                    Picker(selection: $alertSound) {
                        ForEach(NotificationSound.allCases) { sound in
                            Text("\(sound.emoji) \(sound.displayName)").tag(sound)
                        }
                    } label: {
                        Label(L10n.t("notif.sound"), systemImage: "music.note")
                    }
                    .onChange(of: alertSound) { _, sound in
                        NotificationPrefs.globalSound = sound
                        sound.preview()
                        Task { await ReminderManager.rescheduleIfNeeded() }
                    }
                }
            } footer: {
                Text(L10n.t("notif.masterHint"))
            }

            if alertsOn {
                Section(L10n.t("notif.section")) {
                    ForEach(CoupleAlertKind.allCases) { kind in
                        Toggle(isOn: alertBinding(kind)) {
                            Label(L10n.t(kind.titleKey), systemImage: kind.icon)
                        }
                    }
                }
            }

            Section {
                Toggle(isOn: $reminderOn) {
                    Label(L10n.t("settings.reminder"), systemImage: "bell.badge.fill")
                }
                .onChange(of: reminderOn) { _, on in
                    Task {
                        let ok = await ReminderManager.setEnabled(on)
                        if !ok { reminderOn = false }
                    }
                }
                if reminderOn {
                    DatePicker(L10n.t("settings.reminderTime"),
                               selection: $reminderTime,
                               displayedComponents: .hourAndMinute)
                        .onChange(of: reminderTime) { _, newValue in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                            Task {
                                await ReminderManager.setTime(hour: comps.hour ?? 20,
                                                              minute: comps.minute ?? 0)
                            }
                        }
                }
            } footer: {
                Text(L10n.t("settings.reminderHint"))
            }

            Section {
                Toggle(isOn: $streakGuardOn) {
                    Label(L10n.t("settings.streakGuard"), systemImage: "flame.fill")
                }
                .onChange(of: streakGuardOn) { _, on in
                    Task {
                        let ok = await ReminderManager.setStreakGuardEnabled(on, entry: appState.dailyEntry)
                        if !ok { streakGuardOn = false }
                    }
                }
            } footer: {
                Text(L10n.t("settings.streakGuardHint"))
            }

            Section {
                Toggle(isOn: $couponReminderOn) {
                    Label(L10n.t("settings.couponReminder"), systemImage: "ticket.fill")
                }
                .onChange(of: couponReminderOn) { _, on in
                    Task {
                        var coupons: [Coupon] = []
                        if on, let api = appState.api {
                            coupons = (try? await api.coupons()) ?? []
                        }
                        let ok = await CouponReminder.setEnabled(on, coupons: coupons,
                                                                 myMemberId: appState.memberId)
                        if !ok { couponReminderOn = false }
                    }
                }
            } footer: {
                Text(L10n.t("settings.couponReminderHint"))
            }
        }
        .navigationTitle(L10n.t("notif.section"))
        .navigationBarTitleDisplayMode(.inline)
        .animation(.snappy, value: alertsOn)
        .animation(.snappy, value: reminderOn)
    }

    private func alertBinding(_ kind: CoupleAlertKind) -> Binding<Bool> {
        Binding(
            get: { alertKinds[kind] ?? true },
            set: { on in
                alertKinds[kind] = on
                NotificationPrefs.setEnabled(on, for: kind)
            }
        )
    }
}
