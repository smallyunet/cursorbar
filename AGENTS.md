# CursorBar maintenance guide

Before changing usage semantics, credential handling, agent inference, update
behavior, or release automation, read:

1. `docs/contracts/behavior-contracts.yaml`
2. Relevant records in `docs/decisions/`
3. Existing regression tests

Preserve these boundaries:

- Never print or persist Cursor access tokens, session cookies, raw API
  responses, prompts, or transcript contents.
- Authenticated requests must use HTTPS and remain on the original Cursor host.
- Missing API fields must not be replaced with guessed quota or cost values.
- Agent monitoring remains local and its inferred nature stays visible.
- Update checks remain manual and informational.
- Pushes, tags, releases, and installation require explicit user authorization.

Run `./scripts/verify.sh` before merging behavior changes. Menu layout,
VoiceOver output, and first-launch Gatekeeper behavior still require validation
on a real Mac.
