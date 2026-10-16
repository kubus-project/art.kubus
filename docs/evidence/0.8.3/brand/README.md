# 0.8.3 family wordmark evidence

Rendered captures of the kubus family wordmark from a local Flutter web release
build of the integrated 0.8.3 candidate (merge of #298, #300, #299, #301 and this
PR at `98c42e3f`, candidate head `d36d07e3`; `main.dart.js` SHA256
`26a71114d225ee3cbf46ad7790ad1912e0a9065bd2a66d992182566a93bfe396`,
`COMMUNITY_MULTI_MEDIA_ENABLED=true`). The captures are developer fixture runs from
`scripts/qa/family_brand_visual_qa.mjs`: the API is answered locally (one artwork,
empty lists) and writes are blocked. They are not owner-supplied screenshots and
record no owner approval. The map canvas is blank because the harness serves no tiles.

Matrix: Chromium and Firefox, light and dark, English and Slovenian, 390 px and
1440 px where the surface exists on both, reduced motion. 56 of 64 first-matrix
captures succeeded; the 8 failures were the desktop settings capture looking for a
button label the unlabeled gear does not have. They are redone by position in
[settings-report.json](reports/settings-report.json) (8 of 8 captured). The
unlabeled desktop bell and gear icon buttons are a separate, pre-existing
accessibility gap.

| Surface | Capture |
| --- | --- |
| Node screen, mobile, dark, Slovenian | [node-chromium-dark-sl-390](screenshots/node-chromium-dark-sl-390.png) |
| Node screen, 1440 px, light, English (Firefox) | [node-firefox-light-en-1440](screenshots/node-firefox-light-en-1440.png) |
| Artwork detail app bar, mobile, dark, English | [artwork-chromium-dark-en-390](screenshots/artwork-chromium-dark-en-390.png) |
| Artwork detail app bar, desktop, light, Slovenian (Firefox) | [artwork-firefox-light-sl-1440](screenshots/artwork-firefox-light-sl-1440.png) |
| Desktop navigation, light, English | [shell-chromium-light-en-1440](screenshots/shell-chromium-light-en-1440.png) |
| Desktop navigation, dark, Slovenian (Firefox) | [shell-firefox-dark-sl-1440](screenshots/shell-firefox-dark-sl-1440.png) |
| Settings, light, English | [settings-chromium-light-en-1440](screenshots/settings-chromium-light-en-1440.png) |
| Settings, dark, Slovenian (Firefox) | [settings-firefox-dark-sl-1440](screenshots/settings-firefox-dark-sl-1440.png) |

## What the renders show

- Correction (0.8.3 integration): the product name is `kubus Node` with a capital N,
  as in `AGENTS.md`. The renders and report in this folder were captured while the
  copy still read `kubus node`; only the spelling changed, not the typography.
- `kubus` is weight 800 italic. `art.` and `Node` stay regular, including inside
  the bold node-screen hero line ("Poganjaj del omrežja art.**kubus** na svoji opremi").
- The accessibility tree exposes each name as one complete string (`art.kubus`,
  `kubus node`, and the full hero and group labels), not as split runs
  (see `labels` in the reports).
- The artwork title and the "by Recorded Artist" byline are untouched; only the
  app bar wordmark changed. Navigation still works with the new text.
- No horizontal overflow in any captured context.
- Headers no longer detect the brand by themselves; see `brandTitle` in
  `lib/widgets/common/kubus_screen_header.dart`.

## Not shown

- **Onboarding headings.** The branded onboarding headings sit in the structured
  onboarding steps that need an authenticated new-account state. An anonymous
  `/onboarding` opens the guest-first Map shell and `/register` carries no wordmark
  ([register capture](screenshots/register-chromium-dark-en-390.png)), so that
  surface is covered by source and widget tests, not by a render here.
- Mobile settings (reached through the Profile tab) was not captured.
- Physical devices.
