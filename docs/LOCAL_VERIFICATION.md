# Local Verification

Run these commands before opening or merging a PR.

## Flutter app

```powershell
& 'C:\dev\flutter\bin\flutter.bat' analyze
& 'C:\dev\flutter\bin\flutter.bat' test
& 'C:\dev\flutter\bin\flutter.bat' build web --release
```

Targeted profile media checks:

```powershell
& 'C:\dev\flutter\bin\flutter.bat' test test\providers\profile_provider_media_test.dart test\community\profile_edit_media_sync_test.dart
```

Formatting note: a full-tree Dart format gate is not enabled yet because
`dart format --output=none --set-exit-if-changed lib test` currently reports
hundreds of pre-existing files that would be reformatted. Add that CI gate only
with a separate formatting-only cleanup commit.

## Backend

```powershell
cd backend
npm ci
npm run lint
npm test
```

Targeted profile media and CORS checks:

```powershell
cd backend
npm test -- avatarCorsRoutes.test.js uploadStaticCors.test.js serverCorsProdDefaults.test.js profilesMediaPersistence.test.js avatarProfileUploadRoutes.test.js
```
