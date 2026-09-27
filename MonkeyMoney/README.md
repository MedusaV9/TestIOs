# 🐒 MONKEY MONEY — Swift-Port

**Die Quiz-Show fürs Wohnzimmer, jetzt nativ.** Das iPad ist Bühne, Server und
Spielstandspeicher; die Handys der Gäste sind die Controller — QR-Code scannen,
im Browser mitspielen, nichts installieren. Ein Show-Master ist optional
und bekommt in der Lobby einen eigenen, ein- und ausblendbaren QR-Code.

Download: **[monkeymoney-latest](https://github.com/MedusaV9/TestIOs/releases/tag/monkeymoney-latest)**
(unsignierte IPAs aus GitHub Actions — mit AltStore / SideStore / Sideloadly signieren):
`MonkeyMoney-unsigned.ipa` (die komplette Show) und `MonkeyMoney-League-unsigned.ipa` (**League Edition**,
nur League-of-Legends-Fragen, eigene Bundle-ID — beide Apps passen nebeneinander aufs iPad).

## Was drin ist

| Bereich | Umfang |
| --- | --- |
| Fragen | 7.660 validierte Fragen, 14 Ober-/90 Unterkategorien, 7 Typen, 4 Schwierigkeiten (inkl. ULTRAHARD), 12 Pixel-Bilderrätsel |
| Show | Lobby → Opening → Runden (Kategorien-Voting, Erklärkarte, Fragen, Zwischenstand, Glücksrad) → Jackpot-Frage → Lianen-Finale → Highlights → Siegerehrung → Abspann/Revanche |
| Formate | 27: Bananen-Basics, Vier Lianen, Kokosnuss-Uhr, Bananen-Tresor, Affenleiter, Pixel-Dschungel, Affenbank, Stinkbanane, Taschendieb, Alles oder Banane, Lianen-Finale, Monkey Market, Bananen-Börse, Affen-Auktion, Bananen-Bluff, Lianensteg-Duell, Boxkampf, Konter-Quiz, Einer gegen alle, Tortenschlacht, Risiko-Leiter, Goldener Affe, Blitz-DJ, Rückwärts-Banane, Stummfilm-Studio, Wer singt's?, 7-Buchstaben-Telegramm |
| Brettspiele | Werwölfe vom Bananenhain, Bananen-Batsche (UNO), Affen ärgern sich nicht, Bananopoly, Affenturm, Siedler vom Bananenhain — Handys und/oder iPad-Sitze (Pass-and-Play) |
| Ökonomie | Fragenwert F = 100/250/500/1.000 MM — **jedes Format zahlt relativ zu F** (Tresor 1,5F/1F/0,6F, Pixel 1,5F→¼F, Affenbank 0,2F…3,2F, Kokosnuss-Sack 1,5F, Alles-oder-Banane bis 1,5F/750), Speed-Knick, Streak ×1,5/×2, Rückenwind mit Überhol-Kappe, Jackpot-Frage 2F + Glas, Dispo −500, Schuldenerlass, Mitleids-Banane, W_final-Formel, AT-Umrechnung, Level |
| Systeme | 7 Joker, 15 Rad-Segmente (Pech-Schutz, Pity-Timer, Fair-Finale-Pool), 7 Special Rules, Teams, Familien-/18+-Modus, 17 GM-Werkzeuge + Auto-GM, **Timer AUS / feste Zeit pro Frage**, Pause, Save-Slots, Revanche; Erklärkarten als 3–5 Regeln + Gewinn-Zeile; `swift test` enthält Bot-Matches **und Balance-Gates** (keine Runde zahlt >1,9× den Median) |
| Fragen-Set | Der Show-Master wählt den Fragen-Pool per Tipp: **Alles · League of Legends · Gaming · Popkultur · Wissen · Deutschland · Sport · Kinder & Familie · Eigene Auswahl** (Kategorien + Unterkategorien mit Fragenzahl). Gilt sofort für die nächste Runde; die Kategorien-Wahl läuft innerhalb des Sets, Schätz-/Sortier-/Pixel-Runden fallen auf Vier Lianen zurück, wenn das Set sie nicht bedienen kann |
| Regiepult | Browser-Cockpit mit Tabs (Regie · Fragen · Werkzeuge · Einstellungen), alle Werkzeuge als Bottom-Sheets (Spieler-Chips, Betrag-Stepper, Begründungen), jede Match-Einstellung erreichbar — Ablauf-Einstellungen (Modus, Runden, Teams, Special Rules …) nur in der Lobby, alles andere live |
| League Edition | Zweites Target `MonkeyMoneyLeague` (Compile-Flag `LEAGUE_EDITION`, Bundle `de.monkeymoney.league`, eigenes Icon): Katalog beim Start auf Runeterra gefiltert, Fragen-Set fest auf League, Beitreten-Seite mit Edition-Badge |
| League-Fragenpaket | **3100+ League-of-Legends-Fragen** in sechs Unterkategorien — ⚔️ Allgemein · 🧙 Champions & Fähigkeiten · 📜 Lore & Runeterra · 🏆 Esports & Pro-Szene · 🗺️ Spielmechanik & Items · 🎤 Skins, Musik & Arcane — von leicht bis ULTRAHARD (je 600+ pro Stufe), alle Formate (Choice, Wahr/Falsch, Schätzen, Sortieren, Mehrfach). Damit hat auch die League Edition eine echte Kategorien-Wahl. Generator: `tools/content/league_questions.py` (deterministisch, aus strukturierten Champion-/Esports-/Lore-Daten) |
| Flüster-Tipp | Show-Master flüstert einem einzelnen Spieler (Sheet mit Spickzettel-Tipps, „Antwort verraten“ oder Freitext) — erscheint auf genau diesem Handy als eigene Box über der Frage, mit Toast + Vibration |
| Übungsmodus | Solo-Quiz auf dem Handy gegen die iPad-Fragenbank (`/uebung`): Kategorie/Schwierigkeit/kindgerecht, Erklärungen, Serien-Statistik |
| Meta | Profile (PIN/Geräte-Erkennung), 85-Item-Shop, 4 Bestenlisten, Daily-/Monats-Quests, Bananen-Pass, Meilensteine |
| Audio | 22 eigene Musik-Tracks (Sonauto/Treblo v3), CC0/CC-BY-SFX, 50 Song-Snippets für die Musik-Formate; **Sound-Regie**: Stinger pro Phase, Auflösungs-Dreiklang (Zap → Trommelwirbel → Stille → Fanfare + Applaus-Stufe nach Gewinn), Siegerehrungs-Wirbel, Rad-Ticks |

## Screenshots

Aufgenommen im Browser gegen den Dev-Server (`tools/web/*.mjs`, iPad 11" quer bzw. iPhone hoch).

| | |
|---|---|
| ![Hauptmenü](docs/screenshots/01-hauptmenue.jpg) Hauptmenü | ![Modus](docs/screenshots/02-modus.jpg) Show wählen |
| ![Lobby](docs/screenshots/03-lobby.jpg) Lobby mit QR | ![Erklärkarte](docs/screenshots/04-erklaerkarte.jpg) Erklärkarte |
| ![Frage](docs/screenshots/05-frage.jpg) Frage (Kokosnuss-Uhr) | ![Auflösung](docs/screenshots/06-aufloesung.jpg) Auflösung (Schätzen) |
| ![Zwischenstand](docs/screenshots/07-zwischenstand.jpg) Zwischenstand | ![Glücksrad](docs/screenshots/08-gluecksrad.jpg) Glücksrad |
| ![Affenbank](docs/screenshots/09-affenbank.jpg) Affenbank | ![Stinkbanane](docs/screenshots/10-stinkbanane.jpg) Stinkbanane |
| ![Lianen-Finale](docs/screenshots/11-lianen-finale.jpg) Lianen-Finale | ![Siegerehrung](docs/screenshots/12-siegerehrung.jpg) Siegerehrung |
| ![Abspann](docs/screenshots/13-abspann.jpg) Abspann | ![Spiel geladen](docs/screenshots/16-spiel-geladen.jpg) Spielstand geladen |
| ![UNO](docs/screenshots/14-uno.jpg) Bananen-Batsche (UNO) mit iPad-Sitz | ![Siedler](docs/screenshots/15-siedler.jpg) Siedler vom Bananenhain |

**Handy**

![Handy](docs/screenshots/20-handy.jpg)

**Show-Master-Cockpit & Übungsmodus**

![Show-Master](docs/screenshots/21-showmaster.jpg)

## Ordner

```
MonkeyMoney/ios
├─ Core/          Foundation-only Kern — auch unter Linux kompilier- und testbar
│  ├─ Content/    Question/Song-Modelle, ContentCatalog (fragen.json, songs.json)
│  ├─ Rules/      Money, Economy, Settings/Blaupausen, Wheel, Jokers, SeededRandom
│  ├─ Engine/     EngineState, Engine (reduce/tick), Plan, Scoring, Wheel, Actions, Views
│  ├─ Minigames/  Plugin-Vertrag, ChoiceCore, alle 27 Formate
│  ├─ Boardgames/ Plugin-Vertrag + 6 Spiele
│  ├─ Protocol/   ClientMessage/ServerMessage, RoomHub (Sessions, Rechte, Broadcast)
│  ├─ Meta/       Profile, Shop, Bestenlisten, Quests
│  └─ Server/     HTTP/1.1 + WebSocket auf BSD-Sockets, ShowServer (Routen, REST-API)
│                 ShowHost = Menü/Lobby/Match-Lebenszyklus, Spielstände, Bots, Host-API (/api/host/*)
├─ App/           dünne SwiftUI-Hüllen: iPad = WKWebView auf /stage, iPhone = WebView-Beitreten
├─ Resources/     Web (die komplette Oberfläche), Fonts, Content, Audio, Monkeys, Assets
│  └─ Web/        Preact + htm (vendored, kein Build-Schritt)
│     ├─ stage/   Bühne: Menü, Lobby, alle Szenen, Extras, Brettspiele, Sound-Regie (regie.js)
│     ├─ player/  Handy-Controller      ├─ gm/      Show-Master-Cockpit
│     ├─ uebung/  Übungsmodus           └─ lib/     core, ui (Affen-SVGs), audio (Web Audio), prompts
├─ CoreTests/     swift test (Bot-Matches, Regeln, Protokoll, Meta)
├─ DevServer/     mm-dev-server — der echte Server auf Linux/macOS für Browser-Tests
├─ scripts/typecheck/  Linux-"SDK-Simulation" für die SwiftUI-Targets (inkl. WebKit-Shim)
├─ project.yml    XcodeGen (Targets MonkeyMoney + MonkeyMoneyLeague, universal iPhone/iPad)
└─ Package.swift  SwiftPM (Core + Tests + DevServer)
```

## So läuft ein Abend

1. **iPad**: App öffnen → „Neue Show starten“ → Modus (Quick / Klassik / Marathon / Custom) und
   Einstellungen wählen → „Lobby öffnen“. Die Lobby zeigt QR-Code, Raum-Code und die iPad-Adresse.
2. **Handys**: QR scannen. Safari öffnet `http://<ipad-ip>:8080/j/CODE` — Name, Affe, Farbe, „Rein da!“.
   Das Handy zeigt Runde, Fortschritt, das Jackpot-Glas (antippen = Erklärung), Erklärkarten als
   nummerierte Regeln mit Gewinn-Zeile und den eigenen Affen in jeder Wartephase.
3. **Show-Master (optional)**: In der Lobby „Show-Master · Code zeigen“ → zweiter QR + PIN.
   Das Handy zeigt das Regiepult (Spickzettel, Antworten, Werkzeuge). Ohne Show-Master führt das iPad
   („Starten, wenn alle da sind!“, Weiter-Knopf oben rechts oder Leertaste) — Auto-Regie verlängert Timer und pickt Kategorien.
4. **Fragen-Set**: In Modus-Auswahl, Lobby-Einstellungen, iPad-Regiepult und Browser-Cockpit (Tab „Fragen“) den
   Pool wählen — Preset antippen oder unter „Eigene Auswahl“ Kategorien/Unterkategorien an- und abwählen. Der
   Show-Master kann das auch mitten in der Show tun (gilt ab der nächsten Runde).
5. **Timer**: Der Show-Master (Handy-Pult, iPad-Regie oder Lobby-Einstellungen) kann den Fragen-Timer
   ganz ausschalten — Fragen warten dann, bis alle geantwortet haben oder er „Auflösen“ drückt — oder eine
   feste Zeit pro Frage (10 s … 2 min) setzen. Beides geht auch mitten im Match.
6. **Spielstand**: Autosave nach jeder Runde; drei manuelle Slots; beim App-Start „Weiterspielen?“.
7. **Spiele-Abend**: eigener Hauptmenü-Punkt; Spiel wählen, optional iPad-Sitze eintragen, los.
8. **Übungsmodus**: `http://<ipad-ip>:8080/uebung` (Link auf der Beitreten-Seite) — solo üben ohne Raum.

Alle Geräte müssen im selben WLAN sein. Kein Internet nötig.

### Bühne (iPad) — eine Web-App

Die gesamte Oberfläche (Bühne, Handys, Show-Master, Übungsmodus, Sounds) ist eine Web-App in
`Resources/Web`, ausgeliefert vom Swift-`ShowHost`. Die iPad-App startet den Host und zeigt
`http://127.0.0.1:<port>/stage` in einem WKWebView; genau dieselbe Seite läuft im Browser gegen den
Dev-Server. Die Bühne ist eine 1000 Einheiten hohe Leinwand (1400–1800 breit), uniform skaliert.
Menü, Spielstände und Show-Start laufen über die Host-API (`/api/host/state|start|load|save|delete|close|bots`,
auf dem iPad nur von Loopback erreichbar). Sounds: Web-Audio-Engine + `stage/regie.js` (Port der Swift-SoundRegie:
Auflösungs-Dreischlag, Trommelwirbel, Rad-Ticks, Momente). Tastatur: Leertaste/→ = Weiter, P = Pause.

### Warum kein App Clip?

App Clips startet iOS nur aus App-Store-/TestFlight-Builds mit registrierter Associated Domain — eine
sideload-IPA kann keinen auslösen. Die Spieler nutzen deshalb den Browser (QR → Safari); das frühere
Clip-Target wurde entfernt.

## Entwickeln

```bash
# Kern-Tests (Linux/macOS, Swift 6.1)
swift test --package-path MonkeyMoney/ios

# Linux-Typecheck des SwiftUI-Targets (klassisch + League Edition mit -D LEAGUE_EDITION)
MonkeyMoney/ios/scripts/typecheck/typecheck.sh

# Echter Server ohne iPad — komplette UI im Browser
swift run --package-path MonkeyMoney/ios mm-dev-server 8080
#  → http://localhost:8080/stage (Bühne inkl. Menü), /j/CODE (Handy), /gm?code=CODE (Regie), /uebung
# Optionen: league · demo=quick|klassik|marathon · bots=N · tempo=zackig · autostart · storage=DIR
swift run --package-path MonkeyMoney/ios mm-dev-server 8081 league demo=klassik bots=4 autostart
# Dev-API: /api/dev/next · stage · gm · player?id= · pin · code · formats?ids=a,b&fragen=2

# Browser-Tests (Playwright, starten den Dev-Server selbst; Screenshots + Audio-Log)
node tools/web/shoot.mjs  OUT                     # Host-Flow: Menü, Lobby, Regie, Spielstände, Übung
node tools/web/match.mjs  OUT klassik 780 4       # ganzes Match mit Bots (env FORMATS=a,b für einzelne Formate)
node tools/web/boards.mjs OUT                     # alle Brettspiele inkl. iPad-Sitz

# League-Fragenpaket neu erzeugen (schreibt fragen.json + taxonomie.json)
python3 tools/content/league_questions.py            # --dry-run zeigt nur die Statistik

# Xcode-Projekt erzeugen (Schemes MonkeyMoney + MonkeyMoneyLeague)
cd MonkeyMoney/ios && xcodegen generate
```

### Content & Assets neu bauen

```bash
python3 tools/content/compile_content.py <original-repo>   # fragen.json, taxonomie.json, songs.json, pixel/
tools/audio/convert_audio.sh <original-repo>              # SFX, Song-Snippets, Betten → AAC
python3 tools/art/render_monkeys.py                        # 14 Puppen × 8 Farben × 4 Gesichter → PNG
TREBLO_API_KEY=… python3 tools/music/generate_music.py     # Soundtrack (100 Credits pro Track)
```

## Credits

Fragen, Puppen-SVGs, Kosmetik und Song-Pipeline stammen aus dem Original-Projekt (siehe dessen
`CREDITS.md`). Musik-Tracks: generiert mit Sonauto/Treblo v3 (`Resources/Audio/Music/manifest.json`).
SFX: CC0 (BigSoundBank, Kenney) und CC BY (Kevin MacLeod, Tritachyon). Schriften: Outfit & Poppins (SIL OFL 1.1).
