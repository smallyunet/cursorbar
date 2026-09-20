#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/Resources/CursorBar.icns"
OUTPUT="${1:-}"

[[ -f "$SOURCE" ]] || { echo "error: icon source missing: $SOURCE" >&2; exit 1; }
[[ -n "$OUTPUT" ]] || { echo "usage: $0 /path/to/CursorBar.icns" >&2; exit 2; }

mkdir -p "$(dirname "$OUTPUT")"
cp "$SOURCE" "$OUTPUT"
echo "Installed app icon: $OUTPUT"
