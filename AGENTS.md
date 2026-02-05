# art.kubus - Agent Playbook (Codex Ready)

Model compatibility: GPT-5.x Codex-compliant agents.

Mission: keep the Flutter + Node.js stack stable while extending AR, Solana, OrbitDB, and storage features without breaking theme, feature flags, or fallbacks.

Preflight: always review **all** `AGENTS.md` files in this repo (root, `lib/**`, `backend/**`) before making changes.

---

## 1) Core Guardrails (Must Follow)

1. Feature flags everywhere
   - Flutter: never hardcode availability; use `AppConfig.isFeatureEnabled('flag')` and/or `ConfigProvider`.
   - Backend: respect env toggles (`USE_MOCK_DATA`, `ENABLE_DEBUG_ENDPOINTS`, `ORBITDB_SYNC_MODE`, etc.).
2. Theme discipline
   - UI colors come from `Theme.of(context).colorScheme.*` or `themeProvider.accentColor`.
   - No purple outside explicit AI/system indicators.
   - Do not store UI `Color` in domain models (see "UI Color Roles" below).
3. Provider-first state
   - Stateful logic lives in `ChangeNotifier` providers under `lib/providers/`.
   - Provider creation happens in `lib/main.dart`; initialization happens in `lib/core/app_initializer.dart` and `lib/services/app_bootstrap_service.dart`.
   - No provider initialization/binding in widget constructors or `initState` (bindings must be done via ProxyProviders or inside providers, and must be idempotent).
4. No placeholder code
   - No `TODO`, `FIXME`, stub returns, fake success flows, or dead UI actions.
5. Logging discipline
   - Do not ship noisy `debugPrint('DEBUG: ...')` or emoji logs.
   - If a log is useful, guard it with `if (kDebugMode)` and prefix with the class/file name.
6. Storage/IPFS helpers only
   - Never hardcode a single IPFS gateway or construct gateway URLs in UI/models/providers.
   - Use:
     - `StorageConfig.resolveUrl(raw)` (low-level)
     - `MediaUrlResolver.resolve(raw)` (screens/widgets)
     - `ArtworkMediaResolver.resolveCover(...)` (artwork covers)
     - `UserService.safeAvatarUrl(...)` (avatars)
     - `ARService` / `ARManager` for AR model launching
7. OrbitDB dual-write (backend)
   - Any Postgres mutation touching public entities must go through `publicSyncService` and honor `ORBITDB_SYNC_MODE`.
8. Desktop/Mobile parity
   - Any feature change in `lib/screens/` must be mirrored in `lib/screens/desktop/` using the same providers/services/models.
9. Check before creating
   - Search first (`rg`) and reuse existing services/widgets/providers to avoid duplication.
10. Naming discipline
   - Avoid creating duplicate domain models (e.g., do not introduce a second `ArtMarker`/`Achievement`).
   - Service-local structs must be suffixed: `*Definition`, `*Dto`, `*Record`, `*Payload`.
11. Cross-agent consistency
    - Keep guidance aligned across all `AGENTS.md` files; if you update one, update the related layer docs too.

---

## 2) Frontend Architecture (How The App Boots)

- Entry: `lib/main.dart`
  - Top-level providers are created here (ThemeProvider, Config, Web3, Wallet, Chat, Notifications, etc.).
  - Refresh bindings are done via ProxyProviders (no widget-level `bindToRefresh` calls).
- Initial routing: `lib/core/app_initializer.dart`
  - Loads auth token, initializes core providers, and chooses onboarding vs main UI.
- Warmup: `lib/services/app_bootstrap_service.dart`
  - Preloads providers so home/community/web3 screens render with data immediately.

Provider rules:
- Providers expose `initialize()` (idempotent) and do not require widget constructors to trigger loading.
- If a provider needs to listen to another provider, use `ChangeNotifierProxyProvider` and make the bind method idempotent.

Key flows (keep single-source-of-truth):
- Tasks/Achievements (UI progress): `lib/providers/task_provider.dart` + `lib/models/task.dart` + `lib/models/achievements.dart`
- Achievements rewards (KUB8/POAP): `lib/services/achievement_service.dart` (service-local `AchievementDefinition`)
- Map markers: use `ArtMarker` (`lib/models/art_marker.dart`) with `MapMarkerService`/`MapMarkerHelper` (no duplicate marker models)
- HTTP: use `BackendApiService` (do not call `http` directly from screens/widgets)
- Profiles: `User.id` is the wallet identifier; `UserProfile.walletAddress` is the profile identifier (do not invent a third variant)

---
## 2.1) Map Layers Manager (Centralized MapLibre Logic)

## Map System Architecture (Mobile + Desktop)

This document describes the refactored map architecture for art.kubus.
The primary goal is to eliminate duplication between mobile and desktop
map implementations while preserving behavior and performance.

---

## Design Principles

- **Single source of truth** for MapLibre sources, layers, and modes
- **Screens are layout-only** (no business logic)
- **Controllers own side-effects**
- **Explicit lifecycle ownership** (no leaked listeners/timers)
- **Mobile and desktop share logic, differ only in layout**

---

## Core Components

### MapLayersManager
Location:
`lib/features/map/map_layers_manager.dart`

Responsibilities:
- Add/remove MapLibre sources and layers
- Enforce canonical layer IDs and ordering
- Toggle 2D / 3D modes
- Apply theme-safe style updates
- Guard against duplicate layer creation

Notes:
- Screens must never add layers directly
- All layer mutations go through this manager

---

### KubusMapController
Location:
`lib/features/map/controller/kubus_map_controller.dart`

Responsibilities:
- Attach/detach MapLibre controller
- Handle style epochs
- Coordinate MapLayersManager lifecycle
- Own marker selection state
- Handle camera centering and composition offsets
- Cancel auto-follow on user interaction
- Open/close marker overlays
- Own and dispose all listeners, timers, and streams

Screens:
- Instantiate controller
- Pass MapLibre controller reference
- Observe state only

---

### Marker Overlay System
Location:
`lib/features/map/map_overlay_stack.dart`

Components:
- `KubusMapPointerInterceptor`
- `KubusMapMarkerOverlayLayer`

Responsibilities:
- Prevent pointer/scroll passthrough to map
- Render marker info cards
- Dismiss backdrop
- Handle animated transitions
- Desktop cursor behavior

Shared by:
- map_screen.dart
- desktop_map_screen.dart

---

### Nearby Art System
Locations:
- Controller: `lib/features/map/nearby/nearby_art_controller.dart`
- UI: `lib/widgets/map/nearby/kubus_nearby_art_panel.dart`

Responsibilities:
- Fetch and manage nearby art data
- Block map gestures while interacting
- Center map and open marker overlay on selection
- Provide identical behavior across mobile/desktop

---

### Search System
Locations:
- Controller: `lib/features/map/search/map_search_controller.dart`
- UI: `lib/widgets/search/kubus_search_bar.dart`

Responsibilities:
- Debounced search
- Suggestion overlays
- Routing selection to map controller
- Unified cursor behavior (desktop)
- Reused across map, home, community, messages

---

### Primary Map Controls
Location:
`lib/widgets/map/controls/kubus_map_primary_controls.dart`

Responsibilities:
- Zoom in/out
- Create marker
- Toggle 2D / 3D
- Compass
- Layout parametrized by platform

---

## Screens

### map_screen.dart (Mobile)
Responsibilities:
- Layout composition
- Mobile-only positioning
- Wiring controllers to widgets

### desktop_map_screen.dart (Desktop)
Responsibilities:
- Layout composition
- Desktop-only positioning
- Wiring controllers to widgets

Both screens must:
- Contain no MapLibre logic
- Contain no timers/listeners
- Delegate all behavior to controllers

---

## Technical Debt Policy

If logic appears in both map screens:
→ it MUST be extracted.

If a widget handles:
- gestures
- state
- side-effects
→ it MUST live outside the screen file.

Any new map feature must:
- integrate via KubusMapController
- use MapLayersManager for styling
- be testable without a real MapLibre controller

---

## Exit Criteria for Refactors

A refactor is considered complete only if:
- Both map screens shrink significantly
- flutter analyze passes
- No behavior regressions
- Leaving the map frees all resources

---

## 3) UI Color Roles (No Colors In Models)

Do not encode UI colors in models like `Achievement`, `Task`, or `Artwork`.

Use shared UI helpers:
- Category colors: `lib/utils/category_accent_color.dart`
- Rarity colors: `lib/utils/rarity_ui.dart`
- Color transforms: `lib/utils/app_color_utils.dart`

If a new role color is needed, add a helper/util (or extend ThemeProvider) and update both mobile + desktop UIs.

---

## 4) Local-First Fallback Policy (Frontend)

Some backend endpoints may not exist during dev; the app must remain functional without them.

- Collectibles/NFTs: local-first via `CollectiblesProvider` + `CollectiblesStorage`
  - Marketplace uses series + collectibles from local storage.
  - Wallet NFT galleries must not rely on backend `/api/nfts/*`.
- Institutions/Events: local-first via `InstitutionProvider.initialize(...)` + `InstitutionStorage`
- Blocked users: `BlockListService` (local SharedPreferences-backed set)

When adding a new feature that needs persistence:
- Prefer a small storage service under `lib/services/*_storage.dart`
- Then wrap it with a provider under `lib/providers/*_provider.dart`

---

## 5) Async + BuildContext Safety (Avoid Runtime Crashes)

- Do not use a `BuildContext` after an `await` unless properly guarded.
  - Prefer capturing `NavigatorState`, `ScaffoldMessengerState`, `ColorScheme`, and providers before `await`.
  - For `State.context` usage: guard with `if (!mounted) return;`.
  - For other contexts (dialogs/builder contexts): guard with `if (!context.mounted) return;` or avoid using that context after awaits.
- Never `return` from a `finally` block.

---

## 6) Web-Only Code (No `dart:html`)

- Do not import `dart:html` (deprecated). Use `package:web/web.dart` + JS interop.
- Web-only files must be named `*_web.dart` and only imported via conditional imports.
- For conditional imports, prefer `if (dart.library.js_interop)`.

---

## 7) Desktop/Mobile Parity Map (Update Both)

Mobile screens:
- Home: `lib/screens/home_screen.dart`
- Map: `lib/screens/map_screen.dart`
- Community: `lib/screens/community/community_screen.dart`
- Profile: `lib/screens/community/profile_screen.dart`, `lib/screens/community/user_profile_screen.dart`
- Marketplace: `lib/screens/web3/marketplace/marketplace.dart`
- Wallet: `lib/screens/web3/wallet/wallet_home.dart`, `lib/screens/web3/wallet/nft_gallery.dart`
- Institutions: `lib/screens/web3/institution/institution_hub.dart`

Desktop screens:
- Shell/Home/Map/Settings: `lib/screens/desktop/desktop_shell.dart`, `lib/screens/desktop/desktop_home_screen.dart`, `lib/screens/desktop/desktop_map_screen.dart`, `lib/screens/desktop/desktop_settings_screen.dart`
- Community: `lib/screens/desktop/community/*`
- Web3: `lib/screens/desktop/web3/*` (wallet, marketplace, governance, institution hub, artist studio)

---

## 8) Reusable Widgets (Extend, Don't Duplicate)

Core widgets:
- `lib/widgets/avatar_widget.dart`
- `lib/widgets/empty_state_card.dart`
- `lib/widgets/inline_loading.dart`
- `lib/widgets/app_loading.dart`
- `lib/widgets/gradient_icon_card.dart`

---

## 9) Backend Notes (For Full-Stack Changes)

- Express entry: `backend/src/server.js`
- Routes: `backend/src/routes/*.js`
- Storage: `backend/src/services/storageService.js`
- OrbitDB lifecycle: `backend/src/services/orbitdbService.js`
- Dual write: `backend/src/services/publicSyncService.js`

Any mutation touching public entities must call the relevant `publicSyncService` mapper when `ORBITDB_SYNC_MODE != off`.

---

## 10) Review Checklist (Before Shipping)

- Feature flags honored (Flutter + backend).
- No hardcoded colors in UI (no purple outside AI/system).
- No UI colors stored in domain models.
- No duplicated URL/IPFS gateway resolution logic.
- No `dart:html`; use `package:web/web.dart` for web-only code.
- No `BuildContext` usage after `await` without proper guarding.
- Providers initialize idempotently; no widget-level init/binding.
- Desktop/mobile parity maintained.
- Local-first fallbacks remain functional.

---

## 11) Audit watchlist (keep fixed)

Frontend (Flutter)
- Map web style URL normalization must not double-prefix `assets/` and must provide a production-safe fallback.
- Tutorial overlays must block pointer gestures on web (no touch-through to map).
- Reauth/app-lock gates must not trigger before login; only enable auto-lock when PIN/biometric is configured.
- Avoid overlapping polling/timers; gate refresh loops on visibility/feature flags.

Backend (Node)
- Enforce conversation membership on all messaging routes.
- Validate notification recipients (no cross-user creation without admin).
- Do not allow unauthenticated access to achievements stats.
- Require `JWT_SECRET` in non-dev environments; avoid default fallbacks.
- Normalize marker ownership (`createdBy` vs wallet) consistently.
- Analytics ingest should accept `text/plain` payloads and return 204 for filtered/ignored events.
