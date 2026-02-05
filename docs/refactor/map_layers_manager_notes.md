# MapLayersManager notes

This document captures the canonical MapLibre **sources/layers/images** used by the app map and the ordering/constraints that `MapLayersManager` enforces.

## Canonical IDs

These IDs are treated as stable contracts between the screens and `MapLayersManager`.

### Sources

- `kubus_markers` (marker feature collection)
- `kubus_marker_cubes` (3D cube extrusion feature collection)
- `kubus_user_location` (user location point feature collection)
- `kubus_pending_marker` (desktop only; pending marker point feature collection)

### Layers

- `kubus_marker_cubes_layer` (fill-extrusion; 3D cubes)
- `kubus_marker_layer` (symbol layer; 2D marker icons)
- `kubus_marker_cubes_icon_layer` (symbol layer; 3D mode floating icons)
- `kubus_marker_hitbox_layer` (symbol layer with transparent square image; falls back to an invisible circle layer if symbol fails)
- `kubus_user_location_layer` (circle layer)
- `kubus_pending_marker_layer` (desktop only; circle layer)

### Images

- `kubus_hitbox_square_transparent` (1×1 transparent PNG registered once per style epoch)

## Ordering constraints

`ensureInitialized(styleEpoch)` installs everything in a deterministic order after a style load:

1. **Sources first** (markers → cubes → location → pending)
2. **Layers next** (bottom to top):
   1) cube extrusion (`kubus_marker_cubes_layer`)
   2) 2D marker symbols (`kubus_marker_layer`)
   3) 3D cube floating icon symbols (`kubus_marker_cubes_icon_layer`)
   4) marker hitbox (`kubus_marker_hitbox_layer`)
   5) location circle (`kubus_user_location_layer`)
   6) pending circle (`kubus_pending_marker_layer`, desktop only)

This ordering matches the prior duplicated logic in `MapScreen` and `DesktopMapScreen`.

## Mode switching (2D vs 3D)

`MapLayersManager.setMode(MapRenderMode)` performs deterministic visibility toggles:

- `twoD`: marker symbol layer visible, cube layers hidden
- `threeD`: cube extrusion + cube icon visible, marker symbol hidden

No layer re-adds occur during mode switching.

## Safety + idempotency

- `onNewStyle(styleEpoch)` must be called whenever a style is reloaded (style epoch increments).
- `ensureInitialized(styleEpoch)` is idempotent per epoch and guarded with an in-flight completer.
- All MapLibre mutations are **best-effort** (try/catch).
- `safeSetLayerProperties`, `safeSetLayerVisibility`, `safeSetPaintProperty`, `safeSetLayoutProperty` are no-ops when the manager does not believe the layer exists.

## Screen integration points

### Mobile

- `lib/screens/map_screen.dart`
  - Instantiate manager on `onMapCreated` using `MapLibreLayersController(controller)`.
  - In `_handleMapStyleLoaded`: call `onNewStyle`, `updateThemeSpec`, then `await ensureInitialized`.
  - For 2D/3D toggling: delegate to `setMode`.

### Desktop

- `lib/screens/desktop/desktop_map_screen.dart`
  - Instantiate manager in `_handleMapCreated`.
  - In `_handleMapStyleLoaded`: call `onNewStyle`, `updateThemeSpec` (includes pending colors), then `await ensureInitialized`.
  - For 2D/3D toggling: delegate to `setMode`.
