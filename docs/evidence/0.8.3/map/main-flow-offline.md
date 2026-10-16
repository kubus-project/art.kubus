# Map main flow: offline, clock-pinned re-run (2026-10-16)

Closes the two checks that were left unproven in `combined-validation.md`: the
selected-badge pixel check and the layers-after-theme-switch check.

## Result

With the harness corrected (below) the main flow passes on the five-package
candidate `d36d07e3`, at both pinned clocks, with no check failing:

| Build | Browser, viewport | 12:45Z | 16:40Z |
| --- | --- | --- | --- |
| candidate | Chromium 1440x900 | 24/24 | 24/24 (three runs) |
| candidate | Chromium 390x844 | 24/24 | 24/24 |
| candidate | Firefox 1440x900 | 23/23 | 23/23 |
| untouched `dev` `332e13a9` | Chromium 390x844 | 24/24 | 24/24 |
| untouched `dev` `332e13a9` | Chromium 1440x900 | 4 fail | 4 fail |

The four baseline failures at 1440 px are one defect seen four ways: the selected
marker is gone from the marker source after the camera moves away
(`selected marker stays an individual marker`, `badge stays pinned`, `badge is drawn`
and `selection pin survives the theme switch`). The candidate keeps the selection,
which is the geographic selection continuity change in #298. Per-run lines are in
`main-flow-offline-matrix.txt`.

## Root causes of the two "unproven" checks

**Selected-badge pixels depended on the time of day.** The globe's night shade is a
separate 2D canvas (`web/kubus_globe_atmosphere.mjs`) laid over the map canvas, filled
black at up to 0.36 alpha below zoom 4.6. It dims every map pixel under it, including
the badge, and the check counted pixels with `max(r,g,b) > 150`. Ljubljana is on the
day side at 12:45Z and on the night side at 16:40Z, so the same badge passed and failed
(360/832 and 162/832 saturated pixels on the same build, fixture and viewport). With the
overlay deliberately left in the read (`QA_BADGE_KEEP_OVERLAY=1`) the candidate reads
0/832 at 16:40Z, and the screenshot shows the badge drawn and dimmed on the night side.
The product draws the badge; the check measured the shade. The check now hides the
overlay for the read and restores it, and the globe/overlay has its own checks.

Observation for the owner, not a defect found by this work: the night shade sits above
the map canvas, so markers and the selected badge on the night side are dimmed by up to
36 %. They stay visible and legible in the screenshots.

**Layers after the theme switch was a race.** The wait returned after 10 ms to 1.1 s
because the previous style's `kubus_marker_layer` was still present, then the check read
the map while the style was momentarily undefined (`Cannot read properties of undefined
(reading 'getPaintProperty')`). The harness now counts style applications (`setStyle`,
including a new map's constructor) and waits for one applied after the switch that has
finished loading with the layers present. Measured re-install time on the candidate is
2.6 to 4.4 s under software GL, two style applications, and the selection pin survives.

A third flake, `selected marker stays an individual marker` reading 0 right after a
camera jump, is the marker plan being rebuilt: the id returns within 0.1 to 2.2 s. The
check now waits up to 15 s for it and records how long it took.

## `Orbit fallback failed`

`backend_api_service.dart` throws `Exception('Orbit fallback failed: <status>')` when the
primary and the fallback API both answer non-2xx. The offline replay fails the bounds-keyed
overview request closed (503), which reproduces it as an uncaught page error on the
candidate and on the untouched baseline alike (6 to 12 per run). It is unrelated to the
five packages and is left for a separate change.

## Method

`product_v5_spatial_browser_qa.mjs` gained, all opt-in:

- `QA_CLOCK=<ISO time>`: `context.clock.install`, so the sun and every `DateTime.now()`
  are pinned while timers keep running (`setFixedTime` would freeze them).
- `QA_HTTP_FIXTURE=<dir>` with `QA_HTTP_FIXTURE_RECORD=1`: record once, replay after;
  a miss in replay answers 503 and is listed in `report.json` (`network.fixtureMisses`)
  instead of reaching the network.
- `QA_MARKER_FIXTURE=<file>`: the frozen 5,000-record published marker capture used by the
  performance comparison.
- `QA_BADGE_KEEP_OVERLAY=1`: reproduces the old clock-dependent read.

Limits: the set of request URLs is timing dependent (cover fetch order), so replay still
records a handful of new URLs per run and does not reach zero misses; every miss fails
closed. Outcomes, not byte-identical traffic, are what repeat. Software GL (SwiftShader)
in Chromium, default Firefox rendering. Light scheme only in this matrix.
