---
name: backend-test
description: Run the art.kubus backend (Express/Postgres) Jest suite, including auth/wallet suites that must run serially. Use to run, narrow, or debug backend tests.
disable-model-invocation: true
---

# backend-test

Backend lives in `backend/` (Express + `pg` + Jest). Run from that directory.

## Common runs

Full suite with coverage (matches `npm test`):
```bash
cd backend && npm test
```

A single test file (fast iteration):
```bash
cd backend && npx jest __tests__/mediaProxyRoutes.test.js
```

By name:
```bash
cd backend && npx jest -t "binds wallet"
```

## Run serially when state collides

Auth, wallet, and identity suites share DB / account-link state and flake or
double-count when run in parallel (this is why the repo keeps separate
`backend-test-serial.log` / `backend-auth-rerun.log` artifacts). When a suite
touches auth, wallet binding, or `analytics_events`, force serial execution:
```bash
cd backend && npx jest --runInBand __tests__/<suite>.test.js
```
Use `--runInBand` for the whole suite if you see cross-test interference
(records from one test visible in another, dedupe/double-count assertions).

## Debugging a failure
1. Re-run the single file with `-t` to isolate the case.
2. If it passes alone but fails in the full run, it's an ordering/state issue —
   re-run with `--runInBand`.
3. Check whether it needs a clean DB or the migration set (e.g. analytics
   `dedupe_hash` / migration 073). Run `npm run migrate` against the test DB if
   schema is stale.
4. `npm run lint` (eslint) to rule out a lint/compile cause.
