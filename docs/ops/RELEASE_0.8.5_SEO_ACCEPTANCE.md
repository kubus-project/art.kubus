# RELEASE 0.8.5 - SEO acceptance

~~Candidate heads (GH, read-only, 2026-10-24): app #358 d9405235 (full-tier GREEN run 40039543223; draft-tier 40037915357 timer flake, see FINAL_QA) | app #360 ad668604 | backend #131 6ecbfca (CI green run 40047787945; includes #139 4f21086 and #140 6ecbfca) | art.kubus.site #36 ac8237e | node.kubus.site #17 9c87fcc | kubus.site #20 c19a229 | admin #18 a2d78880 | app #361 2dc07c62 (draft)~~ [SUPERSEDED 2026-10-24 S2: heads moved in S2; see the S2 line below]

Candidate heads (S2, GH-verified 2026-10-24): app #358 8802e3ed (full-tier run 40119949889 success; final commit has no review file) | app #360 ad668604 (contained in #358) | app #361 2dc07c62 (contained in #358) | backend #131 86a73d5 (CI run 40115757445 success, self-hosted) | backend hotfix #142 merged as master 7d62d36, DEPLOYED 2026-10-24 10:39:11Z | art.kubus.site #36 ac8237e | node.kubus.site #17 7fd9abd (CI run 40083371476 success) | kubus.site #20 c19a229 | admin #18 046faba, #20 02d7473, #21 5789535, #22 7728455 (CI green, self-hosted) | readiness PR #359 (this commit).

Date: 2026-10-24
Single release ledger: RELEASE_0.8.5_READINESS.md (PR #359)

Legend: EV/ = [local path] SCR/ = [local path] MEM/ = [local path] GH = gh pr/run view, read-only, 2026-10-24. REVIEWED = independent agent review (Sonnet), not a GitHub approval. Status words used: NOT STARTED, IN PROGRESS, IMPLEMENTED, REVIEWED, TESTED, INTEGRATED, DEPLOYED, RELEASED, BLOCKED, DEFERRED. Nothing here is DEPLOYED or RELEASED; merges are owner actions.

No SEO item is claimed to produce indexing. Indexing is decided by search engines and is not promised.

## Status

| Item | Status | Evidence | Notes |
|---|---|---|---|
| art.kubus.site #36: English root, one-hop 301s | TESTED | EV/w2b-evidence/e2e-final2.txt (/en, /en/, /en/map/ each one 301 to the target); REVIEWED: RELEASE_0.8.5_REVIEW_LEDGER.md (APPROVE-WITH-NITS at 3f18a5d; APPROVE at ac8237e); SCR/R-delta-36-20.md; SCR/R-art36-sonnet-review.md | GH: site lint, tests and SEO build green (run 39968698752). Draft, not merged. Nits: /en/nope gives two hops; /en/index.html duplicates /. |
| kubus.site #20: /en and /en/ to root in one 301 | TESTED | RELEASE_0.8.5_REVIEW_LEDGER.md (APPROVE-WITH-NITS at c47fce5; APPROVE at c19a229); SCR/R-delta-36-20.md (8/8 tests); SCR/R-node17-kubus20-review.md (earlier 2-hop finding, http to /en/) | GH: run 39969235659 green. GH head is c19a229. Draft, not merged. |
| ~~node.kubus.site #17: descriptions, 404 label, favicon set~~ | ~~REVIEWED~~ | ~~RELEASE_0.8.5_REVIEW_LEDGER.md (APPROVE-WITH-NITS at 9c87fcc); GH: head 9c87fcc, Validate website run 39967858461 success; SCR/R-node17-kubus20-review.md (18 EN/SL and 404 descriptions grounded in copy; PNG 48/96/192/512/180 plus ICO)~~ | ~~Draft.~~ [SUPERSEDED 2026-10-24 S2: head moved to 7fd9abd in S2] |
| node.kubus.site #17: descriptions, 404 label, favicon set | REVIEWED | Sonnet APPROVE at b215be4 (SONNET_NODE_SITE_17_REVIEW.md); head 7fd9abd; Validate website run 40083371476 success (S2). | Two commits after b215be4 (cc3bb87, 7fd9abd) have no review file on disk. Draft. |
| node.kubus.site: http to https redirect | TESTED | EV/w3b-evidence/w3b-e2e-raw.txt (local rig: http / and sub-paths 301 to https; https 200 with XFP); SCR/W1-B2-report.md section 3 (defect at base) | Local rig result, not a live probe. Live probe after deploy remains an owner step. |
| node.kubus.site: technical indexing blocker | TESTED | SCR/W1-B2-report.md section 1 (10 sitemap URLs 200, index,follow, canonical matches); SCR/W1-B-sonnet-review.md item 2 | No technical blocker found. Quality items only. Read-only, pre-#17 state (2026-10-23). |
| node.kubus.site: Search Console steps | NOT STARTED | SCR/W1-B-report.md "OWNER-ONLY CHECKS" | Owner-only. |
| node.kubus.site: inbound links | NOT STARTED | SCR/W1-B2-report.md section 1 (4 links from kubus.site; 0 from art.kubus.site) | art.kubus.site has no node links. |
| app.kubus.site: SL artwork 404 vs documented SL to EN canonical | IN PROGRESS | SCR/W1-B2-report.md section 4; SCR/W1-B-sonnet-review.md item 5 | Policy and behaviour mismatch recorded by reviewer. Not resolved. |
| Favicon set, four sites | IN PROGRESS | SCR/W1-B-sonnet-review.md item 6 (PNG 501x501, not a multiple of 48); EV/w3b-evidence/favicon-sha-run1.txt | Node set is in #17. Art, kubus and app sets not yet replaced. |
| Content quality experiment (14/28 days) | NOT STARTED | SCR/RELEASE_0.8.5_MASTER_SCOPE.md (SEO-CONTENT row) | Baseline only. No mass deindex. |
| Legacy /en/ chain on kubus.site (before #20) | TESTED | SCR/W1-B2-report.md section 2 (/en/ to 301 to /en to 404) | Base-state result; #20 changes it to one 301 (see row above). |

## Open items / owner gates

- Merge #36, #20 and #17 (owner action). Deployment follows the owner's go.
- Search Console submission and monitoring for node.kubus.site (owner-only).
- Decide policy for SL artwork 404 vs SL to EN canonical (app.kubus.site).
- Replace art, kubus and app favicons with a 48-multiple PNG and ICO set from approved logos.
- Confirm the node http to https redirect with a live probe after deploy (local rig result only so far).
- Close stacked or stale site PRs (art #8/#9/#16/#30, kubus #2) only after owner OK (SCR/RELEASE_0.8.5_MASTER_SCOPE.md STACKED row).
- Indexing outcome is not a release criterion. Do not promise it in copy or in the release notes.
