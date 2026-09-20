# Contributing

Thanks for your interest in CursorBar!

## How to contribute

This repository accepts contributions via **pull requests only**. You cannot push directly to `main`.

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

## Branch protection

The `main` branch is protected by a GitHub ruleset:

- Pull requests are required before merging
- Force pushes and branch deletion are blocked
- The repository owner has bypass permissions for direct maintenance

Do not request write access to this repository — fork and open a PR instead.
