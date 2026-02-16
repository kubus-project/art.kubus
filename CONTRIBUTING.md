# Contributing to art.kubus (Client)

Thanks for your interest in contributing.

## Scope

This repository contains the open-source client and selected public platform artifacts.
Backend implementation and production operations remain proprietary unless explicitly published.

## Before you start

- Read `AGENTS.md` and `.github/copilot-instructions.md` for project guardrails.
- Check existing issues/PRs before opening a new one.
- Keep changes small and focused.

## Development flow

1. Fork the repository.
2. Create a branch from `main`.
3. Make changes with clear commit messages.
4. Run validation locally:
   - `flutter pub get`
   - `flutter analyze`
   - `flutter test`
5. Open a pull request with:
   - problem statement,
   - scope of change,
   - screenshots (if UI),
   - test notes.

## Coding expectations

- Respect feature flags and provider initialization order.
- Keep desktop/mobile parity when changing screens.
- Do not hardcode theme colors outside approved theme helpers.
- Do not introduce secrets, keys, or private credentials.

## Legal

By submitting a contribution, you agree your contribution is licensed under Apache-2.0 for this repository.
Trademark and brand usage remains governed by `TRADEMARK.md`.
Asset/content rights remain governed by `LICENSE_ASSETS.md`.

## Questions

For general help, open a discussion or issue.
For security issues, follow `SECURITY.md`.
