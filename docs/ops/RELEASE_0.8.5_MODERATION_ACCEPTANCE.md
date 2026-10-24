# RELEASE 0.8.5 - Moderation acceptance

~~Candidate heads (GH, read-only, 2026-10-24): app #358 d9405235 (full-tier GREEN run 40039543223; draft-tier 40037915357 timer flake, see FINAL_QA) | app #360 ad668604 | backend #131 6ecbfca (CI green run 40047787945; includes #139 4f21086 and #140 6ecbfca) | art.kubus.site #36 ac8237e | node.kubus.site #17 9c87fcc | kubus.site #20 c19a229 | admin #18 a2d78880 | app #361 2dc07c62 (draft)~~ [SUPERSEDED 2026-10-24 S2: heads moved in S2; see the S2 line below]

Candidate heads (S2, GH-verified 2026-10-24): app #358 8802e3ed (full-tier run 40119949889 success; final commit has no review file) | app #360 ad668604 (contained in #358) | app #361 2dc07c62 (contained in #358) | backend #131 86a73d5 (CI run 40115757445 success, self-hosted) | backend hotfix #142 merged as master 7d62d36, DEPLOYED 2026-10-24 10:39:11Z | art.kubus.site #36 ac8237e | node.kubus.site #17 7fd9abd (CI run 40083371476 success) | kubus.site #20 c19a229 | admin #18 046faba, #20 02d7473, #21 5789535, #22 7728455 (CI green, self-hosted) | readiness PR #359 (this commit).

Date: 2026-10-24
Single release ledger: RELEASE_0.8.5_READINESS.md (PR #359)

Legend: EV/ = [local path] SCR/ = [local path] MEM/ = [local path] GH = gh pr/run view, read-only, 2026-10-24. REVIEWED = independent agent review (Sonnet), not a GitHub approval. Status words used: NOT STARTED, IN PROGRESS, IMPLEMENTED, REVIEWED, TESTED, INTEGRATED, DEPLOYED, RELEASED, BLOCKED, DEFERRED. Nothing here is DEPLOYED or RELEASED; merges are owner actions.

## Status

| Item | Status | Evidence | Notes |
|---|---|---|---|
| ~~Visual Review Deck, admin #18 at a2d78880~~ | ~~IMPLEMENTED~~ | ~~GH: head a2d78880, mergeable CLEAN, Admin CI run 39808186592 success (2026-10-22); SCR/W1-A2-report.md (Review Deck line)~~ | ~~Responsiveness, #17 findings, IPFS previews. Draft status not set; merge is an owner decision.~~ [SUPERSEDED 2026-10-24 S2: head moved to 046faba in S2] |
| Visual Review Deck, admin #18 at 046faba | IMPLEMENTED | GH: head 046faba, merge CLEAN; CI run 40112807227 success (self-hosted, S2); Sonnet APPROVE at 0d51981 (SONNET_ADMIN18_R2_REVIEW.md) | Responsiveness, #17 findings, IPFS previews. Draft status not set; merge is an owner decision. |
| ~~Review Deck exact-head browser gate~~ | ~~NOT STARTED~~ | ~~SCR/W1-A2-report.md (no browser proof on #18 head); SCR/RELEASE_0.8.5_MASTER_SCOPE.md (MOD-DECK)~~ | ~~Only role and session smoke found.~~ [SUPERSEDED 2026-10-24 S2: partial in S2] |
| Review Deck exact-head browser gate | IN PROGRESS | HAIKU_K_ADMIN18_QA.md (run 4 at a2d7888: 79 PASS, 7 FAIL); HAIKU_P_ADMIN18_FIX.md (fixes; targeted rerun 22 of 22 PASS at 0d51981) | Full 93-check run at 046faba is not on disk. |
| Review Deck #17 (earlier PR) | INTEGRATED | GH: admin.kubus #17 MERGED, mergeCommit 8a33b817 (gh pr view 17, 2026-10-24) | Merged. |
| Editorial review state (migration 108, CD-08) | INTEGRATED | GH: backend #99 MERGED, mergeCommit fec505ce (gh pr view 99, 2026-10-24); SCR/W1-A2-report.md (CD-08) | Synthetic 20/20 transitions, pre-merge admin head. |
| Marker moderation gate (backend #131) | REVIEWED | RELEASE_0.8.5_REVIEW_LEDGER.md (APPROVE-WITH-NITS at 88d792ff; #133 APPROVE-WITH-NITS at 5c8b2273, delta APPROVE at 4befea0; integration APPROVE at da299d3); SCR/R-131-sonnet-review.md (single predicate, trigger-based monotonic revocation) | Verdicts are for earlier heads; e79a87c is the fast-forward of #138 onto ad40b80. CI green at e79a87c (GH run 40030165802). |
| Revocation and re-grant guard (migration 113 and 114) | REVIEWED | SCR/R-133-sonnet-review.md item 1 (no un-revoke or re-grant path) | Trigger bypass of editorial state not in fingerprint: same as #131. |
| Map Audit: backend read APIs | IMPLEMENTED | SCR/W4-R-report.md section 1 (markers bbox, nearby, evidence, location corrections, revert) | Backend only. Cluster drill-down, paging and filters missing (same report). |
| ~~Map Audit: admin UI~~ | ~~NOT STARTED~~ | ~~SCR/W1-A2-report.md (Map Audit line); SCR/RELEASE_0.8.5_MASTER_SCOPE.md (MOD-MAP)~~ | ~~Blocked on owner decision 10 (admin repo "Haiku read-only" rule vs brief), per RELEASE_0.8.5_REVIEW_LEDGER.md.~~ [SUPERSEDED 2026-10-24 S2: built in admin #20 in S2] |
| Map Audit: admin UI | IMPLEMENTED | admin #20 at 02d7473: CI run 40112882719 success (self-hosted, S2); Sonnet APPROVE at 607d7d3 (SONNET_ADMIN_20_21_REVIEW.md) | Draft. Browser gate for Map Audit not on disk. |
| ~~Data Inspector~~ | ~~NOT STARTED~~ | ~~SCR/W1-A2-report.md (Data Inspector line)~~ | ~~No code found.~~ [SUPERSEDED 2026-10-24 S2: built in admin #21 in S2] |
| Data Inspector | IMPLEMENTED | admin #21 at 5789535: CI run 40112961483 success (self-hosted, S2); Sonnet APPROVE at 07fce87 (SONNET_ADMIN_21_FINAL_REVIEW.md) | Draft. Commit 15991748 (follow-ups F1 to F4) has no review file on disk. |
| ~~Claims queue admin UI~~ | ~~NOT STARTED~~ | ~~SCR/W1-A2-report.md (CD-12/13); SCR/W4-R-report.md section 2~~ | ~~Backend adminClaimsRouter mounted; no admin UI. Institution claims flag off.~~ [SUPERSEDED 2026-10-24 S2: built in admin #22 in S2] |
| Claims queue admin UI | IMPLEMENTED | admin #22 at 7728455 (see the Institution acceptance doc) | Draft. Institution claims flag off. |
| Moderation Studio S1 (location corrections, revert) | IMPLEMENTED | SCR/W1-A2-report.md (CD-11: migration 110 and route on master; PR #102 open draft) | Writes touch art_markers lat/lng only. |
| Public sync after admin writes | IN PROGRESS | SCR/W4-R-report.md section 1 (errors logged and swallowed; admin still gets 200 on stale public state) | Behaviour recorded by reviewer; no fix or test recorded. |
| ~~Orbit lifecycle (publish, revoke, revert, stale fallback)~~ | ~~IN PROGRESS~~ | ~~SCR/RELEASE_0.8.5_MASTER_SCOPE.md (ORBIT row, partial)~~ | ~~Isolated qualification not run.~~ [SUPERSEDED 2026-10-24 S2: isolated qualification recorded in S2] |
| Orbit lifecycle (publish, revoke, revert, stale fallback) | TESTED at 88d792ff | PR #359 readiness record (isolated stack, 20 of 20 checks, 2026-10-23) | Re-run at the current backend head (86a73d5) NOT DONE. close() risk classification still open. |
| ~~Admin repo policy vs brief~~ | ~~BLOCKED~~ | ~~MEM/release-0-8-5-orchestration (owner decisions: "Haiku read-only" rule)~~ | ~~Owner decision.~~ [SUPERSEDED 2026-10-24 S2: owner approval recorded in S2 (text not on disk)] |
| Admin repo policy vs brief | OWNER APPROVED per coordinator (decision 10; text not on disk) | Admin PRs #20 to #22 were built in S2 | The approval's scope is the S2 recommendation, which is not on disk. |

## Open items / owner gates

- ~~Exact-head browser acceptance of Review Deck on admin #18 at a2d78880 (NOT STARTED). Then the merge decision (owner).~~ [SUPERSEDED 2026-10-24 S2: targeted rerun passed in S2]
- Exact-head browser acceptance of Review Deck on admin #18 at 046faba: full 93-check run NOT DONE (targeted rerun at 0d51981 passed). Then the merge decision (owner).
- ~~Build Map Audit and Data Inspector admin UI on the existing backend reads. Blocked on owner decision 10.~~ [SUPERSEDED 2026-10-24 S2: built in S2]
- Map Audit, Data Inspector and claims queue UI are built in admin #20 to #22 (S2). Their browser gates are open.
- ~~Claims queue UI: depends on the activation decision (owner).~~ [SUPERSEDED 2026-10-24 S2: built in S2]
- Claims queue UI built in admin #22 (S2); activation remains an owner decision.
- ~~Orbit lifecycle qualification in isolation, and classification of close() risk.~~ [SUPERSEDED 2026-10-24 S2: isolated qualification passed at 88d792ff (readiness record)]
- Orbit lifecycle isolated qualification passed at 88d792ff (readiness record); re-run at the current head and close() risk classification remain open.
- Decide backend #105 (notifications) and #102 (Moderation Studio S1) scope: 0.8.5 or 0.9 (owner, from scope).
- Grants-table write privilege: owner decision 8 (RELEASE_0.8.5_REVIEW_LEDGER.md).
- ~~Backend #138 at e79a87c and #137: verdicts are Opus-attested in RELEASE_0.8.5_REVIEW_LEDGER.md; no file-level review for the e79a87c head.~~ [SUPERSEDED 2026-10-24 S2: file-level review recorded in S2]
- Backend #137 and #138 (e79a87c delta): file-level Sonnet APPROVE in SONNET_SECURITY_HOTFIX_REVIEW.md (S2).
- Physical-device and production moderation checks: owner gates.
