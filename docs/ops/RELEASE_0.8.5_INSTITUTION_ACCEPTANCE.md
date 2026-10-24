# RELEASE 0.8.5 - Institution acceptance

~~Candidate heads (GH, read-only, 2026-10-24): app #358 d9405235 (full-tier GREEN run 40039543223; draft-tier 40037915357 timer flake, see FINAL_QA) | app #360 ad668604 | backend #131 6ecbfca (CI green run 40047787945; includes #139 4f21086 and #140 6ecbfca) | art.kubus.site #36 ac8237e | node.kubus.site #17 9c87fcc | kubus.site #20 c19a229 | admin #18 a2d78880 | app #361 2dc07c62 (draft)~~ [SUPERSEDED 2026-10-24 S2: heads moved in S2; see the S2 line below]

Candidate heads (S2, GH-verified 2026-10-24): app #358 8802e3ed (full-tier run 40119949889 success; final commit has no review file) | app #360 ad668604 (contained in #358) | app #361 2dc07c62 (contained in #358) | backend #131 86a73d5 (CI run 40115757445 success, self-hosted) | backend hotfix #142 merged as master 7d62d36, DEPLOYED 2026-10-24 10:39:11Z | art.kubus.site #36 ac8237e | node.kubus.site #17 7fd9abd (CI run 40083371476 success) | kubus.site #20 c19a229 | admin #18 046faba, #20 02d7473, #21 5789535, #22 7728455 (CI green, self-hosted) | readiness PR #359 (this commit).

Date: 2026-10-24
Single release ledger: RELEASE_0.8.5_READINESS.md (PR #359)

Legend: EV/ = [local path] SCR/ = [local path] MEM/ = [local path] GH = gh pr/run view, read-only, 2026-10-24. REVIEWED = independent agent review (Sonnet), not a GitHub approval. Status words used: NOT STARTED, IN PROGRESS, IMPLEMENTED, REVIEWED, TESTED, INTEGRATED, DEPLOYED, RELEASED, BLOCKED, DEFERRED. Nothing here is DEPLOYED or RELEASED; merges are owner actions.

Institution claims stay disabled (backend FEATURE_ENABLE_INSTITUTION_CLAIMS=false) until reviewed E2E and an explicit activation approval. This is an owner gate.

## Status

| Item | Status | Evidence | Notes |
|---|---|---|---|
| Institution data model (migration 109, kind check) | INTEGRATED | GH: backend #101 MERGED, mergeCommit 2ec42109 (gh pr view 101, 2026-10-24); SCR/W1-A2-report.md (CD-12/13) | 10 allowed kinds. |
| ~~Institution browse for email-only accounts (app #360)~~ | ~~REVIEWED~~ | ~~RELEASE_0.8.5_REVIEW_LEDGER.md (APPROVE, P0 to P2 none, P3 2, at ad668604; Opus-attested); GH: head ad668604, draft-tier run 39973672520 success~~ | ~~Removes wallet onboarding from the browse path. SCR/R-360-sonnet-review.md is a skeleton; the verdict is Opus-attested.~~ [SUPERSEDED 2026-10-24 S2: Sonnet integration review recorded in S2] |
| Institution browse for email-only accounts (app #360) | REVIEWED | Sonnet APPROVE with notes, SONNET_APP_INTEGRATION_REVIEW.md section 3 (integration d59dd33f); head ad668604 is contained in #358 8802e3ed (S2). | Removes wallet onboarding from the browse path. |
| Institution search row in app | IMPLEMENTED | SCR/W1-A2-report.md (CD-12/13: FE269-1 PASS on dev); merge PR not identified | Browse only. enableInstitutions is browsing only; no claim UI in the app. |
| Imported institutions need approval (backend #134, migration 115) | REVIEWED | RELEASE_0.8.5_REVIEW_LEDGER.md (APPROVE subject to 2 P2 fixes at 0ef1553; a696f47 APPROVE, P2s fixed, Opus-attested); SCR/R-134-sonnet-review.md (PG probes on the two P2s) | Revoke, withdraw and reject are never blocked. |
| Institution fetcher and dry run (backend #135) | TESTED | RELEASE_0.8.5_REVIEW_LEDGER.md (CHANGES-REQUIRED at b3b2de7; APPROVE at d40a2d8); EV/w7a-evidence/ljubljana-dry-run.stdout.log | Dry run only: 35 accepted, 2 held, 71 skipped, 6 strong merges (Ljubljana). No staging write recorded. |
| Institution kind mapping | IMPLEMENTED | SCR/W6-C-institution-mapping.md; SCR/R-135-sonnet-review.md item 1 | Working definitions per kind. Art-only policy: museum requires museum=art. |
| ~~Institution claims (backend)~~ | ~~IMPLEMENTED~~ | ~~SCR/W4-R-report.md section 2~~ | ~~Routes, states, and transfer semantics recorded. Flag off.~~ [SUPERSEDED 2026-10-24 S2: migration 116 and review recorded in S2] |
| Institution claims (backend) | IMPLEMENTED | SCR/W4-R-report.md section 2; SONNET_131_FINAL_DELTA_REVIEW.md (#131 86a73d5) | Routes, states, transfer semantics recorded; migration 116 (institution_members) in #131 86a73d5 (S2). Flag off. |
| ~~Institution claims admin queue~~ | ~~NOT STARTED~~ | ~~SCR/W1-A2-report.md (CD-12/13: no claims UI in admin master)~~ | ~~Activation is an owner gate.~~ [SUPERSEDED 2026-10-24 S2: admin #22 built in S2] |
| Institution claims admin queue | IMPLEMENTED | admin #22 at 7728455: CI run 40113034452 success (self-hosted); Sonnet APPROVE at 4184fa4 (SONNET_ADMIN22_REVIEW.md); HAIKU_S_CLAIMS_UI.md | Draft. Commit 6dc2ea0e (review nits) has no review file on disk. Activation is an owner gate. |
| Institution claims E2E | NOT STARTED | SCR/RELEASE_0.8.5_MASTER_SCOPE.md (INST-CLAIMS row) | Required before activation. |
| Dispute approval semantics | BLOCKED | SCR/W4-R-report.md (decideClaim dispute approval grants membership) | Owner decision. |
| Wallet-derived institution identity | DEFERRED | MEM/release-0-8-5-orchestration (owner decisions list) | Proposed for v0.9. |
| ODbL share-alike (institution and public-art data) | NOT STARTED | MEM/release-0-8-5-orchestration (owner decisions list) | Owner decision. |

## Open items / owner gates

- Activate institution claims only after reviewed E2E and an explicit owner approval.
- Dispute approval semantics: owner decision 11 (SCR/W4-R-report.md).
- Imported institutions: P2 fixes recorded at a696f47 (RELEASE_0.8.5_REVIEW_LEDGER.md); confirm at the current backend head before promotion.
- ~~#360 verdict is Opus-attested; a verdict file is still missing (SCR/R-360-sonnet-review.md is a skeleton).~~ [SUPERSEDED 2026-10-24 S2: Sonnet verdict recorded in S2]
- #360 verdict: Sonnet APPROVE with notes in SONNET_APP_INTEGRATION_REVIEW.md section 3 (S2). R-360-sonnet-review.md remains a skeleton.
- Staging write for the institution dry run: owner approval.
- Wallet-derived institution identity (owner decision 12, proposed for v0.9) and ODbL share-alike (owner decision 13).
