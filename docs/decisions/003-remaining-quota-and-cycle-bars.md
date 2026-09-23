# 003: Show remaining quota and billing-cycle countdown

## Decision

CursorBar presents included quota as remaining capacity, not as a fill-up of
usage. The menu bar shows only the remaining monthly percentage. The dropdown
pairs that remaining quota bar with a billing-cycle remaining bar derived from
the server-provided cycle start and end.

Daily utilization is not shown. It divided total quota by weekday count and is
not a Cursor-reported value.

## Rationale

Remaining-state bars make quota and renewal timing comparable, matching the
Codex Notch countdown presentation. Estimated daily budgets would invent a
spend plan the API does not provide.

## Consequences

Used percentages stay in memory only as inputs to remaining calculations.
Missing cycle timestamps hide reset progress instead of assuming a 30-day
month. Monetary values come only from their matching structured API fields:
`overall` for the included pool, `plan` for Other Models, and `onDemand` for
on-demand usage. CursorBar does not infer limits from percentages, apply plan
credit floors, parse percentages from display prose, or substitute one pool's
percentage for the blended menu-bar value. Menu-bar agent counts and overspend
badges are no longer part of the status item. The status item uses the original
single quota icon beside the remaining percentage.
