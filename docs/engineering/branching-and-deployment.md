# Branching, CI, and deployment

This document is the canonical engineering contract for the `kubus-project/art.kubus` repository. When another instruction disagrees with it, stop and reconcile the documentation before changing code or repository settings.

## Branch roles

`master` is production-only. `dev` is the integration branch.

| Branch | Purpose | Accepted pull requests | Deployment |
| --- | --- | --- | --- |
| `dev` | Protected integration branch | Ordinary topic branches | Automatic web staging to `development-web` / `https://dev.kubus.site` |
| `master` | Protected production release branch | `dev` release PRs and `hotfix/*` emergency PRs only | Protected web production to `production-web` / `https://app.kubus.site` |

Direct development and direct commits on both long-lived branches are forbidden. Ordinary branches use `feature/`, `fix/`, `refactor/`, `ci/`, `docs/`, or `chore/`. Emergency branches use `hotfix/`; coordinated release preparation may use `release/` when needed.

## Preflight and worktrees

Before editing:

```bash
git status
git branch --show-current
git fetch origin
```

Stop if the active branch is `dev` or `master`. Create a topic branch and preferably a dedicated worktree from the current integration head:

```bash
git fetch origin
git worktree add ../art.kubus-my-change -b fix/my-change origin/dev
git -C ../art.kubus-my-change merge-base --is-ancestor origin/dev HEAD
```

The ancestry command is a starting-state check, not a permanent branch rule. After the branch gains commits, confirm that `git merge-base HEAD origin/dev` resolves and report how far the branch has diverged with `git rev-list --left-right --count origin/dev...HEAD`.

## Feature and release flows

Ordinary work follows:

```text
origin/dev -> topic branch -> pull request to dev -> staging deployment
```

Production releases follow:

```text
dev -> release-candidate pull request -> merge commit on master -> protected production deployment
```

Use a merge commit for `dev -> master`. Squashing a long-lived branch release makes `dev` and `master` histories incompatible and creates misleading future release diffs. Ordinary topic PRs into `dev` may be squash-merged.

Every `dev -> master` release must be reconciled back into `dev` immediately after it merges — this is not optional and is the mirror image of the hotfix rule below. The release merge commit created on `master` is not an ancestor of `dev`, so until it is reconciled `master` diverges: it carries the release merge (and anything merged directly to `master`) as commits that are not on `dev`. See [Post-release reconciliation](#post-release-reconciliation).

Emergency production fixes follow:

```text
master -> hotfix/specific-name -> pull request to master -> production
                                           |
                                           +-> reconcile into dev
```

After a hotfix reaches `master`, merge or cherry-pick it into `dev` promptly and record the reconciliation PR. Agents do not merge PRs without explicit authorization.

## Post-release reconciliation

A successful `dev -> master` release (or any commit that lands on `master`, such as a hotfix) leaves `master` ahead of `dev` by at least the release merge commit. Ordinary development must not resume on `dev` until that ancestry is reconciled back, or the branches drift apart and the next release diff becomes misleading.

The authoritative divergence signal is:

```bash
git fetch --prune origin
git rev-list --left-right --cherry-pick --count origin/master...origin/dev
# output: "<commits only on master>\t<commits only on dev>"
```

`--cherry-pick` omits patch-equivalent commits, so a hotfix that was reconciled into `dev` by cherry-pick (a new SHA with the same change) does not count and a genuine unreconciled release merge still does. A nonzero first number ("commits only on `master`") means reconciliation is required. Treat it as a release blocker for further `dev` work.

Reconcile with exactly one of these non-rewriting actions, then open a PR to `dev`:

- merge the resulting `master` release merge commit back into `dev`:

  ```bash
  git switch --create chore/sync-master-into-dev-<date> origin/dev
  git merge --no-ff origin/master   # ancestry-only when master carries no unique content
  ```

- or an equivalent non-rewriting ancestry reconciliation PR.

Rules:

- Use a merge commit. Never squash a reconciliation and never rebase a protected branch — either would drop the `master` parent link and leave the divergence open.
- Never "fix" the count by changing the default branch, force-updating a ref, or resetting `dev`/`master`.
- Inspect merge conflicts semantically: preserve the newer validated `dev` architecture and any genuine production-only fix from `master`.

Enforcement:

- `npm run verify:branch-reconciliation` runs `scripts/ci/check_branch_reconciliation.mjs`, which fails when `origin/master` has commits not yet reconciled into `origin/dev`. Override the compared refs with `RECONCILE_BASE_REF` / `RECONCILE_HEAD_REF`.
- The weekly `scheduled-quality.yml` **Release ancestry reconciliation guard** job runs this check so unreconciled divergence surfaces automatically.
- The parsing/verdict logic is unit-tested in `scripts/ci/branch_reconciliation.test.mjs` (part of `npm run verify:ci`).

## CI tiers

`pr-validation.yml` is the only ordinary pull-request workflow. It classifies changed paths into `full`, `frontend`, `web`, `backend`, `android`, `ios`, `docs`, `versioning`, `ci`, `deployment`, and `agents`.

- PRs to `dev` run affected guardrails, Flutter/Node tests, web smoke, routing, platform compilation, backend compatibility, and documentation checks.
- PRs to `master` are release candidates. Only same-repository `dev` and `hotfix/*` heads are accepted, and the complete release validation tier runs.
- `PR validation required` always runs and accepts only `success` or legitimate `skipped` results from every declared dependency.
- PR jobs never reference deployment, Basic Auth, or mobile-signing secrets. The read-only backend checkout key is used only by the backend compatibility boundary, never by deployment jobs or fork PRs.
- Weekly/manual `scheduled-quality.yml` owns expensive browser, dependency, platform, migration, architecture, and documentation checks.

CI failures must be investigated. Do not bypass a required check, convert failure to success, or weaken validation to make a branch mergeable.

## Staging deployment

`deploy-development.yml` runs only for the exact `dev` head or a manual dispatch selected on `dev`. It builds web from that SHA, adds `kubus-web-revision.txt`, creates per-file checksums, applies staging-only noindex/robots policy, validates locally, and uploads a versioned release. Immediately before any remote change it checks the current remote `dev` SHA; an obsolete queued deployment exits successfully without promotion.

The privileged job uses only the `development-web` environment. Promotion is serialized by `deploy-development` with cancellation disabled. An unauthenticated smoke requires the configured protected response and authentication challenge. Authenticated smoke checks `/app`, localized routes, the revision, `X-Robots-Tag`, and the deny-all `robots.txt`. If smoke fails after promotion, the previous symlink is restored automatically.

Staging must emit:

```text
X-Robots-Tag: noindex, nofollow, noarchive
```

and:

```text
User-agent: *
Disallow: /
```

Staging pages must not name `dev.kubus.site` as a production canonical or publish a staging sitemap.

## Production deployment

`release-production.yml` runs only for the exact `master` head or a manual dispatch selected on `master`. It builds a fresh immutable artifact for that exact commit, validates checksums and deployment scripts locally, then enters `production-web`. Repository settings should require an approval before the privileged job continues.

Production retains the existing security and recovery contract: immutable SHA directories, verified SSH fingerprint, safe absolute paths, archive and per-file SHA-256 verification, symlink-based atomic promotion, exact revision verification, app/routing/canonical/SEO/takeover smoke, rollback after any post-promotion critical failure, and cleanup only after success. Production deployment is never authorized merely because a workflow or PR exists.

## Mobile releases

`mobile-release.yml` is independent from web deployment. A `v*` tag or explicit manual run resolves a commit already contained by `master`, builds and signs Android APK/AAB in `android-release`, optionally signs an IPA in `ios-release`, verifies checksums and signatures, and publishes GitHub Release metadata only when the workflow is explicitly in publishing mode. Pull requests never receive signing material.

## Environments and configuration

Required environments:

- `development-web`, restricted to `dev`
- `production-web`, restricted to `master` and protected by explicit approval
- `android-release`, restricted to release tags/manual trusted refs
- `ios-release`, restricted to release tags/manual trusted refs

Both web environments define these variables with environment-specific values:

- `SFTP_PORT`
- `WEB_SERVER_DIR`
- `WEB_RELEASES_DIR`
- `WEB_SMOKE_URL`
- `ENVIRONMENT_NAME`
- `EXPECTED_DEPLOYMENT_HOST`

Both web environments define separate values for these secrets:

- `SFTP_SERVER`
- `SFTP_USERNAME`
- `SFTP_PRIVATE_KEY`
- `SFTP_PRIVATE_KEY_PASSPHRASE`
- `SFTP_HOST_FINGERPRINT`

`development-web` additionally defines `HTTP_BASIC_USERNAME` and `HTTP_BASIC_PASSWORD`. Never copy production credentials blindly, place secret values in repository variables, or include credentials in URLs, logs, artifacts, screenshots, or PR descriptions.

The current repository-scoped deployment secrets must be copied by a human into `production-web`, independently provisioned for `development-web`, and then removed from repository scope. Until that move is complete, environment separation is not cryptographically complete and staging deployment must remain disabled.

## Backend coordination

The parent repository uses `backend` as its sole canonical backend gitlink. CI rejects duplicate backend gitlinks and verifies the canonical private repository URL and immutable commit shape. Cross-repository branch reachability is not enforced in the main PR workflow because the backend is private and GitHub's repository token cannot deterministically inspect it without widening permissions.

The backend follow-up migration must create backend `dev` from verified backend `master`, add the same topic/release/hotfix policy, protect both branches, and provide a read-only deterministic provenance mechanism. After that migration, parent `dev` gitlinks must point to commits reachable from backend `dev`; parent `master` gitlinks must point to commits reachable from backend `master`.

### Related repository migration ledger

Inspection found that each related repository still defaults to `master` and
has no `dev` branch. None is required for the main repository's workflow to
build or fail closed, so each migration belongs in its own reviewed PR:

- `kubus-project/art.kubus-backend`: create `dev` from verified `master`, split
  trusted integration/release CI, protect both branches, then enforce parent
  gitlink reachability from backend `dev` or `master` in trusted CI.
- `kubus-project/art.kubus.site`: keep public publishing on `master`; introduce
  a separate non-production environment before enabling automatic deploys from
  its future `dev` branch.
- `kubus-project/kubus.site`: keep the public corporate site on `master`; move
  ordinary site PRs to a protected `dev` branch and add preview/staging without
  reusing production hosting credentials.
- `kubus-project/admin.kubus`: create a protected `dev` branch and isolated
  admin staging environment before moving ordinary PRs; production admin
  credentials must remain restricted to `master`.
- `kubus-project/kubus-node`: create a protected `dev` branch and non-production
  node/runtime environment; release only reviewed `dev` commits through
  `master`, with hotfix reconciliation back to `dev`.

Do not change any related repository's default branch until its own `dev`
workflow, staging target, PR retargeting, protections, and secret boundaries
have been validated.

## Branch protection expectations

Protect `dev` with required pull requests, resolved conversations, deletion/force-push protection, and the `PR validation required` status check. Squash merge is appropriate for ordinary PRs. A single-maintainer repository need not require another person's approval.

Protect `master` with required pull requests, resolved conversations, deletion/force-push protection, the same stable release-candidate aggregate check, and successful staging deployment where GitHub supports deployment gates. Workflow provenance rejects every source except same-repository `dev` and `hotfix/*`. Release PRs use merge commits.

Administrative bypass is for emergencies only. Default-branch changes wait until staging has been validated, open PRs have been safely retargeted, the production workflow no longer depends on `workflow_run`, and protections are active.

## Failure recovery

- Failed PR validation: reproduce the failing job; do not bypass it.
- Stale staging run: the latest-head guard exits before remote mutation; allow the newer serialized run to continue.
- Upload/checksum failure: no promotion occurred; remove only the SHA-specific incoming directory and retry.
- Post-promotion smoke failure: run the automated rollback, verify the prior revision, and preserve diagnostics.
- Production failure before environment approval: no production mutation occurred.
- Hotfix release: reconcile the exact fix into `dev` before ordinary development proceeds.
- Lost or rotated credentials: stop deployment, rotate through environment settings, verify the host fingerprint out of band, and never commit replacement material.

## First-release migration procedure

1. Verify `master`, create `dev` at that exact commit, and create the migration topic branch from `origin/dev`.
2. Retarget ordinary open PRs only after confirming their old base equals or is contained by `dev` and their diff does not expand.
3. Merge the workflow/governance PR into `dev` only after local and PR validation pass.
4. Configure `development-web` with independently provisioned staging credentials, paths, host fingerprint, Basic Auth, and branch restriction.
5. Run the first staging deployment; verify SSH/SCP, symlinks, atomic rename, remote SHA-256, Basic Auth, noindex, exact revision, smoke, and a safe rollback drill.
6. Move production deployment values from repository scope into `production-web`, add the `master` restriction and approval gate, and validate the workflow locally without dispatching it.
7. Activate `dev` and `master` rulesets with the stable aggregate check. Confirm the staging deployment gate if the plan supports it.
8. Retarget or close remaining ordinary `master` PRs. Do not merge them during governance migration unless separately authorized.
9. Change the default branch to `dev` only after steps 3-8 are complete.
10. Open `dev -> master` as the first release PR, require a merge commit, and obtain explicit production authorization before merging or approving deployment.

## Manual GitHub configuration checklist

In **Settings > Environments**, create/review the four environments above, add branch/tag policies, add production approval, and populate environment-scoped values without exposing them. In **Settings > Rules > Rulesets**, apply the protection expectations to `dev` and `master`; ensure no direct-push bypass exists. In **Settings > General > Pull Requests**, keep squash merge for topic PRs and merge commits for releases. After the first verified staging deployment and PR cleanup, use **Settings > General > Default branch** to switch from `master` to `dev`.
