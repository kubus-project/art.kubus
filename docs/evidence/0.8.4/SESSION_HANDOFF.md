# 0.8.4 session handoff

Read this first when resuming. Detailed state: [integration-ledger.md](integration-ledger.md)
and [scope-matrix.md](scope-matrix.md). Security findings are never written here; they
live in the private draft advisory and `C:/kubus-build/_private/security/`.

```text
LATEST (2026-10-20 02:00, recovery pass): see integration-ledger.md "Session 7" for live state.
  App dev is bb83fd2dfc2d540ab5d4047289bc4b344a3ea55e; #325 is merged. #326 is OPEN at
  3dec5397f86f8ab77eb63e88cb980cd6a6ecff04 with its full required CI green. #331 (359224cd),
  #332 (17304c50) and #333 (7dee1efe) remain open drafts behind dev 9309b1ff. Backend master is
  fec505cedc8df06ce9f3229dd7e6a631814afea3; this repository has no dev branch. #97/#99 merged;
  #96/#98/#100/#101/#102/#103 remain open (#102 is draft/dirty on GitHub). No merge was made:
  both repository playbooks require explicit user authorization. Session 6 staging results and
  the pre-109 database backup remain preserved; they were not rerun in this recovery pass.
  G REVIEW: `community_posts.author_id` already provides nullable FK `users.id` plus an index;
  account-ID authorship is feasible without adding a second author column. Main-post owner/read
  paths still key off wallet, and keyed submission replay is wallet-PK scoped. Keep group posts
  wallet-gated until group membership has an account-ID contract. Root assigned a bounded backend
  implementation in `G:/kubus-build-084/walletless-backend-084` from fetched live master; no merge
  or production migration is authorized.
  F REVIEW: overlap/rebase sequence is recorded in integration-ledger.md. No merge was made.

SESSION 6 CHECKPOINT (2026-10-20 ~01:30; superseded by the live-state check below): see integration-ledger.md
  "Session 6". Merged: backend #99 fec505ce, app #325 bb83fd2d. Open: app #326 (full tier on
  3dec5397), #331, #332, #333; backend #96 ready, #98, #100, #101, #102 (stacked), #103.
  Staging: cd G:/kubus-build-084/staging-isolation; node scripts/qa/staging/launch_backend.mjs
    --backend G:/kubus-build-084/backend-candidate-2 --private G:/kubus-build-084/_staging/_private
    --database-url postgresql://artkubus:local-084-test@127.0.0.1:55432/staging084 ; then
    node scripts/qa/staging/preflight.mjs --api http://127.0.0.1:53101 --web http://127.0.0.1:58180
    --web-root G:/kubus-build-084/frontend-candidate-2/build/web --defines <same>/.dart_tool/public-build-defines.json
  NEXT: 1. merge #326 when green; owner review of #100/#103/#96 (+#333,#332). 2. claim routes on
    #101, then S2b nearby/evidence on #102. 3. rebuild candidate 2 with #333 7dee1efe and run the
    keyboard/reduced-motion + video/badge harnesses, then Phase E gates.

LATEST (2026-10-19 ~23:30, session 5 "Resume Interrupted Session", Opus coordinator):
  dev 9309b1ff, backend master c4115594, admin master bbabc713 (unchanged, verified live).
  Recovered + pushed (no PRs yet): backend feat/084-institution-identity 47d8a05 (claims
  service, 25/25), feat/084-moderation-studio-api d6dde04 (migration 110 + S1 service + router,
  34/34). #97 c4caaff: 3 Codex threads fixed + resolved. B-18 NOT reproduced (24 runs,
  b18-like-continuation-qa.md). Staging web build was talking to production until rebuilt
  with BACKEND_BASE_URL pinned (same doc). Backups: G:/kubus-build-backup/084-20261019-recovery.
  #325 -> b9f993bd, #326 -> a1e2ab33 (all Codex threads fixed + resolved; full tier re-running).
  OWNER: merges (#325, #326 once green; #97 CLEAN; #96/#98/#99 ready-for-review is the owner's
    call), #97 production read, production health (Home backend, OrbitDB, standby replay).
  NEXT THREE: 1. open draft PRs for feat/084-institution-identity (base: #99 branch) and
    feat/084-moderation-studio-api (stacked) once #99 merges; add claim routes. 2. Studio S2
    bounded reads (docs/MODERATION_STUDIO_API.md) + search merged_into_id filter. 3. Staging
    journey: put migrations 109/110 into the backend candidate, migrate staging084, start the
    admin dev server (5174), walk Review Deck / Map Audit with the synthetic admin.
  RESUME QA: cd G:/kubus-build-084/_staging; node start-backend.cjs (if 53101 is down);
    node serve-web.cjs G:/kubus-build-084/frontend-candidate/build/web 58180;
    node b18-run.mjs firefox 3 300,1500,4000
  Detail: integration-ledger.md "Session 5". Older blocks below are history.

DATE: 2026-10-19 (session art-kubus-87, Opus coordinator, Haiku-first brief)
CURRENT PHASE: Milestones 1-2 DONE. M1 security #315 (CLEAN, all green at 6953282f),
  backend #94 (01ffd59), CI tier #322 (READY, full run green). M2 video + badges
  committed and browser-verified (browser-qa-video-badges.md), not pushed.
DEV SHA: 2190782e   MASTER SHA: 841d92a3   (unchanged)
OPEN PRS (this program): #315 security (draft: device acceptance owed), #318 fallback
  (draft, CLEAN), #312 startup (draft, remote 4d4733ec, local 94f637b9), #322 CI tier
  (ready), backend #93 Orbit (draft), backend #94 passkey (draft)
OWNER ACTIONS: review+merge #322 first (makes every later draft cheap); merges of all PRs
  (classifier denies gh pr merge); one private security policy decision; device acceptance
  for #315 (Android 8 biometric prompt, cold-start lock after OS kill, backup exclusion)
UNPUSHED (all committed, clean): video 0cdc9432, badges ef3f27be, a11y 0900e878,
  dialogs edda7c92, map 0ade69d4, perf 94f637b9, evidence (this branch)
DISPOSABLE: G:/kubus-build-084/candidate-ui (chore/084-ui-candidate 040b3880 + build/web +
  output/playwright evidence); delete when no longer needed
AGENT DEFINITIONS: G:/WorkingDATA/art.kubus/.claude/agents/{haiku-scout,haiku-implementer,
  sonnet-reviewer}.md - a fresh session launched from G:/WorkingDATA/art.kubus loads them
SECURITY: findings + 2 deferred low items private:
  C:/kubus-build-084/_private/security/2026-10-19-review-5-084-security.md
UPDATE 2026-10-19 (session 2): #322 corrected at 71406fdf (draft tier reports as non-required
  'PR validation (draft tier, not merge evidence)'; full run 39228957912 green; probe PR #324
  run 39233279590 proved the draft run produces no 'PR validation required'; thread resolved;
  merge BLOCKED only by classifier denial of gh pr merge - OWNER MERGES #322 (squash)).
  video/badges/a11y/dialogs/map each passed analyze --fatal-infos --fatal-warnings, custom_lint,
  ratchet, format and focused tests locally (see ledger); NOT pushed - waiting for #322 on dev so
  the drafts get the cheap tier. Android backup stays disabled: audit (inferred plugin file names)
  says FlutterSecureStorage.xml ciphertext would restore without its Keystore key; any future
  re-enable needs backup_rules.xml + data_extraction_rules.xml excluding secure storage and
  FlutterSharedPreferences in cloud-backup AND device-transfer, verified on a physical device.
UPDATE 2026-10-19 (session 3, art-kubus-73): dev c53ab80e (#322 merged). Drafts #325 video,
  #326 badges (+review fixes), #327 a11y, #328 dialogs, #329 map, #330 B-20 email session,
  backend #95 authorship (P0 addendum) all pushed; #325-#329 draft-tier green. Owner addendum
  "Cultural Data, Authorship and Moderation" added as scope rows CD-01..CD-15. In progress:
  Flutter CD-04 on fix/084-profile-authorship. Next after CD-04: SEO authored count (CD-05),
  then the read-only data audit (CD-07, needs owner read-only DB access) and moderation state
  (CD-08: inspect the existing `migration:contract:editorial` gate first).
CHECKPOINT 2026-10-19 evening (session 3): PRs opened this session -
  art.kubus: #325 video, #326 badges, #327 a11y (READY, full tier), #328 dialogs, #329 map,
    #330 B-20 email session, #331 CD-04 profile authorship (draft tier green where run)
  art.kubus-backend: #95 CD-01/03/05 authorship (all green), #96 SEO authored (stacked on #95),
    #97 CD-07 audit tooling (not run on prod), #98 CD-10 import evaluation,
    #99 CD-08 editorial state (stacked on #95)
  admin.kubus: #17 CD-11 Review Deck (first slice)
  Merge order for backend: #95 -> retarget #96/#99 to master -> #97/#98 any time.
  Remaining CD rows: CD-06 contributions (needs model), CD-09 propagation audit beyond
  syncArtworkById, CD-11 Map Audit + Data Inspector + staging journey, CD-12/13 institutions,
  CD-14 street-art ingestion, CD-15 SEO/index eligibility for unreviewed external records.
  Owner gates: merges; prod read-only run of #97; staging admin journey for #17/#99;
  UX naming "Added Public Art" tile vs "Public art added" section (#331).
NEXT THREE ACTIONS (fresh session; superseded by the update above where they conflict):
  1. After #322 merges: merge dev into video/badges/a11y/dialogs/map, push each as a
     draft PR (cheap tier), one push each.
  2. Startup #312: push local 94f637b9, then finish the D4 open items listed in the
     2026-10-18 memory (managed-wallet startup sync, _clearLastError, desktop RPC).
  3. Re-read scope-matrix.md MISSING/PARTIAL rows (onboarding continuation, support/admin
     compat, provenance/SEO, map harness) and pick the next smallest release blocker.
```

## Traps carried forward

- Flutter SDK is `C:/dev/flutter` (3.44.2), not on the Bash PATH.
- `dart format lib` rewrites ~150 files; format only changed files.
- `gen-l10n` drops the `_supportedLocaleName` / locale guard; run the bump-l10n skill.
- Bash `git show origin/dev:path` needs `MSYS_NO_PATHCONV=1`.
- `gh pr merge` is denied by the permission classifier; the owner merges.
- The production API returns 403 to local origins; browser harnesses must rewrite
  `QA_API_ORIGIN` or mock.
- Node test of `maplibre_runtime_atmosphere` needs `--experimental-vm-modules`.
