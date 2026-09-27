# Backend deployment environment source

Operational guard recorded during Wave 4 (app PR, no backend change). It
describes *where* the production backend environment comes from; it contains
no values and must never contain any.

## Which files matched production

At the 2026-09-27 backend deployment (backend `master@4d5e3254`, Wave 3.6
PR #70), the running Oracle container was reproduced exactly only by the
environment files in the **app checkout's backend submodule working tree**:

```text
art.kubus/art.kubus/backend/.env.ha.shared
art.kubus/art.kubus/backend/.env.ha.oracle
```

Before that deploy, `docker compose ... config --hash backend` computed from
those files (with the deployed revision's `GIT_COMMIT` and the running
`DEPLOYED_AT`) matched the container label
`com.docker.compose.config-hash`.

## Copies that are *not* authoritative

The same-named files in the standalone backend checkout
(`art.kubus-backend/.env.ha.*`) have drifted from production. Known
differing areas: analytics allowed origins/sites, WAL archive limits, IPFS
garbage collection, snapshot settings and pin-reaper keys/settings. Do not
deploy with them and do not assume any repository-adjacent copy is current.

## Required before any future backend deployment

1. Identify the env files you intend to use.
2. From a clean worktree of the **currently deployed** SHA, run the compose
   `config --hash backend` with those files, that SHA as `GIT_COMMIT` and the
   container's `DEPLOYED_AT`.
3. Compare with the running container's `com.docker.compose.config-hash`
   label. Proceed only on an exact match; otherwise stop and reconcile.

## Secrets

`.env*` files are ignored by `.gitignore` in both repositories and must never
be committed, pasted into PRs, CI logs, screenshots or documentation.
Reconciling the drifted copies is separate operational work; it is not part
of any UI wave.
