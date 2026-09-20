# 001: Use a manual informational update check

## Decision

CursorBar checks the fixed `smallyunet/cursorbar` GitHub Releases API only after
the user selects the update action. It validates that the returned release page
belongs to the same repository and opens that page on explicit request.

CursorBar does not download, replace, or relaunch the application.

## Rationale

The app is ad-hoc signed. Directly deleting and replacing the running bundle
cannot provide trustworthy artifact verification, atomic rollback, or a good
Gatekeeper experience. A manual release-page flow keeps the network and
supply-chain boundary small.

## Consequences

Users install updates deliberately from GitHub Releases. A future automatic
updater requires a separate decision covering Developer ID signing,
notarization, signature verification, atomic replacement, and rollback.
