# Contributing to art.kubus

Thanks for your interest in art.kubus. This guide is the shortest path from a fresh clone to a merged pull request.

## Scope

This repository contains the open-source Flutter client and selected public platform artifacts. The backend (`backend/` submodule, `art.kubus-backend`) and production operations are separate and not open by default. See [`docs/OPEN_PLATFORM.md`](docs/OPEN_PLATFORM.md). Client-only contributions never need backend access.

## 1. Prerequisites

- Flutter **3.44.2**, the version pinned in [`.fvmrc`](.fvmrc). `fvm use` or `puro` pick it up automatically.
- Git.
- A target platform: Chrome is the quickest. Android, iOS and desktop setup is in [`docs/GETTING_STARTED.md`](docs/GETTING_STARTED.md).
- Node.js 22 only if you work on `scripts/` or the Playwright web QA.

## 2. Clone and install

```bash
git clone https://github.com/kubus-project/art.kubus.git
cd art.kubus
git switch dev
flutter pub get
```

You do not need the `backend/` submodule. Leave it uninitialized unless a maintainer has given you access.

## 3. Run

```bash
flutter run -d chrome
```

By default the app uses the public API at `https://api.kubus.site`, so maps, artworks and profiles load without any setup. Signing in works with a normal account on that API.

## 4. Configure a backend (optional)

The API base URL and other settings are build-time defines read in [`lib/config/config.dart`](lib/config/config.dart) and [`lib/config/api_keys.dart`](lib/config/api_keys.dart):

```bash
flutter run -d chrome --dart-define=BACKEND_BASE_URL=http://localhost:3000
```

Never commit real keys, tokens or `.env` files. See [`SECURITY.md`](SECURITY.md).

## 5. Test, format and lint

Run these before opening a pull request:

```bash
dart format <files you changed>
flutter analyze
flutter test
```

Format only the files you touched. Running `dart format .` over the whole tree creates unrelated churn. `flutter analyze` includes the project lints in [`packages/kubus_lints/`](packages/kubus_lints/), which enforce theme tokens instead of raw colors, borders and backdrop filters.

To run a single test file:

```bash
flutter test test/path/to/some_test.dart
```

The broader verification commands (`npm run verify:*`, Playwright web QA) are listed in [`docs/LOCAL_VERIFICATION.md`](docs/LOCAL_VERIFICATION.md). CI runs the relevant subset automatically.

## 6. Branches and pull requests

- Start from the current `origin/dev`, the integration branch: `git fetch origin && git switch -c fix/my-change origin/dev`. `master` is production only.
- Name your branch `feature/`, `fix/`, `docs/`, `refactor/`, `ci/` or `chore/` followed by a short description, for example `fix/qr-scanner-tooltips`.
- Keep a pull request to one change. Small PRs get reviewed faster.
- Open an ordinary pull request targeting `dev`. CI rejects PRs into `master` from anything other than `dev` or `hotfix/*`.
- Fill in the PR template. Include screenshots for any visible change, on both a narrow (mobile) and a wide (desktop) layout where the screen has both.
- Resolve review conversations before merge. The branch rules require it.

Production releases are merge-commit pull requests from `dev` to `master`. Emergency `hotfix/*` branches start from `master`, target `master`, and are then reconciled into `dev`. The full branch, release and deployment model is in [`docs/engineering/branching-and-deployment.md`](docs/engineering/branching-and-deployment.md).

## 7. Find something to work on

- [`good first issue`](https://github.com/kubus-project/art.kubus/labels/good%20first%20issue): small, well-described tasks with named files and acceptance criteria.
- [`help wanted`](https://github.com/kubus-project/art.kubus/labels/help%20wanted): larger tasks where outside help is welcome.
- [`accessibility`](https://github.com/kubus-project/art.kubus/labels/accessibility) and [`localization`](https://github.com/kubus-project/art.kubus/labels/localization) are good areas to start in.

Comment on an issue before starting so nobody duplicates work. If you want to build something that has no issue yet, open a discussion or feature request first.

## 8. Coding expectations

- Match the surrounding code. [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) explains the provider-first structure and boot sequence.
- Respect feature flags and provider initialization order.
- Keep mobile and desktop parity when you change a screen. Many screens have a separate desktop layout under `lib/screens/desktop/`.
- Use theme helpers and tokens, never hardcoded colors.
- User-visible text goes through `AppLocalizations`. Add every new key to both `lib/l10n/app_en.arb` and `lib/l10n/app_sl.arb`, then run `flutter gen-l10n`. Regeneration drops a hand-kept locale guard in `lib/l10n/app_localizations.dart`; restore it so that `git diff dev -- lib/l10n/app_localizations.dart` shows only additions. `test/l10n/` fails if the guard is missing.
- Brand names are lowercase: `art.kubus`, `kubus`, `kubus Node`.
- Do not add secrets, keys or private credentials.

Maintainers and automated agents also follow [`AGENTS.md`](AGENTS.md) and [`.github/copilot-instructions.md`](.github/copilot-instructions.md).

## 9. Ask questions

- Usage or setup questions: [Discussions, Q&A](https://github.com/kubus-project/art.kubus/discussions/categories/q-a).
- Ideas and proposals: [Discussions, Ideas](https://github.com/kubus-project/art.kubus/discussions/categories/ideas).
- Reproducible bugs: [open an issue](https://github.com/kubus-project/art.kubus/issues/new/choose).
- Security vulnerabilities: follow [`SECURITY.md`](SECURITY.md) and report privately, never in a public issue.

## Legal

By submitting a contribution, you agree that it is licensed under MPL-2.0 for this repository (or Apache-2.0 for contributions to a file explicitly designated as a public platform API artifact), unless explicitly agreed otherwise in writing with the maintainers.
Trademark and brand usage remains governed by [`TRADEMARK.md`](TRADEMARK.md).
Asset and content rights remain governed by [`LICENSE_ASSETS.md`](LICENSE_ASSETS.md).

Contributors and agents must not merge pull requests or deploy production without explicit maintainer authorization. Participation follows the [Code of Conduct](CODE_OF_CONDUCT.md).
