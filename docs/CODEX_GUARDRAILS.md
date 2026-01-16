# Codex Guardrails (art.kubus)

This document is a **do-not-break-the-app** checklist for agent-assisted work in the Flutter + Node.js stack.

If a change violates a guardrail, refactor the approach instead of patching around it.

## Provider-First State (Flutter)

- [ ] Stateful logic lives in a `ChangeNotifier` under `lib/providers/` (not in widgets).
- [ ] Provider instances are created in `lib/main.dart` (typically via `MultiProvider`).
- [ ] Provider initialization is **idempotent** (safe to call multiple times).
- [ ] No provider initialization/binding happens in widget constructors or `initState`.
- [ ] Cross-provider dependencies are wired with `ChangeNotifierProxyProvider` / `ProxyProvider` (bindings remain idempotent).
- [ ] App boot is respected: init work belongs in `lib/core/app_initializer.dart` and `lib/services/app_bootstrap_service.dart` (not in screens).

Quick checks:
- `rg -n "initState\\(\\).*\\b(initialize|bind|connect|load)\\b" lib/screens lib/widgets -S`
- `rg -n "ChangeNotifierProxyProvider|ProxyProvider" lib/main.dart -S`

## Networking (Flutter)

- [ ] **All HTTP** goes through `lib/services/backend_api_service.dart`.
- [ ] Screens/widgets never import or use `package:http` directly.
- [ ] Providers/services call `BackendApiService()` methods; they do not construct ad-hoc REST clients.
- [ ] Backend availability is not assumed: clients handle `404`/feature-gated routes gracefully (local-first where applicable).

Quick checks:
- `rg -n "package:http/http\\.dart" lib -S` (should be limited to `lib/services/backend_api_service.dart`)
- `rg -n "\\bhttp\\.(get|post|put|delete|patch)\\b" lib -S` (should not appear in `lib/screens/` or `lib/widgets/`)

## Media + IPFS URL Resolution

Do not hardcode IPFS gateways or build gateway URLs in UI/models/providers.

- [ ] Low-level resolution uses `StorageConfig.resolveUrl(raw)` (`lib/services/storage_config.dart`).
- [ ] Screens/widgets use `MediaUrlResolver.resolve(raw)` for general media (`lib/utils/media_url_resolver.dart`).
- [ ] Artwork covers use `ArtworkMediaResolver.resolveCover(...)` (`lib/utils/artwork_media_resolver.dart`).
- [ ] Avatars use `UserService.safeAvatarUrl(...)` (`lib/services/user_service.dart`).
- [ ] AR model launching/handling goes through `ARService` / `ARManager` (no custom URL/gateway logic).

Quick checks:
- `rg -n "ipfs\\.io|cloudflare-ipfs|gateway\\.pinata\\.cloud|/ipfs/" lib -S` (avoid introducing new gateway hardcodes)
- `rg -n "ipfs://" lib -S` (allowed only when immediately routed through resolvers)

## Feature Flags + Safe Fallbacks

- [ ] New UI/flows are gated using `AppConfig.isFeatureEnabled('<flag>')` and/or `ConfigProvider`.
- [ ] Backend routes respect env toggles and feature gates (e.g. `USE_MOCK_DATA`, `ENABLE_DEBUG_ENDPOINTS`, `ORBITDB_SYNC_MODE`, router `featureGate('<flag>')`).
- [ ] When a feature is disabled, the app remains functional (route calls skipped or gracefully degraded).
- [ ] Feature flags are treated as runtime conditions (no hardcoding "available" behavior).

## WebSockets (Idempotent + Feature-Gated)

- [ ] WebSocket connect is not triggered from `build()`; it happens from providers/services/bootstrap only.
- [ ] WebSocket connect is safe to call multiple times (no duplicate socket instances).
- [ ] Event handlers are registered idempotently (reconnect does not multiply listeners).
- [ ] Subscription APIs dedupe by wallet/conversation/room (no repeated joins).
- [ ] Connect/disconnect paths are safe across login/logout and app resume.
- [ ] Any new WS event is behind the same feature flag expectations as REST.

Reference implementation: `lib/services/socket_service.dart`.

## Desktop/Mobile Parity (Screens)

If you modify or add a screen under `lib/screens/`, mirror the change under `lib/screens/desktop/` using the **same providers/services/models**.

- [ ] Mobile screen updated: `lib/screens/...`
- [ ] Desktop counterpart updated: `lib/screens/desktop/...`
- [ ] Shared logic moved into providers/services (not duplicated across UIs).

Parity map (common entry points):
- Home: `lib/screens/home_screen.dart` <-> `lib/screens/desktop/desktop_home_screen.dart`
- Map: `lib/screens/map_screen.dart` <-> `lib/screens/desktop/desktop_map_screen.dart`
- Community: `lib/screens/community/*` <-> `lib/screens/desktop/community/*`
- Web3 wallet: `lib/screens/web3/wallet/*` <-> `lib/screens/desktop/web3/*`

## Analyzer Clean + Platform Safety

- [ ] `flutter analyze` is clean (no new warnings/errors).
- [ ] No `BuildContext` usage after `await` without a `mounted`/`context.mounted` guard.
- [ ] No `dart:html` imports (web-only code uses `package:web/web.dart` + conditional imports).
- [ ] No deprecated APIs are introduced; fix warnings in touched files.

Quick checks:
- `flutter analyze`
- `rg -n "import 'dart:html'" lib -S`
- `rg -n "await .*;\\s*$\\n\\s*.*context\\." lib -S` (spot-check for context-after-await patterns)

## Stable Response Envelope (Backend + Client Expectations)

The backend should return a consistent JSON envelope so `BackendApiService` can parse reliably and the UI can fail gracefully.

- [ ] Success responses include `success: true`.
- [ ] Success responses include `data` for the payload (optionally `message`, `count`, etc.).
- [ ] Error responses include `success: false` and a human-readable `error` string (optionally `details`).
- [ ] Avoid top-level arrays/primitives as responses; wrap in an object.
- [ ] Routes and shapes are documented/kept in sync with `docs/backend_route_map.md`.

Recommended shapes:

```json
{ "success": true, "data": { } }
```

```json
{ "success": false, "error": "Human readable message", "details": { } }
```
