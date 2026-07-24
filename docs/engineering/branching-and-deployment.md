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

### cPanel Basic Auth across atomic releases

cPanel Directory Privacy writes its Basic Auth directives into the active document root's `.htaccess`. The atomic deployment makes that document root a symlink to an immutable release and changes the symlink target during promotion. Directory Privacy therefore protected the old target, but the newly built target initially contained only the application's routing rules. The post-promotion smoke correctly detected the resulting unauthenticated `200` and rolled back.

Development now has a remote, pre-promotion host-policy phase. After the uploaded archive and its original CI checksums are verified, the remote release script:

1. reads the existing cPanel-managed `AuthUserFile` directive from the currently protected release;
2. accepts it only when it resolves within the authenticated account's cPanel-managed password area and names a readable, non-empty credential file;
3. prepends one deterministic development auth block to a fresh copy of the application's complete `.htaccess`;
4. verifies that the application rules are byte-for-byte identical to the rules covered by the original artifact manifest;
5. records a separate host-policy digest outside the document root, without recording the resolved path; and
6. permits the live symlink switch only after those checks pass.

The original `SHA256SUMS` is never regenerated after the host-local overlay. A retry reuses and verifies an existing immutable SHA directory without duplicating the auth block; it never deletes or replaces that directory. The freshly uploaded artifact manifest must exactly match the existing release's original manifest, and a freshly prepared overlay must exactly match the existing release's host policy, or preparation fails closed. If the current cPanel policy, password file, application `.htaccess`, overlay structure, environment boundary, or separate policy record cannot be verified, preparation fails before promotion and the current live release stays selected.

The htpasswd path remains server-local. Do not add it, an account username, or an account home directory to a GitHub variable, secret description, workflow, artifact, log, screenshot, or pull request. `DEV_HTPASSWD_FILE` is not part of the deployment contract. Normal cPanel access is sufficient; no WHM, reseller package, or vhost edit is required.

Production uses a separate preparation branch that rejects the development markers and all `AuthType`, `AuthUserFile`, and `Require valid-user` directives. It never derives or installs the cPanel policy.

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

To verify that the Imunify360 exception bypasses only the WAF rule and never Basic Auth, prepare a private curl netrc file containing the development credentials and, separately, a mode-`0600` curl config containing the `X-Deploy-Smoke` header. Do not print either file or pass secret values directly in a URL. Run these four probes:

```bash
curl --head https://dev.kubus.site/app
curl --head --netrc-file "$DEV_NETRC" https://dev.kubus.site/app
curl --head --config "$DEV_SMOKE_HEADER_CONFIG" https://dev.kubus.site/app
curl --head --config "$DEV_SMOKE_HEADER_CONFIG" --netrc-file "$DEV_NETRC" https://dev.kubus.site/app
```

The results must be `401`, `200`, `401`, and `200`, respectively; both `401` responses must include `WWW-Authenticate`. The authenticated responses must retain staging `X-Robots-Tag`, and `kubus-web-revision.txt` must equal the deployed `dev` SHA.

Run the workflow manually from the `dev` ref with:

```bash
gh workflow run deploy-development.yml --ref dev -f bootstrap_web_root=false
```

The bootstrap input remains `false` for ordinary retries. Set it only for the separately approved one-time migration of a physical document root to the atomic symlink layout.

## Production deployment

`release-production.yml` runs only for the exact `master` head or a manual dispatch selected on `master`. It builds a fresh immutable artifact for that exact commit, validates checksums and deployment scripts locally, then enters `production-web`. Repository settings should require an approval before the privileged job continues.

Production retains the existing security and recovery contract: immutable SHA directories, verified SSH fingerprint, safe absolute paths, archive and per-file SHA-256 verification, symlink-based atomic promotion, exact revision verification, app/routing/canonical/SEO/takeover smoke, rollback after any post-promotion critical failure, and cleanup only after success. Production deployment is never authorized merely because a workflow or PR exists.

### Post-promotion smoke and the origin WAF (HTTP 415)

The production origin (`app.kubus.site`) is a LiteSpeed host fronted by an Imunify360-style reverse-proxy bot filter. That filter greylists datacenter IP ranges and answers them with `HTTP 415`, while an ordinary client IP receives the correct `308 -> /en` canonicalization (verified: the `415` appears only from the GitHub-hosted runner and even a wrong `X-Deploy-Smoke` header from a normal IP still returns `308`, so the block is keyed on IP reputation, not content). The post-promotion smoke runs on a GitHub-hosted runner, so without an exception it receives `415`, fails the `root canonicalization` assertion, and rolls back a good release.

Every production smoke client already sends `X-Deploy-Smoke: <SMOKE_BYPASS_TOKEN>` scoped to the deployment origin, and `release-production.yml` forwards the environment secret. The remaining piece is a **host-side** rule that recognises the header. It cannot be an `.htaccess` directive: the reverse-proxy filter decides before LiteSpeed reads `.htaccess`, so a blocked request never reaches Apache/LiteSpeed rewrite or header processing. The setup and verification runbook is [`production-waf-smoke-exception.md`](production-waf-smoke-exception.md).

On shared cPanel hosting (no WHM/root), the recommended path is instead `USE_SSH_SMOKE_EGRESS=true`, which routes the whole smoke through a verified SSH SOCKS tunnel so it leaves from the host's own trusted IP and never meets the greylist. It needs no host-admin change and keeps GitHub-hosted runners. The alternatives are a WHM/root WAF header exception or a trusted-IP runner; all three are documented in the runbook.

Until the host rule exists, the smoke **fails closed** with a token-safe diagnosis that names the exact mode instead of an opaque `got 415`: missing/unforwarded token, host rule not installed (header ignored, still `415`), transient WAF state, or an ordinary application/routing/SEO failure. A `415` is never converted into a pass. The shared classifier is `scripts/deploy/waf_smoke_diagnostics.sh`; the read-only verifier is `scripts/deploy/waf_smoke_probe.sh`. Neither ever prints the token.

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

Optional per-environment secret `SMOKE_BYPASS_TOKEN`: when the origin host's WAF/bot filter blocks the CI runner's IP (e.g. LiteSpeed/Imunify360 returning `415`), set this secret and configure the host to skip that filter only for requests carrying `X-Deploy-Smoke: <token>`. The post-deploy smoke sends that header on every request (curl, `fetch`, and Playwright), scoped to the deployment origin so third-party hosts never receive it, while keeping Basic Auth and all other assertions intact. Leave it unset when the runner reaches the host directly (e.g. a self-hosted or trusted-IP runner). The host-side rule is **not** an `.htaccess` change; see [`production-waf-smoke-exception.md`](production-waf-smoke-exception.md) for the exact root/WHM setup, the trusted-runner fallback, and the read-only verification probe. The token value must never appear in a repository variable, source file, artifact, log, screenshot, or PR text.

Optional per-environment variable `USE_SSH_SMOKE_EGRESS`: set to `true` to route the post-deploy smoke through a verified SSH SOCKS tunnel to the deployment host, so it egresses from the host's own trusted IP instead of the runner's greylisted datacenter IP. This needs no host-admin change (only that the deploy user may open an SSH tunnel, i.e. `AllowTcpForwarding`), keeps GitHub-hosted runners, and is the recommended path on cPanel-only shared hosting where a WHM/root WAF exception is not available. The tunnel is verified against `SFTP_HOST_FINGERPRINT` and fails closed if forwarding is refused; the smoke suite runs unchanged through it. See [`production-waf-smoke-exception.md`](production-waf-smoke-exception.md).

No htpasswd location is configured in GitHub. The development remote script derives it from cPanel's current server-local Directory Privacy policy and never emits it.

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

- No deployment run: first verify that the event was a push to `dev` or a manual dispatch on `dev`. Opening or closing an unmerged pull request is not a deployment trigger.
- Waiting for `development-web`: the deploy job has reached a GitHub Environment approval gate; no privileged deployment step has started until approval is granted.
- Failed build: inspect the reusable artifact job. No remote promotion occurred.
- Stale staging run: the latest-head guard exits before remote mutation; allow the newer serialized run to continue.
- Failed preparation or promotion: inspect the named host-policy/checksum or atomic-promotion step. A host-policy failure occurs before the live symlink changes.
- Failed post-promotion smoke with successful rollback: the candidate was selected, a runtime assertion failed, and the rollback step restored the prior symlink. Treat the workflow as failed even though rollback succeeded.
- Failed PR validation: reproduce the failing job; do not bypass it.
- Upload/checksum failure: no promotion occurred; remove only the SHA-specific incoming directory and retry.
- Post-promotion smoke failure: run the automated rollback, verify the prior revision, and preserve diagnostics.
- Production smoke `root canonicalization ... got 415`: the origin WAF is blocking the runner, not an application regression. Read the printed WAF diagnosis to tell apart a missing/unforwarded `SMOKE_BYPASS_TOKEN`, a host rule that is not installed (bypass-header request still `415`), a transient WAF state, or an ordinary app failure. Fix per [`production-waf-smoke-exception.md`](production-waf-smoke-exception.md); confirm with `scripts/deploy/waf_smoke_probe.sh` before re-releasing. The rollback already restored the prior release, so production stayed healthy.
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
