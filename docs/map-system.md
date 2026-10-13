# Map system

This is the durable technical contract for the shared product map. It complements
[Architecture](ARCHITECTURE.md), [Design system](DESIGN_SYSTEM.md) and the
[guest-first entry contract](GUEST_FIRST_ENTRY.md). Historical measurements are
evidence for a particular revision/environment, not permanent performance guarantees.

## Ownership

| Concern | Owner |
| --- | --- |
| Camera, gestures, selection, style epoch, same-coordinate spiderfy | `KubusMapController` |
| MapLibre source/layer mutations, ordering and styling | `MapLayersManager` and `KubusMarkerLayerStyler` |
| Marker features, clustering, canonical icons and covers | `KubusMapMarkerSyncEngine` |
| Visual sync scheduling | `MapMarkerRenderCoordinator` / visual sync coordinator |
| Deep-link and search targets | `MapTargetCoordinator` and `MapTargetIntent` |
| Renderer capabilities | `KubusMapCapabilities` |
| Spatial framing / minimum zoom | `MapSpatialFraming` |
| Marker LOD and cover stages | `KubusMarkerLod` |
| Result constraints | `resolveMapConstraints` and `KubusMapConstraintStrip` |
| Nearby results and panel lifecycle | Nearby controller and existing draggable-sheet controller |

Phone and desktop screens share policies and services while owning their layout.
Do not introduce a second renderer, selection model or independent source writer.
Small editor/picker maps have a separate task and do not redefine product-map state.

## Initialization and capability

Wait for the attached map and current style before installing custom assets/layers
or applying a target. `KubusMapCapabilities.resolve` enables globe only for the web
renderer with the `mapGlobe` feature flag. Native and flag-disabled paths use flat
Mercator with the same selection, filters, clusters and constraints. Bundled globe
projection is injected by the style service for the capable renderer; native styles
remain flat. Keep vendored runtime/worker compatibility checks.

Style reloads discard custom assets. Controller/manager style epochs reinstall them
without losing controller selection. Asynchronous work must belong to the current
controller and style epoch before registering state or publishing sources. A stale
completion must not mark an image as registered in a replacement style. Preserve
manager queue guards and controller lifecycle disposal.

## Marker presentation and grouping

Canonical marker visibility depends on marker data and canonical icon assets, never
on artwork downloads. Far markers use low-cost dots; mid markers use canonical
geometry; close eligible individual markers replace the face with artwork inside
the same geometry. Thresholds belong in `KubusMarkerLod`, not scattered widget
conditions. Prefetch warms decoded artwork before close-level display.

Preserve feature identity, hitboxes, selected-marker representation and grouping
semantics through LOD changes. Selected markers are pinned out of ordinary clusters;
same-coordinate records keep their shared representation and spiderfy. Geographic
cluster spacing and maximum span represent real spatial groups, not a fixed marker
budget. The regroup gate separates topology changes from visual-only LOD changes
and uses hysteresis to absorb camera jitter. Equivalent data, cover completion or
return navigation must not restart an unrelated entrance animation.

## Cover and media work

`KubusMarkerCoverLoader` owns bounded downloads, resolved-URL/physical-size cache
keys, in-flight deduplication, queued display versus prefetch lanes, decoded-image
LRU disposal, viewport cancellation and failure backoff. Selected/display artwork
precedes background prefetch; obsolete offscreen work must not delay current work.
Every eligible visible individual can eventually show a cover; do not reintroduce
a center-only fixed cover count. Missing/failed artwork leaves the canonical marker.

Use `ArtworkMediaResolver.resolveCover` for suitable thumbnails. Bound decoding by
the loader's physical-size and decoded-pixel limits; preserve aspect ratio and
avoid archival downloads for tiny marker faces. Active decoded pins and registered
images have independent bounds. MapLibre registration is append-only within a style
epoch, so a spent registration budget keeps canonical badges until a style reload.
The source constants are authoritative: do not copy historical conflicting caps
into a new permanent guarantee.

`KubusCoverWorkGate` serializes rasterization/readback and spaces work more widely
while the camera moves. Coalesced cover refreshes must publish usable artwork within
a bounded window without rebuilding GeoJSON for every image. Preserve disposal,
stale-work preconditions and pending-request delivery. Tune pacing and coalescing
only against paired measurements of latency, source writes and frame distribution.

`KubusCachedImage` and the shared failure registry support card/detail continuity.
Keep image dimensions stable and retain decoded content during refresh. A cover
replacement preserves marker geometry and selection; no blank frame or second
unrelated entrance is acceptable. No screen constructs its own IPFS gateway URL.

## Navigation, camera and panel continuity

Programmatic product-map movement goes through `KubusMapController.animateTo` /
`fitBounds`. The programmatic-move flag separates automatic framing from deliberate
engagement; preserve the tested `map_engaged` contract. Initial framing, style reload,
deep-link framing and responsive restoration do not become deliberate user gestures.

Direct targets use the deterministic map-target contract after readiness. A pushed
entity route keeps the map mounted, so Back preserves camera, filters, search and
appropriate selection. `KubusMapSessionMemory` carries in-memory camera/search/
filter/selection state across responsive layout swaps and is cleared at signout.
It is not process-death persistence. Explicit targets and walking navigation retain
their established precedence. Desktop gesture-dismissal and phone selection behavior
are intentional layout policies rather than two selection systems.

Nearby sheet extent and scroll position belong to its existing controller lifecycle.
Marker overlays must not recreate it on unrelated updates. Floating controls follow
the sheet's measured edge within safe viewport bounds; use extent notifications and
local listeners, rather than rebuilding the entire map on every drag frame. Map
information has stable icon dimensions and separate explanatory content.

## Reliability and evidence

Test theme/style changes, stale completions, equivalent-source deduplication,
coalescing, cached covers, viewport cancellation, panel/overlay transitions and Back
during active transitions. A basemap/media failure degrades content without erasing
valid markers or entering a map recreation loop. Walking route sources/layers remain
owned and restored through the same style lifecycle.

Measure network, decoding, rasterization/GPU readback, image registration, source
construction/write and final paint separately. Report cold/warm conditions, fixture
revision, browser/device, frame p50/p95/p99, misses and memory where measured. RAF
intervals are not physical-device presented-frame measurements. Compilation is not
smoothness evidence. Existing [spatial evidence](evidence/product-v5-spatial/README.md)
retains its dated browser/emulator experiments and explicit platform limitations.
