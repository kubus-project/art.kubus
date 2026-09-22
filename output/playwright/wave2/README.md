# Wave 2 public entry visual evidence

These screenshots were captured from the backend's local public-only SEO preview, not from production. The preview uses demonstration records and its shared art-map social image; it verifies the SSR layout and no-JavaScript fallback, not production media fidelity.

- `wave2-artwork-en-1440-light.png`: artwork layout at 1440 × 900, light theme.
- `wave2-artwork-sl-390-dark.png`: Slovenian artwork layout at 390 × 844, dark theme, reduced motion.
- `wave2-event-en-1440-light.png`: event-specific content order at 1440 × 900, light theme.
- `wave2-profile-en-1440-light.png`: artist profile content order at 1440 × 900, light theme.
- `wave2-profile-nojs-1440-light.png`: the semantic profile page with JavaScript resources blocked.

The missing local Flutter web build means after-takeover screenshots, slow-boot timing, and Flutter bundle failure visual states could not be captured. The browser verified that the SSR remains visible when the local Flutter bootstrap asset is absent. Dart 3.12.2 formatting was run through a temporary standalone SDK. The Flutter SDK, Flutter analysis, and widget tests are unavailable locally; those gates are being checked by PR CI.
