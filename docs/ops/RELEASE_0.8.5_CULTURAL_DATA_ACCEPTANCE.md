# RELEASE 0.8.5 - Cultural data acceptance

~~Candidate heads (GH, read-only, 2026-10-24): app #358 d9405235 (full-tier GREEN run 40039543223; draft-tier 40037915357 timer flake, see FINAL_QA) | app #360 ad668604 | backend #131 6ecbfca (CI green run 40047787945; includes #139 4f21086 and #140 6ecbfca) | art.kubus.site #36 ac8237e | node.kubus.site #17 9c87fcc | kubus.site #20 c19a229 | admin #18 a2d78880 | app #361 2dc07c62 (draft)~~ [SUPERSEDED 2026-10-24 S2: heads moved in S2; see the S2 line below]

Candidate heads (S2, GH-verified 2026-10-24): app #358 8802e3ed (full-tier run 40119949889 success; final commit has no review file) | app #360 ad668604 (contained in #358) | app #361 2dc07c62 (contained in #358) | backend #131 86a73d5 (CI run 40115757445 success, self-hosted) | backend hotfix #142 merged as master 7d62d36, DEPLOYED 2026-10-24 10:39:11Z | art.kubus.site #36 ac8237e | node.kubus.site #17 7fd9abd (CI run 40083371476 success) | kubus.site #20 c19a229 | admin #18 046faba, #20 02d7473, #21 5789535, #22 7728455 (CI green, self-hosted) | readiness PR #359 (this commit).

Date: 2026-10-24
Single release ledger: RELEASE_0.8.5_READINESS.md (PR #359)

Legend: EV/ = [local path] SCR/ = [local path] MEM/ = [local path] GH = gh pr/run view, read-only, 2026-10-24. REVIEWED = independent agent review (Sonnet), not a GitHub approval. Status words used: NOT STARTED, IN PROGRESS, IMPLEMENTED, REVIEWED, TESTED, INTEGRATED, DEPLOYED, RELEASED, BLOCKED, DEFERRED. Nothing here is DEPLOYED or RELEASED; merges are owner actions. The CD rows come from SCR/W1-A2-report.md (dated 2026-10-23, older heads); they are carried as recorded.

## Status

| Item | Status | Evidence | Notes |
|---|---|---|---|
| CD-01 to CD-03: authored, documented, managed relationships | INTEGRATED | GH: backend #95 MERGED, mergeCommit c4115594 (gh pr view 95, 2026-10-24); SCR/W1-A2-report.md (matrix 2) | PG contract 14/14 per ledger. No E2E. |
| CD-04: profile authorship UI | INTEGRATED | GH: art.kubus #331 MERGED, mergeCommit 7d7586e1 (gh pr view 331, 2026-10-24) | "Public art added" naming still open. |
| CD-05: SEO authored count | INTEGRATED | GH: backend #96 MERGED, mergeCommit 8a4a085e (gh pr view 96, 2026-10-24) | PG 11/11 per SCR/W1-A2-report.md. |
| CD-06: contributions model | NOT STARTED | SCR/W1-A2-report.md (CD-06) | No PR. Proposed DEFERRED-0.9, owner to confirm. |
| CD-07: production read-only audit | BLOCKED | SCR/W1-A2-report.md (CD-07, production run note) | Tooling merged (#97). Production run not done. Needs owner authorisation. |
| CD-08: editorial review state | INTEGRATED | GH: backend #99 MERGED, mergeCommit fec505ce (gh pr view 99, 2026-10-24); SCR/W1-A2-report.md (20/20 synthetic transitions) | Real queue and staging journey owed. |
| CD-09: propagation audit | NOT STARTED | SCR/W1-A2-report.md (CD-09) | Proposed DEFERRED-0.9, owner to confirm. |
| CD-10: import evaluation, staged new imports | TESTED | EV/w7b-evidence/seed-apply-run1.log (created 13, updated 2, errors 0; staged is_public=false, needs_review) | Local rig. Staging E2E NOT STARTED. |
| Public-art, two-city scoped validate (Ljubljana, Maribor) | TESTED | EV/w7b-evidence/validate-2city-scoped.log (RESULT PASS; 20 records; image re-verify 20/20) | Scoped run only. |
| Public-art, full 10-per-city coverage | BLOCKED | EV/w7b-evidence/validate.log (RESULT FAIL; 376 city-minimum gaps, not source-exhausted) | 376 gaps listed by city. Not closed. |
| Institution discovery dry run, Ljubljana | TESTED | EV/w7a-evidence/ljubljana-dry-run.stdout.log; EV/w8b-evidence/ljubljana-dry-run.stdout.log | 115 raw, 35 accepted, 2 held, 71 skipped, 6 strong merges. Both runs have equal totals; per-kind counts differ by one (museum 6 vs 5, gallery 19 vs 20, arts_centre 9 vs 10, cultural_centre 1 vs 0). |
| Institution fetcher (OSM and Wikidata, backend #135) | REVIEWED | RELEASE_0.8.5_REVIEW_LEDGER.md (CHANGES-REQUIRED at b3b2de7, P1 DB guard bypass; APPROVE at d40a2d8); SCR/R-135-delta-review.md (55-case fuzz) | Bypass forms refused in the fuzz at d40a2d8. |
| Target-DB safety guard (scripts/lib/targetSafety.mjs) | REVIEWED | RELEASE_0.8.5_REVIEW_LEDGER.md (APPROVE with P2 fixes at a6c4b02; APPROVE at 129c73a); SCR/R-136-sonnet-review.md (no bypass found) | Residual: loopback allowed on the production host. Non-listed host passes with the human attestation flag. |
| Kind mapping, 10 kinds | IMPLEMENTED | SCR/W6-C-institution-mapping.md; SCR/R-135-sonnet-review.md item 1 (kindMapping.mjs read) | Working definitions in the W6-C research; migration 109 gives no per-kind text. |
| ~~Institution claims~~ | ~~IMPLEMENTED~~ | ~~SCR/W4-R-report.md section 2~~ | ~~Backend router in place. FEATURE_ENABLE_INSTITUTION_CLAIMS default false. Activation is an owner gate.~~ [SUPERSEDED 2026-10-24 S2: backend migration and admin queue status changed in S2] |
| Institution claims | IMPLEMENTED | HAIKU_U_CLAIMS_BACKEND.md; SONNET_131_FINAL_DELTA_REVIEW.md (#131 86a73d5); admin claims queue in #22 (7728455) | Backend router and migration 116 in #131 86a73d5 (S2). Admin claims queue in admin #22 (S2). FEATURE_ENABLE_INSTITUTION_CLAIMS default false. Activation is an owner gate. |
| Dispute approval semantics | BLOCKED | SCR/W4-R-report.md (decideClaim special-cases transfer only) | Owner decision 11 (RELEASE_0.8.5_REVIEW_LEDGER.md). |
| Legacy marker cohort (8,955 frozen IDs, migration 113) | IMPLEMENTED | SCR/W1-A-sonnet-review.md item 5; MEM/release-0-8-5-orchestration (owner decisions) | Bounded public as unverified. Owner classification recorded in scope; 9,046 figure retired. |
| Dry run of 13,029 records (EV/w7b-evidence/seed-dryrun-npm-literal.log) | NOT STARTED | not used | Provenance not established; excluded from acceptance. |
| Street-art live seeding (SEED_PUBLISH_IMPORTS removed) | NOT STARTED | SCR/R-136-sonnet-review.md (new rows only, staged) | Owner decision 14 (RELEASE_0.8.5_REVIEW_LEDGER.md). |
| ODbL share-alike position | NOT STARTED | MEM/release-0-8-5-orchestration (owner decisions list) | Owner decision 13 (RELEASE_0.8.5_REVIEW_LEDGER.md). |
| Wallet-derived institution identity | DEFERRED | MEM/release-0-8-5-orchestration (owner decisions list) | Owner decision 12: to v0.9 (RELEASE_0.8.5_REVIEW_LEDGER.md). |

## Open items / owner gates

- CD-07 read-only production audit (owner decision 2, with placeholder attribution and public Invader collection checks): owner authorises, then run with output outside the repo.
- Public-art coverage: close the 376 gaps or mark sources exhausted per city.
- ~~Institution claims activation and claims queue UI (flag stays false until owner approves).~~ [SUPERSEDED 2026-10-24 S2: claims queue UI exists in S2]
- Institution claims activation (flag stays false until owner approves). The claims queue UI exists in admin #22 (S2).
- Dispute approval semantics and ODbL share-alike position: owner decisions.
- R-134 P2 findings (migration 115 repair UPDATE, 23514): resolved per RELEASE_0.8.5_REVIEW_LEDGER.md (a696f47 APPROVE; P2s fixed, revoke, withdraw and reject never blocked). Opus-attested; no file read in this pass.
- CD-06 and CD-09: owner decision 3 (defer to DEFERRED-0.9).
- Staging E2E for imports and institutions: NOT STARTED.
