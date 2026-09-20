#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

"$ROOT/scripts/check_contracts.sh"
swift test
"$ROOT/scripts/package.sh"
"$ROOT/scripts/verify_app.sh" "$ROOT/CursorBar.app"

echo "Full verification passed"
