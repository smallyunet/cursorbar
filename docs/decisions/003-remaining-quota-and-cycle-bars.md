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
month. Menu-bar agent counts, overspend badges, and gauge icon styles are no
longer part of the status item.
