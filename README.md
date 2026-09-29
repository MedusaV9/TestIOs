# TestIOs — iOS build snapshots

- **[Monkey Money](MonkeyMoney/README.md)** — Party-Quiz-Show, Swift/SwiftUI-Port: iPad = Bühne + Server, iPhone/App Clip/Browser = Controller. Workflow `Monkey Money IPA`, Download [monkeymoney-latest](https://github.com/MedusaV9/TestIOs/releases/tag/monkeymoney-latest).
- **SoooDreamy** — siehe unten.

---

# SoooDreamy — IPA build snapshot

Build snapshot for the unsigned iOS 26 IPA. Source of truth stays in the private project; this tree is only the app + CI.

**Current client: 5.0.0 (28)** — allows `http://ark.atomi23.de:7792` (AMP). Sideload `SoooDreamy-unsigned.ipa` with [AltStore](https://altstore.io), [SideStore](https://sidestore.io) or Sideloadly. The IPA is not signed; those tools sign it with your Apple ID.

Download: [sooodreamy-latest](https://github.com/MedusaV9/TestIOs/releases/tag/sooodreamy-latest)

After install, the server screen must show **App-Build 5.0.0 (28) · HTTPS, AMP-HTTP für ark.atomi23.de**. If it still says “HTTPS geschützt”, the old IPA is still on the phone — delete the app first.

Workflow: Linux logic tests + typecheck, then `macos-26` / Xcode 26 unsigned `xcodebuild`.
