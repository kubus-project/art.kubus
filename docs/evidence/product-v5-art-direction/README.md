# Wave 5A-R art-direction evidence

Each `*.jpg` is BEFORE | MASTER | AFTER at identical size from the same
local fixtures (no network), rendered with real Sofia Sans and Space Mono.

| Column | Source |
| --- | --- |
| BEFORE | `dev@1be4de61` plus only the desktop-home build-phase fix (dev's desktop Home threw in debug and rendered an error panel) |
| MASTER | `master@ee5554f0`, visual reference only (`20cda54f` is contained in it) |
| AFTER | this branch, `a5acdb25` |

Flutter matrix: `test/qa/product_v5_art_direction_visual_matrix_test.dart`
(`KUBUS_RUN_VISUAL_QA=1 QA_LABEL=after`); 27 scenes, 0 render errors on
AFTER. The master desktop Home cell shows Flutter's error panel: master has
the same build-phase error this PR fixes, so master's phone Home is the
reference for that surface. Master's profile stat tiles overflow by 28 px
(53 px at 200 %); AFTER has none.

Coverage: Home 390/1440/320 light+dark (+artist persona), profile
artist/institution/account at 390/1440/320 light+dark, EN+SL, 200 % text at
1280; settings desktop+phone; artwork editor, Artist Studio, Institution
Hub; wallet 390/1440/320 light+dark, SL; achievements, DAO intro,
marketplace.

`browser-*.jpg` come from `scripts/qa/product_v5_art_direction_browser_qa.mjs`
against `flutter build web --release` in offline Chromium (no request
leaves the machine):

- `browser-zoom200-home`: 200 % page zoom of a 1440x900 window (720x450
  CSS px at DPR 2), which is the phone layout.
- `browser-hover-desktop-home-dark`: pointer at rest, 60 ms and settled on
  the Explore Map tile: 2 px lift, accent edge and shadow.
- `browser-hover-reduced-motion-desktop-home-dark`: same with
  `prefers-reduced-motion: reduce`: edge and shadow change, no movement.
- `browser-home-desktop-dark-light-sl`, `browser-home-mobile`: guest Home
  in a real browser, dark/light, EN/SL, 390 and 320.

## Review fixes (Codex P1/P2)

Single-state captures from the same matrix (`QA_LABEL=review-fix`), 0 render
errors:

- `review-fix-home-quick-actions`: returning-user desktop Home, recorded
  quick actions in the horizontal strip, dark EN, light EN, dark SL at 200 %
  text. The scenes are `home-desktop-quickactions-*`; earlier matrix runs
  never populated this strip.
- `review-fix-action-tile-long-title`: inline tiles in a horizontal scroll
  row with a 60-character title, dark/light at 1x and 2x text. The title
  wraps inside `KubusActionTile.inlineMaxWidth` (280, scaled with the text);
  before the fix it ran on one line to a 1021 px tile.
- `review-fix-owner-cover-resolved-role`: image-less mobile owner cover when
  the role comes from an approved DAO review while `currentUser` still says
  neither (artist dark, institution dark, plain account SL, artist light,
  institution light). The cover matches the role badge.
