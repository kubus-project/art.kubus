# Sonnet 5.5 handoff: finish v0.8.5 from this checkpoint

## Resumed run, 2026-10-23 afternoon (Sonnet 5.5) — read this first

This section supersedes the checkpoint text below where they differ. Still **NO-GO**.

- **App full-tier CI was not green at the checkpoint head.** Run 39937612488 (6a885b2d) failed one test (a stale expectation that contradicted the withheld-marker-snapshot policy), which also skipped motion/Chrome/flags. Fixed test-only in `207e9a90`. Run 39941704781 then passed the Flutter suite (5832) and PRODUCT motion, but the explicit Chrome map step was cancelled by the 60-minute job limit while still compiling; fixed by moving it to its own job (`94248e4f`, `b3519e3c`).
- **Auth:** the "Not now / entity-URL mismatch" was not reproduced in five configurations. A different, reproduced defect was fixed instead (sheet destroyed by late route replacement; intent cancelled). Details: `evidence/marker-policy-20261023/auth-sheet-interruption-finding.md`.
- **OrbitDB lifecycle: PASS** (20/20) at backend 88d792ff, isolated; harness v1 failures were all harness assumptions. `evidence/marker-policy-20261023/orbitdb-marker-lifecycle-pass-88d792ff.json`.
- **Head to qualify:** app `b3519e3c` (PR #358), full-tier run 39949987686. Record its result in the readiness ledger; do not call it PASS until every job including `map_browser_regression` and the aggregate has finished.
- Unchanged owner gates: DNSLink pointer (dated 2026-10-09), HA recovery, production-signed Android/iOS artifacts, physical device and installed App Links, released-v0.8.4 performance comparison, all protected merges/deploys/tags.
- Traps found: `OrbitDBService.close()` stops the remote Kubo daemon (do not call it against a shared Kubo); the backend's in-memory rate limiter blocks repeated logins in a long browser session (restart the local backend between runs); in non-raw Python strings the escapes backslash-f and backslash-a in Windows paths become control characters.

---


Checkpoint: 2026-10-23, Europe/Ljubljana. **NO-GO; v0.8.5 is not released.**
Continue the preserved candidate. Do not restart orchestration, repeat completed
audits, or rebuild the existing final-head artifact unnecessarily. All workers
were asked to freeze for this handoff; no auth fix is in progress.

## First actions

1. Read this file, [readiness](RELEASE_0.8.5_READINESS.md),
   [preflight](RELEASE_0.8.5_PREFLIGHT.md), and applicable repository instructions.
   Fetch and inspect exact worktrees before editing. Copy SHAs from Git output;
   several worker messages contained mistyped full SHAs that were reconciled.
2. Check app full-tier run **39937612488**, exact head **6a885b2d**. At handoff
   it was still running the Flutter test suite. Web build/browser smoke,
   Android and unsigned iOS compilation, routing, compatibility and guardrails
   had passed. Motion, explicit Linux Chrome map regressions, community flags
   and aggregate must actually finish. Do not cancel or call the run PASS early.
3. Resolve the authenticated **Not now / entity-URL mismatch** below before
   declaring auth acceptance. First eliminate fixture effects; do not change
   security or routing speculatively.
4. Resume the bounded isolated OrbitDB lifecycle harness below. It failed
   before reaching Orbit; it is not lifecycle acceptance.
5. Refresh #359 with terminal CI, actual auth/Orbit results and exact heads.
   Produce a defensible GO/NO-GO. Owner-only operational/signing gates remain.

Use focused Luna XHigh implementation/independent review where available.
Keep one writer per file/worktree. Any new auth/routing fix needs independent
review on its immutable pushed SHA before integration. Preserve all completed
work and unrelated v0.9 branches. No protected merge, production migration,
deployment, tag, publication, signing dispatch or live HA intervention is approved.

## Verified candidate heads and ancestry

| Surface | Exact SHA / status |
| --- | --- |
| App PR #358 | `6a885b2d9eca78534d6dd0a5d97cf29c07c6a312`; open, pushed. Source and workflow independently reviewed. Full CI 39937612488 pending at freeze. |
| Backend PR #131 | `88d792ffccc4ccaff96f82f230d4b9e14b7e00a1`; open, pushed; full exact-head CI **39938446580 SUCCESS**, including PostgreSQL matrix and required gate. PR body updated. |
| Admin PR #18 | `a2d788804779baf63a6c091d4734ce04ea38a887`; unchanged. Fresh isolated session/role/CSRF/logout smoke passed; prior UI proof retained through tree equivalence. |
| Docs PR #359 | `docs/release-0.8.5-preparation`; this handoff/readiness/evidence are on that topic. Re-read its head rather than reusing a pre-handoff docs SHA. |
| Production backend baseline | `46c9b84fed42aff21463c788e5e13994689c7f73`; candidate was not deployed. v0.8.4 release baseline remains preserved. |
| Preserved rejected strict-marker WIP | `495ebfa2d350176e30c88bd3b87e8c3a4fde8455`; do not integrate. |

Backend ancestry: reviewed #129 `1e94d5b2` + #130 `9f53af8a` assembled at
`9401f734`; reviewed CSS #132 `bd8bb310` integrated at `3e09a1a3`; reviewed
bounded-marker policy `27b6c94f158b0452a56c53ea56a1cd4d58c9e034` integrated at
`d6ffb166`; reviewed test corrections `114da50d`/`d518c48f` then reviewed
ephemeral CI-DB initialization `88d792ff`. No protected PR was merged.

App ancestry: original public-entry/history/auth work `085726e7` -> CI budget
fix `a1629792` -> snapshot guard `6881043a`/`cd9611f4` -> cache guards
`0e751ff8` -> reviewed socket/mounted-map cleanup `0a22db86` -> reviewed
explicit Linux Chrome regression step `6a885b2d`. All are in #358.
The full-tier job retains its 60-minute limit and all motion/flag gates.

## Owner decisions: do not ask again or change them

- Preserve the frozen **8,955** eligible legacy UUIDs as **unreviewed** under
  the approved cohort/material-fingerprint rules. New/materially changed
  markers require approval. Always deny private/inactive/rejected/archived
  markers and hidden linked owners; revocation is monotonic across reverts.
- Public visibility is neither editorial verification nor SEO permission.
  Unreviewed legacy markers do not earn editorial enrichment/independent SEO.
- Auth returns to the canonical entity and offers the intended action without
  automatic replay. Stripping arrival query/fragment is an accepted auth-only
  exception; ordinary navigation preserves them.
- Emulator use is authorized, but it must be off after testing. Do not remove
  the existing 0.8.1 debug app/data or override App Link verification to fake PASS.

The **9,046 vs 8,955** issue is reconciled: 9,046 was not a reproducible current
total; a historical audit uses it for the `artwork_not_ar` subset. Fresh evidence
has 9,050 raw active/own-public/unreviewed rows, 95 failing existing linked-owner
visibility, and 8,955 eligible. Do not claim 91 rows were removed. The frozen
cutoff is `2026-10-22T23:31:10Z`; capture has 8,955 unique IDs, zero eligible
post-cutoff/missing-time rows, and matching count/checksum. Independent review
verified completeness and a later typed-projection comparison with **0/8,955**
fingerprint drift. See [decision](RELEASE_0.8.5_MARKER_POLICY_DECISION.md) and
the committed evidence under `docs/ops/evidence/marker-policy-20261023/`.

## Completed evidence: retain, do not repeat on the same sources

- Backend final exact-head CI 39938446580 PASS: lint, deterministic suite,
  schema parity, both clean snapshots (103 migrations/144 tables), editorial
  migration and full PostgreSQL contracts. Marker reviewer independently ran
  12/12 PG tests and schema parity; fixture reviewer ran 14/14 cache units.
  Fresh DB migration + spatial suite passed 24/24.
- A local full Jest run retained one known 5-second wallet-login timeout:
  250 suites/2,542 tests passed, one failed; isolated auth file passed 11/11.
  Do not relabel that local run green; final hosted CI is green independently.
- Final **6a885b2d local build + 88d792ff renderer**: JS family matrix 64/64,
  no-JS SSR matrix 64/64; Chromium/Firefox desktop/mobile, EN/SL, eight families.
  Map handoff/Back/Forward 4/4; actual MapLibre camera direct+refresh lat46.05,
  lng14.51, zoom12; URL/query/hash retained.
- Final SSR-L1 five cases PASS: mobile/desktop, 320px SL at 150% text,
  dark/reduced motion; 500ms/8s/failure flow, readable SSR, failure-only manual
  Refresh, status accessibility, zero measured content displacement/CLS.
- Public matrix attempted 92 POSTs; all were intercepted locally and answered
  405 before egress. No API writes reached a service.
- Fresh isolated admin/moderator auth/role/CSRF/logout browser smoke PASS.
- Earlier Android API34/Chrome155 emulator proof on 085726e7 remains preserved;
  no final-head emulator run or physical-device proof was added.

Final browser evidence directory:
`G:\kubus-build-084\_staging\final085-resume-20261023\operational\final-head-6a885b2d-20261023`
contains `final-head-qa-manifest.json`, `final-head-qa-summary.md`, all result
JSON/scripts/screenshots and `cleanup-state.json`. Summary/manifest are also
copied into #359. The earlier evidence is preserved, not overwritten.

Exact tested local artifact:
`G:\kubus-build-084\_staging\final085-resume-20261023\app-fallback-cache-guards\build\local-finalhead-6a885b2d`.
Flutter3.44.2/Dart3.12.2, release-mode **development config**, version0.8.5,
build1432513261. It is not the uploaded CI or production release artifact.
SHA256SUMS file digest `3b7637538827c84f487e10a58953a437574d472490e7a398fce89e38f5c7cc31`;
main.dart.js `2d234319371523743f1230a78f2b1a1e5cb86cdd0a1fe8982c915f3780710238`.
Compiled APIs are loopback4285; app/share origin4288. Identity JSON is committed.
GitHub artifact download previously failed with account-egress 503; do not loop
retries or substitute the old CI artifact silently.

Local browser-widget compilation failed before execution because Windows DDC
converted `file:///C:/.../ddc_outline.dill` to `/C:/...` and could not find SDK
root. **0 browser cases executed locally**; VM39/39 and independent service9/9
are separate. CI now explicitly runs `test/map/map_screen_web_smoke_test.dart`
on Linux with Playwright Chromium. Do not patch the SDK or weaken tests.

## Auth finding: next investigation, no fix yet

Real local `POST /api/auth/login/email` returned200 for a synthetic walletless
non-admin user against backend88d792ff. The exact local app displayed
`Like this artwork?` for the canonical QA artwork; no Like mutation was made.
After clicking **Not now**, signed-in Home content appeared while the URL
stayed `/en/artworks/{id}`. This is observed but **not yet attributed** to a
product defect. Do not report full positive auth-return PASS.

Only canonical artwork GET was mocked via4176; profile/saved/messages reached
real backend4285. Correctly decoded browser JWT gave profile200, saved401
`Authenticated wallet is required`, messages400 `Invalid user`. A previous
direct-fetch `Invalid or expired token` was a **harness error**: SharedPreferences
stores `flutter.jwt_token` as a JSON-encoded string; `JSON.parse` it before
constructing a Bearer header. Never expose tokens.

Next: recreate a disposable DB and use a fresh browser context plus a synthetic
wallet-linked email account matching the v0.8.5 baseline. Compare immediate vs
delayed Not now and a no-dismiss control; record actual auth/session/visible
route/address/history. Distinguish walletless-fixture effects, asynchronous
401 handling and a genuine continuation/router pop. Do not pull v0.9 walletless
features or relax auth. If a product bug is confirmed, make a minimal isolated
topic from6a885, test, obtain independent review, then update #358 and rerun
relevant exact-head acceptance.

Auth evidence/helper directory:
`G:\kubus-build-084\_staging\final085-resume-20261023\app\map-fallback-cache-guards`.
Contains `auth-positive-action-confirmation.png`, `auth-positive-return-after-refresh.png`,
`start-local-auth-backend.cjs`, `static-preview.mjs`, local artifact identity,
VM/analyzer/DDC logs. **The auth helper contains synthetic credentials: do not
copy it into PRs or print it.** Its current seed is walletless; adapt only a
local fixture after checking the contract. `acceptance.md` in this directory
still has stale pre-commit/auth-pending text; this handoff supersedes that text.

All auth/preview services are stopped. Auto-remove container
`kubus-auth-e2e-20261023`/DB`auth_e2e085` on55440 no longer exists: recreate,
do not assume the user/session remains. Static script serves the existing
artifact on4288; backend helper uses4285 after a valid disposable DB exists.
No auth source branch/edit was created. Never use shared53107/53108 or prod DB.

## OrbitDB: bounded harness blocker, no runtime PASS

`G:\kubus-build-084\_staging\final085-resume-20261023\backend-orbitdb-lifecycle`
contains `orbitdb-marker-lifecycle.js`, `orbitdb-marker-lifecycle.json`, and
`candidate-container-output.log`. Exact candidate88d792ff; syntax check passed,
but bootstrap failed at baseCounts with `relation "art_markers" does not exist`
after attempted schema_complete.sql +113. No rows/grants, Orbit init/write/read,
API call or snapshot publication occurred. Both temporary DBs were dropped.
Investigate harness schema execution/search_path, reusing proven migration
runner/bootstrap contracts rather than treating this as a production bug.

Isolation was verified: Docker context`desktop-linux`; internal-only network
`kubus-ssr-orbitdb-20261022`; preserved task PG15.8/PostGIS3.4.3 on55906 and Kubo
on55905, loopback only, private swarm and0 peers. DNSLink off, publisher disabled,
no external peers. Both `kubus-ssr-orbitdb-pg-20261022` and
`kubus-ssr-orbitdb-ipfs-20261022` are now Exited(0); volumes untouched. Redis and
old Node stayed stopped; candidate was an ephemeral removed container. Start
only these task services if needed, reverify isolation, never reset volumes.
Do not replace this missing actual lifecycle proof with the passing SQL tests.

## Owner-only and unavailable gates

- Current DNSLink registry is dated2026-10-09. Read-only09:54UTC evidence found
  repeated5s upload/pinning timeouts; cluster-pin stage is a strong inference,
  not a proven cause for every failure. Diagnose/remediate only after approval.
  Qualify a new pointer only from the reviewed schema-ready candidate producer.
  App guard blocks stale marker snapshot reads locally; it does not fix the
  live pointer. Historical immutable IPFS CIDs remain fetchable; never promise erasure.
- HA: Oracle writable but0 streaming replicas, lost/inactive slot; Home stale,
  unready/503. Recovery packet is in preflight. Backup restore, authority/witness,
  fencing, slot/reseed plan and explicit approval precede intervention. No repair run.
- No production-signed v0.8.5 APK/AAB or distributable IPA qualified. CI temporary
  device-test signing is not release signing. Physical Android and verified
  installed-candidate App Links remain blocked. Signing and publication are
  distinct protected approvals; no mobile-release dispatch/tag/publish.
- Equivalent released-v0.8.4 performance comparison unavailable; no claimed
  improvements/field INP. Preserve the limitation rather than rebuilding old artifacts.

## Worktrees, shutdown and reporting

- App integration: `G:\kubus-build-084\s27-public-entry-app`, branch
  `fix/085-public-entry-integration`, clean at6a885.
- App fallback topic: `G:\kubus-build-084\_staging\final085-resume-20261023\app-fallback-cache-guards`,
  branch`fix/085-fallback-map-cache-guards-20261023`, clean at6a885.
- Backend integration: `G:\kubus-build-084\_staging\final085-resume-20261023\backend`,
  branch`codex/085-backend-integration-20261023`, clean at88d792.
- Backend CI-fix topic: `...\backend-pg-ci-fix`, clean at88d792.
- Docs: `G:\WorkingDATA\art.kubus\_worktrees\release-085-preparation-docs`.
  Update this topic/#359; keep one writer. Main nested app/backend checkouts
  have unrelated work and must not be repurposed/reset/cleaned.
- Owned previews4175/4176/4178/4285/4288 and auth DB55440 are shut down.
  ADB empty; emulator off. Re-check before any restart; do not kill unrelated services.
- CI39937612488 remains running remotely; it was deliberately left active.
  Redundant draft39937680368 was cancelled only after the full-tier run was confirmed.

Use repository-qualified gh commands, e.g.
`gh run view 39937612488 -R kubus-project/art.kubus --json headSha,status,conclusion,jobs`.
Preserve report distinctions: implemented / reviewed / pushed / tested / merged /
deployed / owner accepted / released. The next final report must remain NO-GO
while auth, Orbit or owner-only/device gates remain unqualified.
