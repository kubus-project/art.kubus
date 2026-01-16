# Phase 1 Wiring Map (A–F)

This document maps the current wiring for the six audit scopes (A–F): where each feature starts in UI, which providers/services it uses, and which backend endpoints it hits.

> Notes
> - “Scope” generally means `public` vs `private` data paths.
> - Feature flags are enforced via `AppConfig.isFeatureEnabled('<flag>')` and (where applicable) user settings via providers like `ConfigProvider`.

---

## A) Onboarding duplication + persona flow

### UI entry points

- App boot routing: `lib/core/app_initializer.dart` (`AppInitializer`)
  - Reads SharedPreferences keys including:
    - `completed_onboarding` (main gate)
    - `skipOnboardingForReturningUsers` (opt-out)
    - plus additional “welcome” keys (`PreferenceKeys.hasSeenWelcome`, `PreferenceKeys.isFirstLaunch`, `first_time`)
  - Routes to:
    - `lib/screens/onboarding/onboarding_screen.dart` (mobile layout)
    - `lib/screens/desktop/onboarding/desktop_onboarding_screen.dart` (desktop layout)
    - or `lib/main_app.dart` (`MainApp`) when onboarding is completed.

- Persona onboarding gate (runs *after* main routing):
  - Mobile: `lib/main_app.dart` wraps the scaffold in `UserPersonaOnboardingGate`
  - Desktop: `lib/screens/desktop/desktop_shell.dart` wraps the shell in `UserPersonaOnboardingGate`

- Persona UI: `lib/widgets/user_persona_onboarding_sheet.dart`
  - Writes persona via `ProfileProvider.setUserPersona(...)`
  - Performs persona-specific navigation (e.g. creator → artist studio, institution → institution hub)

### Providers / persistence

- `lib/providers/profile_provider.dart`
  - Persona persistence is **per wallet** in SharedPreferences (keyed by wallet)
  - Uses `needsPersonaOnboarding` and “seen” keys to decide whether to show the sheet.

### Root-cause notes (why this feels duplicated)

- There are **two distinct onboarding gates**:
  1) “Welcome / first run” onboarding (global preference key `completed_onboarding`)
  2) Persona onboarding (per-wallet persona + “seen” state)

This is intentional separation in code, but UX-wise it can look like duplicated onboarding if both gates trigger near first sign-in, or if wallet changes.

---

## B) Presence (smoothness + correctness)

### UI entry points / consumers

- Presence is displayed primarily through reusable UI widgets:
  - `lib/widgets/avatar_widget.dart`
  - `lib/widgets/user_activity_status_line.dart`

These typically call `PresenceProvider.prefetch([...])` and use `context.select(...)` to avoid large rebuilds.

### Provider wiring

- Provider: `lib/providers/presence_provider.dart` (`PresenceProvider`)
- Bound in `lib/main.dart` via `ChangeNotifierProxyProvider2<AppRefreshProvider, ProfileProvider, PresenceProvider>`:
  - `bindToRefresh(appRefreshProvider)`
  - `bindProfileProvider(profileProvider)`

### Key behavior

- Batch fetch: debounce 60ms, TTL 15s
- Auto refresh watched wallets every 10s
- Heartbeat every 30s for the signed-in user, **only if**:
  - `AppConfig.isFeatureEnabled('presence')` and
  - `ProfileProvider.preferences.showActivityStatus == true`

### Backend endpoints

Via `lib/services/presence_api.dart` → `BackendPresenceApi` → `lib/services/backend_api_service.dart`:

- `POST /api/presence/batch` (`BackendApiService.getPresenceBatch`)
- `POST /api/presence/ping` (`BackendApiService.pingPresence`)
- `POST /api/presence/visit` (`BackendApiService.recordPresenceVisit`)

### Root-cause notes (likely contributors to “choppy” presence)

- Frequent polling (10s) + short TTL (15s) means the UI will legitimately receive updates often.
- Multiple “watchers” can accumulate if many avatars are on-screen; batching helps but the watched set can still grow.

---

## C) Analytics (infinite loaders / zeros)

### UI entry points

- Artist analytics screen: `lib/screens/web3/artist/artist_analytics.dart`
  - Snapshot fetch: `StatsProvider.ensureSnapshot(...)`
  - Series fetch: `StatsProvider.ensureSeries(...)` (only when analytics is enabled)

### Provider wiring

- Provider: `lib/providers/stats_provider.dart` (`StatsProvider`)
- Bound in `lib/main.dart` via `ChangeNotifierProxyProvider2<AppRefreshProvider, ConfigProvider, StatsProvider>`:
  - `bindToRefresh(appRefreshProvider)`
  - `bindConfigProvider(configProvider)`

- Feature gating:
  - `StatsProvider.analyticsEnabled == AppConfig.isFeatureEnabled('analytics') && (ConfigProvider.enableAnalytics ?? true)`

### Backend endpoints

- `GET /api/stats/:entityType/:entityId` (`BackendApiService.getStatsSnapshot`)
  - supports query params: `metrics`, `scope`, `groupBy`
- `GET /api/stats/:entityType/:entityId/series` (`BackendApiService.getStatsSeries`)
  - supports query params: `metric`, `bucket`, `timeframe`, `from`, `to`, `scope`, `groupBy`

### Root-cause notes (where loaders/zeros can come from)

- **Two stats paths exist**:
  - `StatsProvider` (caching + TTL + error backoff)
  - `ProfileProvider._loadBackendStats(...)` (direct snapshot call; see scope E)

- The analytics UI commonly uses `scope: 'private'` for series; if auth is missing/expired the provider will store an error and the UI may show “no data” or retry loops depending on the widget.

---

## D) Desktop notifications parity

### UI entry points

- Desktop shell sidebar: `lib/screens/desktop/desktop_shell.dart`
  - Notification bell opens a panel (`_showNotificationsPanel`)

- Desktop community AR attachments currently shows a “mobile-only” CTA:
  - `lib/screens/desktop/community/desktop_community_screen.dart` contains an “Open mobile app” action that routes to `DownloadAppScreen`.

### Provider wiring

- Provider: `lib/providers/notification_provider.dart` (`NotificationProvider`)
  - Bound in `lib/main.dart` via `ChangeNotifierProxyProvider<AppRefreshProvider, NotificationProvider>`

- Recent activity aggregator:
  - `lib/providers/recent_activity_provider.dart` bound to `NotificationProvider`

### Backend endpoints

From `lib/services/backend_api_service.dart`:

- `GET /api/notifications` (`getNotifications`)
- `GET /api/notifications/unread-count` (`getUnreadNotificationCount`)
- `PUT /api/notifications/:id/read` (`markNotificationAsRead`)
- `PUT /api/notifications/read-all` (`markAllNotificationsAsRead`)
- `DELETE /api/notifications/:id` (`deleteNotification`)

### Root-cause notes

- The notification *data* layer exists for desktop; the remaining parity gaps appear to be **feature gating / UX routing** in desktop community flows (e.g., AR attachment UX), not the unread-count plumbing.

---

## E) Desktop home stats mismatch

### UI entry points

- Desktop home: `lib/screens/desktop/desktop_home_screen.dart`
  - Uses `StatsProvider.ensureSnapshot` for some metrics (often `scope: 'private'`)
  - Also uses `ProfileProvider` fields as fallbacks (e.g. discovered counts)

### Provider wiring

- `StatsProvider`: see scope C
- `ProfileProvider`: `lib/providers/profile_provider.dart`

### Backend endpoints (duplicate sources)

- `StatsProvider` → `StatsApiService` → `BackendApiService.getStatsSnapshot/getStatsSeries`
- `ProfileProvider._loadBackendStats(...)` calls `StatsApiService().fetchSnapshot(...)` directly with `scope: 'public'` and metrics like `collections`, `followers`, `following`, `posts`, `artworks`.

### Root-cause notes (why numbers diverge)

- Multiple widgets mix:
  - `StatsProvider` snapshots (with TTL/error backoff) and
  - `ProfileProvider` stored stats + direct fetch results

Differences in metric names, timing (TTL), and `scope` (public vs private) can produce visible mismatches.

---

## F) Marker management UX (create/edit/publish)

### UI entry points

- Manage markers (mobile):
  - `lib/screens/web3/artist/artist_studio_create_screen.dart` → `ManageMarkersScreen`
  - `lib/screens/web3/institution/institution_hub.dart` → `ManageMarkersScreen`

- Manage markers (desktop):
  - `lib/screens/desktop/web3/desktop_artist_studio_screen.dart` embeds `ManageMarkersScreen`
  - `lib/screens/desktop/web3/desktop_institution_hub_screen.dart` embeds `ManageMarkersScreen`

- Marker list + editor split view:
  - `lib/screens/map_markers/manage_markers_screen.dart`
  - `lib/screens/map_markers/marker_editor_view.dart`
  - `lib/screens/map_markers/marker_editor_screen.dart` (mobile navigation wrapper)

### Provider wiring

- Provider: `lib/providers/marker_management_provider.dart` (`MarkerManagementProvider`)
  - Created/bound in `lib/main.dart` via `ChangeNotifierProxyProvider2<ProfileProvider, WalletProvider, MarkerManagementProvider>`
  - Fetches “my markers” only when an auth token is present.

### Backend endpoints

From `lib/services/backend_api_service.dart`:

- `GET /api/art-markers/mine` (`getMyArtMarkers`)
- `POST /api/art-markers` (`createArtMarkerRecord`)
- `PUT /api/art-markers/:id` (`updateArtMarkerRecord`)
- `DELETE /api/art-markers/:id` (`deleteArtMarkerRecord`)

(Additional runtime endpoints exist for end-user interactions: view/interact.)

### Root-cause notes

- Marker management relies on auth token presence; if the token is missing/expired, the provider intentionally clears markers and shows no error.
- The editor UI is large and stateful; keeping it consistent across mobile/desktop relies on using the shared `MarkerEditorView`.
