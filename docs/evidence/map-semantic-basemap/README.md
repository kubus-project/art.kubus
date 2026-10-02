# Semantic basemap visual QA

Evidence for `feat(map): improve semantic zoom and basemap hierarchy`.

Both bundled production styles (`assets/map_styles/kubus_light.json`,
`assets/map_styles/kubus_dark.json`) were loaded into the exact MapLibre GL JS
build the app ships on web (`web/local/maplibre-gl/maplibre-gl-csp.js`) in a
headless Chromium, against the live CARTO vector tile service. Every capture
below reached both `load` and `idle` with an empty map error array.

## Before / after

Ljubljana (14.5058, 46.0569), 900 x 640, `pitch: 0` except z15 which uses
`pitch: 55` to exercise the isometric presentation.

| zoom | dark | light |
|---|---|---|
| z5 — regional | [dark-z5](dark-z5-before-after.png) | [light-z5](light-z5-before-after.png) |
| z7 — cities | [dark-z7](dark-z7-before-after.png) | [light-z7](light-z7-before-after.png) |
| z10 — urban structure | [dark-z10](dark-z10-before-after.png) | [light-z10](light-z10-before-after.png) |
| z13 — building mass | [dark-z13](dark-z13-before-after.png) | [light-z13](light-z13-before-after.png) |
| z15 — detailed, pitched | [dark-z15](dark-z15-before-after.png) | [light-z15](light-z15-before-after.png) |

What the captures show:

- **z5** — before: no urban footprint, no motorway structure, Ljubljana absent,
  the view is dominated by administrative-region labels. After: capitals and
  major cities carry the view, urban masses are visible around Milan, Munich,
  Vienna and Ljubljana, and the Adriatic reads unambiguously as water.
- **z7** — before: no roads at all and no urban mass. After: the motorway/trunk
  network is legible in neutral grey and Ljubljana, Zagreb, Maribor, Graz,
  Klagenfurt and Venice each read as a distinct urban mass.
- **z10** — the Ljubljana ring road and built-up area read as a city; the Sava
  and Ljubljanica are clearly water.
- **z13** — the generalized built-up mass the source ships at z13 provides
  building context without individual footprints.
- **z15** — individual footprints with an offset top face, correct under pitch.

## Marker dominance

[marker-dominance-dark-z13.png](marker-dominance-dark-z13.png) ·
[marker-dominance-light-z13.png](marker-dominance-light-z13.png)

Kubus-style marker layers were appended at runtime the same way
`MapLayersManager` does it (`addSource` + `addLayer`, appended last). The
captures confirm the runtime layers land on top of every basemap layer
(`place_continent` is the last basemap layer, then `kubus_marker_pulse_layer`
and `kubus_marker_layer`) and that saturated brand markers dominate the neutral
basemap in both themes.

## Reproducing

The captures are produced by driving the bundled style files through MapLibre
GL JS in Playwright. The harness is not checked in: it serves
`web/local/maplibre-gl/` and `assets/map_styles/` over a local HTTP server,
constructs a `maplibregl.Map` per (style, centre, zoom, pitch), waits for
`idle`, and screenshots the map container.
