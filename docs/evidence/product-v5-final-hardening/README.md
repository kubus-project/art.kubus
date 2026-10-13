# Final 0.8.0 UX hardening: evidence

Screenshots from the opt-in visual matrices, rendered from fixtures with the
real screens (no network, no production data). These are historical captures;
they do not establish current visual or runtime acceptance. The former narrative
is available at [its immutable source revision](https://github.com/kubus-project/art.kubus/blob/307b165ec57e9b4cf8d8a012bd93f62ce0906c6a/docs/design/PRODUCT_V5_FINAL_UX_HARDENING.md).

| Surface | Files |
| --- | --- |
| Public profile (whole page) | `profile-mobile-390-*`, `profile-tablet-768-*`, `profile-desktop-1440-*`, `profile-wide-1920-*` |
| Home entity cards | `home-rail-light.png`, `home-rail-dark.png` |
| Artist Studio gallery | `studio-gallery-390-light`, `-1440-light`, `-1920-light`, `studio-gallery-empty-1440-dark` |
| Artwork editor (one chrome owner) | `studio-editor-1440-light.png` |
| DAO | `dao-desktop-1440-light.png`, `dao-mobile-390-dark.png` |
| kubus Node | `node-no-node-*`, `node-discovered-*`, `node-capability-rail-wide-dark.png` |
| Account entry | `auth-signin-*`, `auth-register-*`, `auth-forgot-*` |
| 200 % text scale (Node, auth) | `a11y200-*` |
| Map marker face | `marker-sheet-light.png`, `marker-sheet-dark.png` (rest, selected, cover, clusters) |

Fixture limits: `flutter test` answers network requests with 400, so artwork and
cover photographs render as the no-media role field. The marker sheet uses a
generated stand-in photograph.
