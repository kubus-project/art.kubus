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
- **CD-04 -> #331** draft (`fix/084-profile-authorship` `045a15d4`): data layer with
  old-backend detection, mobile + desktop owner/visitor sections, EN/SL, documented cards
  credit the recorded artist; full suite 5192 pass / 27 skip at `fa83fc37`; browser QA
  `scripts/qa/profile_authorship_qa.mjs` release build: scoped 4/4 Chromium + 1 Firefox PASS,
  legacy 2/2 PASS. Open UX point: existing "Added Public Art" tile vs new "Public art added".
- **CD-05 -> backend #96** draft, stacked on #95 (`55a8e0c`): SEO profile authored count and
  related artworks use `AUTHORED_BY_PROFILE`; PG contract 11/11; SEO suites 251 pass.
  Retarget to master after #95 merges (backend CI runs only for master-based PRs).
- **CD-07 -> backend #97** draft (`audit/084-cultural-data` `e4abe8e`): read-only stratified
  audit tooling, own allowlisted extractor; local fixture 21 assertions / 19 checks PASS.
  NOT run on production (owner authorisation).
- **CD-08** branch `feat/084-editorial-state` (stacked on #95; `236a732`, `d0a2aa6`, review
  fixes in progress): migration 108 editorial state + `editorial_decisions`; decide/revert/
  history admin routes; PG 10/10. Sonnet: 0 P0/P1; P2 revert drift + PATCH republish being
  fixed. Not pushed yet.
- **CD-10 -> backend #98** draft (`feat/084-import-evaluation` `38c4d43`): subject never
  rejects; legal restriction (porn/obscene, extremist symbols) + non-art structure reject;
  everything else staged `needs_review`; `test:public-art` 41/41 and now in CI.
- **#95** backend: all checks green incl. the PostgreSQL contracts job. **#330** draft green.
- **#327** marked ready (`63279355`): full tier running.
- **#327 full tier**: `PR validation required` PASS at `63279355` (Android, iOS, release web +
  smoke, guardrails); a duplicate Flutter job still pending = known UNSTABLE rollup quirk.
  Ready for the owner's merge.
- **#98** now `978a865`: `scripts/seedStreetArt.js` inserts NEW records hidden + `needs_review`
  (when the column exists); re-runs never change existing visibility; `SEED_PUBLISH_IMPORTS=true`
  is the explicit owner-approved publish mode; PG 6/6 in CI.
- **#99** now `da57561`: approving a hidden `needs_review` record publishes it; undo hides it
  again (PG 17/17). Together with #98 this is CD-15 for new imports: staged records are not
  public, so they produce no public/SEO pages until approved. Legacy `unreviewed` records keep
  today's contract (no mass de-index without an owner decision).
- **admin.kubus #17** (`feat/084-review-deck` `07dafbd`): Review Deck; lint/typecheck/317
  tests/build PASS; read-only Haiku review P2s fixed. Staging journey owed (owner env).
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

## Session 4 (2026-10-19 evening, Opus coordinator, "Complete Release Orchestration" brief)

Baseline: app `dev` `9309b1ff` (#327 merged), backend `master` `c4115594` (#95 squash), admin
`master` `bbabc713`.

| WS | Repo | Branch / PR | Head | Status | Tests | Merge eligibility | Next |
|---|---|---|---|---|---|---|---|
| CD-05 SEO | backend | #96 | `daec86c` | merge of master: #95 squash tree == old `ba16f3a`, conflicts kept branch side, merge commit has zero tree change | PG 8 suites (68), parity, bootstrap, migration contract PASS; lint; test:ci 2039 pass + 1 auth timeout (known bcrypt-12 5 s timeout under load, also on master; CI green) | MERGEABLE, CI deterministic green, PG job pending | ready + merge after #99 order check |
| CD-08 editorial | backend | #99 | `99a8754` | same zero-tree merge | PG 8 suites (79), parity, bootstrap (99 migrations, 137 tables), test:ci 2103 pass, lint | MERGEABLE | ready |
| CD-10 import | backend | #98 | `12f8c36` | merge of master, CI yml union (both PG steps, both path sets) | PG 68, test:ci 2040 pass (idle rerun), public-art 41/41 | MERGEABLE | ready |
| CD-07 audit | backend | #97 | `44e24c9` | standby target + in-session recovery guard + forced read-only + timeouts (`e8...` commit before merge) | fixture 21 cases / 19 checks PASS; guard verified locally (non-standby refused, write -> 25006) | READY (full CI running) | prod run BLOCKED_OWNER (classifier: Production Reads) |
| CD-04 profile | app | #331 | `359224cd` | tile "Public art documented" / SL "Dokumentirana javna umetnost"; tile counts the documented set; owner screens now request authoredArtworks (were silently showing wallet-owned count); authorship metrics separate request (pre-0.8.4 backend 400s unknown metrics and wiped visitor counters) | gate: lock, format, analyze fatal, custom_lint, ratchet PASS; 190 tests | draft, CI pending | ready after green |
| CD-12/13 institutions | backend | `feat/084-institution-identity` (stacked on #99), worktree `G:/kubus-build-084/backend-institutions` | `e46e270` | migration 109 + design doc (coordinator), snapshots + editorial institutions (Haiku) | parity, bootstrap 142 tables, editorial unit 70 + PG 18 | local only | public read visibility (Haiku, running), then claims service/routes |
| candidate | backend | `integration/084-backend-candidate` (local, `G:/kubus-build-084/backend-candidate`) | `b68911c` | master + #96 + #99 + #98 + #97 + #93 + #94, union-resolved CI/package conflicts | not yet | disposable | staging backend |

Frontend A3: `dev` merged locally into video `8392b714`, badges `13d52d2c`, dialogs `3baf9f49`,
map `9a3e7170`, email-session `1ac5233b`, perf `6b7d5d61`; pairwise merge-tree of all nine
0.8.4 frontend branches is conflict-free (any merge order works). Gates running.

Production observations (2026-10-19 ~21:00, read-only, recorded for the owner, not acted on):
Home `artkubus-backend` reports `unhealthy`; `artkubus-orbitdb` restart loop; Home standby
`pg_is_in_recovery()=t`, `transaction_read_only=on`, but `now() - pg_last_xact_replay_timestamp()`
= 624087 s (~7.2 days). The follow-up WAL receiver / pg_stat_replication read was DENIED by the
classifier (Production Reads), so stalled replication vs. idle replay is unverified. If stalled, a
failover would lose ~7 days. OWNER ACTION: check `pg_stat_wal_receiver` on Home and
`pg_stat_replication` on Oracle.

## Session 5 (2026-10-19 22:30, recovery after the session-4 limit)

Verified live, not taken from the session-4 narrative. App `dev` `9309b1ff`, backend `master`
`c4115594`, admin `master` `bbabc713` (all unchanged). Every frontend feature worktree equals its
remote head. Backups of every local-only branch and of the one uncommitted diff:
`G:/kubus-build-backup/084-20261019-recovery/`.

| WS | Repo | Branch / PR | Head | Status | Tests (this session, local) | Next |
|---|---|---|---|---|---|---|
| CD-12/13 institutions | backend | `feat/084-institution-identity` (pushed, no PR, stacked on #99) | `47d8a05` | claims service committed by the worker that hit the limit; verified here | claims PG + rules 25/25 on `kubus-pg-084`; lint clean | claim routes + evidence check (no network check yet); search lacks `merged_into_id IS NULL` (merged duplicates can surface); promotionService reads unfiltered (admin-created, lower risk); SEO fallback `i.*` reaches the row object |
| CD-11 Studio S1 | backend | `feat/084-moderation-studio-api` (pushed, no PR, stacked on `0335c26`) | `d6dde04` | `4c6b7fd` migration 110 (worker had left it uncommitted; parity + bootstrap re-run: 101 migrations, 143 tables); `a44ebac` service; `d6dde04` router at `/api/admin/moderation-studio`, two export lines in adminModeration.js, CI step + filter | S1 PG + rules 26/26, routes 8/8, adminModeration* 84 pass / 3 skip, lint | `art_markers.geo` is GENERATED: the service writes only lat/lng (the spec said to write geo). S2 bounded reads not started |
| CD-07 audit | backend | #97 ready | `c4caaff` | 3 Codex threads (2 P1, 1 P2) fixed, replied, resolved; CI green, CLEAN | fixture 75 seeded cases PASS; lint | owner merge; prod run BLOCKED_OWNER |
| A video | app | #325 ready | `b9f993bd` | Codex P2 fixed (posters probed only on the adaptive single-video stage), thread resolved; full tier re-running on the new head (previous head passed, run 39308298666) | test/community + test/widgets/community 542 pass; analyze fatal, custom_lint, ratchet | owner merge after the full tier is green |
| B badges | app | #326 ready | `a1e2ab33` | 3 Codex P2 fixed (`bb227b6a` nested author roles + resolved lookup roles; `a1e2ab33` `ConversationAvatar` unread count top-left, no clip), threads resolved; full tier re-running | identity/search/community/desktop 587 pass; format, analyze fatal, custom_lint, ratchet | owner merge after the full tier is green |
| CD-04 profile | app | #331 draft | `359224cd` | draft tier green, 0 threads | | ready when owner accepts the UX naming |
| CD-05 / CD-08 / CD-10 | backend | #96 / #99 / #98 drafts | `daec86c` / `99a8754` / `12f8c36` | CLEAN, CI green, 0 threads | | ready-for-review is the owner's call; order #99 -> #96, #98 any time |

B-18: not reproduced in 24 authenticated runs; latent stale-intent slot P3. Full record:
[b18-like-continuation-qa.md](b18-like-continuation-qa.md).

Staging (isolated, synthetic): backend `backend-candidate` `b68911c` on `127.0.0.1:53101` (the
node process binds `::`, i.e. all interfaces; synthetic data only, note for the next restart),
DB `kubus-pg-084`/`staging084` at migration **108** (109 and 110 are not in the candidate),
web `f20b2129` rebuilt with the backend pinned, served on `127.0.0.1:58180`; admin dev server
5174 NOT running. The first `f20b2129` build talked to production hosts (see the B-18 record).

Production observations from session 4 (~21:00) carried forward unchanged as BLOCKED_OWNER: Home
backend unhealthy, OrbitDB restart loop, Home standby replay timestamp ~7.2 days old (replication
state unverified; an old replay timestamp can also mean an idle primary). Not re-checked.

## Session 6 (2026-10-20 00:00-, "Integration, Safe Staging and Release Validation" brief)

Baseline: app `dev` `9309b1ff`; backend `master` `29b2dc3` (#97 squash, merged by owner) ->
`fec505ce` (#99 squash, merged this session with `--match-head-commit 99a8754c`).

### Phase A - staging isolation (code, not documentation)

| Workstream | Repo / PR | Head | Result |
|---|---|---|---|
| Isolation tooling | app **#332** draft (`test/084-staging-isolation`) | `84495380` | `scripts/qa/staging/{isolation,preflight,build_web,launch_backend,playwright_guard}.mjs`; `isolation.test.mjs` 12/12 in the guardrails job (asserts `config.dart` still reads the pinned keys); docs:doctor, workflow_contracts 45/45 |
| Loopback binding | backend **#100** (`fix/084-loopback-listen-host`) | `850bf0fb` | optional `LISTEN_HOST`, invalid values stop startup, unset unchanged; 9/9; CI green, CLEAN |

Live proof (2026-10-20): the launcher started a backend without `LISTEN_HOST` support, found port
53101 answering on 5 external addresses (LAN 192.168.0.61, Tailscale 100.87.75.116 + fd7a:...,
two Hyper-V/WSL) and stopped it (exit 1). With #100: loopback only; OS listener `127.0.0.1:53101`.
Preflight PASSED on the rebuilt candidate (one bare `api.kubus.site` remains in the media
resolver's direct-display allowlist: a host name, not an endpoint, reported as a note). Browser
guard in Chromium + Firefox blocked `api`/`bapi.kubus.site` GETs and an off-staging POST, passed
staging; the app itself POSTs Solana JSON-RPC (`api.devnet.solana.com`) at startup, which the guard
blocks (reads included). Admin dev server already binds `127.0.0.1:5174`; it defaults to
production too, so it is started with `VITE_API_BASE_URL`/`VITE_API_FALLBACK_BASE_URL` pinned.

### Phase B - merges and stacks

| PR | Head | State |
|---|---|---|
| app #325 video | `b9f993bd` | full tier failed only in PRODUCT motion acceptance (Firefox sampling coverage hole 579-604 ms under CI load; lift/bob/shadow in range; PR touches no motion code); one failed-job re-run requested (run 39325124258) |
| app #326 badges | `a1e2ab33` | same motion-gate failure; re-run after #325's |
| backend #99 | `99a8754c` | **MERGED** `fec505ce` (no file overlap with #97 verified first) |
| backend #96 | `9a34bb8d` | master merged (rerere union of CI/package, filter set = exact union), PG 28/28, parity, lint; CI green; **marked ready**, not merged |
| backend #98 | `7b8f7d68` | master merged (CI union), PG 23/23, public-art 41/41, lint; CI running |
| backend **#101** draft institutions | `090a9160` | master merged: merge adds only #97's 7 files; diff vs master == institution commits (asserted); 125/125 PG+unit, parity, bootstrap 100/142; CI step for claims + public reads |
| backend **#102** draft Studio S1 | `ef0aa4a` | base #101; diff = 13 Studio files; 48/48, bootstrap 101/143 |

### Phase C - backend acceptance

- **C1** (#101 `87d7e95`, `985754f`, `090a916`): search (2 queries) and home rails use one
  `getPublicInstitutionPredicate()`; merged duplicates stay out of discovery; the predicate and the
  SEO helper now **fail closed** (an empty column introspection used to degrade to `true`, i.e.
  staged listings public). Admin promotion views keep every row. `is_active` is nullable default
  true; NULL is hidden (as list/search already did; the home rail used to show it). SEO `i.*`
  never reaches HTML (curated presentation objects). Tests 188 + SEO 214 pass.
- **C2 email-only post**: REPRODUCED on staging (desktop Create post -> `POST /community/posts`
  500, no message). Contract: posting is wallet-keyed (NOT NULL column, mobile gate, migration 103
  of 0.8.2 never landed). Fix: backend **#103** `d17f561` (403 `WALLET_REQUIRED` before any write on
  posts, reposts, group posts; 9 tests) + app **#333** `c3cfb197` (desktop asks for a wallet like
  mobile; maps `WALLET_REQUIRED`; 325 tests). Verified on staging: email-only POST -> 403
  WALLET_REQUIRED. Account-keyed posting stays an owner decision.
- **C3 Studio S2**: GET /markers bbox read in progress (Haiku); nearby/evidence next; entity
  search and the category write deferred.

### Phase D - staging

- Backup: `G:/kubus-build-backup/084-staging-db/staging084-pre109-20261020.dump` (pg_dump -Fc).
- `staging084` migrated 108 -> **110** with `node src/db/migrate.js` from candidate 2; second run
  applied 0; 101 ledger rows, no duplicates, 144 tables.
- Backend candidate 2 `integration/084-backend-candidate-2` (local) `094121b` = master + #96 #98 #93
  #94 #100 #101 #102 #103.
- Mailpit `kubus-mail-084` on 127.0.0.1:51027 (SMTP) / 58027 (UI): verification mail delivered.
- Frontend candidate 2 `integration/084-frontend-candidate-2` `999f5986` = dev + 11 0.8.4 branches;
  analyze fatal clean; isolated build running.

### Session 6 - later (end-of-session checkpoint)

Merged this session: backend **#99** (`fec505ce`), app **#325** (`bb83fd2d`, after one failed-job
re-run of the Firefox motion-coverage flake). New PRs: app #332 (isolation, `17304c50`+), #333
(desktop wallet gate + copy, `7dee1efe`); backend #100 (LISTEN_HOST), #101 (institutions, draft),
#102 (Studio S1 + S2a bbox read + title fix `5d2fc00`, draft, stacked on #101), #103
(WALLET_REQUIRED). #96 marked ready (CLEAN). #98 draft CLEAN. #326 merged dev -> `3dec5397`, full tier
running.

Further isolation fixes found live and fixed in #332: the backend's admin status monitor probed the
production sites/API from the server (ADMIN_MONITOR_TARGETS default) -> launcher pins staging
targets + PUBLIC_API_URL/APP_URL/SEO_PUBLIC_BASE_URL; the old rig's AUTH_RATE_LIMIT did not raise
the sign-in limiter (AUTH_RATE_LIMIT_MAX_REQUESTS, default 25/15 min) -> launcher sets it; admin dev
server needs VITE_HA_PRIMARY/STANDBY_BASE_URL pinned (HA panel defaulted to bapi.kubus.site).

Staging (all loopback, preflight PASSED): backend candidate 2 `0ae4430` (local), DB staging084 at
migration 110 (backup pre109 dump), web candidate 2 `999f5986` (built with build_web.mjs; #333's
copy commit 7dee1efe not yet in the build), admin #17 dev server, Mailpit 51027/58027.

E2E results (scripts in G:/kubus-build-084/_staging, evidence under b18-out/ and admin-out/):

| Journey | Result |
|---|---|
| Ordinary user: guest map -> register -> real verification mail -> verify -> sign in -> like/reload/unlike | PASS Chromium + Firefox at 1440 and 390 |
| Email-only post (C2) | before fix: 500; after #103 + #333: no request, actionable message (copy corrected in 7dee1efe, not yet rebuilt) |
| Moderator Review Deck: approve publishes, undo hides, history, reject with reason, stale-version conflict | PASS Chromium + Firefox (16 checks); UX P2 for admin #17: after a decision the deck advances and Undo is disabled (undo only from the decided queue) |
| Map Audit API (S1+S2a): auth, bbox, duplicates, clusters, correction, replay, conflict, revert, CSRF | PASS 15/15 (after the artwork-less title fix) |
| Artist authored vs documented lists | PASS; count assertion and institution search assertion FAILED in my script, likely wrong endpoint/regex - UNVERIFIED |
| Institution list/claimState/merged resolution | PASS; claims cannot be exercised end-to-end: no claim HTTP routes yet |

Not done: keyboard / reduced-motion pass on the candidate, video + badges harness re-run on
candidate 2, Phase E full gates, physical devices. #315/#94 security PRs unchanged (own gates).
Production observations unchanged, BLOCKED_OWNER (not re-checked).

## Session 7 (2026-10-20 02:00, recovery and integration contract review)

This pass re-fetched the app and backend remotes and checked GitHub PRs. It did not merge,
deploy, mutate staging, or rerun Session 6 browser/database evidence. The evidence worktree is
`docs/084-release-evidence` at `fecf61c0d63b9d1cf75614f8e9227367b8fa7b6b` (15 ahead / 2 behind
its local `origin/dev`); preserve its history and reconcile before any push.

| Repo / PR | Live state on 2026-10-20 | Exact head | CI / integration note |
|---|---|---|---|
| app dev / #325 | dev `bb83fd2dfc2d540ab5d4047289bc4b344a3ea55e`; #325 merged | #325 `b9f993bd03551f40b5a40f87d7419afea24dfa30` | live dev contains the merge |
| app #326 | OPEN, non-draft, CLEAN | `3dec5397f86f8ab77eb63e88cb980cd6a6ecff04` | full required CI passed on run `39339219070`; review decision blank |
| app #331 | OPEN draft, BEHIND | `359224cd00da5b29a9c88a20cf153625e9238267` | PR baseRefOid is `9309b1ffe95091298e444ea9a2348febe79c8c51`; only draft-tier validation passed, web/native/compatibility jobs skipped |
| app #332 | OPEN draft, BEHIND | `17304c5016a4097d27a30ee4568b149849dc598b` | draft-tier pass; release web and native jobs skipped |
| app #333 | OPEN draft, BEHIND | `7dee1efe1f696175b9e1cc6a59d36720b4270757` | draft-tier pass; release web and native jobs skipped |
| backend master / #97, #99 | master `fec505cedc8df06ce9f3229dd7e6a631814afea3`; #97 and #99 merged | #97 `c4caafff405d4b0041cbadeadb3251bdf7f027b2`; #99 `99a8754c10d2d7049f51f70edeab49801c0a8610` | backend currently has no `dev` branch; app branching guide documents this as a separate migration |
| backend #96, #98, #100, #101, #103 | OPEN; #96/#100/#103 non-draft; #98/#101 draft | `9a34bb8d`, `7b8f7d68`, `850bf0fb`, `090a9160`, `d17f5616` | their current applicable checks pass; #100/#103 skip the unrelated PostgreSQL job |
| backend #102 | OPEN draft, DIRTY on GitHub; stacked on #101 | `5d2fc00df8bc027c02417fcd9f2de0ec6bdcddc5` | only GitGuardian is reported; backend worktree itself is clean. Preserve recovery patch `G:/kubus-build-backup/084-20261019-recovery/backend-studio-uncommitted.patch` for comparison; do not apply blindly |

Relevant worktrees: app #326 `G:/kubus-build-084/badges` (clean); #331 `.../profile-authorship`
(untracked QA outputs); #332 `.../staging-isolation`; #333 `.../desktop-post-gate`; integration
candidate 2 `.../frontend-candidate-2` at `999f5986`. Backend #101 `.../backend-institutions`
at `090a9160`; #102 `.../backend-studio` at `5d2fc00`; #103 `.../backend-wallet-required` at
`d17f5616`; backend candidate 2 `.../backend-candidate-2` at `0ae4430`. Preserve every worktree.

Wallet-required contract snapshot: backend #103 tests expect 403 `WALLET_REQUIRED` before a
post/repost/group-post write for an authenticated account without a wallet; the Flutter #333
preflight avoids upload/request and retains the compose draft, and maps the server code to the
localized wallet prompt if local wallet state is stale. Both backend schema snapshots currently
declare `community_posts.wallet_address NOT NULL`. This is the existing contract, not a product
decision against account-ID authorship. The account-ID trace and migration design are recorded in
the Session 7 review below. Do not treat `users.id` as a wallet value; never restore NOT NULL after
walletless rows are accepted.

Backups retained: `G:/kubus-build-backup/084-20261019-recovery` (local Git bundles, Studio patch,
location-correction SQL), `G:/kubus-build-backup/084-staging-db/staging084-pre109-20261020.dump`,
and the earlier `084-20261018/scope-part1.md` / `scope-part2.md`. Prior Session 6 staging/browser
results remain historical evidence and were not rerun here. Repository playbooks require explicit
user authorization for PR merges; green CI alone is not merge authorization.

### Session 7 account-ID authorship and integration overlap review

Research was read-only in the frontend candidate `G:/kubus-build-084/frontend-candidate` at
`f20b2129405c149bf1a6c8a5ca1afb5f95617b4a` and backend #103 worktree
`G:/kubus-build-084/backend-wallet-required` at `d17f56166c0d6067c8ce2f1c64c8c5cf706179e5`.
Both remained clean. Root subsequently assigned implementation to a separate backend worktree;
no source files were changed during this research pass.

The account-ID design has an existing canonical key: `community_posts.author_id` is nullable UUID,
indexed (`idx_posts_author`) and FK to `users(id)` in both `src/db/schema.sql` and
`src/db/schema_complete.sql`. The FK currently cascades on account deletion. `communityPostService`
does not populate it; post/repost create and post edit/delete/repost-delete ownership are wallet
keyed. Feed/detail reads join profiles by `community_posts.wallet_address`, and emit the profile's
`user_id` rather than the post's `author_id`. `wallet_address` is currently NOT NULL. The
idempotency table migration `098_community_post_submissions.sql` uses `(wallet_address, operation,
submission_key)` as a NOT NULL primary key, so making only the post wallet nullable would break
keyed submissions.

The existing auth `/bind-wallet` flow updates the same `users.id` row after rejecting a wallet
already attached to another user (`src/routes/auth.js`, bind-wallet transaction). Thus `users.id`
can remain the author across a wallet link. A safe ordinary-post implementation should populate
`author_id` only from the authenticated account, retain nullable wallet metadata for existing
clients, scope durable idempotency by account ID while preserving/reconciling old wallet-keyed
records, make reads and owner predicates account-ID first with wallet fallback for legacy rows, and
keep both schema snapshots in parity. Do not accept an author ID from request data. Group posts
remain wallet-gated: `group_members` is keyed by `(group_id, wallet_address)` and membership checks
use that key. The #103/#333 global gate is therefore superseded for ordinary posts, while the group
gate remains until group membership is migrated as a separately reviewed contract. Existing
`author_id` FK `ON DELETE CASCADE` is an account-deletion policy risk; preserve current deletion
semantics unless account/content retention policy requires a separately reviewed change. Migration
up/down and rollback tests must use isolated synthetic data and prove old posts/legacy wallet reads
survive.

Cross-repository acceptance needed: email-only authenticated create/read/edit/delete; legacy and
wallet-backed author preservation; same-row wallet link with stable author ID; cross-account edit/
delete denial; body-supplied owner spoof rejection; account-scoped idempotency replay/conflict;
null-wallet author serializers in feed/detail/repost; and proof group posting plus blockchain
actions remain gated. Existing #103 tests only prove 403/no insert for general post, repost and
group routes; they do not prove account-ID authorship.

File overlap and minimal integration sequence (computed from live PR changed-file lists on
2026-10-20):

| Repo / PRs | Exact shared paths | Integration consequence |
|---|---|---|
| app #326 x #333 | `lib/screens/desktop/community/desktop_community_screen.dart`; `lib/screens/desktop/community/desktop_community_screen_parts/desktop_community_screen_p5.dart` | Integrate/review the shared compose paths together; #333 wallet gate behavior is superseded for ordinary posts by the account-ID implementation. |
| app #331 x #333 | `lib/l10n/app_en.arb`; `lib/l10n/app_localizations.dart`; `lib/l10n/app_localizations_en.dart`; `lib/l10n/app_localizations_sl.dart`; `lib/l10n/app_sl.arb` | Regenerate/reconcile localization after #331/#333 content is combined. |
| app #332 | No changed paths overlap #326/#331/#333 | Staging isolation can be integrated independently, then full gates must run on updated dev. |
| backend #96 x #98 | `.github/workflows/backend-ci.yml`; `package.json` | Serialize CI/package integration and re-run full backend checks. |
| backend #96 x #101 | `.github/workflows/backend-ci.yml`; `package.json`; `__tests__/seoPublicPagesRepository.test.js`; `src/services/seoPublicPagesRepository.js` | Merge/rebase #96 before #101; inspect semantic hunks and repeat PG/full CI on the exact combined head. |
| backend #98 x #101 | `.github/workflows/backend-ci.yml`; `package.json` | Reconcile package/CI deltas after #98 before final #101 validation. |
| backend #101 x #102 | `.github/workflows/backend-ci.yml`; `package.json`; `src/db/schema.sql`; `src/db/schema_complete.sql` | #102 is stacked on #101; reconcile migration 109/110 schema parity and rerun PG + full CI after #101 base lands. |
| backend #100 x #102 | `src/server.js` | Apply/review the loopback listen-host and Studio route changes together before #102 final CI. |
| backend #103 x walletless implementation | `src/routes/community.js` and `src/routes/groups.js` are the ownership boundary | Preserve the group wallet gate while replacing the ordinary post/repost global wallet gate. |

Recommended review order: app #326, then rebase/review #331, then reconcile #333 (or replace its
ordinary-post gate in the separate walletless frontend task); #332 is independent. Backend #96
before #98/#101 shared changes, #100 before #102's server change, #101 before stacked #102; integrate
#103's group-only gate with walletless ordinary post ownership. Every integration changes the PR
head/base evidence, so currently green exact-head CI must not be reused after a rebase or merge.
No merge authorization was exercised by this ledger update.

## Session 8 (2026-10-20, integration checkpoint)

### G — walletless ordinary Community posting implementation

Backend worktree `G:/kubus-build-084/walletless-backend-084` is clean on
`fix/084-account-community-posting`, commit `7c0fdf090d18cfe508e01eb153e5503c347f0352`,
based on fetched live `master` `fec505cedc8df06ce9f3229dd7e6a631814afea3`. Draft PR
[#104](https://github.com/kubus-project/art.kubus-backend/pull/104) is OPEN against that
exact base. On current-head run `39347631529`, `Resolve affected backend surfaces` and
GitGuardian pass; `Lint, deterministic tests, and static validation` is in progress. No merge,
deployment, or production migration was performed.

The 10 changed paths are `src/routes/community.js`, `src/routes/groups.js`,
`src/services/communityPostService.js`, `src/middleware/validation.js`, both schema snapshots,
`migrations/111_account_community_posting.sql`,
`scripts/rollback_account_community_posting.sql`, and the two focused PostgreSQL tests.
Ordinary posts and reposts use authenticated `users.id` ownership, wallet metadata remains
optional, and caller-supplied author IDs are ignored. Read/owner paths are account-first with
wallet fallback only for legacy rows. Account deletion retains the existing `author_id` FK
`ON DELETE CASCADE` behavior; no legacy authors are backfilled. Rollback refuses to restore
wallet constraints while walletless posts or account-scoped submission keys exist. Group posts
remain wallet-gated. Flutter composition is still gated and needs a separate matching change.

An independent review found keyed retries for existing wallet-only group members left the
submission's `post_id` and stored response null because the completion updates matched only
`user_id`; retry then returned `COMMUNITY_POST_ALREADY_COMMITTED`. Commit `7c0fdf09` now updates
the account-scoped row when a user ID exists and the legacy wallet-scoped row only when it does
not. A real-route PostgreSQL regression proves the first response is stored and the legacy retry
returns the exact response without inserting or syncing a second post.

Isolated loopback PostgreSQL proof: `walletlessCommunityMigration.postgres.test.js` plus
`communityPostIdempotency.postgres.test.js` passed 24/24 tests after the repair, including legacy
wallet group replay, legacy preservation, owner spoof rejection, cross-account denial, same-row
wallet linking, durable replay, group gate, and account-deletion semantics. `verifySchemaBootstrap.js`
clean-bootstrapped both snapshots and all 100 migrations into 137-table schemas; resulting
catalogs matched. `verifySchemaParity.js` reported zero table drift and migration filename
policy passed. Targeted ESLint, JS syntax, and
`git diff --check` passed. This is local synthetic evidence; exact-head CI is running and
independent ownership/security review is requested again for the repaired head.

Migration sequence compatibility was checked against current PRs: #101 contributes migration
109; stacked #102 includes 109 and adds 110; #103 has no migration; #104 uses 111. Recheck the
combined migration history before any later integration or release migration.

### Current app PR heads and review queue

| PR | Live state on 2026-10-20 | Exact head / base | Current evidence |
|---|---|---|---|
| app #326 | OPEN, non-draft, CLEAN | `3dec5397f86f8ab77eb63e88cb980cd6a6ecff04` / `bb83fd2dfc2d540ab5d4047289bc4b344a3ea55e` | Required exact-head run `39339219070` green; do not rerun without a new finding. |
| app #334 | OPEN draft, BLOCKED | `bb56bb9844cfe6a5d57fc23fa4b53c44e9765420` / same dev SHA | Draft-tier run `39345869661` passed its applicable checks; native builds were skipped. Local static native-resource tests 3/3 and focused Flutter tests 32/32 were reported. Console/signed runtime and packaged-resource build proof remain unverified. |
| app #335 | OPEN draft, BLOCKED | `c46b05987c71a4ab95c13ce7a0a5d76994549da9` / same dev SHA | Local targeted analyze and 13 tests reported green; draft run `39347227776` still had repository guardrails pending when checked. |
| app #336 | OPEN draft, BLOCKED | `f5da072044edd013e552ddbac1e74cf27f608804` / same dev SHA | Local 246 tests and targeted analyzer on 13 files reported green; draft run `39347272752` had affected-surface resolution pending. |

The owner confirmed R03 depends on user-provided Google Sign-In API/config. Do not alter signing
or OAuth secrets. Initial source review of #334 found no blocker in branding/location/OAuth scope;
native builds and signed runtime remain unverified. #326 identity review, #335 navigation review,
and incremental #336 review remain outstanding while the repaired #104 head receives independent
review. No merge approval is claimed here.
