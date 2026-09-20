#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="CursorBar"
APP_BUNDLE="$ROOT/$APP_NAME.app"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
ARCHITECTURES="${ARCHITECTURES:-}"

cd "$ROOT"

BUILD_ARGS=(-c release)
if [[ -n "$ARCHITECTURES" ]]; then
    read -r -a ARCH_LIST <<< "$ARCHITECTURES"
    for arch in "${ARCH_LIST[@]}"; do
        BUILD_ARGS+=(--arch "$arch")
    done
fi

echo "Building $APP_NAME..."
swift build "${BUILD_ARGS[@]}"
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
BIN_PATH="$BIN_DIR/$APP_NAME"
[[ -x "$BIN_PATH" ]] || { echo "error: executable not found: $BIN_PATH" >&2; exit 1; }

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
"$ROOT/scripts/build_icon.sh" "$APP_BUNDLE/Contents/Resources/CursorBar.icns"

if [[ "$SIGN_IDENTITY" != "none" ]]; then
    if [[ "$SIGN_IDENTITY" == "-" ]]; then
        codesign --force --options runtime --timestamp=none \
            --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
    else
        codesign --force --options runtime --timestamp \
            --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
    fi
fi

echo "Built $APP_BUNDLE"

if [[ "${1:-}" == "--install" ]]; then
    echo "Installing to /Applications..."
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP_BUNDLE" "/Applications/$APP_NAME.app"
    xattr -cr "/Applications/$APP_NAME.app" 2>/dev/null || true
    echo "Installed /Applications/$APP_NAME.app"
fi

if [[ "${1:-}" == "--open" || "${2:-}" == "--open" ]]; then
    bash "$ROOT/scripts/launch.sh"
fi
