import SwiftUI

/// Mode picker + the settings matrix ("Kreditvertrag", §6.1).
struct ModeSelectView: View {
    @EnvironmentObject var host: HostModel
    @State private var showCustom = false

    var s: Binding<MatchSettings> { $host.settingsDraft }

    var body: some View {
        VStack(spacing: 0) {
            HostTopBar()
            ScrollView {
                VStack(spacing: 22) {
                    Text("WELCHE SHOW HEUTE?").font(.outfit(40, .black)).foregroundStyle(MM.cream).padding(.top, 10)
                    HStack(spacing: 16) {
                        ForEach(Modus.allCases, id: \.self) { m in
                            ModeCard(modus: m, selected: host.settingsDraft.modus == m, minutes: Plan.estimateMinutes(settings: previewSettings(m))) {
                                var fresh = MatchSettings(modus: m)
                                fresh.tempo = host.settingsDraft.tempo
                                fresh.fragienMixKeep(from: host.settingsDraft)
                                host.settingsDraft = fresh
                            }
                        }
                    }
                    .padding(.horizontal, 30)

                    PanelCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Einstellungen").font(.outfit(22, .bold)).foregroundStyle(MM.gold)
                                Spacer()
                                Text("≈ \(Plan.estimateMinutes(settings: host.settingsDraft)) min").font(.poppins(14, .semibold)).foregroundStyle(MM.cream.opacity(0.8))
                            }
                            QuestionSetPicker(sets: host.catalog.questionSetInfos(activePool: host.settingsDraft.kategorienPool, kidSafe: host.settingsDraft.familienModus),
                                              kategorien: host.catalog.categoryInfos(activePool: host.settingsDraft.kategorienPool, kidSafe: host.settingsDraft.familienModus),
                                              pool: host.settingsDraft.kategorienPool, poolInfo: host.poolInfo(host.settingsDraft),
                                              onSet: { host.settingsDraft.applyQuestionSet($0) },
                                              onPool: { host.settingsDraft.apply(patch: ["kategorienPool": .array($0.map { .string($0) })]) })
                            HStack(spacing: 24) {
                                SettingPicker(title: "Tempo", options: Tempo.allCases.map { ($0.rawValue, $0.label) }, selection: Binding(get: { host.settingsDraft.tempo.rawValue }, set: { host.settingsDraft.tempo = Tempo(rawValue: $0) ?? .gemuetlich }))
                                SettingPicker(title: "Fragen-Mix", options: FragenMix.allCases.map { ($0.rawValue, $0.label) }, selection: Binding(get: { host.settingsDraft.fragenMix.rawValue }, set: { host.settingsDraft.fragenMix = FragenMix(rawValue: $0) ?? .locker }))
                                SettingPicker(title: "Teams", options: [("aus", "Einzeln"), ("2er", "2er-Teams"), ("2v2v2v2", "4 Lager")], selection: Binding(get: { host.settingsDraft.teams.rawValue }, set: { host.settingsDraft.teams = TeamModus(rawValue: $0) ?? .aus }))
                            }
                            HStack(spacing: 18) {
                                ToggleChip(title: "Joker", on: s.jokerAn)
                                ToggleChip(title: "Glücksrad", on: s.radAn)
                                ToggleChip(title: "Kategorien-Wahl", on: Binding(get: { host.settingsDraft.kategorienWahl != "aus" }, set: { host.settingsDraft.kategorienWahl = $0 ? "voting" : "aus" }))
                                ToggleChip(title: "v2-Formate", on: s.v2Formate)
                                ToggleChip(title: "Musik", on: s.musik)
                                ToggleChip(title: "Kurze Show", on: s.kurzeShow)
                            }
                            HStack(spacing: 18) {
                                ToggleChip(title: "⏱️ Timer aus (Show-Master löst auf)", on: s.timerAus)
                                SettingPicker(title: "", options: [("0", "Zeit: Auto"), ("15", "15 s"), ("20", "20 s"), ("30", "30 s"), ("60", "60 s"), ("120", "2 min")], selection: Binding(get: { String(host.settingsDraft.fragenZeit ?? 0) }, set: { host.settingsDraft.fragenZeit = (Int($0) ?? 0) <= 0 ? nil : Int($0) }))
                            }
                            HStack(spacing: 18) {
                                ToggleChip(title: "👨‍👩‍👧 Familien-Modus", on: s.familienModus)
                                ToggleChip(title: "🥃 18+ Zinsen & Shots", on: s.alkoholEdition)
                                ToggleChip(title: "All-in erlaubt", on: s.allInErlaubt)
                                ToggleChip(title: "Ohne Game Master (iPad führt)", on: s.gmLos)
                            }
                            DisclosureGroup(isExpanded: $showCustom) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Special Rules").font(.poppins(14, .bold)).foregroundStyle(MM.gold)
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260))], spacing: 10) {
                                        ForEach(SpecialRule.allCases, id: \.self) { rule in
                                            Button {
                                                if host.settingsDraft.specialRules.contains(rule) { host.settingsDraft.specialRules.remove(rule) } else { host.settingsDraft.specialRules.insert(rule) }
                                            } label: {
                                                HStack(alignment: .top, spacing: 10) {
                                                    Text(rule.emoji).font(.system(size: 22))
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(rule.name).font(.poppins(14, .bold))
                                                        Text(rule.description).font(.poppins(11)).opacity(0.8).multilineTextAlignment(.leading)
                                                    }
                                                    Spacer()
                                                    Image(systemName: host.settingsDraft.specialRules.contains(rule) ? "checkmark.circle.fill" : "circle").foregroundStyle(MM.gold)
                                                }
                                                .padding(10).foregroundStyle(MM.cream)
                                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(host.settingsDraft.specialRules.contains(rule) ? 0.45 : 0.2)))
                                            }.buttonStyle(.plain)
                                        }
                                    }
                                    Text("Finale-Faktor").font(.poppins(14, .bold)).foregroundStyle(MM.gold)
                                    SettingPicker(title: "", options: [("1.0", "1,0 streng"), ("1.25", "1,25 Standard"), ("1.5", "1,5 Chaos")], selection: Binding(get: { String(host.settingsDraft.finaleFaktor) }, set: { host.settingsDraft.finaleFaktor = Double($0) ?? 1.25 }))
                                    Text("Deutschland-Anteil: \(Int(host.settingsDraft.deAnteil * 100)) %").font(.poppins(14, .bold)).foregroundStyle(MM.gold)
                                    Slider(value: s.deAnteil, in: 0...1, step: 0.1).tint(MM.gold)
                                    Text("Runden (Custom)").font(.poppins(14, .bold)).foregroundStyle(MM.gold)
                                    SettingPicker(title: "", options: [("0", "Wie im Modus"), ("2", "2"), ("3", "3"), ("4", "4"), ("5", "5"), ("6", "6"), ("8", "8")], selection: Binding(get: { String(host.settingsDraft.rundenOverride ?? 0) }, set: { host.settingsDraft.rundenOverride = (Int($0) ?? 0) <= 0 ? nil : Int($0) }))
                                }.padding(.top, 8)
                            } label: {
                                Text("Custom Game · Special Rules · Finale · Runden").font(.poppins(15, .bold)).foregroundStyle(MM.cream)
                            }.tint(MM.gold)
                        }
                    }
                    .padding(.horizontal, 30)

                    GoldButton(title: "Lobby öffnen — QR-Code zeigen", icon: "qrcode") { host.startShow(settings: host.settingsDraft) }
                        .frame(width: 520).padding(.bottom, 30)
                }
            }
        }
    }

    func previewSettings(_ m: Modus) -> MatchSettings {
        var s = MatchSettings(modus: m)
        s.tempo = host.settingsDraft.tempo
        return s
    }
}

private extension MatchSettings {
    mutating func fragienMixKeep(from other: MatchSettings) {
        fragenMix = other.fragenMix
        familienModus = other.familienModus
        alkoholEdition = other.alkoholEdition
        gmLos = other.gmLos
        musik = other.musik
    }
}

struct ModeCard: View {
    var modus: Modus
    var selected: Bool
    var minutes: Int
    var action: () -> Void

    var emoji: String { modus == .quick ? "⚡" : (modus == .klassik ? "🎬" : "🏃") }
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(emoji).font(.system(size: 40))
                Text(modus.title).font(.outfit(26, .black)).foregroundStyle(selected ? MM.ink : MM.cream)
                Text(modus.subtitle).font(.poppins(13)).foregroundStyle(selected ? MM.ink.opacity(0.8) : MM.cream.opacity(0.8))
                Spacer()
                Text("≈ \(minutes) min").font(.poppins(13, .bold)).foregroundStyle(selected ? MM.ink : MM.gold)
            }
            .padding(18).frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22).fill(selected ? MM.gold : MM.panelDark.opacity(0.9)).overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(selected ? MM.goldDark : MM.gold.opacity(0.3), lineWidth: 2)))
            .shadow(color: .black.opacity(0.35), radius: 14, y: 10)
        }.buttonStyle(PressStyle())
    }
}
