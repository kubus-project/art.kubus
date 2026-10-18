# art.kubus 0.8.4 CI usage baseline (task 084-L1)

Status: read-only measurement. No workflow was dispatched, rerun or cancelled. No repository file was edited. Coordinator: Opus session art-kubus-66. Worker model: Haiku 5.5.

## Method, window and caveats

- Measured: 2026-10-18, gh queries run 20:50 to 21:05 UTC (`date -u` at start: 2026-10-18T20:50:22Z).
- Window: runs created on or after 2026-10-04 (gh `--created ">=2026-10-04"`), about 14.5 days up to 2026-10-18T21:00Z. Limits were set high enough that no list was truncated (art.kubus pr-validation 370 runs, limit 1000).
- Workflow YAML: art.kubus read with `git show origin/dev:` as tasked. art.kubus.site and admin.kubus read with `gh api ... ?ref=master` (their default branch). Neither repo has a `dev` branch (`gh api .../contents/...?ref=dev` returns 404 for both).
- Minutes = sum over non-skipped jobs of (completedAt - startedAt), from `gh run view --json jobs` for the latest attempt. Earlier attempts of the 11 re-run runs (9 PR-validation, 1 Release production web, 1 Deploy development web) were measured separately (section 3.5). These are runner job-minutes, not billed minutes. No money figures are given.
- macOS and Windows minutes (iOS jobs on macos-15, Flutter test on macos-15 and windows-2025) are raw minutes. They are not comparable to ubuntu minutes; no conversion was applied.
- Runs executed the workflow file revision at their own head SHA. Older tag runs therefore show older job sets (for example the iOS signing job is skipped in all five Mobile release runs). The reason the iOS signing job is skipped was not verified.
- Raw JSON for every number below is in `C:\Users\Rok\AppData\Local\Temp\claude\g--WorkingDATA-art-kubus\1063bf20-d337-4eb1-94d7-21bb09227fdd\scratchpad\ci-usage\`.

## Headline numbers

| Item | Value (measured) |
|---|---|
| art.kubus, all workflows, 14 days, latest attempts, job-minutes | 14,940.4 |
| of which Pull request validation (370 runs) | 14,511.4 (97.1%) |
| of which Flutter + Android + iOS jobs inside PR validation | 12,636.4 (84.6% of all art.kubus minutes) |
| PR-validation minutes in cancelled runs (103 runs; cancelled by the concurrency group, inferred to be superseded by a newer push) | 2,564 |
| PR-validation minutes in failed runs (32 runs) | 1,356 |
| Re-run earlier attempts, not in the totals above | about 372.5 |
| art.kubus.site ci.yml, 14 days, 21 runs | 29.6 |
| admin.kubus Admin CI, 14 days, 16 runs | 17.6 |

## 1. Triggers (question 1)

### art.kubus (origin/dev workflows)

| Workflow | pull_request | push | schedule | workflow_dispatch | Filters and notes |
|---|---|---|---|---|---|
| pr-validation.yml | yes: branches [dev, master]; no paths; default types (opened, synchronize, reopened) | no | no | yes | No `draft` or `ready_for_review` anywhere in the file. No job `if` references draft. |
| deploy-development.yml | no | yes: branches [dev]; no paths | no | yes (inputs community_multi_media_enabled, bootstrap_web_root) | Every push to dev deploys. Calls web-artifact.yml. |
| release-production.yml | no | no | no | yes | Job guard rejects non-master. Calls web-artifact.yml. |
| mobile-release.yml | no | yes: tags v* | no | yes | Tag pushes only. |
| pages.yml | no | yes: branches [master], paths docs/** and the workflow file | no | yes | Docs only. |
| scheduled-quality.yml | no | no | yes: `23 3 * * 1` (Mondays 03:23 UTC) | yes | Scheduled runs use the default branch. Calls web-artifact.yml (three browsers). |
| ios-unsigned-build.yml | no | no | no | yes | Manual IPA only. |
| web-artifact.yml | no | no | no | no | workflow_call only. Called by pr-validation, deploy-development, release-production, scheduled-quality. |

GitHub-managed or branch-only workflows seen in the window (not in origin/dev): "Dependabot Updates" (dynamic, 9 runs) and two temporary workflows that exist only on branch `fix/settings-support-center-20261008` ("Temporary Dart format evidence (0.8.3)", 5 push runs; "Temporary 0.8.3 formatter recheck", 2 push runs).

### Same-commit duplicates in art.kubus

- No single workflow fires on both push and pull_request for the same commit. pr-validation has no push trigger; deploy-development has no pull_request trigger. Measured: 0 commits had a pull_request run and a push run of the same workflow.
- Same workflow, same commit, push plus workflow_dispatch: 2 commits (deploy-development: c57232f6 with a successful dispatch and a cancelled push; cd7ce732 with a failed dispatch and a successful push). Dispatch is a deliberate re-deploy, so this is not counted as waste.
- Cross-workflow, measured: 7 dev commits ran pr-validation as a pull_request head (dev to master release PRs) and deploy-development as a push to dev. Web build minutes: 40.5 in the 7 PR runs and 24.9 in the 7 deploy runs (each about 3.5 to 6.5 min). Inferred: the same source is built twice, once with production policy and once with development policy.
- Temporary branch workflows: 7 push runs on fix/settings-support-center-20261008 (4.4 min total); 5 of those commits also had a pr-validation pull_request run that was cancelled.

## 2. pr-validation decision logic (question 2)

### 2.1 scripts/ci/classify_changed_paths.mjs (read from origin/dev, run locally on file lists)

| Category | Set when a changed path matches | Enables |
|---|---|---|
| full | any path under .github/workflows/, .github/actions/ or scripts/ci/; any path no rule matches (for example root CHANGELOG.md, .gitignore, scripts/kubus-lint-ratchet.mjs); base branch master; workflow_dispatch | every job |
| ci | .github/workflows/, .github/actions/, scripts/ci/, any AGENTS.md, .github/copilot-instructions.md | documentation job (and full for workflow and action paths) |
| frontend | lib/, test/, integration_test/, assets/, tool/, packages/kubus_lints/, pubspec.yaml, pubspec.lock, analysis_options.yaml | flutter_quality, web_artifact; also sets web, android, ios |
| web | web/, scripts/qa/ | web_artifact, web_routing |
| android | android/ | android (plus frontend paths) |
| ios | ios/ | ios (plus frontend paths) |
| backend | the `backend` gitlink, scripts/ci/checkout_backend_submodules.sh, scripts/ci/backend_gitlink_contract.mjs | backend_contract |
| docs | docs/, README.md, CONTRIBUTING.md, GOVERNANCE.md, SECURITY.md, SUPPORT.md, .github/pull_request_template.md, ISSUE_TEMPLATE/, .github/dependabot.yml | documentation |
| versioning | pubspec.yaml, version.json, package.json, scripts/sync_versions.js, scripts/sync_all_versions.mjs, scripts/resolve_ci_build_metadata.mjs, backend | backend_contract |
| deployment | scripts/deploy/, docs/DEPLOYMENT_GATES.md, docs/engineering/branching-and-deployment.md, docs/seo-public-pages.md, web/.htaccess (also sets web) | guardrails (verify:ci step), web_routing, web_artifact |
| agents | AGENTS.md, .github/copilot-instructions.md | documentation |

Local probe of the real script (synthetic one-path lists, read-only):

| Path | Categories set |
|---|---|
| README.md | docs |
| docs/release-0.8.3.md | docs |
| docs/engineering/branching-and-deployment.md | web, docs, deployment |
| AGENTS.md | docs, ci, agents (not full) |
| lib/x.dart | frontend, web, android, ios |
| web/index.html | web |
| android/app/build.gradle | android |
| ios/Runner/Info.plist | ios |
| pubspec.yaml | frontend, web, android, ios, versioning |
| package.json | versioning |
| .github/workflows/pr-validation.yml | full, ci |
| .github/dependabot.yml | docs |
| scripts/kubus-lint-ratchet.mjs | full (unmatched) |
| CHANGELOG.md | full (unmatched) |
| .gitignore | full (unmatched) |

### 2.2 Which jobs run

| Job | Runs when |
|---|---|
| source_policy, changes | always |
| guardrails | always (needs source_policy and changes; no `if`). Its verify:ci step needs full or deployment; PHP lint needs full or web. |
| documentation | full, docs, agents or ci |
| flutter_quality | full or frontend |
| web_artifact (reusable "Release web build and browser smoke") | full, frontend or web |
| backend_contract | full, backend or versioning |
| android | full or android |
| ios | full or ios |
| web_routing | full, web or deployment |
| required ("PR validation required") | always (`if: always()`) |

For pull_request runs the diff is `BASE_SHA..GITHUB_SHA` (the merge ref). For workflow_dispatch, `full=true` and the file list is `git ls-files`, so a manual run covers everything. A base of master forces `full=true` regardless of paths.

### 2.3 Draft PRs

- Draft PRs are not filtered. The trigger has no `types:` list, so GitHub defaults apply (opened, synchronize, reopened). No job checks draft state. Result: a draft PR runs the same jobs as a ready PR.
- Measured: 8 runs were on current draft PR heads and 90 runs on non-draft heads (ready PRs, plus merged or closed PRs; matched by head SHA; PR state read at query time). Mean job-minutes: 45.4 (draft) and 43.3 (non-draft).
- Measured job-set comparison: PR #302 (draft, docs only) 1.4 min vs PR #307 (ready, docs only) 1.3 min, same jobs. PR #318 (draft, lib) 60.9 min vs PR #269 (ready, lib) 50.1 min, same jobs.
- Inferred: marking a draft ready does not start a run, because ready_for_review is not in the types list.
- Conclusion: drafts do not get cheaper validation today. Only the path classifier reduces cost, and it does not look at draft state.

### 2.4 validate_job_results.mjs and skipped jobs

- For each of the 10 expected jobs, the result must be `success` or `skipped`. A missing key, `failure`, `cancelled` or a missing result fails the aggregate.
- A skipped job is accepted without checking that the classifier justified the skip.
- Measured, all 370 runs: "PR validation required" concluded success in all 225 successful runs; failure in 103 cancelled runs and 34 failed runs; absent in 6 cancelled runs; cancelled in 1 failed run; success in 1 cancelled run (its upstream jobs had all passed before the cancel). Example: run 39151330370.

### 2.5 Measured mix of the 355 pull_request runs (14 days)

| Group (by which job families executed, not skipped) | Runs | Mean job-min |
|---|---|---|
| Flutter, Android, iOS and web all executed (with or without docs and backend) | 308 | 44.4 |
| No Flutter, Android or iOS job executed: 19 guardrails-only (mean 3.0), 11 docs-only (mean 1.4), 7 with the web build (mean 5.6 to 5.7). Cause of the guardrails-only group not checked per run (inferred: empty or non-matching diffs) | 37 | 1.4 to 5.7 by sub-group |
| Flutter, Android and iOS shown but no runtime (cancelled before start, inferred) | 10 | 1.0 |

Empty-diff PRs (changedFiles = 0 in the PR list) include PR #311, #313, #320 and #321 (matched runs). Those are inferred to be among the 37 guardrails-only runs.

## 3. pr-validation run data (question 3)

### 3.1 The 80-run list requested

Command: `gh run list -R kubus-project/art.kubus --workflow pr-validation.yml --limit 80 --json databaseId,event,headBranch,headSha,conclusion,createdAt,updatedAt,status,displayTitle` (displayTitle added to the requested fields).

| Metric | Value |
|---|---|
| Runs | 80 (77 pull_request, 3 workflow_dispatch) |
| Conclusions | success 48, cancelled 20, failure 12 |
| Window | 2026-10-15T21:02:03Z to 2026-10-18T20:30:37Z (3.2 days; this is why section 3.2 uses 14 days) |
| Distinct headSha | 80 (no SHA repeated) |
| Distinct headBranch | 24 |

### 3.2 14-day totals

Command: `gh run list -R kubus-project/art.kubus --workflow pr-validation.yml --limit 1000 --created ">=2026-10-04" --json databaseId,event,headBranch,headSha,conclusion,createdAt,updatedAt,status,displayTitle,attempt`.

| Event / conclusion | Runs | Job-min total | Mean job-min per run |
|---|---|---|---|
| pull_request / success | 220 | 9,859 | 44.8 |
| pull_request / cancelled | 103 | 2,564 | 24.9 |
| pull_request / failure | 32 | 1,356 | 42.4 |
| workflow_dispatch (all) | 15 | 732 | 48.8 |
| All | 370 | 14,511 | 39.2 |

Distinct headSha: 370 for 370 runs, so zero repeated runs on the same SHA. Re-runs: 9 PR runs have a second or third attempt (section 3.5).

Per-job totals across the 370 runs (non-skipped jobs):

| Job | Executed runs | Total min | Median min (executed runs) | p90 min |
|---|---|---|---|---|
| Flutter analysis, lint, format, and tests | 333 | 5,290.1 | 14.9 | 31.7 |
| Android release compile without signing | 333 | 4,871.0 | 16.6 | 19.4 |
| iOS release compile without codesigning | 333 | 2,475.3 | 7.9 | 9.8 |
| Release web build and browser smoke (web-artifact.yml) | 329 | 1,173.8 | 3.5 | 4.0 |
| Repository, CI, and deployment guardrails | 361 | 200.8 | 0.6 | 0.7 |
| Apache production routing contract | 340 | 113.3 | 0.3 | n/a |
| Resolve affected CI surfaces | 364 | 101.0 | 0.3 | n/a |
| Validate PR branch provenance | 364 | 93.0 | 0.3 | n/a |
| PR validation required | 364 | 92.9 | 0.2 | n/a |
| Documentation and agent consistency | 215 | 66.0 | 0.3 | n/a |
| Backend compatibility contract | 119 | 34.3 | 0.3 | n/a |

Top three cost drivers in pr-validation: Flutter (5,290 min), Android (4,871 min) and iOS (2,475 min). Together they are 87.1% of PR-validation minutes.

### 3.3 Representative runs (per-job minutes, latest attempt)

Command per run: `gh run view <id> -R kubus-project/art.kubus --json databaseId,workflowName,attempt,event,headBranch,headSha,conclusion,status,createdAt,startedAt,updatedAt,displayTitle,jobs`. PR numbers were matched by head SHA (`gh pr list`) and changed files by `gh pr view <n> --json files`. Categories come from the real classifier on those files.

| Run | PR | State | Classifier categories | Source | Classify | Guard | Docs | Flutter | Android | iOS | Web | Backend | Routing | Required | Total job-min | Wall min |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 39034176229 | #307 | ready | docs (1 file) | 0.2 | 0.2 | 0.3 | 0.3 | skip | skip | skip | skip | skip | skip | 0.2 | 1.3 | 1.2 |
| 38968991124 | #302 | DRAFT | docs (2 files) | 0.2 | 0.3 | 0.4 | 0.3 | skip | skip | skip | skip | skip | skip | 0.3 | 1.4 | 1.3 |
| 39147276715 | #309 | ready | web, docs, deployment | 0.2 | 0.3 | 0.6 | 0.3 | skip | skip | skip | 3.8 | skip | 0.3 | 0.2 | 5.8 | 5.0 |
| 38097279728 | #269 | ready | frontend, web, android, ios (2 lib files) | 0.2 | 0.3 | 0.5 | skip | 15.1 | 21.2 | 8.9 | 3.5 | skip | 0.4 | 0.2 | 50.1 | 22.2 |
| 39135423927 | #318 | DRAFT | frontend, web, android, ios (2 lib files) | 0.2 | 0.2 | 0.5 | skip | 31.8 | 14.9 | 9.3 | 3.5 | skip | 0.3 | 0.2 | 60.9 | 32.9 |
| 39057804342 | #308 | ready | frontend, web, android, ios, docs (10 files) | 0.2 | 0.2 | 0.5 | 0.3 | 30.0 | 16.4 | 8.9 | 3.6 | skip | 0.3 | 0.2 | 60.8 | 31.1 |
| 38965013878 | #303 | ready | frontend, web, android, ios, docs (185 files) | 0.2 | 0.2 | 0.6 | 0.3 | 29.9 | 15.3 | 9.5 | 3.5 | skip | 0.3 | 0.2 | 60.2 | 32.4 |
| 38232008481 | #273 | ready, FAILED at Flutter test | frontend, web, android, ios, docs (100 files) | 0.2 | 0.2 | 0.5 | 0.3 | 13.5 | 18.3 | 5.7 | 3.1 | skip | 0.3 | 0.2 | 42.2 | 19.3 |
| 37516701099 | #245 | ready | full (`.github/workflows/deploy-development.yml` and scripts/ci) | 0.3 | 0.2 | 0.7 | 0.3 | 12.6 | 14.6 | 9.1 | 3.0 | 0.3 | 0.3 | 0.2 | 41.6 | 16.0 |
| 37974478579 | #175 (dependabot) | ready | full (`.github/workflows/*.yml`) | 0.2 | 0.2 | 0.6 | 0.3 | 15.6 | 20.1 | 8.1 | 3.5 | 0.5 | 0.4 | 0.3 | 49.7 | 21.4 |
| 38719586772 | #293 (base master, 3 scripts/qa files) | ready | web, forced to full by base master | 0.4 | 0.2 | 0.7 | 0.3 | 40.9 | 18.4 | 9.3 | 5.7 | 0.4 | 0.3 | 0.2 | 76.9 | 42.4 |

Reading the table: a docs-only PR costs about 1.3 min. A two-file Dart change costs about 50 min (flutter 15 + android 21 + iOS 9 + web 4). Any change under .github/workflows costs the full set (41 to 50 min for two or three files).

### 3.4 Per PR head branch (repeated runs)

Measured by headBranch as a proxy for the PR (inferred; the SHA-to-PR join covers only current heads).

- 89 distinct PR head branches produced 355 pull_request runs. Median 3 runs per branch (histogram: 24 branches with 1 run, 20 with 2, 11 with 3, 13 with 4, and 21 with 5 or more).
- Top branches:

| Branch | Runs | Cancelled | Failure | Success |
|---|---|---|---|---|
| dev (release PRs to master) | 18 | 2 | 0 | 16 |
| fix/083-map-motion-performance | 15 | 9 | 1 | 5 |
| feat/0.8.2-community-guest-gating | 15 | 2 | 3 | 10 |
| fix/083-profile-artwork | 12 | 7 | 2 | 3 |
| feat/0.8.2-support-center | 12 | 3 | 0 | 9 |
| fix/0.8.2-media-resolution | 12 | 0 | 1 | 11 |
| fix/settings-support-center-20261008 | 11 | 9 | 2 | 0 |
| fix/083-community-media | 10 | 4 | 3 | 3 |

### 3.5 Re-runs

- 9 PR-validation runs had re-run attempts (8 at attempt 2, 1 at attempt 3). Attempt 1 of those runs was measured separately: 344.6 PR job-min. The latest attempt of 37369689809 (attempt 3) is in the totals, and its attempt 2 was measured at 15.8 min.
- Two other re-runs: Release production web attempt 1 (9.3 min) and Deploy development web attempt 1 (2.8 min). Totals with earlier attempts: about 372.5 min more across art.kubus.

### 3.6 Lib-only versus draft versus ready (measured)

Covered in section 2.3 and the table in 3.3.

## 4. Other art.kubus workflows, last 14 days (question 4)

| Workflow | Runs | Events | Conclusions | Total job-min | Mean job-min per run | Notes |
|---|---|---|---|---|---|---|
| Deploy development web | 38 | 36 push, 2 dispatch | 36 success, 1 failure, 1 cancelled | 159.6 | 4.2 | Build 3.5 min per run, promote 0.7 min. Failure: dispatch 2026-10-14 at the deploy-web-artifact action. |
| Scheduled quality | 2 | schedule | 2 failure | 119.1 | 59.5 | Both on master (2026-10-05, 2026-10-12). Flutter test: macOS 24.2, Windows 20.7, Ubuntu 10.7 (mean per run). Failed at `npm ci` in the private backend job and at "Cache Playwright browser binaries". |
| Release production web | 8 | dispatch (master) | 8 success | 61.8 | 7.7 | Build 5.8 min, promote 1.9. Wall time mean 102.5 min (median 19.6), inflated by a few long-waiting runs (not analysed). |
| Mobile release | 5 | push tags | 5 success | 58.5 | 11.7 | Tags v0.8.0, v0.8.1, v0.8.2, v0.8.2.1, v0.8.3. Android sign 10.9 min mean. The iOS signing job is skipped in all 5 (reason not verified). |
| Dependabot Updates | 9 | dynamic (GitHub-managed) | 9 success | 12.9 | 1.4 | Billing treatment not verified. |
| Pages (docs) | 7 | push master (docs paths) | 7 success | 2.7 | 0.4 | Docs site build and deploy. |
| iOS unsigned build | 1 | dispatch (master) | 1 success | 9.9 | 9.9 | 2026-10-18 17:49Z. |
| Temporary workflows (branch fix/settings-support-center-20261008) | 7 | push | 7 success | 4.4 | 0.6 | Not in origin/dev. |
| Pull request validation (for comparison) | 370 | 355 pull_request, 15 dispatch | see 3.2 | 14,511 | 39.2 | |

Scheduled quality runs at the cron time on Mondays. Both failed, so 119 min were spent on no passing signal.

## 5. art.kubus.site and admin.kubus (question 5)

### 5.1 art.kubus.site (kubus-project/art.kubus.site, private, default master)

Workflow: `.github/workflows/ci.yml` only (`gh workflow list --all` shows only "CI").

Triggers:
- `pull_request:` with no filters (every base branch, every branch with a PR).
- `push:` with no filters (every branch).
- `workflow_dispatch:`.
- Job `site` (lint, tests, SEO build) runs for every event. Job `deploy` (Netcup production, environment production-web) runs only on dispatch on master.
- Concurrency group includes `github.event_name`, so a pull_request run and a push run for the same commit never cancel each other.

Measured, 14 days (21 runs; command `gh run list -R kubus-project/art.kubus.site --limit 1000 --created ">=2026-10-04" --json ...`):

| Event / conclusion | Runs |
|---|---|
| push / success 9, cancelled 1, failure 1 | 11 |
| pull_request / success 5, cancelled 1, failure 1 | 7 |
| workflow_dispatch / success | 3 |

Job-minutes: `site` 27.5 (mean 1.3 per run); `deploy` 2.1 (3 successful production deploys to Netcup, all on dispatch; the two other deploy entries belong to cancelled runs and took 0 min; deploy is skipped on other events).

Duplicates (measured):
- 7 commits ran both pull_request and push (same SHA, both `site` jobs ran to completion). Minutes: pull_request copies 9.1, push copies 9.0. One copy of each pair is redundant (about 9 min over the window).
- 3 commits ran both push and workflow_dispatch on master (a manual dispatch on a commit already pushed). Dispatch copies: 6.1 min, including the production deploy. Deliberate, so not counted as waste.

Last 21 runs (all in window, newest first):

| Run | Created (UTC) | Event | Branch | SHA | Conclusion | Title |
|---|---|---|---|---|---|---|
| 38756761711 | 10-15 15:02 | push | master | 97471111 | success | docs(brand): standardize scoped kubus wordmark |
| 38720260745 | 10-15 10:26 | pull_request | docs/wordmark-typography-082 | c7d903f0 | success | Document the approved kubus ecosystem wordmark |
| 38720255163 | 10-15 10:26 | push | docs/wordmark-typography-082 | c7d903f0 | success | docs(brand): standardize scoped kubus wordmark |
| 38717315427 | 10-15 10:01 | push | master | ff00bb1e | success | Merge pull request #31 |
| 38717315241 | 10-15 10:01 | workflow_dispatch | master | ff00bb1e | success | CI |
| 38714087568 | 10-15 09:35 | pull_request | topicfix/082-family-brand | 0a40c6b8 | success | Align kubus family branding |
| 38714081768 | 10-15 09:35 | push | topicfix/082-family-brand | 0a40c6b8 | success | fix(brand): emphasize authored consent |
| 38712392882 | 10-15 09:21 | pull_request | topicfix/082-family-brand | 984b176e | success | Align kubus family branding |
| 38712384957 | 10-15 09:21 | push | topicfix/082-family-brand | 984b176e | success | chore(release): synchronize canonical |
| 38712324154 | 10-15 09:21 | pull_request | topicfix/082-family-brand | a0ad2646 | cancelled | Align kubus family branding |
| 38712318643 | 10-15 09:21 | push | topicfix/082-family-brand | a0ad2646 | cancelled | test(brand): use unescaped quotes |
| 38654136307 | 10-14 23:26 | pull_request | topicfix/082-family-brand | d75c2970 | failure | Align kubus family branding |
| 38654131393 | 10-14 23:26 | push | topicfix/082-family-brand | d75c2970 | failure | fix: preserve art kubus family wordmark |
| 38077543423 | 10-10 18:52 | pull_request | fix/typography-inter-audit | d81a56a3 | success | fix(typography): retire Inter |
| 38077308692 | 10-10 18:49 | push | fix/typography-inter-audit | d81a56a3 | success | fix(typography): retire Inter |
| 38003621542 | 10-09 23:16 | workflow_dispatch | master | 31a2a5d4 | success | CI |
| 37677186344 | 10-07 19:47 | push | master | 31a2a5d4 | success | fix(header): set the brand title |
| 37243075661 | 10-04 23:15 | workflow_dispatch | master | f792acf9 | success | CI |
| 37243055429 | 10-04 23:14 | push | master | f792acf9 | success | Merge pull request #29 |
| 37241232462 | 10-04 22:45 | pull_request | release/0.8.1 | c99af4c3 | success | release: art.kubus.site 0.8.1 |
| 37241229338 | 10-04 22:45 | push | release/0.8.1 | c99af4c3 | success | release: art.kubus.site 0.8.1 |
| 37241229338 | 10-04 22:45 | push | release/0.8.1 | c99af4c3 | success | release: art.kubus.site 0.8.1 |

Config risk (inferred, not a measured failure): a push to any branch with an open PR produces two runs of the full `site` job. The job has no path filter, so docs-only commits also run the full lint, test and SEO build.

### 5.2 admin.kubus (kubus-project/admin.kubus, private, default master)

Workflows (`gh workflow list --all`): "Admin CI" (`ci.yml`, active) and "Copilot" (GitHub-managed dynamic; the run listing returns 1 run, from 2026-07-12, none in window).

Triggers of Admin CI:
- `push:` branches master and chore/desloppify-audit only.
- `pull_request:` no filters (every base branch and head).
- No workflow_dispatch. Concurrency group per ref (`admin-ci-<workflow>-<ref>`), cancel-in-progress true.

Measured, 14 days: 16 runs; push 4 (all success, all master merges), pull_request 12 (all success). Job "Lint, typecheck, test, and build": 17.6 min total, mean 1.1 min per run.

Duplicates: none measured. No SHA in the window had both a pull_request and a push run. Config risk (inferred): the only branch that would duplicate is chore/desloppify-audit, if it has an open PR. None existed in the window.

Last 16 runs (newest first):

| Run | Created (UTC) | Event | Branch | SHA | Conclusion | Title |
|---|---|---|---|---|---|---|
| 38756809624 | 10-15 15:02 | push | master | bbabc713 | success | docs(brand): standardize scoped kubus wordmark |
| 38720287987 | 10-15 10:26 | pull_request | docs/wordmark-typography-082 | cc535968 | success | Document the approved kubus ecosystem wordmark |
| 38654239221 | 10-14 23:27 | push | master | 66bea466 | success | Merge pull request #15 |
| 38653683389 | 10-14 23:22 | pull_request | fix/082-family-brand | 3b34b4a0 | success | Align admin wordmarks with kubus family |
| 38653302264 | 10-14 23:18 | pull_request | fix/082-family-brand | d635fa80 | success | Align admin wordmarks with kubus family |
| 38235752495 | 10-12 10:20 | push | master | 53a14e87 | success | Merge pull request #14 |
| 38233143210 | 10-12 09:56 | pull_request | fix/support-reply-keeps-edits | c00f4d95 | success | fix(support): reply no longer discards |
| 38232695719 | 10-12 09:52 | pull_request | fix/support-reply-keeps-edits | 776772b9 | success | fix(support): reply no longer discards |
| 38183230853 | 10-11 23:09 | pull_request | fix/support-reply-keeps-edits | 6d5ab6db | success | fix(support): reply no longer discards |
| 38182228714 | 10-11 22:54 | push | master | 438bde04 | success | Merge pull request #13 |
| 38046327130 | 10-10 10:50 | pull_request | fix/support-ticket-console-2026 | 71c2f48b | success | draft(0.8.2): support and bug tickets |
| 38045191434 | 10-10 10:31 | pull_request | fix/support-ticket-console-2026 | 6ab29511 | success | draft(0.8.2): support and bug tickets |
| 38043653264 | 10-10 10:04 | pull_request | fix/support-ticket-console-2026 | aba46dd3 | success | draft(0.8.2): support and bug tickets |
| 38006889696 | 10-09 23:57 | pull_request | fix/support-ticket-console-2026 | 583086f0 | success | draft(0.8.2): support and bug tickets |
| 38004797788 | 10-09 23:30 | pull_request | fix/support-ticket-console-2026 | 4aebc7bd | success | draft(0.8.2): support and bug tickets |
| 37850894706 | 10-08 22:02 | pull_request | fix/support-ticket-console-2026 | bf14b74d | success | draft(0.8.2): support and bug tickets |

## 6. Answers and cost drivers

1. Triggers: section 1. Duplicate execution of one workflow on push and pull_request for the same commit does not occur in art.kubus. It does occur in art.kubus.site (7 commits) and, cross-workflow, in art.kubus (7 commits, release PR and dev deploy both build the web bundle).
2. Classifier and jobs: section 2. Drafts run the full set; there is no draft gate. "PR validation required" accepts skipped jobs without checking why they were skipped.
3. Per-job and per-run minutes: section 3. Typical docs-only PR about 1.3 min; typical lib change about 50 to 60 min; full-set PR about 41 to 77 min.
4. Other art.kubus workflows: section 4.
5. art.kubus.site and admin.kubus: section 5.

Top three cost drivers (art.kubus, 14 days, job-minutes):
1. Platform compile jobs in pr-validation: Flutter 5,290, Android 4,871, iOS 2,475 (12,636 total, 84.6% of all art.kubus minutes in the window).
2. Cancelled and failed PR runs: 2,564 min in 103 cancelled runs (about 25 min each before cancellation; the cancellations are concurrency-group cancels, inferred to be superseded pushes) plus 1,356 min in 32 failed runs.
3. Full-set validation of release PRs (dev head to master base): 1,023 min across 18 runs (7.4% of pull_request-event minutes). Every master-base run is forced to full, even when only a few scripts changed (PR #293: 76.9 min for 3 scripts/qa files).

## 7. Inferred items (not measured)

- Draft PRs trigger pull_request runs with the same job set: measured on 8 current draft heads. The default-types reasoning is inferred.
- A draft-to-ready conversion does not start a run: inferred from the types list. Not tested.
- The 19 guardrails-only PR runs (no platform, docs or web job) are empty or non-matching diffs: inferred, not checked run by run.
- The 10 runs with Flutter, Android and iOS shown but no runtime are cancelled before start: inferred.
- Runs executed the workflow revision at their own head SHA: inferred from GitHub semantics; consistent with the iOS skip in older tag runs.
- Billing: not converted. macOS and Windows minutes are not comparable to ubuntu minutes; GitHub's per-OS billing rates were not looked up.
- Dependabot Updates minutes: GitHub-managed, billing not verified.
- Branch-as-PR mapping in section 3.4: inferred.

## 8. Commands used

Read-only. All with `-R kubus-project/<repo>`.

- `gh auth status`
- `MSYS_NO_PATHCONV=1 git -C G:/WorkingDATA/art.kubus/art.kubus show origin/dev:.github/workflows/<file>.yml` (8 files)
- `MSYS_NO_PATHCONV=1 git -C G:/WorkingDATA/art.kubus/art.kubus ls-tree --name-only origin/dev .github/workflows/ scripts/ci/`
- `git show origin/dev:scripts/ci/classify_changed_paths.mjs` and `validate_job_results.mjs` (saved to scratchpad; run with node on file lists only)
- `gh run list --workflow pr-validation.yml --limit 80 --json databaseId,event,headBranch,headSha,conclusion,createdAt,updatedAt,status,displayTitle`
- `gh run list --workflow pr-validation.yml --limit 1000 --created ">=2026-10-04" --json databaseId,event,headBranch,headSha,conclusion,createdAt,updatedAt,status,displayTitle,attempt`
- `gh run list --limit 1000 --created ">=2026-10-04" --json databaseId,workflowName,event,headBranch,headSha,conclusion,status,createdAt,updatedAt,attempt,displayTitle` (all workflows)
- `gh run view <id> --json databaseId,workflowName,attempt,event,headBranch,headSha,conclusion,status,createdAt,startedAt,updatedAt,displayTitle,jobs` (447 runs, art.kubus)
- `gh run view <id> --attempt 1 --json databaseId,workflowName,event,conclusion,createdAt,updatedAt,jobs` (re-run attempts)
- `gh pr list --state all --limit 300 --json number,title,headRefName,headRefOid,baseRefName,isDraft,state,createdAt,mergedAt,closedAt,changedFiles,additions,deletions`
- `gh pr view <n> --json number,title,isDraft,baseRefName,headRefName,files` (for 309, 302, 307, 269, 318, 308, 245, 175, 293, 278, 313, 320)
- `gh repo view kubus-project/art.kubus.site --json defaultBranchRef,visibility,isArchived` (and admin.kubus)
- `gh workflow list -R kubus-project/art.kubus.site --all`, `gh workflow list -R kubus-project/admin.kubus --all`
- `gh api repos/kubus-project/art.kubus.site/contents/.github/workflows/ci.yml?ref=master -H 'Accept: application/vnd.github.raw'`
- `gh api repos/kubus-project/admin.kubus/contents/.github/workflows/ci.yml?ref=master -H 'Accept: application/vnd.github.raw'`
- `gh api repos/kubus-project/art.kubus.site/branches --paginate`, `gh api repos/kubus-project/admin.kubus/branches --paginate`
- `gh run list -R kubus-project/art.kubus.site --limit 1000 --created ">=2026-10-04" --json databaseId,workflowName,event,headBranch,headSha,conclusion,status,createdAt,updatedAt,attempt,displayTitle` and the same for admin.kubus
- `gh run view <id> -R kubus-project/art.kubus.site --json ...jobs` (21 runs) and `-R kubus-project/admin.kubus` (16 runs)
- `gh run list -R kubus-project/admin.kubus --workflow Copilot --limit 100 --json databaseId,event,conclusion,createdAt,headBranch,updatedAt,displayTitle`
- Local only: the output file's directory was created with `mkdir -p`. No repository file was touched.
