# RELEASE 0.8.5 - Performance acceptance

~~Candidate heads (GH, read-only, 2026-10-24): app #358 d9405235 (full-tier GREEN run 40039543223; draft-tier 40037915357 timer flake, see FINAL_QA) | app #360 ad668604 | backend #131 6ecbfca (CI green run 40047787945; includes #139 4f21086 and #140 6ecbfca) | art.kubus.site #36 ac8237e | node.kubus.site #17 9c87fcc | kubus.site #20 c19a229 | admin #18 a2d78880 | app #361 2dc07c62 (draft)~~ [SUPERSEDED 2026-10-24 S2: heads moved in S2; see the S2 line below]

Candidate heads (S2, GH-verified 2026-10-24): app #358 8802e3ed (full-tier run 40119949889 success; final commit has no review file) | app #360 ad668604 (contained in #358) | app #361 2dc07c62 (contained in #358) | backend #131 86a73d5 (CI run 40115757445 success, self-hosted) | backend hotfix #142 merged as master 7d62d36, DEPLOYED 2026-10-24 10:39:11Z | art.kubus.site #36 ac8237e | node.kubus.site #17 7fd9abd (CI run 40083371476 success) | kubus.site #20 c19a229 | admin #18 046faba, #20 02d7473, #21 5789535, #22 7728455 (CI green, self-hosted) | readiness PR #359 (this commit).

Date: 2026-10-24
Single release ledger: RELEASE_0.8.5_READINESS.md (PR #359)

Legend: EV/ = [local path] SCR/ = [local path] MEM/ = [local path] GH = gh pr/run view, read-only, 2026-10-24. REVIEWED = independent agent review (Sonnet), not a GitHub approval. Status words used: NOT STARTED, IN PROGRESS, IMPLEMENTED, REVIEWED, TESTED, INTEGRATED, DEPLOYED, RELEASED, BLOCKED, DEFERRED. Nothing here is DEPLOYED or RELEASED; merges are owner actions.

Web startup was measured at app head 1d68dfa3, not at the current #358 head d9405235. Marker bench numbers are synthetic.

## Status

| Item | Status | Evidence | Notes |
|---|---|---|---|
| Web startup, guest, cold and warm, 1440 and 390 (v0.8.4 vs 1d68dfa3) | TESTED | EV/w11b-perf/PERF-REPORT.md (results table, 7 runs per cell) | NO CHANGE in all 4 guest cells (7 of 8 cells overall). Replay fixtures, not live API. Map-ready measured with no marker data in both builds. |
| Web startup, returning wallet, 1440 (cold and warm) | TESTED | EV/w11b-perf/PERF-REPORT.md | NO CHANGE in both 1440 cells (cold -3.5%, warm +3.7%). |
| Returning wallet, warm 390x844 | NOT STARTED | EV/w11b-perf/PERF-REPORT.md (verdict summary) | REGRESSED +8.8% (+99 ms), ranges do not overlap. One cell to re-measure. Re-measure not run. |
| Guest Solana RPC count | TESTED | EV/w11b-perf/PERF-REPORT.md ("Solana RPC: 0 in every run of both builds") | Solana and IPFS hosts aborted locally; counts are attempts, timings exclude RPC latency. |
| Cold-start 30% target vs v0.8.3 | BLOCKED | EV/w11b-perf/PERF-REPORT.md (NOT COMPARABLE) | No v0.8.3 build in this rig. v0.8.3 baseline used live API, 5 runs, different matrix. |
| Marker predicate, PR #131 design at 88d792ff | TESTED | EV/w2c-bench-out/BENCH-131.md (verdict OPTIMIZE BEFORE PROMOTION) | Overview tiles and cache revalidation 9 to 14 times slower. Reviewer reorder (V1) did not help. 20,000 synthetic markers. |
| Marker predicate, grant-based design (bench variant "fix") | TESTED | EV/w3a-evidence/bench/run3.log; EV/w3a-evidence/bench/bench3.js; commit 4befea06 is an ancestor of e79a87c (git) | Same 15,000-row set as #131 (hash ed7ef53b). Fingerprint calls 0 vs 9,000. Q5 JIT-on, first and second values (inferred as p50, p95 per BENCH-131 method): fix 57.5 / 62.3 ms; #131 575.5 / 595.5 ms; master-equivalent 47.2 / 49.8 ms. Q6: fix 61.7 / 68.1; #131 682.3 / 715.6. Synthetic data. |
| ~~Marker predicate, grant design re-run at e79a87c~~ | ~~NOT STARTED~~ | ~~none~~ | ~~Bench run at the current backend head not done.~~ [SUPERSEDED 2026-10-24 S2: backend head moved in S2] |
| Marker predicate, grant design re-run at 86a73d5 (current backend #131 head) | NOT STARTED | none | Bench run at the current backend head not done (S2: head moved from e79a87c). |
| ~~Web startup at d9405235 (current #358 head)~~ | ~~NOT STARTED~~ | ~~none~~ | ~~No measurement at this head.~~ [SUPERSEDED 2026-10-24 S2: head moved in S2] |
| Web startup at 8802e3ed (current #358 head) | NOT STARTED | none | No measurement at this head (S2: head moved from d9405235). |
| Device startup, iOS image loading, glass | NOT STARTED | EV/w11b-perf/PERF-REPORT.md (Chromium only, no device) | Physical device owner gate (see FINAL_QA). |

Reading note: verdict chain for the #131 design is in RELEASE_0.8.5_REVIEW_LEDGER.md. The 88d792ff bench verdict applies to the earlier fingerprint design. The later design is the one measured in bench variant "fix". Owner or Opus must confirm which design #131 e79a87c carries before any promotion.

## Open items / owner gates

- Re-measure returning-wallet warm 390x844 at the candidate head (one cell, +8.8%).
- Re-run the marker bench at e79a87c on a fresh database, and check the design matches bench variant "fix".
- A v0.8.3 build in the same rig is needed before the 30% target can be evaluated. Until then it stays BLOCKED.
- Physical device measurements (Android, iOS): owner gate.
- Backend promotion of #131 waits for the performance decision and the owner's HA reseed decision (see FINAL_QA).
