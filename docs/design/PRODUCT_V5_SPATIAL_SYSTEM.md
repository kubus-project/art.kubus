# PRODUCT v5 — spatial map system (Wave 5B)

Status: implemented reality of Wave 5B on `feat/product-v5-spatial-system`
(rebased onto `dev@d6810271`). Everything below is what the code does today; limits and
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
| iOS, MapLibre Native 6.27.0 | Not verified at runtime | no macOS host; the PR's `iOS release compile without codesigning` job is the only iOS evidence (it compiles); treated as flat |
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
| mid | 6 – 12.5 | the canonical kubus marker (shape, signal ring, promotion star) with count badges for clusters; the **selected** marker may already show its cover from 10 | existing |
| close | ≥ 12.5 | the canonical marker with the artwork cover **inside its geometry** for every eligible individual marker in view | work and memory bounded, see §5 |

Cover stages (`KubusMarkerLod.coverStageForZoom`, 0.8.1):

| Stage | Zoom | Constant | What happens |
| --- | --- | --- | --- |
| 0 none | < 10 | — | no covers |
| 1 selected only | 10 – 11.5 | `selectedCoverMinZoom = 10.0` | the selected marker (pinned out of clustering) shows its cover |
| 2 prefetch | 11.5 – 12.5 | `coverPrefetchMinZoom = 11.5` | nearby covers are downloaded and decoded (never rasterised) for the next stage |
| 3 display | ≥ 12.5 | `coverDisplayMinZoom = 12.5` | **every** eligible individual marker in view is planned for a cover |

Covers start after clusters dissolve (`MapScreenConstants.clusterMaxZoom =
12.0`), so a nearby cover only ever replaces a canonical individual marker.

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
  maxWidth: KubusMarkerLod.coverFetchWidthPx(markerPixelRatio))` (thumbnail /
  width-clamped URLs, never archival media) and decoded so that the cover's
  *shorter* side is that size (the marker crops to the shorter side, so a
  wide image keeps its detail where the crop needs it; never upscaled), subject
  to absolute ceilings of 1024 px on the long edge and 262144 decoded pixels.
  Extreme panoramas sacrifice crop resolution to preserve bounded memory.
  The default 48-image cache holds at most 48 MiB of decoded RGBA geometry;
  this excludes decoder working memory and GPU copies.
  The size is the 44 px cover face x 1.5 oversample x the device pixel
  ratio, snapped up to 32 px steps and clamped to 96-256: 96 px at 1x, 160 px
  at 2x, 224 px at 3x.

## 5. Cover working set

There is **no fixed number of covers**. Superseded (final 0.8.1, owner
direction): the staged 8-24 viewport budget ranked selected, promoted, then
nearest the camera centre, which painted a photo circle around the middle of the
screen and left eligible markers at the edges as icons. At
`coverDisplayMinZoom` every eligible marker in view eventually shows its cover.
What stays bounded is the work and the memory:

* **Eligible** = a marker that is currently an individual marker face (not a
  hidden cluster child and not a same-coordinate stack), inside the viewport,
  not hidden by a filter, with a resolvable cover that has not failed. The
  selected marker is first, then promoted markers, then everyone else.
* **Loading order is spatially fair** (`selectCoverMarkerIds`,
  `spatiallyFairOrder`): the rest are binned into a 4 x 4 grid over their own
  extent and taken round-robin in a scattered cell order, so a viewport fills
  across its whole area instead of centre-out. A panned camera plans only the
  new visible set; old offscreen priority is dropped. Prefetch (zoom 11.5-12.5)
  warms at most `coverPrefetchLimit = 32`.
* **Concurrency stays bounded**: at most 4 concurrent downloads, one raster at
  a time (paced wider while the camera moves, §5 raster rule), de-duplicated
  in-flight requests, generation-safe cancellation, coalesced source writes.
* **Memory stays bounded**: decoded images have the 1024 px / 262144-pixel
  ceilings; the decoded cache keeps its LRU of 48 but **pins** the covers of the
  active viewport that are not drawn into the map yet (up to `maxPinned = 192`),
  so a visible cover is never evicted before it is used. Offscreen, stale-size
  and old-zoom entries are evicted first. Registered covers need no decoded copy.
  MapLibre cannot remove an image, so registered images are append-only per
  style epoch, capped at `maxRegisteredCoverImages = 320` (about 20 MB at 2x);
  past it markers keep their canonical badge until the next style reload.

* `KubusMarkerCoverLoader`: de-duplicates in-flight requests, at most 4
  concurrent fetches, two lanes (covers about to be drawn always start before
  prefetches; a display request for a queued prefetch promotes it; each new
  prefetch plan drops prefetches that have not started), an LRU of 48 decoded images (disposed on eviction), and
  cancellation synchronously frees the URL/size key; identity-owned completion
  prevents an old cancelled task from removing its replacement. Also,
  a failed URL is not retried for 5 minutes. Decodes are keyed by resolved URL
  **and** physical width, so markers sharing media share one decode while a
  different pixel ratio never reuses a too-small bitmap. A failed or missing cover leaves the canonical
  marker (and frees its slot for the next candidate); it can never remove a
  marker.
* MapLibre has no image removal and the web plugin ignores a re-added name, so
  the number of cover images *registered* per style epoch is capped at 160
  (≈ 10 MB worst case on a 2x phone). When spent, markers keep their canonical
  badge until the next style load clears the images. This is a stated limit,
  not an eviction scheme.
* Covers are re-planned on camera idle whenever
  `KubusMarkerLod.plansCoversAt(zoom, hasSelection:)` holds: from the prefetch
  zoom (11.5) for everyone, and from 10 when a marker is selected (selection
  usually animates the camera). They are also planned by every marker source
  sync during motion (a level-of-detail or grouping change, an entrance
  frame) and when a cover finishes loading; they are never recomputed per
  camera frame.
* **Paced raster rule** (0.8.2 Slice C, supersedes the camera-idle raster rule).
  A cover is rasterised (a GPU readback) one at a time (`KubusCoverWorkGate`):
  24 ms apart while the camera rests, `motionSpacing` = 140 ms apart while it
  moves. Measured on web at 4 ms median / 10 ms p95 per raster and 1.4 ms per
  `addImage`, that keeps covers arriving during a slow zoom or pan without
  moving the motion frame p95/p99. Prefetch (zoom 11.5-12.5, download +
  decode only) still waits for idle.
* **No lost sync requests.** `MarkerVisualSyncCoordinator` throttles source
  syncs to one per 60 ms; a request inside the window runs when the in-flight
  sync ends or, if none is in flight, when the window closes. (Before 0.8.2 it
  was only remembered until the next request, so a cover-stage change landing
  just behind a regroup frame waited for the camera to stop.)
* **Failed media is shared.** A cover that fails to load (a real error, not a
  slow timeout) is recorded in `KubusMediaFailureRegistry`, which
  `KubusCachedImage` (the quick card's media) honours for 2 minutes, so a card
  following its marker does not re-request a dead URL on every rebuild.
* **Coalesced source refresh.** Finished covers do not each rebuild the marker
  source: the gate fires one resync 140 ms after the last finished cover
  (`resyncDelay`), but never later than 450 ms after the first pending one
  (`resyncMaxWait`), so a long batch shows its first covers early instead of
  only after the last. The reason is measured in §10c.

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

Clustering stays the existing Dart grid ("pseudo-clustering", below
`clusterMaxZoom = 12.0`) with its entry/regroup animation, spiderfy and
cluster-tap activation. 5B changes only what a cluster *looks like* when far
(a sized dot) and keeps selected markers out of it.

Clustering exists to stop markers colliding, not to erase where they are
(final 0.8.1, `MapScreenConstants.clusterTargetSpacingPx`). Superseded: the
earlier curve grouped *more* widely the farther out the camera was (116 px),
which folded the world into one or two dots. The world now reads as a
distributed cultural map:

| Scale | Reads as | Target spacing |
| --- | --- | --- |
| World (zoom 0-3) | distributed regional clusters and isolated records | 48 px rising to 56 px, further capped by the span rule |
| Region / country (3-8) | regional, then country groups | 56 → 64 → 68 px |
| City (8-12) | city, then neighbourhood groups | 68 → 64 → 60 px |
| ≥ 12 | individual records | no clustering (returns below 11.75, see hysteresis) |

* The curve is **continuous and piecewise linear**, so the integer grid level
  is a monotonic function of zoom: no topology flicker, and zooming out then in
  gives the same membership. It is not required to be monotonic in pixels.
* **Geographic safety rule**: a grid cell's diagonal bounds how far apart its
  members can be, so the spacing is also capped to
  `clusterMaxSpanMeters = 1 500 000` (equatorial Mercator metres, floor
  `clusterMinSpacingPx = 20`). At world scale a cluster therefore represents a
  coherent region: Lisbon and Ljubljana never share a dot, Zagreb, Celje and
  Ljubljana do. The rule only binds below about zoom 3 and is not country based.
* An isolated record stays its own dot (it is a cell of one). Cluster count is
  never a budget: it falls out of the data, the viewport and the spacing.
* **Grouping hysteresis** (0.8.2 Slice C, `KubusMarkerRegroupGate`). Grouping
  is evaluated at a *topology zoom* that follows the camera at once when
  zooming in and lags a zoom-out by `topologyPlay = 0.25`. Individual records
  still appear exactly at A = 12.0; they regroup into clusters only below
  B = 11.75 (grid levels get the same slack). Measured before: ±0.06 camera
  jitter around z12 swapped 6 clusters for 55 markers on every step (14
  topology flips, 36 source writes in 12 steps); after: 2 flips, 3 writes.
  0.25 absorbs one MapLibre wheel notch (~0.15) plus settle jitter; level of
  detail (artwork, covers) keeps following the real zoom.
* **Progressive reveal.** A regroup is a centre-out wave
  (`kubusEntryRevealOffsets`): each feature's soft entrance starts later the
  farther it is from the viewport centre, the whole wave capped at 240 ms
  (360 ms for a first entrance), and each marker fans out from its cluster's
  centroid on its own progress. The cap bounds animation frames (source
  writes) by time, not by marker count: 56 markers entering a city used to
  stagger over 2 s (~45 animation-only writes) while rendering as six
  clusters.
* **Artwork warmed before the threshold.** Within one zoom of A, while the
  camera rests, the individual-marker icons are rasterised ahead, so the
  crossing only rewrites the source.
* The policy is shared by the web globe, the web Mercator fallback and the flat
  Android and iOS maps; there is no globe-only clustering. Cluster activation
  (`resolveKubusClusterActivationPlan`) still moves to the next real split zoom,
  so a world cluster opens region → country → city.

Same-coordinate groups still collapse to one `cluster_same:` feature that
spiderfies; covers skip them.

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

## 10b. Contracts that did not move

* **Guest-first entry** (frozen from 5A-E): a fresh install opens straight on the
  map. No alpha notice, onboarding, account/wallet/profile wall, startup location
  request or startup notification request was added; the Android emulator opening
  frames in the evidence folder were taken on a fresh install of the branch build.
  Location is asked for only by the explicit "Center on me" control.
* **`map_engaged`** (frozen from 5A-E): first deliberate interaction, once per
  session (user feature or marker tap, search-result selection, deliberate pan or
  zoom). Initial globe framing, programmatic zoom, deep-link framing, style
  reload, responsive restore and session-memory camera restore do not qualify;
  the restore paths use the same programmatic-move flag as every other
  `KubusMapController.animateTo`/`fitBounds` caller (§10).
* **WebGL context loss**: the browser QA simulates a lost and restored context;
  the app keeps one map instance, restores its layers and does not enter a
  recreate loop. A style that cannot draw a globe falls back to flat; no state
  blanks the app (offline tiles and a failed cover image are covered by the same
  QA: the markers stay, the basemap degrades).
* **Walking navigation**: untouched. The route lives in its own source and layers
  and is restored by the style epoch like every other layer; the existing
  walking/navigation widget and unit tests run unchanged in the full suite.

## 10c. Performance (measured, and what is not)

Three different kinds of evidence exist and are never mixed:

### Network (browser, 5-run fixture replay)

Marker covers used to be fetched at the size the media resolver returned for a
detail view (960 px). They are now requested at the badge's own size (stored
Wikimedia thumbnails are re-bucketed to the requested width, 120/250/330 px).

| 390x844, same camera path | image requests | decoded bytes |
| --- | --- | --- |
| dev (before 5B) | 13 | **3 368 KB** (13 x 960 px class) |
| Wave 5B | 13-27 (one per cover that lands) | **117-354 KB** |

At 1440x900 dev fetched 2 images (16 KB) because it draws no covers; 5B draws
up to 24 and fetches 13-16 of them (229-336 KB) on the same path.

### Browser frame pacing (Chromium, 5 runs per cell, medians, ms)

The experiment holds machine, browser, viewport, warm-up, camera path
(zoom 3.5 -> 15 -> pan -> 6 over Ljubljana, 68 of 300 fixture markers), cache
policy and measurement window constant. Marker reads are a pinned dataset and
every external read is replayed from disk, so the configurations differ in the
bundle only. Configurations: **A** = dev (MapLibre GL JS 4.7.1, flat),
**A2** = the same dev code with the 5.24.0 runtime swapped in (isolates the
runtime), **B/C** = Wave 5B flat / globe before the fix below, **Bf/Cf** = after.
Harness: `scripts/qa/product_v5_spatial_perf_ab.mjs`; CPU profile:
`scripts/qa/product_v5_spatial_cpu_profile.mjs`. Raw summaries are in the
evidence folder.

Real GPU (RTX 3080 Ti through ANGLE/D3D11), 1440x900:

| | p50 | p95 | p99 | max | frames >33 | frames >50 | long tasks | readPixels |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A dev | 16.7 | 16.8 | 16.8 | 49.9 | 1 | 0 | 0 | 39 / 60 ms |
| A2 dev + 5.24 | 16.7 | 16.8 | 33.3 | 33.4 | 1 | 0 | 0 | 39 / 50 ms |
| B 5B flat, before fix | 16.7 | **49.9** | 66.6 | 116.6 | 20 | **9** | 12 / 844 ms | 59 / 166 ms |
| C 5B globe, before fix | 16.7 | **50.0** | 83.4 | 233.3 | 20 | **9** | 13 / 1195 ms | 91 / 168 ms |
| Bf 5B flat, fixed | 16.7 | 16.8 | 33.3 | 100.0 | 3 | 2 | 3 / 209 ms | 42 / 89 ms |
| Cf 5B globe, fixed | 16.7 | 16.8 | 50.0 | 133.3 | 4 | 3 | 3 / 255 ms | 79 / 89 ms |

Software GL (SwiftShader: the worst case, CPU rasterised), 1440x900:

| | p50 | p95 | p99 | max | frames >50 | long tasks |
| --- | --- | --- | --- | --- | --- | --- |
| A | 16.7 | 66.6 | 183.4 | 249.9 | 15 | 14 / 1634 ms |
| A2 | 16.7 | 66.7 | 216.6 | 266.6 | 19 | 14 / 1641 ms |
| B before fix | 16.7 | **99.9** | 350.0 | 383.3 | **25** | 21 / 2491 ms |
| C before fix | 16.7 | **100.0** | 333.3 | 350.0 | **28** | 19 / 2543 ms |
| Bf fixed | 33.2 | 66.7 | 333.2 | 366.6 | 15 | 10 / 1441 ms |
| Cf fixed | 33.3 | 66.8 | 333.3 | 366.6 | 18 | 13 / 1949 ms |

At 390x844 the real GPU is flat across all six (p95 16.8 ms everywhere, 0-2
frames >50 ms). On software GL the phone viewport shows p95 66.7 (A, A2, Bf),
83.3 (Cf) and 100.1 (B, C), frames >50 ms 19 / 18 / 17 / 16 / 21 / 18; the
spread between runs of one cell is as large as the Cf-versus-Bf difference
(66.6-116.6 for Cf), so the globe's cost on a phone-size software canvas is not
separable from noise.

**What the experiment attributes the cost to**

* MapLibre GL JS 5.24 runtime: **nothing** (A against A2: identical on both
  GL modes).
* Globe projection: **a small constant**, visible only as `Map._render` CPU
  time (p50 1.4 -> 2.0 ms real GPU, 2.2 -> 3.5 ms software). It adds no
  measurable dropped frames once the cover work is fixed (Bf against Cf).
* The 5B marker / cover work **before the fix**: p95 16.8 -> 49.9 ms, nine
  frames over 50 ms and twelve long tasks. A CPU profile showed the extra time is
  `readPixels` (CanvasKit reads each rendered icon back from the GPU): one stall
  per cover icon, started while the camera was still moving, and each finished
  cover forced an immediate full marker-source rebuild.
* Source serialisation (`setData`) is 1-2 ms per call in every configuration;
  it is not a factor. Active features were identical across configurations
  (80-92 at the street frame).

**The fix** (`KubusCoverWorkGate`): new cover preparation starts only while the
camera is idle, runs one cover at a time with a 24 ms breather, and collapses the
resyncs of a batch into one trailing rebuild. Skipped covers are re-planned at
the next camera idle (both screens already do this at street scale). The
level-of-detail rules, the selected-marker invariant and the image budget are
unchanged (the cover count policy and cluster spacing were revised for the final
0.8.1, see §5 and §7).

0.8.1 superseded parts of this 5B description (the measurements above are the
5B record and stay as measured): covers now start earlier and staged, the
trailing rebuild has a 450 ms maximum wait, and idle re-planning starts at the
prefetch zoom or, with a selection, at 10. The current contract is §4, §5 and
§7; the 0.8.0 vs 0.8.1 comparison is in `docs/release-0.8.1.md`.

0.8.2 Slice C (map continuity) superseded the camera-idle start: cover jobs run
during motion at a wider pace (§5), after a probe showed raster + `addImage` at
~5 ms per cover and found the real reason covers waited for idle (a dropped
throttled sync request, §5). Its before/after record and the reproducible probe
(`scripts/qa/map_continuity_probe.mjs`) are in the Slice C pull request.

Measurement integrity note: an earlier pass was taken while a stray Android
emulator from a previous session consumed CPU; it inflated every configuration.
All numbers above are from runs on a quiet machine (emulator stopped). The
ordering (5B before the fix worse, after the fix equal to dev) held in both
passes.

Remaining browser cost, stated plainly: after the fix 5B still issues more
`readPixels` calls than dev (42-79 against 39) because it renders cover icons,
and the frames of 117-316 ms that remain on the real GPU (dev: 33-83 ms) all fall
in the zoom-in segment of the 1440 path, the stretch that ends with the camera
settling at street zoom, which is when the first cover is rasterised. That
attribution is consistent with the timing but was not isolated further (the globe
build also crosses MapLibre's own globe-to-Mercator projection change on this
stretch, which may account for its larger spikes). This is
browser evidence on one machine.

### Android emulator (evidence only, not a device claim)

`scripts/qa/android_emulator_map_perf.sh` derives frame intervals from the
Flutter `SurfaceView` BLAST layer in `dumpsys SurfaceFlinger --latency` (the layer
is discovered at run time; `dumpsys gfxinfo` reports no Flutter frames). One
freshly booted API 34 x86_64 emulator with host GPU, signed release APKs built
from current `dev` and from the final branch, the same scripted pans and cluster
tap, run baseline / branch / baseline / branch:

| run | frames | p50 | p90 | p95 | p99 | >33 ms | >50 ms |
| --- | --- | --- | --- | --- | --- | --- | --- |
| baseline r1 (first run after boot) | 840 | 17.2 | 44.6 | 57.4 | 130.9 | 139 | 62 |
| branch r1 | 1114 | 16.7 | 18.3 | 19.0 | 33.9 | 17 | 3 |
| baseline r2 | 1144 | 16.7 | 18.1 | 18.8 | 33.4 | 13 | 0 |
| branch r2 | 1112 | 16.7 | 18.3 | 19.4 | 34.1 | 17 | 4 |

The first baseline run is a cold-emulator outlier and is kept in the table; the
warm baseline run and both branch runs are within about 1 ms at p95 and p99,
with the branch showing 3-4 frames over 50 ms against 0 for the warm baseline.
Read that as "no regression visible at emulator resolution", not as equality.

### Physical Android: NOT VERIFIED

No physical Android device was available. **Physical Android performance is not
verified**; nothing in this document or the PR claims it. The emulator figures
above say the Flutter surface keeps pace in a virtual device and nothing more.

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
* Android only: during development one rotation-driven map-screen swap on an
  earlier branch build threw a Java `NullPointerException` inside Flutter's
  `PlatformViewsController.resize`
  (`SurfaceProducerPlatformViewRenderTarget.getWidth` on a released surface
  producer) and the app process was terminated. **Observed once; not reproduced
  under controlled conditions; no proven Wave 5B attribution.** Controlled run on
  the final build: a freshly booted emulator per run (API 34 x86_64, host GPU,
  2 GB, 4 cores), signed release APKs built from current `dev` (`d6810271`) and
  from the final branch, 20 portrait to landscape cycles per run with 3 s rest
  after each rotation, in two states (idle map; search then selecting its result,
  which opens the preview card), two runs per state per build: **80 cycles per
  build, 0 process deaths, 0 `FATAL EXCEPTION`, 0 `PlatformViewsController`
  or `SurfaceProducerPlatformViewRenderTarget` lines on either build**
  (`scripts/qa/android_rotation_repro.sh`; summaries in the evidence folder).
  The `NullPointerException` lines that appear in logcat belong to Google Play
  services / system processes, not to the app. The stack of the original crash is
  entirely engine/plugin code and the screen swap itself is not new, but this
  remains an observation, not a proven pre-existing defect and not a fix.
* The first request for a thumbnail size the media host has not generated yet can
  take seconds, so a street-level cover can arrive late (the canonical marker is
  always there meanwhile). Browser QA saw this as intermittent "no covers yet"
  failures right after the 120/250/330 px sizes were first requested, none once
  they were cached; the QA now polls up to 12 s and records the first-cover
  latency instead of guessing a fixed wait.
* The wide layout shows two attribution controls on native Android (the plugin's
  own button and the app's glass one); this predates 5B and was left alone.
