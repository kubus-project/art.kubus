# RELEASE 0.8.5 - SSR and UX acceptance

~~Candidate heads (GH, read-only, 2026-10-24): app #358 d9405235 (full-tier GREEN run 40039543223; draft-tier 40037915357 timer flake, see FINAL_QA) | app #360 ad668604 | backend #131 6ecbfca (CI green run 40047787945; includes #139 4f21086 and #140 6ecbfca) | art.kubus.site #36 ac8237e | node.kubus.site #17 9c87fcc | kubus.site #20 c19a229 | admin #18 a2d78880 | app #361 2dc07c62 (draft)~~ [SUPERSEDED 2026-10-24 S2: heads moved in S2; see the S2 line below]

Candidate heads (S2, GH-verified 2026-10-24): app #358 8802e3ed (full-tier run 40119949889 success; final commit has no review file) | app #360 ad668604 (contained in #358) | app #361 2dc07c62 (contained in #358) | backend #131 86a73d5 (CI run 40115757445 success, self-hosted) | backend hotfix #142 merged as master 7d62d36, DEPLOYED 2026-10-24 10:39:11Z | art.kubus.site #36 ac8237e | node.kubus.site #17 7fd9abd (CI run 40083371476 success) | kubus.site #20 c19a229 | admin #18 046faba, #20 02d7473, #21 5789535, #22 7728455 (CI green, self-hosted) | readiness PR #359 (this commit).

Date: 2026-10-24
Single release ledger: RELEASE_0.8.5_READINESS.md (PR #359)

Legend: EV/ = [local path] SCR/ = [local path] MEM/ = [local path] GH = gh pr/run view, read-only, 2026-10-24. REVIEWED = independent agent review (Sonnet), not a GitHub approval. Status words used: NOT STARTED, IN PROGRESS, IMPLEMENTED, REVIEWED, TESTED, INTEGRATED, DEPLOYED, RELEASED, BLOCKED, DEFERRED; N/A marks a row with no arrival route. Nothing here is DEPLOYED or RELEASED; merges are owner actions.

## Status

| Item | Status | Evidence | Notes |
|---|---|---|---|
| No-JS SSR, 8 families EN/SL, 4 engine/viewport runs | TESTED | EV/w12a-evidence/results/ssr-*.summary.json; RELEASE_0.8.5_REVIEW_LEDGER.md (SSR split) | 64/64 acceptable: 60 of 64 entity cell-runs PASS plus 4 SL thin posts self-canonical with noindex (correct by policy); 4/4 unknown-id 404 controls PASS. Run at app 1d68dfa3 / backend da299d3, before #137 and #138 (SSR rendering unchanged by them, Opus). |
| SL thin post self-canonical (4 rows, one per run) | TESTED | EV/w12a-evidence/DIAGNOSES-W12A.md (c); INDEX_OWNERSHIP_CANONICAL_POLICY_V1.md:39 and ~92; publicSearchPolicy.js ~309 | Correct by policy: noindex and self-canonical (THIN_SOCIAL_POST). Harness expectation was corrected after diagnosis; rerun under the final harness NOT STARTED. |
| Takeover JS matrix, 264 cells | TESTED | EV/w17-evidence/RESULTS.md section B; EV/w17-app HEAD d91d23d4 | Chromium desktop 84, Firefox desktop 84, Chromium mobile 48, Firefox mobile 48. All PASS. |
| Firefox forced bootstrap abort reaches failed | TESTED | EV/w13a-evidence/probe-summary.json; commit 96e86c59 is an ancestor of d9405235 (git) | failed state reached in all 6 probe runs (3 Chromium, 3 Firefox). Before the fix Firefox stayed pending for 30 s (DIAGNOSES-W12A (a)). |
| Transient entity errors 429/503/404, EN+SL, both engines | TESTED | EV/w19a-evidence/results/c-w19a-transient-chromium-desktop.summary.json; ...-firefox-desktop.summary.json | 23 of 24 pass in the W19-A worktree (HEAD d9405235 at check time; run head not recorded; runs 00:57 to 01:02). 503 marker cells, which failed 4 of 4 in W17 section C, now pass. |
| Transient cell: Chromium desktop 503 profile EN | TESTED | EV/w25-evidence/results/D503-transient-chromium-desktop.jsonl | W19-A recorded 2813 ms at an earlier head. Final heads (W25-D): 503 cells pass, Chromium 2 of 2. |
| Profile stall (backend 429 shown as not-found) | IMPLEMENTED | EV/w14a-evidence/W14A-DIAGNOSIS.md; d9405235 contains 2dc9685c, 96c05f7e, 54589ca4 (git) | Fix is on #358. REVIEWED: SCR/R-app-d9405235-review.md (APPROVE, P3 notes). |
| Marker cold-link takeover (outage read as missing marker) | IMPLEMENTED | EV/w14a-evidence/W14A-DIAGNOSIS.md; d9405235 contains 08489f89 (git) | Fix is on #358. Full-tier GREEN at d9405235 (run 40039543223). |
| ~~Backend public-read rate-limit exemption (#137)~~ | ~~REVIEWED~~ | ~~RELEASE_0.8.5_REVIEW_LEDGER.md (172b0c4d APPROVE, Opus-attested; ad40b80 delta APPROVE); EV/w17-evidence/RESULTS.md section A (exemption PASS)~~ | ~~Anonymous-only skip matching the full path.~~ [SUPERSEDED 2026-10-24 S2: deployed in hotfix #142 (S2)] |
| Backend public-read rate-limit exemption (#137) | DEPLOYED | Covered by hotfix #142 (PR title: public-read and SEO rate limits), merged 7d62d36 and deployed 2026-10-24 10:39:11Z; HAIKU_O_HOTFIX_DEPLOY.md | Anonymous-only skip matching the full path. |
| ~~Backend SEO limiter per route and encoded-alias evasion (#138)~~ | ~~REVIEWED~~ | ~~RELEASE_0.8.5_REVIEW_LEDGER.md (CHANGES-REQUIRED at 1905bfb; e79a87c APPROVE, Opus-attested); SCR/R-138-review.md; SCR/R-138-delta.md~~ | ~~e79a87c contains d1d353e and ad40b80 (git). No file-level review at e79a87c.~~ [SUPERSEDED 2026-10-24 S2: deployed in hotfix #142 (S2)] |
| Backend SEO limiter per route and encoded-alias evasion (#138) | DEPLOYED | Covered by hotfix #142 (deployed as above). File-level Sonnet APPROVE on the e79a87c-specific delta: SONNET_SECURITY_HOTFIX_REVIEW.md | Mixed-case locale 301 is a behaviour change to call out in release notes. |
| Rate-limit literal acceptance (350 GETs, no 429), default limits | TESTED | EV/w25-evidence/results/A-default-limits.jsonl | Profile and marker 350 of 350 at 200, no 429. Control: artworks 429 from request 301. Budget review is owner decision 18. Earlier W17 run (51 x 429) was before the final heads. |
| History H1-H3 (back/forward, refresh, second entity), Chromium desktop | TESTED | EV/w19b-evidence/results/history-chromium-desktop.jsonl | 24 of 24 PASS. |
| History H4 query and auth params on entity URLs | TESTED | EV/w19b-evidence/results/history-chromium-desktop.jsonl; history-firefox-desktop.jsonl | Reclassified PASS: params on entity URLs are ordinary navigation. Earlier "not stripped" reading withdrawn. |
| History H2 refresh, Firefox desktop | IN PROGRESS | EV/w19b-evidence/results/history-firefox-desktop.jsonl; h2-retry-firefox-desktop.jsonl | Original artwork EN reload timed out (30 s); H2 retry 2 of 2 PASS. Cause not explained. |
| H5 verify-email and reset-password strip tokens | TESTED | EV/w19b-evidence/results/h5-chromium-desktop.jsonl; h5-firefox-desktop.jsonl | PASS in both engines. |
| H5 sign-in callback params | N/A | EV/w19b-evidence/results/h5-*-desktop.jsonl (pass:false) | /sign-in is not an arrival route for these params, so the row does not apply. Sign-in fields are exposed as named native inputs (EV/w22b-evidence/results/probe-dom-base.json). |
| R18 Chromium desktop (walletless and wallet sheet) | TESTED | EV/w19b-evidence/results/r18-chromium-desktop.jsonl | 7 of 7 after driver race fix (was 5 of 7). |
| R18 Firefox desktop | TESTED | EV/w19b-evidence/results/r18-firefox-desktop.jsonl | 7 of 7, provisional. |
| ~~R18 account switch~~ | ~~NOT STARTED~~ | ~~none~~ | ~~UNVERIFIED.~~ [SUPERSEDED 2026-10-24 S2: defect found and fixed in S2] |
| R18 account switch (same document) | IMPLEMENTED; Firefox S5 INCONCLUSIVE | HAIKU_F_R18_SWITCH.md (defect); fix 9e014fa2 to c65c98b4 in #358; SONNET_ACCOUNT_SWITCH_REVIEW.md (APPROVE) | Defect fixed. Clean Firefox S5 rerun and post-fix same-document browser run NOT DONE. |
| Accessibility: failed-state contrast and reduced motion | TESTED | EV/w19b-evidence/results/a11y-*.jsonl | Failed-state contrast 5.05:1; reduced motion PASS. |
| Accessibility: slow-state copy contrast | TESTED | EV/w25-evidence/results/E-slow-contrast-artwork.json; backend #139 4f21086 (Sonnet APPROVE) | Fixed: light 2.93 to 5.05:1 (W25-E PASS); dark 5.08 to 8.67:1 (per Opus). Cause was static opacity .72 on #flutter-takeover-status[data-state=slow] (seoPublicPagesService.js:1313). |
| ~~Firefox reload stall~~ | ~~IN PROGRESS~~ | ~~EV/w22a-evidence/w22a-status.txt~~ | ~~UNVERIFIED in real browser; harness artefact likely. Doc 200 in about 110 ms; not server or app (Opus). Owner spot-check, decision 17.~~ [SUPERSEDED 2026-10-24 S2: verified in stock Firefox 158 in S2] |
| Firefox reload stall | TESTED | HAIKU_F_FIREFOX_RELOAD.md (stock Firefox 158.0) | VERIFIED: no stall in stock Firefox 158.0 (W22-A 20 of 20; families 24 of 24; reload timing 6 of 6 and 6 of 6; forced failure 5 of 5). The stall reproduced only in Playwright's bundled Firefox 146 (harness artefact). Decision 17. |
| Firefox failed-state focus repetition | TESTED | EV/w24b-evidence/W24B-DIAGNOSIS.md | Headless end-of-document behaviour, not an app focus trap. Host inert honoured; all links and Refresh reachable. Resolved. |
| Final-heads acceptance, W25-B (backend 4f21086 with app d9405235, default limits) | TESTED | EV/w25-evidence/results/ (A-default-limits.jsonl, B-ssr-*.summary.json, C-*-takeover-*.jsonl, D503/D404-transient-*.jsonl, E-slow-contrast-*.json) | A: limits pass. B: SSR no-JS 68/68. C: takeover 16/16 ready, slow and failed 4/4. D: forced 503/404 6/6. E: slow contrast 5.05:1. #140 is dependency patching only, not in this run. |
| ~~App #361 password-toggle accessible names~~ | ~~REVIEWED~~ | ~~GH: PR #361 head 2dc07c62, OPEN draft; SCR/R-signin-a11y-review.md (stub, no verdict word)~~ | ~~Verdict REVIEWED per Opus (attested). Draft-tier CI running.~~ [SUPERSEDED 2026-10-24 S2: Sonnet verdict and CI recorded in S2] |
| App #361 password-toggle accessible names | REVIEWED | Sonnet APPROVE, SONNET_APP_INTEGRATION_REVIEW.md section 2 (integration d59dd33f); draft-tier run 40042467088 success (S2). | Head 2dc07c62 (draft). |

Pre-fix W12-A takeover summaries (Firefox desktop 3 of 6, Chromium mobile 41 of 48) are superseded by the 264-cell run above.

## Open items / owner gates

- ~~Owner decision 17: real-Firefox reload spot-check (Firefox reload row UNVERIFIED).~~ [SUPERSEDED 2026-10-24 S2: verified in S2]
- Owner decision 17: VERIFIED in stock Firefox 158 (S2).
- Owner decision 18: anonymous rate-limit budget review. The 300 per 15 min anonymous budget is exhausted by about 14 cold public page loads through non-exempt reads (artwork lists, home rails, stats). Still strictly better than production, where no public read is exempt.
- ~~R18 account switch NOT STARTED (UNVERIFIED).~~ [SUPERSEDED 2026-10-24 S2: defect fixed in S2]
- R18 account switch: defect fixed in #358 (S2); clean Firefox S5 rerun NOT DONE.
- Unpinned W12-A build sent read-only GETs to api.kubus.site and bapi.kubus.site from local sessions (DIAGNOSES-W12A (b)). Report to owner.
- ~~Merges of #358, #361 and backend #131 are owner actions. No row here is DEPLOYED or RELEASED.~~ [SUPERSEDED 2026-10-24 S2: heads moved and hotfix deployed in S2]
- Merges of #358 (8802e3ed) and backend #131 (86a73d5) are owner actions. Backend hotfix #142 is DEPLOYED 2026-10-24 and covers the rate-limit rows above. No other row here is DEPLOYED or RELEASED.
