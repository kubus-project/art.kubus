# COMPLETE AUDIT — art.kubus + backend

## Audit Progress (2026-01-29)
- **Phase 0 baselines**: `flutter analyze`, `flutter test`, `flutter build web`, `npm run lint`, `npm test` ✅
- **Active remediation**: AK-AUD follow-ups in `audit/_notes/*.md` (see per-note status updates as they are resolved).
- **Master status**: F-01..F-13 remain resolved; AK-AUD items will be reflected in note files + Verification Runs below.

## Table of Contents
- [Scope Map](#scope-map)
- [Audit Methodology](#audit-methodology)
- [Findings (Master Table)](#findings-master-table)
- [Findings by Repo](#findings-by-repo)
  - [Frontend (art.kubus)](#frontend-artkubus)
  - [Backend (art.kubus-backend)](#backend-artkubus-backend)
- [Cross-Cutting Root Causes](#cross-cutting-root-causes)
- [Verification Runs](#verification-runs)
- [Change Log](#change-log)

## Scope Map

### Repos in scope
- **Frontend**: `g:\WorkingDATA\art.kubus\art.kubus` (Flutter/Dart)
- **Backend**: `g:\WorkingDATA\art.kubus\art.kubus\backend` (Node.js/Express + Postgres/PostGIS + Redis)

### Frontend entry points and structure
- Entry: `lib/main.dart`, `lib/main_app.dart`
- Boot/initialization: `lib/core/app_initializer.dart`, `lib/services/app_bootstrap_service.dart`
- Navigation/routing: `lib/core/app_navigator.dart`, `lib/screens/**`, `lib/screens/desktop/**`
- State management: `lib/providers/**` (ChangeNotifier + ProxyProviders)
- Services: `lib/services/**`
- Widgets: `lib/widgets/**`
- Utilities: `lib/utils/**`

### Backend entry points and structure
- Entry: `backend/src/server.js`
- Routing: `backend/src/routes/**`
- Middleware: `backend/src/middleware/**`
- Services: `backend/src/services/**`
- DB/migrations: `backend/src/db/**`, `backend/migrations/**`

### Command scripts (from docs + package.json)
- Frontend:
  - `flutter analyze`
  - `flutter test`
  - `flutter run --debug`
  - `flutter build web`
- Backend:
  - `npm test`
  - `npm run lint`
  - `npm run dev`

## Audit Methodology
- Static inspection of app + backend code.
- Focused review of auth/reauth, map, analytics/telemetry, security baseline, and performance/fetch duplication.
- Evidence recorded with file path + line anchors.

## Findings (Master Table)

| ID | Severity | Category | Repo | Title | Status |
|---|---|---|---|---|---|
| F-01 | High | Security | Backend | Messaging routes missing conversation membership enforcement | Resolved |
| F-02 | High | Security | Backend | Notifications creation lacks recipient ownership validation | Resolved |
| F-03 | High | Security | Backend | Achievements stats endpoints exposed without auth gate | Resolved |
| F-04 | Medium | Security | Backend | JWT secret fallback to dev value in production risk | Resolved |
| F-05 | Medium | Reliability | Backend | Web analytics ingest rejects valid payloads; allowlist + UUID gating drops events | Resolved |
| F-06 | Medium | Reliability | Backend | Art marker ownership checks yield 403s due to createdBy/wallet mismatch | Resolved |
| F-07 | Medium | Reliability | Frontend | Reauth/app-lock gate triggers before real login due to wallet-only local account | Resolved |
| F-08 | Medium | Reliability | Frontend | Web map can render blank: double-prefixed style assets + dev-only fallback | Resolved |
| F-09 | Low | Reliability | Frontend | Tutorial overlay does not block map gestures on web | Resolved |
| F-10 | Medium | Performance | Frontend | Overlapping timers and refresh loops cause extra network churn | Resolved |
| F-11 | Low | Architecture | Frontend | Duplicate marker fetch services (MapMarkerService vs ArtMarkerService) | Resolved |
| F-12 | Low | Architecture/Performance | Backend | Legacy vs public analytics split causes stale stats and redundant queries | Resolved |
| F-13 | Low | Tests | Backend | Web analytics route tests failing; coverage low and not enforced | Resolved |

## Findings by Repo

### Frontend (artkubus)

#### Security
- No critical frontend-only auth bypass observed in this pass; main authZ gaps are server-side (see backend security findings).

#### Reliability
- **F-07 — Reauth/app-lock before login**
  - **Evidence**: `lib/services/auth_gating_service.dart` (`hasLocalAccountSync` uses wallet/user_id); `lib/providers/security_gate_provider.dart` (`hasAppLock` uses `requirePin` OR `autoLockSeconds > 0`); `lib/services/settings_service.dart` default `autoLockSeconds` set to 5 minutes even when PIN disabled.
  - **Impact**: Users see reauth/app-lock prompts before sign-in; local wallet presence counts as “account”.
  - **Fix checklist**:
    - Gate “local account” on a valid session token or completed onboarding, not wallet alone.
    - Only enable `autoLockSeconds` if PIN/biometric is actually configured.
    - Ensure the reauth gate explicitly bypasses login/registration routes.
  - **Verify**: `test/auth_reprompt_login_test.dart` and a manual cold start with only wallet connected.

- **F-08 — Web map blank due to style URL handling**
  - **Evidence**: `lib/services/map_style_service.dart` (`_toWebAssetUrl` can double-prefix `assets/`); dev-only asset fallback; `lib/widgets/art_map_view.dart` ignores taps until `_styleInitialized`.
  - **Impact**: On web, map style fails to load or taps ignored until style init; blank map reports.
  - **Fix checklist**:
    - Normalize web asset URLs to avoid double `assets/` prefix.
    - Provide a production-safe fallback style URL (not debug-only).
    - Defer map tap wiring until style init, with explicit ready state.
  - **Verify**: open map on web build and confirm style load + tap selection.

- **F-09 — Tutorial overlay touch-through on web**
  - **Evidence**: `lib/screens/map_screen.dart` sets `_shouldBlockMapGestures` false on web; `lib/widgets/tutorial/interactive_tutorial_overlay.dart` uses `GestureDetector` (tap only) and does not absorb drags.
  - **Impact**: Map pans/zooms behind tutorial, causing inconsistent onboarding.
  - **Fix checklist**:
    - Use an absorbing pointer layer or `ModalBarrier` to block gestures during tutorial.
    - Align `_shouldBlockMapGestures` with tutorial visibility.
  - **Verify**: run web map tutorial and confirm no underlying map interaction.

#### Performance
- **F-10 — Overlapping timers and refresh loops**
  - **Evidence**: `lib/services/app_bootstrap_service.dart` warmup triggers many provider refreshes; `lib/providers/chat_provider.dart` polling every 5s; `lib/providers/notification_provider.dart` refresh every 45s plus monitor every 25s; `lib/providers/presence_provider.dart` refresh every 10s; `lib/screens/map_screen.dart` multiple 10s timers + streams.
  - **Impact**: Unnecessary network churn and battery/CPU usage, especially on mobile.
  - **Fix checklist**:
    - Consolidate refresh loops; debounce or pause on background/inactive views.
    - Prefer push/socket for chat/notifications where available.
    - Gate provider refreshes behind feature flags or view visibility.
  - **Verify**: profile network requests on idle home screen; compare before/after request rate.

#### Architecture
- **F-11 — Duplicate marker fetch services**
  - **Evidence**: `lib/services/map_marker_service.dart` and `lib/services/art_marker_service.dart` both call `BackendApiService.getNearbyArtMarkers` and maintain separate flows.
  - **Impact**: Duped logic increases maintenance and inconsistent caching.
  - **Fix checklist**:
    - Consolidate to a single service with shared caching and API contract.
    - Keep socket merge logic in one place to avoid divergence.
  - **Verify**: map and marker create flows still function; no duplicate fetch paths remain.

#### Tests
- `flutter analyze` passes and `flutter test` passes. Web build succeeds with wasm dry-run warnings from third-party packages (see Verification Runs).

### Backend (artkubus-backend)

#### Security
- **F-01 — Messaging routes missing membership enforcement**
  - **Evidence**: `backend/src/routes/messages.js` uses auth middleware but does not consistently gate GET/POST by conversation membership; member checks are not applied for read/attachments/members in several handlers.
  - **Impact**: Authenticated users can access or mutate conversations they don’t belong to.
  - **Fix checklist**:
    - Apply `ensureConversationMember` (or equivalent) across all conversation-scoped routes.
    - Validate `conversationId` ownership for reads and writes.
  - **Verify**: add/update tests for unauthorized access; ensure 403 for non-members.

- **F-02 — Notifications create lacks recipient validation**
  - **Evidence**: `backend/src/routes/notifications.js` allows creation via auth without verifying recipient ownership or scope.
  - **Impact**: Any authenticated user can create notifications targeting other users.
  - **Fix checklist**:
    - Require sender/recipient constraints; block cross-user creation unless admin.
  - **Verify**: add route test for cross-user notification creation.

- **F-03 — Achievements stats endpoints public**
  - **Evidence**: `backend/src/routes/achievements.js` exposes user/stat endpoints without auth guard.
  - **Impact**: Public access to user progress and stats.
  - **Fix checklist**:
    - Gate endpoints with auth or sanitize to public-only aggregates.
  - **Verify**: unauthenticated request returns 401/403.

- **F-04 — JWT secret fallback to dev**
  - **Evidence**: `backend/src/middleware/auth.js` falls back to a default secret when env is unset.
  - **Impact**: Production misconfiguration risk; tokens can be forged if env missing.
  - **Fix checklist**:
    - Fail fast when `JWT_SECRET` missing in non-dev.
    - Enforce startup validation of required env vars.
  - **Verify**: boot fails with clear error when secret missing in production config.

#### Reliability
- **F-05 — Web analytics ingestion rejects valid payloads**
  - **Evidence**: `backend/src/routes/analytics.js` validates allowlisted `site` and enforces UUIDs/session IDs; current tests expect 204 but receive 400 (`__tests__/webAnalyticsRoutes.test.js`, `__tests__/webAnalyticsWwwNormalization.test.js`).
  - **Impact**: Web telemetry dropped, stats stale, dashboards inconsistent.
  - **Fix checklist**:
    - Align allowlist normalization (www vs apex) and payload parsing for `text/plain`.
    - Keep privacy fail-closed behavior but return 204 for ignored events.
  - **Verify**: re-run failing tests and confirm 204 responses.

- **F-06 — Marker 403s due to owner mismatch**
  - **Evidence**: `backend/src/routes/artMarkers.js` uses `createdBy`/wallet mapping; inconsistencies between stored `createdBy` and authenticated wallet cause 403 even for owners.
  - **Impact**: Users can’t edit/delete their markers or see expected results.
  - **Fix checklist**:
    - Normalize ownership mapping; treat legacy `createdBy` values consistently with wallet IDs.
    - Provide migration or alias resolution for old IDs.
  - **Verify**: edit/delete marker with legacy owner ID succeeds.

#### Performance
- **F-12 — Analytics query fan-out and legacy split**
  - **Evidence**: `backend/src/services/statsService.js` aggregates from legacy tables; unified analytics tables exist elsewhere (`webAnalyticsService.js`).
  - **Impact**: redundant queries and inconsistent stats depending on pipeline used.
  - **Fix checklist**:
    - Consolidate reads to unified table or ensure writes mirror legacy tables.
  - **Verify**: stats endpoints match analytics ingest source of truth.

#### Architecture
- Legacy vs public analytics split is a systemic architecture issue that causes duplicated logic and stale dashboards (see F-12).

#### Tests
- `npm run lint` completed without reported errors. `npm test` passes. Coverage remains low (~31% overall) and not enforced.

## Cross-Cutting Root Causes
- **Auth/reauth prompt before login**: `hasLocalAccountSync` treats wallet presence as a local account; `SecurityGateProvider` treats `autoLockSeconds > 0` as an active lock even when PIN is disabled. This results in reauth/lock prompts before real login flows.
- **Map blank + touch-through**: web asset URL normalization can double-prefix `assets/`, and map fallback styles are debug-only. Additionally, tutorial overlays do not absorb gestures on web, letting the map pan/zoom under the overlay.
- **Telemetry not updating**: analytics ingest fail-closed validation rejects valid payloads (www normalization, `text/plain` JSON, and non-UUID IDs), while stats read paths rely on legacy tables.
- **Marker 403s**: ownership checks compare `createdBy` vs wallet IDs inconsistently across legacy records.

## Verification Runs
- **Frontend** (Windows):
  - `flutter analyze` ✅ No issues found.
  - `flutter test` ✅ All tests passed.
  - `flutter build web` ✅ Build succeeded; wasm dry-run warnings from third-party packages (`flutter_secure_storage_web`, `geolocator_web`, `image` lints).
- **Backend** (Windows):
  - `npm run lint` ✅ No lint errors reported.
  - `npm test` ✅ 41 suites, 174 tests passed.
  - Console warnings during tests from email provider mocks are expected (invalid API key/email logs).

## Change Log
- Replaced all audit placeholders with findings, evidence, and root causes.
- Added verification results from frontend and backend test runs.
- Closed F-01..F-13 with backend authZ/secret hardening, analytics mirroring, polling reductions, and refreshed test evidence.
