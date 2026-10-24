# RELEASE 0.8.5 - Review ledger

Date: 2026-10-24
Single release ledger: RELEASE_0.8.5_READINESS.md (PR #359)
Authority: Opus-attested, 2026-10-24.

REVIEWED here means "independent agent review (Sonnet), not a GitHub approval." This is the only place the statement appears in this ledger.

Legend: SCR/ = [local path] EV/ = [local path] "Opus-attested" = recorded by the coordinator with no file read in this pass.

## Session 2 checkpoint (2026-10-24)

- Backup before S2 edits: [local path] Nothing deleted. Stale text is struck and tagged [SUPERSEDED 2026-10-24 S2: reason]. Line numbers cited in S2 notes refer to the pre-S2 file.
- Sources: S2-SONNET = SONNET_RECOVERY_REVIEW.md (authoritative for corrections); S2-B = HAIKU_B_GITHUB_STATE.md; S2-C = HAIKU_C_SECURITY_HOTFIX.md. All three are in [local path]
- Short names: MASTER_SCOPE = SCR/RELEASE_0.8.5_MASTER_SCOPE.md; MEM = [local path] FQA = RELEASE_0.8.5_FINAL_QA.md; SSR, PERF, MOD, CUL, INS, SEO = RELEASE_0.8.5_<SSR_UX | PERFORMANCE | MODERATION | CULTURAL_DATA | INSTITUTION | SEO>_ACCEPTANCE.md.

### Verified heads (S2-B, gh GET, 2026-10-24): all UNCHANGED against the expected heads

| Item | Head | Evidence on exact head | Note |
|---|---|---|---|
| backend #131 | 6ecbfca | run 40047787945 Backend CI SUCCESS | draft, CLEAN |
| backend master (prod baseline) | 46c9b84 | n/a | unchanged |
| art.kubus #358 | d9405235 | dispatch run 40039543223 green; PR-tier run 40037915357 red | red run = feed_like_settlement_test teardown-timer flake (S2-SONNET 2) |
| art.kubus #360 | ad668604 | run 39973672520 success | draft |
| art.kubus #361 | 2dc07c62 | run 40042467088 SUCCESS | draft |
| art.kubus #359 (docs) | 638601f7 | run 39956291450 success | draft; no expected head given |
| admin #18 | a2d78880 | run 39808186592 success | ready, CLEAN |
| art.kubus.site #36 | ac8237ec | run 39968698752 success | draft |
| kubus.site #20 | c19a2295 | run 39969235659 success | draft |
| node.kubus.site #17 (PRIVATE repo kubus-project/node.kubus.site) | 9c87fcc | run 39967858461 success | draft |

- Tags: backend has no v0.8.4 tag (only pre-release v0.7.0-alpha). admin.kubus has no tags or releases. No v0.8.5 tag anywhere. art.kubus: v0.8.4 latest, master 8c2c571f, dev c0647e5c.
- S2-B correction: run 40046344084 is PR #131's Backend CI run on headSha 4f21086, created 4 s after #139 merged into the integration branch. #139 had no CI run of its own (base is not master). That run failed the production dependency audit, which #140 fixed at 6ecbfca (S2-SONNET 3).
- Stale documents: PR #131 body still cites 88d792ff and "24 files, no dependency change". #359 RELEASE_0.8.5_READINESS.md pins app b3519e3c and backend 88d792ff and says NO-GO.

### Corrections applied (S2-SONNET; annotated in place)
- #138 row: d1d353e fixes P1 only. The P2 (double count) was found there and is open. e79a87c fixes the P2; Opus-attested only, file-level review pending.
- SSR L47: "not changed" is false. #138 and #139 change SSR output; #137 changes the limiter skip.
- SSR L75: rerun done. W25-B 68/68 at backend 4f21086 + app d9405235. Carries to 6ecbfca for GET/SSR/takeover/rate-limit only; POST, multipart and SMTP are not covered.
- #361 CI is green (run 40042467088).
- Carried to acceptance docs, not edited here: Ljubljana dry run = 115 raw rows, 7 folded into 6 strong merges = 108 records (35 accepted, 2 held, 71 skipped). CUL L24 and INS L20 need this.

### Still open (S2-SONNET; not yet applied to ledger text)
- L4 "Single release ledger" names the stale PR #359 file (2026-10-23 snapshot, NO-GO). Either commit the release docs (owner decision 7) or relabel the line.
- Backend rows that say e79a87c should read "superseded by 6ecbfca (e79a87c + #139 CSS + #140 deps)".
- #139 "APPROVE (Sonnet)" has no saved review file. #140 is reviewed in SCR/R-140-review.md; cite it.
- #139 and #140 were merged into codex/085-backend-integration-20261023 under the owner's gh identity; authorisation not recorded. FQA's "no merge" sentence needs qualifying.
- Two PR #131 comments (21:08Z on #137, 21:55Z on #138) say "Reviewed APPROVE" with no file-level review behind them. Footnote or amend.
- #358 merge evidence is the dispatch run only; the PR-tier run is red at the same head.
- Decisions 3 and 12 are shown as decided in CUL; treat as pending.
- LEDGER L72 "each acceptance doc cites them by number" holds only for decisions 2, 3, 8, 10-14, 17, 18.
- Ordering: the exact-head matrix must run on the final merged dev head; the version bump creates a new head; the SMTP smoke needs a named staging target; tying backend promotion to the HA reseed may delay the decision-16 hotfix.
- Acceptance-doc fixes (S2-SONNET 5.11-5.13, 5.17, 5.19) not applied here.

## Verdicts

| PR | SHA | Verdict | Evidence |
|---|---|---|---|
| backend #131 | 88d792ff | APPROVE-WITH-NITS | SCR/R-131-sonnet-review.md |
| backend 114 design | not stated | APPROVE-WITH-CHANGES | SCR/R-131-design-check.md |
| backend #133 | 5c8b2273 | APPROVE-WITH-NITS | SCR/R-133-sonnet-review.md; 4befea0 delta APPROVE: SCR/R-133-delta-review.md |
| backend #134 | 0ef1553 | APPROVE subject to 2 P2 fixes | SCR/R-134-sonnet-review.md; a696f47 APPROVE (P2s fixed; revoke, withdraw and reject never blocked): Opus-attested |
| backend #135 | b3b2de7 | CHANGES-REQUIRED (P1 DB guard bypass) | SCR/R-135-sonnet-review.md; d40a2d8 APPROVE (55-case fuzz): SCR/R-135-delta-review.md |
| backend #136 | a6c4b02 | APPROVE with P2 fixes | SCR/R-136-sonnet-review.md; 129c73a APPROVE (seeder never publishes): SCR/R-136-delta-review.md |
| backend #131 integration | da299d3 | APPROVE (guard union, merges complete) | SCR/R-131-da299d3-review.md; Opus-attested |
| backend #137 | 172b0c4d | APPROVE | Opus-attested; ad40b80 delta APPROVE: Opus-attested |
| backend #138 | 1905bfb | CHANGES-REQUIRED (P1 encoded-alias evasion) | SCR/R-138-review.md; ~~d1d353e fixes P2 double counting: SCR/R-138-delta.md~~ [SUPERSEDED 2026-10-24 S2: d1d353e fixes the P1 only. The P2 (double count) was found there and left open (SCR/R-138-delta.md). e79a87c fixes the P2 and adds mixed-case locale 301s; Opus-attested only, file-level review pending.]; e79a87c APPROVE (no open redirect, counts once): Opus-attested |
| backend #139 | 4f21086 | APPROVE (Sonnet) | Merged into branch codex/085-backend-integration-20261023 (gh). Slow-state copy contrast: light 2.93 to 5.05:1, dark 5.08 to 8.67:1 |
| backend #140 | 6ecbfca | APPROVE incl. lockfile integrity match (Sonnet) | Merged into the same branch (gh). Patches GHSA-27r3-jxmh-p828 (body-parser 1.20.9), GHSA-q7qp-rjg7-q26m (multer 2.5.0), nodemailer 10.1.4 (GHSA-8c8m-p3m8-cjg8, GHSA-m943-m63m-w62w, GHSA-85x2-q946-cp5h). Production 46c9b84f carries the vulnerable versions. P3: send one real SMTP message through the pool on staging after deploy. Backend package.json still 0.8.2; bump at release |
| backend final candidate | 6ecbfca | e79a87c + #139 + #140 | CI green run 40047787945 (GH). Final-heads acceptance (EV/w25-evidence) ran backend 4f21086 with app d9405235 at default limits; #140 not in that run |
| backend candidate | e79a87c | fast-forward of #138 onto ad40b80 | git: 1905bfb, d1d353e, ad40b80 are ancestors of e79a87c (checked 2026-10-24). CI green: Backend CI required, PG contracts, lint and tests (GH run 40030165802) |
| app #358 map-host fix | 1d68dfa3 | APPROVE | Opus-attested; full tier green run 39998320064 (GH) |
| app Firefox takeover fix | b47fdb42 | APPROVE | SCR/R-ff-takeover-review.md |
| app #358 | d91d23d4 | APPROVE | SCR/R-app-d91d23d4-review.md; full tier green run 40027457947 (GH) |
| app #358 | d9405235 | APPROVE | SCR/R-app-d9405235-review.md. CI: full-tier GREEN run 40039543223 (all 12 jobs; Flutter 5871 passed / 28 skipped; GH). Draft-tier run 40037915357 failed on a timer flake in feed_like_settlement_test (socket_io WebSocketTransport, 5 s; EV/w20a-evidence/draft-fail.txt) |
| app #361 | 2dc07c62 | APPROVE (Opus-attested) | Sign-in password-toggle accessible names. SCR/R-signin-a11y-review.md is a stub; GH: PR #361 OPEN draft; ~~draft-tier CI running~~ [SUPERSEDED 2026-10-24 S2: draft-tier run 40042467088 = SUCCESS] |
| app #360 | ad668604 | APPROVE (P0 to P2 none; P3 2) | Opus-attested |
| art.kubus.site #36 | 3f18a5d | APPROVE-WITH-NITS | SCR/R-art36-sonnet-review.md; ac8237e APPROVE: SCR/R-delta-36-20.md |
| node.kubus.site #17 | 9c87fcc | APPROVE-WITH-NITS | SCR/R-node17-kubus20-review.md; https redirect evidenced: EV/w3b-evidence/w3b-e2e-raw.txt (http 301 to https; https 200s) |
| kubus.site #20 | c47fce5 | APPROVE-WITH-NITS | SCR/R-node17-kubus20-review.md; c19a229 APPROVE: SCR/R-delta-36-20.md |

Note: GH (gh pr view, 2026-10-24) confirms current heads: #358 d9405235, #360 ad668604, backend #131 6ecbfca (final candidate; e79a87c before #139 and #140), #36 ac8237e, node #17 9c87fcc, kubus #20 c19a229, admin #18 a2d78880. Head c47fce5 (kubus #20) is an earlier head.

## Review status: Opus-attested only (needs Sonnet review)

Verdicts above that rest on Opus attestation, with no file-level Sonnet review in the cited evidence (S2-SONNET 5.10):
- app #360 ad668604 (R-360-sonnet-review.md is a skeleton)
- app #361 2dc07c62 (R-signin-a11y-review.md is empty)
- backend #134 fix a696f47 (P2 fixes; revoke, withdraw and reject)
- backend #137 172b0c4 and ad40b80
- backend #138 e79a87c (P2 fix plus mixed-case 301 redirect; no file-level review)
- backend #131 integration da299d3 (R-131-da299d3-review.md is interim, no verdict)
- app #358 1d68dfa3 (map-host fix)
- admin #18 a2d78880: none. No independent review recorded in any doc; ready, not draft.

## SSR no-JS count (reconciled)

Per-run summary files (EV/w12a-evidence/results/ssr-*.jsonl) show 17 rows per engine and viewport. Across the four runs that is 68 rows.

- 64 entity cell-runs: 60 PASS, and 4 are the SL thin post self-canonical row with noindex. That row is correct by policy (EV/w12a-evidence/DIAGNOSES-W12A.md (c); INDEX_OWNERSHIP_CANONICAL_POLICY_V1.md:39 and ~92; publicSearchPolicy.js ~309). Result: 64/64 acceptable.
- 4 unknown-id 404 controls: 4/4 PASS.

The matrix ran at app 1d68dfa3 and backend da299d3, before backend #137 and #138. ~~SSR rendering is not changed by those two PRs (Opus).~~ [SUPERSEDED 2026-10-24 S2: false. #138 changes SSR routing (seoPublicPages.js per-route limiter and a new mixed-case locale 301 route); #139 changes SSR slow-state CSS (seoPublicPagesService.js); #137 changes the server.js limiter skip. Source: git diff da299d3..4f21086, S2-SONNET 1.3.]

## Owner decisions (numbered, Opus list)

No owner approval is recorded for any item below, and none has full question wording (S2-SONNET section 8). Each source pointer names where fuller wording exists, or says label only.

1. HA reseed
   Source wording: MASTER_SCOPE L61 (OWNER: approve reseed runbook) and L70 (order: #131 review clear, backend candidate PG CI, owner approves HA reseed, backend promotion). Runbook: [local path]
2. CD-07 read-only production audit (plus placeholder attribution and public Invader collection checks)
   Source wording: MASTER_SCOPE L51 (OWNER approval: standby unusable, read-only primary fallback); SCR/W1-A2-report.md L60 (Oracle production read-only extract, output outside repo); placeholder and Invader checks: SCR/R-136-delta-review.md P3 and SCR/R-136-sonnet-review.md. No wording of the decision itself.
3. Defer CD-06 and CD-09
   Source wording: MASTER_SCOPE L52 (proposed DEFERRED-0.9, OWNER confirm). Still a proposal.
4. Backend #105 scope
   Source wording: MASTER_SCOPE L37 (decide #105, 0.8.5 vs 0.9); SCR/W1-A2-report.md L73 (adds #102 Moderation Studio S1: review, merge or drop).
5. Physical devices
   Source wording: MASTER_SCOPE L63 (physical Android device = OWNER) and L33 (iOS Google Sign-In: owner Google config and device). Paid iOS signing is a recorded decision (MASTER_SCOPE L25), not pending.
6. Node Search Console
   Source wording: MASTER_SCOPE L48 (owner Search Console steps); SEO acceptance doc L31 and L36.
7. #359 commit route
   Source wording: MEM L13 only (committing RELEASE_0.8.5_MASTER_SCOPE.md to #359 was not permitted by tool policy; owner decision).
8. Grants-table write privilege
   Source wording: SCR/R-133-sonnet-review.md L5 (TRUNCATE grants has no trigger but only removes visibility; re-insert needs seed GUC, owner decision); MOD acceptance doc L36. No fuller text.
9. Website copy (node descriptions, SL alpha vs EN stable, mobile EN/SL switch)
   Source wording: SCR/R-node17-kubus20-review.md item 5 (copy.ts:112 EN stable since 0.8.1 vs :316 SL alpha only). Node descriptions = the 18 EN/SL descriptions in node #17 (S2-SONNET 8). Mobile EN/SL switch: label only.
10. Admin repo "Haiku read-only" rule vs brief
   Source wording: MOD acceptance doc L21 and L32 only. The rule text is in the original orchestration brief, which is not on disk. Otherwise label only.
11. Dispute-approval semantics
   Source wording: SCR/W4-R-report.md L60 (decideClaim special-cases transfer only, so approving a dispute grants the disputing account a membership; needs owner decision). Accurate fuller text: INS acceptance doc L25.
12. Wallet-derived institution identity to v0.9
   Source wording: label only in MEM and in this ledger. INS acceptance doc L26 and L36 say Proposed for v0.9. Pending, not decided.
13. ODbL share-alike
   Source wording: label only in MEM. Only substantive text: licence note in [local path] and w8b-evidence/ljubljana-dry-run.json (share-alike may apply to a derived database; owner/legal check before publication).
14. SEED_PUBLISH_IMPORTS removal
   Source wording: SCR/W1-A2-report.md L50 (live seeding needs owner, SEED_PUBLISH_IMPORTS); MEM L17 (#136 seeder never publishes, flag removed). No recommendation recorded. CUL acceptance doc title reads as done.
15. Cleanup and _private secrets
   Source wording: [local path] L153 (_private folder; owner decides retention), L165 and L181. Do not open the _private contents.
16. Hotfix vs ship-with-0.8.5 for the production rate-limit bugs
   Source wording: LEDGER L66 only; MEM L23 (prod affected since b91358f for #137, since 3b0ddfa for #138); PR #131 comments. Local option: hotfix/0.8.4.2-security a7834c8 (see Security hotfix track).
17. Real-Firefox reload spot-check (W22-A: Firefox reload stall, UNVERIFIED in real browser; harness artefact likely)
   Source wording: [local path] SSR acceptance doc L35 and L44.
18. Rate-limit budget review (anonymous 300 per 15 min is exhausted by about 14 cold public page loads via non-exempt reads; still better than production, where no public read is exempt)
   Source wording: LEDGER L68 and SSR acceptance doc L45 only. Budget (300 per 900 s anonymous) confirmed by [local path] and results/A-default-limits.jsonl (first 429 at 301).

## Open items / owner gates

- Owner decisions 1 to 18 above. Each acceptance doc cites them by number where relevant.
- #358 d9405235 full tier: GREEN (run 40039543223).
- #361 2dc07c62: ~~draft-tier CI running~~ [SUPERSEDED 2026-10-24 S2: draft-tier run 40042467088 = SUCCESS]; verdict Opus-attested.
- ~~SSR matrix rerun at the current heads is NOT STARTED (matrix at 1d68dfa3 / da299d3).~~ [SUPERSEDED 2026-10-24 S2: rerun done. W25-B SSR no-JS 68/68 at backend 4f21086 + app d9405235 ([local path]). 4f21086..6ecbfca is package.json and lock only, so the GET, SSR, takeover and rate-limit results carry to 6ecbfca. POST, multipart and SMTP are NOT covered. Still open: the SL thin-post noindex assertion (B-ssr rows have no robots field; S2-SONNET 1.3 addendum).]

## Security hotfix track

- Status: local only. Not pushed, no PR, no deploy. Branch hotfix/0.8.4.2-security at a7834c8, worktree [local path] based on backend master 46c9b84 (S2-C).
- Cherry-picks (cherry-pick -x, no conflicts): 6587344 <- 172b0c4 (#137); bee277a <- ad40b80 (#137); cd62f6d <- 1905bfb (#138); 84e721c <- d1d353e (#138); 30fe3da <- e79a87c (#138, includes the mixed-case 301); a7834c8 <- 6ecbfca (#140 dependency patches). #139 (4f21086) excluded. No migration or schema files. Diff vs master: 6 files, +503/-34.
- Tests: lint PASS (rc 0). test:ci: 2550 passed, 200 skipped, 1 failed (authSecureAccount "wallet login returns canonical email verification fields", 5000 ms timeout). That file passes 11/11 alone on the hotfix and on master. Targeted (publicReadRateLimitSkip, seoPublicRateLimitScope, seoPublicPages): 146/146 pass. verify:toolchain fails for environment only (npm 11.19.1 vs 11.7.0). Not run: schema:parity, audit:ci.
- Deps, master to hotfix: body-parser 1.20.6 to 1.20.9; multer 2.4.0 to 2.5.0; nodemailer 10.0.14 to 10.1.4; express 4.22.2 unchanged. npm audit --omit=dev: 3 (2 high, 1 moderate) to 0.
- Open: Sonnet security review of a7834c8 IN PROGRESS ([local path] status "in progress"). Owner: decision 16; authSecureAccount timeout is load-dependent (rerun or raise the timeout); nodemailer 10.1 SMTP change needs a staging SMTP send; the mixed-case 301 is a behaviour change to call out in release notes.

## Session 2 final state (2026-10-24)

Scope: state at the end of this pass, verified against GitHub (gh, read-only) on 2026-10-24 unless stated. Evidence names are session evidence files (kept outside the repository, named for traceability) or PR and run identifiers. This pass made no merges, tags, deploys, reruns, dispatches or pushes to any repository except the PR #359 branch. Merges are owner actions.

### S2-1 Verified heads, reviews and CI

| Item | Head (2026-10-24) | State | Review and CI evidence |
|---|---|---|---|
| backend hotfix #142 | 24d8b0c0, merged as master 7d62d36 at 2026-10-24T10:33:38Z | MERGED. DEPLOYED to production (Oracle) 2026-10-24 10:39:11Z. Rollback tag rollback-pre-7d62d36 on the prior image (baseline 46c9b84). | CI run 40083797542 success on 24d8b0c0. Sonnet APPROVE: SONNET_SECURITY_HOTFIX_REVIEW.md (a7834c8), SONNET_MEDIA_PROXY_CAP_REVIEW.md. Deploy and edge checks: HAIKU_O_HOTFIX_DEPLOY.md (health ready, revision header, 30 of 30 anonymous exempt reads 200, /EN 301, forged X-Forwarded-For did not reset the counter). Open: a media-proxy 200 fetch was not achieved (the allowlisted host was not known to the check). |
| backend #131 | 86a73d5 (draft, merge CLEAN) | Not deployed. Includes migrations 113 to 116 (116 = institution_members versioning). | CI run 40115757445 success on the self-hosted runner (PostgreSQL contracts on the workstation Postgres label). Sonnet APPROVE on 4cdf098..86a73d5: SONNET_131_FINAL_DELTA_REVIEW.md. Earlier: SONNET_131_CLAIMS_R2_REVIEW.md (d9ac696..4cdf098), SONNET_131_CLAIMS_REVIEW.md. Migration 116: HAIKU_U_CLAIMS_BACKEND.md. The PR body still cites 88d792ff and must be refreshed. |
| admin #18 | 046faba (ready, merge CLEAN) | Not merged | CI run 40112807227 success (self-hosted). Sonnet APPROVE at 0d51981 (earlier head): SONNET_ADMIN18_R2_REVIEW.md. 046faba adds only a master merge. Browser: HAIKU_P_ADMIN18_FIX.md (targeted run 22 of 22 PASS at 0d51981). The full 93-check run was at a2d7888 (HAIKU_K_ADMIN18_QA.md, 7 FAIL, all addressed in 3d678ef); no full rerun is on disk. |
| admin #20 | 02d7473 (draft, merge CLEAN) | Not merged | CI run 40112882719 success (self-hosted). Sonnet APPROVE at 607d7d3: SONNET_ADMIN_20_21_REVIEW.md, SONNET_ADMIN_21_FINAL_REVIEW.md. Later commits are merges of master and #18 only. |
| admin #21 | 5789535 (draft, merge CLEAN) | Not merged | CI run 40112961483 success (self-hosted). Sonnet APPROVE at 07fce87 (1 MEDIUM-LOW, 4 LOW): SONNET_ADMIN_21_FINAL_REVIEW.md. Commit 15991748 (Data Inspector follow-ups F1 to F4) has NO review file on disk. |
| admin #22 | 7728455 (draft, merge CLEAN) | Not merged | CI run 40113034452 success (self-hosted). Sonnet APPROVE at 4184fa4 with nits: SONNET_ADMIN22_REVIEW.md. Commit 6dc2ea0e (review nits) has NO review file on disk. |
| art.kubus #358 | 8802e3ed (draft, merge BLOCKED while draft) | Not merged | Full-tier run 40119949889 success (2026-10-24T18:16Z). Reviewed chain (ancestry verified in the repository): 8cb325a0 REQUEST CHANGES, fixed in 59a8307d and c65c98b4 (APPROVE): SONNET_ACCOUNT_SWITCH_REVIEW.md. Nearby fix c0e8274c APPROVE: SONNET_NEARBY_FIX_REVIEW.md. Institution guards e142909e APPROVE: SONNET_INSTITUTION_GUARDS_REVIEW.md. Integration d59dd33f APPROVE, including #360 and #361 (sections 2 and 3): SONNET_APP_INTEGRATION_REVIEW.md. Final commit 8802e3ed (TaskProvider progress request after an identity change): NO review file on disk. |
| art.kubus #360 | ad668604 (draft) | Contained in #358 | Sonnet APPROVE with notes in the integration review at d59dd33f (section 3, SONNET_APP_INTEGRATION_REVIEW.md). Draft-tier run 39973672520 success. |
| art.kubus #361 | 2dc07c62 (draft) | Contained in #358 | Sonnet APPROVE in the integration review at d59dd33f (section 2, SONNET_APP_INTEGRATION_REVIEW.md). Draft-tier run 40042467088 success. |
| art.kubus #359 (this docs PR) | 638601f7 before this commit | Draft | The head changes with the commit that adds these documents; the final head is reported with the pass. |
| node.kubus.site #17 (private repository) | 7fd9abd (draft) | Not merged | Validate website run 40083371476 success on 7fd9abd. Sonnet APPROVE at b215be4: SONNET_NODE_SITE_17_REVIEW.md. Two later commits (cc3bb87, 7fd9abd) have NO review file on disk. |
| art.kubus.site #36 | ac8237e (draft) | Unchanged in S2 | Run 39968698752 success (earlier). Reviews: R-art36-sonnet-review.md, R-delta-36-20.md. |
| kubus.site #20 | c19a229 (draft) | Unchanged in S2 | Run 39969235659 success (earlier). Reviews: R-delta-36-20.md. |

### S2-2 Corrections and open review gaps

The S2 brief stated "Sonnet APPROVE on every delta". On disk this holds for art.kubus #358 through c65c98b4 and for each predecessor head listed above. It does not hold for: #358 8802e3ed; admin #21 15991748 and #22 6dc2ea0e (commits after the reviewed heads); node #17 cc3bb87 and 7fd9abd. The admin #18 and #20 heads moved only by master or branch merges; no delta review of those merges is on disk. Treat all of these as unreviewed until a review file records them.

### S2-3 Decisions

- Decision 7 (commit route for #359): approved. This pass commits sanitized copies of the release documents to the existing PR branch, and nothing else.
- Decisions 1 to 18: the coordinator recorded owner approval of decisions 1 to 18 per the Opus S2 recommendations. The decision wording and the S2 recommendations are not on disk, so this ledger does not restate them. Approval of a decision does not execute it. Items marked NOT DONE below still need a separate go.
- Decision 16 (hotfix now): executed. #142 merged and deployed on 2026-10-24 (S2-1).
- Decision 17 (real-Firefox reload spot-check): VERIFIED. Stock Firefox 158.0 (HAIKU_F_FIREFOX_RELOAD.md): W22-A cold plus reload 20 of 20 PASS; family A 24 of 24; reload at 300 ms 6 of 6; reload at 3 s 6 of 6; forced failure 5 of 5 with Refresh recovery; no-preference 3 of 3. The stall reproduced only in Playwright's bundled Firefox 146 (4 of 20 reloads), which is a harness artefact. Not isolated: the Firefox 146 versus 158 effect, and the Chromium family matrix was not rerun.
- Decision 18 (anonymous rate-limit budget): owner approval recorded per the coordinator (see the decisions 1 to 18 bullet). The hotfix deployed the public-read and SEO rate-limit changes; the edge checks in HAIKU_O_HOTFIX_DEPLOY.md show exempt reads not limited and no counter reset on forged forwarding headers. The budget itself remains a product decision to review.

### S2-4 R18 account switch

- Defect found (HAIKU_F_R18_SWITCH.md, defect 1): after a same-document sign-out and sign-in as another account, the confirmed Like wrote zero backend mutations (Chromium run 1; not reproduced after a full document load). Cause: setLiked short-circuited on cached flags, and logout did not clear the artwork cache.
- Fixed in the #358 chain 9e014fa2 to c65c98b4 (Sonnet final APPROVE: SONNET_ACCOUNT_SWITCH_REVIEW.md).
- Firefox S5 (back and forward across the switch): INCONCLUSIVE. The guest Like gate did not appear on one run, and the cause was not diagnosed (screenshot evidence only). NOT DONE: a clean rerun.
- NOT DONE: a post-fix same-document browser run (no evidence on disk).

### S2-5 Infrastructure (no production writes in this pass beyond the approved hotfix deploy)

- IPFS cluster API wedged (HAIKU_R_IPFS_DIAG.md). The cluster container has been running since 2026-10-09 with its REST accept queue full and memory near its limit; the kubo node is healthy. The public snapshot publish aborts at its first dataset because a 5 s cluster pin timeout is fatal, even with the unpinned fallback flag set. Upload failures are logged since 2026-10-11 (about 1,500 per day). DNSLink was last updated 2026-10-09. Owner restart pending: capture state first, because a restart drops in-flight pin requests. The public-pin-reaper stays disabled until it is recreated on the current image.
- HA (HAIKU_Z_HA_DIAG.md; SONNET_HA_RUNBOOK_REVIEW.md). The primary is writable. The Home standby has not streamed since 2026-10-12 13:39 UTC; its replication slot is lost (wal_status lost) and the WAL gap (about 54 GiB) is beyond the archive, so a reseed is required. The reseed runbook (HAIKU_Z_HA_RESEED_RUNBOOK.md) is a DRAFT and NOT EXECUTED. The Sonnet verdict is NEEDS CHANGES with six defects, including auto-heal loops that would restart Postgres during a wipe, a password rotation the renewer would revert, a missing application_name, and automatic strict synchronous commit once the standby streams. NOT DONE: reseed, slot change, credential rotation, DNS write. Owner decisions: go or no-go for the reseed after the corrections; credential rotation before any reseed; capture of the 2026-10-12 host event before wiping; an off-host backup and replication-loss alerting.
- Self-hosted CI (HAIKU_AA_CI_RUNS.md). GitHub-hosted jobs failed at about 2 s with no steps (account billing block) on backend #131 and admin #21 and #22 at earlier heads. The admin heads, and backend #131 at 86a73d5, now run on the workstation self-hosted runner. Admin routing arrived via master (PR #23). art.kubus (public) still runs on GitHub-hosted runners; its iOS jobs need macOS. Owner decision: runner registration and billing.

### S2-6 Owner actions remaining, in order

1. Close the review gaps in S2-2 (Sonnet review of art.kubus #358 8802e3ed, admin #21 15991748 and #22 6dc2ea0e, node #17 cc3bb87 and 7fd9abd), and decide whether the admin #18 and #20 master merges need a delta review.
2. Merges (owner only; none done): backend #131 after items 4 and 8; admin #18, then #20, #21 and #22 in stacked order; art.kubus #358 (contains #360 and #361, whose own PRs are then closed or merged per owner); art.kubus #359 (this docs PR); art.kubus.site #36; kubus.site #20; node.kubus.site #17.
3. IPFS cluster restart in a maintenance window, after a read-only state capture. Code decision: whether a pin timeout may fall back to a kubo pin, or the cluster pin may be made non-blocking. The reaper stays disabled.
4. HA: go or no-go for the reseed after the runbook corrections; replication-credential rotation before any reseed; check that the external health monitor uses the writable endpoint; capture of the 2026-10-12 host event; off-host backup and alerts.
5. R18: clean stock-Firefox rerun of S5, and a post-fix same-document browser run.
6. Admin #18: full browser gate (93 checks) at the current head.
7. Runner and billing decision for GitHub-hosted jobs and the macOS iOS job.
8. Backend release steps: the #140 SMTP staging send after deploy (P3); the backend package.json version bump at release; the performance gate (returning-wallet re-measure, marker bench at the current head). Promotion of #131 only after items 4 and 8.
9. Device and store gates: physical Android Chrome; iOS Google Sign-In configuration; installed App Link proof. No signed 0.8.5 artifact is qualified.
10. Node: Search Console steps and a live http-to-https probe after deploy; the SL and EN copy decision (decision 9).
11. Execution still pending for decisions: 2 (the CD-07 production read-only audit has to be run), 11 (dispute approval semantics), 13 (ODbL review), 14 (live seeding flag) and 15 (_private retention).

### S2-7 Not done in this pass

No merges, tags or releases. No deploys beyond the approved #142 hotfix. No reseed, slot change, password change or DNS write. No cluster restart and no reaper change. No CI reruns or dispatches. No force pushes. Nothing was pushed to any repository except the PR #359 branch.
