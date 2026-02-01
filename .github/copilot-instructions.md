# art.kubus - GitHub Copilot / AI Agent Instructions

These rules exist to keep the Flutter + Node.js stack stable and to stop duplication/regressions.

---

## Mission
Ship production-ready Flutter features (AR, Solana, OrbitDB, storage) without breaking:
- feature flags
- theme system
- provider initialization order
- desktop/mobile parity
- IPFS/HTTP/S3 fallbacks

Preflight: always review **all** `AGENTS.md` files in this repo (root, `lib/**`, `backend/**`) before making changes.

---

## Non-Negotiables
1. **Feature flags everywhere**
   - Flutter: never hardcode availability; use `AppConfig.isFeatureEnabled('flag')` and/or `ConfigProvider`.
   - Backend: respect env toggles (`USE_MOCK_DATA`, `ENABLE_DEBUG_ENDPOINTS`, `ORBITDB_SYNC_MODE`, etc.).
2. **Theme discipline**
   - All UI colors must come from `Theme.of(context).colorScheme.*` or `themeProvider.accentColor`.
   - No purple outside explicit AI/system indicators.
3. **Provider-first state**
   - Stateful logic belongs in `ChangeNotifier` providers under `lib/providers/`.
   - Providers are created in `lib/main.dart` and initialized in `lib/core/app_initializer.dart` / `lib/services/app_bootstrap_service.dart`.
   - Do not initialize providers inside widgets (`initState`, constructors). Bindings (refresh hooks, socket wiring) must be idempotent.
4. **No placeholder/stub code**
   - No `TODO`, `FIXME`, stub returns, or "coming soon" flows that pretend to work.
   - If something isn't shippable, gate it behind a feature flag and keep shipped code coherent.
5. **Async + BuildContext safety**
   - Don't use a `BuildContext` after an `await` unless properly guarded.
   - Prefer capturing `NavigatorState`, `ScaffoldMessengerState`, `ColorScheme`, and providers before `await`.
   - For `State.context` usage: guard with `if (!mounted) return;`.
   - For dialog/builder contexts: guard with `if (!context.mounted) return;` or avoid using that context after awaits.
6. **Web-only code (no `dart:html`)**
   - Don't import `dart:html` (deprecated). Use `package:web/web.dart` + JS interop in `*_web.dart` files.
   - Conditional imports should use `if (dart.library.js_interop)`.
7. **Logging discipline**
   - Do not ship noisy `debugPrint('DEBUG: ...')` or emoji logs.
   - If a log is useful, guard it with `if (kDebugMode)` and prefix with the class/file name (e.g. `HomeScreen: ...`).
8. **Media + IPFS URL resolution**
   - Never build gateway URLs in UI/models/providers.
   - Use:
     - `MediaUrlResolver.resolve(raw)` (screens/widgets)
     - `ArtworkMediaResolver.resolveCover(...)` (artwork covers)
     - `StorageConfig.resolveUrl(raw)` (low-level service usage)
     - `UserService.safeAvatarUrl(...)` (avatars)
9. **OrbitDB dual-write**
   - Any backend Postgres mutation touching public entities must go through `publicSyncService` and honor `ORBITDB_SYNC_MODE`.
10. **Desktop/Mobile parity**
   - Any feature change in `lib/screens/` must be mirrored in `lib/screens/desktop/` (same providers/services/models; layout differs).

---

## "Single Source Of Truth" Helpers (Don't Duplicate)
- **Category/task/achievement colors:** `lib/utils/category_accent_color.dart`
- **Rarity colors:** `lib/utils/rarity_ui.dart` (never return colors from models)
- **Color transforms:** `lib/utils/app_color_utils.dart`
- **Navigation definitions:** `NavigationProvider.screenDefinitions` is typed (no hardcoded colors)
- **Map markers:** use `ArtMarker` (`lib/models/art_marker.dart`) and `MapMarkerService`/`MapMarkerHelper` (do not add a second marker model)

## Naming / Modeling Rules (Avoid Duplication)
- Do not create new classes that collide with existing domain models (`Achievement`, `Task`, `Artwork`, `ArtMarker`, etc.).
- Service-local structs must be suffixed to show intent: `*Definition`, `*Record`, `*Payload`, `*Dto`.
- Profiles: `User.id` is the wallet identifier; `UserProfile.walletAddress` is the profile identifier (don't invent `walletAddress` on `User`).

---

## Local-First Fallback Policy (Frontend)
Backend endpoints are not guaranteed to exist in dev; the app must remain usable offline.

- **Collectibles/NFTs:** use `CollectiblesProvider` + `CollectiblesStorage` (local). UI must not rely on backend `/api/nfts/*`.
  - Marketplace: `lib/screens/web3/marketplace/marketplace.dart`
  - Wallet NFT gallery: `lib/screens/web3/wallet/nft_gallery.dart`
  - Desktop wallet NFT tab: `lib/screens/desktop/web3/desktop_wallet_screen.dart`
- **Institutions/Events:** use `InstitutionProvider.initialize(...)` + `InstitutionStorage` (local-first; backend optional).
- **Blocked users:** use `BlockListService` (local SharedPreferences-backed set).

---

## Achievements / Tasks (Avoid Two Systems)
- UI progress + points: `lib/models/achievements.dart` + `TaskProvider` (`lib/providers/task_provider.dart`)
- Rewards (KUB8 / POAP local persistence + backend calls): `AchievementService` (`lib/services/achievement_service.dart`)
- Do not add another "Achievement" model; service-local types must stay clearly named (e.g. `AchievementDefinition`).

---

## Quick File Map
- Bootstrapping: `lib/main.dart`, `lib/core/app_initializer.dart`, `lib/services/app_bootstrap_service.dart`
- Theme: `lib/providers/themeprovider.dart`
- Media resolution: `lib/services/storage_config.dart`, `lib/utils/media_url_resolver.dart`, `lib/utils/artwork_media_resolver.dart`
- AR: `lib/services/ar_service.dart`, `lib/services/ar_manager.dart`, `lib/services/ar_integration_service.dart`
- Web3: `lib/services/solana_wallet_service.dart`, `lib/providers/web3provider.dart`, `lib/providers/wallet_provider.dart`
- Tasks/Achievements: `lib/providers/task_provider.dart`, `lib/models/task.dart`, `lib/models/achievements.dart`, `lib/services/achievement_service.dart`
- Collectibles: `lib/providers/collectibles_provider.dart`, `lib/services/collectibles_storage.dart`
- Institutions: `lib/providers/institution_provider.dart`, `lib/services/institution_storage.dart`
- Web notifications: `lib/services/notification_helper.dart`, `lib/services/notification_show_helper.dart`
- Tile caching: `lib/providers/tile_disk_cache.dart`

---

## Workflow Expectations
- Search before creating new code (`rg` first).
- Prefer typed models over `Map<String, dynamic>` unless parsing API JSON.
- Keep changes minimal, coherent, and production-grade.
