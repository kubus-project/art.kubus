# v0.8.5 release readiness — 2026-10-23

**NO-GO. v0.8.5 is not released.** Implementation advanced, but final acceptance and marker policy qualification are incomplete. Execution agents hit the account usage limit. No protected branch merge, tag, publication, production deployment, production data migration or HA repair was performed in this run.

## Exact candidate ledger

| Surface | SHA / state |
|---|---|
| App, draft PR #358 | `085726e76b24c1a240f37a99d469e897aba17098`, pushed; independent source review clear |
| Backend deployed Oracle baseline | `46c9b84fed42aff21463c788e5e13994689c7f73`, container GIT_COMMIT verified |
| Backend SSR-L1 / language fix, PR #129 | `1e94d5b278df7627fea4fe5f23e993d2b0966517`, pushed, reviewed, required CI passed |
| Backend test restoration, PR #130 | `9f53af8a7bc71969daf3f7d3efdbfd058b172c54`, pushed; targeted 55 tests passed; final integration not performed |
| Admin, open PR #18 | `a2d788804779baf63a6c091d4734ce04ea38a887`, includes #19; CI green and source compatibility reviewed; exact-head browser gate open |
| Marker editorial gate | Separate WIP topic `codex/marker-editorial-visibility-20261022`; exact SHA recorded below. NOT reviewed or release approved. |

There is **no single integrated final backend candidate** combining #129, #130 and the marker gate. Do not deploy a branch merely because its individual tests passed.

App #353 is in dev; #354/#355/#356/#357 are preserved and assembled in draft #358, not merged into protected branches by this run. Backend #117/#120/#123–#128 ancestry was reconciled against current master; #121/#122 code exists in that ancestry although their PR records remain open. #129/#130 are additional open work. Documentation is draft app PR #359. Unrelated v0.9 work and shared-checkout WIP were preserved.

## Recovered issues and fixes

- Desktop shell navigation after refresh was misclassified as Back: corrective routing is in #358.
- Exact entity readiness now requires matching type, ID, path and locale; engine readiness is a separate mark. Timers only expose loading/slow state.
- SSR-L1 has localized 500 ms loading, 8-second slow state and failure/manual Refresh behavior; no automatic reload.
- `/map` camera query was parsed but unused; #358 now passes validated camera state through the existing controllers for mobile/desktop initial and mounted updates.
- `/map?lang=en#camera` lost its URI during shell replacement; corrected in final #358 head.
- SL post/marker English-content fallback claimed the wrong document language; fixed in #129 without changing canonical/index ownership.
- Dropped role-variant and row-lock race regression tests were restored in #130.

## QA matrix

| Gate | Result / evidence boundary |
|---|---|
| Final app source review | PASS, independent report `security-admin-review/app-pr358-085726e7-backend-pr129-1e94d5b-review.md`; focused route tests 34/34 |
| Final app local analyzer | PASS; no issues. Focused route/parser checks passed. Chrome widget test stalled and was stopped: NOT PASS. |
| Exact app full CI, run 39835198150 | NOT GREEN: completed/cancelled; Flutter analysis/lint/tests cancelled; aggregate required check failed. Web build/browser smoke and unsigned Android/iOS compiles succeeded. |
| SSR/no-JS | PASS 64/64 at backend #129 exact 1e94d5b: 8 families × EN/SL × Chromium/Firefox × desktop/mobile; metadata, language fallback, readable content, URL query/hash. `ssr-nojs-64-matrix-1e94d5b.json` |
| JS direct + refresh | PASS 64/64 at **earlier app d182cfbb**, backend 1e94d5b. `candidate-d182-js-64-matrix.json`. This is NOT final app acceptance. |
| Final app JS/history/camera | BLOCKED: final artifact matrix not completed. Source/props tests do not prove actual camera motion. |
| Protected actions / positive auth return | BLOCKED: final integrated positive auth/action matrix incomplete. Synthetic GET fixtures do not prove authentication completion. |
| Android Chrome emulator | PARTIAL: API34 Pixel 6 / Chrome 113 opened readable SSR; final takeover/history/camera and installed-native matrix incomplete. Emulator is not physical Android proof. |
| Physical Android Chrome | BLOCKED: no device attached; remains required release gate. |
| Native App Links | PARTIAL: v0.8.4 signed APK certificate matches live and checked-in assetlinks; final installed 0.8.5 App Link behavior unverified. |
| Backend renderer | PASS targeted 130 tests and required hosted CI. Full local suite had one 5s auth timeout under load; isolated failing file then passed 11/11. Do not report that full local run green. |
| Admin/security | Source compatibility reviewed; #130 two suites/55 tests pass; predecessor E2E evidence does not qualify current admin exact head. |
| OrbitDB / snapshots | PARTIAL: isolated mirror-mode artwork publish/readback and Kubo snapshot registry/dataset readback passed, DNSLink off. Marker approval/rejection/revert and stale fallback/purge lifecycle NOT qualified. |
| HA | BLOCKED: Oracle zero streaming replicas / replication unhealthy; Home ce11d5fcaeaf081b981b84cfb69c4fcb641b9047 stale and readiness/writability 503. No repair authorized/performed. |
| Accessibility / responsive | PARTIAL: four browser/viewport SSR and earlier takeover evidence; final semantics, loading/failure, contrast and reduced-motion acceptance incomplete. |

## Marker policy — critical data prerequisite

Read-only Oracle aggregate audit (read-only transaction, rollback) found **9,046 otherwise-public eligible markers, all unreviewed**. Legacy migration 108 intentionally left these visible. The requested strict approved-only policy therefore has material public-map impact.

A separate 17-file WIP marker-only gate was preserved and pushed. It is unfinished, unreviewed and unqualified; do not integrate or deploy it. No records were bulk approved, hidden or deindexed. Owner-reviewed legacy classification and a reviewed rollout decision are required. Do not infer approval from uploader identity or legacy public flags. Artwork publication must remain a separate policy.

## SEO and performance boundaries

Historic near-10k indexed count, 875 impression-bearing URL export, capped 1,000-row export, and source-policy eligibility are different measurements. No current Google index coverage result was established and no mass canonical/noindex operation was performed.

Released-v0.8.4 equivalent-build performance comparison remains BLOCKED. Earlier candidate/Lighthouse probes are not release-baseline improvements. No field INP or final comparative CWV acceptance is claimed. Chrome DevTools MCP 1.12.0 was enabled in local Codex config with a backup; command startup verified, current-session trace integration was not completed.

## Native artifacts and signing

Unsigned Android/iOS CI compiles passed at final app SHA. No signed v0.8.5 APK/AAB or distributable IPA is qualified. Local Android release keystore/key.properties absent; protected environment signing must be checked through the existing release workflow. Repository-secret absence alone does not establish environment-secret absence. Existing signed v0.8.4 proves prior signer identity, not a signed 0.8.5 artifact. Final immutable checksums/release manifest remain pending; template values must stay null rather than fabricated.

## Release / rollback procedure and owner gates

Draft PR #359 contains proposed notes, preflight and pending artifact manifest. Refresh it against final heads before use. Gate sequence: reviewed candidate and exact-SHA acceptance → schema/config/backup/rollback preflight → owner-approved backend rollout → compatible admin → frontend web → native distribution separately. Stop on failed gates. No protected action is authorized by this report.

Before release: resolve 9,046-marker classification; finish/review/test marker predicate and stale Orbit lifecycle; assemble backend candidate; rerun final app CI and rendered/browser/physical-device/auth/failure matrix; qualify HA recovery and rollback; produce signed native artifacts and immutable checksums. Verify current deployment/image SHA and schema parity immediately before any approved promotion.

Use existing protected workflows and guarded atomic web rollback. Backend baseline rollback anchor is current Oracle 46c9b84f, subject to image/schema verification. Admin production rollback artifact must be identified. Preserve backups and do not guess host paths. After an approved dev→master release, reconcile ancestry back into dev with a merge commit; require master-only cherry-pick-aware count zero.

## Preservation and shutdown

All implementation work remains isolated. Marker WIP is also saved as `marker-editorial-unreviewed.patch`. Task-owned Orbit Redis/Node/Kubo/PostgreSQL containers were stopped, not removed; data/evidence retained. ADB shows no attached devices and no emulator/QEMU process remains. Shared Docker resources and production were left untouched.

Final recommendation: **NO-GO**. This is an auditable incomplete release candidate, not a released or fully accepted v0.8.5.
Marker WIP exact pushed SHA: `495ebfa2d350176e30c88bd3b87e8c3a4fde8455`.
