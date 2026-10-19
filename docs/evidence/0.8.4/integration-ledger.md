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
| A video | `fix/084-community-video-sizing` | `G:/kubus-build-084/video` | `0cdc9432` (unpushed) | none yet | learn-once real aspect (d7ad0666, merge 72801db2) + QA harness | focused community tests (prior); browser QA 24/24 pass at candidate 040b3880 ([browser-qa-video-badges.md](browser-qa-video-badges.md)) | | | Push as draft after #322 merges. Not covered: Firefox/WebKit, iOS device Validated: 2026-10-19 pre-push CI commands @0cdc9432: pub get/lock clean, format (3 files), analyze --fatal-infos --fatal-warnings, custom_lint, ratchet all PASS; test/community + test/widgets/community 538 pass (~10 pre-existing skips in community_composer_flow_test.dart, none added by branch). |
| B badges | `fix/084-avatar-role-badges` | `G:/kubus-build-084/badges` | `ef3f27be` (unpushed) | none yet | explicit `ProfileIdentityRoles` + avatar-anchored badge on every identity surface (7ba74239, 075c8157, 1dd03f64, 86ed15ee) + QA harness | 744 identity/community/profile/search/home tests; analyze clean; browser QA 16/16 x4 runs | | | home rail contract now asserts KubusIdentityAvatar. Push as draft after #322 Validated: 2026-10-19 pre-push CI commands @ef3f27be: all PASS (45 files format-clean, analyze/custom_lint/ratchet clean, 7 changed test files 96 pass). |
| C security | `fix/084-security-settings` | `G:/kubus-build-084/security` | `6953282f` (pushed) | #315 draft | review-4 and review-5 corrections, 19 commits b1a2d708..6953282f | full suite 5303 pass / 27 skip / 0 fail at 6953282f; analyze --fatal-infos, custom_lint, ratchet clean | 975892d1 failed analyze (fatal infos) -> fixed; **all green, CLEAN at 6953282f** (run incl. Android, iOS, web smoke) | | 5 independent reviews; 2 low items deferred to 0.8.5 (private); device acceptance owed; allowBackup=false side effect in PR |
| D fallback | `fix/084-public-fallback` | `G:/kubus-build-084/fallback` | `473948be` (pushed) | #318 draft | yes + 401-not-to-mirror fix (473948be) | matrix 21/21, test/services 1067 pass (2026-10-18) | pending at 473948be | | Server side: backend #93 |
| E map | `test/084-map-reliability` | `G:/kubus-build-084/map` | `0ade69d4` | none yet | harness only (d42f52b4 = cherry-pick of 15b3c6c1) | | | | Validated: 2026-10-19 pre-push CI commands @0ade69d4: analyze/custom_lint/ratchet PASS; no Dart changed (docs evidence + scripts/qa/product_v5_spatial_browser_qa.mjs, node --check OK). |
| H a11y | `fix/084-accessibility` | `G:/kubus-build-084/a11y` | `0900e878` | none yet | rail bell/gear/invites labels (cb6f0c83) | 67 a11y + l10n + nav tests, analyze clean | | | Validated: 2026-10-19 pre-push CI commands @0900e878: all PASS (5 files format-clean; changed test 7/7; test/l10n + test/widgets/desktop 70 pass). |
| H dialogs | `fix/084-desktop-dialogs` | `G:/kubus-build-084/dialogs` | `edda7c92` | none yet | shell nav + marketplace dialogs (efc64c66) + import order | arch test + 50 shell/marketplace tests, analyze clean | | | Closes FE277-1 / FE277-3 Validated: 2026-10-19 pre-push CI commands @edda7c92: all PASS (3 files format-clean; test/architecture + shell/marketplace tests 96 pass). |
| CI tier | `ci/084-tiered-validation` | `G:/kubus-build-084/ci` | `71406fdf` (pushed) | **#322** ready | draft/full tier + review fixes; **71406fdf** reports the draft tier under its own non-required context `PR validation (draft tier, not merge evidence)`; only full/missing/unknown tier keeps `PR validation required` (missing tier rejected by the aggregator) | workflow_contracts 45/45, all scripts/ci 89/89, docs:doctor, architecture guard. `verify:deploy` fails on Windows at `development preparation accepted an auth directory Apache cannot traverse`, reproduced on the unmodified 758578c3 (no diff vs dev in scripts/deploy): Windows file-mode limit, passed on ubuntu CI | full run 39228957912 all green (aggregate = `PR validation required`); draft probe PR #324 run 39233279590 reported only the draft context (probe closed, branch deleted) | | Review thread resolved. mergeStateStatus BLOCKED only by the merge itself: classifier denies `gh pr merge` (Merge Without Review), so the owner merges (squash). Then push the five drafts |
| K startup | `perf/web-startup-dedupe-20261018` | `G:/kubus-build-084/perf` | `94f637b9` | #312 draft (remote 4d4733ec) | yes + send/receive ensureWalletData (94f637b9) | wallet tests 81 pass; startup matrix (prior session) | green at 4d4733ec | | Returning-wallet cold start 21.7-22.2 s -> 2.4-4.9 s with #318 (prior evidence, to re-verify) |
| L release | `ci/083-multiplatform-release` | | `8308b020` | #319 | yes | | green | **merged** `f76f260e` 2026-10-18 | Reconciled by #320 (`2190782e`) |
| docs | `docs/084-release-evidence` | `G:/kubus-build-084/evidence` | | none yet | this ledger | | | | |

Local merges of `origin/dev` `2190782e` into every branch above were clean
(2026-10-18); none is pushed yet.

## Session 2026-10-19 (3): drafts pushed on the cheap tier

`origin/dev` `c53ab80e` (#322 squash-merged by the owner). `origin/dev` merged into every
branch below with no conflicts; the merge touches only CI files (`.github/workflows`,
`scripts/ci`, two docs), no `lib/` or `test/` file, so the pre-push local validation recorded
above still applies to the feature content. Cross-branch overlap: only
`lib/screens/desktop/components/desktop_navigation.dart` (badges + a11y); a merge-tree of
the two is conflict-free.

Draft tier verified on #325 (run on `d807cbd6`): Flutter quality, guardrails, provenance,
Apache contract and surface resolution ran and passed; Android, iOS, release web + browser
smoke, backend contract and docs jobs were skipped; the aggregate reported only
`PR validation (draft tier, not merge evidence)`; no `PR validation required` context exists.

| WS | PR | PR head | Local validation | CI tier / result | Review | Next |
|---|---|---|---|---|---|---|
| A video | #325 draft | `d807cbd6` | as above (`0cdc9432`) | draft / green | coordinator read: learn-once order fallback < poster < player, 3 % tolerance, eased only on the single-video stage, jump under reduced motion; no findings | Firefox QA on integrated candidate |
| B badges | #326 draft | `73f90e89` | as above (`ef3f27be`) | draft / pending | Sonnet: 0 P0/P1; 3 P2 verified (role inferred from author `role`/`type` substrings; `??` precedence lets `roles.artist:false` hide `isArtist:true`; profile cache parses `== true` and `isVerified ?? false` can throw) -> fix in progress (Haiku) | push fix, re-run draft |
| H a11y | #327 draft | `63279355` | as above (`0900e878`) | draft / pending | coordinator read: labels + Tooltip + Semantics, hit area unchanged; P3: unread count not in the bell label | |
| H dialogs | #328 draft | `72bdb6b3` | as above (`edda7c92`) | draft / pending | coordinator read: `showKubusDialog` keeps root navigator + barrier dismiss; no findings | browser back/escape + artwork Save check on candidate |
| E map | #329 draft | `9e5215fa` | as above (`0ade69d4`) | draft / pending | harness only | re-run on candidate |
| K startup | #312 draft | `9b589b10` | 2026-10-19 @`9b589b10`: format (11 files), analyze --fatal-infos --fatal-warnings, custom_lint, ratchet PASS; wallet provider/screens/session/link tests 63 pass | draft / pending | | D4 open items |

Scope rows worked this session:

- **B-20** (P1, desktop email session shows Sign in): root cause verified at
  `desktop_shell.dart:607-610`: profile hydration runs only with an auth wallet
  (`loadProfile(authWallet)`); an email session without a wallet never hydrates, so
  `ProfileProvider.isSignedIn` stays false and the rail shows Sign in and guest items. The
  session loader `ProfileProvider.loadAuthenticatedProfile()` (`getMyProfile`) already exists.
  Branch `fix/084-desktop-email-session` (worktree `G:/kubus-build-084/email-session`, from
  `c53ab80e`), fix in progress (Haiku).
- **B-18** (P1 like continuation): the backend `POST /community/posts/:id/like` is idempotent
  (`likeCommunityPost` returns `created`; achievement and notification side effects run only
  when `created === true` and carry idempotency keys). A duplicate POST after reload is
  therefore a wasted request, not a data defect. Client race (scout, not verified): the done
  marker is persisted only after the POST returns (`pending_action_provider.dart:186-200`), and
  `_executedKeys` is in memory. "Mark sent before POST" was rejected because it can lose a like.
  The user-visible half (Firefox shows not liked) needs a browser reproduction; suspect a stale
  interactions refresh (`community_interactions_provider.dart:228-244`). Proposed severity: the
  duplicate P3, the Firefox display P2 until reproduced.

### Later in session 3

- Draft CI: #325-#329 all green on the draft tier. #326 re-pushed `f05dd550` with the Sonnet
  P2 fixes (`262c57c9` roles only from stated flags, one parser for posts and the profile
  cache; `f05dd550` username/search lookups), green. #312 `9b589b10`: one failure in
  `test/screens/community/feed_like_settlement_test.dart` (a real socket_io WebSocket close
  left a 5 s fake-async timer). Passed 3/3 locally on #312 and on dev, #312 touches no socket
  code, and the job re-run passed. Recorded as a FLAKY test with a socket leak (test-hygiene
  follow-up), not a regression.
- **B-20 -> #330** draft (`fix/084-desktop-email-session` `4c39abc2`): pure
  `resolveDesktopProfileHydration`; 5 unit tests; desktop/analytics/architecture 76 pass;
  analyze/custom_lint/ratchet/format PASS. Browser acceptance with an email-only account owed.
- **CD-01..CD-03, CD-05 (backend) -> art.kubus-backend #95** draft
  (`fix/084-artwork-authorship-scopes` `ba16f3a`): migration 107 `artwork_attributions` +
  `idx_artworks_wallet_lower`; shared `artworkRelationshipSql.js` (SEO SQL proven
  byte-identical); `?relationship=authored|documented|managed`; stats
  `authoredArtworksCount`/`documentedArtworksCount`; real-PostgreSQL contract 14/14 on the
  CI image; schema parity + bootstrap PASS; lint clean; full jest 2039 pass, 1 environmental
  (`ipfsPatternReachability` 30 s subprocess under load; passes alone). Sonnet review: 0 P0/P1,
  P2 full-table scan fixed (candidate prefilter + index), P3 tests added.
- **CD-04 (Flutter)**: branch `fix/084-profile-authorship` (worktree
  `G:/kubus-build-084/profile-authorship`, from `c53ab80e`); data layer F1 in progress
  (`getProfileArtworks` + old-backend detection via the echoed `relationship`), then UI F2.
- Disposable local DB for backend contracts: docker container `kubus-pg-084`
  (postgis/postgis:15-3.4, 127.0.0.1:55432, user artkubus). Remove when done.

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
