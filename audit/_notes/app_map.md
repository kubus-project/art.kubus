# App Map Audit (MapLibre GL)

## Summary
The map flow is split between `MapScreen`/`DesktopMapScreen` and the shared `ArtMapView`. Marker rendering/tap handling depends on MapLibre style initialization. The most likely web rendering failure is a double-`assets/` prefix in style URL resolution, which can silently 404 the style JSON in production. Marker tap/floating card issues tie back to `_styleInitialized` never flipping true. On mobile, modal blocking logic is present; on web it is intentionally disabled, which causes touch-through gestures. The tutorial overlay uses a tap-only gesture handler, so drag/pan gestures can still reach the map beneath it.

## Findings
### AK-AUD-001 — Web map style URL can be double-prefixed, causing style load failure on web
**Root cause:** `MapStyleService._toWebAssetUrl` unconditionally prefixes `assets/` for paths that are already asset paths like `assets/map_styles/...`, resulting in `assets/assets/...` which is not a valid web asset URL. When this happens, MapLibre GL JS fails to load the style and the map remains blank.  
**Evidence:**
- `lib/services/map_style_service.dart:59-60` – web path resolution uses `_toWebAssetUrl(...)` for any non-URL style ref.
- `lib/services/map_style_service.dart:68-83` – `_toWebAssetUrl` only whitelists `assets/assets/`, `assets/packages/`, `assets/fonts/`, `assets/shaders/`, then prefixes `assets/` for everything else.

### AK-AUD-002 — Web style load fallback only enabled in dev; production web has no fallback
**Root cause:** The fallback style is guarded by `devFallbackEnabled`, which is only true for dev + debug. If the web style fails to load in release/prod (e.g., due to AK-AUD-001 or CORS in style JSON), the fallback never triggers and the map stays blank.  
**Evidence:**
- `lib/services/map_style_service.dart:14-20` – `devFallbackEnabled` is dev/debug only.
- `lib/widgets/art_map_view.dart:149-161` – timeout fallback only runs when `MapStyleService.devFallbackEnabled` is true.

### AK-AUD-003 — Marker taps (and floating card) are skipped until style initialization completes
**Root cause:** `_handleMapTap` exits early unless `_styleInitialized` is true. If style init never completes (e.g., due to AK-AUD-001/002), map clicks won’t resolve features and no marker card will show.  
**Evidence:**
- `lib/screens/map_screen.dart:2820-2827` – `_handleMapTap` returns when `_styleInitialized` is false.
- `lib/screens/map_screen.dart:2748-2760` – `_styleInitialized` is only set true in `_handleMapStyleLoaded` and set false on failure.

### AK-AUD-004 — Touch-through modal/gesture issues on web due to disabled blocking
**Root cause:** `_shouldBlockMapGestures` explicitly returns `false` on web, so the map continues to receive gestures even when the bottom sheet or overlays are open. The `IgnorePointer`/`ModalBarrier` guards are only active when `_shouldBlockMapGestures` is true.  
**Evidence:**
- `lib/screens/map_screen.dart:1320-1323` – `_shouldBlockMapGestures` returns `false` when `kIsWeb`.
- `lib/screens/map_screen.dart:2395-2402` – map is wrapped with `IgnorePointer`, and the `ModalBarrier` only appears if `_shouldBlockMapGestures` is true.
- `lib/screens/map_screen.dart:2557-2560` – map gesture flags are tied to `!_shouldBlockMapGestures`.

### AK-AUD-005 — Tutorial overlay doesn’t block drag/scroll; map can still pan underneath
**Root cause:** The tutorial overlay uses a `GestureDetector` that only handles `onTapUp`. It doesn’t absorb drag/scroll gestures, so panning/zooming can bleed through to the map while the overlay is active.  
**Evidence:**
- `lib/widgets/tutorial/interactive_tutorial_overlay.dart:155-165` – overlay only listens for tap events, no drag/scroll handlers or `AbsorbPointer`.

### AK-AUD-006 — Floating card anchoring depends on projection; anchor stays null if style not ready
**Root cause:** `_refreshSelectedMarkerAnchor` requires a valid MapLibre projection and `_styleInitialized`. If projection fails or style never initializes, `_selectedMarkerAnchor` remains null and the card is positioned via fallback centering, which is less reliable and may appear “missing” if the overlay is off-screen.  
**Evidence:**
- `lib/screens/map_screen.dart:2139-2151` – anchor update is skipped unless `_styleInitialized` and `toScreenLocation` succeeds.
- `lib/screens/map_screen.dart:3383-3398` – fallback positioning depends on `_selectedMarkerAnchor` and can be clamped away from the marker.

### AK-AUD-007 — Web build “unreachable code” warnings are known to occur in platform/env helpers
**Root cause:** Several helpers have comments noting DDC “unreachable code” warnings, tied to early-return and exhaustive switch patterns in web debug builds. These warnings aren’t map-specific but show up in web build logs.  
**Evidence:**
- `lib/config/config.dart:314` – comment about “unreachable code after return” in generated debug JS.
- `lib/providers/platform_provider.dart:35` – comment about avoiding early returns to prevent unreachable code warnings.
- `lib/services/telemetry/telemetry_service.dart:397` – comment about avoiding DDC unreachable code warnings.

## Top P0 / P1
- **P0:** AK-AUD-001 – style URL double-prefixing on web can 404 the style JSON and result in a blank map.
- **P0:** AK-AUD-002 – no production fallback if style load fails; leaves web map blank.
- **P1:** AK-AUD-004 – web touch-through gestures cause modal/bottom-sheet interaction bugs.
- **P1:** AK-AUD-005 – tutorial overlay doesn’t block map drag/scroll.
- **P1:** AK-AUD-003/006 – marker tap + floating card depend on style init / projection; breaks when style is not loaded or projection fails.

## Files Reviewed
- `lib/screens/map_screen.dart` — map flow, marker taps, overlays, gesture blocking
- `lib/screens/desktop/desktop_map_screen.dart` — desktop map flow and marker tap handling
- `lib/widgets/art_map_view.dart` — MapLibre widget wrapper, style load, web resize
- `lib/widgets/map_marker_dialog.dart` — marker creation dialog flow
- `lib/widgets/tutorial/interactive_tutorial_overlay.dart` — tutorial overlay hit-testing
- `lib/services/map_style_service.dart` — style resolution & web asset URL mapping
- `lib/services/map_marker_service.dart` — marker loading + socket updates
- `lib/config/config.dart` — map style config, web warnings comment
- `lib/providers/platform_provider.dart` — web warning comment
- `lib/services/telemetry/telemetry_service.dart` — web warning comment
