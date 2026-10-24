# RELEASE 0.8.5 - Final QA (skeleton)

~~Candidate heads (GH, read-only, 2026-10-24): app #358 d9405235 (full-tier GREEN run 40039543223; draft-tier 40037915357 timer flake, see FINAL_QA) | app #360 ad668604 | backend #131 6ecbfca (CI green run 40047787945; includes #139 4f21086 and #140 6ecbfca) | art.kubus.site #36 ac8237e | node.kubus.site #17 9c87fcc | kubus.site #20 c19a229 | admin #18 a2d78880 | app #361 2dc07c62 (draft)~~ [SUPERSEDED 2026-10-24 S2: heads moved in S2; see the S2 line below]

Candidate heads (S2, GH-verified 2026-10-24): app #358 8802e3ed (full-tier run 40119949889 success; final commit has no review file) | app #360 ad668604 (contained in #358) | app #361 2dc07c62 (contained in #358) | backend #131 86a73d5 (CI run 40115757445 success, self-hosted) | backend hotfix #142 merged as master 7d62d36, DEPLOYED 2026-10-24 10:39:11Z | art.kubus.site #36 ac8237e | node.kubus.site #17 7fd9abd (CI run 40083371476 success) | kubus.site #20 c19a229 | admin #18 046faba, #20 02d7473, #21 5789535, #22 7728455 (CI green, self-hosted) | readiness PR #359 (this commit).

Date: 2026-10-24
Single release ledger: RELEASE_0.8.5_READINESS.md (PR #359)

Legend: EV/ = [local path] SCR/ = [local path] MEM/ = [local path] GH = gh pr/run view and gh run view, read-only, 2026-10-24. REVIEWED = independent agent review (Sonnet), not a GitHub approval. Status words used: NOT STARTED, IN PROGRESS, IMPLEMENTED, REVIEWED, TESTED, INTEGRATED, DEPLOYED, RELEASED, BLOCKED, DEFERRED. Nothing here is DEPLOYED or RELEASED; merges are owner actions.

Release status: v0.8.5 is NOT STARTED as a tag (MEM/release-0-8-5-orchestration: "NOT released"). No merge, tag, deploy or native build has been done in this pass. Merges, deploys and production data operations are owner actions.

## CI at candidate heads

| Repo and PR | Head | Status | Evidence | Notes |
|---|---|---|---|---|
| ~~app #358~~ | ~~d9405235~~ | ~~TESTED~~ | ~~GH run 40039543223 (full tier, success, all 12 jobs; Flutter 5871 passed / 28 skipped). Draft-tier run 40037915357 failed on a timer flake in feed_like_settlement_test (socket_io WebSocketTransport, 5 s; EV/w20a-evidence/draft-fail.txt)~~ | ~~Verdict APPROVE: RELEASE_0.8.5_REVIEW_LEDGER.md (SCR/R-app-d9405235-review.md).~~ [SUPERSEDED 2026-10-24 S2: head moved to 8802e3ed in S2] |
| app #358 | 8802e3ed | TESTED | GH run 40119949889 (full tier, success, 2026-10-24). Reviewed chain and gaps: RELEASE_0.8.5_REVIEW_LEDGER.md Session 2 final state, S2-1 and S2-2. | Draft, merge BLOCKED while draft. Final commit 8802e3ed has no review file on disk. |
| ~~app #361~~ | ~~2dc07c62~~ | ~~REVIEWED~~ | ~~GH: PR #361 OPEN draft; draft-tier CI running~~ | ~~APPROVE (sign-in password-toggle accessible names), Opus-attested; SCR/R-signin-a11y-review.md is a stub.~~ [SUPERSEDED 2026-10-24 S2: verdict and CI recorded in S2] |
| app #361 | 2dc07c62 | REVIEWED | Draft-tier run 40042467088 success (S2). | Sonnet APPROVE in SONNET_APP_INTEGRATION_REVIEW.md section 2 (integration d59dd33f). Contained in #358. |
| app #358 | d91d23d4 | TESTED | GH run 40027457947 (full tier, success); run 40025281481 (draft tier, success) | Superseded by d9405235. |
| ~~app #360~~ | ~~ad668604~~ | ~~TESTED~~ | ~~GH run 39973672520 (draft tier, success)~~ | ~~Draft. Review verdict not recorded (skeleton).~~ [SUPERSEDED 2026-10-24 S2: Sonnet verdict recorded in S2] |
| app #360 | ad668604 | REVIEWED | Draft-tier run 39973672520 success. | Sonnet APPROVE with notes in SONNET_APP_INTEGRATION_REVIEW.md section 3 (S2). Contained in #358. |
| ~~backend #131~~ | ~~6ecbfca~~ | ~~TESTED~~ | ~~GH run 40047787945 (Backend CI, green). Includes #139 4f21086 and #140 6ecbfca, both merged into branch codex/085-backend-integration-20261023 (gh pr view). Earlier head e79a87c run 40030165802~~ | ~~Draft. Verdicts APPROVE for #139 and #140 (Sonnet; RELEASE_0.8.5_REVIEW_LEDGER.md). #140 is patching only: body-parser, multer, nodemailer advisories.~~ [SUPERSEDED 2026-10-24 S2: head moved to 86a73d5 in S2] |
| backend #131 | 86a73d5 | TESTED | CI run 40115757445 success (self-hosted runner, S2). | Draft, merge CLEAN. Sonnet APPROVE on 4cdf098..86a73d5 (SONNET_131_FINAL_DELTA_REVIEW.md). Not deployed. Migrations 113 to 116. |
| backend hotfix #142 | 24d8b0c0 (merged as master 7d62d36) | DEPLOYED | CI run 40083797542 success. Deploy and edge checks: HAIKU_O_HOTFIX_DEPLOY.md. | Merged 2026-10-24T10:33:38Z; deployed 10:39:11Z; rollback tag rollback-pre-7d62d36. Open: a media-proxy 200 fetch was not achieved. |
| art.kubus.site #36 | ac8237e | TESTED | GH run 39968698752 (site lint, tests, SEO build success); deploy skipped | Draft. |
| ~~node.kubus.site #17~~ | ~~9c87fcc~~ | ~~TESTED~~ | ~~GH run 39967858461 (Validate website: production success); deploy skipped~~ | ~~Draft.~~ [SUPERSEDED 2026-10-24 S2: head moved to 7fd9abd in S2] |
| node.kubus.site #17 | 7fd9abd | TESTED | Validate website run 40083371476 success (S2). | Draft (private repository). Sonnet APPROVE at b215be4; cc3bb87 and 7fd9abd have no review file on disk. |
| kubus.site #20 | c19a229 | TESTED | GH run 39969235659 (build and verify routing success); deploy skipped | Draft, CLEAN. |
| ~~admin #18~~ | ~~a2d78880~~ | ~~TESTED~~ | ~~GH run 39808186592 (Admin CI success, 2026-10-22)~~ | ~~Not draft. Browser gate open.~~ [SUPERSEDED 2026-10-24 S2: heads moved in S2] |
| admin #18 | 046faba | TESTED | CI run 40112807227 success (self-hosted, S2). Targeted browser rerun 22 of 22 PASS at 0d51981 (HAIKU_P_ADMIN18_FIX.md). | Ready, merge CLEAN. Sonnet APPROVE at 0d51981 (SONNET_ADMIN18_R2_REVIEW.md). 046faba adds a master merge only. Full browser run not on disk. |
| admin #20 | 02d7473 | TESTED | CI run 40112882719 success (self-hosted, S2). | Draft, merge CLEAN. Sonnet APPROVE at 607d7d3. |
| admin #21 | 5789535 | TESTED | CI run 40112961483 success (self-hosted, S2). | Draft, merge CLEAN. Sonnet APPROVE at 07fce87; commit 15991748 has no review file on disk. |
| admin #22 | 7728455 | TESTED | CI run 40113034452 success (self-hosted, S2). | Draft, merge CLEAN. Sonnet APPROVE at 4184fa4; commit 6dc2ea0e has no review file on disk. |
| ~~readiness PR #359~~ | ~~638601f7~~ | ~~TESTED~~ | ~~GH run 39956291450 (docs, success)~~ | ~~Single ledger. OPEN.~~ [SUPERSEDED 2026-10-24 S2: head changes with this commit] |
| readiness PR #359 | this commit (was 638601f7) | DRAFT | Sanitized release documents committed (decision 7). | Single ledger. OPEN. |

## Acceptance documents

| Document | Status | Evidence | Notes |
|---|---|---|---|
| ~~SSR and UX~~ | ~~IN PROGRESS~~ | ~~RELEASE_0.8.5_SSR_UX_ACCEPTANCE.md~~ | ~~Final-heads W25-B TESTED (A to E); slow contrast fixed (#139); Firefox focus resolved (W24-B); Firefox reload UNVERIFIED (decision 17); R18 account switch NOT STARTED.~~ [SUPERSEDED 2026-10-24 S2: R18 and decision 17 status changed in S2] |
| SSR and UX | IN PROGRESS | RELEASE_0.8.5_SSR_UX_ACCEPTANCE.md | Firefox reload VERIFIED in stock Firefox 158 (decision 17, S2). R18 same-document defect fixed in #358 (S2); Firefox S5 inconclusive. Final-heads browser rerun and R18 clean rerun remain. |
| SEO | IN PROGRESS | RELEASE_0.8.5_SEO_ACCEPTANCE.md | Site one-hop 301s TESTED; node http redirect and favicons IN PROGRESS. |
| Performance | IN PROGRESS | RELEASE_0.8.5_PERFORMANCE_ACCEPTANCE.md | Guest startup TESTED at 1d68dfa3; returning-wallet cell to re-measure. |
| Cultural data | IN PROGRESS | RELEASE_0.8.5_CULTURAL_DATA_ACCEPTANCE.md | CD-07 BLOCKED; public-art full coverage BLOCKED. |
| ~~Moderation~~ | ~~IN PROGRESS~~ | ~~RELEASE_0.8.5_MODERATION_ACCEPTANCE.md~~ | ~~Review Deck browser gate NOT STARTED; Map Audit UI NOT STARTED.~~ [SUPERSEDED 2026-10-24 S2: Review Deck and admin UI status changed in S2] |
| Moderation | IN PROGRESS | RELEASE_0.8.5_MODERATION_ACCEPTANCE.md | Review Deck browser gate PARTIAL (S2). Map Audit UI, Data Inspector and claims queue UI IMPLEMENTED in admin #20 to #22 (S2). Full browser gate on the current head remains open. |
| ~~Institution~~ | ~~IN PROGRESS~~ | ~~RELEASE_0.8.5_INSTITUTION_ACCEPTANCE.md~~ | ~~Dry run TESTED; claims flag off.~~ [SUPERSEDED 2026-10-24 S2: claims queue UI status changed in S2] |
| Institution | IN PROGRESS | RELEASE_0.8.5_INSTITUTION_ACCEPTANCE.md | Dry run TESTED; claims flag off; claims queue UI IMPLEMENTED in admin #22 (S2). |

## Review verdicts (SCR/R-*.md)

The authoritative verdict table, including Opus-attested verdicts and CI notes, is RELEASE_0.8.5_REVIEW_LEDGER.md. The table below is the file-level view.

Verdicts that are recorded in the review files. A blank in "Verdict" means the file has findings or a skeleton and no verdict word.

| File | Head | Verdict |
|---|---|---|
| R-131-sonnet-review.md | 88d792ff | APPROVE-WITH-NITS |
| R-131-design-check.md | not stated | APPROVE-WITH-CHANGES |
| R-131-da299d3-review.md | da299d3 | interim, no verdict |
| R-133-sonnet-review.md / R-133-delta-review.md | 5c8b2273 / 4befea0 | findings, no verdict word |
| R-134-sonnet-review.md / R-134-delta-review.md | 0ef1553 / not stated | findings / "delta review done" |
| R-135-sonnet-review.md | b3b2de7 | findings (P1 bypass) |
| R-135-delta-review.md | d40a2d8 | APPROVE |
| R-136-sonnet-review.md | a6c4b02 | no bypass found, P2 items |
| R-136-delta-review.md | 129c73a | APPROVE |
| R-137-review.md | not stated | empty |
| R-138-review.md | 1905bfb | findings (P1/P2 evasion) |
| R-138-delta.md | d1d353e | P0 0, P1 0, P2 1 |
| R-358fix-sonnet-review.md | not stated | skeleton |
| R-360-sonnet-review.md | ad668604 | skeleton |
| R-app-d91d23d4-review.md | d91d23d4 | checks, no verdict word |
| R-app-d9405235-review.md | d9405235 | APPROVE |
| R-art36-sonnet-review.md | 3f18a5d | APPROVE-WITH-NITS |
| R-delta-36-20.md | ac8237e, c19a229 | APPROVE, APPROVE |
| R-ff-takeover-review.md | b47fdb42 | 86/86 tests; Firefox probe open at that time |
| R-node17-kubus20-review.md | 9c87fcc (and c47fce5) | findings, no verdict word |
| R-signin-a11y-review.md | 2dc07c62 | stub, no verdict word (verdict Opus-attested) |

## What is evidenced, pending, and owner gates

- Evidenced: candidate heads and CI (GH); final-heads W25-B (default limits PASS; SSR no-JS 68/68; takeover 16/16 ready plus 4/4 slow and failed; forced 503/404 6/6; slow contrast 5.05:1); takeover 264/264; transient 23/24 (W19-A); Firefox failed-state probes 6/6; W24-B Firefox focus repetition is headless end-of-document behaviour; #358 d9405235 full tier GREEN.
- ~~Pending: Firefox reload stall in a real browser (decision 17); R18 account switch; #361 draft-tier CI and merge decision; exact-head browser matrix; performance re-measure; Review Deck browser gate; node redirect probe; one real SMTP message through the pool on staging after deploy (#140, P3).~~ [SUPERSEDED 2026-10-24 S2: decision 17 verified and R18 defect fixed in S2]
- Pending (S2): R18 clean Firefox S5 rerun and a post-fix same-document run; admin #18 full browser gate at the current head; exact-head browser matrix; performance re-measure; Review Deck full browser gate; node redirect probe; one real SMTP message through the pool on staging after deploy (#140, P3).
- Owner gates (decisions numbered 1 to 18 in RELEASE_0.8.5_REVIEW_LEDGER.md; 17 real-Firefox reload spot-check, 18 anonymous rate-limit budget review): merges of #358, #360, #131, #361, #36, #20, #17, #18, #359; production promotion of #131 (production 46c9b84f carries the vulnerable body-parser, multer and nodemailer versions); backend package.json still 0.8.2, bump at release; deploys; HA reseed (backend-resume-evidence.md; HA slot wal_status lost); CD-07 read-only production audit; Search Console (node); physical Android and iOS devices; iOS signing (none in 0.8.x); Google Sign-In config for iOS; Map Audit, Data Inspector and claims UI decisions; institution claims activation; dispute semantics; ODbL; wallet-derived identity (v0.9); backend #105 scope; SEO limiter production setting; grants-table write privilege; node SL and EN copy; a prod-side note about the unpinned W12-A build.
- Cleanup (reference only): EV/cleanup/REPO_WORKTREE_CLEANUP_MANIFEST.draft.md lists 329 registered worktree entries; 181 removal candidates (51.2 GB; 182 CANDIDATE-REMOVE rows minus the submodule store row). Nothing removed. C: is 95% used.

## Open items / owner gates

- ~~Merges of #358, #361 and backend #131 are owner actions. #358 d9405235 full tier is GREEN (run 40039543223).~~ [SUPERSEDED 2026-10-24 S2: heads moved in S2]
- Merges of #358 (8802e3ed, which contains #360 and #361) and backend #131 (86a73d5) are owner actions. #358 full tier GREEN at 8802e3ed (run 40119949889).
- Owner approval for each merge and the 0.8.5 GO or NO-GO decision. This document cannot give GO.
- ~~Decision 17 (real-Firefox reload spot-check) and decision 18 (anonymous rate-limit budget review) are open.~~ [SUPERSEDED 2026-10-24 S2: decision 17 verified in S2]
- Decision 17 is VERIFIED (S2, stock Firefox 158). Decision 18 (anonymous rate-limit budget) remains a product review after owner approval (S2).
- No release tag, deployment or native build until the owner says so.
