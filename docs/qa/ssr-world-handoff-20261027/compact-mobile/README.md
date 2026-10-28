# WORLD HANDOFF: compact mobile layout, 2026-10-28

Owner revision of PRs backend #148 / app #369: the 282 px status section pushed real artwork titles below the first
screen. Measured with the real dev web artifact, the backend renderer of backend commit `72ea267` and the real
production artwork "Mary's column" (see `../real-engine-and-performance.md` for the rig). Engine withheld so the
loading state stays on screen. Design hash on both repositories: `f8be2c08e74a07cadee1bfcf2cebb0b663961bf947f75963ff6e7267450268f4`.

## What changed

- Mobile section is one wrapping flex frame without a fixed height: the globe (3.25 rem) sits beside the head (label +
  message, message size unchanged); the head wraps **below** the globe when the root font size is scaled
  (`flex: 1 1 12rem`, rem based, so it follows text scaling); the note and the actions take full lines and the two actions stack
  when they no longer fit; the trace is the section's bottom edge.
- From 760 px the section is the previous two-column grid (265 px, was 266 px).
- Tall phones only (`max-width: 760px` and `min-height: 800px`) and only while the section is shown, the hero image cap is
  `min(55vh, max(18rem, 100svh - 32rem))` so the title's first line stays above the fold. Short phones keep the full 55vh hero.
- Markup: label and message are wrapped in `<span class="takeover-head">`; gateway (PHP) and backend render identical markup.

## Before / after at 100% text (`fold-before.json`, `fold-after.json`)

| Lang | Viewport | Section before | Section after | Title top before | Title top after | First title line visible before | after | Hero height |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| EN | 320x700 | 282 | 198 | 909 | 825 | no | no | 385 -> 385 |
| SL | 320x700 | 291 | 212 | 949 | 870 | no | no | 385 -> 385 |
| EN | 360x740 | 282 | 198 | 931 | 847 | no | no | 407 -> 407 |
| SL | 360x740 | 255 | 198 | 936 | 878 | no | no | 407 -> 407 |
| EN | 390x844 | 282 | 198 | 988 | 772 | no | **yes** | 464 -> 332 |
| SL | 390x844 | 255 | 180 | 993 | 785 | no | **yes** | 464 -> 332 |
| EN | 412x915 | 283 | 198 | 996 | 812 | no | **yes** | 503 -> 403 |
| SL | 412x915 | 256 | 180 | 1000 | 825 | no | **yes** | 503 -> 403 |

- 198 px (EN) and 180 to 212 px (SL) sit at or just under the 190 to 220 px target; SL is shorter because its message is one
  line. Heights are intrinsic, not fixed.
- At 320x700 and 360x740 the title is **not** visible and the hero is **not** cropped: the owner asked not to crop artwork merely
  to satisfy a fold metric on short phones. The section is 84 px shorter than before, so more of the real image shows.
- At 390x844 and 412x915 the hero is capped (464 -> 332 px, 503 -> 403 px) while the section is shown. That is a real crop of a portrait
  photograph (object-fit: cover), applied only to tall phones, only while the handoff section is on screen, and not to SSR-only
  or no-JS visitors (the section is hidden for them). Flagged for the owner's visual judgement (`after-en-390x844-100.jpg`).

## Text scaling (accessibility first), 320x700 and 390x844, EN and SL

At 100, 150 and 200% (`html{font-size}`): no horizontal overflow, no overlapping actions, every action inside the viewport (12/12).
At 150% and 200% the head wraps below the globe and the actions stack; sections are 500 to 570 px at 150% and 734 to 918 px at 200%
(was 1 048 px at 320x700, 200%). Screenshots: `after-en-320x700-150.jpg`, `after-sl-390x844-200.jpg`.

## Layout shift, motion, reduced motion

- Desktop layout shift: a first revision measured **CLS 0.2472 on desktop** (baseline 0.0005). Cause: the capability pre-paint rule set
  `display: flex` for the pending state and out-specified the 760 px `display: grid`, so the section flipped flex to grid when the
  script revealed it. Fixed in backend `72ea267` (the wide media query carries the same pending selector with `display: grid`; a
  test pins it). After the fix: desktop CLS 0.0005 / 0.0006 (= baseline), mobile CLS 0 (`layout-shift-after.json`, `layout-shift-baseline.json`).
- The section's top never moves (54 px mobile, 59 px desktop). Its height is constant for EN; for SL it changed between frames
  (180 -> 198 and 212 -> 232 px) during load. The baseline layout shows the same effect (282 -> 304 px), consistent with the
  Google web-font swap reflowing the message; the font workstream is separate and this was not isolated further.
- Compositor-only animation is preserved: with the loading animation running (6 animations: pose, orbit, trace) a 3 s trace shows
  0 Layout, 0 UpdateLayoutTree and 0 Paint events on mobile and desktop. With `prefers-reduced-motion: reduce`: 0 running animations.

## Not verified here

A real phone, WebKit, and the deployed `dev.kubus.site` host (Basic auth); the PHP gateway output was compared to the backend
byte for byte (CSS, SVG, markup order), not rendered in a browser; `php -l` was not run (PHP is not installed on this machine).
