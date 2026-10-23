# v0.8.5 release readiness — 2026-10-23

**NO-GO. v0.8.5 is not released.** Marker source review is clear, but final app review, snapshot freshness, integrated acceptance, HA and signed/native qualification remain incomplete. This report records completed evidence separately from pending gates. No protected branch merge, tag, publication, production deployment, production data migration or HA repair was performed.

## Exact candidate ledger

| Surface | SHA / state |
|---|---|
| App, draft PR #358 | `6a885b2d9eca78534d6dd0a5d97cf29c07c6a312`, pushed; independently reviewed snapshot/cache/socket/mounted-map fallback guards plus explicit full-tier Chrome regression step. Exact-head run 39937612488 is pending. Previous a1629792 full-tier run remains PASS evidence for that earlier head. |
| Backend deployed Oracle baseline | `46c9b84fed42aff21463c788e5e13994689c7f73`, container GIT_COMMIT verified |
| Backend SSR-L1 / language fix, PR #129 | `1e94d5b278df7627fea4fe5f23e993d2b0966517`, pushed, reviewed, required CI passed |
| Backend test restoration, PR #130 | `9f53af8a7bc71969daf3f7d3efdbfd058b172c54`, independently reviewed and integrated with #129 in #131 at 9401f734; hosted CI passed there. |
| Backend candidate, PR #131 | `88d792ffccc4ccaff96f82f230d4b9e14b7e00a1`; includes #129/#130, reviewed CSS #132 (bd8bb310), marker policy 27b6c94, fixture/cache-regression correction d518c48 and independently reviewed CI database initialization. Exact-head run 39938446580 is pending. |
| Admin, open PR #18 | `a2d788804779baf63a6c091d4734ce04ea38a887`; tree-equivalent UI proof preserved; fresh isolated role/session/CSRF/logout browser smoke passed against backend 9401f734. |
| Marker selected-policy topic | `27b6c94f158b0452a56c53ea56a1cd4d58c9e034`, independently cleared for candidate integration; reviewer reran 12/12 focused PG tests and schema parity, checked matching migration/schema function blocks and provenance. Replaces uncleared 1fac612/ff30f0a and is integrated in #131. |
| App snapshot-fallback topic | cd9611f → 0e751ff → 0a22db86 → `6a885b2d9eca78534d6dd0a5d97cf29c07c6a312`; independently reviewed and integrated into #358. Snapshot, cache, event and mounted-map state are guarded during confirmed fallback. VM/service tests passed; actual browser acceptance remains pending. |

**#131 is the single integrated backend candidate**, including the reviewed marker gate. It is not a qualified production release until its exact integrated acceptance and operational gates pass. Do not deploy a branch merely because its individual tests passed.

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
| Prior app full CI | PASS at a1629792, [run 39876644908](https://github.com/kubus-project/art.kubus/actions/runs/39876644908): required aggregate, analysis/lint/tests, PRODUCT motion, both community flag configurations, backend/routing contracts, web build/smoke, Android and unsigned iOS compilation. [Saved job evidence](evidence/marker-policy-20261023/app-a162-full-tier-ci.json). Earlier run 39835198150 hit the 45-minute budget; it remains cancelled, not PASS. |
| Final app full CI | PENDING at 6a885b2d, [full-tier run 39937612488](https://github.com/kubus-project/art.kubus/actions/runs/39937612488). Independent source review clear; service/fallback tests 9/9 and workflow contracts 45/45 independently passed. Author VM suite 39/39; local browser-only widget run executed 0 tests because Windows DDC failed before launch. Linux CI now explicitly runs those browser regressions. Redundant auto draft run 39937680368 was cancelled after the full-tier run was confirmed; it is not acceptance evidence. |
| SSR/no-JS | PASS 64/64 at backend #129 exact 1e94d5b: 8 families × EN/SL × Chromium/Firefox × desktop/mobile; metadata, language fallback, readable content, URL query/hash. `ssr-nojs-64-matrix-1e94d5b.json` |
| JS direct + refresh | PASS 64/64 on app 085726e7 CI artifact 12450603749 and backend renderer 1e94d5b: Chromium/Firefox desktop/mobile, EN/SL, eight families. `final085-resume-20261023/app/candidate-085726e-final-js-64-matrix.json`. Earlier d182 evidence remains preserved. |
| Final app JS/history/camera | PASS for the tested 085726e7 artifact: artwork→map→Back→Forward across four browser/viewport contexts; actual MapLibre center/zoom direct+refresh. a1629792 changes only workflow timeout; newer regenerated artifact revision/download and any subsequent app source change require separate qualification. |
| Protected actions / positive auth return | PARTIAL: rendered mock email-login flow returns to canonical artwork and offers explicit action confirmation without replay. Owner accepts auth-only query/fragment stripping; ordinary navigation retains them. Real-backend positive authentication/action E2E remains unproven. |
| Android Chrome emulator | PASS for completed API34/Pixel 6, Chrome 155.0.8059.87 browser cases: artwork direct/refresh, numerical map camera, Back/Forward. Separate numeric map-after-refresh addon incomplete after preview shutdown. Emulator is not physical-device or installed-native proof. |
| Physical Android Chrome | BLOCKED: no device attached; remains required release gate. |
| Native App Links | PARTIAL: v0.8.4 signed APK certificate matches live and checked-in assetlinks; final installed 0.8.5 App Link behavior unverified. |
| Backend renderer | PASS targeted 130 tests and required hosted CI. Full local suite had one 5s auth timeout under load; isolated failing file then passed 11/11. Do not report that full local run green. |
| Integrated backend | At d6ffb166: toolchain/lint/schema parity/Compose and both clean schema bootstraps PASS (103 migrations/144 tables); editorial migration contract PASS. Reviewed d518c48 corrections restore production-compatible fixtures and stale-cache revalidation assertions; focused units 39/39, PG 24/24, independent cache unit 14/14. Full local run: 250 suites/2,542 tests passed, one auth timeout, 22 suites/216 tests skipped; isolated auth retry 11/11. CI 39937175593 deterministic tests passed but the job's unmigrated service DB caused PG failure. Reviewed 88d792ff adds migration of that ephemeral DB; fresh empty-DB reproduction migrated through 113 and passed 24/24. [Reproduction evidence](evidence/marker-policy-20261023/postgres-ci-bootstrap-reproduction.json). Final exact-head CI pending; full acceptance is not yet green. |
| Admin/security | PASS for source compatibility, tree-equivalent prior UI coverage, and fresh isolated admin/moderator session/CSRF/logout smoke against backend 9401f734; zero business mutations/external requests. Production acceptance remains pending. |
| OrbitDB / snapshots | PARTIAL: isolated mirror-mode artwork publish/readback and Kubo snapshot registry/dataset readback passed, DNSLink off. Marker approval/rejection/revert and stale fallback/purge lifecycle NOT qualified. |
| HA | BLOCKED: Oracle zero streaming replicas / replication unhealthy; Home ce11d5fcaeaf081b981b84cfb69c4fcb641b9047 stale and readiness/writability 503. No repair authorized/performed. |
| Accessibility / responsive | PASS for scoped SSR loading/failure matrix at CSS bd8bb310: 390px EN, desktop, 320px SL with 150% text, dark/reduced motion; hidden status absent from role tree, failure-only Refresh, readable SSR, no overlap and zero measured status-induced layout shifts. Renderer suite 130/130 independently rerun. Broader final app accessibility/performance remains partial. |

## Marker policy — critical data prerequisite

The earlier **9,046** readiness figure is not a verified comparable total. Historical September evidence uses 9,046 for the `artwork_not_ar` subset, not all eligible markers. Fresh read-only evidence finds 9,050 own-public active/unreviewed rows; 95 fail existing linked-artwork visibility, leaving **8,955** eligible markers. Do not describe this as 91 records removed. See the [marker decision and saved queries](RELEASE_0.8.5_MARKER_POLICY_DECISION.md).

The owner approved candidate implementation of bounded visibility for a captured **8,955-UUID cohort**, kept explicitly unreviewed. New/materially changed markers need approval; private/inactive/rejected/archived records and hidden linked owners remain denied. Public visibility is neither editorial verification nor SEO permission. The independent saved-capture check finds 8,955 unique IDs, no post-cutoff eligible records, and a manifest emitted from the same eligible CTE; no unintentional capture exclusion/admission was found at that capture. The fingerprint follow-up cleared independent review at 27b6c94; [saved review](evidence/marker-policy-20261023/marker-policy-cohort-crosscheck-ff30f0a.md) and [typed compatibility evidence](evidence/marker-policy-20261023/marker-cohort-typed-projection-compatibility.json) preserve the provenance. No production migration, bulk approval, hiding or deindexing occurred.

Preserve strict-gate WIP `495ebfa2d350176e30c88bd3b87e8c3a4fde8455` separately; it is not the selected policy. Current DNSLink and historical immutable CIDs are distinct: stale current publication is unresolved, and historical IPFS erasure is not promised. The app fallback guard blocks snapshot marker rows/embedded marker IDs locally; it does not itself repair the publisher or replace the current DNSLink pointer.

Focused read-only evidence at 2026-10-23 09:54 UTC confirms the current registry was generated on 2026-10-09. Four sanitized upload-error samples report a 5,000 ms timeout with pinning requested; the cluster-pin stage is the strong inferred failure point, not a proven cause for every earlier failure. See [DNSLink/publisher evidence](evidence/marker-policy-20261023/dnslink-publisher-readonly-2026-10-23.json). Owner-approved repair must diagnose the pin service before any timeout/configuration change, then qualify a successful publication from the reviewed, schema-ready policy producer and verify datasets, registry and current DNSLink. No repair, publication or DNS write was performed.

## SEO and performance boundaries

Historic near-10k indexed count, 875 impression-bearing URL export, capped 1,000-row export, and source-policy eligibility are different measurements. No current Google index coverage result was established and no mass canonical/noindex operation was performed.

Released-v0.8.4 equivalent-build performance comparison remains BLOCKED. Earlier candidate/Lighthouse probes are not release-baseline improvements. No field INP or final comparative CWV acceptance is claimed. Chrome DevTools MCP 1.12.0 was enabled in local Codex config with a backup; command startup verified, current-session trace integration was not completed.

## Native artifacts and signing

Android and unsigned iOS CI compiles passed at a1629792. The Android CI job also signed and uploaded a temporary device-test APK; this is not production release-signing or verified installed App Links evidence. No production-signed v0.8.5 APK/AAB or distributable IPA is qualified. Local Android release keystore/key.properties absent; protected environment signing must be checked through the existing release workflow. Repository-secret absence alone does not establish environment-secret absence. Existing signed v0.8.4 proves prior signer identity, not a signed v0.8.5 release artifact. Final release checksums/manifest remain pending; template values must stay null rather than fabricated.

## Release / rollback procedure and owner gates

Draft PR #359 contains proposed notes, preflight and pending artifact manifest. Refresh it against final heads before use. Gate sequence: reviewed candidate and exact-SHA acceptance → schema/config/backup/rollback preflight → owner-approved backend rollout → compatible admin → frontend web → native distribution separately. Stop on failed gates. No protected action is authorized by this report.

Before release: resolve current-snapshot freshness; finish app fallback review and integrate only cleared changes; run the full exact-head matrix, including the restored PostgreSQL fixtures; finish real-auth/physical-device/native qualification; qualify HA recovery and rollback; separately approve signed native artifact generation and then publication. Verify deployment/image SHA and schema parity immediately before any approved promotion.

Use existing protected workflows and guarded atomic web rollback. Backend baseline rollback anchor is current Oracle 46c9b84f, subject to image/schema verification. Admin production rollback artifact must be identified. Preserve backups and do not guess host paths. After an approved dev→master release, reconcile ancestry back into dev with a merge commit; require master-only cherry-pick-aware count zero.

## Preservation and shutdown

All implementation work remains isolated. Marker WIP is also saved as `marker-editorial-unreviewed.patch`. Task-owned Orbit Redis/Node/Kubo/PostgreSQL containers were stopped, not removed; data/evidence retained. ADB shows no attached devices and no emulator/QEMU process remains. Shared Docker resources and production were left untouched.

Final recommendation: **NO-GO**. This is an auditable incomplete release candidate, not a released or fully accepted v0.8.5.
Marker WIP exact pushed SHA: `495ebfa2d350176e30c88bd3b87e8c3a4fde8455`.
