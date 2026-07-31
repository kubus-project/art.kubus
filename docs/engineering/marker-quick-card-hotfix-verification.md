# Marker quick-card hotfix: browser verification

Evidence for the map hotfix that (1) keeps event/exhibition markers on the shared
floating quick-details card and (2) removes the card's internal scroller.

Harness: [`output/playwright/verify_marker_quick_card.mjs`](../../output/playwright/verify_marker_quick_card.mjs).

## How to reproduce

```bash
puro flutter build web --release
npx http-server build/web -p 8099 -s --cors      # serve the exact release artifact
node output/playwright/verify_marker_quick_card.mjs \
  > output/playwright/qc-results.json \
  2> output/playwright/qc-stderr.log             # one JSON record per case, streamed
```

The harness serves **one fixture per page load**, pinned to the geolocation point
the camera follows, and selects it by clicking the map. The map is a WebGL
platform view, so a marker cannot be located by DOM query; pinning it to the
camera centre makes the initial tap deterministic and routes it through the real
`KubusMapController` selection path rather than a test-only shortcut.

Screenshots are written to `output/playwright/qc-<viewport>-<fixture>-{card,primary,final}.png`.
They are intentionally not committed (24 MB), matching the existing convention
for this directory.

## Coverage

| Viewport | Size | Fixtures |
| --- | --- | --- |
| desktop | 1440x900 | all 8 |
| narrow desktop / tablet | 1024x768 | event-valid, orphaned-subject, long-description, stacked |
| mobile | 390x844 | all 8 |
| short mobile / landscape | 844x390 | event-valid, orphaned-subject, long-description, stacked |

Fixtures: `artwork`, `street-art`, `event-valid`, `exhibition-valid`,
`orphaned-subject`, `long-attribution`, `long-description`, `stacked`.

`orphaned-subject` reproduces the verified production shape exactly: marker
`312d350e-72a7-47f9-9654-b9a2eaf2e9d1` ("Ponjava VI"), `markerType: event`,
`metadata.subjectType: exhibition`, `metadata.subjectId:
8a1d8347-fada-4755-95d2-6024519c93cd`, with both `/api/exhibitions/8a1d…` and
`/api/events/8a1d…` stubbed to `404`.

## Results

24 records, all viewports:

- **24/24** initial taps opened the floating quick card. No tap opened a popup, a
  detail page, or a side panel.
- **0/24** showed the legacy marker-info dialog, on tap or after the primary
  action. (Detected by its copy, `No linked artwork found for this marker yet.`)
- **0/24** added a scroll container. The metric is the delta between the page's
  own scrollable elements before selection and after, so it is card-scoped.
- Primary-action routing matched the expected surface in every case:
  - `artwork`, `street-art` -> artwork detail
  - `event-valid` -> event detail (canonical entity data)
  - `exhibition-valid` -> exhibition detail side panel (canonical entity data)
  - `orphaned-subject`, `long-attribution`, `long-description`, `stacked` ->
    generic marker-detail surface

Five records were classified `unknown` by the first pass of the harness rather
than by the app: Flutter's semantic nodes are visually hidden, so
`document.body.innerText` omits them on the pushed mobile page while the
`aria-label`s carry the same strings. Those five were confirmed from their
screenshots and the classifier now searches both channels.

One tablet record (`long-description`) recorded a misclick: a forced click landed
on the map's attribution control and opened the "Map attributions" dialog. The
quick card is correctly composed behind it in the screenshot. The harness no
longer forces that click.

## Visual confirmations

- **Event/exhibition initial tap opens the floating card.** `qc-desktop-1440x900-orphaned-subject-card.png`
  shows the Ponjava VI card with the `Exhibition` kicker, the title, and
  `Kino Siska - 2026-08-01 -> 2026-08-10` resolved from *marker* metadata (the
  canonical exhibition is gone), badges, description, three attribution rows, and
  `More info`.
- **No internal scrollbar; image not crushed.** `qc-desktop-1440x900-artwork-card.png`
  shows a full 180px cover with a ten-line description below it — against the
  pre-hotfix five lines inside a 92px scrolling box.
- **Description and attribution readable.** `qc-tablet-1024x768-long-description-card.png`
  shows all three long credit rows wrapping to two lines each, fully legible, with
  the description above them uncropped.
- **Save/Share and the primary CTA remain visible.** `qc-mobile-390x844-street-art-card.png`
  shows Claim / Save / Share / Like as icon-only actions plus `View details`.
- **Valid entities open the correct detail surface.** `qc-desktop-1440x900-exhibition-valid-primary.png`
  shows the existing exhibition side panel with canonical title, dates, venue,
  status, description, artwork count, and its own actions.
- **Orphans open the generic detail surface, never the legacy popup.**
  `qc-desktop-1440x900-orphaned-subject-primary.png` (desktop panel) and
  `qc-mobile-390x844-orphaned-subject-primary.png` (mobile page) both show the
  `Marker information` kicker and the notice *"The linked exhibition for this
  marker is not available, so the details below come from the marker itself"*,
  followed by dates, venue, category, distance, description, attribution, and
  `Open on map` / `Share`.
- **Short viewports compact deliberately.** `qc-mobile-landscape-844x390-long-description-card.png`
  (844x390) shows the reduced-media composition: header, smaller cover, distance
  badge, and the primary CTA, with no scroller and no overflow. At that height the
  description and attribution are dropped rather than scrolled; the full text
  stays reachable through the primary action.

## Known limitation of the harness

`mediaVisible` cannot be asserted from the DOM: CanvasKit paints the cover into
the canvas, so there is no `<img>` to query. The media area is verified from the
screenshots and, in unit tests, by measuring the rendered
`marker_overlay_media` box against
`MarkerOverlayCardMetrics.mediaHeightRegular`.
