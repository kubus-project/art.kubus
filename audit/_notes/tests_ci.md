# Tests & CI Audit (2026-01-29)

## Summary
- CI runs Flutter verification (analyze, test, web build) when Flutter-related paths change and runs backend lint/tests when backend changes are detected.
- Backend npm scripts define `lint` and `test` (with Jest coverage enabled).
- Test suites exist in both Flutter (`test/`) and backend (`backend/__tests__/`).
- Coverage gaps: Flutter CI does not collect coverage, and backend coverage is not published or enforced with thresholds.

## Findings

### AK-AUD-001 — Flutter CI verification is configured (analyze/test/build web)
**Evidence:**
- `.github/workflows/ci.yml` lines **99–106** (Flutter analyze, test, build web steps).

### AK-AUD-002 — Backend CI runs npm lint/tests and scripts are defined
**Evidence:**
- `backend/package.json` lines **6–10** (scripts: `test` = `jest --coverage`, `lint` = `eslint src/**/*.js`).
- `.github/workflows/ci.yml` lines **149–159** (CI runs `npm run lint` and `npm test`).

### AK-AUD-003 — Test suites exist in both Flutter and backend
**Evidence:**
- `test/auth/session_reauth_prompt_test.dart` lines **1–105** (Flutter widget tests).
- `backend/__tests__/authEmailLifecycle.test.js` lines **1–249** (Jest test suite).

### AK-AUD-004 — Coverage gaps (collection/publishing/enforcement)
**Details:**
- Flutter CI runs `flutter test` without `--coverage`, so no coverage is generated in CI.
- Backend Jest runs with `--coverage`, but CI does not publish artifacts or enforce thresholds; no `coverageThreshold` configuration is present in `backend/package.json`.

**Evidence:**
- `.github/workflows/ci.yml` lines **102–103** (Flutter test command lacks `--coverage`).
- `backend/package.json` lines **1–77** (no `jest` config / `coverageThreshold` entries).
- `.github/workflows/ci.yml` lines **154–159** (backend tests run but no coverage upload/publish step).

## Top P0/P1
- **P1:** CI does not collect Flutter coverage, and backend coverage is not enforced or published (see AK-AUD-004).
- **P0:** None observed.

## Files Reviewed
- `.github/workflows/ci.yml` (lines 1–164)
- `backend/package.json` (lines 1–77)
- `test/auth/session_reauth_prompt_test.dart` (lines 1–105)
- `backend/__tests__/authEmailLifecycle.test.js` (lines 1–249)
- `.github/workflows/deploy.yml` (lines 1–260+)
- `.github/workflows/pages.yml` (lines 1–47)
