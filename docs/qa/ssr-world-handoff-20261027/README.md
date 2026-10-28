# SSR WORLD HANDOFF section: before and after, 2026-10-27

Design contract: [`docs/engineering/ssr-world-handoff-design.md`](../../engineering/ssr-world-handoff-design.md).
Baseline: app `dev` `cd4f1ee6` + backend `master` `fbcc7a8` (the merged #366 / #146 section). Candidate: branch
`feat/ssr-world-handoff-design` in both repositories.

## Confirmed design problem

The merged section was a 14.4 px, one-line status bar (62 to 93 px tall) with rounded corners and a drop shadow.
It was easy to overlook and carried no sense of place. See `before-*` screenshots.

## Implemented

A flat editorial band: label (`THE WORLD IS OPENING`, Space Mono), the loading message in Sofia Sans at 24 to 36 px
(the only live region), a quiet note, a fine trace, then Retry and Go to app; an inline globe (limb, parallels, a
tilted orbit with one travelling marker) leads on the left (>= 760 px) or above. Go to app is the primary action
while loading; Retry is once loading has failed. EN and SL copy as specified. Reduced motion, failure and a hidden
tab keep the static globe with the same hierarchy and every action.

| viewport | before: height / message | after: height / message | entity H1 top before / after |
| --- | --- | --- | --- |
| 320×700 | 93 px / 14.4 px | 282 px / 24.0 px | 544 / 729 |
| 390×844 | 93 px / 14.4 px | 282 px / 24.0 px | 544 / 729 |
| 430×932 | 93 px / 14.4 px | 256 px / 24.5 px | 512 / 671 |
| 768×1024 | 62 px / 14.4 px | 259 px / 29.9 px | 217 / 410 |
| 1280×800 | 62 px / 14.4 px | 266 px / 36.0 px | 232 / 432 |
| 1440×900 | 62 px / 14.4 px | 266 px / 36.0 px | 234 / 434 |

3 to 4 times taller, message 1.7 to 2.5 times larger. At 320×700 the entity title is below the first viewport (it was
at 544), but the breadcrumbs and the image start are visible; at 390×844 and up the title is on screen. No horizontal
overflow in any captured state, action height 44 px, loading and slow states have the same box, failure is a compact frame
(208 to 264 px).

Animation: four static SVG layers (three longitude arcs each, 15 degrees apart) cross-fade with `opacity` in an 8 s
loop (a 60 degree turn repeats the graticule, so it is seamless); the marker is an HTML box moved along a tilted
orbit with `transform` (and dims on the far side); the trace is a pseudo-element on `transform`. Nothing animates
layout; there is no script, request, font or image.

## Performance (local harness, Lighthouse 12.8.2, same machine and Chrome)

The harness serves the real backend renderer and this repository's `web/` takeover assets with a stub Flutter
bootstrap, gzip like the edge. Interleaved A/B (baseline and candidate alternating, 8 rounds per row,
`lighthouse-ab-interleaved.json`), medians:

| page | arm | Perf (runs) | A11y | BP | SEO | FCP | LCP | SI | TBT | CLS | requests | transfer |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| EN desktop | base | 100 (99 once) | 100 | 96 | 100 | 439 ms | 439 ms | 439 ms | 0 | 0.000 | 8 | 65 546 B |
| EN desktop | cand | 100 (99 once) | 100 | 96 | 100 | 441 ms | 441 ms | 441 ms | 0 | 0.000 | 8 | 67 227 B |
| SL desktop | base | 100 (8/8) | 100 | 96 | 100 | 450 ms | 450 ms | 450 ms | 0 | 0.001 | 9 | 84 103 B |
| SL desktop | cand | 100 (99 twice) | 100 | 96 | 100 | 446 ms | 446 ms | 446 ms | 0 | 0.000 | 9 | 85 810 B |
| EN mobile | base | 88 (82 to 88) | 100 | 96 | 100 | 1437 ms | 1437 ms | 1437 ms | 0 | 0.236 | 8 | 65 546 B |
| EN mobile | cand | 92 (87 once) | 100 | 96 | 100 | 1431 ms | 1431 ms | 1431 ms | 0 | 0.168 | 8 | 67 227 B |
| SL mobile | base | 100 (94 twice) | 100 | 96 | 100 | 1432 ms | 1432 ms | 1432 ms | 0 | 0.000 | 9 | 84 102 B |
| SL mobile | cand | 100 (8/8) | 100 | 96 | 100 | 1428 ms | 1428 ms | 1428 ms | 0 | 0.000 | 9 | 85 810 B |

- Added transfer: HTML +1 575 B EN and +1 601 B SL (gzip), `public_flutter_takeover.js` +106 B, so +1 681 B and
  +1 707 B per page in total; new requests: 0; target was <= 5 KB.
- **The baseline is not 100 everywhere.** Desktop is 100 (median) in both arms and stays 100. Mobile EN is 88 in the
  baseline and 92 in the candidate; the cause in both is CLS from the Google web-font swap of the entity layout
  (`Sofia Sans` / `Space Mono`, `display=swap`), unrelated to the section. The candidate's lower CLS is an artefact of
  the taller section pushing that block partly out of the viewport, not a fix. Not changed here; a follow-up
  (`display=optional` or metric-matched fallback) would lift EN mobile.
- 99-point runs (1 point) coincide with FCP outliers of 700 to 800 ms and occur in both arms across batches (baseline
  1 of 16 desktop A/B runs plus earlier batches, candidate 3 of 16). Medians are equal; this is environmental noise,
  not a measured regression. Stated plainly: the candidate was not 100 in every desktop run.
- Speed Index equals FCP in the A/B above. In a later run on a busier machine it rose above FCP in both arms
  (desktop EN, interleaved: baseline 543 to 758 ms, candidate 567 to 649 ms), so that spread is environmental. An
  earlier candidate whose still frame differed from the animation's first frame did show a real SI penalty
  (690 vs 444 ms); making the still frame identical to animation time zero removed it.
- Real production SSR pages (`app.kubus.site`, `lighthouse-production-reference.json`) score 21 to 25 mobile and
  about 50 desktop because they load the whole Flutter app (about 18 MB). They are not a 100 baseline; the harness
  isolates the section's own cost.
- Layout shift of the section: 0 at first paint, during loading and at handoff, with and without web fonts
  (`trace-*.json`, Chromium layout-shift API, 390×844 and 1280×800, EN and SL).
- Steady-state trace of 3 s of animation (`trace-candidate.json`): 0 Layout, 0 Paint, 0 UpdateLayoutTree, 0 script,
  0 long tasks, 0 to 1 ms main thread (baseline 0). Compositor, Viz and GPU threads about 100 ms per 3 s in a
  software-GL headless browser.
- In about 5% of page loads (2 of 40) Chromium kept the animations on the main thread: a style recalc and commit per
  frame, still 0 layout, 0 paint, no long task. It is gated by starting motion only after the takeover script has set
  the loading state; the residual rate is a Chromium behaviour we could not remove.

## Accessibility and structure

One live region (the message), decorative graphics `aria-hidden`, no heading in the section, one `<h1>` in the
document, tab order Retry then Go to app, 3 px focus ring, Lighthouse accessibility 100, native EN and SL copy
(`a11y.json`). After the handoff the document is made inert by the existing takeover, so focus falls to the body as
before. Native-language review of the Slovenian copy is a separate gate.

## Compatibility

- New backend + the old production web JS (`app.kubus.site/public_flutter_takeover.js`, no capability file): the
  section stays `hidden` (`display:none`), 0 animations, CLS 0, no stuck loader.
- No JavaScript: the section stays hidden; the ordinary SSR document is untouched (`en-light-390x844-ssr-nojs`).
- The first-paint handshake (`takeover_capability.js` + the `[hidden][data-state=pending]` rule) is unchanged except
  that the displayed value is `grid`.

## Browsers and states captured

Chromium: 6 viewports × light and dark × EN and SL × initial SSR (no JS), loading, animating, slow, failed,
reduced motion, handoff. Firefox: loading, animating, slow, failed, reduced motion at 390×844 and 1280×800 (renders
identically).

## Not verified

- The real Flutter engine handoff: `dev.kubus.site` is behind Basic auth and no credential is available here. The
  harness stub fires the same event shapes; it does not prove the real engine.
- WebKit, physical devices, field (CrUX) data, and PageSpeed Insights itself (local Lighthouse only).
- The hero image: the harness's local image URL is rejected by the renderer's public-image rules, so LCP is text.
- A deployment: nothing is deployed; production still serves the old hidden section.
