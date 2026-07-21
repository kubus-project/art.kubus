# Authenticated profile visual QA

Deterministic screenshot matrices for the profile surfaces and the Home
discovery rails. Both suites render the **real** screens/widgets — not mocks,
not loading skeletons — and write inspectable PNGs plus a machine-readable
`report.json`.

```powershell
puro flutter test test/qa/profile_visual_matrix_test.dart   # -> output/qa/profile-visual-matrix/
puro flutter test test/qa/home_rail_visual_matrix_test.dart # -> output/qa/home-rails/
```

Both suites wipe and rewrite their output directory on every run, so a partial
(`--plain-name`) run produces a partial matrix. Always run them unfiltered when
producing evidence for review.

## Why this is not an authentication bypass

Authenticated state is reached exclusively through APIs that already exist for
production use:

| Surface | Seam |
| --- | --- |
| mobile/desktop public profile, community overlay | `UserProfileScreen(initialCriticalPackage:, initialExtendedPackageFuture:)` |
| mobile/desktop owner profile | `ProfileProvider.setCurrentUser(...)` |

No authentication check is disabled, no debug flag is introduced, and nothing in
`lib/` is aware that a QA run is happening. Every fixture lives in
`test/support/profile_fixtures.dart`.

## Determinism

* Frozen `fetchedAt` timestamp — no wall-clock text.
* No randomness and no network dependency for the rendered content.
* `report.json` records the commit SHA, the branch, whether the working tree was
  dirty, the Flutter root and the font families that were registered, so a stale
  capture set cannot be mistaken for a fresh one.
* `pumpProfileSurface` fails the test on any render error other than the
  documented pre-existing ones listed in `test/support/profile_screen_harness.dart`.

## Fonts

`flutter test` ships no real text font, and `google_fonts` cannot fetch Inter
from a test process. `test/support/qa_font_loader.dart` registers the pinned
Flutter SDK's Roboto faces under every family name `google_fonts` requests
(`Inter_regular`, `Inter_600`, …) plus `MaterialIcons` and the checked-in
Material Symbols subset.

Consequence: glyph shapes and metrics are Roboto rather than shipped Inter.
Layout structure, wrapping, badge placement, clipping and overflow are faithful;
letter-level kerning is not. Colour, spacing and geometry are unaffected.
