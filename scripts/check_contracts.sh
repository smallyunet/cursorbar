#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTRACTS="$ROOT/docs/contracts/behavior-contracts.yaml"

[[ -f "$CONTRACTS" ]] || { echo "Missing behavior contracts" >&2; exit 1; }

python3 - "$ROOT" "$CONTRACTS" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
text = Path(sys.argv[2]).read_text()
ids = re.findall(r"^\s+- id: ([A-Z0-9-]+)$", text, re.MULTILINE)
if not ids or len(ids) != len(set(ids)):
    raise SystemExit("Contracts must have unique IDs")

guards = re.findall(r"^\s+- ((?:Sources|Tests|scripts|\.github)/\S+)$", text, re.MULTILINE)
missing = [guard for guard in guards if not (root / guard).exists()]
if missing:
    raise SystemExit("Missing contract guards: " + ", ".join(missing))

print(f"Validated {len(ids)} behavior contracts")
PY
