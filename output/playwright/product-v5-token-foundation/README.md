# PRODUCT v5 token foundation visual evidence

These captures render the test-only token preview at `test/visual/product_v5_token_preview.dart`. They verify the shared token, theme and primitive fixture only. They are not screenshots of production entity data or a claim that all app screens have migrated.

## Capture record

- Source implementation commit: `6deee1170ed8df3c0ff963904611da7a9c786361`; the test-only preview and evidence index are included in the following QA/documentation commit.
- Fixture: local PRODUCT v5 token preview, English copy, light/dark theme controls, browser JavaScript enabled.
- No production services or records were used.
- Viewports: 390 × 844 and 1440 × 900; separate captures use browser zoom at 200%.
- Assertions: page width stayed within the viewport at 390 and 1440, including 200% zoom; the focus ring remained visible; hover had no generic glow; reduced-motion preference was enabled for the hover capture.

## Chromium

| Capture | Viewport/state | What it checks |
| --- | --- | --- |
| `tokens-chromium-390-light.png` | 390 × 844, light | Neutral ground/surface, type and button roles at mobile width |
| `tokens-chromium-390-dark.png` | 390 × 844, dark | Dark semantic counterpart and status roles |
| `tokens-chromium-1440-light.png` | 1440 × 900, light | Full token and primitive fixture |
| `tokens-chromium-1440-dark.png` | 1440 × 900, dark | Full dark token and primitive fixture |
| `tokens-chromium-390-light-200pct.png` | 390 × 844, 200% zoom | Narrow zoom behavior and reflow |
| `tokens-chromium-1440-light-200pct.png` | 1440 × 900, 200% zoom | Desktop zoom behavior and reflow |
| `tokens-chromium-390-keyboard-focus.png` | 390 × 844, keyboard focus | Visible focus state on an interactive control |
| `tokens-chromium-1440-primary-hover-reduced-motion.png` | 1440 × 900, reduced motion | Restrained hover without glow or required animation |

`tokens-chromium-390-200pct-lower.png` is a lower-page companion capture of the narrow 200% fixture.

## Firefox

| Capture | Viewport/state | What it checks |
| --- | --- | --- |
| `tokens-firefox-390-light.png` | 390 × 844, light | Mobile light-theme rendering |
| `tokens-firefox-390-dark.png` | 390 × 844, dark | Mobile dark-theme rendering |
| `tokens-firefox-1440-light.png` | 1440 × 900, light | Desktop light-theme rendering |
| `tokens-firefox-1440-dark.png` | 1440 × 900, dark | Desktop dark-theme rendering |
| `tokens-firefox-1440-light-200pct.png` | 1440 × 900, 200% zoom | Desktop zoom reflow |
| `tokens-firefox-1440-keyboard-focus.png` | 1440 × 900, keyboard focus | Visible keyboard focus treatment |

The browser smoke test separately exercised Flutter web runtime startup. This fixture demonstrates the semantic token surface and common shared primitives; screen-by-screen migration remains later work.

## Existing app regression sample

These two additional captures came from the repository's `npm run qa:web`
runtime smoke at `2026-09-23T13:29:18Z`. Its report recorded Chromium, a dirty
working tree based on `251130ec6296c24ad317c5231d8dd365ed513874`, matched
served/build JavaScript hashes, and zero console, HTTP, page, or request
failures. The home screen still contains older blue hero and colored status
surfaces; those are recorded migration debt, not changed in this foundation.

| Capture | Viewport/state | What it checks |
| --- | --- | --- |
| `app-home-chromium-1440x1100-light.png` | 1440 × 1100, light | Current app desktop shell, navigation and inherited theme |
| `app-home-map-chromium-390x664-light.png` | 390 × 664, light | Current compact shell and map surface; marker/category colors remain contextual |

The artwork, artist, institution and event screenshots in the separate Wave 2B
branch were reviewed as pre-foundation references. They are not represented as
screenshots of this token branch; the Wave 2B branch should rerun its visual
matrix after stacking on this foundation.
