# Final 0.8.0 UX hardening: evidence

Screenshots from the opt-in visual matrices, rendered from fixtures with the
real screens (no network, no production data). Narrative and decisions:
[PRODUCT_V5_FINAL_UX_HARDENING.md](../../design/PRODUCT_V5_FINAL_UX_HARDENING.md).

| Surface | Files |
| --- | --- |
| Public profile (whole page) | `profile-mobile-390-*`, `profile-tablet-768-*`, `profile-desktop-1440-*`, `profile-wide-1920-*` |
| Home entity cards | `home-rail-light.png`, `home-rail-dark.png` |
| Artist Studio gallery | `studio-gallery-390-light`, `-1440-light`, `-1920-light`, `studio-gallery-empty-1440-dark` |
| Artwork editor (one chrome owner) | `studio-editor-1440-light.png` |
| DAO | `dao-desktop-1440-light.png`, `dao-mobile-390-dark.png` |
| kubus Node | `node-no-node-*`, `node-discovered-*`, `node-capability-rail-wide-dark.png` |
| Account entry | `auth-signin-*`, `auth-register-*`, `auth-forgot-*` |
| Map marker face | `marker-sheet-light.png`, `marker-sheet-dark.png` (rest, selected, cover, clusters) |

Fixture limits: `flutter test` answers network requests with 400, so artwork and
cover photographs render as the no-media role field. The marker sheet uses a
generated stand-in photograph. The post card's author avatar is outside this pass.
