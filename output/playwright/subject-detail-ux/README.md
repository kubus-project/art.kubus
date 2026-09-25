# Subject detail participation UX visual evidence

Capture source: `0c7056c0596130c566f6d754ce4077fd823434dc` (the UI and accessibility changeset tested here).

This evidence was generated with the repository's public-entry browser harness and a local, public-only SSR preview at `http://127.0.0.1:4177`. The Flutter release web artifact was built from the same source. API requests were routed to that local preview. No production entity data or production API was used.

## Browser run

- Chromium 153.0.8010.53 (installed Chrome executable)
- Firefox 151.0 (Playwright browser)
- Reduced motion: enabled for each browser context
- Normal captures: 390 × 844 and 1440 × 900
- Breakpoint captures: 900, 1024, and 1280 px; widget tests separately cover 899/900/901
- The full run produced 142 case records and 294 screenshots. This package retains 126 curated screenshots to keep the PR reviewable. `visual-matrix.json` preserves all 142 case results and layout metrics; its `screenshotFiles` lists only files retained in `evidence/`.
- No case reported horizontal overflow.

Each result in `visual-matrix.json` records the source SHA, browser, viewport, theme, locale, entity type and ID, fixture identity, SSR/Flutter state, JavaScript state, reduced-motion setting, zoom mode, and any retained screenshot paths.

## Fixture identities

All records below are synthetic public-only local preview fixtures, not live production records.

| Entity | Fixture ID |
| --- | --- |
| Artwork | `11111111-1111-4111-8111-111111111111` |
| Artist profile | `22222222-2222-4222-8222-222222222222` |
| Institution profile | `99999999-9999-4999-8999-999999999999` |
| Event | `33333333-3333-4333-8333-333333333333` |
| Exhibition | `44444444-4444-4444-8444-444444444444` |
| Collectible | `55555555-5555-4555-8555-555555555555` |
| Post | `66666666-6666-4666-8666-666666666666` |
| Collection | `77777777-7777-4777-8777-777777777777` |
| Marker | `88888888-8888-4888-8888-888888888888` |

The artwork evidence covers EN and SL, 390 and 1440 px, light and dark themes, SSR without JavaScript and Flutter takeover, in Chromium and Firefox. The retained set also includes representative profile, institution, event, exhibition, collection, post, marker, collectible, slow-load/failure, keyboard-focus, long-text, and narrow-width captures.

## Visual review findings

- Artwork remains media-led at mobile and desktop widths. Its title and cultural attribution remain prominent; the subject action group is labeled, wraps on compact widths, and does not show the legacy artwork reward value.
- Like is exposed as a keyboard-focusable switch with a visible 3 px focus outline. The browser harness reaches this action after enabling Flutter accessibility; SSR becomes inert only after exact entity takeover.
- Compact event and exhibition Flutter entry now places the entity cover before identity and description. Desktop remains a side-by-side context/media composition.
- **Known compact handoff difference:** current server-rendered event/exhibition HTML remains identity/context-first, while Flutter is cover-first. The two first frames therefore reorder visibly on compact takeover. This app PR does not own the SSR renderer, so the discrepancy is recorded for a coordinated renderer follow-up rather than hidden. Desktop SSR and Flutter keep media beside the context column.
- The browser zoom shortcut did not change page zoom. Both browser records are `real-browser-zoom-unverified`; the 195 CSS px / DPR 2 narrow viewport is a separate responsive simulation, not 200% zoom evidence.

## Reproduction

Build and serve the Flutter web artifact using the repository's normal public-entry preview setup, then run:

```powershell
$env:QA_ARTIFACT_DIR='output/playwright/subject-detail-ux'
$env:SEO_PREVIEW_URL='http://127.0.0.1:4177'
$env:WAVE2B_SOURCE_SHA='0c7056c0596130c566f6d754ce4077fd823434dc'
$env:WAVE2B_BROWSERS='chromium,firefox'
node .\scripts\qa\wave2b_visual_acceptance.mjs
```

The local preview service and its fixture-only configuration are not part of production deployment instructions. Do not treat these images as production-data evidence.

## Event and exhibition SSR ordering closeout

The responsive SSR renderer follow-up is tracked in backend PR #68 (`fix/subject-detail-ssr-ordering`). It keeps the semantic detail-first HTML and applies compact-only visual ordering for Event and Exhibition. Event uses its labeled date/location facts without repeating the same venue as a loose line; Exhibition keeps institution context ahead of date facts. The target recapture is in `ssr-ordering-closeout/continuity.json` with the paired SSR and Flutter screenshots. It covers Event and Exhibition at 390 px in Chromium and Firefox, and at 1440 px in Chromium. SSR ordering was also measured at 900, 1024, and 1280 px. The fixtures are synthetic public-only local preview records.

Both compact subjects pass the continuity check: media starts at y=70 and the title at y=584. Event date/location facts follow the title at y=650. Exhibition institution context follows the title at y=643, then date/location facts at y=690. Both browsers report a 390 px document width and scroll position 0. Flutter takeover keeps the same canonical path and scroll position, fills the viewport, and has no horizontal overflow. In the paired screenshots, media stays first and the title and identity/context follow it after takeover. Desktop remains a two-column detail-left/media-right composition at 900, 1024, 1280, and 1440 px; the 1440 SSR/Flutter screenshots are included.

Reproduce the focused recapture with `node scripts/qa/subject_detail_ssr_ordering_closeout.mjs` while the backend's fixture-only SEO preview is running at `http://127.0.0.1:4177`.

## Human 200% browser zoom check (required; not yet performed)

Automated genuine browser zoom is unavailable in this environment. The previous browser shortcut attempts did not alter browser page zoom; viewport changes, DPR changes, and CSS zoom are not accepted as substitutes. A human must complete and record this check before calling 200% zoom verified:

1. Open the integrated #182 build in Chrome or Firefox.
2. Set browser zoom to 200% using the browser UI.
3. Check representative Artwork desktop, Event, Exhibition, Artist profile, and Institution profile pages.
4. For each page, verify there is no horizontal page overflow, no clipped title, no inaccessible action, no hidden Share/Save/Discuss action, no action bar collision, and no content hidden under navigation.
5. Verify keyboard focus remains visible.
6. Enter each subject from its canonical URL and verify SSR → Flutter takeover remains usable.
7. Record browser name, version, and the result for each representative page.

Status remains `TRUE 200% BROWSER ZOOM REQUIRES HUMAN VERIFICATION` until a human records the check.
