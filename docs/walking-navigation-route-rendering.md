# Walking navigation: route rendering and routing source

Status: 2026-07-21. Supersedes the rendering notes in
`docs/walking-navigation-flow-implementation-note.md`.

## Reported defect

The user selects in-app walking navigation, the navigation map opens, and no
pedestrian route line is drawn.

## Pipeline stages

The route pipeline is diagnosed as discrete stages, each with a coordinate-free
diagnostic event (`WalkingNavigationDiagnostics`):

| # | Stage | Event |
|---|-------|-------|
| 1 | Walking intent exists | `session_started` |
| 2 | Fresh live origin acquired | `location_request_started`, `live_fix_acquired` |
| 3 | `WalkingDirectionsApi.route()` called | `route_request_started` |
| 4 | Routing source returns usable data | — |
| 5 | `WalkingRoute` with >= 2 valid points | `route_created` (`points=N`) |
| 6 | `toGeoJson()` has a valid `LineString` | `geojson_created` (`features=N`) |
| 7 | MapLibre route source exists | `route_source_write_failed reason=sourceMissing` |
| 8 | GeoJSON written to the source | `route_source_write_started` / `_succeeded` |
| 9 | Route layers exist | `route_visibility_failed reason=layerMissing` |
| 10 | Route layers visible | `route_visibility_succeeded` |
| 11 | Filters match route features | covered by layer-filter tests |
| 12 | Camera viewport contains the route | `route_camera_fitted` |
| 13 | Route visually distinguishable | `route_visually_ready` |

No event carries coordinates; `reason` values are bounded to 64 characters.

## Root cause (stage 3)

`WalkingNavigationProvider.updatePosition` only started routing when the status
was exactly `awaitingLocation`:

```dart
if (_status == WalkingNavigationStatus.awaitingLocation || ...) {
  await _requestRoute(position, preserveCurrentRoute: false);
}
```

Both map screens call `beginLocationRequest()` before acquiring a fix, which
moves the status to `requestingPermission`. Nothing ever moved it back. The
first live fix therefore hit the `_route == null` branch, notified listeners,
and returned — **`WalkingDirectionsApi.route()` was never called at all**, so
every stage from 4 onward was dead. The session sat in `requestingPermission`
indefinitely.

The fix routes on any live fix received while the session still has no route:

```dart
final needsFirstRoute = _route == null &&
    _status != WalkingNavigationStatus.calculating &&
    _status != WalkingNavigationStatus.error;
```

`_requestRoute` already de-duplicates in-flight requests per generation, and
route (non-location) failures still require an explicit retry, so this does not
loosen throttling.

### Why the PR #33 tests did not catch it

`test/providers/walking_navigation_provider_test.dart` drives
`prepare(intent)` then `updatePosition(...)` directly. It never calls
`beginLocationRequest`, which production always calls. No test in the repository
referenced `beginLocationRequest` at all. PR #33 also documented that "the local
release build had no artwork dataset, so real-browser sheet and live-GPS route
capture were unavailable" — the end-to-end path was never exercised.

`test/providers/walking_navigation_startup_sequence_test.dart` now reproduces
the production call order exactly.

## Rendering synchronization design

`WalkingNavigationMapCoordinator` previously cached before confirming:

```dart
_lastRoute = route;
await manager.upsertWalkingRouteData(...);   // could throw and be swallowed
```

`MapLayersManager` caught MapLibre errors and returned `void`, so a write that
failed during a style/source race was permanently treated as applied: the route
object stayed identical, so no rebuild ever retried it.

The coordinator now:

- writes through a **serialized queue** — one mutation in flight, at most one
  (latest) queued, so an older revision can never overwrite a newer one;
- tags every write with a **revision** and the **style epoch** it targets;
- updates `_renderedRoute` / `_renderedVisibility` **only after** MapLibre
  confirms the mutation, and clears both when a visibility write fails so the
  next sync redoes the whole pair;
- drops confirmed state when `MapLayersManager.initializedStyleEpoch` changes,
  which re-writes the retained route onto the new style's source and layers;
- applies a **route overview** camera fit once per route before follow mode, and
  keeps `isRouteOverviewActive` set until the user taps Resume so passive
  location centering cannot throw the fitted route out of the viewport.

`MapLayersManager.upsertWalkingRouteData` and `setWalkingNavigationVisibility`
now return `WalkingRouteMutationResult`, distinguishing `success`,
`sourceMissing`, `layerMissing`, `styleNotReady`, `staleStyleEpoch`,
`invalidGeometry`, `controllerRejected`, and `platformError`. Generic map
operations remain best-effort; only walking-route rendering is observable and
retryable.

Walking-route source and layer installation is additionally wrapped in its own
guard inside `_installLayersForStyle`. Previously a single MapLibre failure
there aborted the whole style install, leaving the map with no markers and no
location layer; now it degrades to a typed, retryable `sourceMissing` state.

## GeoJSON validation

`WalkingRoute.toGeoJson()` previously emitted `points.sublist(graphStart,
graphEnd + 1)` unconditionally. When the routable graph slice collapsed to a
single node the primary `kind == 'route'` feature was silently dropped and only
dashed connectors remained — the route layer filter matched nothing and no line
was drawn, from a nominally successful routing result.

It now:

- discards non-finite and out-of-bounds coordinates;
- collapses consecutive duplicate vertices (1e-7 epsilon);
- emits the **complete route** as the primary route when the graph slice has
  fewer than two distinct points;
- returns an empty collection (instead of throwing on `clamp`) for empty or
  single-point routes, and the coordinator refuses to write an empty collection
  for a non-null route, reporting `invalidGeometry` instead.

## Layer filters

The three route layers are installed with

```dart
['==', ['get', 'kind'], 'route']       // casing + route
['==', ['get', 'kind'], 'connector']   // dashed graph-snap connectors
```

These were captured unchanged and verified to match at runtime on
`maplibre_gl 0.26.1` / `maplibre_gl_web` in Chrome: the deterministic route
renders with both the solid route line and the dashed connector visible. No
speculative filter-syntax change was made.

## Routing-source findings (measured 2026-07-21, Chrome, localhost origin)

Both configured `OVERPASS_WALKING_ENDPOINTS` were exercised from a real browser
origin with the production query and a fixed Ljubljana bounding box
(`46.047,14.502,46.053,14.511`):

| Endpoint | Status | Bytes | Elements | Nodes | Ways | Elapsed |
|---|---|---|---|---|---|---|
| `https://overpass-api.de/api/interpreter` | 200 | 353,084 | 2,654 | 2,017 | 637 | 694 ms |
| `https://overpass.private.coffee/api/interpreter` | `TypeError: Failed to fetch` | — | — | — | — | 318,806 ms |

Conclusions:

- The primary endpoint works from a browser: CORS is permitted, the response is
  well-formed JSON, and it is comfortably inside the 8 MB response bound.
- **The configured fallback endpoint is not usable from a browser.** It neither
  completed nor returned CORS headers, failing only after more than five
  minutes. In the deployed web app the effective failover depth is therefore
  one, not two: if the primary endpoint is throttled (public Overpass instances
  enforce per-IP quotas) or unavailable, walking navigation has no working
  source.
- The service does bound its own requests (20 s timeout, 1 s minimum interval,
  8 MB / 160k element caps, abortable requests), so a hanging fallback costs one
  timeout rather than hanging the UI.

### Recommendation (not implemented here)

This change does not add backend work, because the evidence shows the rendering
pipeline — not the routing source — was the reported defect, and the primary
endpoint is functional. The measured fallback failure is nonetheless a real
production risk. The smallest production-safe follow-up is a bounded
art.kubus-owned Overpass proxy:

- `POST /api/walking-graph` accepting only a bounding box, validated to the same
  bounds the client already enforces;
- strict per-IP rate limiting and response-size caps;
- no persistence of precise coordinates (log bbox area and element counts only);
- configured as the first entry in `OVERPASS_WALKING_ENDPOINTS`, keeping the
  public interpreter as fallback.

That work belongs in a separate branch in the backend repository and is not
required to make the route render.

## Focused navigation mode

Walking navigation is entered as its own pushed route
(`MapNavigation.openWalking` -> `Navigator.push(MapScreen(...))`), so the shell
that owns the bottom tab bar is not in the tree. Previously the screen still
reserved `KubusLayout.mainBottomNavBarHeight` for a bar nothing rendered, and
kept the browse chrome (search bar, Discovery Path chip, Nearby Art sheet) on
top of a navigation session.

Walking navigation is now an explicit focused mode (`_isWalkingFocusedMode`):

- the search bar, Discovery Path chip, and Nearby Art sheet are suppressed;
- the bottom-nav reservation is dropped and map controls sit against the safe
  area instead;
- a persistent back/exit control is rendered top-left — it cannot live in the
  instruction panel, which hides itself once the session goes idle;
- ending navigation pops the route instead of stranding the user on a
  chrome-less map.

This keeps PR #33's pushed-map entry; no shell rewrite was required.

## Retry and self-healing

Runtime capture showed the failure mode this design exists for. In a dark-theme
cold start the map style reloads after the session begins, and the sequence was:

```
session_started
location_request_started
route_render_deferred reason=styleNotReady
route_request_started
live_fix_acquired
route_created reason=points=6
route_render_deferred reason=newController
geojson_created reason=features=3
route_source_write_started
route_source_write_succeeded
route_visibility_succeeded
route_camera_fitted
route_visually_ready
```

Before the retry existed, the run stopped permanently after `route_created`: the
sync that followed the route arriving found the style mid-reload, bailed, and
nothing external ever called `sync` again, because no further provider
notification was coming. The coordinator now schedules its own bounded retry
(250 ms interval, 40 attempts max, cancelled on success and on dispose) whenever
it cannot proceed, and `resetForMapController` re-arms it for a recreated
controller.

## Debug rendering harness

`/debug/walking-route` (debug builds only — gated behind
`WalkingNavigationDebugHarness.isEnabled`, which is an assert-only flag, so
release builds cannot reach the route) injects a fixed six-point Ljubljana route
through the **production** pipeline: provider, `toGeoJson`, coordinator,
`MapLayersManager`, the real MapLibre source and layers, visibility, and the
camera fit. Only the routing source and location source are substituted.

`/debug/walking-route?live=1` keeps the deterministic location but uses the real
`WalkingDirectionsService`, which separates routing-source failures from
rendering failures.

There is no test-only drawing implementation.
