#!/usr/bin/env bash
# Monkey Money — Linux "SDK simulation" for the iOS app.
#
# There is no Xcode on Linux, so `swift build` cannot compile SwiftUI code
# here. This script builds a set of *stub* modules (SwiftUI, UIKit, WidgetKit,
# ActivityKit, AVFoundation, …) that mirror the API surface the app uses,
# then runs `swiftc -typecheck` on the real app sources against them.
#
# What it catches: undefined symbols, wrong argument labels, type mismatches,
# non-exhaustive switches, missing protocol requirements, actor-isolation
# errors — i.e. everything the type checker sees. What it cannot catch:
# runtime behaviour, SDK signatures the stubs model too loosely, linking.
#
# Usage:
#   scripts/typecheck/typecheck.sh            # app
#   scripts/typecheck/typecheck.sh app        # app target only
#   TYPECHECK_DEBUG=1 …                       # also define DEBUG
#
# The stub sources live in ./Shims/<ModuleName>/. Extend them when the app
# starts using new SDK API — keep the signatures faithful to Apple's docs,
# otherwise the check lies.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS="$(cd "$HERE/../.." && pwd)"
SHIMS="$HERE/Shims"
BUILD="${TYPECHECK_BUILD_DIR:-$IOS/.typecheck-build}"
MODULES="$BUILD/modules"
SCRATCH="$BUILD/src"
mkdir -p "$MODULES" "$SCRATCH"

TARGET="${1:-all}"

# Xcode builds the app in Swift 5 language mode with minimal concurrency
# checking (see project.yml) — mirror that exactly.
COMMON_FLAGS=(-swift-version 5 -parse-as-library -I "$MODULES"
              -Xcc -fmodule-map-file="$SHIMS/CoreImage/clang/module.modulemap" -I "$SHIMS/CoreImage/clang")
# Foundation on Linux keeps URLSession & friends in FoundationNetworking, and
# a few Darwin-only Foundation/CoreGraphics types live in our DarwinShims —
# import both implicitly so the app sources stay untouched.
IMPLICIT=(-Xfrontend -import-module -Xfrontend FoundationNetworking
          -Xfrontend -import-module -Xfrontend DarwinShims)

log() { printf '\033[1;34m[typecheck]\033[0m %s\n' "$*"; }

build_module() {
    local name="$1"; shift
    local extra=("$@")
    local out="$MODULES/$name.swiftmodule"
    local srcs=("$SHIMS/$name"/*.swift)
    # Rebuild only when a shim source is newer than the module.
    if [[ -f "$out" ]] && ! find "${srcs[@]}" -newer "$out" -print -quit | grep -q .; then
        return
    fi
    log "building stub module $name"
    swiftc -emit-module -module-name "$name" -emit-module-path "$out" \
        "${COMMON_FLAGS[@]}" "${extra[@]}" "${srcs[@]}"
    # swift-frontend leaves an unchanged .swiftmodule untouched (moveFileIfDifferent),
    # so bump the timestamp ourselves or the freshness check rebuilds forever.
    touch "$out"
}

# Order matters: each module may only depend on the ones built before it.
build_module DarwinShims
build_module Combine "${IMPLICIT[@]}"
build_module UIKit "${IMPLICIT[@]}"
build_module Security "${IMPLICIT[@]}"
build_module UniformTypeIdentifiers "${IMPLICIT[@]}"
build_module CoreTransferable "${IMPLICIT[@]}"
build_module SwiftUI "${IMPLICIT[@]}"
build_module CoreImage "${IMPLICIT[@]}" -import-underlying-module
build_module ImageIO "${IMPLICIT[@]}"
build_module AVFoundation "${IMPLICIT[@]}"
build_module AVKit "${IMPLICIT[@]}"
build_module VisionKit "${IMPLICIT[@]}"
build_module Photos "${IMPLICIT[@]}"
build_module PhotosUI "${IMPLICIT[@]}"
build_module CoreHaptics "${IMPLICIT[@]}"
build_module LocalAuthentication "${IMPLICIT[@]}"
build_module CommonCrypto "${IMPLICIT[@]}"
build_module CryptoKit "${IMPLICIT[@]}"
build_module CloudKit "${IMPLICIT[@]}"
build_module UserNotifications "${IMPLICIT[@]}"
build_module BackgroundTasks "${IMPLICIT[@]}"
build_module Charts "${IMPLICIT[@]}"
build_module AppIntents "${IMPLICIT[@]}"
build_module ActivityKit "${IMPLICIT[@]}"
build_module WidgetKit "${IMPLICIT[@]}"

# Darwin-only *syntax* that has no Linux equivalent is substituted on a
# scratch copy (line numbers are preserved, error paths are mapped back):
#   @objc            -> removed      (no Objective-C runtime on Linux)
#   #selector(...)   -> Selector(...) (DarwinShims.Selector accepts any method ref)
prepare_sources() {
    local rel out
    rm -rf "$SCRATCH"; mkdir -p "$SCRATCH"
    while IFS= read -r -d '' f; do
        rel="${f#"$IOS"/}"
        out="$SCRATCH/$rel"
        mkdir -p "$(dirname "$out")"
        if grep -qE '@objc\b|#selector\(' "$f"; then
            sed -E 's/@objc(Members)?\b//g; s/#selector\(/Selector(/g' "$f" > "$out"
            log "substituted Darwin-only syntax in $rel"
        else
            cp "$f" "$out"
        fi
    done < <(find "$IOS/App" "$IOS/Core" -name '*.swift' -print0)
}

typecheck_target() {
    local name="$1"; shift
    local dirs=("$@")
    local files=()
    while IFS= read -r -d '' f; do files+=("$f"); done \
        < <(find "${dirs[@]/#/$SCRATCH/}" -name '*.swift' -print0 | sort -z)
    local defines=()
    [[ "${TYPECHECK_DEBUG:-0}" == "1" ]] && defines=(-D DEBUG)
    log "typechecking $name (${#files[@]} files)"
    local logf="$BUILD/$name.log"
    set +e
    swiftc -typecheck -continue-building-after-errors -module-name "$name" \
        "${COMMON_FLAGS[@]}" "${IMPLICIT[@]}" "${defines[@]}" "${files[@]}" > "$logf" 2>&1
    local status=$?
    set -e
    # Map scratch paths back to the real sources.
    sed -i "s#$SCRATCH/#$IOS/#g" "$logf"
    # Drop diagnostics that are artefacts of the Linux simulation (see allowlist.txt).
    local real_errors
    real_errors=$(grep ': error:' "$logf" | grep -vEf <(grep -vE '^\s*(#|$)' "$HERE/allowlist.txt") | sort -u || true)
    local allowed
    allowed=$(grep ': error:' "$logf" | grep -Ef <(grep -vE '^\s*(#|$)' "$HERE/allowlist.txt") | sort -u | wc -l || true)
    local warnings
    warnings=$(grep -c ': warning:' "$logf" || true)
    if [[ -n "$real_errors" ]]; then
        echo "$real_errors" | head -400
        log "$name: FAILED with $(echo "$real_errors" | wc -l) error(s) ($allowed allow-listed Linux-only) — full log: $logf"
        return 1
    fi
    log "$name: OK (0 errors, $allowed allow-listed Linux-only, $warnings warning(s)) — log: $logf"
}

prepare_sources

rc=0
case "$TARGET" in
    app|all) typecheck_target MonkeyMoney App Core || rc=1 ;;
    *) echo "unknown target: $TARGET (app|all)" >&2; exit 2 ;;
esac
exit $rc
