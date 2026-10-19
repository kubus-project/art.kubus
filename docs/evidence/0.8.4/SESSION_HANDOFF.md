# 0.8.4 session handoff

Read this first when resuming. Detailed state: [integration-ledger.md](integration-ledger.md)
and [scope-matrix.md](scope-matrix.md). Security findings are never written here; they
live in the private draft advisory and `C:/kubus-build/_private/security/`.

```text
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
