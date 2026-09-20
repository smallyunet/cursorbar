# Contributing

Thanks for your interest in CursorBar!

## How to contribute

External contributions should come in as pull requests. The maintainer can push directly to `main` for release work.

1. Fork the repository
2. Create a feature branch in your fork
3. Make your changes
4. Open a pull request against `main`

## Who can merge

Only the repository owner can merge pull requests and push to `main`. External contributors can open PRs but cannot merge them.

## Before submitting

- Run the full verification harness with `bash scripts/verify.sh`
- Verify API access: `.build/release/CursorBar --status`
- For usage, privacy, agent, update, or release changes, preserve the contracts
  in `docs/contracts/behavior-contracts.yaml` and add a regression guard.

## Branch policy

This independent distribution does not use GitHub branch protection or rulesets on `main`. External contributors should still fork and open a PR rather than requesting write access.
