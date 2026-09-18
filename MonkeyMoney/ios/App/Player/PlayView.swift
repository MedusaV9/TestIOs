import SwiftUI

/// The phone controller: header (avatar, name, balance), joker bar and the
/// declarative prompt renderer — one view per PlayerPrompt kind.
struct PlayView: View {
    @EnvironmentObject var player: PlayerModel

    var body: some View {
        if let v = player.view {
            VStack(spacing: 10) {
                header(v)
                if !v.jokers.isEmpty { jokerBar(v) }
                ScrollView {
                    PromptView(prompt: v.prompt, whisper: v.whisper, streak: v.me.streak) { player.act($0) }
                        .padding(.bottom, 20)
                        .id(v.prompt.kind + String(v.phase.rawValue))
                        .transition(.opacity)
                    if [.zwischenstand, .halbzeit, .siegerehrung, .ende, .pause].contains(v.phase) { ranking(v) }
                }
                .animation(.easeInOut(duration: 0.25), value: v.prompt.kind)
                HStack {
                    Text(v.sectionLabel).font(.poppins(10, .semibold)).foregroundStyle(MM.cream.opacity(0.6))
                    Spacer()
                    Button("Verlassen") { player.send(.leave); player.disconnect() }.font(.poppins(11, .semibold)).foregroundStyle(MM.cream.opacity(0.5))
                }
            }
            .padding(.horizontal, 14).padding(.top, 8)
            .overlay { if let f = v.flash { FlashOverlay(kind: f).id(v.me.id + f + String(v.phaseEndsAt ?? 0)) } }
        } else {
            VStack(spacing: 12) { ProgressView().tint(MM.gold); Text("Verbinde mit dem iPad …").font(.poppins(15, .semibold)).foregroundStyle(MM.cream); GoldButton(title: "Abbrechen", style: .ghost, compact: true) { player.disconnect() } }
        }
    }

    func header(_ v: PlayerView) -> some View {
        HStack(spacing: 12) {
            MonkeyImage(avatar: Avatar(wire: v.me.avatar), face: v.me.streak >= 3 ? "jubel" : "neutral").frame(height: 66)
            VStack(alignment: .leading, spacing: 2) {
                Text(v.me.name).font(.outfit(18, .black)).foregroundStyle(MM.cream)
                Text(v.statusText + (v.rueckenwind > 1 ? " · 🌬️ ×\(String(format: "%.2g", v.rueckenwind))" : "")).font(.poppins(11)).foregroundStyle(MM.cream.opacity(0.8)).lineLimit(1)
                if v.me.streak >= 3 { Text("🔥 Streak \(v.me.streak) (×\(v.me.streak >= 5 ? "2" : "1,5"))").font(.poppins(11, .bold)).foregroundStyle(MM.orange) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(Money.format(v.me.balance)).font(.outfit(24, .black)).foregroundStyle(MM.gold).contentTransition(.numericText())
                Text("Platz \(v.me.platz)").font(.poppins(11, .semibold)).foregroundStyle(MM.cream.opacity(0.7))
            }
        }
        .padding(12).background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.3)).overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(MM.gold.opacity(0.25))))
    }

    func jokerBar(_ v: PlayerView) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(v.jokers) { j in
                    Button {
                        if j.id == "schmiergeld" { player.act(.joker(id: j.id, stufe: 1)) } else { player.act(.joker(id: j.id, stufe: nil)) }
                    } label: {
                        VStack(spacing: 2) {
                            Text(j.emoji).font(.system(size: 22))
                            Text(j.name).font(.poppins(10, .bold)).lineLimit(1)
                            Text(j.ladungen > 0 ? "\(j.ladungen)× frei" : (j.preis > 0 ? Money.format(j.preis) : "gratis")).font(.poppins(10, .semibold)).foregroundStyle(MM.gold)
                        }
                        .frame(width: 92).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.3)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(MM.gold.opacity(0.3))))
                        .foregroundStyle(MM.cream)
                    }
                    .disabled(!j.nutzbar).opacity(j.nutzbar ? 1 : 0.4)
                    .contextMenu { if j.id == "schmiergeld" { Button("Stufe 2: Hinweis (35 %)") { player.act(.joker(id: j.id, stufe: 2)) } } }
                }
            }
        }
    }

    func ranking(_ v: PlayerView) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Zwischenstand").font(.outfit(16, .bold)).foregroundStyle(MM.gold)
            ForEach(v.ranking) { r in
                HStack { Text("\(r.platz). \(r.name)\(r.id == v.me.id ? " (du)" : "")").font(.poppins(13, .semibold)); Spacer(); Text(Money.format(r.balance)).font(.outfit(14, .black)).foregroundStyle(MM.gold) }.foregroundStyle(MM.cream)
            }
        }.padding(14).background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.3)))
    }
}

struct FlashOverlay: View {
    var kind: String
    @State private var opacity = 0.7
    var body: some View {
        RadialGradient(colors: [(kind == "richtig" ? MM.green : MM.red).opacity(opacity), .clear], center: .center, startRadius: 0, endRadius: 500)
            .ignoresSafeArea().allowsHitTesting(false)
            .onAppear { withAnimation(.easeOut(duration: 0.9)) { opacity = 0 } }
    }
}

/// Renders every PlayerPrompt kind natively (mirrors player.js).
struct PromptView: View {
    var prompt: PlayerPrompt
    var whisper: String?
    var streak: Int
    var send: (PlayerAction) -> Void

    @State private var number: Double = 0
    @State private var wager: Int = 0
    @State private var order: [Int] = []
    @State private var chips: [Int] = []
    @State private var text = ""
    @State private var taps = 0
    @State private var pendingTaps = 0
    @State private var feedback: [String] = ["", "", ""]

    var body: some View {
        VStack(spacing: 12) {
            if let w = whisper { Text(w).font(.poppins(14, .semibold)).foregroundStyle(MM.cream).padding(12).frame(maxWidth: .infinity).background(RoundedRectangle(cornerRadius: 12).fill(MM.lila.opacity(0.25)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(MM.lila, style: StrokeStyle(lineWidth: 1, dash: [5])))) }
            switch prompt {
            case .idle(let title, let subtitle):
                idle(title, subtitle)
            case .choice(let q, let options, let chosen, let deadline, let secondTry, let hint):
                timer(deadline)
                if let h = hint { hintView(h) }
                question(q)
                optionList(options, chosen: chosen, locked: chosen != nil && !secondTry) { send(.choose($0)) }
                if secondTry { hintView("↩️ Rückgaberecht: wähle eine andere Antwort (50 % Gewinn)") }
            case .multiChoice(let q, let options, let chosen, let required, let locked, let deadline):
                timer(deadline); question(q)
                Text("\(chosen.count)/\(required) gewählt").font(.poppins(12, .semibold)).foregroundStyle(MM.gold)
                optionList(options, chosen: nil, locked: locked, multi: Set(chosen)) { id in var s = Set(chosen); if s.contains(id) { s.remove(id) } else { s.insert(id) }; send(.multiChoose(Array(s))) }
            case .reveal(let title, let correct, let delta, let detail, let st, _):
                VStack(spacing: 12) {
                    StampView(text: title, color: correct == true ? MM.green : (correct == false ? MM.red : MM.gold)).padding(.top, 20)
                    Text(Money.formatDelta(delta)).font(.outfit(48, .black)).foregroundStyle(delta < 0 ? MM.red : MM.gold).contentTransition(.numericText())
                    if st >= 3 { Text("🔥 Streak \(st)").font(.poppins(14, .bold)).foregroundStyle(MM.orange) }
                    if let d = detail { Text(d).font(.poppins(14)).foregroundStyle(MM.cream.opacity(0.85)).multilineTextAlignment(.center) }
                }.frame(maxWidth: .infinity).padding(.vertical, 20)
                if correct == true { Burst() }
            case .buzzer(let q, let armed, let pressed, _, let hint):
                if let q = q { question(q) }
                Button { send(.buzz(at: ServerClock.now())) } label: {
                    Text(pressed ? "GEBUZZERT!" : (armed ? "BUZZ!" : "…")).font(.outfit(40, .black)).foregroundStyle(armed ? MM.ink : MM.cream.opacity(0.5))
                        .frame(width: 280, height: 280)
                        .background(Circle().fill(armed ? RadialGradient(colors: [Color(hex: "#FFE58A"), MM.gold, MM.goldDark], center: UnitPoint(x: 0.5, y: 0.35), startRadius: 0, endRadius: 200) : RadialGradient(colors: [.gray, Color(hex: "#444")], center: .center, startRadius: 0, endRadius: 200)))
                        .shadow(color: armed ? MM.goldDark : .black, radius: 0, y: 14).shadow(color: .black.opacity(0.5), radius: 24, y: 20)
                }.buttonStyle(PressStyle()).disabled(!armed).frame(maxWidth: .infinity).padding(.vertical, 20)
                if let h = hint { hintView(h) }
            case .number(let q, let lo, let hi, let step, _, let unit, let current, let locked, let deadline):
                timer(deadline); question(q)
                VStack(spacing: 8) {
                    Text(fmtNum(current ?? number)).font(.outfit(46, .black)).foregroundStyle(MM.gold).contentTransition(.numericText())
                    Text(unit).font(.poppins(13)).foregroundStyle(MM.cream.opacity(0.8))
                    Slider(value: $number, in: lo...hi, step: max(step, 0.0001)).tint(MM.gold).disabled(locked)
                    HStack(spacing: 10) {
                        ForEach([(-10.0, "−−"), (-1.0, "−"), (1.0, "+"), (10.0, "++")], id: \.1) { m in
                            Button(m.1) { number = min(hi, max(lo, number + m.0 * step)) }.font(.outfit(22, .black)).foregroundStyle(MM.gold).frame(width: 64, height: 50).background(RoundedRectangle(cornerRadius: 14).fill(MM.panelDark)).disabled(locked)
                        }
                    }
                    GoldButton(title: locked ? "EINGELOGGT ✔" : "EINLOGGEN") { send(.number(number)) }.disabled(locked)
                }.onAppear { number = current ?? (lo + hi) / 2 }
            case .order(let q, let items, let serverOrder, let locked, let deadline):
                timer(deadline); question(q)
                VStack(spacing: 8) {
                    ForEach(Array((order.isEmpty ? serverOrder : order).enumerated()), id: \.offset) { pos, id in
                        HStack(spacing: 10) {
                            Text("\(pos + 1)").font(.outfit(16, .black)).foregroundStyle(MM.ink).frame(width: 30, height: 30).background(Circle().fill(MM.gold))
                            Text(items.first { $0.id == id }?.text ?? "").font(.poppins(15, .bold)).foregroundStyle(MM.cream)
                            Spacer()
                            Button { move(pos, -1, serverOrder) } label: { Image(systemName: "chevron.up") }.disabled(pos == 0 || locked)
                            Button { move(pos, 1, serverOrder) } label: { Image(systemName: "chevron.down") }.disabled(pos == items.count - 1 || locked)
                        }
                        .foregroundStyle(MM.cream).padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.3)))
                    }
                    GoldButton(title: locked ? "EINGELOGGT ✔" : "EINLOGGEN") { send(.order(order.isEmpty ? serverOrder : order)); send(.confirm) }.disabled(locked)
                }.onAppear { if order.isEmpty { order = serverOrder } }
            case .wager(let title, let subtitle, let lo, let hi, let step, let current, let locked, let deadline):
                timer(deadline); question(title)
                if let s = subtitle { Text(s).font(.poppins(13)).foregroundStyle(MM.cream.opacity(0.8)) }
                VStack(spacing: 8) {
                    Text(Money.format(current ?? wager)).font(.outfit(46, .black)).foregroundStyle(MM.gold).contentTransition(.numericText())
                    Slider(value: Binding(get: { Double(wager) }, set: { wager = Int($0) / max(1, step) * max(1, step) }), in: Double(lo)...Double(max(lo, hi)), step: Double(max(1, step))).tint(MM.gold).disabled(locked)
                    HStack { Button("−") { wager = max(lo, wager - step) }.font(.outfit(24, .black)); Button("+") { wager = min(hi, wager + step) }.font(.outfit(24, .black)) }.foregroundStyle(MM.gold)
                    GoldButton(title: locked ? "EINGELOGGT ✔" : "EINSATZ SETZEN") { send(.wager(wager)) }.disabled(locked)
                }.onAppear { wager = current ?? lo }
            case .text(let q, let placeholder, let maxLength, let submitted, let deadline):
                timer(deadline); question(q)
                TextField(placeholder, text: $text).textFieldStyle(.plain).font(.poppins(18, .semibold)).foregroundStyle(MM.cream).padding(14).background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.3))).disabled(submitted != nil)
                    .onChange(of: text) { _, v in if v.count > maxLength { text = String(v.prefix(maxLength)) } }
                GoldButton(title: submitted != nil ? "ABGESCHICKT ✔" : "ABSCHICKEN") { if !text.isEmpty { send(.text(text)) } }.disabled(submitted != nil)
            case .tapFrenzy(let title, _, let deadline, let active):
                timer(deadline); question(title)
                Text("\(taps)").font(.outfit(44, .black)).foregroundStyle(MM.gold)
                Button { taps += 1; pendingTaps += 1 } label: { Text("🥥").font(.system(size: 80)).frame(width: 260, height: 260).background(RoundedRectangle(cornerRadius: 40).fill(MM.wood)) }.buttonStyle(PressStyle()).disabled(!active)
                    .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in if pendingTaps > 0 { send(.taps(pendingTaps)); pendingTaps = 0 } }
            case .chips(let q, let options, let total, let placed, let locked, let deadline):
                timer(deadline); question(q)
                let used = (chips.isEmpty ? placed : chips).reduce(0, +)
                Text("\(total - used) Chips übrig").font(.poppins(14, .bold)).foregroundStyle(MM.gold)
                ForEach(Array(options.enumerated()), id: \.element.id) { i, o in
                    HStack {
                        Text(o.text).font(.poppins(14, .bold)).foregroundStyle(MM.cream); Spacer()
                        Button("−") { if chips.isEmpty { chips = placed }; chips[i] = max(0, chips[i] - 1) }.frame(width: 44, height: 44).background(RoundedRectangle(cornerRadius: 10).fill(MM.panel)).disabled(locked)
                        Text("\((chips.isEmpty ? placed : chips)[i])").font(.outfit(22, .black)).foregroundStyle(MM.gold).frame(width: 36)
                        Button("+") { if chips.isEmpty { chips = placed }; if chips.reduce(0, +) < total { chips[i] += 1 } }.frame(width: 44, height: 44).background(RoundedRectangle(cornerRadius: 10).fill(MM.panel)).disabled(locked)
                    }.foregroundStyle(MM.cream).font(.outfit(20, .black)).padding(10).background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.3)))
                }
                GoldButton(title: locked ? "GESETZT ✔" : "SETZEN") { send(.chips(chips.isEmpty ? placed : chips)); send(.confirm) }.disabled(locked || used != total)
            case .pickPlayer(let title, let subtitle, let candidates, let chosen, let deadline):
                timer(deadline); question(title)
                if let s = subtitle { Text(s).font(.poppins(13)).foregroundStyle(MM.cream.opacity(0.8)).multilineTextAlignment(.center) }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(candidates) { c in
                        Button { send(.pickPlayer(c.id)) } label: {
                            HStack { MonkeyImage(avatar: Avatar(wire: c.avatar)).frame(height: 44); VStack(alignment: .leading) { Text(c.name).font(.poppins(14, .bold)); Text(Money.format(c.balance)).font(.poppins(11)).opacity(0.7) }; Spacer() }
                                .padding(10).foregroundStyle(MM.cream).background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.3)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(chosen == c.id ? MM.gold : Color.white.opacity(0.1), lineWidth: 2)))
                        }.buttonStyle(PressStyle())
                    }
                }
            case .bank(let q, let options, let chosen, let pot, let banked, let deadline):
                timer(deadline)
                HStack { Chip(text: "Pott: \(Money.format(pot))", gold: true); Chip(text: "Gesichert: \(Money.format(banked))") }
                Button { send(.bank) } label: {
                    Text("🏦 BANK! \(Money.format(pot))").font(.outfit(26, .black)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 22)
                        .background(RoundedRectangle(cornerRadius: 18).fill(MM.red).shadow(color: Color(hex: "#9E1F31"), radius: 0, y: 6))
                }.buttonStyle(PressStyle()).disabled(pot <= 0).opacity(pot > 0 ? 1 : 0.5)
                if let q = q { question(q) }
                optionList(options, chosen: chosen, locked: chosen != nil) { send(.choose($0)) }
            case .cheer(let title, let subtitle, let count):
                question(title)
                if let s = subtitle { Text(s).font(.poppins(13)).foregroundStyle(MM.cream.opacity(0.8)) }
                Button { send(.cheer) } label: { Text("🥁 ANFEUERN!").font(.outfit(30, .black)).foregroundStyle(MM.ink).frame(maxWidth: .infinity).padding(.vertical, 60).background(RoundedRectangle(cornerRadius: 28).fill(MM.gold)) }.buttonStyle(PressStyle())
                if count > 0 { Text("\(count)").font(.outfit(30, .black)).foregroundStyle(MM.gold) }
            case .confirm(let title, let subtitle, let button, let done, let deadline):
                timer(deadline); question(title)
                if let s = subtitle { Text(s).font(.poppins(13)).foregroundStyle(MM.cream.opacity(0.8)).multilineTextAlignment(.center) }
                GoldButton(title: done ? "✔ \(button)" : button) { send(.confirm) }.disabled(done)
            case .binary(let title, let subtitle, let a, let b, let chosen, let deadline):
                timer(deadline); question(title)
                if let s = subtitle { Text(s).font(.poppins(13)).foregroundStyle(MM.cream.opacity(0.8)).multilineTextAlignment(.center) }
                HStack(spacing: 12) {
                    GoldButton(title: a.uppercased(), style: chosen == a ? .gold : .green) { send(.binary(a)) }.disabled(chosen != nil)
                    GoldButton(title: b.uppercased(), style: chosen == b ? .gold : .green) { send(.binary(b)) }.disabled(chosen != nil)
                }
            case .vote(let title, let options, let chosen, let deadline):
                timer(deadline); question(title)
                VStack(spacing: 8) {
                    ForEach(options) { o in
                        Button { send(.vote(o.id)) } label: {
                            HStack { Text(o.emoji ?? "•").font(.system(size: 24)); Text(o.label).font(.poppins(16, .bold)); Spacer(); if o.count > 0 { Text("\(o.count)").font(.poppins(13)).opacity(0.7) } }
                                .padding(14).foregroundStyle(MM.cream).background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.3)).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(chosen == o.id ? MM.gold : Color.white.opacity(0.1), lineWidth: 2)))
                        }.buttonStyle(PressStyle()).disabled(chosen != nil && chosen != o.id).opacity(chosen != nil && chosen != o.id ? 0.55 : 1)
                    }
                }
            case .explain(let title, let body, let ready, let streik, let deadline):
                timer(deadline)
                Text(title).font(.outfit(24, .black)).foregroundStyle(MM.gold)
                Text(body).font(.poppins(14)).foregroundStyle(MM.cream).lineSpacing(3)
                HStack { GoldButton(title: ready ? "✔ Bereit" : "Bereit!") { send(.ready("bereit")) }.disabled(ready); GoldButton(title: "✊ Streik", style: .ghost) { send(.ready("streik")) }.disabled(streik) }
            case .actions(let title, let lines, let buttons, let deadline):
                timer(deadline); question(title)
                ForEach(lines, id: \.self) { Text($0).font(.poppins(13)).foregroundStyle(MM.cream.opacity(0.85)).frame(maxWidth: .infinity, alignment: .leading) }
                ForEach(buttons) { b in GoldButton(title: b.label, style: b.style == "primary" ? .gold : (b.style == "danger" ? .red : .green)) { send(.button(b.id)) }.disabled(!b.enabled).opacity(b.enabled ? 1 : 0.5) }
            case .cards(let title, let cards, let buttons, let deadline, let hint):
                timer(deadline); question(title)
                if let h = hint { Text(h).font(.poppins(12)).foregroundStyle(MM.cream.opacity(0.7)) }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                    ForEach(cards) { c in
                        let parts = c.text.split(separator: " ").map(String.init)
                        Button { send(.choose(c.id)) } label: {
                            Text(parts.count > 1 ? parts[1...].joined(separator: " ") : c.text).font(.outfit(18, .black)).foregroundStyle(.white).frame(width: 70, height: 100)
                                .background(RoundedRectangle(cornerRadius: 10).fill(cardColor(parts.first ?? "")).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white, lineWidth: 3)))
                        }.buttonStyle(PressStyle()).disabled(c.removed).opacity(c.removed ? 0.35 : 1)
                    }
                }
                HStack { ForEach(buttons) { b in GoldButton(title: b.label, style: b.style == "danger" ? .red : .green, compact: true) { send(.button(b.id)) }.disabled(!b.enabled) } }
            case .feedback(let questions, let done):
                Text("📝 Presse-Stimmen").font(.outfit(24, .black)).foregroundStyle(MM.gold)
                ForEach(Array(questions.enumerated()), id: \.offset) { i, q in
                    Text(q).font(.poppins(13, .bold)).foregroundStyle(MM.cream)
                    TextField("…", text: Binding(get: { i < feedback.count ? feedback[i] : "" }, set: { if i < feedback.count { feedback[i] = $0 } })).textFieldStyle(.plain).padding(10).background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.3))).foregroundStyle(MM.cream)
                }
                GoldButton(title: done ? "Danke! ✔" : "Abschicken") { send(.feedback(feedback)) }.disabled(done)
            }
        }
    }

    // MARK: pieces

    func idle(_ title: String, _ subtitle: String?) -> some View {
        VStack(spacing: 10) {
            Text("🐵").font(.system(size: 60)).phaseAnimator([0, 1]) { v, p in v.offset(y: p == 0 ? 0 : -8) } animation: { _ in .easeInOut(duration: 1.2) }
            Text(title).font(.outfit(26, .black)).foregroundStyle(MM.cream).multilineTextAlignment(.center)
            if let s = subtitle { Text(s).font(.poppins(14)).foregroundStyle(MM.cream.opacity(0.8)).multilineTextAlignment(.center) }
        }.frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    @ViewBuilder
    func timer(_ deadline: Millis?) -> some View {
        if let d = deadline { TimerBar(deadline: d, totalMs: max(1000, d - ServerClock.now()), height: 8) }
    }

    func hintView(_ h: String) -> some View {
        Text(h).font(.poppins(13, .semibold)).foregroundStyle(MM.cream).padding(10).frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 10).fill(MM.gold.opacity(0.14)))
    }

    func question(_ q: String) -> some View {
        Text(q).font(.outfit(q.count > 80 ? 19 : 23, .bold)).foregroundStyle(MM.cream).multilineTextAlignment(.center).lineSpacing(3).frame(maxWidth: .infinity).padding(.vertical, 6)
    }

    func optionList(_ options: [ChoiceOption], chosen: Int?, locked: Bool, multi: Set<Int> = [], onPick: @escaping (Int) -> Void) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(options.enumerated()), id: \.element.id) { i, o in
                Button { onPick(o.id) } label: {
                    HStack(spacing: 12) {
                        Text(["A", "B", "C", "D", "E", "F", "G", "H"][i % 8]).font(.outfit(18, .black)).foregroundStyle(MM.ink).frame(width: 36, height: 36).background(RoundedRectangle(cornerRadius: 10).fill(MM.optionColors[i % MM.optionColors.count]))
                        Text(MM.optionEmojis[i % MM.optionEmojis.count])
                        Text(o.text).font(.poppins(16, .bold)).foregroundStyle(MM.cream).multilineTextAlignment(.leading)
                        Spacer()
                        if let c = o.count { Text("\(c)").font(.poppins(12)).foregroundStyle(MM.cream.opacity(0.7)) }
                    }
                    .padding(14).frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 16).fill(chosen == o.id || multi.contains(o.id) ? MM.gold.opacity(0.2) : Color.black.opacity(0.28)).overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(chosen == o.id || multi.contains(o.id) ? MM.gold : Color.white.opacity(0.12), lineWidth: 2)))
                }
                .buttonStyle(PressStyle())
                .disabled(o.removed || locked)
                .opacity(o.removed ? 0.3 : (locked && chosen != o.id ? 0.55 : 1))
                .overlay { if o.removed { Rectangle().fill(MM.red).frame(height: 3).rotationEffect(.degrees(-3)) } }
            }
        }
    }

    func move(_ pos: Int, _ dir: Int, _ base: [Int]) {
        if order.isEmpty { order = base }
        let to = pos + dir
        guard to >= 0, to < order.count else { return }
        order.swapAt(pos, to)
        send(.order(order))
    }

    func fmtNum(_ v: Double) -> String { v == v.rounded() ? Money.formatNumber(Int(v)) : String(format: "%.1f", v) }
    func cardColor(_ emoji: String) -> Color { ["🔴": MM.red, "🟡": MM.goldDark, "🟢": Color(hex: "#3AA655"), "🔵": MM.blue][emoji] ?? .black }
}

// MARK: - Phone GM cockpit

struct PhoneGmView: View {
    @EnvironmentObject var player: PlayerModel
    @State private var scorePlayer = ""
    @State private var reason = "Bester Fehlversuch"

    var body: some View {
        if let g = player.gmView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Group {
                    HStack { Text("🎬 SHOW-MASTER · \(g.roomCode)").font(.outfit(18, .black)).foregroundStyle(MM.gold); Spacer(); Chip(text: g.stage.phase.rawValue) }
                    Text(g.stage.sectionLabel).font(.outfit(22, .bold)).foregroundStyle(MM.cream)
                    GoldButton(title: g.stage.advanceLabel ?? "Weiter", icon: "play.fill") { player.gm(.flowNext) }.disabled(!g.stage.canAdvance && !g.stage.paused)
                    HStack { GoldButton(title: g.stage.paused ? "▶ Weiter" : "⏸ Pause", style: .green, compact: true) { player.gm(g.stage.paused ? .resume : .pause(text: "🍌 Bananen-Pause", dauerMs: nil)) }; GoldButton(title: "⏭ Opening", style: .green, compact: true) { player.gm(.flowSkipOpening) }; GoldButton(title: "⏳ +15 s", style: .green, compact: true) { player.gm(.timerExtend(ms: 15_000)) } }
                    if let q = g.spickzettel {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("🤫 Spickzettel").font(.poppins(12, .bold)).foregroundStyle(MM.gold)
                            Text(q.text).font(.poppins(14, .bold)).foregroundStyle(MM.cream)
                            Text("✔ \(q.korrekt)").font(.outfit(20, .black)).foregroundStyle(MM.green)
                            Text(q.erklaerung).font(.poppins(12)).foregroundStyle(MM.cream.opacity(0.8))
                        }.padding(12).background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.3)))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Live").font(.poppins(12, .bold)).foregroundStyle(MM.gold)
                        ForEach(g.players) { p in HStack { Text(p.connected ? "🟢" : "🔴"); Text(p.name).font(.poppins(13, .bold)); Spacer(); Text(g.antworten[p.id] ?? "").font(.poppins(11)).opacity(0.8).lineLimit(1); Text(Money.format(p.balance)).font(.outfit(13, .black)).foregroundStyle(MM.gold) }.foregroundStyle(MM.cream) }
                    }.padding(12).background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.3)))
                    }
                    Group {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        tool("💡 Tipp-Kanone") { player.gm(.hintGlobal) }
                        tool("🎤 Encore") { player.gm(.encore) }
                        tool("🎡 Rad drehen") { player.gm(.wheelSpin(rigTarget: nil)) }
                        tool("🌡️ Stimmung") { player.gm(.moodPoll) }
                        tool("🔴 Roter Buzzer") { player.gm(.questionMarkBroken(grund: "Frage fehlerhaft", refund: "grantAll")) }
                        tool("🚪 Notausgang") { player.gm(.gameSkip(keepPoints: true)) }
                        tool("📝 Feedback") { player.gm(.feedbackCollect) }
                        tool("🔁 Revanche") { player.gm(.revanche) }
                    }
                    Picker("Spieler", selection: $scorePlayer) { ForEach(g.players) { p in Text(p.name).tag(p.id) } }.pickerStyle(.menu).tint(MM.gold)
                    TextField("Begründung", text: $reason).textFieldStyle(.roundedBorder)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        tool("🏦 +100 MM") { if !scorePlayer.isEmpty { player.gm(.scoreAdjust(playerId: scorePlayer, delta: 100, grund: reason)) } }
                        tool("🏦 −100 MM") { if !scorePlayer.isEmpty { player.gm(.scoreAdjust(playerId: scorePlayer, delta: -100, grund: reason)) } }
                        tool("🐒 Boost ×2") { if !scorePlayer.isEmpty { player.gm(.boost(playerId: scorePlayer, art: "x2", grund: reason)) } }
                        tool("⚖️ Bananen-Steuer") { if !scorePlayer.isEmpty { player.gm(.punish(playerId: scorePlayer, strafe: "bananensteuer")) } }
                        tool("🎁 Joker schenken") { if !scorePlayer.isEmpty { player.gm(.jokerGrant(ziel: scorePlayer, jokerId: "bananen-split")) } }
                        tool("🤫 Flüstern: Tipp 1") { if !scorePlayer.isEmpty, let t = g.spickzettel?.tipps.first { player.gm(.whisper(playerId: scorePlayer, text: t)) } }
                    }
                    Text("Drama \(g.dramaScore): \(g.empfehlung)").font(.poppins(12)).foregroundStyle(MM.cream.opacity(0.8))
                    Button("Pult verlassen") { player.disconnect() }.font(.poppins(12, .semibold)).foregroundStyle(MM.cream.opacity(0.5))
                    }
                }.padding(14)
            }
            .onAppear { if scorePlayer.isEmpty, let p = g.players.first { scorePlayer = p.id } }
        } else {
            VStack { ProgressView().tint(MM.gold); Text("Regiepult lädt …").foregroundStyle(MM.cream) }
        }
    }

    func tool(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(.poppins(13, .semibold)).lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity).padding(.vertical, 10).background(RoundedRectangle(cornerRadius: 10).fill(MM.panel)).foregroundStyle(MM.cream) }.buttonStyle(PressStyle())
    }
}
