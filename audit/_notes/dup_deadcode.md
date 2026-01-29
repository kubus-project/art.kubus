# Duplication & Dead-Code Audit

## Summary
- Scope: Flutter app (`lib/`) + backend (`backend/src/`).
- Focus: duplicated logic, unreachable branches, inconsistent patterns.
- Result: duplicated logic found in backend routes and frontend marker fetching; logging pattern inconsistencies in content services. No clear unreachable branches found via targeted scans for `return`-after-`return`, `throw`-after-`return`, or `if (false)` in core code paths.

## Findings

### AK-AUD-001 — Duplicate subscription handler logic (backend)
- **Type:** Duplicate code (route handlers)
- **Severity:** P1
- **Evidence:** `backend/src/routes/subscriptions.js` lines **49–113** (waitlist) and **116–180** (newsletter)
- **Details:** The validation chain, normalization, DB upsert, EmailOctopus subscribe, and response payload are nearly identical between `/waitlist` and `/newsletter`. This duplication increases risk of inconsistent behavior and makes changes error-prone.
- **Status:** Fixed — consolidated into `subscribeValidators` + `createSubscribeHandler` and reused by both routes.
- **Evidence:** `backend/src/routes/subscriptions.js` (`subscribeValidators`, `createSubscribeHandler`, `/waitlist` and `/newsletter` use the shared handler).

### AK-AUD-002 — Duplicate marker-fetch + cache + rate-limit logic (frontend)
- **Type:** Duplicate code (service methods)
- **Severity:** P2
- **Evidence:** `lib/services/map_marker_service.dart` lines **205–273** (`loadMarkers`) and **276–344** (`loadMarkersInBounds`)
- **Details:** Both methods repeat the same rate-limit short-circuit, cache lookup, `_dedupeInFlight` usage, and error/fallback logic with only the API call and cache key differing.
- **Status:** Fixed — extracted `_loadMarkersInternal` and wired both methods through it.
- **Evidence:** `lib/services/map_marker_service.dart` (`_loadMarkersInternal`, `loadMarkers`, `loadMarkersInBounds`).

### AK-AUD-003 — Logging discipline inconsistent in content services
- **Type:** Inconsistent pattern (logging)
- **Severity:** P2
- **Evidence:**
  - `lib/services/art_content_service.dart` lines **40–47**, **64** (`debugPrint` unguarded)
  - `lib/services/ar_content_service.dart` lines **30**, **58**, **104**, **123**, **129**, **138**, **151–152**, **186**, **190–195**, **266** (`debugPrint` unguarded)
- **Details:** Logs are emitted without `if (kDebugMode)` guards, which conflicts with the project logging discipline. This may cause noisy logs in production.
- **Status:** Fixed — all debug prints in these services are now guarded with `if (kDebugMode)`.
- **Evidence:** `lib/services/art_content_service.dart`, `lib/services/ar_content_service.dart` (debug logging guarded).

## Top P0/P1
- **P1:** AK-AUD-001 — Duplicate subscription handler logic in `backend/src/routes/subscriptions.js`.

## Files Reviewed
- `lib/services/telemetry_service.dart`
- `lib/services/telemetry/telemetry_service.dart`
- `lib/services/map_marker_service.dart`
- `lib/services/art_marker_service.dart`
- `lib/services/art_content_service.dart`
- `lib/services/ar_content_service.dart`
- `backend/src/routes/subscriptions.js`