# SSR WORLD HANDOFF section: design contract

The inline section of a public entity document ("The world of art is coming into focus…" with Retry and
Go to app). It is progressive enhancement of a genuine server-rendered page: it never replaces SSR content,
adds no heading (the entity keeps its one `<h1>`), and leaves canonical URLs, hreflang, JSON-LD, links and
status codes untouched.

## One design, two renderers

| Renderer | File |
| --- | --- |
| Backend (`art.kubus-backend`) | `src/services/takeoverStatusDesign.js` (source of truth), used by `seoPublicPagesService.js` |
| PHP gateway (this repo) | `web/seo-proxy.php`: `KUBUS_TAKEOVER_STATUS_CSS`, `KUBUS_TAKEOVER_GLOBE_SVG` |

The PHP constants are generated, never hand-edited:

```bash
node scripts/sync_takeover_status_design.mjs ../art.kubus-backend
```

Both repositories pin the same SHA-256 of `css + NUL + svg` (currently `67d5646157a09d963ed6a56de79407cf6246f5923760a904b773549f463c7ce5`; backend `__tests__/seoPublicPages.test.js`, this repo
`test/takeover_status_design_parity.test.js`). Changing the design means: edit the backend module, run the sync
script, update the hash in both tests. A change on one side only fails CI on whichever repository is behind.

## Composition

Label (`THE WORLD IS OPENING`, Space Mono) and message (Sofia Sans 24 to 36 px, the only live region) sit in one
`takeover-head` wrapper, then a note, a fine trace and Retry and Go to app. Mobile is a compact flex section: the
globe (3.25 rem) sits beside the head, and the head wraps below the globe when text is scaled up. The trace leaves
the flow and becomes the section's 2 px bottom edge. From 760 px the section is a wide two-column grid: the globe
(8.5 rem) spans the left column and the head, note, trace (max 22 rem) and actions stack in the right column. While loading,
Go to app is the primary action; once loading has failed, Retry is. Copy lives in `LOCALES` (backend),
`KUBUS_TAKEOVER_COPY` (PHP) and `public_flutter_takeover.js` (failure and loading text, kept in parity by tests).

## Performance rules (each one is enforced by a test or was measured)

- Inline CSS and six tiny inline SVGs plus two spans: no request, no font, no script, no image. About 1.4 KB gzip
  added to a document, 0 added requests.
- Animation is CSS only, on `transform` and `opacity`, never on layout properties, never with `will-change`, filters
  or blur, no `requestAnimationFrame` loop.
- **Never animate SVG children.** Chromium runs transform/opacity animations of SVG child elements on the main thread
  (a trace showed one Layout, Paint and Commit per frame). The globe is therefore four static SVG *roots* (three
  longitude arcs each, 15 degrees apart) cross-faded with `opacity`, plus an HTML marker moved with `transform`; the
  trace is a pseudo-element. Steady state: 0 Layout, 0 Paint, 0 script, about 2 ms main-thread per 3 s.
- The still frame equals the animation's first frame (pose 0, marker at the orbit's end, trace off-screen), so
  starting the motion changes nothing visible. This kept Speed Index equal to FCP.
- Motion starts only once the takeover script has set the loading state (`data-state=loading|slow`). Before that
  (pending, no script), after failure and in reduced motion the globe is static. Starting animations while the
  script made its first DOM mutations sometimes left Chromium running them on the main thread.
- A hidden tab pauses the animations (`data-paused`, one `visibilitychange` listener). Reduced motion shows the
  static globe with the same hierarchy and every action.
- The section is painted at first paint (`takeover_capability.js` handshake), so its box is final before the first
  frame; old production JavaScript with the new backend degrades to a hidden section, never a stuck loader.

## Verifying

Local harness (real backend router plus these `web/` assets with a controllable Flutter stub) and results:
`docs/qa/ssr-world-handoff-20261027/README.md`. The real engine handoff on `dev.kubus.site` needs the Basic-auth
credential and is not covered by the harness.
