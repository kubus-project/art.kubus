# Local Verification

Run these commands before opening or merging a PR.

## Stable root commands

From the repo root:

```powershell
npm run verify:architecture
npm run verify:docs
npm run verify:backend-status
npm run verify:flutter
npm run verify:backend
npm run verify:all
```

The verification runner resolves Flutter from `FLUTTER_BIN`, then from the
local Windows fallback `C:\dev\flutter\bin\flutter.bat`, then from PATH. If your
Flutter install lives elsewhere:

```powershell
$env:FLUTTER_BIN='D:\tools\flutter\bin\flutter.bat'
npm run verify:flutter
```

Targeted commands:

```powershell
npm run verify:flutter:analyze
npm run verify:flutter:smoke
npm run backend:status
npm run verify:backend:lint
npm run verify:backend:smoke
npm run docs:doctor
npm run qa:web:test
npm run qa:web
```

`verify:flutter:analyze` treats analyzer warnings and informational diagnostics
as fatal, matching CI.

`verify:flutter` runs analysis, the complete Flutter test suite with coverage,
and a release web build. `verify:backend` requires both backend gitlinks to be
present and aligned, then runs canonical backend lint plus the complete serial
Jest suite. `verify:all` adds pinned-toolchain, architecture, documentation, and
Android debug/unsigned-release build gates.

Root GitHub Actions jobs clone the private backend gitlinks after the public
root checkout. Configure `BACKEND_SUBMODULE_SSH_KEY` as the private half of a
dedicated read-only deploy key installed on `art.kubus-backend`. The checkout
script verifies GitHub's published Ed25519 host fingerprint and removes the
temporary runner key material after every fetch. Do not reuse a developer PAT
or a write-capable deployment key for this secret.

`qa:web` is a Playwright browser smoke. Install its nested dependencies once
with `npm run qa:web:install`. It captures screenshots and diagnostics under
`output/playwright/artifacts/`, uses deterministic API/socket stubs instead of
contacting production, and fails on page, console, HTTP, or unexpected request
errors. `qa:web:test` validates those stub and failure-classification contracts
without launching a browser.

`docs:doctor` checks required `AGENTS.md` files, local verification docs,
Markdown links in the docs index, and generated-artifact hygiene.

## Flutter app

Targeted profile media checks:

```powershell
npm run verify:flutter:analyze
npm run verify:flutter:smoke
flutter test test\providers\profile_provider_media_test.dart test\community\profile_edit_media_sync_test.dart
```

Formatting note: a full-tree Dart format gate is not enabled yet because
`dart format --output=none --set-exit-if-changed lib test` currently reports
hundreds of pre-existing files that would be reformatted. Add that CI gate only
with a separate formatting-only cleanup commit.

## Backend

```powershell
npm run backend:status
cd backend
npm ci
cd ..
npm run verify:backend
```

`backend:status` reports whether `backend/` is available as a checked-out
submodule, the backend HEAD, dirty state, and whether backend validation can run.
It also reports `backend-open-art-wt` mirror configuration, HEAD, and dirty state
so the auxiliary backend worktree cannot silently drift. CI requires both
gitlinks and fails when either is missing or points at a different commit.

Targeted profile media and CORS checks:

```powershell
cd backend
npx jest --runInBand avatarCorsRoutes.test.js uploadStaticCors.test.js serverCorsProdDefaults.test.js profilesMediaPersistence.test.js avatarProfileUploadRoutes.test.js
```
