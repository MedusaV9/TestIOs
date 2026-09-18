import SwiftUI

/// iPad-side Show-Master panel (the iPad can direct the show itself):
/// cheat sheet, live answers, the tools and the audio/regie settings.
struct GmPanelView: View {
    @EnvironmentObject var host: HostModel
    @ObservedObject var audio = AudioManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var gm: GmView?
    @State private var scorePlayer: PlayerId = ""
    @State private var scoreDelta = 100
    @State private var scoreReason = "Bester Fehlversuch"
    @State private var whisperText = ""
    @State private var voteQuestion = "Pause machen?"
    @State private var voteOptions = "Ja, Nein"
    @State private var timer: Timer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("🎬 Regiepult").font(.outfit(32, .black)).foregroundStyle(MM.gold)
                    Spacer()
                    if let g = gm { Chip(text: "PIN \(g.gmPin)", gold: true); Chip(text: g.stage.sectionLabel) }
                    GoldButton(title: "Schließen", style: .ghost, compact: true) { dismiss() }
                }
                if let g = gm {
                    HStack(alignment: .top, spacing: 16) {
                        // Cheat sheet
                        PanelCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("🤫 Spickzettel").font(.outfit(18, .bold)).foregroundStyle(MM.gold)
                                if let q = g.spickzettel {
                                    Text(q.text).font(.poppins(15, .bold)).foregroundStyle(MM.cream)
                                    Text("✔ \(q.korrekt)").font(.outfit(22, .black)).foregroundStyle(MM.green)
                                    Text(q.erklaerung).font(.poppins(13)).foregroundStyle(MM.cream.opacity(0.85))
                                    if !q.tipps.isEmpty { Text("Tipps: " + q.tipps.joined(separator: " · ")).font(.poppins(12)).foregroundStyle(MM.cream.opacity(0.7)) }
                                } else { Text("Keine Frage aktiv.").font(.poppins(13)).foregroundStyle(MM.cream.opacity(0.7)) }
                                if !g.regal.isEmpty {
                                    Text("📚 Fragen-Regal").font(.poppins(13, .bold)).foregroundStyle(MM.gold).padding(.top, 6)
                                    ForEach(g.regal, id: \.id) { r in Text("• \(r.text) — \(r.korrekt)").font(.poppins(12)).foregroundStyle(MM.cream.opacity(0.85)).lineLimit(2) }
                                }
                                Text("Antworten live").font(.poppins(13, .bold)).foregroundStyle(MM.gold).padding(.top, 6)
                                ForEach(g.antworten.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                                    Text("\(g.players.first { $0.id == k }?.name ?? k): \(v)").font(.poppins(12)).foregroundStyle(MM.cream)
                                }
                            }
                        }.frame(maxWidth: .infinity)
                        // Tools
                        PanelCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Werkzeuge").font(.outfit(18, .bold)).foregroundStyle(MM.gold)
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    tool("⏳ +15 s (\(g.timerExtensionsLeft))") { host.command(.timerExtend(ms: 15_000)) }
                                    tool("💡 Tipp-Kanone") { host.command(.hintGlobal) }
                                    tool("🎤 Encore (\(g.encoresLeft))") { host.command(.encore) }
                                    tool("🎡 Rad drehen") { host.command(.wheelSpin(rigTarget: nil)) }
                                    tool("🌡️ Stimmung (\(g.moodPollsLeft))") { host.command(.moodPoll) }
                                    tool("📝 Feedback") { host.command(.feedbackCollect) }
                                    tool("🔴 Roter Buzzer") { host.command(.questionMarkBroken(grund: "Frage fehlerhaft", refund: "grantAll")) }
                                    tool("🚪 Notausgang") { host.command(.gameSkip(keepPoints: true)) }
                                    tool("⏭ Opening skippen") { host.command(.flowSkipOpening) }
                                    tool("🔁 Revanche") { host.command(.revanche) }
                                }
                                Group {
                                Divider().overlay(MM.gold.opacity(0.3))
                                Text("🏦 Bananen-Bank / Boost / Pranger / Flüster-Tipp").font(.poppins(13, .bold)).foregroundStyle(MM.gold)
                                Picker("Spieler", selection: $scorePlayer) { ForEach(g.players) { p in Text(p.name).tag(p.id) } }.pickerStyle(.menu).tint(MM.gold)
                                HStack {
                                    Stepper("Betrag: \(scoreDelta)", value: $scoreDelta, in: -2000...2000, step: 50).foregroundStyle(MM.cream)
                                    TextField("Begründung", text: $scoreReason).textFieldStyle(.roundedBorder)
                                }
                                HStack {
                                    tool("Punkte buchen") { if !scorePlayer.isEmpty { host.command(.scoreAdjust(playerId: scorePlayer, delta: scoreDelta, grund: scoreReason)) } }
                                    tool("🐒 Boost ×2") { if !scorePlayer.isEmpty { host.command(.boost(playerId: scorePlayer, art: "x2", grund: scoreReason)) } }
                                    tool("⚖️ Bananen-Steuer") { if !scorePlayer.isEmpty { host.command(.punish(playerId: scorePlayer, strafe: "bananensteuer")) } }
                                    tool("🎁 Joker") { if !scorePlayer.isEmpty { host.command(.jokerGrant(ziel: scorePlayer, jokerId: "bananen-split")) } }
                                }
                                HStack { TextField("Flüster-Tipp", text: $whisperText).textFieldStyle(.roundedBorder); tool("🤫 Flüstern") { if !scorePlayer.isEmpty, !whisperText.isEmpty { host.command(.whisper(playerId: scorePlayer, text: whisperText)); whisperText = "" } } }
                                HStack { TextField("Voting-Frage", text: $voteQuestion).textFieldStyle(.roundedBorder); TextField("Optionen (Komma)", text: $voteOptions).textFieldStyle(.roundedBorder); tool("🗳️ Voting") { host.command(.voteStart(frage: voteQuestion, optionen: voteOptions.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }, dauerMs: 20_000, bindend: false)) } }
                                }
                                Divider().overlay(MM.gold.opacity(0.3))
                                Text("🔊 Soundboard").font(.poppins(13, .bold)).foregroundStyle(MM.gold)
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                                    ForEach([("applaus_gross", "👏"), ("trommelwirbel", "🥁"), ("falsch", "❌"), ("dreiklang_tief", "😮"), ("kaching", "💰"), ("slime", "🦗"), ("muenzregen", "🎊"), ("glitch", "🌑")], id: \.0) { s in
                                        tool(s.1) { host.audio.sfx(s.0) }
                                    }
                                }
                            }
                        }.frame(maxWidth: .infinity)
                        // Status
                        PanelCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Group {
                                Text("Drama-Meter \(g.dramaScore)").font(.outfit(18, .bold)).foregroundStyle(MM.gold)
                                GeometryReader { geo in ZStack(alignment: .leading) { Capsule().fill(Color.black.opacity(0.3)); Capsule().fill(LinearGradient(colors: [MM.blue, MM.gold, MM.red], startPoint: .leading, endPoint: .trailing)).frame(width: geo.size.width * Double(g.dramaScore) / 100) } }.frame(height: 10)
                                Text(g.empfehlung).font(.poppins(12)).foregroundStyle(MM.cream.opacity(0.85))
                                }
                                Group {
                                Text("Regie").font(.poppins(13, .bold)).foregroundStyle(MM.gold).padding(.top, 6)
                                SettingPicker(title: "Tempo", options: Tempo.allCases.map { ($0.rawValue, $0.label) }, selection: Binding(get: { g.settings.tempo.rawValue }, set: { host.command(.settingsSet(["tempo": .string($0)])) }))
                                SettingPicker(title: "Fragen-Mix", options: FragenMix.allCases.map { ($0.rawValue, $0.label) }, selection: Binding(get: { g.settings.fragenMix.rawValue }, set: { host.command(.settingsSet(["fragenMix": .string($0)])) }))
                                ToggleChip(title: "⏱️ Timer aus", on: Binding(get: { g.settings.timerAus }, set: { host.command(.settingsSet(["timerAus": .bool($0)])) }))
                                SettingPicker(title: "Zeit pro Frage", options: [("0", "Auto"), ("15", "15 s"), ("20", "20 s"), ("30", "30 s"), ("60", "60 s"), ("120", "2 min")], selection: Binding(get: { String(g.settings.fragenZeit ?? 0) }, set: { host.command(.settingsSet(["fragenZeit": .number(Double($0) ?? 0)])) }))
                                HStack(spacing: 8) {
                                    ToggleChip(title: "Auto-Regie", on: Binding(get: { g.settings.autoGm }, set: { host.command(.autoGmSet($0)) }))
                                    ToggleChip(title: "Musik", on: Binding(get: { g.settings.musik }, set: { host.command(.settingsSet(["musik": .bool($0)])) }))
                                }
                                HStack(spacing: 8) {
                                    ToggleChip(title: "🃏 Joker", on: Binding(get: { g.settings.jokerAn }, set: { host.command(.settingsSet(["jokerAn": .bool($0)])) }))
                                    ToggleChip(title: "🎡 Rad", on: Binding(get: { g.settings.radAn }, set: { host.command(.settingsSet(["radAn": .bool($0)])) }))
                                    ToggleChip(title: "👨‍👩‍👧 Familie", on: Binding(get: { g.settings.familienModus }, set: { host.command(.settingsSet(["familienModus": .bool($0)])) }))
                                }
                                SettingPicker(title: "Kategorien-Wahl", options: [("voting", "Voting"), ("gm", "Show-Master"), ("aus", "Aus")], selection: Binding(get: { g.settings.kategorienWahl }, set: { host.command(.settingsSet(["kategorienWahl": .string($0)])) }))
                                HStack { Text("Deutschland-Anteil \(Int(g.settings.deAnteil * 100)) %").font(.poppins(12)).foregroundStyle(MM.cream); Slider(value: Binding(get: { g.settings.deAnteil }, set: { host.command(.settingsSet(["deAnteil": .number($0)])) }), in: 0...1, step: 0.1).tint(MM.gold) }
                                HStack { Text("Lautstärke").font(.poppins(12)).foregroundStyle(MM.cream); Slider(value: $audio.volume, in: 0...1).tint(MM.gold) }
                                }
                                QuestionSetPicker(sets: g.fragenSets, kategorien: g.kategorien, pool: g.settings.kategorienPool, poolInfo: g.poolInfo, compact: true,
                                                  onSet: { host.command(.settingsSet(["fragenSet": .string($0)])); refresh() },
                                                  onPool: { host.command(.settingsSet(["kategorienPool": .array($0.map { .string($0) })])); refresh() })
                                    .padding(.top, 6)
                                Text("Spielstand").font(.poppins(13, .bold)).foregroundStyle(MM.gold).padding(.top, 6)
                                HStack { ForEach(1...3, id: \.self) { n in tool("💾 Slot \(n)") { host.writeSlot(n) } } }
                                Text("Aktions-Log").font(.poppins(13, .bold)).foregroundStyle(MM.gold).padding(.top, 6)
                                ForEach(Array(g.log.suffix(14).reversed().enumerated()), id: \.offset) { _, l in Text(l.text).font(.poppins(11)).foregroundStyle(MM.cream.opacity(0.8)).lineLimit(1) }
                            }
                        }.frame(width: 340)
                    }
                }
            }
            .padding(26)
        }
        .background(MM.bg)
        .onAppear { refresh(); timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in refresh() } }
        .onDisappear { timer?.invalidate() }
    }

    func refresh() {
        gm = host.server?.withHub { $0.gmView(now: ServerClock.now()) }
        if scorePlayer.isEmpty, let p = gm?.players.first { scorePlayer = p.id }
    }

    func tool(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.tap(); action() }) {
            Text(title).font(.poppins(13, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                .padding(.horizontal, 10).padding(.vertical, 9).frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 10).fill(MM.panel)).foregroundStyle(MM.cream)
        }.buttonStyle(PressStyle())
    }
}
