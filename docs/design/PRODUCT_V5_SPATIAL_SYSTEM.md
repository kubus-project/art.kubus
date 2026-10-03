# PRODUCT v5 — spatial map system (Wave 5B)

Status: implemented reality of Wave 5B on `feat/product-v5-spatial-system`
(base `dev@9109d65e`). Everything below is what the code does today; limits and
unverified platforms are listed explicitly at the end. Nothing here is a
roadmap item.

The map is the anonymous entry surface (see `GUEST_FIRST_ENTRY.md`, frozen).
Wave 5B makes it one coherent world → region → country → city → street →
artwork experience **without a second map implementation**: the same
`maplibre_gl ^0.26.2` plugin, the same `KubusMapController`,
`MapLayersManager` and `KubusMapMarkerSyncEngine`, the same two screens.

## 1. Ownership (unchanged, extended)

| Concern | Owner |
| --- | --- |
| Camera, selection, style epoch, gestures, same-coordinate spiderfy | `KubusMapController` |
| Sources, layers, layer styling, image registration | `MapLayersManager` (+ `KubusMarkerLayerStyler`) |
| Marker features, clustering, icons, covers | `KubusMapMarkerSyncEngine` |
| Direct targets (deep link, search artwork) | `MapTargetCoordinator` + `MapTargetIntent` |
| Renderer capability | `KubusMapCapabilities` (new, one value) |
| Framing vocabulary / globe minimum zoom | `MapSpatialFraming` (new, pure) |
| Marker level of detail policy | `KubusMarkerLod` (new, pure) |
| What restricts results | `resolveMapConstraints` (new, pure) + `KubusMapConstraintStrip` |

New files are pure policy or one widget; none owns a renderer, camera or
selection. There is no `MapEngineV2`, second MapLibre wrapper, second map
screen or second selection state.

## 2. Globe capability (Wave 5B-0 measured result)

`maplibre_gl 0.26.2` has **no projection API**. The only way to ask for a globe
is a style-level `"projection": {"type": "globe"}`. The probe (a throwaway app
using the same plugin and the same Kubus styles, outside the repo) found:

| Platform / runtime | Globe? | Notes |
| --- | --- | --- |
| Web, Chromium, MapLibre GL JS **5.24.0** | **Yes** | camera, bearing, pitch, wheel / drag / ctrl-wheel pinch, custom GeoJSON, circle + symbol layers, `queryRenderedFeatures`, `setFeatureState`, `setStyle` theme swap all work |
| Web, Firefox, MapLibre GL JS 5.24.0 | **Yes** | same results (software WebGL; allow longer settle) |
| Web, any, MapLibre GL JS **4.7.1** (what the app vendored before 5B) | No | the `projection` key is silently ignored: flat |
| Android emulator, MapLibre Native 13.3.0 | No | style accepted, renders flat Mercator (screenshot evidence) |
| iOS, MapLibre Native 6.27.0 | Not testable here | no macOS host; treated as flat until someone verifies it |
| Physical Android | Not available | none attached; no physical-device claim is made anywhere |

Other measured facts that shaped the design:

* `setFeatureState` is implemented on web only (native throws
  `UnimplementedError`), so nothing in the product depends on feature state.
  Selection is expression based (`['==', ['id'], selectedId]`), as before.
* A style swap drops every custom layer on every platform; the existing style
  epoch machinery re-installs them (unchanged).
* On the web globe, `getVisibleRegion()` is degenerate below roughly zoom 2
  (`west == east == -180`); the globe minimum zoom keeps the camera out of that
  range for any realistic viewport.
* MapLibre's globe `getZoom()` is the Mercator zoom at the *centre latitude*;
  its minimum-zoom constraint applies at the equator, and the visible disc is a
  perspective silhouette smaller than the sphere's front diameter.

### Adapter (the whole capability boundary)

* `KubusMapCapabilities.supportsGlobe` — `true` only on web with the
  `mapGlobe` feature flag (`MAP_GLOBE_ENABLED`, default on). One pure
  `resolve(isWeb, globeEnabled)` rule, unit tested as a matrix.
* `MapStyleService.resolveStyleString(ref, globe: true)` stamps
  `projection: globe` onto a bundled style at load time on web
  (`withGlobeProjection`). Remote style URLs are left as their owner wrote
  them. The bundled style files stay flat (a test asserts it), so native
  platforms never see the key.
* The vendored web runtime moved from MapLibre GL JS 4.7.1 to **5.24.0**
  (`web/local/maplibre-gl`, the version the plugin README names). A test fails
  the build if the vendored banner drops below 5.x or the bundle and worker
  disagree.
* `ArtMapView` enforces a viewport-dependent minimum zoom on the globe
  (`MapSpatialFraming.globeMinZoomFor`) so the globe always fills 92 % of the
  shorter side and never shrinks into "a small ball in an empty field". The
  formula models MapLibre's perspective camera and matches the measured render
  at 1440x900 (predicted 0.787 of the sphere diameter, rendered 0.786). The flat
  map keeps its minimum zoom 3.
* On web the space around the globe takes the theme's map ground colour
  (`setWebMapGroundColor`) instead of the static boot teal.

### Fallback

Android, iOS and any web build with the flag off render the flat Mercator map
with the **same** framing levels, level of detail, selection, clusters, filters
and constraints. A missing globe is never a blank screen, an unsupported
product or a second renderer.

## 3. Framing levels

`MapSpatialFraming.levelForZoom` (shared by both renderers; both use the
Mercator zoom scale):

| Level | Zoom from | Reference |
| --- | --- | --- |
| world | < 3.5 | WORLD opening 2.55 |
| region | 3.5 | EN opening (Europe, z4) |
| country | 5.5 | SL opening (Slovenia, z7), WORLD discover 5.6 |
| city | 8.5 | |
| neighbourhood | 12.5 | cluster limit 12 |
| street | 15 | spiderfy / nearby close-up |
| artwork | 17 | direct-target focus |

Nothing here moves the camera. The opening camera is the existing
`MapInitialViewport` (SL Slovenia, EN wide Europe). PRODUCT has no scroll
narrative: the camera moves only for gestures, search, selection, location and
explicit framing actions.

## 4. Marker level of detail

One identity (the canonical kubus marker), three costs. Thresholds live in
`KubusMarkerLod` and are device-tuning inputs, not magic numbers in widgets.

| Level | Zoom | What is drawn | Cost |
| --- | --- | --- | --- |
| far | < 6 | data-coloured dots; clusters are dots sized by `sqrt(count)` (capped 14 px) | no marker artwork rendered, registered or downloaded |
| mid | 6 – 15 | the canonical kubus marker (shape, signal ring, promotion star) with count badges for clusters | existing |
| close | ≥ 15 | the canonical marker with the artwork cover **inside its geometry** for a bounded set | covers bounded, see §5 |

* Far → mid is a continuous GPU ramp: the badge opacity interpolates over
  `[5.5, 6.5]` while the dot stays underneath; marker artwork is prepared from
  zoom 5.5 so it exists before the ramp reveals it.
* A far marker is the same GeoJSON feature as a mid one (same id, kind,
  entry animation, hitbox, spiderfy keys) with a blank, already-registered
  icon, so selection, taps and topology transitions behave identically.
* The hitbox anchors at the dot while far and at the floating badge from the
  blend band on.
* A cover is the mid marker with its face replaced: clipped to the same shape
  inset by a 2.5 px category-colour rim, same signal ring and promotion star.
  Photography never replaces the marker silhouette.
* Cover images are requested through `ArtworkMediaResolver.resolveCover(...,
  maxWidth: 160)` (thumbnail / width-clamped URLs, never archival media) and
  decoded at the rendered size.

## 5. Cover budget

Covers are the only per-record cost, so they are the only bounded set:

* active covers = `clamp(viewport area / 60 000 px², 8, 24)` (phone ≈ 8,
  1440x900 ≈ 22, hard cap 24). Candidates are markers inside the viewport that
  are not part of a same-coordinate stack; order is selected → promoted →
  nearest to the camera centre. The selected marker is always included.
* `KubusMarkerCoverLoader`: de-duplicates in-flight URLs, at most 4 concurrent
  fetches, an LRU of 48 decoded images (disposed on eviction), and a failed URL
  is not retried for 5 minutes. A failed or missing cover leaves the canonical
  marker (and frees its slot for the next candidate); it can never remove a
  marker.
* MapLibre has no image removal and the web plugin ignores a re-added name, so
  the number of cover images *registered* per style epoch is capped at 160
  (≈ 10 MB worst case on a 2x phone). When spent, markers keep their canonical
  badge until the next style load clears the images. This is a stated limit,
  not an eviction scheme.
* Covers are re-planned when the camera settles at street scale and when a
  cover finishes loading; they are not recomputed per camera frame.

## 6. Selection invariant

The selected marker never disappears because the level of detail, a cluster,
a filter, a style reload or a viewport refresh changed:

* **Not absorbed into a cluster** — `kubusClusterBucketsWithPinned` returns the
  selected marker as its own bucket at its exact position at every zoom, and
  the remaining markers cluster without it. (A selected marker that shares its
  coordinate with others stays in that same-coordinate stack, whose badge is its
  representation and which spiderfies on selection.)
* **Not faded with its level** — the badge opacity expression keeps the
  selected id fully opaque at far zoom, where every other marker is a dot.
* **Not hidden by its own layer toggle** — `buildRenderedMarkers` always renders
  the selected marker (the filter pipeline already pinned it).
* **Not dropped by a viewport refresh** — a bounds refresh replaces the loaded
  set; `markersPreservedAcrossViewportRefresh` carries the selected marker, the
  deep-link target and search temporaries over. Both screens use it.
* **Style reload / theme** — selection is controller state; the epoch re-install
  rewrites the layers and the restyle re-applies the pinned expression.

Desktop dismisses the selection on a user pan/zoom by design (anchored
overlay); the phone layout keeps it through gestures. The "survives zoom-out"
guarantee is therefore a phone behaviour, and the desktop one is "never
disappears while selected".

## 7. Clusters and same-coordinate records

Clustering stays the existing Dart grid ("pseudo-clustering", zoom < 12) with
its entry/regroup animation, spiderfy and cluster-tap activation. 5B changes
only what a cluster *looks like* when far (a sized dot) and keeps selected
markers out of it. Same-coordinate groups still collapse to one
`cluster_same:` feature that spiderfies; covers skip them.

A shared `KubusMarkerRegroupGate` replaces the duplicated per-screen logic and
reports `topology` (cluster mode / grid level changed: regroup animation),
`visual` (a level-of-detail boundary: rewrite artwork only) or `none`.

## 8. Result constraints

Everything that silently narrows the map is one typed list
(`KubusMapConstraint`), shown by `KubusMapConstraintStrip` under the search
field on phone and desktop:

* **map area** (baseline, informational), **travel radius** (with "location
  needed" when no fix exists yet, because then it narrows nothing), **search
  text**, **discovery status**, **AR only**, **favourites only**, **hidden
  content types**.
* Shown only while something restricts the result; each restriction clears
  alone; **Reset all** clears the search and every filter through the same
  `_handleFilterStateChanged` path the filter panel uses. Hidden while the
  filter panel is open (it shows and resets the same state).
* A test proves the listed constraints are exactly the predicates that remove
  markers, and that a reset leaves no chip (no ghost state).
* Not implemented, because the product has no such concept: city / place
  framing as a constraint (search results have no place kind) and a "quick
  filter" row separate from the filter panel. Nothing fabricates a coordinate.

## 9. Search, targets, Back

* Search results flow into the same controller: an artwork result selects the
  exact marker (or a temporary one) and frames it; the query stays an active,
  visible constraint.
* `MapTargetIntent` / `MapTargetCoordinator` is the single deterministic
  internal target contract (exact marker id → artwork → subject → coordinates;
  readiness gated on map + style, no timers). It is unchanged. #181 only changes
  how a URL reaches the app; it must keep feeding this contract and must not
  redefine map state.
* The map stays mounted under a pushed entity route; Back returns to the same
  camera, filters, search and selection (browser evidence in §11).

## 10. Camera ownership (audit)

Every programmatic move goes through `KubusMapController.animateTo` /
`fitBounds` (the only callers of the plugin's `animateCamera` on the product
map; `marker_editor_view` and `artwork_creator_screen` own tiny separate
picker maps). Callers: search result, cluster activation, marker overlay
composition correction, nearby selection, `MapTargetCoordinator`, locate-me /
center-on-me, walking follow and route fit, zoom controls, isometric toggle,
initial locale framing. `MapCameraController` queues a request made before the
map is ready.

Gesture vs programmatic is decided by the controller's
`programmaticCameraMove` flag, set when an animation starts and cleared on
camera idle. `map_engaged` is fed only by frames with the flag clear, and the
tracker baseline is reset after programmatic moves (frozen from 5A-E, covered
by `map_engagement_tracker_test` and `kubus_map_controller_engagement_test`).

Known limit (pre-existing, not changed): a user gesture that interrupts a
programmatic animation is classified programmatic until the next idle. Fixing
it by clearing the flag when the animation future completes would let the
programmatic move itself be counted as a gesture, which would break the frozen
`map_engaged` semantics, so it was deliberately left alone.

## 10a. Session continuity across layout swaps

The phone and wide layouts are two map screens, each with its own controller.
A rotation, a resizable window or a foldable crossing the breakpoint swaps one
for the other, which used to reopen the map at the locale framing and drop the
search text, filters and selection. `KubusMapSessionMemory` (one `Provider`,
in-memory, no persistence) is written by both screens (camera on idle, filters,
search text, selection) and read by the next screen before its first render:

* camera: the new map opens at the previous centre and zoom, and the locale
  fit-bounds is skipped (an explicit target, a deep link or walking navigation
  still wins);
* search text and filters are restored, so the constraint strip is the same;
* the selected marker is restored through the screen's own marker-tap path once
  the style is ready and markers have loaded (still one selection owner).

Browser evidence: selecting a marker on desktop with an active search, then
resizing to 390 px, opens the phone map at the same camera with the same
marker selected and the same search constraint. Android landscape/portrait
swaps keep camera and search text. Only a *new* screen reads the memory; it is
not a restore-after-process-death feature.

## 11. Evidence

See `docs/evidence/product-v5-spatial/README.md`.

## 12. Known limitations

* Globe is web only; Android is flat Mercator, iOS is unverified (treated flat).
* No physical Android device was available: **performance acceptance is
  incomplete**. Emulator and software-GL numbers are labelled as such.
* The cover image pool is capped per style epoch rather than evicted (MapLibre
  has no `removeImage`).
* The far level is capped by the existing viewport fetch limit (300 markers per
  request at low zoom buckets); "complete archive in GPU layers" is true of what
  the app loads, and loading more is a backend/query decision outside 5B.
* A remote (URL) map style does not get a globe: only bundled styles are
  stamped.
* Android only: on the branch build one rotation-driven map-screen swap threw a
  Java `NullPointerException` inside Flutter's `PlatformViewsController.resize`
  (`SurfaceProducerPlatformViewRenderTarget.getWidth` on a released surface
  producer) and closed the app. It did not reproduce in the later rotation runs
  on either build (several single rotations and short stress loops on the
  branch, and the same on the unchanged baseline); the emulator also dropped
  its adb link under repeated rotation, so those runs are not conclusive either
  way. The stack is entirely engine/plugin code and the screen swap itself is
  not new, but this is an observation, not a proven pre-existing defect.
* The wide layout shows two attribution controls on native Android (the plugin's
  own button and the app's glass one); this predates 5B and was left alone.
