# lib/screens/ — Agent Notes (repo-grounded)

## Mission
Deliver stable, theme-consistent UI with feature flags and safe async handling.

Preflight: review all `AGENTS.md` files (root, `lib/**`, `backend/**`) before making changes.

## Theme + tokens
- Use `Theme.of(context).colorScheme` and `ThemeProvider.accentColor`.
- Use tokens from `lib/utils/design_tokens.dart` (`KubusSpacing`, `KubusRadius`, `KubusLayout`, `KubusTypography`).
- Use semantic roles from `lib/utils/kubus_color_roles.dart` and `AppColorUtils` for markers/feature accents.

## Media resolution
- Use `ArtworkMediaResolver.resolveCover(...)` and `MediaUrlResolver.resolve(...)` (see `lib/utils/*_resolver.dart`).

## Map UX rules (from `lib/screens/map_screen.dart`)
- Travel mode + isometric view are gated by `AppConfig.isFeatureEnabled('mapTravelMode'|'mapIsometricView')`.
- Avoid caching context-backed loaders: “Do not cache a BuildContext-backed loader as a field/getter.”
- Permission/service prompts are throttled and persisted (see `_kPrefLocationPermissionRequested`).
- Marker colors must use `AppColorUtils.markerSubjectColor(...)` + `KubusColorRoles`.

## AR UX rules (from `lib/screens/art/ar_screen.dart`)
- AR is platform‑gated; on web the screen redirects to `DownloadAppScreen`.
- Keep AR chrome transparent so global gradient can paint.

## Async safety
- After any `await`, guard `if (!mounted) return;` (see `MapScreen` and `ARScreen`).

## Audit watchlist (screens)
- Tutorial overlays must block pointer gestures on web (no touch-through to map).
- Map web style URL handling must avoid double `assets/` prefix and use production-safe fallback styles.

## Evidence (direct quotes with line references)
- `lib/screens/map_screen.dart` (lines 183, 257, 292):
	- “// Avoid repeatedly requesting permission/service on each timer tick”
	- “// Travel mode is viewport-based (bounds query), not huge-radius.”
	- “/// NOTE: Do not cache a BuildContext-backed loader as a field/getter.”
- `lib/screens/art/ar_screen.dart` (lines 37–38, 319):
	- “/// AR Screen with seamless Android and iOS support”
	- “/// On web, redirects to download app screen”
	- “// Keep AR chrome transparent so the root gradient can still paint.”
