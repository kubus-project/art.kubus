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
npm run qa:web
```

`verify:flutter:analyze` uses `flutter analyze --no-fatal-infos` so local
verification remains stable when the analyzer reports informational diagnostics.
Use plain `flutter analyze` when you need CI-strict behavior.

The root verification commands run maintained smoke suites, not every checked-in
test. Direct full-suite runs are still useful for investigation, but they are
not yet stable enough to be the default agent handoff gate.

`qa:web` is a Playwright browser smoke. Install its nested dependencies once
with `npm run qa:web:install`. It captures screenshots and diagnostics under
`output/playwright/artifacts/`.

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
CI uses the same script before deciding to run or explicitly skip backend checks.

Targeted profile media and CORS checks:

```powershell
cd backend
npx jest --runInBand avatarCorsRoutes.test.js uploadStaticCors.test.js serverCorsProdDefaults.test.js profilesMediaPersistence.test.js avatarProfileUploadRoutes.test.js
```
