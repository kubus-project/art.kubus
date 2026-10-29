# WORLD HANDOFF: real-engine acceptance and production performance, 2026-10-28

Merged: app #368 -> `dev` `b37aa39a7c9fb3c2feff717194b924d695a50033`; backend #147 -> `master`
`6c221d8e40b9c340d53cf585b248f80d7691ebcb`. Design hash `0fd9827a...6fe51` on both reviewed heads.

## Setup (what "real" means here)

- The **exact development web artifact** of the merge (`flutter-web-development-b37aa39a...`, `kubus-web-revision.txt`
  = merge SHA): the real Flutter engine, real takeover scripts.
- The **merged backend SSR renderer** with a **real production artwork** ("Mary's column",
  `2890e5ec-3fdd-474e-a0ee-b16e5097b669`), read-only from the public API and mapped into the renderer's row shape.
- A local server (`127.0.0.1`), not `dev.kubus.site`: the dev host is behind Basic auth and no credential is available,
  so **the deployed dev host itself was not browser-tested** and the PHP gateway path was not exercised. No stub and
  no synthetic `kubus:public-entity-ready` event is used anywhere below; the events are the engine's own.
- Faults are injected at the server (`flutter_bootstrap.js` 500, `main.dart.js` 500, `main.dart.js` delayed) and the
  entity API (503) by request interception.

## Real-engine matrix (`real-engine-matrix.json`, `real-engine-nav.json`)

Chromium and Firefox, mobile (390x844) and desktop (1280x800), EN and SL, 48 runs + 8 navigation runs.

| Check | Result |
| --- | --- |
| Raw HTTP: meaningful SSR, one `h1`, canonical, JSON-LD, status section | all runs |
| Section visible and animating while the engine loads (6 s delayed engine) | 8/8 |
| Engine starts, requests the entity (`/api/artworks/<id>`) | 24/24 normal, delayed, nav |
| Engine's own `public-entity-ready`: type, id, path, locale exact | 24/24 |
| Handoff only after ready; status removed; URL unchanged (canonical path kept) | 24/24 |
| Takeover time (normal) | 2.2 to 3.5 s (Chromium 2.4 to 3.5, Firefox 2.2 to 3.0) |
| After handoff: SSR document `inert` + `aria-hidden`, Flutter host live (no duplicate accessible document) | 24/24 |
| The real artwork is rendered (not an empty canvas) | screenshot `real-engine-desktop-en-after-handoff.jpg` |
| Genuine failure (bootstrap 500 or main.dart.js 500): failed state, SSR readable, animations stopped, no ready event | 16/16 |
| Retry: one reload per activation; Go to app href `/map?lang=<locale>` | 16/16 |
| Go to app opens the real Flutter map; Back returns to the entity and the engine takes over again | 8/8 |
| Page errors | none |

Entity API returning 503 for every call (`fail-api`) still completes the takeover: the engine renders the entity from
the SSR bootstrap JSON embedded in the page (`kubus-public-entity-bootstrap`), so this is not a failure case by
design; the section only fails when the engine or its bootstrap cannot load.

## SEO parity on real data

Baseline renderer (`master` `fbcc7a8`) vs merged renderer, same artwork, EN and SL: title, canonical, robots, JSON-LD,
`h1` and all 10 links identical; the whole document is identical after removing the status block and its CSS except
the bootstrap JSON `generatedAt` / `expiresAt` timestamps. `hreflang` count is 0 in both (this artwork has no
translation alternates), so no change.

## Performance on real data (local Lighthouse 12.8.2, 5 runs each, `lighthouse-real-data.json`)

Same machine, gzip like the edge, the real 4.3 MB hero image from Wikimedia.

| | mobile perf | desktop perf | mobile LCP | desktop LCP | mobile TBT | mobile CLS |
| --- | --- | --- | --- | --- | --- | --- |
| A. SSR only (no takeover, no JS) | 61 | 79 | 23.1 s | 4.0 s | 0 | 0.27 |
| B. SSR + WORLD HANDOFF animation (engine withheld) | 64 to 67 | 79 | 23.1 s | 4.0 s | 0 | 0.17 |
| C. Real SSR + full Flutter takeover | 30 | 60 to 62 | 34.4 s | 5.6 s | 1 894 ms | 0.17 |
| D. A with a resized hero (experiment) | 86 | **100** | 1.5 s | 0.5 s | 0 | 0.27 |
| E. C with a resized hero (experiment) | 25 to 53 | 79 to 81 | 1.6 s | 0.4 s | 3 651 ms | 0.17 |
| F. E + engine deferred until load + idle (experiment) | 47 to 53 | 78 to 81 | 2.3 s | 0.4 s | 3 466 ms | 0.17 |
| Live production page (earlier run, 3x) | 21 to 25 | 50 to 53 | 23.2 s | 4.1 s | 2 804 ms | 0.22 |

Accessibility 100 and SEO 92 to 100 throughout. **The earlier "100 to 100" figures were measured without a real hero
image and must not be read as a production result.**

### What actually costs the score

1. **The hero image (LCP).** The SSR `<img>` is the original 4.3 MB Wikimedia JPEG (`width=1200` attribute, 4 176 KiB
   of savings flagged). It is the LCP element and it competes for bandwidth with 8.5 MB of Flutter. Serving a 1200 px
   variant takes LCP from 23 s to 1.5 s (mobile) and gets SSR-only desktop to **100** (D). Biggest, lowest-risk lever;
   it is an SSR renderer change (Wikimedia `thumb/` URLs, a resize endpoint for other hosts, `srcset`).
2. **Flutter starts at once and contends with the hero** (`canvaskit.wasm` 5.77 MB and `main.dart.js` 2.77 MB gzip
   begin at about 260 ms). With the hero fixed (E) LCP is 1.6 s, but the engine's main-thread work then dominates:
   TBT 1.9 to 3.7 s on mobile, Speed Index 12 s.
3. **`canvaskit.wasm` is served uncompressed in production** (5 760 502 B on the wire; 2.2 MB gzip). Lighthouse flags
   3.0 MB of text-compression savings. Check the nginx `gzip_types` / brotli for `application/wasm`.
4. **Unused JavaScript:** 1.96 MB of `main.dart.js` unused on an artwork page; the engine also fetches basemap tiles
   (3.7 MB, `cartocdn` in production) that the artwork view does not need.
5. **CLS 0.17 to 0.27 from the Google web-font swap** of the entity layout (`display=swap`), with or without the
   section. It alone keeps SSR-only mobile at 86 instead of 100.
6. Deferring the engine until load + idle (F) **did not help** in the lab (TBT unchanged, FCP worse) and delays
   interactivity; not recommended as is.

### Recommended bounded work (separate PRs, not done here)

1. Backend: size-appropriate hero (`srcset`, Wikimedia thumb URLs) in `normalizePublicImage` / the entity renderer.
2. Edge: gzip/brotli for `canvaskit.wasm` (-3.5 MB).
3. Backend renderer: web-font `display=optional` or a metric-matched fallback to remove the font-swap CLS.
4. Flutter: do not start the basemap on entity pages; split or defer unused code.
5. Targets: SSR-only/animated page 100 desktop and >= 90 mobile after (1) and (3); full Flutter experience
   LCP <= 2.5 s (reachable after (1)), CLS <= 0.1, INP <= 200 ms, TBT as an explicit budget; its Lighthouse score is not
   expected to reach 100 while the engine boots on the main thread.

## Visual and accessibility (real artwork)

At 320x700 and 390x844 the real hero image is large, so the entity title is below the first screen even at 100% text
(title top 909 / 988 px; the image top is at 423 px and half-visible). The section accounts for 282 px of that; with
the old bar (93 px) the title would sit near 800 px, i.e. just inside 390x844. **Assessment:** the SSR-first intent
holds (the section, the artwork image and breadcrumbs are on the first screen), but the title no longer is; on short
phones the note could be hidden or the section compacted. Not changed here; flagged for the owner.

Text scaling (`textscale-*`): no horizontal overflow at 100/150/200% in EN and SL at 320x700 and 390x844, no overlapping
actions; at 150% on 320 px Slovenian "Pojdi v aplikacijo" reached the viewport edge. Fixed in the follow-up PR (auto-fit
actions grid); at 200% the section is taller than a 700 px viewport (1 048 px), which is expected at that scale.

## Not verified

The deployed `dev.kubus.site` host and the PHP gateway in a browser (Basic auth); WebKit; physical devices; PageSpeed
Insights proper (the API is unreachable from this machine); the hero-image fix and the other optimisations were
**experiments only** and are not in any merged code.
