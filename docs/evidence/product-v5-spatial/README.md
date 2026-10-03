# Evidence: PRODUCT v5 spatial map system (Wave 5B)

Companion to [`docs/design/PRODUCT_V5_SPATIAL_SYSTEM.md`](../../design/PRODUCT_V5_SPATIAL_SYSTEM.md).
Bounded on purpose: curated captures and the text results of the final runs on
the branch head. Intermediate runs, APKs, emulator logs and the A/B fixture are
not kept. Every number in the design document comes from a file here or from the
scripts that produced it.

What was run, where, and with what:

| Evidence | Where it came from | Script |
| --- | --- | --- |
| Browser QA, Chromium + Firefox, 1440x900 and 390x844, light and dark, offline tiles, WebGL context loss | local release web build served from `build/web`, public reads passed through, every write and analytics call answered locally | `scripts/qa/product_v5_spatial_browser_qa.mjs` (`results/browser-qa-chromium-main.txt`, `...-firefox-main.txt`) |
| UI flows: search constraint, Reset all, marker preview, entity and Back, layout swap in both directions, EN and SL | same | `QA_FLOW=ui` (`results/browser-qa-*-ui.txt`) |
| Responsive openings at 320, 390, 768, 1440, 1920 | same | `QA_FLOW=responsive` (`results/browser-qa-*-resp.txt`) |
| Real 200 % browser zoom | Chromium headed with the browser's own zoom level (the page reports ~712 CSS px at 2x); Firefox at the 720x450 CSS px, 2x density equivalent because Playwright cannot set Firefox's page zoom | `QA_FLOW=zoom200` (`results/browser-qa-zoom200.txt`) |
| Web frame pacing, dev against Wave 5B, before and after the cover-work fix | one machine, quiet (emulator stopped), pinned marker dataset, every external read replayed from disk, 5 runs per cell, configurations interleaved | `scripts/qa/product_v5_spatial_perf_ab.mjs` (`results/web-frame-pacing-real-gpu.txt`, `results/web-frame-pacing-software-gl.txt`) |
| Android emulator frame pacing | API 34 x86_64 emulator, host GPU, signed release APKs; EMULATOR ONLY | `scripts/qa/android_emulator_map_perf.sh` (`android/*-frames.txt`) |
| Android rotation reproduction | fresh emulator boot per run, 20 portrait to landscape cycles, two states, two runs each, baseline against branch | `scripts/qa/android_rotation_repro.sh` (`android/rotation-*-summary.txt`) |

## Captures (`browser/`)

* World to street on desktop (light): `desktop-light-01-world-globe` (web globe),
  `-02-region-far-dots` (cheap GPU dots), `-03-country-canonical-markers`,
  `-04-city`, `-05-street-covers` (bounded covers inside the canonical marker),
  `-06-close-street`, `-07-selected-street`; dark: `desktop-dark-*`.
* Phone: `phone-light-01..04` (the last is the selected marker at far zoom, the
  frame the pixel proof reads), `phone-dark-01`.
* Constraints: `desktop-en-01`, `desktop-sl-01`, `phone-en-01`, `phone-sl-01`
  (search is shown as a constraint with an individual clear and Reset all).
* Marker preview and entity round trip: `desktop-en-02`, `desktop-en-03`,
  `phone-en-02`.
* Layout swap with camera, search and selection kept: `layout-swap-1..3`.
* Degraded paths: `desktop-light-08-after-webgl-context-loss`,
  `desktop-light-09-offline-tiles`.
* Responsive openings: `responsive-*`. Firefox: `firefox-desktop-light-street-covers`.
* Real 200 % zoom: `zoom200-*` (the Chromium captures are whole-viewport CDP
  captures at device resolution; Playwright's own screenshot crops under page
  zoom).

## Android (`android/`)

`branch-fresh-install-opening-flat-map` is the first frame of a fresh install of
the branch: straight onto the flat map, no notice, onboarding, account wall or
permission prompt. The rotation summaries record, per run, cycles completed,
`FATAL EXCEPTION`, `PlatformViewsController`, `SurfaceProducerPlatformViewRenderTarget`
and process-death counts. The `NullPointerException` counts in them come from
Google Play services and other system processes.

## Not evidence

* **No physical Android device was available. Physical-device performance is not
  verified.** The emulator numbers are labelled as such everywhere.
* iOS: no macOS host. The only iOS evidence is the CI compile job.
* Firefox was not driven at a true page zoom (see the table above).
