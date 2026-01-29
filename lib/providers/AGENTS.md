# lib/providers/ — Agent Notes (repo-grounded)

## Mission
Own state in `ChangeNotifier` providers, and keep app initialization stable and idempotent.

## Initialization order (source of truth)
- Providers are wired in `lib/main.dart` (MultiProvider + ProxyProviders).
- Startup sequence is in `lib/core/app_initializer.dart`.
- Warm‑up preloading is in `lib/services/app_bootstrap_service.dart`.

## Refresh & binding patterns
- App-wide refresh uses `AppRefreshProvider` (`lib/providers/app_refresh_provider.dart`).
- Bind methods should be idempotent and guard repeated binding:
	- Example: `PresenceProvider.bindToRefresh(...)` and `bindProfileProvider(...)` in `lib/providers/presence_provider.dart`.

## Feature flags inside providers
- Providers must respect `AppConfig.isFeatureEnabled(...)` (see `lib/config/config.dart`).
- Example: `PresenceProvider` gates prefetch/heartbeat/visit logging behind `presence` and `presenceLastVisitedLocation` flags.

## Polling discipline
- When timers are required, keep them bounded and cancellable.
- Example: `PresenceProvider` uses `_autoRefreshInterval`/`_heartbeatInterval` and cancels timers when feature flags or session state disable presence.

## Do not initialize in widgets
- Providers must not be initialized from widgets; use `AppInitializer` + `AppBootstrapService` only.

## Evidence (direct quotes with line references)
- `lib/providers/app_refresh_provider.dart` (line 3):
	- “/// App wide refresh provider to notify components to refresh their data.”
- `lib/providers/presence_provider.dart` (lines 16, 64):
	- “// Keep presence feeling "live" without spamming the backend.”
	- “void bindToRefresh(AppRefreshProvider refreshProvider) {”
- `lib/core/app_initializer.dart` (lines 128, 138):
	- “// Initialize ConfigProvider first”
	- “// Initialize WalletProvider early to restore cached wallet (safe for fresh starts).”
