# 0.8.4 session handoff

Date: 2026-10-17. Phase: A (finish 0.8.3) at the owner-approval gate; C started locally.

## GitHub state

- `dev` `74923da19503c46d0fc8b2491e2e8a17bda56e84` (after #307 `85c5699a` and #308 `74923da1`).
- `master` `4181b4d28dc628ca3dc44091804d759b10f04588` (production, `kubus-web-revision.txt` matches).
- Open release PR: #306 (`dev` to `master`, merge commit only). Review threads: 3 of 3 resolved.
  Exact-head run 39064711730: every job green except the Flutter job, still running at the
  last check. Deploy run 39064707394 promoted `74923da1` to staging.
- Staging is behind Basic Auth: the served revision and the authenticated flows below were
  not read from this environment.

## Owner acceptance still owed (authenticated `dev.kubus.site`)

Artwork edit then Save (returns to a working app, persists after reload, a failed save keeps
the editor and the typed input); mixed-media carousel keeps a stable 4:3 stage; a single video
keeps its source aspect; Node prose is plain text; map search, cluster animation and selected
markers; owner profile navigation; core map starts with the atmosphere module blocked.

## Worktrees (all under C:/kubus-build, nothing pushed, nothing deleted)

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

Owner: merge #306 with a merge commit, authorise the protected `release-production.yml`
deployment on the resulting master SHA, record the tag. Optional before the release: merge the
`docs/083-final-record` corrections (restarts #306's exact-head CI).

## Next three actions

1. When the Flutter job is green, send the owner the #306 approval request; after the
   authorised release, dispatch production, verify `kubus-web-revision.txt`, and open the
   non-squash master-to-dev reconcile PR.
2. Third security review of `7c212838`, then push the security branch as a draft PR.
3. Measure the visible portrait-video size on the merged video branch in Chromium and
   Firefox, then push it as a draft PR; validate the badge and fallback branches on an
   integrated build.
