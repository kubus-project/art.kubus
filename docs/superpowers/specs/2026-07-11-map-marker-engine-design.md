# Slice 3 — Shared Map Marker Sync Engine

Date: 2026-07-11
Status: Executing under the standing UI-overhaul mandate (roadmap item 3,
"map engine unification", scoped down per measurement).

## Measurement (2026-07-11, master @ slice-2 merge)

The 2026-02 unification audit (docs/refactor/unification_audit.md) is mostly
executed — search system, glass buttons/chips, map prefs controller, marker
feature building (`kubusBuildMarkerFeatureList`, `kubusMarkerFeatureFor`,
`kubusClusterFeatureFor`), collision/filtering/overlay planning all live in
`lib/features/map/` + `lib/widgets/map/`. What remains duplicated between
`map_screen.dart` (5,720 L) and `desktop_map_screen.dart` (6,004 L) is the
**marker sync orchestration layer**:

| Function | mobile | desktop | similarity |
|---|---|---|---|
| `_syncMapMarkersSafe` | 10 L | 10 L | 0.90 |
| `_syncMapMarkers` | 79 L | 71 L | 0.87 |
| `_preregisterMarkerIcons` | 28 L | 28 L | 0.89 |
| `_markerFeatureFor` | 29 L | 29 L | **identical** |
| `_clusterFeatureFor` | 27 L | 27 L | **identical** |

Known real divergences to preserve behind host hooks (behavior-preserving):
- mobile: `TimelineTask` perf tracing, 3D marker-cube sync when
  `_renderCoordinator.is3DModeActive`, `_debugMarkerSourceWriteCount`.
- desktop: `sortClustersBySizeDesc: false` (mobile `true`), pending-marker
  handling around style loads.
- `_handleMapStyleLoaded` is only 0.74 similar — **out of scope** this slice
  (it wires screen-specific layer setup); revisit later.

## Design

New `lib/features/map/engine/kubus_map_marker_sync_engine.dart`:

- `abstract class KubusMapMarkerSyncHost` — what the engine needs from the
  hosting `State`: `mapController`, `styleInitialized`, `hostMounted`,
  `managedSourceIds`, `markerSourceId`, `kubusMapController`,
  `registeredMapImages`, `lastZoom`, `clusterMaxZoom`,
  `clusterGridLevelForZoom(zoom)`, `markerPixelRatio()`,
  `resolveArtMarkerColor(marker, themeProvider)`, `hostContext`,
  `sortClustersBySizeDesc`, `debugLabel`, and hooks
  `onAfterMarkerSourceWrite()` (debug counter) +
  `afterSync(themeProvider)` (mobile 3D cubes; desktop no-op).
- `class KubusMapMarkerSyncEngine` — owns `syncSafe/sync/preregisterIcons/
  markerFeatureFor/clusterFeatureFor`, byte-ported from the current bodies
  with host lookups replacing field access.
- Both screen `State`s implement the host interface and delegate; the five
  private methods are deleted from each screen (~150 L per screen).

No visual or behavioral change intended. Divergences stay divergent via the
host (notably cluster sorting) — unifying them is a later, deliberate choice.

## Verification bar

- `flutter analyze` + `dart run custom_lint` clean; ratchet stays 0/0/0/0.
- Map suites: `test/widgets/map/`, map-named tests — zero new failures.
- Full suite: +1235 ~1 -1 baseline (one pre-existing TabBar failure).
- Visual: project verify skill — guest map loads, markers render, cluster
  + tap-select still work on web (mobile viewport) and desktop width.

## Outcome (2026-07-11)

- `KubusMapMarkerSyncEngine` + `KubusMapMarkerSyncHost` landed in
  `lib/features/map/engine/`; both screens implement the host and keep two
  thin `_syncMapMarkers*` delegators (zero call-site churn). The
  `_preregisterMarkerIcons` / `_markerFeatureFor` / `_clusterFeatureFor`
  trios are deleted from both screens (-130 L mobile, -119 L desktop).
- Divergences preserved via host: cluster sort order, zoom field, debug
  counters; desktop additionally gains perf-timeline tracing (gated by
  MapPerformanceDebug, previously mobile-only).
- Verified: analyze + custom_lint clean (ratchet 0/0/0/0), 76 map widget
  tests pass, full suite +1235 ~1 -1 (identical to baseline), visual pass
  of BOTH hosts on web (mobile viewport guest map + desktop shell map).
- Noted for later: desktop Home center pane shows 'An unexpected error
  occurred' offline (backend-dependent; unrelated to map diff).
