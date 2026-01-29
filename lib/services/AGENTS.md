# lib/services/ — Agent Notes (repo-grounded)

## Mission
Keep services reusable and centralized: all backend I/O, storage, auth, and AR live here.

## Storage + media rules
- Storage resolution must go through `StorageConfig.resolveUrl(...)` (`lib/services/storage_config.dart`).
- UI/media callers should use `MediaUrlResolver.resolve(...)` (`lib/utils/media_url_resolver.dart`).
- Artwork cover selection must use `ArtworkMediaResolver.resolveCover(...)` (`lib/utils/artwork_media_resolver.dart`).
- IPFS gateway selection + overrides are centralized in `StorageConfig` (`IPFS_GATEWAY`, `IPFS_GATEWAYS`).

## Backend API access
- Use `BackendApiService` as the single API gateway (`lib/services/backend_api_service.dart`).
	- Auth tokens are loaded/issued via `ensureAuthLoaded()` / `_ensureAuthBeforeRequest()`.
	- Re-auth handling and retry logic are centralized in `_request()`.
	- Avoid direct `http` usage in providers/screens unless there is no service.

## AR services
- AR entrypoint is `ARService` (`lib/services/ar_service.dart`).
	- It resolves model URLs via `StorageConfig.resolveUrl(...)` before launching AR viewers.
- AR integration orchestration uses `ARIntegrationService` / `ARManager` (imported in screens).

## Logging
- Use `AppConfig.debugPrint(...)` and guard logs with `kDebugMode` where needed.
- `BackendApiService` includes `_debugLogThrottled(...)` to avoid log spam; follow that pattern.

## Modeling
- Service-local structs must be named with `*Dto`, `*Payload`, or `*Record`.
- Do not introduce new domain models that collide with existing ones (`Artwork`, `ArtMarker`, etc.).

## UI separation
- Services must not depend on widgets or UI colors. Use the theme system from `lib/utils/design_tokens.dart` at the UI layer instead.

## Evidence (direct quotes with line references)
- `lib/services/storage_config.dart` (lines 59–60):
	- “/// Resolve storage URLs by handling IPFS CIDs and backend-relative paths.”
	- “/// Falls back to the configured HTTP backend for relative paths.”
- `lib/utils/media_url_resolver.dart` (lines 6–8):
	- “/// Shared media URL resolver for images, models, and other assets.”
	- “/// Centralizes IPFS and backend-relative path handling so widgets and providers don't re‑implement gateway logic or base URL fallbacks.”
- `lib/utils/artwork_media_resolver.dart` (line 4):
	- “/// Centralizes artwork media URL resolution so every screen shows the same cover image with IPFS/HTTP fallbacks applied consistently.”
- `lib/services/backend_api_service.dart` (lines 31–32, 333):
	- “/// Provides a centralized interface for all backend API calls.”
	- “/// Handles authentication, error handling, and data transformation.”
	- “/// Ensure auth token is loaded. If token missing and wallet provided,”
- `lib/services/ar_service.dart` (lines 9–10):
	- “/// Professional AR Service using Google ARCore Scene Viewer and ARKit Quick Look”
	- “/// Supports IPFS models via HTTP gateways”
