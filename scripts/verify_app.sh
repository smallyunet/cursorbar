#!/usr/bin/env bash
set -euo pipefail

APP="${1:-}"
[[ -n "$APP" ]] || { echo "usage: $0 /path/to/CursorBar.app" >&2; exit 2; }
EXECUTABLE="$APP/Contents/MacOS/CursorBar"
PLIST="$APP/Contents/Info.plist"
ICON="$APP/Contents/Resources/CursorBar.icns"

[[ -d "$APP" ]] || { echo "error: app missing: $APP" >&2; exit 1; }
[[ -x "$EXECUTABLE" ]] || { echo "error: executable missing" >&2; exit 1; }
[[ -f "$PLIST" ]] || { echo "error: Info.plist missing" >&2; exit 1; }
[[ -f "$ICON" ]] || { echo "error: icon missing" >&2; exit 1; }

plutil -lint "$PLIST"
test "$(plutil -extract CFBundleIdentifier raw -o - "$PLIST")" = "com.smallyunet.cursorbar"
test "$(plutil -extract CFBundleIconFile raw -o - "$PLIST")" = "CursorBar"
codesign --verify --strict "$APP"

if [[ -n "${EXPECTED_ARCHITECTURES:-}" ]]; then
    actual="$(lipo -archs "$EXECUTABLE")"
    for expected in $EXPECTED_ARCHITECTURES; do
        case " $actual " in
            *" $expected "*) ;;
            *) echo "error: missing architecture $expected" >&2; exit 1 ;;
        esac
    done
fi

signature="$(codesign -dvv "$APP" 2>&1 || true)"
case "$signature" in
    *"flags="*"runtime"*) ;;
    *) echo "error: hardened runtime flag missing" >&2; exit 1 ;;
esac

echo "Verified $APP"
