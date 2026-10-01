# Wave 2B visual acceptance evidence

> **Superseded for current acceptance review.** This 56-case capture predates the PRODUCT v5 token foundation. Keep it as historical evidence only. Use the refreshed Chromium/Firefox capture in [`wave2b-v5-c23c776b`](../wave2b-v5-c23c776b/README.md).

Captured 2026-09-23 from the local public renderer and the exact app web artifact built by CI for app source `5f8f03df1529b3008574877aaf21b5e2f2781d52`. The backend preview used the focused SSR zoom reflow change at `ea0782c0552601d8b01f4d7a138e298eaf6387e3`.

These are synthetic, public-only preview fixtures. They contain no production entity IDs or production record content. The screenshots demonstrate layout and handoff behavior; they do not establish production data behavior. The fixture image is the local public preview asset.

## Matrix

`visual-matrix.json` records 56 cases: 28 each in Chromium and Firefox. It includes:

- Artwork in EN and SL at 390 × 844 and 1440 × 900, light and dark, SSR with JavaScript disabled, loading before takeover, and exact Flutter takeover.
- Artist profile, institution profile, event, and exhibition at 1440 × 900 in light theme, before and after takeover.
- Long EN and SL titles, attribution, and descriptions at 320, 360, 390, and 430 CSS pixels.
- A 2.4 second delayed Flutter bundle, an aborted Flutter bundle, reduced-motion preference, and keyboard navigation/focus checks.
- A 200% effective-width model using a 195 CSS-pixel viewport with DPR 2. This checks the 390-pixel layout at half its available CSS width; it is not a browser chrome zoom control.

The matrix was captured from the exact CI web artifact for the app SHA above. Screenshots use the matching names in this directory, suffixed with `chromium` or `firefox`.

## Artwork observations

| Check | Result | Evidence |
| --- | --- | --- |
| Media remains the dominant anchor | Pass | On mobile, SSR and Flutter use the same 358 × 465 media frame at x=16. The first media pixels begin at y=70 in SSR and y=68 in Flutter. Desktop remains media-dominant. |
| Title hierarchy and location | Mobile pass; desktop partial | Mobile title starts at nearly the same point after the media. On desktop the title stays beside the media but is visibly smaller than SSR and shifted with the app content area. |
| Cultural artist attribution | Pass | Both frames name Maja Novak as artist; Flutter uses the compact “by Maja Novak” byline. The associated account is not substituted for the artwork artist. |
| Horizontal datum | Mobile pass; desktop gap remains | At 1440, SSR media begins at x=136, y=99 and is 638 × 648. Flutter media begins at x=244, y=84 and is 688 × 680. The 108-pixel x shift comes from the persistent desktop navigation rail and the resulting narrower content area. This pass did not alter global navigation or add app-shell chrome to SSR. |
| Unintended mobile horizontal overflow | Pass | Browser measurements at 320, 360, 390, and 430 show the document and body fit each viewport in both browsers. The Flutter view begins at x=0 and ends at the viewport width. No overflow offenders were reported. |
| SSR to Flutter continuity | Mobile pass; desktop remains a blocker | Mobile keeps the image, title, and artist in the same opening order and nearly the same position. Desktop retains an obvious shell-rail shift and title-scale change, so the transition is not yet visually negligible there. |

The exact 390-pixel route uses the compact `ArtDetailScreen`; `DesktopArtworkDetailScreen` starts at the existing 900-pixel breakpoint. The artwork route widget test covers 390, 899, 900, and 901 pixels.

### Responsive defect fixed

The compact artwork description used a start-aligned `Column`, allowing its reading surface to keep an intrinsic width narrower than the available detail column and clip long text at the right edge. Setting that column to `CrossAxisAlignment.stretch` makes the reading surface use the available width. The regression test in `test/widgets/detail/public_artwork_description_layout_test.dart` checks the 320-pixel layout.

The first 5f8 stress run also sampled Flutter immediately after a resize and observed a stale 320-pixel renderer bound at the next 360-pixel step. The harness now waits for the Flutter view bounds to match each expected width before measuring. A separate direct 360-pixel load also measured a 360-pixel Flutter view. This was a test timing race, not a page overflow defect.

The earlier 200% effective-width check exposed `min-width: 18rem` in the existing SSR CSS. Backend PR #65 removes that floor; Chromium and Firefox now report 195-pixel document, body, and Flutter widths with no overflow offenders.

## Other entity review

These checks are representative classifications, not redesigns of every entity type:

- Artist profile: **blocking parity issue**. SSR is a compact identity-and-work page; Flutter switches to a cover, large profile surface, stats, and action layout.
- Institution profile: **blocking parity issue**. It inherits the same broad profile presentation mismatch.
- Event: **blocking parity issue**. SSR prioritizes event identity, date, place, and media; Flutter shows the map-led event surface and shell chrome.
- Exhibition: captured in the matrix; deeper parity work remains outside this artwork-focused pass.

Closing those differences needs entity-specific screen work beyond the narrow artwork detail pass. The Wave 2B PR remains draft; this evidence does not mark the broader public-entry acceptance complete.

## Accessibility and takeover

- SSR links receive keyboard focus and remain usable during slow Flutter loading and when the Flutter bundle is blocked.
- On exact takeover, SSR becomes both `inert` and hidden from the accessibility tree. The Flutter accessibility entry and a semantic entity action can be reached by keyboard with a visible focus outline.
- Reduced-motion preference is enabled in the matrix. Flutter takeover preserves the canonical pathname and keeps the SSR content visible until exact readiness.
- The effective-width zoom model is described above; no separate browser UI zoom control was used.

## Screenshot guide

- `artwork-en-390-light-ssr-*` / `artwork-en-390-light-flutter-*`: paired compact opening frame.
- `artwork-sl-390-*`: Slovenian route and dark-mode cases.
- `artwork-en-1440-light-*`: desktop composition before and after takeover.
- `artwork-*-long-text-{320,360,390,430}-flutter-*`: compact-width regression evidence.
- `artwork-en-390-light-flutter-keyboard-focused-*`: keyboard focus after takeover.
- `artwork-en-390-200-percent-zoom-effective-*`: narrow effective-width evidence.
- `artwork-*-slow-loading-*` and `artwork-en-1440-bundle-failure-ssr-*`: delayed/failed Flutter behavior.
- `artist-profile-*`, `institution-profile-*`, `event-*`, and `exhibition-*`: reduced representative category review.

## Scope record

The app changes use existing Kubus `Theme.colorScheme`, typography, `DetailSpacing`, and detail-surface tokens. No global token migration was made. This pass did not change indexing, canonical ownership, Android App Links, map behavior, database content, deployment, or merge state.

The Wave 1 audit handoff remains unchanged: all 9,049 public marker/artwork pairs were independently index-eligible in the measured audit. Canonical/index ownership work is explicitly deferred to its later policy package.
