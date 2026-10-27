# Map system

## Globe and user-location presentation

The web globe uses the public site's astronomical solar model (UTC subsolar
position), with a camera-projected soft night field. Theme controls the exact
black/white ground, never the sun. The field fades into the local map and pauses
when hidden, backgrounded or reduced motion is requested. Reduced motion retains
the correct solar state at entry; native flat maps do not gain a decorative globe.

Location layers share one real fix: the contrasting dot, a separate paint-only
expanding ring, measured accuracy and a screen-sized north-aligned heading sector.
The ring is decorative and never changes measured accuracy. Missing compass data
hides the sector. Device heading is never inferred from camera bearing or walking
course. Heading expires after ten seconds and requires a fix younger than thirty
seconds. The compass plugin's Android high-confidence status maps to 15 degrees;
its medium/low statuses (30/45) fail the shared 25-degree reliability threshold.
iOS supplies native heading accuracy. Browser geolocation emulation cannot accept
either native sensor implementation. Offscreen maps pause the shared animation;
reduced motion retains a static fix, accuracy and reliable heading.

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

Overlapping direct marker syncs also need latest-request ownership within the same
style: an older feature-building completion must not overwrite a newer dataset.
Source-publication generation and controller/style freshness are separate guards.
Do not use source generation to cancel useful cover jobs on every ordinary refresh.

## Basemap provider

The basemap is OpenFreeMap's public OpenMapTiles vector tiles, keyless: no API key,
account or paid service. Every provider URL lives in the two bundled styles
(`assets/map_styles/kubus_{light,dark}.json`) and nowhere in Dart: the vector source
(`https://tiles.openfreemap.org/planet`), the glyph endpoint, and the source
`attribution`. Dart only mirrors the attribution text (`kubusMapAttributionCredit`,
asserted equal to the styles by `kubus_map_chrome_test.dart`) and names the sources
in the attribution dialog. The web site (`art.kubus.site`) vendors the same two files
byte for byte and owns the provider registry that rewrites them at load time; see its
`docs/map.md`.

- The styles are the Kubus cartography (our palette and layer structure, derived from
  the CARTO Positron look) drawn on OpenFreeMap data; OpenFreeMap's stock styles are
  not used, and no CARTO resource is requested.
- Fonts must be Noto Sans Regular, Bold, Italic or Bold Italic: OpenFreeMap does not
  composite a missing font out of a stack, so an unknown face drops the labels. Noto
  Sans replaces the former Montserrat labels (slightly narrower and bolder); it is a
  known visual delta.
- OpenFreeMap tiles carry a single local `name`, so the bilingual place names CARTO
  joined ("Maniago / Mania") are lost. Known limitation; localised labels are not
  handled in the basemap.
- There is no production fallback basemap. If OpenFreeMap is unreachable no basemap
  tiles are drawn until it recovers.
- Buildings first exist at z13 (footprint detail at z14). The styles' semantic-zoom
  contract and `production_map_styles_test.dart` depend on it.
- Attribution ("OpenFreeMap © OpenMapTiles Data from OpenStreetMap") must stay visible.
- OpenStreetMap's community raster tile servers are never a fallback: their usage
  policy forbids unrestricted production use.
- `MAP_STYLE_LIGHT_ASSET` / `MAP_STYLE_DARK_ASSET` select a different checked-in style;
  that is the provider switch. `production_map_styles_test.dart` validates whatever is
  configured.

Self-hosted Protomaps (PMTiles) is planned, not implemented. Protomaps tiles use a
different vector schema from OpenMapTiles, so the Kubus styles cannot be reused: it
needs Protomaps-schema styles, a self-hosted PMTiles archive (HTTP Range and CORS),
self-hosted glyphs, `pmtiles://` support confirmed on the pinned `maplibre_gl` native
(Android, iOS) and web builds, and the style-contract test extended per schema.
Self-hosting OpenFreeMap itself needs none of that: same schema, only the URLs in the
styles change.

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
Bounded fetch/decode prefetch also runs during the continuous zoom approach;
requiring camera idle would skip that band entirely. Prefetch never rasterizes or
registers icons, and changed viewport demand cancels stale queued work.

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
their established precedence. Both layouts preserve the selected marker through
zoom/pan topology changes and style reloads. Background taps, explicit dismissal,
and removal of the actual record still clear selection; camera motion alone does not.

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
