# Map duplication heatmap (mobile vs desktop)

Compared files:
- `lib/screens/map_screen.dart` (mobile)
- `lib/screens/desktop/desktop_map_screen.dart` (desktop)

> Goal: identify highest-ROI extractions to reduce duplicated LOC and centralize single-source-of-truth behavior.

## Current shared helpers (already extracted)

- `lib/widgets/map/kubus_map_marker_rendering.dart`
- `lib/widgets/map/kubus_map_marker_geojson_builder.dart`
- `lib/widgets/map/kubus_map_marker_features.dart`

These reduce duplication in clustering + icon prereg + GeoJSON feature building, but the biggest remaining duplication is screen-level orchestration.

## Ranked duplication hotspots

Coupling scale: **1 = mostly pure**, **5 = heavy state + callbacks + async side effects**.

| Rank | Duplicated item | Est. duplicated LOC | Coupling | Notes |
|---:|---|---:|:---:|---|
| 1 | MapLibre style + sources/layers bootstrap (`_handleMapStyleLoaded`) | ~330–360 | 5 | Complex controller mutation + managed IDs + platform diffs |
| 2 | Marker layer style updates (queued apply + expression builders) | ~170–180 | 4 | High-frequency; many state inputs (hover/press/select/3D) |
| 3 | Map tap hit-testing + fallback pick (hitbox query + cluster zoom) | ~230–260 | 4 | QueryRenderedFeatures + selection side effects + web diffs |
| 4 | Marker GeoJSON sync orchestration around shared helpers | ~180–220 | 4 | Similar “glue” with subtle param differences |
| 5 | Travel/isometric prefs load + toggle | ~70–90 | 3 | SharedPreferences + invalidate/refresh |
| 6 | Feature tap/hover binding + hover state | ~110–140 | 3 | Listener wiring + hover + debug |
| 7 | Tutorial flow plumbing (seen + index navigation) | ~90–130 | 2–3 | Steps differ; coordinator is shareable |
| 8 | Polling pause/resume skeleton | ~70–110 | 3 | Same cancel/debounce/queue; different subscriptions |
| 9 | Theme resync plumbing | ~50–70 | 2–3 | Safe extraction |
| 10 | Marker loading/merge pipeline | ~150–250 | 5 | High regression risk (selection reconciliation differs) |

## Detail by item (paths, ranges, extractability, proposed destination)

### 1) MapLibre style + sources/layers bootstrap

- **Signatures**:
  - Mobile: `Future<void> _handleMapStyleLoaded(ThemeProvider themeProvider)`
  - Desktop: `Future<void> _handleMapStyleLoaded(ThemeProvider themeProvider)`
- **Approx ranges**:
  - Mobile: ~`532–883`
  - Desktop: ~`1106–1478`
- **Extractability**: **Hard** (very coupled)
- **Proposed destination**: `lib/features/map/map_layers_manager.dart`
  - `MapLayersManager.installStyleLayers(...)` + hooks for desktop-only pending marker layers.

### 2) Marker layer style updates + expression builders

- **Approx ranges**:
  - Mobile: ~`2534–2708`
  - Desktop: ~`5881–6057`
- **Extractability**: **Medium (high ROI)**
- **Proposed destination**: `lib/features/map/map_layers_manager.dart`
  - `MapLayersManager.applyMarkerLayerStyle(...)` or `KubusMarkerLayerStyler`.

### 3) Map tap hit-testing + fallback pick

- **Approx ranges**:
  - Mobile: ~`4325–4575`
  - Desktop: ~`1508–1743`
- **Extractability**: **Medium**
- **Proposed destination**: `lib/features/map/map_marker_interaction.dart`
  - Shared hit-test engine with callbacks for screen-specific side effects.

### 4) Marker GeoJSON sync orchestration

- **Approx ranges**:
  - Mobile: ~`4606–4813`
  - Desktop: ~`1805–2100`
- **Extractability**: **Medium**
- **Proposed destination**: `lib/features/map/map_layers_manager.dart`

### 5) Travel/isometric prefs

- **Approx ranges**:
  - Mobile: ~`1245–1310`
  - Desktop: ~`372–440`
- **Extractability**: **Easy**
- **Proposed destination**: `lib/features/map/map_core_view.dart` (or `lib/features/map/prefs/` helper).

### 6) Feature tap/hover binding

- **Approx ranges**:
  - Mobile: ~`403–530`
  - Desktop: ~`755–860`
- **Extractability**: **Medium**
- **Proposed destination**: `lib/features/map/map_marker_interaction.dart`

### 7) Tutorial coordinator scaffolding

- **Approx ranges**:
  - Mobile: ~`1317–1450`
  - Desktop: ~`443–550`
- **Extractability**: **Medium**
- **Proposed destination**: `lib/features/map/map_overlay_stack.dart` (tutorial overlay host) + helper under `lib/features/map/tutorial/`.

### 8) Polling lifecycle skeleton

- **Extractability**: **Medium**
- **Proposed destination**: `lib/features/map/map_core_view.dart` (lifecycle + cleanup).

### 9) Theme resync helper

- **Extractability**: **Easy**
- **Proposed destination**: `lib/features/map/map_core_view.dart`

### 10) Marker loading/merge pipeline

- **Extractability**: **Hard / risky** (defer until controller + selection are unified)

## Top 5 extraction targets (highest ROI)

1. Marker layer styling (queued apply + expressions)
2. Hit-testing engine (hitbox query + cluster zoom + fallback pick)
3. Style/layers bootstrap installer (common subset)
4. Travel/isometric prefs helper
5. Tutorial coordinator scaffolding

## Suggested extraction order

1) B: shared controller/lifecycle + prefs + tutorial coordinator
2) C: overlay stack + pointer/gesture contract
3) D: layers manager (install once; update via `setGeoJsonSource`)
4) E: perf instrumentation + leak cleanup
