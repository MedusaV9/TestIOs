# Linux SDK simulation (`typecheck.sh`)

There is no Xcode on Linux, so the SwiftUI app cannot be compiled here. This
harness fills the gap: it builds **stub modules** that mirror the API surface
SoooDreamy uses from Apple's SDK (SwiftUI, UIKit, WidgetKit, ActivityKit,
AppIntents, AVFoundation, CoreHaptics, CryptoKit, CloudKit, …) and runs
`swiftc -typecheck` over the real app and widget sources against them.

```sh
scripts/typecheck/typecheck.sh          # app + widget extension
scripts/typecheck/typecheck.sh app
scripts/typecheck/typecheck.sh widgets
TYPECHECK_DEBUG=1 scripts/typecheck/typecheck.sh   # also define DEBUG
```

Exit code 0 means every file type-checked. Diagnostics are printed with the
real source paths; full logs land in `.typecheck-build/*.log`.

## What it catches / what it cannot

Caught: undefined symbols, wrong argument labels, type mismatches,
non-exhaustive switches, missing protocol requirements, result-builder
limits (10 views per block), actor-isolation errors, `@MainActor`
misuse — everything the type checker sees. A mutation test with five
injected mistakes (wrong label, unknown member, unknown `Color`, wrong
type, missing `switch` case) reports all five.

Not caught: runtime behaviour, layout, SDK signatures the stubs model too
loosely, linking, resources, entitlements. When the stubs are wrong, the
check lies — keep them faithful to Apple's documented signatures.

Runtime behaviour of pure logic is covered separately by the SwiftPM
package (`swift test --package-path ios`): Foundation-only files under
`Core/` (rules, search index, invitation links, L10n) run as real code
on Linux. Move logic there when it should be *tested*, not just typed.

## Alternatives evaluated (and why they are not used)

Three "run iOS on Linux" routes were checked against their sources:

- `MarbleLabs1/IOS-emulator` boots a generic `qemu-system-aarch64 -M virt`
  UEFI VM; its firmware script is a self-declared placeholder. A generic
  ARM64 VM cannot boot iOS (iBoot/SPTM/SoC emulation missing). Nothing
  iOS is ever downloaded or run.
- `touchHLE/touchHLE` re-implements iPhone OS 2.x/3.0 frameworks for
  32-bit ARMv6 apps and states "never: 64-bit iOS". Out of scope for an
  arm64 / iOS 26 / SwiftUI app.
- `jprx/darwin-vm` boots real iOS 26/27 kernels (A14–A19) in a QEMU fork
  to a root shell, also on x86_64. By its own README it has no display,
  GUI, or SpringBoard, so it cannot render UIKit/SwiftUI; its setup step
  needs macOS (`hdiutil` to patch the ramdisk) and building anything for
  it needs Apple's iOS toolchain, which does not exist for Linux.

Conclusion: only a macOS runner renders the UI. This harness gates that
runner; the SwiftPM tests cover behaviour that does not need a screen.

## Layout

- `Shims/<Module>/*.swift` — one directory per Apple module. `DarwinShims` is
  imported implicitly into every file and holds Foundation/CoreGraphics
  declarations missing from swift-corelibs-foundation (`CGAffineTransform`,
  `LocalizedStringResource`, `UndoManager`, `Selector`, …).
  `CoreImage/clang/module.modulemap` exists only so
  `import CoreImage.CIFilterBuiltins` resolves; the API lives in the Swift
  overlay next to it.
- `allowlist.txt` — regexes for diagnostics that are artefacts of the Linux
  simulation (each with a justification). Anything else fails the run.
- `typecheck.sh` — builds the modules in dependency order (incrementally),
  copies the sources to a scratch dir where `@objc` / `#selector(` are
  rewritten (no Objective-C runtime on Linux), type-checks with
  `-swift-version 5` like the Xcode project, and maps paths back.

## Conventions that matter for fidelity

- `View`, `App`, `Scene`, `ViewModifier`, `Widget` are `@MainActor
  @preconcurrency` (iOS 18+ SDK). UIKit classes are `@preconcurrency
  @MainActor` so isolation violations are warnings in Swift 5 mode, exactly
  like Objective-C-imported declarations.
- `.task`, `.refreshable` closures are `@_inheritActorContext @Sendable`.
- Result builders return `C?` from `buildIf` and `_Conditional…<T, F>` from
  `buildEither` — the generic parameter must flow through the return type or
  `if` inside a builder fails to infer.
- Deprecated overloads that would be ambiguous with their replacements
  (`background(_ view:)`) are `@_disfavoredOverload`.
- `LocalizedStringKey` vs `StringProtocol` initializer pairs are declared
  exactly as in the SDK so literal vs. variable arguments resolve the same way.

When the app starts using new SDK API, extend the matching stub. Prefer the
documented signature over a permissive one.
