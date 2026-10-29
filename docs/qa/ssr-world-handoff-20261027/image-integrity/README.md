# Artwork image integrity, 2026-10-28

Owner decision: the WORLD HANDOFF loading section must not crop the artwork photograph, and the title may need
scrolling. The tall-phone hero cap (`@media(max-width:760px) and (min-height:800px){html:has(#flutter-takeover-status:not([hidden])) .entity-media img{max-height:min(55vh,max(18rem,calc(100svh - 32rem)))}}`) is removed from the shared design; nothing replaces it.
Design hash `67d5646157a09d963ed6a56de79407cf6246f5923760a904b773549f463c7ce5` (was `f8be2c08...`) on backend and gateway.

## Finding: the ordinary layout also cropped the artwork

Real artwork "Mary's column" (`2890e5ec-3fdd-474e-a0ee-b16e5097b669`): a 2:3 portrait photograph. The product CSS shows it with
`object-fit: cover` inside a height-capped box (55vh on phones, 72vh from 761 px), so the ordinary SSR page, with no
loading section at all, already hid part of the photograph. Measured visible fraction, merged baseline vs corrected
(Chromium, EN, light, loading state, 100% text):

| Viewport | Baseline (`cover`) | Corrected (`contain`, artwork only) |
| --- | --- | --- |
| 320x700 | 288x385 cover, 89% | 288x385 contain, 100% |
| 360x740 | 328x407 cover, 83% | 328x407 contain, 100% |
| 390x844 | 358x332 cover, 62% (loading) / 86% (SSR-only) | 358x464 contain, 100% |
| 412x915 | 380x403 cover, 71% (loading) / 88% (SSR-only) | 380x503 contain, 100% |
| 430x932 | 398x420 cover, 70% (loading) | 398x513 contain, 100% |
| 768x1024 | 396x737 cover, 81% | 396x737 contain, 100% |
| 1440x900 | 638x648 cover, 68% | 638x648 contain, 100% |

The correction is one artwork-only rule, `.entity-artwork .entity-media img{object-fit:contain}`, placed after the unchanged base
rule. The image box (size, caps, min-height) is unchanged, so layout does not move; the unused part of the box shows the figure's
existing `--color-surface-soft` background. Events, exhibitions, posts, profiles, collections and markers are untouched.
The photograph, its credit, licence and source link are the same data (`seo-diff.cjs`).

## Matrix (`matrix-corrected.json`, `matrix-baseline.json`)

233 rendered measurements on the corrected build: Chromium (light + dark) and Firefox (light), viewports 320x700, 360x740, 390x844,
412x915, 430x932, 768x1024, 1440x900; EN and SL; states loading, slow (8 s), failed (bootstrap 500), SSR-only (takeover disabled),
no JavaScript, reduced motion; 150% and 200% text scaling on phones. Result: 0 errors; 0 horizontal overflow; caption and
provenance block visible in every row; the title follows the image on phones; actions inside the viewport and not overlapping
(including 150%/200%); **0 viewport/language/scheme groups whose image size or fit differs between states** (the baseline had 6);
100% of the photograph visible everywhere; max CLS 0.048 at 768x1024 (baseline 0.049; phones 0, Firefox 0). The remaining CLS
comes from the image's `width="1200" height="1000"` attribute not matching a 2:3 original (PR backend #150 emits the real ratio).

SEO invariants (`seo-diff.cjs`, baseline vs corrected renderer): after removing `<style>` blocks and bootstrap timestamps, EN and SL
documents are byte-identical, JSON-LD, canonical and og:image identical, and a missing id is a 404 in both.

Screenshots (`*.jpg`): before (`baseline-*`) and after (`corrected-*`) for loading, failed, no-JS and SSR-only at 320x700, 390x844 and
1440x900 (dark included), plus 200% text.

## Not verified

The PHP gateway output (PHP is not installed here; `php -l` not run): its CSS/SVG/markup are byte-compared to the backend, not rendered.
The deployed `dev.kubus.site` host (Basic auth), a physical phone and WebKit.
