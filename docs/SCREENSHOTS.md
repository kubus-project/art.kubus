# Screenshots

README and documentation images live in `docs/screenshots/`. They show the real application, never mockups or generated images.

## Current images

| File | Shows | Source |
| --- | --- | --- |
| `map.png` | Desktop web map, dark theme, guest session, artwork card opened from the nearby list | `scripts/qa/readme_screenshots_capture.mjs`, scenario `map-card-desktop-dark`, downscaled to 1920x1200 |
| `map_mobile.png` | Mobile web map (390x844 at 2x), dark theme, artwork card opened from the nearby sheet | same script, scenario `map-card-mobile-dark` |
| `home.png` | Desktop home, light theme, guest session | `scripts/qa/product_v5_wave4_capture.mjs` (Product v5 Wave 4 evidence) |
| `../branding/social-preview.png` | 1280x640 GitHub social preview composed from `map.png` | composed by hand from the capture above |

The map captures use real public content from `api.kubus.site`. The capture script only lets read-only `GET` requests through; every write and analytics call is stubbed. The browser geolocation is set to central Ljubljana so the nearby list is deterministic. Only artworks whose photo licence is stated in the card (CC BY 3.0 and CC BY 2.0) were chosen for published images.

Signed-in surfaces such as Artist Studio, Institution Hub and profiles are covered by the Flutter visual QA matrices under `test/qa/`, which render the real widgets with local fixtures. Their output is under `docs/evidence/`.

## Recapturing

```bash
flutter build web --release
npm --prefix scripts/qa ci
node scripts/qa/readme_screenshots_capture.mjs            # all scenarios
QA_SCENARIOS=map-card node scripts/qa/readme_screenshots_capture.mjs
```

Output goes to `output/playwright/artifacts/readme/`, which is ignored by Git. Review every image before copying it into `docs/screenshots/`. Check that no private data, loading state or unlicensed photo is visible. `QA_DUMP_LABELS=1` prints the semantics labels and positions, which helps when a click target changes.
