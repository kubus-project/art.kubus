# Architecture & Content Audit

This document captures a high-level map of the current stack and highlights gaps that may require follow-up work.

## Frontend (Flutter)
- **Boot flow**: `lib/main.dart` builds the provider tree, then renders `AppInitializer` (`lib/core/app_initializer.dart`) which hydrates config/auth/wallet/profile/chat and routes to onboarding vs main UI.
- **Warmup**: `lib/services/app_bootstrap_service.dart` preloads core providers so primary screens render with data immediately.
- **Navigation**: `lib/main_app.dart` drives the main shell and switches to desktop shells when appropriate.
- **State management**: Provider-first (`ChangeNotifier`) in `lib/providers/`; widget constructors and `initState` should not be responsible for provider initialization.
- **Networking**: `lib/services/backend_api_service.dart` is the single HTTP client; screens/widgets should not call `http` directly.
- **Media/IPFS**: URL resolution must go through `StorageConfig`/`MediaUrlResolver`/`ArtworkMediaResolver`/`UserService.safeAvatarUrl` (no hardcoded gateways in UI/models).
- **AR**: AR entry points live in `lib/services/ar_service.dart` / `lib/services/ar_manager.dart` and require physical devices (ARCore/ARKit).
- **Web3/Solana**: wallet flows live in `lib/services/solana_wallet_service.dart` + `lib/providers/wallet_provider.dart` + `lib/providers/web3provider.dart`.
- **Community + messaging**: `lib/screens/community/` + `ChatProvider`/`CommunityHubProvider`; websocket wiring should respect feature flags and be idempotent.
- **Desktop parity**: desktop views live under `lib/screens/desktop/` and should be kept feature-equivalent to mobile.

## Backend (Node.js)
- **Location**: `backend/` (submodule-style layout).
- **Server entry**: `backend/src/server.js`
- **Routes**: `backend/src/routes/*.js`
- **Core services**: `backend/src/services/*` (storage, OrbitDB lifecycle, sync/dual-write, etc.)

## User-Facing Strings / i18n
- ARB-based localization is present and generated via Flutter gen-l10n:
  - ARB sources: `lib/l10n/app_en.arb`, `lib/l10n/app_sl.arb`
  - Generated API: `lib/l10n/app_localizations.dart` (`AppLocalizations`)
  - Wired into `MaterialApp` in `lib/main.dart`.

- High-surface hotspots to keep localized (and parity-check for desktop):
  - Auth: `lib/screens/auth/`
  - Onboarding: `lib/screens/onboarding/` and `lib/screens/desktop/onboarding/`
  - Map/AR: `lib/screens/map_screen.dart`, `lib/screens/art/ar_screen.dart`
  - Community/Messaging: `lib/screens/community/` and desktop community screens
  - Settings/Profile: `lib/screens/settings_screen.dart`, `lib/screens/community/user_profile_screen.dart`

## Phase 1 wiring map

For the current A–F wiring maps (UI → providers → services → endpoints), see:

- `docs/PHASE1_WIRING_MAP.md`

## Build / Run
- **Flutter**: `flutter pub get` then `flutter run --debug` (use physical devices for AR features).
- **Backend**: `cd backend; npm install; npm run dev` (or use the provided docker compose).

## Noted Gaps / Follow-Ups
- Add an i18n layer if translations are required.
- Keep analyzer clean (especially async `BuildContext` usage and deprecated APIs).
- Ensure desktop/mobile parity for any new or modified features.
