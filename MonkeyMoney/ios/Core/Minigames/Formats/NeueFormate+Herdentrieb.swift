import Foundation

/// Herdentrieb — the majority game without a right answer. Everybody taps
/// what they think THE HERD picks. The largest group gets 0.4 F each; tied
/// largest groups get 0.2 F each; a lone monkey on an option (Einzelgänger)
/// gets nothing.
public enum Herdentrieb: MinigamePlugin {
    public struct Frage: Codable, Equatable, Sendable {
        public var text: String
        public var optionen: [String]
        public var emojis: [String]

        public var labels: [String] { zip(emojis, optionen).map { "\($0) \($1)" } }
    }

    public struct State: Codable, Equatable, Sendable {
        /// Indices into `Herdentrieb.fragen` for this round.
        public var auswahl: [Int]
        public var gesamt: Int
        public var index: Int
        /// "frage" | "mini" | "fertig"
        public var phase: String
        public var startedAt: Millis
        public var deadline: Millis
        public var timerMs: Int
        public var revealUntil: Millis?
        public var wert: Int
        public var wahl: [PlayerId: Int]
        public var wahlAt: [PlayerId: Millis]
        public var punkte: [PlayerId: Int]
        public var treffer: [PlayerId: Int]
        public var einzelAnzahl: [PlayerId: Int]
        public var beantwortet: [PlayerId: Int]
        public var lastPoints: [PlayerId: Int]
        public var lastMehrheit: [Int]
        public var lastEinzel: [PlayerId]
        public var gespielt: Int
    }

    private static let h = NeueFormate.faktor(NeueFormate.Anteil.herde)
    private static let g = NeueFormate.faktor(NeueFormate.Anteil.herdeGleichstand)

    public static let meta = MinigameMeta(
        id: "herdentrieb", name: "Herdentrieb", emoji: "🐑",
        kurz: "Keine richtige Antwort — tippe, was die Mehrheit wählt. Die Herde kassiert, Einzelgänger gehen leer aus.",
        erklaerung: "Pizza oder Pasta? Strand oder Berge? Hier gibt es kein Richtig oder Falsch — nur die Herde. Tippe, was deiner Meinung nach DIE MEHRHEIT wählt. Die größte Gruppe bekommt \(h) Fragenwert pro Kopf. Sind mehrere Gruppen gleich groß, bekommen alle \(g). Wer ganz allein auf einer Antwort steht, ist ein Einzelgänger und geht leer aus.",
        regeln: ["Keine richtige Antwort — nur die Meinung der Herde zählt",
                 "Tippe, was die MEHRHEIT wählt, nicht deinen Liebling",
                 "Größte Gruppe: \(h) Fragenwert pro Kopf",
                 "Gleichstand an der Spitze: alle Spitzen-Gruppen \(g)",
                 "Allein auf einer Antwort? Einzelgänger — 0"],
        gewinn: "Größte Gruppe \(h) Fragenwert · Gleichstand \(g) · Einzelgänger 0",
        contentKind: .none, roundBased: true, streak: false, jokerAktionen: [], isMc: true, musik: "market_trade", v2: true
    )

    static let fensterMs = 12_000
    static let eimer = 6

    static func f(_ text: String, _ opts: [(String, String)]) -> Frage {
        Frage(text: text, optionen: opts.map { $0.1 }, emojis: opts.map { $0.0 })
    }

    /// The built-in herd questions (family-friendly, 2–4 options each).
    public static let fragen: [Frage] = [
        f("Pizza oder Pasta?", [("🍕", "Pizza"), ("🍝", "Pasta")]),
        f("Strand oder Berge?", [("🏖️", "Strand"), ("🏔️", "Berge")]),
        f("Frühaufsteher oder Langschläfer?", [("🌅", "Frühaufsteher"), ("😴", "Langschläfer")]),
        f("Welche Superkraft wäre am besten?", [("🦅", "Fliegen"), ("👻", "Unsichtbar"), ("🧠", "Gedankenlesen"), ("✨", "Teleportieren")]),
        f("Hund oder Katze?", [("🐶", "Hund"), ("🐱", "Katze")]),
        f("Sommer oder Winter?", [("☀️", "Sommer"), ("❄️", "Winter")]),
        f("Süß oder salzig?", [("🍫", "Süß"), ("🥨", "Salzig")]),
        f("Kaffee, Tee oder Kakao?", [("☕", "Kaffee"), ("🍵", "Tee"), ("🍫", "Kakao")]),
        f("Lieber lesen oder gucken?", [("📚", "Buch"), ("🎬", "Film")]),
        f("Das perfekte Frühstück?", [("🥐", "Croissant"), ("🥣", "Müsli"), ("🍳", "Rührei"), ("🥞", "Pfannkuchen")]),
        f("Wohin geht die Traumreise?", [("🗼", "Paris"), ("🗽", "New York"), ("🏝️", "Karibik"), ("🗾", "Japan")]),
        f("Welches Haustier wäre das beste?", [("🐶", "Hund"), ("🐱", "Katze"), ("🐹", "Hamster"), ("🦜", "Papagei")]),
        f("Welche Eissorte?", [("🍦", "Vanille"), ("🍫", "Schoko"), ("🍓", "Erdbeere"), ("🍋", "Zitrone")]),
        f("Zug oder Auto?", [("🚆", "Zug"), ("🚗", "Auto")]),
        f("Stadt oder Land?", [("🏙️", "Stadt"), ("🌾", "Land")]),
        f("Duschen oder Baden?", [("🚿", "Duschen"), ("🛁", "Baden")]),
        f("Die schönste Jahreszeit?", [("🌷", "Frühling"), ("☀️", "Sommer"), ("🍂", "Herbst"), ("❄️", "Winter")]),
        f("Pommes am liebsten mit …?", [("🍅", "Ketchup"), ("🥚", "Mayo"), ("🍟", "Beidem"), ("🚫", "Ohne alles")]),
        f("Lieber anrufen oder schreiben?", [("📞", "Anrufen"), ("💬", "Schreiben")]),
        f("Was spielen wir am Spieleabend?", [("🃏", "Kartenspiel"), ("🎲", "Brettspiel"), ("🎮", "Videospiel"), ("🎤", "Karaoke")]),
        f("Kino oder Couch?", [("🍿", "Kino"), ("🛋️", "Couch")]),
        f("Frühstück im Bett oder am Tisch?", [("🛏️", "Im Bett"), ("🍽️", "Am Tisch")]),
        f("Die schönste Farbe?", [("🔴", "Rot"), ("🔵", "Blau"), ("🟢", "Grün"), ("🟡", "Gelb")]),
        f("Wandern oder Radfahren?", [("🥾", "Wandern"), ("🚲", "Radfahren")]),
        f("Zelten oder Hotel?", [("⛺", "Zelten"), ("🏨", "Hotel")]),
        f("Welche Schokolade?", [("🥛", "Vollmilch"), ("🍫", "Zartbitter"), ("🤍", "Weiße")]),
        f("Welches Tier wärst du am liebsten?", [("🦁", "Löwe"), ("🐬", "Delfin"), ("🦅", "Adler"), ("🐒", "Affe")]),
        f("Sonnenaufgang oder Sonnenuntergang?", [("🌅", "Sonnenaufgang"), ("🌇", "Sonnenuntergang")]),
        f("Das beste Obst?", [("🍌", "Banane"), ("🍎", "Apfel"), ("🍓", "Erdbeere"), ("🍉", "Melone")]),
        f("Weihnachten oder Geburtstag?", [("🎄", "Weihnachten"), ("🎂", "Geburtstag")]),
        f("Popcorn süß oder salzig?", [("🍬", "Süß"), ("🧂", "Salzig")]),
        f("Der beste Snack zum Filmabend?", [("🍿", "Popcorn"), ("🥔", "Chips"), ("🍫", "Schokolade"), ("🥕", "Gemüsesticks")]),
        f("Achterbahn oder Riesenrad?", [("🎢", "Achterbahn"), ("🎡", "Riesenrad")]),
        f("Meer oder See?", [("🌊", "Meer"), ("🏞️", "See")]),
        f("Der coolste Superheld?", [("🕷️", "Spider-Man"), ("🦇", "Batman"), ("🦸", "Wonder Woman"), ("💚", "Hulk")]),
        f("Zeitreise: wohin?", [("🏛️", "Vergangenheit"), ("🚀", "Zukunft")]),
        f("Dinosaurier oder Drachen?", [("🦖", "Dinosaurier"), ("🐉", "Drachen")]),
        f("Nudeln am liebsten mit …?", [("🍅", "Tomatensoße"), ("🌿", "Pesto"), ("🧀", "Käsesoße"), ("🧈", "Butter")]),
        f("Das gemütlichste Wetter?", [("🌧️", "Regen"), ("⛈️", "Gewitter"), ("❄️", "Schnee"), ("☀️", "Sonne")]),
        f("Party oder Spieleabend?", [("🎉", "Party"), ("🎲", "Spieleabend")]),
        f("Welcher Kuchen?", [("🧀", "Käsekuchen"), ("🍎", "Apfelkuchen"), ("🍫", "Schokokuchen"), ("🍓", "Erdbeertorte")]),
        f("Meerjungfrau oder Einhorn?", [("🧜", "Meerjungfrau"), ("🦄", "Einhorn")]),
        f("Wer ist am coolsten?", [("🏴‍☠️", "Piraten"), ("🛡️", "Ritter"), ("🥷", "Ninjas"), ("🧑‍🚀", "Astronauten")]),
        f("Das beste Sommergetränk?", [("🍋", "Limonade"), ("🧃", "Saft"), ("💧", "Wasser"), ("🧋", "Eistee")]),
        f("Schwimmbad oder Freizeitpark?", [("🏊", "Schwimmbad"), ("🎠", "Freizeitpark")]),
        f("Der beste Tag der Woche?", [("🥳", "Freitag"), ("🎉", "Samstag"), ("😴", "Sonntag")]),
        f("Lieber singen oder tanzen?", [("🎤", "Singen"), ("💃", "Tanzen")]),
        f("Lieber zaubern oder mit Tieren sprechen?", [("🪄", "Zaubern"), ("🐾", "Mit Tieren sprechen")]),
        f("Bratwurst oder Burger?", [("🌭", "Bratwurst"), ("🍔", "Burger")]),
        f("Welche Pizza?", [("🍅", "Margherita"), ("🍍", "Hawaii"), ("🍄", "Funghi"), ("🌶️", "Salami")]),
        f("Lieber reich oder berühmt?", [("💰", "Reich"), ("⭐", "Berühmt")]),
        f("Pfannkuchen am liebsten mit …?", [("🍬", "Zucker"), ("🍏", "Apfelmus"), ("🍫", "Nuss-Nougat"), ("🍓", "Marmelade")]),
        f("Schwimmen im Meer oder im Pool?", [("🌊", "Meer"), ("🏊", "Pool")]),
        f("Weltall oder Tiefsee?", [("🚀", "Weltall"), ("🐙", "Tiefsee")]),
        f("Einen Tag lang verzichten auf …?", [("📵", "Handy"), ("🍭", "Süßigkeiten")]),
        f("Der coolste Dschungelbewohner?", [("🐒", "Affe"), ("🐯", "Tiger"), ("🦜", "Papagei"), ("🐍", "Schlange")]),
        f("Was kommt aufs Brot?", [("🧀", "Käse"), ("🥓", "Wurst"), ("🍯", "Honig"), ("🍓", "Marmelade")]),
        f("Der Wecker klingelt …", [("⏰", "Sofort raus"), ("😴", "Schlummertaste")]),
        f("Einen Tag lang Riese oder Zwerg?", [("🦒", "Riese"), ("🐭", "Zwerg")]),
        f("Wo würdest du am liebsten wohnen?", [("🌳", "Baumhaus"), ("🏰", "Schloss"), ("🏖️", "Strandhütte"), ("🛰️", "Raumstation")]),
        f("Was machen wir im Schnee?", [("⛄", "Schneemann"), ("🛷", "Schlitten"), ("❄️", "Schneeballschlacht")]),
        f("Welches Instrument?", [("🎸", "Gitarre"), ("🎹", "Klavier"), ("🥁", "Schlagzeug"), ("🎺", "Trompete")]),
        f("Spaghetti schneiden oder drehen?", [("✂️", "Schneiden"), ("🍝", "Drehen")]),
        f("Pommes isst man …?", [("🍴", "Mit Gabel"), ("✋", "Mit den Fingern")]),
        f("Das beste Frühstücksgebäck?", [("🥖", "Brötchen"), ("🍞", "Toast"), ("🥨", "Brezel"), ("🥯", "Bagel")]),
        f("Verreisen mit Freunden oder Familie?", [("👫", "Freunde"), ("🏡", "Familie")]),
        f("Die beste Gummibärchen-Farbe?", [("🔴", "Rot"), ("🟢", "Grün"), ("🟡", "Gelb"), ("⚪", "Weiß")]),
        f("Das süßeste Tierbaby?", [("🐣", "Küken"), ("🐶", "Welpe"), ("🐱", "Kätzchen"), ("🐼", "Panda")]),
        f("Wer gewinnt: Hai oder Krokodil?", [("🦈", "Hai"), ("🐊", "Krokodil")]),
        f("Beim Spielen zählt …?", [("🏆", "Gewinnen"), ("😄", "Spaß haben")]),
        f("Die beste Süßigkeit?", [("🍭", "Lolli"), ("🍬", "Bonbon"), ("🍫", "Schokolade"), ("🧸", "Gummibärchen")]),
        f("Zum Nachtisch?", [("🍮", "Pudding"), ("🍨", "Eis"), ("🍰", "Kuchen"), ("🍎", "Obst")]),
        f("Im Regen tanzen oder in der Sonne liegen?", [("🌧️", "Im Regen tanzen"), ("🌞", "In der Sonne liegen")]),
        f("Kartoffeln am liebsten als …?", [("🍟", "Pommes"), ("🥔", "Püree"), ("🍳", "Bratkartoffeln"), ("🥗", "Kartoffelsalat")]),
        f("Wie viel Schlaf ist perfekt?", [("😴", "7 Stunden"), ("🛌", "8 Stunden"), ("💤", "9 Stunden"), ("🐨", "10 und mehr")]),
    ]

    /// Questions for a round: the list is split into six interleaved buckets; round n
    /// draws (seeded) from bucket n mod 6 first, so two herd rounds in one show never
    /// repeat a question unless they are six rounds apart.
    static func auswahl(anzahl: Int, ctx: inout MinigameContext) -> [Int] {
        let start = (max(1, ctx.section.rundenNummer) - 1) % eimer
        var out: [Int] = []
        for k in 0..<eimer where out.count < anzahl {
            let b = (start + k) % eimer
            let bucket = fragen.indices.filter { $0 % eimer == b }
            out += ctx.rng.shuffled(bucket).prefix(anzahl - out.count)
        }
        return out
    }

    /// One question's verdict — pure: points per voter, the majority option ids, the lone wolves.
    public static func auswertung(_ wahl: [(player: PlayerId, option: Int)], optionen: Int, wert: Int)
        -> (punkte: [PlayerId: Int], mehrheit: [Int], einzel: [PlayerId], counts: [Int]) {
        var counts = Array(repeating: 0, count: max(1, optionen))
        for w in wahl where counts.indices.contains(w.option) { counts[w.option] += 1 }
        let top = counts.max() ?? 0
        let mehrheit = top >= 2 ? counts.indices.filter { counts[$0] == top } : []
        let each = NeueFormate.betrag(wert, mehrheit.count == 1 ? NeueFormate.Anteil.herde : NeueFormate.Anteil.herdeGleichstand)
        var punkte: [PlayerId: Int] = [:]
        var einzel: [PlayerId] = []
        for w in wahl where counts.indices.contains(w.option) {
            if counts[w.option] == 1 { einzel.append(w.player); punkte[w.player] = 0 }
            else { punkte[w.player] = mehrheit.contains(w.option) ? each : 0 }
        }
        return (punkte, mehrheit, einzel, counts)
    }

    static func frage(_ s: State) -> Frage { fragen[s.auswahl[s.index % s.auswahl.count]] }

    public static func initState(questions: [Question], songs: [Song], ctx: inout MinigameContext) -> State {
        let n = NeueFormate.schritte(ctx, verfuegbar: fragen.count)
        var s = State(auswahl: auswahl(anzahl: n, ctx: &ctx), gesamt: n, index: 0, phase: "frage", startedAt: ctx.now, deadline: ctx.now, timerMs: 0,
                      revealUntil: nil, wert: NeueFormate.sectionWert(ctx: ctx), wahl: [:], wahlAt: [:], punkte: [:], treffer: [:], einzelAnzahl: [:],
                      beantwortet: [:], lastPoints: [:], lastMehrheit: [], lastEinzel: [], gespielt: 0)
        start(&s, index: 0, ctx: ctx)
        return s
    }

    static func start(_ s: inout State, index: Int, ctx: MinigameContext) {
        s.index = index
        s.phase = "frage"
        s.timerMs = NeueFormate.fenster(fensterMs, ctx: ctx)
        s.startedAt = ctx.now
        s.deadline = ctx.now + s.timerMs
        s.revealUntil = nil
        s.wahl = [:]
        s.wahlAt = [:]
        s.lastPoints = [:]
        s.lastMehrheit = []
        s.lastEinzel = []
    }

    static func resolve(_ s: inout State, ctx: MinigameContext) {
        let fr = frage(s)
        let wahl = ctx.players.compactMap { p in s.wahl[p].map { (player: p, option: $0) } }
        let a = auswertung(wahl, optionen: fr.optionen.count, wert: s.wert)
        for w in wahl {
            s.beantwortet[w.player, default: 0] += 1
            let pts = a.punkte[w.player] ?? 0
            s.punkte[w.player, default: 0] += pts
            if pts > 0 { s.treffer[w.player, default: 0] += 1 }
        }
        for p in a.einzel { s.einzelAnzahl[p, default: 0] += 1 }
        s.lastPoints = a.punkte
        s.lastMehrheit = a.mehrheit
        s.lastEinzel = a.einzel
        s.gespielt += 1
    }

    static func weiter(_ s: inout State, ctx: MinigameContext) {
        if s.index + 1 < s.gesamt { start(&s, index: s.index + 1, ctx: ctx) } else { s.phase = "fertig"; s.revealUntil = nil }
    }

    public static func reduce(_ state: inout State, action: PlayerAction, from player: PlayerId, ctx: inout MinigameContext) {
        guard state.phase == "frage", state.wahl[player] == nil, ctx.now <= state.deadline + ChoiceCore.graceMs else { return }
        let n = frage(state).optionen.count
        switch action {
        case .choose(let i):
            guard i >= 0, i < n else { return }
            state.wahl[player] = i
        case .vote(let v):
            guard let i = Int(v), i >= 0, i < n else { return }
            state.wahl[player] = i
        default:
            return
        }
        state.wahlAt[player] = ctx.now
    }

    public static func gm(_ state: inout State, action: GmMinigameAction, ctx: inout MinigameContext) {
        switch action {
        case .timerExtend(let ms):
            if state.phase == "frage" { state.deadline += ms; state.timerMs += ms }
        case .timerShift(let ms):
            state.deadline += ms
            state.startedAt += ms
            for (p, t) in state.wahlAt { state.wahlAt[p] = t + ms }
            if let r = state.revealUntil { state.revealUntil = r + ms }
        case .forceFinish:
            if state.phase == "frage", !state.wahl.isEmpty { resolve(&state, ctx: ctx) }
            state.phase = "fertig"
            state.revealUntil = nil
        case .skipQuestion:
            if state.phase != "fertig" { weiter(&state, ctx: ctx) }
        default:
            break
        }
    }

    public static func tick(_ state: inout State, ctx: inout MinigameContext) {
        switch state.phase {
        case "frage":
            let done = ctx.now > state.deadline + ChoiceCore.graceMs || NeueFormate.alleDrin(NeueFormate.aktive(ctx: ctx)) { state.wahl[$0] != nil }
            if done {
                resolve(&state, ctx: ctx)
                state.phase = "mini"
                state.revealUntil = ctx.now + ctx.ms(NeueFormate.Reveal.herde)
            }
        case "mini":
            if let r = state.revealUntil, ctx.now >= r { weiter(&state, ctx: ctx) }
        default:
            break
        }
    }

    public static func isFinished(_ state: State, ctx: MinigameContext) -> Bool { state.phase == "fertig" }

    public static func scores(_ state: State, ctx: MinigameContext) -> [PlayerId: Int] {
        var s: [PlayerId: Int] = [:]
        for p in ctx.players { s[p] = state.punkte[p] ?? 0 }
        return s
    }

    static func detail(_ s: State, _ p: PlayerId) -> String {
        var parts = ["\(s.treffer[p] ?? 0)/\(s.gespielt)× mit der Herde"]
        if let e = s.einzelAnzahl[p], e > 0 { parts.append("\(e)× Einzelgänger") }
        return parts.joined(separator: " · ")
    }

    public static func outcomes(_ state: State, ctx: MinigameContext) -> [PlayerId: Outcome] {
        var out: [PlayerId: Outcome] = [:]
        for p in ctx.players {
            let pts = state.punkte[p] ?? 0
            out[p] = Outcome(correct: pts > 0 ? true : ((state.beantwortet[p] ?? 0) > 0 ? false : nil), countsForStreak: false, detail: detail(state, p))
        }
        return out
    }

    public static func stage(_ state: State, revealed: Bool, ctx: MinigameContext) -> MinigameStageOutput {
        let phase = revealed ? "fertig" : state.phase
        let fr = frage(state)
        let open = phase != "frage"
        let opts = fr.optionen.indices.map { i -> HerdeOption in
            let voters = ctx.players.filter { state.wahl[$0] == i }
            return HerdeOption(id: i, text: fr.optionen[i], emoji: fr.emojis[i], count: open ? voters.count : nil, voters: open ? voters : nil)
        }
        let answered = ctx.players.filter { state.wahl[$0] != nil }
        let extra = StageExtra.herde(nummer: state.index + 1, gesamt: state.gesamt, phase: phase, prompt: fr.text, options: opts,
                                     majority: open ? state.lastMehrheit : [], einzelgaenger: open ? state.lastEinzel : [],
                                     answered: phase == "frage" ? answered.count : 0, points: open ? state.lastPoints : [:], totals: state.punkte,
                                     wert: NeueFormate.betrag(state.wert, NeueFormate.Anteil.herde))
        if phase == "frage" {
            let wall = QuestionWall(text: fr.text, kategorie: "herdentrieb", kategorieName: "Herdentrieb", kategorieEmoji: "🐑",
                                    schwierigkeit: ctx.section.schwierigkeiten.max() ?? .medium, wert: NeueFormate.betrag(state.wert, NeueFormate.Anteil.herde),
                                    options: fr.labels.enumerated().map { ChoiceOption(id: $0.offset, text: $0.element) }, answered: answered,
                                    deadline: ctx.visible(state.deadline), timerMs: state.timerMs, revealed: false, correctIndex: nil, answersByPlayer: [:],
                                    tipp: "🐑 Tippt, was die MEHRHEIT wählt!", nummer: state.index + 1, gesamt: state.gesamt)
            return MinigameStageOutput(wall: wall, extra: extra, title: meta.name, audio: AudioCue(music: meta.musik))
        }
        let title = phase == "mini" ? "🐑 Frage \(state.index + 1) von \(state.gesamt)" : "🐑 Herdentrieb"
        return MinigameStageOutput(wall: nil, extra: extra, title: title, audio: AudioCue(music: meta.musik))
    }

    public static func prompt(_ state: State, player: PlayerId, revealed: Bool, ctx: MinigameContext) -> PlayerPrompt {
        let fr = frage(state)
        if revealed {
            let pts = state.punkte[player] ?? 0
            let t = state.treffer[player] ?? 0
            let title = pts == 0 ? ((state.beantwortet[player] ?? 0) > 0 ? "🐺 Einsamer Wolf" : "Nicht mitgeblökt") : (t == state.gespielt ? "🐑 HERDENTIER!" : "🐑 Mit der Herde!")
            return .reveal(title: title, correct: outcomes(state, ctx: ctx)[player]?.correct ?? nil, delta: pts, detail: detail(state, player), streak: 0, speedBonus: nil)
        }
        switch state.phase {
        case "frage":
            let opts = fr.labels.enumerated().map { ChoiceOption(id: $0.offset, text: $0.element) }
            return .choice(question: fr.text, options: opts, chosen: state.wahl[player], deadline: ctx.visible(state.deadline), secondTry: false,
                           hint: "🐑 Frage \(state.index + 1)/\(state.gesamt) · Tippe, was die MEHRHEIT wählt!")
        case "mini":
            let herde = state.lastMehrheit.map { fr.labels[$0] }.joined(separator: " & ")
            let loesung = herde.isEmpty ? "Keine Herde — alle allein" : "Herde: \(herde)"
            guard let w = state.wahl[player] else {
                return .reveal(title: "⏰ Nicht mitgeblökt", correct: nil, delta: 0, detail: loesung, streak: 0, speedBonus: nil)
            }
            let pts = state.lastPoints[player] ?? 0
            if state.lastEinzel.contains(player) {
                return .reveal(title: "🐺 Einzelgänger!", correct: false, delta: 0, detail: "Nur du: \(fr.labels[w]) · \(loesung)", streak: 0, speedBonus: nil)
            }
            if pts > 0 {
                let tie = state.lastMehrheit.count > 1
                return .reveal(title: tie ? "🐑 Gleichstand — halbe Herde!" : "🐑 Mit der Herde!", correct: true, delta: pts,
                               detail: "Du: \(fr.labels[w]) · \(loesung)", streak: 0, speedBonus: nil)
            }
            return .reveal(title: "🙈 Falsche Herde", correct: false, delta: 0, detail: "Du: \(fr.labels[w]) · \(loesung)", streak: 0, speedBonus: nil)
        default:
            return .idle(title: "🐑 Auswertung …", subtitle: nil)
        }
    }

    public static func gmInfo(_ state: State, ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        if state.phase == "fertig" {
            var answers: [PlayerId: String] = [:]
            for p in ctx.players { answers[p] = "\(detail(state, p)) · \(Money.formatDelta(state.punkte[p] ?? 0))" }
            return (NeueFormate.gmRunde("herdentrieb-runde", "🐑 Herdentrieb — \(state.gespielt) Fragen", ctx: ctx), answers)
        }
        let fr = frage(state)
        let korrekt = state.phase == "mini" && !state.lastMehrheit.isEmpty ? state.lastMehrheit.map { fr.labels[$0] }.joined(separator: " & ") : "Mehrheit entscheidet"
        let info = GmQuestionInfo(id: "herde_\(state.auswahl[state.index % state.auswahl.count])", text: "\(fr.text) (\(fr.labels.joined(separator: " / ")))",
                                  kategorie: "Herdentrieb", schwierigkeit: ctx.section.schwierigkeiten.max() ?? .medium, korrekt: korrekt,
                                  erklaerung: "Keine richtige Antwort — die größte Gruppe gewinnt.", tipps: [], typ: .choice)
        var answers: [PlayerId: String] = [:]
        for (p, w) in state.wahl {
            let secs = Double(max(0, (state.wahlAt[p] ?? state.startedAt) - state.startedAt)) / 1000
            answers[p] = "\(fr.labels[w]) (\(String(format: "%.1f", secs)) s)"
        }
        return (info, answers)
    }

    /// No catalogue questions are consumed.
    public static func questionsUsed(_ state: State) -> Int { 0 }
}
