# SoooDreamy — IPA build snapshot

Public build repo for the unsigned iOS 26 IPA. Source of truth stays in the private project; this tree is only the app + CI.

Sideload `SoooDreamy-unsigned.ipa` with [AltStore](https://altstore.io), [SideStore](https://sidestore.io) or Sideloadly. The IPA is not signed; those tools sign it with your Apple ID.

Workflow: Linux logic tests + typecheck, then `macos-26` / Xcode 26 unsigned `xcodebuild`. Download from Actions artifacts or the `sooodreamy-latest` prerelease.
