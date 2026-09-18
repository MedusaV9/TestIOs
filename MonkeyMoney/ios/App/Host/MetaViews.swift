import SwiftUI

/// Profiles: the iPad is the save store — create, edit, PIN, level, AT, stats.
struct ProfilesView: View {
    @EnvironmentObject var host: HostModel
    @State private var newName = ""
    @State private var newPin = ""
    @State private var newAffe = 0
    @State private var newFarbe = "gelb"
    @State private var selected: Profile?

    var body: some View {
        VStack(spacing: 0) {
            HostTopBar()
            HStack(alignment: .top, spacing: 20) {
                PanelCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("👤 Profile (\(host.meta.profiles.count))").font(.outfit(26, .black)).foregroundStyle(MM.gold)
                        Text("Profile leben auf dem iPad: All-Time-Konto, Level, Shop-Besitz, Statistiken. Handys erkennen ihr Profil per PIN oder Geräte-Token.").font(.poppins(13)).foregroundStyle(MM.cream.opacity(0.8))
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 10) {
                                ForEach(host.meta.profiles.sorted { $0.zuletzt > $1.zuletzt }) { p in
                                    Button { selected = p } label: {
                                        HStack(spacing: 10) {
                                            MonkeyImage(avatar: p.wireAvatar).frame(height: 56)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(p.name).font(.outfit(17, .bold)).foregroundStyle(MM.cream)
                                                Text("Lv \(p.level) · \(Money.formatNumber(p.atAktuell)) AT").font(.poppins(12, .semibold)).foregroundStyle(MM.gold)
                                                Text("\(p.stats.matches) Matches · \(p.stats.siege) Siege\(p.pin != nil ? " · 🔒" : "")").font(.poppins(11)).foregroundStyle(MM.cream.opacity(0.7))
                                            }
                                            Spacer()
                                        }
                                        .padding(10).background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(selected?.id == p.id ? 0.5 : 0.25)).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(selected?.id == p.id ? MM.gold : Color.white.opacity(0.1))))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                        GoldButton(title: "🛍️ AT-Shop", style: .green, compact: true) { host.screen = .shop }
                    }
                }.frame(maxWidth: .infinity)

                VStack(spacing: 16) {
                    if let p = selected.flatMap({ s in host.meta.profile(s.id) }) {
                        PanelCard(highlight: true) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack { MonkeyImage(avatar: p.wireAvatar, face: "jubel").frame(height: 110); VStack(alignment: .leading) { Text(p.name).font(.outfit(30, .black)).foregroundStyle(MM.cream); Text(host.meta.autoTitle(p.id) ?? p.titel ?? Monkeys.monkey(p.avatar.affe).titel).font(.poppins(14, .semibold)).foregroundStyle(MM.gold); Text("Level \(p.level) · \(Money.formatNumber(p.atGesamt)) AT gesamt").font(.poppins(13)).foregroundStyle(MM.cream.opacity(0.8)) } }
                                GeometryReader { geo in ZStack(alignment: .leading) { Capsule().fill(Color.black.opacity(0.3)); Capsule().fill(MM.gold).frame(width: geo.size.width * Level.progress(forAT: p.atGesamt)) } }.frame(height: 8)
                                Text("Konto: \(Money.formatNumber(p.atAktuell)) AT · Bananen-Pass Stufe \(Quests.passStep(xp: p.passXp)) (\(p.passXp) XP)").font(.poppins(13, .semibold)).foregroundStyle(MM.cream)
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                                    stat("Quote", "\(Int(p.stats.quote * 100)) %"); stat("Matches / Siege", "\(p.stats.matches) / \(p.stats.siege)")
                                    stat("Schnellster Buzz", p.stats.schnellsteMs.map { String(format: "%.1f s", Double($0) / 1000) } ?? "—"); stat("Höchster Endstand", Money.format(p.stats.hoechsterEndstand))
                                    stat("Längste Serie", "\(p.stats.laengsteSerie)"); stat("Comebacks", "\(p.stats.comebacks)")
                                    stat("Wetten", "\(p.stats.wettenGewonnen) : \(p.stats.wettenVerloren)"); stat("Klau-Bilanz", "\(p.stats.gestohlen) / \(p.stats.bestohlen)")
                                    stat("Brettspiele", "\(p.stats.brettspiele) (\(p.stats.brettspielSiege) Siege)"); stat("Items", "\(p.besitz.count) / \(Shop.items.count)")
                                }
                                if !p.meilensteine.isEmpty { Text("Meilensteine: " + p.meilensteine.joined(separator: ", ")).font(.poppins(12)).foregroundStyle(MM.gold) }
                                HStack {
                                    GoldButton(title: p.pin == nil ? "PIN setzen" : "PIN entfernen", style: .ghost, compact: true) {
                                        var m = host.meta
                                        m.update(p.id, name: nil, avatar: nil, pin: .some(p.pin == nil ? String(format: "%04d", Int.random(in: 0...9999)) : nil))
                                        host.persistMeta(m)
                                        if let np = m.profile(p.id)?.pin { host.toast = "Neue PIN: \(np)" }
                                    }
                                    GoldButton(title: "Löschen", style: .red, compact: true) { var m = host.meta; m.profiles.removeAll { $0.id == p.id }; host.persistMeta(m); selected = nil }
                                }
                            }
                        }
                    }
                    PanelCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("✨ Neues Profil").font(.outfit(22, .bold)).foregroundStyle(MM.gold)
                            TextField("Name", text: $newName).textFieldStyle(.roundedBorder)
                            TextField("Optionale 4-stellige PIN", text: $newPin).textFieldStyle(.roundedBorder).keyboardType(.numberPad)
                            HStack { Button("‹") { newAffe = (newAffe + 13) % 14 }.buttonStyle(.bordered).tint(MM.gold); MonkeyImage(avatar: Avatar(affe: Monkeys.all[newAffe].id, farbe: newFarbe)).frame(height: 110); Button("›") { newAffe = (newAffe + 1) % 14 }.buttonStyle(.bordered).tint(MM.gold); Text(Monkeys.all[newAffe].name).font(.outfit(16, .bold)).foregroundStyle(MM.cream) }
                            HStack { ForEach(Monkeys.colors, id: \.id) { c in Circle().fill(Color(hex: c.hex)).frame(width: 30, height: 30).overlay(Circle().strokeBorder(.white, lineWidth: newFarbe == c.id ? 3 : 0)).onTapGesture { newFarbe = c.id } } }
                            GoldButton(title: "Profil anlegen (+300 AT Willkommen)", compact: true) {
                                guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                                var m = host.meta
                                var rng = SeededRandom(seed: UInt32(truncatingIfNeeded: Int(Date().timeIntervalSince1970)))
                                _ = m.create(name: newName, avatar: Avatar(affe: Monkeys.all[newAffe].id, farbe: newFarbe), pin: newPin.count == 4 ? newPin : nil, deviceToken: nil, now: Int(Date().timeIntervalSince1970 * 1000), rng: &rng)
                                host.persistMeta(m)
                                newName = ""; newPin = ""
                            }
                        }
                    }
                }.frame(width: 420)
            }
            .padding(24)
        }
    }

    func stat(_ k: String, _ v: String) -> some View {
        HStack { Text(k).font(.poppins(12)).foregroundStyle(MM.cream.opacity(0.75)); Spacer(); Text(v).font(.poppins(12, .bold)).foregroundStyle(MM.cream) }
    }
}

/// AT shop: 85 cosmetics with rarity, level gates and “what is what” card.
struct ShopView: View {
    @EnvironmentObject var host: HostModel
    @State private var profileId: String = ""
    @State private var slot: String = "alle"
    @State private var message: String?

    var profile: Profile? { host.meta.profile(profileId) }

    var body: some View {
        VStack(spacing: 0) {
            HostTopBar()
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("🛍️ AT-SHOP").font(.outfit(34, .black)).foregroundStyle(MM.gold)
                    Picker("Profil", selection: $profileId) { Text("Profil wählen …").tag(""); ForEach(host.meta.profiles) { p in Text("\(p.name) · \(Money.formatNumber(p.atAktuell)) AT").tag(p.id) } }.pickerStyle(.menu).tint(MM.gold)
                    if let p = profile { HStack { MonkeyImage(avatar: p.wireAvatar).frame(height: 90); VStack(alignment: .leading) { Text(p.name).font(.outfit(20, .bold)); Text("\(Money.formatNumber(p.atAktuell)) AT · Level \(p.level)").font(.poppins(13, .semibold)).foregroundStyle(MM.gold) }.foregroundStyle(MM.cream) } }
                    PanelCard(padding: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Was ist was?").font(.outfit(16, .bold)).foregroundStyle(MM.gold)
                            Text("🍌 MM = Abend-Spielgeld · 🏆 AT = Dauer-Konto (Endstand/10, Sieger ×1,5) · 📈 Level sinkt nie · 🎫 Pass & Quests geben Bonus-AT. Kein Item verändert Punkte oder Fragen.").font(.poppins(12)).foregroundStyle(MM.cream.opacity(0.85))
                        }
                    }
                    if let m = message { Text(m).font(.poppins(13, .bold)).foregroundStyle(MM.gold) }
                    ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(["alle"] + Shop.slots, id: \.self) { s in Button { slot = s } label: { Text(s == "alle" ? "Alle" : (Shop.slotNames[s] ?? s)).font(.poppins(12, .semibold)).padding(.horizontal, 10).padding(.vertical, 6).background(Capsule().fill(slot == s ? MM.gold : Color.black.opacity(0.3))).foregroundStyle(slot == s ? MM.ink : MM.cream) }.buttonStyle(.plain) } } }
                }.frame(width: 340)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210))], spacing: 12) {
                        ForEach(Shop.items.filter { slot == "alle" || $0.slot == slot }) { item in
                            let owned = profile?.besitz.contains(item.id) ?? false
                            let equipped = profile?.ausgeruestet[item.slot] == item.id
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { Text(item.emoji).font(.system(size: 30)); Spacer(); Text(item.seltenheit.capitalized).font(.poppins(10, .bold)).padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(rarityColor(item.seltenheit))).foregroundStyle(MM.ink) }
                                Text(item.name).font(.outfit(15, .bold)).foregroundStyle(MM.cream).lineLimit(2)
                                Text(item.beschreibung).font(.poppins(11)).foregroundStyle(MM.cream.opacity(0.75)).lineLimit(2)
                                Spacer(minLength: 0)
                                HStack {
                                    Text("\(Money.formatNumber(item.preis)) AT").font(.outfit(15, .black)).foregroundStyle(MM.gold)
                                    Text(item.preisInAbenden).font(.poppins(10)).foregroundStyle(MM.cream.opacity(0.6))
                                    if let lvl = item.minLevel { Text("Lv \(lvl)+").font(.poppins(10, .bold)).foregroundStyle(MM.orange) }
                                }
                                if owned {
                                    GoldButton(title: equipped ? "Angelegt ✓" : "Anlegen", style: equipped ? .green : .ghost, compact: true) {
                                        var m = host.meta; m.equip(profileId, item: equipped ? nil : item.id, slot: item.slot); host.persistMeta(m)
                                    }
                                } else {
                                    GoldButton(title: "Kaufen", compact: true) {
                                        guard !profileId.isEmpty else { message = "Bitte oben ein Profil wählen."; return }
                                        var m = host.meta
                                        switch m.buy(profileId, item: item.id) {
                                        case .success: host.persistMeta(m); message = "🍌 \(item.name) geschält & angelegt!"; host.audio.sfx("kaching")
                                        case .failure(let e): message = e == .tooExpensive ? "Nicht genug AT — Preis \(item.preis)." : "\(e)"
                                        }
                                    }
                                }
                            }
                            .padding(12).frame(height: 190)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(owned ? 0.45 : 0.25)).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(equipped ? MM.gold : Color.white.opacity(0.1), lineWidth: equipped ? 2 : 1)))
                        }
                    }
                }
            }
            .padding(24)
        }
        .onAppear { if profileId.isEmpty, let p = host.meta.profiles.first { profileId = p.id } }
    }

    func rarityColor(_ s: String) -> Color {
        switch s { case "reif": return MM.gold; case "gold": return MM.orange; case "diamant": return Color(hex: "#9BE7FF"); default: return MM.green }
    }
}

/// The four leaderboards with thresholds.
struct BoardsView: View {
    @EnvironmentObject var host: HostModel
    var body: some View {
        let b = host.meta.boards()
        VStack(spacing: 0) {
            HostTopBar()
            Text("🏆 BESTENLISTEN").font(.outfit(40, .black)).foregroundStyle(MM.gold).padding(.top, 10)
            HStack(alignment: .top, spacing: 16) {
                board("💰 Money-Boss", "Lifetime-AT", b.moneyBoss)
                board("⚡ Blitz-Buzzer", "Median-Antwortzeit · ab 30 Antworten", b.blitzBuzzer)
                board("🚀 Comeback-König", "Siege ohne Führung vor dem Finale · ab 5 Matches", b.comebackKoenig)
                PanelCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("📚 Kategorie-Meister").font(.outfit(20, .bold)).foregroundStyle(MM.gold)
                        Text("Beste Quote je Kategorie · ab 20 Antworten").font(.poppins(11)).foregroundStyle(MM.cream.opacity(0.7))
                        if b.kategorieMeister.isEmpty { Text("Noch keine Meister — spielt weiter!").font(.poppins(13)).foregroundStyle(MM.cream.opacity(0.8)) }
                        ForEach(b.kategorieMeister.keys.sorted(), id: \.self) { k in
                            if let top = b.kategorieMeister[k]?.first { HStack { Text(host.catalog.categoryEmoji(k)); Text(host.catalog.categoryName(k)).font(.poppins(12, .bold)); Spacer(); Text("\(top.name) \(top.anzeige)").font(.poppins(12)) }.foregroundStyle(MM.cream) }
                        }
                    }
                }.frame(maxWidth: .infinity)
            }
            .padding(24)
            Spacer()
        }
    }

    func board(_ title: String, _ sub: String, _ entries: [BoardEntry]) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.outfit(20, .bold)).foregroundStyle(MM.gold)
                Text(sub).font(.poppins(11)).foregroundStyle(MM.cream.opacity(0.7))
                if entries.isEmpty { Text("Noch leer — die Schwelle ist transparent: spielt weiter!").font(.poppins(13)).foregroundStyle(MM.cream.opacity(0.8)) }
                ForEach(Array(entries.enumerated()), id: \.element.profileId) { i, e in
                    HStack { Text("\(i + 1)").font(.outfit(18, .black)).foregroundStyle(i == 0 ? MM.gold : MM.cream).frame(width: 26); MonkeyImage(avatar: Avatar(wire: e.avatar)).frame(height: 36); Text(e.name).font(.poppins(14, .bold)); Spacer(); Text(e.anzeige).font(.poppins(13, .semibold)).foregroundStyle(MM.gold) }.foregroundStyle(MM.cream)
                }
            }
        }.frame(maxWidth: .infinity)
    }
}

/// App settings (audio, network info, danger zone).
struct HostSettingsView: View {
    @EnvironmentObject var host: HostModel
    @ObservedObject var audio = AudioManager.shared
    var body: some View {
        VStack(spacing: 0) {
            HostTopBar()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("⚙️ EINSTELLUNGEN").font(.outfit(36, .black)).foregroundStyle(MM.gold)
                    PanelCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Audio").font(.outfit(20, .bold)).foregroundStyle(MM.gold)
                            Toggle("Musik", isOn: $audio.musicEnabled).tint(MM.gold).foregroundStyle(MM.cream)
                            Toggle("Soundeffekte", isOn: $audio.sfxEnabled).tint(MM.gold).foregroundStyle(MM.cream)
                            HStack { Text("Lautstärke").foregroundStyle(MM.cream); Slider(value: $audio.volume, in: 0...1).tint(MM.gold) }
                            Text("Soundtrack: 22 Tracks generiert mit Sonauto/Treblo v3 · SFX CC0 (BigSoundBank, Kenney) · Song-Snippets CC BY (Kevin MacLeod, archive.org)").font(.poppins(11)).foregroundStyle(MM.cream.opacity(0.7))
                        }
                    }
                    PanelCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Netzwerk").font(.outfit(20, .bold)).foregroundStyle(MM.gold)
                            Text("iPad-Adresse: http://\(host.lanIP):\(host.port) — Handys müssen im selben WLAN sein. Kein Internet nötig.").font(.poppins(13)).foregroundStyle(MM.cream)
                            Text("Beitritt: QR-Code scannen → Safari öffnet den Spieler direkt im Browser, nichts zu installieren. Mit installierter Monkey-Money-App auf dem iPhone kann der Link auch in der App geöffnet werden (monkeymoney://).").font(.poppins(12)).foregroundStyle(MM.cream.opacity(0.8))
                        }
                    }
                    PanelCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Inhalt").font(.outfit(20, .bold)).foregroundStyle(MM.gold)
                            Text("\(host.catalog.questions.count.formatted()) Fragen in \(host.catalog.categories.count) Kategorien · \(host.catalog.songs.count) Songs · 27 Minispiel-Formate · 6 Brettspiele").font(.poppins(13)).foregroundStyle(MM.cream)
                            HStack { ForEach(Difficulty.allCases, id: \.self) { d in Chip(text: "\(d.label): \(host.catalog.questions.filter { $0.schw == d }.count)") } }
                        }
                    }
                    PanelCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Gefahrenzone").font(.outfit(20, .bold)).foregroundStyle(MM.red)
                            HStack {
                                GoldButton(title: "Alle Spielstände löschen", style: .red, compact: true) { for i in 0...3 { host.deleteSlot(i) } }
                                GoldButton(title: "Alle Profile löschen", style: .red, compact: true) { host.persistMeta(MetaStore()) }
                            }
                        }
                    }
                }.padding(24)
            }
        }
    }
}

/// Save slots (1 autosave + 3 manual).
struct SavesView: View {
    @EnvironmentObject var host: HostModel
    var body: some View {
        VStack(spacing: 0) {
            HostTopBar()
            Text("💾 SPIELSTÄNDE").font(.outfit(36, .black)).foregroundStyle(MM.gold).padding(.top, 10)
            VStack(spacing: 12) {
                slotRow(host.autosaveAvailable ?? host.readSlot(0), n: 0)
                ForEach(0..<3, id: \.self) { i in slotRow(host.slots[i], n: i + 1) }
            }.padding(24)
            Spacer()
        }
    }

    func slotRow(_ slot: HostModel.SaveSlot?, n: Int) -> some View {
        PanelCard(padding: 14) {
            HStack {
                Text(n == 0 ? "Autosave" : "Slot \(n)").font(.outfit(18, .bold)).foregroundStyle(MM.gold).frame(width: 110, alignment: .leading)
                if let s = slot {
                    VStack(alignment: .leading) { Text(s.label).font(.poppins(14, .bold)); Text(Date(timeIntervalSince1970: Double(s.savedAt) / 1000).formatted(date: .abbreviated, time: .shortened)).font(.poppins(12)).opacity(0.7) }.foregroundStyle(MM.cream)
                    HStack(spacing: -8) { ForEach(s.state.players.prefix(6)) { p in MonkeyImage(avatar: p.avatar).frame(height: 40) } }
                    Spacer()
                    GoldButton(title: "Laden", compact: true) { host.loadSlotAndStart(s) }
                    GoldButton(title: "Löschen", style: .red, compact: true) { host.deleteSlot(n) }
                } else {
                    Text("— leer —").font(.poppins(13)).foregroundStyle(MM.cream.opacity(0.6))
                    Spacer()
                    if n > 0, host.server != nil { GoldButton(title: "Aktuelles Spiel speichern", style: .ghost, compact: true) { host.writeSlot(n) } }
                }
            }
        }
    }
}

struct HowToView: View {
    @EnvironmentObject var host: HostModel
    let steps: [(String, String, String)] = [
        ("📺", "Das iPad ist die Bühne", "Es zeigt Fragen, Rad, Podium — und ist gleichzeitig der Server. Kein PC, keine Cloud, kein Internet nötig."),
        ("📱", "Handys scannen den QR-Code", "Safari öffnet den Spieler sofort. Wer die Monkey-Money-App hat, kann den Link auch in der App öffnen. Name + Affe wählen, „Rein da!“."),
        ("🎬", "Show-Master (optional)", "Der Code für das Regiepult lässt sich in der Lobby ein- und ausblenden. Das Handy des Show-Masters zeigt Spickzettel, Antworten und 17 Werkzeuge. Ohne Show-Master führt das iPad."),
        ("🍌", "Money ist Punktestand UND Ressource", "Joker kaufen, Einsätze setzen, klauen — alle Beträge in 50er-Scheinen. Dispo-Limit −500, vor dem Finale Schuldenerlass."),
        ("🎡", "Glücksrad zwischen den Runden", "15 Segmente mit Gewichten, Pech-Schutz und Pity-Timer. In den letzten zwei Runden nur der faire Pool."),
        ("🐊", "Lianen-Finale mit Aufhol-Formel", "W_final = max(500, 1,25 × Abstand / Fragen). Der Letzte kann noch gewinnen — wenn er perfekt spielt."),
        ("🎲", "Spiele-Abend", "Werwolf, UNO, Mensch-ärgere-dich-nicht, Bananopoly, Affenturm und Siedler — mit Handys oder gemischt mit iPad-Sitzen."),
        ("🏆", "Profile, Shop, Bestenlisten", "Match-Money wird zu All-Time-Money (÷10, Sieger ×1,5). 85 Kosmetik-Items, Level, Bananen-Pass und Quests — alles lokal auf dem iPad."),
    ]
    var body: some View {
        VStack(spacing: 0) {
            HostTopBar()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("SO FUNKTIONIERT'S").font(.outfit(40, .black)).foregroundStyle(MM.gold)
                    ForEach(Array(steps.enumerated()), id: \.offset) { _, s in
                        HStack(alignment: .top, spacing: 16) {
                            Text(s.0).font(.system(size: 40))
                            VStack(alignment: .leading, spacing: 4) { Text(s.1).font(.outfit(20, .bold)).foregroundStyle(MM.cream); Text(s.2).font(.poppins(14)).foregroundStyle(MM.cream.opacity(0.85)) }
                        }.padding(14).background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.28)))
                    }
                }.padding(24)
            }
        }
    }
}
