# art.kubus • Agent Playbook (Codex Ready)

> **Model compatibility:** Optimized for GPT-5.1-Codex (Preview) and other OpenAI Codex-compliant agents.
>
> **Mission:** Keep the Flutter + Node.js stack stable while extending AR, Solana, and OrbitDB features without breaking theme, feature flags, or storage fallbacks.

---

## 1. Core Guardrails

1. **Feature flags everywhere** – never hardcode feature availability. On Flutter call `AppConfig.isFeatureEnabled()`. On the backend respect env toggles (`USE_MOCK_DATA`, `ENABLE_DEBUG_ENDPOINTS`, `ORBITDB_SYNC_MODE`, etc.).
2. **Theme discipline** – UI colors must come from `Theme.of(context).colorScheme` or `themeProvider.accentColor`. Purple hues are reserved for AI/system indicators only.
3. **Provider-first state** – all stateful logic belongs in `ChangeNotifier` providers under `lib/providers/`. Initialize them via `AppInitializer` and `ChangeNotifierProxyProvider`, not widget constructors.
4. **No placeholder code** – every function ships production-ready (no `TODO`, no stub returns). If you touch a feature, make it complete.
5. **IPFS/Storage helpers only** – always route CID resolution through `StorageService`, `ARService`, or `UserService.safeAvatarUrl`. They implement gateway rotation, retries, and HTTP/S3 fallbacks.
6. **OrbitDB dual-write** – any Postgres mutation touching artworks, AR markers, profiles, collections, or community posts must go through `publicSyncService`. Respect `ORBITDB_SYNC_MODE` (`dual-write`, `catch-up`, `off`).
7. **Physical hardware for AR** – AR features require ARCore/ARKit capable devices. Simulators/emulators are for UI only.
8. **Check before creating** – use `grep_search`, `file_search`, or semantic search to avoid duplicate files, widgets, or services.
9. **Desktop/Mobile parity** – when adding or modifying ANY feature, update BOTH mobile screens (in `lib/screens/`) AND desktop screens (in `lib/screens/desktop/`). Use shared providers, services, and models.

---

## 2. Project Snapshot

| Layer | Stack | Highlights |
|-------|-------|------------|
| Mobile app | Flutter 3.3.x, Provider, Riverpod-style patterns, ARCore/ARKit plugins | `lib/` houses config, providers, services, screens, onboarding, web3 modules, widgets. |
| Backend | Node.js 20 + Express, PostgreSQL 15, OrbitDB, Redis, IPFS/IPFS-Cluster | `backend/src/` contains server, routes, services (storage, OrbitDB, sync), db helpers, middleware. |
| Blockchain | Solana Web3 (`solana` Dart + JS SDKs), SPL token (KUB8), WalletConnect | Wallet flows live in `lib/services/solana_wallet_service.dart` & `lib/web3/`. |
| Storage | Hybrid IPFS + HTTP/S3 fallback | Controlled via `DEFAULT_STORAGE_PROVIDER` and helper services. |

Key reference files:
- `lib/core/app_initializer.dart` – boots providers, handles onboarding tiers.
- `lib/services/backend_api_service.dart` – single HTTP client respecting auth + feature flags.
- `lib/services/ar_service.dart` – platform AR launcher with IPFS gateway conversion.
- `backend/src/server.js` – Express setup (Helmet, rate limits, sockets, health checks).
- `backend/src/services/{storageService,orbitdbService,publicSyncService}.js` – storage abstraction, OrbitDB lifecycle, Postgres→Orbit dual writes.
- `backend/src/routes/*.js` – REST modules (auth, artworks, arMarkers, community, profiles, etc.).

---

## 3. Frontend Architecture

### 3.1 App shell & state flow
- `main.dart` wires up the provider tree. `AppInitializer` runs migrations (SharedPreferences keys like `first_time`, `completed_onboarding`, `has_wallet`) before presenting onboarding vs. main app.
- Runtime config toggles propagate through `ConfigProvider` → downstream providers (mock data, AR viewer flags, blockchain mode).

### 3.2 Provider ecosystem
- **ThemeProvider** – accent color palette + material dynamic colors. Never hardcode hex outside this provider.
- **MockupDataProvider** – central switch for mock vs. live data. Downstream providers pull from it automatically via `ChangeNotifierProxyProvider`.
- **Web3Provider / WalletProvider** – manage Solana network selection, SPL balances, WalletConnect sessions, mnemonic storage.
- **ArtworkProvider / InstitutionProvider / DAOProvider / CommunityProvider** – fetch domain data, watch config flags, and expose derived metrics to UI.
- **NotificationProvider / TaskProvider / ChatProvider** – handle real-time socket events (only if `ENABLE_WEBSOCKETS=true`).

### 3.3 Services & integrations
- `backend_api_service.dart` centralizes auth headers, retries, and base URL logic (reads from `ApiKeys.backendUrl`). Always reuse it.
- `ar_service.dart` handles IPFS → HTTP conversion, ARCore Scene Viewer intents (Android), AR Quick Look (iOS). Do not bypass; it already checks permissions and formats.
- `solana_wallet_service.dart` + `solana_walletconnect_service.dart` maintain mnemonic wallets and external wallet sessions. Persist mnemonics encrypted in `SharedPreferences`.
- `achievement_service.dart` triggers POAP/token rewards and writes local prefs.

### 3.4 UI conventions
- Use `Theme.of(context).colorScheme` for every color. Purple shades (#8B5CF6, #A855F7, #9333EA, etc.) are strictly reserved for AI/system indicators.
- Gradient headers default to white text in light mode; general body text uses `colorScheme.onSurface`.
- Shared widgets live in `lib/widgets/` (e.g., `avatar_widget.dart`, `ar_view.dart`, `inline_loading.dart`). Extend them instead of duplicating logic.

### 3.5 Feature flags & onboarding
- All features thread through `lib/config/config.dart`. When adding features, add toggles there and expose them via `ConfigProvider`.
- First-time user experience: OnboardingScreen (wallet optional) → Explore mode vs. wallet-connected mode. Respect `skipOnboardingForReturningUsers`.

### 3.6 Desktop & Mobile Parity

The app supports **responsive layouts** with dedicated desktop screens:

```
lib/screens/desktop/
├── desktop_shell.dart              # Main navigation shell with sidebar
├── desktop_home_screen.dart        # Home feed + quick actions + Web3 hub
├── desktop_map_screen.dart         # Full-screen map with side panels
├── desktop_community_screen.dart   # Social feed + messages panel
├── desktop_marketplace_screen.dart # NFT grid with filters
├── desktop_wallet_screen.dart      # Portfolio dashboard
├── desktop_profile_screen.dart     # Profile + settings (10 sections)
└── components/
    ├── desktop_widgets.dart        # Shared UI components
    └── desktop_navigation.dart     # Sidebar navigation
```

**Responsive breakpoints** (`DesktopBreakpoints`):
- `compact`: 600px (phone)
- `medium`: 900px (tablet portrait)
- `expanded`: 1200px (tablet landscape / small desktop)
- `large`: 1600px (full desktop)

**⚠️ CRITICAL: Keep Desktop & Mobile In Sync**

When adding or modifying features, **ALWAYS update both versions simultaneously**:

| Feature Area | Mobile Location | Desktop Location |
|--------------|-----------------|------------------|
| Home/Feed | `lib/screens/home_screen.dart` | `desktop_home_screen.dart` |
| Map/Explore | `lib/screens/map_screen.dart` | `desktop_map_screen.dart` |
| Community | `lib/screens/community/` | `desktop_community_screen.dart` |
| Marketplace | `lib/screens/web3/marketplace/` | `desktop_marketplace_screen.dart` |
| Wallet | `lib/screens/web3/wallet/` | `desktop_wallet_screen.dart` |
| Profile/Settings | `lib/screens/settings/settings_screen.dart` | `desktop_profile_screen.dart` |
| Messages/Chat | `lib/screens/community/messages_screen.dart` | Sidebar panel in `desktop_community_screen.dart` |

**Desktop-specific patterns**:
- Side panels instead of bottom sheets (Google Maps style)
- Dialog overlays instead of `showModalBottomSheet`
- Hover states and larger touch targets
- Same providers + services + models as mobile

---

## 4. Backend Architecture

### 4.1 Express layout
- `src/server.js` wires Helmet, CORS, body parsers, rate limits, Socket.IO, and conditional debug endpoints controlled by `ENABLE_DEBUG_ENDPOINTS`.
- Routes live under `src/routes/` (auth, artworks, arMarkers, community, achievements, profiles, collections, upload, storage, orbitdb, mockData, health, etc.). Every route enforces JWT middleware except explicitly marked public endpoints.
- Middleware: `auth.js` (JWT + API key fallback), `socketAuth.js`, `errorHandler.js` (reports size limits, hides internals in production).

### 4.2 Database & migrations
- PostgreSQL schema lives in `backend/src/db/schema_complete.sql`. Migrations and helper scripts sit in `backend/migrations` + `src/db/migrate.js`.
- Required extensions: `pg_trgm` (text similarity) and `uuid-ossp`. Functions like `update_profile_stats` and `set_default_avatar_url` are part of the schema dump—never remove them.
- When adding tables/columns affecting OrbitDB or mock data, update the schema dump, migrations, and `publicSyncService` mappers simultaneously.

### 4.3 OrbitDB dual write
- `publicSyncService.js` converts Postgres rows into OrbitDB documents for `artworks`, `ar_markers`, `profiles`, `community_posts`, and `collections`.
- Envs:
	- `ORBITDB_SYNC_MODE`: `dual-write` (default), `catch-up`, `off`.
	- `ORBITDB_REPO_PATH`: persistent repo directory.
	- `ORBITDB_SERVER_PRIVATE_KEY`: identity seed (rotate with care).
	- `ORBITDB_PEER_SYNC_INTERVAL_MS`: background sync cadence.
- When `ORBITDB_SYNC_MODE` ≠ `off`, call the appropriate sync helper (`syncArtworkRow`, `syncProfileRow`, etc.) inside each mutation route or service.

### 4.4 Storage & IPFS resilience
- `storageService.js` abstracts Pinata uploads, HTTP storage, and S3-compatible drivers. Provider selected via `DEFAULT_STORAGE_PROVIDER` (`ipfs`, `http`, `hybrid`).
- `orbitdbService.js` handles IPFS connectivity. In `IPFS_MODE=remote`, it retries connections using `IPFS_REMOTE_RETRIES` and `IPFS_REMOTE_RETRY_DELAY_MS`. If unreachable and `IPFS_REMOTE_FALLBACK=true`, it boots an embedded `ipfs-core` node.
- `IPFS_GATEWAY_URL` accepts comma-separated gateways (Pinata → ipfs.io → Cloudflare → dweb.link → localhost). Always feed this list to helpers; never hardcode a single gateway.
- If IPFS degrades, keep assets reachable via HTTP/S3 using `S3_*` envs plus hybrid storage mode.

### 4.5 Caching & background services
- `redisClient.js` toggles between Redis and in-memory cache via `CACHE_DRIVER` / `CACHE_ENABLED`.
- `workers/orbitdbPeer.js` keeps OrbitDB peers in sync (`ORBITDB_PEER_SYNC_INTERVAL_MS`).
- Cloudflare tunnel support lives in Docker compose profiles for zero-port-forwarding dev access.

---

## 5. Development Workflow

### 5.1 Setup & installation
```powershell
# Flutter deps
flutter pub get

# Backend deps
cd backend
npm install
cd ..

# Environment
cp backend/.env.example backend/.env  # fill real secrets
```

### 5.2 Running services
```powershell
# Mobile app (physical device for AR)
flutter run --debug

# Backend + dependencies
docker compose up postgres redis backend

# Backend local dev (hot reload)
cd backend; npm run dev
```

### 5.3 Testing & QA
- `flutter analyze`, `flutter test` – run before every PR touching Flutter code.
- `npm test` or targeted Jest scripts (see `backend/__tests__`).
- `npm run migrate:status` / `npm run migrate:up` when editing DB schema.
- For OrbitDB changes, run backend with `ORBITDB_SYNC_MODE=dual-write` and verify `publicSyncService` logs.

### 5.4 Data + feature flag tips
- Mock data toggles live in app settings → Developer Options. When toggled, `ConfigProvider` and `MockupDataProvider` propagate new values without rebuilds.
- Backend mock routes exist only when `USE_MOCK_DATA=true`; never leave it enabled in production.

---

## 6. Pain Points & Watch-outs

| Area | Issue | Mitigation |
|------|-------|------------|
| AR | Simulators lack ARCore/ARKit support. | Test AR flows on physical hardware; guard code paths with feature flags. |
| Solana devnet | Airdrops limited to 2 SOL per request; network flakes. | Use `requestDevnetAirdrop` with retries, allow switching to testnet/mainnet via settings. |
| OrbitDB sync | Missing sync calls lead to stale decentralized data. | Always call `publicSyncService` helpers after Postgres mutations; log success/failures. |
| IPFS gateways | Single gateway timeouts break AR models and avatars. | Use gateway lists + fallback logic (`IPFS_REMOTE_FALLBACK=true`, `DEFAULT_STORAGE_PROVIDER=hybrid`). |
| Provider init | Initializing inside widgets causes double fetches and null crashes. | Keep initialization inside `AppInitializer` and providers’ `initialize()` methods. |
| Theme colors | Hardcoded hex (esp. purple) violates brand rules. | Pull from `Theme.of(context).colorScheme` or `themeProvider`. |

---

## 7. Review Checklist

- [ ] Feature flags & env toggles honored on both Flutter and Node.
- [ ] Providers initialized/disposed correctly; no singleton shortcuts.
- [ ] OrbitDB dual-write helpers invoked wherever Postgres is mutated.
- [ ] IPFS fetching goes through resolver helpers; hybrid fallback verified.
- [ ] UI colors strictly use theme/accent values; no purple outside AI indicators.
- [ ] Desktop/Mobile parity maintained (both versions updated simultaneously).
- [ ] `flutter analyze`, `flutter test`, and backend linters/tests pass.
- [ ] Sensitive data pulled from `.env` or secure storage (never hardcoded).
- [ ] Documentation/comments updated for new env vars, feature flags, or workflows.

Stay disciplined, keep the decentralized pipeline healthy, and always fall back gracefully when IPFS is flaky.