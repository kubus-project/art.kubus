# Mobile anchored marker-card visual QA

Captured from the release web build on 2026-07-27 with deterministic artwork
and search fixtures.

Representative screenshots:

- [360 × 640, light, English](360x640-light-en.png)
- [412 × 915, dark, Slovenian, reduced motion](412x915-dark-sl-reduced.png)
- [844 × 390, landscape, light, English](844x390-landscape-light-en.png)

The [interaction recording](marker-selection-pan-dismiss.webm) covers marker
selection, anchored-card entry, map pan/zoom tracking, independent chrome
occlusion, dismissal/restoration, and a second-marker selection.

The complete local run additionally covered 390 × 700 (dark, English) and
390 × 844 (light, Slovenian). The automated environment received one 403 from
an external map resource; the Flutter overlay, camera composition geometry,
responsive layout, interaction, and accessibility behaviors were still
exercised.
