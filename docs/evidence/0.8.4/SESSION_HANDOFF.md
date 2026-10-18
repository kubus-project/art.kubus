# 0.8.4 session handoff

Date: 2026-10-18. Phase: 0.8.3 is RELEASED to production; closeout (ancestry, record, tag) in progress.

## Release state

- Production `master` `2f93f64e61ccf5ac8923cf625b5f8b3a4c30eeaf` (PR #306, merge commit). Production
  deployment run 39080160967 succeeded (exact-SHA build, local and production smoke, rollback skipped).
  Do not redeploy.
- Live check 2026-10-18: `app.kubus.site/kubus-web-revision.txt` = `2f93f64e`; `kubus-community-build.json`
  has `COMMUNITY_MULTI_MEDIA_ENABLED`, `COMMUNITY_VIDEO_AUTOPLAY_ENABLED`, `COMMUNITY_VIDEO_POSTERS_ENABLED`
  all true; `/`, `/map`, `/community` return 200; canonical `https://app.kubus.site/en`.
- `dev` `74923da1` (before reconciliation). Master-to-dev reconciliation: PR #311
  (`chore/sync-master-into-dev-20261018`, merge `244c764e`, empty tree diff, parents 74923da1 + 2f93f64e).
  Merge with a merge commit only. Before: `master...dev` = `1 0`; after merge it must be `0 N`;
  confirm with `npm run verify:branch-reconciliation`.
- Docs PR #309 (`docs/083-final-record` `7604f471`): needs the staging/production wording updated
  after #311 lands (production is now complete) and a dev merge into its branch if behind.
- Tag `v0.8.3`: NOT created. A `v*` tag push triggers `mobile-release.yml` with publish=true,
  prerelease=false: protected `android-release` and `ios-release` signing, and a public GitHub Release.
  Needs explicit owner authorisation; tag the master SHA `2f93f64e`, never a later commit. Latest
  release is `v0.8.2.1`; `pubspec.yaml` is `0.8.3+26101601`.

## Acceptance

Authenticated artwork Save after the hotfix has NOT been exercised on a live environment (staging is
behind Basic Auth). Local browser evidence only. Owner acceptance owed: artwork edit, Save (app stays
usable, persists after reload, failed save keeps the editor); mixed-media carousel keeps a stable 4:3
stage; single video keeps its aspect; Node prose plain text; map search, cluster animation, selected
markers; owner profile navigation. Legacy portrait video sizing on phones remains a 0.8.4 defect.
Physical-device acceptance outstanding.

## Worktrees (all under C:/kubus-build, nothing pushed except the reconcile branch, nothing deleted)

| Branch | Worktree | Head | State |
| --- | --- | --- | --- |
| `fix/084-community-video-sizing` | `084-video` | `72801db2` | dev (#307, #308) merged; `community_video_audio_geometry_test.dart` restored to dev; focused tests, analyze, format clean |
| `fix/084-security-settings` | `084-security` | `7c212838` | second review fixes N1-N5, N7 committed; needs a third review of the new head |
| `fix/084-avatar-role-badges` | `084-badges` | `7ba74239` | merges cleanly with dev; not re-verified on integrated build |
| `fix/084-public-fallback` | `084-fallback` | `132a0d98` | merges cleanly with dev |
| `fix/084-accessibility` | `084-a11y` | `cb6f0c83` | merges cleanly with dev |
| `fix/084-desktop-dialogs` | `084-dialogs` | `efc64c66` | merges cleanly with dev |
| `test/084-map-reliability` | `084-map` | `d42f52b4` | merges cleanly with dev |
| `chore/084-candidate-disposable` | `084-candidate` | `e1d737b7` | dirty: `scripts/qa/corrective_visual_qa.mjs` (QA_LEGACY_VIDEO), identical to the video branch commit `b8922586` |
| `fix/084-web-runtime-and-prose` | `084-webrt` | `4e27e5e6` | merged as #308; do not push again |
| `docs/083-final-record` | `083-final-record` | `7604f471` | local docs corrections for the 0.8.3 record and the Netcup TLS statement |

## Playwright flutter-view timeout

Not reproducible. The harness (`QA_BROWSERS=chromium QA_WIDTHS=390 QA_SHAPE=portrait
QA_LEGACY_VIDEO=bare QA_MEDIA_ROOT=C:/kubus-build/084-qa/media`) boots, serves fixtures and
captures against the candidate build (`C:/kubus-build/084-qa/out/diag-1`). The earlier run most
likely hit resource contention against the 60 s `flutter-view` limit. The visible portrait
video size is not yet measured: the 390 px capture clips the stage at the viewport edge, so
the next run needs `QA_CLICK="Play video"` scrolling and a bounding-box measurement.

## Security findings (second independent review of `2e2a520c`)

Fixed in `7c212838`: N5 (first PIN ungated while biometrics is the only factor), N4 (settings
toggle path accepted a sign-in), N3 (auto-lock skipped on an unreadable PIN store), N2 auto-lock
clock set-back, N1 (PRF output stripped on sign-in and account passkey registration), N7.

Open: N2 lockout forward clock jump (cannot be closed on-device without a keystore-bound
counter; the lockout stage is kept, so a jump only skips the wait); N6 provider-level gating of
`enrollEncryptedWalletBackupPasskey` (onboarding reachability while signed in unverified);
N8 `verifyPin` is unserialized but not reachable today; N9 requirePin/biometricAuth are plain
preferences; N10 enroll does not check that the mnemonic derives the target wallet; N11 Android
window theme on API 26-27 needs a device run. Not verifiable from the client: D9 challenge
atomicity, server binding of passkeys to accounts, whether the backend requests PRF eval, web
PIN hash storage.

## Outstanding approvals

Owner: merge #311 (merge commit, NOT squash/rebase), then #309; decide on the `v0.8.3` tag
(mobile signing + public GitHub Release side effects); live authenticated Save acceptance.

## Next three actions

1. Third security review of `7c212838`, then push `fix/084-security-settings` as a draft PR.
2. Measure the visible portrait-video size on `fix/084-community-video-sizing` in Chromium and Firefox
   (`QA_CLICK="Play video"` plus a bounding-box measurement), then push as a draft PR.
3. Validate the badge and fallback branches on an integrated build off post-reconcile `dev`, then
   push as draft PRs; continue map QA, accessibility, dialogs, onboarding.
