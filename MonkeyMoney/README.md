# 🐒 MONKEY MONEY — Swift-Port

**Die Quiz-Show fürs Wohnzimmer, jetzt nativ.** Das iPad ist Bühne, Server und
Spielstandspeicher; die iPhones der Gäste sind die Controller — per QR-Code
im Browser (immer) oder in der App / als App Clip. Ein Show-Master ist optional
und bekommt in der Lobby einen eigenen, ein- und ausblendbaren QR-Code.

Download: **[monkeymoney-latest](https://github.com/MedusaV9/TestIOs/releases/tag/monkeymoney-latest)**
(unsignierte IPA aus GitHub Actions — mit AltStore / SideStore / Sideloadly signieren).

## Was drin ist

| Bereich | Umfang |
| --- | --- |
| Fragen | 7.660 validierte Fragen, 14 Ober-/90 Unterkategorien, 7 Typen, 4 Schwierigkeiten (inkl. ULTRAHARD), 12 Pixel-Bilderrätsel |
| Show | Lobby → Opening → Runden (Kategorien-Voting, Erklärkarte, Fragen, Zwischenstand, Glücksrad) → Jackpot-Frage → Lianen-Finale → Highlights → Siegerehrung → Abspann/Revanche |
| Formate | 27: Bananen-Basics, Vier Lianen, Kokosnuss-Uhr, Bananen-Tresor, Affenleiter, Pixel-Dschungel, Affenbank, Stinkbanane, Taschendieb, Alles oder Banane, Lianen-Finale, Monkey Market, Bananen-Börse, Affen-Auktion, Bananen-Bluff, Lianensteg-Duell, Boxkampf, Konter-Quiz, Einer gegen alle, Tortenschlacht, Risiko-Leiter, Goldener Affe, Blitz-DJ, Rückwärts-Banane, Stummfilm-Studio, Wer singt's?, 7-Buchstaben-Telegramm |
| Brettspiele | Werwölfe vom Bananenhain, Bananen-Batsche (UNO), Affen ärgern sich nicht, Bananopoly, Affenturm, Siedler vom Bananenhain — Handys und/oder iPad-Sitze (Pass-and-Play) |
| Ökonomie | 100/250/500/1.000 MM, Speed-Knick, Streak ×1,5/×2, Rückenwind mit Überhol-Kappe, Jackpot-Glas, Dispo −500, Schuldenerlass, Mitleids-Banane, W_final-Formel, AT-Umrechnung, Level |
| Systeme | 7 Joker, 15 Rad-Segmente (Pech-Schutz, Pity-Timer, Fair-Finale-Pool), 7 Special Rules, Teams, Familien-/18+-Modus, 17 GM-Werkzeuge + Auto-GM, Pause, Save-Slots, Revanche |
| Meta | Profile (PIN/Geräte-Erkennung), 85-Item-Shop, 4 Bestenlisten, Daily-/Monats-Quests, Bananen-Pass, Meilensteine |
| Audio | 22 eigene Musik-Tracks (Sonauto/Treblo v3), CC0/CC-BY-SFX, 50 Song-Snippets für die Musik-Formate |

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
├─ App/           SwiftUI — Host (iPad), Player (iPhone), Design, Audio
├─ Clip/          App-Clip-Target (nutzt App/Player)
├─ Resources/     Web (Browser-Client), Fonts, Content, Audio, Monkeys (PNG-Puppen), Assets
├─ CoreTests/     swift test (Bot-Matches, Regeln, Protokoll, Meta)
├─ DevServer/     mm-dev-server — der echte Server auf Linux/macOS für Browser-Tests
├─ scripts/typecheck/  Linux-"SDK-Simulation" für die SwiftUI-Targets
├─ project.yml    XcodeGen (Targets MonkeyMoney + MonkeyMoneyClip)
└─ Package.swift  SwiftPM (Core + Tests + DevServer)
```

## So läuft ein Abend

1. **iPad**: App öffnen → „Neue Show starten“ → Modus (Quick / Klassik / Marathon / Custom) und
   Einstellungen wählen → „Lobby öffnen“. Die Lobby zeigt QR-Code, Raum-Code und die iPad-Adresse.
2. **Handys**: QR scannen. Safari öffnet `http://<ipad-ip>:8080/j/CODE` — Name, Affe, Farbe, „Rein da!“.
   Wer die App installiert hat, kann stattdessen in der App den QR scannen (gleicher Ablauf, nativ).
3. **Show-Master (optional)**: In der Lobby „Show-Master-Code einblenden“ → zweiter QR + PIN.
   Das Handy zeigt das Regiepult (Spickzettel, Antworten, Werkzeuge). Ohne Show-Master führt das iPad
   („Starten, wenn alle da sind!“, Weiter-Knopf unten rechts) — Auto-Regie verlängert Timer und pickt Kategorien.
4. **Spielstand**: Autosave nach jeder Runde; drei manuelle Slots; beim App-Start „Weiterspielen?“.
5. **Spiele-Abend**: eigener Hauptmenü-Punkt; Spiel wählen, optional iPad-Sitze eintragen, los.

Alle Geräte müssen im selben WLAN sein. Kein Internet nötig.

### App Clip

Das Target `MonkeyMoneyClip` ist angelegt (Invocation-URL `https://<domain>/j/CODE?host=<ip:port>`,
AASA-Route im Server). App Clips werden von iOS **nur** aus App-Store-/TestFlight-Builds mit registrierter
Associated Domain gestartet — eine unsignierte IPA kann keinen App Clip auslösen. Für Sideload-Builds
bleiben deshalb Safari (QR) und die installierte App (QR-Scanner, `monkeymoney://join?code=…&host=…`).

## Entwickeln

```bash
# Kern-Tests (Linux/macOS, Swift 6.1)
swift test --package-path MonkeyMoney/ios

# Linux-Typecheck der SwiftUI-Targets (App + Clip)
MonkeyMoney/ios/scripts/typecheck/typecheck.sh

# Echter Server ohne iPad — Browser-Client testen
swift run --package-path MonkeyMoney/ios mm-dev-server 8080 quick
#  → http://<ip>:8080/j/CODE (Spieler), /gm?code=CODE (Regie), /api/dev/next (Bühnen-„Weiter“)

# Xcode-Projekt erzeugen
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
