#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="${1:-${DIST_DIR:-$ROOT/dist}}"
VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$ROOT/Resources/Info.plist")"
ARCHIVE_ARCH="${ARCHIVE_ARCH:-$(uname -m)}"
APP="$ROOT/CursorBar.app"
ARCHIVE="$DIST/CursorBar-$VERSION-macOS-$ARCHIVE_ARCH.zip"

if [[ -n "${GITHUB_REF_NAME:-}" && "$GITHUB_REF_NAME" != "v$VERSION" ]]; then
    echo "error: tag $GITHUB_REF_NAME does not match app version v$VERSION" >&2
    exit 1
fi

mkdir -p "$DIST"
"$ROOT/scripts/check_contracts.sh"
swift test --package-path "$ROOT"
"$ROOT/scripts/package.sh"
"$ROOT/scripts/verify_app.sh" "$APP"

rm -f "$ARCHIVE"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"
(
    cd "$(dirname "$ARCHIVE")"
    shasum -a 256 "$(basename "$ARCHIVE")"
) | tee "$ARCHIVE.sha256"

echo "Release archive: $ARCHIVE"
