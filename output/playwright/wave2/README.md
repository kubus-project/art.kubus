# Wave 2 public entry visual evidence

These screenshots were captured from the backend's local public-only SEO preview, not from production. The preview uses demonstration records and its shared art-map social image; it verifies the SSR layout and no-JavaScript fallback, not production media fidelity.

- `wave2-artwork-en-1440-light.png`: artwork layout at 1440 × 900, light theme.
- `wave2-artwork-sl-390-dark.png`: Slovenian artwork layout at 390 × 844, dark theme, reduced motion.
- `wave2-event-en-1440-light.png`: event-specific content order at 1440 × 900, light theme.
- `wave2-profile-en-1440-light.png`: artist profile content order at 1440 × 900, light theme.
- `wave2-profile-nojs-1440-light.png`: the semantic profile page with JavaScript resources blocked.
- `wave2-artwork-en-1440-after-takeover.png`: local Chrome capture after the CI-built Flutter artifact took over the artwork fixture route (artifact built from the same functional source before formatting-only commits).
- `wave2-artwork-en-390-after-takeover.png`: the same takeover at a 390 px viewport.

The SSR screenshots use public-only demonstration records and a shared map preview image, not production media. The after-takeover captures use a CI-built Flutter artifact from the same functional source before formatting-only commits and the preview's demonstration artwork. They show the matching title and artist in Flutter, but a material transition difference remains: Flutter presents a map/comments/sidebar composition while SSR presents a media-first detail page. At 390 px the Flutter frame clips the artwork graphic and description horizontally. This is an observed parity gap; these captures do not pass the requested visual-negligibility or mobile-overflow criteria.

The local Playwright bridge could not load JavaScript assets from its local preview tunnel, so the after-takeover captures were made with headless Chrome against that CI-built artifact. The browser verified SSR remains visible when the local Flutter bootstrap asset is absent. Dart 3.12.2 formatting was run through a temporary standalone SDK using the package's Dart 3.6 language version. The Flutter SDK, Flutter analysis, and widget tests are unavailable locally; those gates are being checked by PR CI. Firefox, 200% zoom, and keyboard/focus acceptance remain unverified.
