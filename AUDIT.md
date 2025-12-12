# Architecture & Content Audit

## Frontend architecture
- **Entrypoints & layout**: `lib/main.dart` boots providers and error handling, then renders `AppInitializer` which routes to onboarding/auth/main app after hydrating config, cache, wallet, profile, and chat providers. `AppInitializer` also prewarms data via `AppBootstrapService` and chooses desktop vs mobile onboarding shells.【F:lib/main.dart†L1-L112】【F:lib/core/app_initializer.dart†L43-L200】
- **Navigation**: `lib/main_app.dart` drives a bottom navigation stack (Map, AR, Community, Home feed, Profile) and swaps to `DesktopShell` when `DesktopBreakpoints.isDesktop` is true. AR tab is lazily built; wallet lock overlay handled at shell level.【F:lib/main_app.dart†L22-L156】
- **State management**: Provider-based `MultiProvider` in `main.dart` registers Theme, Config, Platform/Connection, Wallet/Web3, Profile, SavedItems, Chat, Notifications, RecentActivity, Artwork, Institutions, DAO, CommunityHub, Task, Collectibles, TileProviders, AppRefresh, Cache, and Navigation providers (mostly `ChangeNotifier`). Providers are hydrated during `AppInitializer` before navigation decisions.【F:lib/main.dart†L113-L220】【F:lib/core/app_initializer.dart†L43-L200】
- **API client structure**: `lib/services/backend_api_service.dart` is the centralized HTTP client (uses `http`, `FlutterSecureStorage`, `SharedPreferences`). Handles JWT storage/issuance, rate limiting, and endpoints for profiles, artworks, markers, community, storage, search, etc. Other services (e.g., `ar_service.dart`, `map_marker_service.dart`, `task_service.dart`, `push_notification_service.dart`, `solana_wallet_service.dart`) sit in `lib/services/` and reuse shared config and providers.【F:lib/services/backend_api_service.dart†L1-L200】
- **Auth flows**: `AppInitializer` checks persisted flags and decides between onboarding, sign-in, or main app. `lib/screens/auth/sign_in_screen.dart` supports email/password, Google sign-in, and WalletConnect entry, provisioning wallets/profiles on success. JWTs are loaded/issued via `BackendApiService`; wallet auth also syncs `Web3Provider` and `ProfileProvider`.【F:lib/core/app_initializer.dart†L119-L200】【F:lib/screens/auth/sign_in_screen.dart†L161-L243】
- **Feed/Discover**: `lib/screens/home_screen.dart` (not modified here) provides feed-style content; `lib/screens/community/community_screen.dart` (mobile) and `lib/screens/desktop/community/desktop_community_screen.dart` handle community posts/groups with floating action buttons for posting. `RecentActivityProvider` binds to notifications for feed updates.【F:lib/main.dart†L146-L177】【F:lib/screens/community/community_screen.dart†L2769-L2896】
- **Map & markers**: `lib/screens/map_screen.dart` manages geolocation, compass, draggable sheets, marker fetching via `MapMarkerService`, AR proximity checks, and discovery filters. Supports marker types (artwork, institution, event, residency, drop, experience) and search suggestions via `SearchService`.【F:lib/screens/map_screen.dart†L1-L140】【F:lib/screens/map_screen.dart†L214-L270】
- **Events/Exhibitions**: Represented within map markers (event/residency types) and tasks/achievements (`lib/models/task.dart`, `lib/services/task_service.dart`). No dedicated events screen beyond map overlays; desktop shells reuse the same data sources.
- **Messaging/Groups**: `ChatProvider`, community screens, and `CommunityHubProvider` handle conversations/groups; sockets are bound when notifications are enabled (details in providers/services not listed here).
- **Profile types**: `ProfileProvider` loads profiles based on wallet; `user_profile.dart` models users. `InstitutionProvider` and `DAOProvider` support institution/DAO roles surfaced in profile and marketplace views.

## Backend architecture (submodule missing)
- The backend is a git submodule (`backend/` → `art.kubus-backend`), but it is not checked out in this workspace, so source code for routes/controllers/services/DB schema is unavailable. Expectations from repo metadata: Express + Postgres + OrbitDB + Socket.IO with JWT auth and IPFS/HTTP hybrid storage; consult the submodule for actual routes and schema once initialized.【F:.gitmodules†L1-L3】【F:README.md†L37-L44】

## UI copy over-emphasizing “XR network” / “XR-first”
- No in-app Flutter UI strings explicitly over-emphasize “XR network” or “XR-first”. README marketing copy references “extended reality (XR)” in the overview; adjust if marketing tone needs softening.【F:README.md†L12-L27】

## Translation / user-facing strings
- **Translation approach**: No localization scaffolding is present (no `AppLocalizations`, arb files, or i18n helpers). Strings are embedded directly in widgets, dialogs, snackbars, and buttons.
- **High-surface hotspots for user-facing strings**:
  - Auth: `lib/screens/auth/sign_in_screen.dart` (snackbars for email/Google/wallet status, button labels, error messages).【F:lib/screens/auth/sign_in_screen.dart†L161-L243】
  - Onboarding: `lib/screens/onboarding/` (mobile) and `lib/screens/desktop/onboarding/` contain welcome/feature copy.
  - Navigation & shell: `lib/main_app.dart`, `lib/screens/home_screen.dart`, `lib/screens/community/profile_screen.dart` (tab labels, toasts), `lib/screens/download_app_screen.dart`.
  - Map/AR: `lib/screens/map_screen.dart` (search prompts, permission dialogs, marker sheets) and `lib/screens/art/ar_screen.dart` (AR camera prompts).
  - Community/Messaging: `lib/screens/community/community_screen.dart` and desktop counterpart for posts/comments/groups plus FAB labels.【F:lib/screens/community/community_screen.dart†L2769-L2896】
  - Settings/Profile: `lib/screens/settings_screen.dart`, `lib/screens/community/user_profile_screen.dart`, and widgets under `lib/widgets/` (dialogs, buttons, empty states).
  - Error/empty states: shared widgets like `lib/widgets/inline_loading.dart`, `lib/widgets/map_marker_dialog.dart`, `lib/widgets/art_marker_cube.dart` contain fallback text.

## Dependencies
- **Flutter (pubspec.yaml)**: Core Flutter SDK plus cupertino_icons, path_provider, permission_handler, flutter_native_splash, url_launcher, image_picker, provider, location, flutter_map (+ cancellable_tile_provider + geojson + latlong2 + proj4dart), shared_preferences, flutter_secure_storage, local_auth, geolocator, google_fonts, animations, google_sign_in, fl_chart, http/http_parser, pointycastle, solana, bip39, flutter_local_notifications, reown_walletkit, qr_flutter, mobile_scanner, camera, flutter_compass, arcore_flutter_plugin (local path), crypto, logger, vector_math, file_picker, path, filesystem_picker, intl, share_plus, socket_io_client, dio, equatable; dev: flutter_test, flutter_lints.【F:pubspec.yaml†L16-L119】【F:pubspec.yaml†L133-L169】
- **Node/Express**: package.json not present because backend submodule is missing; dependencies to be listed after submodule init.

## Build/Run notes (inferred)
- Frontend: `flutter pub get` then `flutter run --debug` targeting physical devices for AR features; theming/providers initialized via `AppLauncher` → `AppInitializer` → `MainApp`. Feature flags live in `lib/config/config.dart`.
- Backend: initialize submodule, run `npm install` inside `backend`, configure environment (.env like `.env.example`), then `npm run dev` or Docker compose for Postgres/Redis/API (per root README/AGENTS guidance).【F:README.md†L31-L54】

## Feature checklist (observed vs gaps)
- [x] Provider-based state tree with config/cache/auth/web3/profile/chat/artwork/etc. bootstrapped before routing.【F:lib/core/app_initializer.dart†L43-L200】
- [x] Responsive navigation with desktop shell swap and mobile bottom navigation tabs (Map, AR, Community, Home, Profile).【F:lib/main_app.dart†L22-L156】
- [x] Map/marker discovery with search, filters, AR proximity, and marker types including events/residencies.【F:lib/screens/map_screen.dart†L1-L140】【F:lib/screens/map_screen.dart†L214-L270】
- [x] Multi-auth support (email, Google, wallet connect) with wallet provisioning and JWT persistence.【F:lib/core/app_initializer.dart†L119-L200】【F:lib/screens/auth/sign_in_screen.dart†L161-L243】
- [x] Community/feed screens with creation FABs and desktop parity components.【F:lib/screens/community/community_screen.dart†L2769-L2896】
- [ ] Localization/i18n layer (all strings hardcoded; needs arb/localizations setup and string extraction).
- [ ] Backend source absent in this workspace (submodule not initialized), so routes/controllers/schema/tests need verification after fetching.【F:.gitmodules†L1-L3】
- [ ] Explicit events/exhibitions screens beyond map overlays; consider dedicated listing/detail views if required.
- [ ] Messaging/group socket setup verification blocked without backend code; ensure Socket.IO integration aligns with providers once backend is available.
- [ ] Storage/OrbitDB/IPFS behaviors cannot be validated until backend submodule is present; check storage helpers after sync.
