# 002: Keep agent monitoring local and heuristic

## Decision

CursorBar derives agent activity from recent transcript modification times and
Cursor-owned values in `state.vscdb`. Reads run off the main actor and only the
resulting snapshot is published to the UI.

## Rationale

Cursor exposes no stable public agent-status API. Local state preserves privacy
and enables useful status indicators, but write debouncing and internal schema
changes mean the result cannot be authoritative.

## Consequences

The UI and documentation describe agent counts as inferred. Parse failures
produce empty values rather than invented states. Changes to Cursor's internal
keys require fixture-backed parser updates.
