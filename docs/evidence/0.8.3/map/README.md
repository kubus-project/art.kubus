# Map motion and performance evidence — 0.8.3

This packet compares release web builds from `febffbe5b97b605a2fd04d9b48301c5fc13929ce`
and the combined validation source `c5e1c419570370a65f463ea74deb21fe5565e291`.
The latter contains the PR #298 map implementation at `32c62d69d11f14f50a02ea109497cee8dce3b120`.
It also contains the other corrective packages; this is a combined candidate comparison,
not an attribution of every millisecond to one individual patch. No release branch,
production data or deployment was changed.

## Reproduction and data

`scripts/qa/product_v5_spatial_perf_ab.mjs` ran serially, with other task browsers,
builds and local test runs paused. Chromium used hardware ANGLE/D3D11 on an NVIDIA
RTX 3080 Ti, MapLibre 5.24.0, globe projection. A 390 px viewport is desktop browser
emulation, not Android/iOS performance evidence.

Both builds replayed the same 5,000 real published marker records, obtained from
the public `/api/art-markers` endpoint with world bounds, `limit=5000`, and the
Ljubljana search origin (46.0569, 14.5058). Dataset SHA256:
`4d8808d38ba006ef315589a00360f6d4c8ffe204684b8c000e8025c6662f10fd`.
This nearest-first snapshot is not the entire published world dataset.
The dense camera centers on Ljubljana (14.5058, 46.0569); the sparse path centers
on Kranj (14.355, 46.239). The same records are used in both paths.

Each page starts with an empty app image/decode cache, then repeats the camera
path with that page's warm cache. HTTP responses, including failures, are replayed
from a warmed fixture; media proxy `sid` is excluded from cache identity because
it is request telemetry. **All 12 measured paths have zero external fixture
misses.** A separate baseline startup overview request missed once per page,
before the measured interval. This is controlled HTTP replay, not a mobile-network
cold-download benchmark.

Commands use `PERF_CONFIGS=before-febffbe5=C:/kubus-build/083-baseline-web,after-c5e1c419=C:/kubus-build/083-web-c5e1c419`,
`PERF_GL=hardware`, `PERF_PATH=topology`, `PERF_VIEWPORTS=390x844,1440x900`.
Dense uses `PERF_RUNS=2`; sparse uses `PERF_RUNS=1` and the Kranj `PERF_CENTER`.
The path performs a 2.8 s split (zoom 10.5 → 13.4), interrupts a merge after
500 ms with an 1.8 s reversal, pans, then merges to 10.5. It repeats cold/warm.
All 96 recorded endpoints match their requested zoom and center (maximum error
below 0.000001 zoom and 0.000000001 degrees). Earlier exploratory runs whose
`moveend` listener consumed the interrupted movement are excluded.

## Frame and source results

Numbers are per-run ranges where two runs exist. Frame times come from rAF
intervals, and missed frames are an estimate at 60 Hz, not physical presentation
telemetry. Long held frames remain included. Dense p99 varies substantially in
the baseline; two runs establish this path's result, not a broad device population.

| Region / viewport | Build | p50 / p95 / p99 ms | Estimated missed 60 Hz frames | Marker source writes | Peak active images |
| --- | --- | --- | --- | --- | --- |
| Dense 390×844 | Before | 16.7 / 116.6–116.7 / 349.9–350 | 1036–1083 | 68–69 | 84 |
| Dense 390×844 | After | 16.7 / 16.7–16.8 / 16.8 | 27–28 | 173–176 | 97 |
| Dense 1440×900 | Before | 16.7 / 116.7 / 233.3–750 | 1139–1169 | 83 | 100 |
| Dense 1440×900 | After | 16.7 / 16.8 / 16.8 | 27 | 141–145 | 101 |
| Sparse 390×844 | Before | 16.7 / 16.8 / 100 | 759 | 18 | 51 |
| Sparse 390×844 | After | 16.7 / 16.8 / 16.8 | 21 | 34 | 54 |
| Sparse 1440×900 | Before | 16.7 / 16.8 / 100 | 759 | 18 | 57 |
| Sparse 1440×900 | After | 16.7 / 16.7 / 16.8 | 26 | 33 | 58 |

The principal bottleneck was repeatedly processing a nearly 5,000-feature source
containing invisible markers, coupled to rebuilding canonical plans and image work
for visual ticks. In the measured dense settled frames the source falls from
4,988 features to 42 (mobile) / 55 (desktop); sparse frames hold two real markers.
Clustering still considers the complete input before source visibility filtering,
so this does not discard group members or alter counts to improve timing.

**Source write frequency increases.** The corrected topology engine now publishes
intermediate motion instead of failing during retirement or freezing until a full
resync. Each tick clones the cached canonical plan, preserves style/generation
guards, and avoids rerunning cover registration/clustering. Geometry changes still
require GeoJSON updates on this supported plugin path. Location pulse uses paint
updates separately. This trades more small, bounded writes and some image memory
for correct motion; it is not a claim of fewer source writes.

Dense icon registrations during the path: 81 → 93 at 390 px and 97 → 97 at
1440 px. Peak decoded cover memory rises from 35 images / 1.89 MB to 41 / 2.22 MB
on mobile width; desktop remains 41 / 2.22 MB. The bounded budget is preserved.
Dense cover requests/decoded transfer stay 36 / 522 KB (390) and 28 / 462 KB
(1440). Cover fetch/decode p95 drops from about 2.9 s to 88–104 ms;
PNG rendering and registration remain single-digit milliseconds. See per-run
counts and phase distributions in [metrics.json](metrics.json). Sparse runs do
not register cover images and do not establish cover-heavy behavior.

The first paired mobile trace publishes split/merge motion episodes over about
171–190 ms, versus baseline split entry episodes of 411–1058 ms. These are
**source-state publication spans**, not a separately measured first painted pixel.
Cold cover replacement can continue after topology settles (up to about 1.5 s
after the camera endpoint in these runs); warm replacement work is largely absent.
The canonical marker remains present during replacement. Rendered cover-appearance
latency is measured in [Cold-cover appearance](#cold-cover-appearance) below.

## Rendered evidence

The videos include the actual real-data map, slow split, immediate reversal,
pan and merge. Their wall-clock lengths differ because baseline work stalls the
event loop; camera targets and requested durations are identical.

- [Before video](before-split-reversal-merge.mp4)
- [After video](after-split-reversal-merge.mp4)
- [After at half speed](after-half-speed.mp4)
- [Before frame sequence](before-contact.png)
- [After frame sequence](after-contact.png)

The observed sequence shows canonical markers spreading during the split, cover
replacement without changing their geographic anchor, and convergence on merge.
It also retains evidence of the bounded cold-cover replacement tail; the video
is not evidence that all covers arrive simultaneously. Selection and gesture QA
is tracked separately from these unselected benchmark runs.

Low-zoom investigation found the overview's zoom-1.5 grid produced six nodes for
9,050 published records; requesting the existing zoom-3 aggregation produced
18 nodes for the same total. The frontend now uses that finer overview floor.
There is no backend sampling/classification mutation or fabricated marker.

## Tests and acceptance limits

The map module recorded 702 focused tests passing and full analysis passed.
PR #298's production-code head `32c62d69d11f14f50a02ea109497cee8dce3b120`
passed required remote CI. Later evidence/harness commits require their own
exact-head checks. [renderer-traces.json.gz](renderer-traces.json.gz) retains
the measured source frame/event traces; [metrics.json](metrics.json) is the
readable summary without those large arrays.

Physical Android/iOS frame, compass and interaction acceptance remains pending.
These results do not establish live protected-account acceptance, deployment,
merge, production acceptance or 0.8.3 release readiness. Original user screenshot
attachments were unavailable; no generated capture is treated as an approved baseline.

## Cold-cover appearance

Question: does prefetching through the continuous zoom approach and the shorter
64 ms cover-work spacing (`41a97d6f`) make covers appear sooner without worse
frame stalls? Compared builds: before = `c8a742e9` (parent of the change),
after = `304e0b08` (identical `lib/`). Release web builds, `main.dart.js` SHA256
`bbda62e8...330e` (before) and `d313a690...093b` (after). Chromium, hardware GL
(RTX 3080 Ti via ANGLE/D3D11, headless), the same frozen HTTP responses and
300-marker fixture, identical camera endpoints, one browser at a time,
before/after alternating per round, no builds or other browsers running. Raw rows:
[cold-cover-results.json](cold-cover-results.json). Not a physical-device result.

**Appearance** (3 paired runs each; the camera eases 10.5 to 13.4 over 2.8 s; times
are after the camera first crosses zoom 13; "n" is distinct covers painted by the
end):

| Viewport / cache | Build | n | First cover ms | Last cover ms |
| --- | --- | --- | --- | --- |
| 390 cold | Before | 26-27 | 300-306 | 3195-3371 |
| 390 cold | After | 31-32 | 0-57 | 3421-3437 |
| 390 warm | Before | 39-40 | 0 | 1377-1460 |
| 390 warm | After | 40 | 0 | 441-481 |
| 1440 cold | Before | 24-27 | 365-439 | 3218-3403 |
| 1440 cold | After | 26-27 | 316-375 | 3175-3260 |
| 1440 warm | Before | 43 | 0 | 1840-1981 |
| 1440 warm | After | 42-43 | 0 | 1005-1243 |

Canonical markers are present at zoom 13 in both builds (54 of 54, first at 0 ms),
so a cover never replaces a missing base marker. The cold last-cover time stays
bound by fetch/decode of the replayed images; the change moves the first covers
earlier, lets more of them land during the zoom, and cuts warm completion to
roughly a third (390) or about 60 percent (1440) of the previous time.

**Frame pacing and cost** (topology path, 3 paired runs per cell, rAF intervals):

| Viewport | Build | p95 ms | frames over 50 ms | max ms | marker source writes | image adds / peak active |
| --- | --- | --- | --- | --- | --- | --- |
| 390 | Before | 16.8 | 4-6 | 300-316.7 | 160-169 | 93 / 96 |
| 390 | After | 16.8 | 4-6 | 216.7-316.5 | 136-142 | 93 / 96 |
| 1440 | Before | 16.8 | 5 | 300-316.7 | 137-142 | 97 / 100 |
| 1440 | After | 16.8 | 3-4 | 300-333.4 | 128-133 | 97 / 100 |

Severe stalls do not regress (the roughly 300 ms outlier is the same in both and
unrelated to cover work), marker source writes are equal or slightly lower, and
image registrations, peak active images and decoded cover memory (36 requests,
522 KB at 390) are unchanged, so the cover budgets are preserved. Estimated missed
60 Hz frames overlap between builds (390: 73-82 before, 82-86 after; 1440: 57-74
before, 60-71 after); this run does not claim a frame-pacing improvement. Each
configuration was run as its own process because repeated hardware-GL launches in
one process produced a blank first page in this environment (no measured run was
discarded). A one-request fixture miss at 1440 px appears in both builds.
