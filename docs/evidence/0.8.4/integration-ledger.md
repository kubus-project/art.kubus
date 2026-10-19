# 0.8.4 integration ledger

Living record of every 0.8.4 implementation branch, its exact head, validation and
merge state. The requirement-level view is [scope-matrix.md](scope-matrix.md); the
resumable session state is [SESSION_HANDOFF.md](SESSION_HANDOFF.md).

Baseline (2026-10-18 22:40 CEST): `origin/dev` `2190782e` (after #319 and #320),
`origin/master` `841d92a3`, released tag `v0.8.3` -> `2f93f64e`. Production web
serves `2f93f64e`.

States are reported separately: implemented, tested, pushed, PR, merged, deployed,
owner-accepted, released. A blank cell means "not yet".

## Frontend (`kubus-project/art.kubus`)

| WS | Branch | Worktree | Head | PR | Implemented | Tested (local) | CI on head | Merged | Notes |
|---|---|---|---|---|---|---|---|---|---|
| A video | `fix/084-community-video-sizing` | `G:/kubus-build-084/video` | `0cdc9432` (unpushed) | none yet | learn-once real aspect (d7ad0666, merge 72801db2) + QA harness | focused community tests (prior); browser QA 24/24 pass at candidate 040b3880 ([browser-qa-video-badges.md](browser-qa-video-badges.md)) | | | Push as draft after #322 merges. Not covered: Firefox/WebKit, iOS device |
| B badges | `fix/084-avatar-role-badges` | `G:/kubus-build-084/badges` | `ef3f27be` (unpushed) | none yet | explicit `ProfileIdentityRoles` + avatar-anchored badge on every identity surface (7ba74239, 075c8157, 1dd03f64, 86ed15ee) + QA harness | 744 identity/community/profile/search/home tests; analyze clean; browser QA 16/16 x4 runs | | | home rail contract now asserts KubusIdentityAvatar. Push as draft after #322 |
| C security | `fix/084-security-settings` | `G:/kubus-build-084/security` | `6953282f` (pushed) | #315 draft | review-4 and review-5 corrections, 19 commits b1a2d708..6953282f | full suite 5303 pass / 27 skip / 0 fail at 6953282f; analyze --fatal-infos, custom_lint, ratchet clean | 975892d1 failed analyze (fatal infos) -> fixed; **all green, CLEAN at 6953282f** (run incl. Android, iOS, web smoke) | | 5 independent reviews; 2 low items deferred to 0.8.5 (private); device acceptance owed; allowBackup=false side effect in PR |
| D fallback | `fix/084-public-fallback` | `G:/kubus-build-084/fallback` | `473948be` (pushed) | #318 draft | yes + 401-not-to-mirror fix (473948be) | matrix 21/21, test/services 1067 pass (2026-10-18) | pending at 473948be | | Server side: backend #93 |
| E map | `test/084-map-reliability` | `G:/kubus-build-084/map` | `0ade69d4` | none yet | harness only (d42f52b4 = cherry-pick of 15b3c6c1) | | | | |
| H a11y | `fix/084-accessibility` | `G:/kubus-build-084/a11y` | `0900e878` | none yet | rail bell/gear/invites labels (cb6f0c83) | 67 a11y + l10n + nav tests, analyze clean | | | |
| H dialogs | `fix/084-desktop-dialogs` | `G:/kubus-build-084/dialogs` | `edda7c92` | none yet | shell nav + marketplace dialogs (efc64c66) + import order | arch test + 50 shell/marketplace tests, analyze clean | | | Closes FE277-1 / FE277-3 |
| CI tier | `ci/084-tiered-validation` | `G:/kubus-build-084/ci` | `758578c3` (pushed) | **#322** ready | draft/full PR-validation tier + review fixes | workflow_contracts 38/38, docs:doctor | draft run 39171897478 (draft tier, platform jobs skipped) + full run 39173380255 success | | Owner review + merge; then push a11y/dialogs/map drafts |
| K startup | `perf/web-startup-dedupe-20261018` | `G:/kubus-build-084/perf` | `94f637b9` | #312 draft (remote 4d4733ec) | yes + send/receive ensureWalletData (94f637b9) | wallet tests 81 pass; startup matrix (prior session) | green at 4d4733ec | | Returning-wallet cold start 21.7-22.2 s -> 2.4-4.9 s with #318 (prior evidence, to re-verify) |
| L release | `ci/083-multiplatform-release` | | `8308b020` | #319 | yes | | green | **merged** `f76f260e` 2026-10-18 | Reconciled by #320 (`2190782e`) |
| docs | `docs/084-release-evidence` | `G:/kubus-build-084/evidence` | | none yet | this ledger | | | | |

Local merges of `origin/dev` `2190782e` into every branch above were clean
(2026-10-18); none is pushed yet.

## Superseded / not to resubmit

- `fix/084-web-runtime-and-prose` (`4e27e5e6`): landed in 0.8.3 through #308.
- `docs/084-handoff` (#313 closed unmerged): replaced by this folder.
- `chore/084-candidate-disposable` (`C:/kubus-build/084-candidate`, `e1d737b7`): old
  disposable candidate; its uncommitted QA edit is backed up as a patch.

## Backups

`G:/kubus-build-backup/084-20261018/084-local.bundle` holds every branch that had
no remote copy on 2026-10-18 (video, badges, a11y, dialogs, map, candidate);
`084-candidate-corrective_visual_qa.patch` holds the candidate's uncommitted edit;
`scope-part1.md` / `scope-part2.md` are the prior requirement audits.

## Related repositories

| Repo | Default | Head | Open 0.8.4 work |
|---|---|---|---|
| `art.kubus-backend` | `master` only | `b2dfef54` | **#93** draft `78df86a` bounded Orbit reads (WS-D); **#94** draft `01ffd59` (`fix/084-passkey-challenge-atomic`, G:/kubus-build-084/backend-passkey): atomic single-use challenges incl. wallet sign-in, forward-only sign count, PRF results stripped at any depth, purpose binding, registrant checked before consume; 14 suites / 115 tests, eslint clean; independent review 0 P0/P1, 2 P2 fixed. Needs Redis >= 6.2 |
| `admin.kubus` | `master` | `bbabc713` | none |
