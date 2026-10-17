# 0.8.3 combined validation

A disposable local branch (`chore/083-combined-disposable`, never pushed, not a release
branch) merged the four 0.8.3 PRs onto fetched `dev` `332e13a9` in this order, each
`--no-ff` with no conflicts: map `79afd280` (#298), globe `18a52e55` (#300), profile
`7d62ecd9` (#299), community `222c136b` (#301). The merge head is `c368a12d`; the
later heads of #298 and #299 add documentation only. The four copies of the shared QA
scripts (`product_motion_acceptance.mjs`, `product_motion_sampling.mjs`,
`product_v5_spatial_browser_qa.mjs`) are byte-identical across the branches and
merged cleanly.

## Gates run on `c368a12d`

| Gate | Result |
| --- | --- |
| `flutter analyze` (whole repo) | No issues |
| `flutter test` (whole repo) | 5125 passed, 27 skipped, 0 failed |
| `git diff --check` against `dev` | One trailing blank line in the identity README, since fixed on #299 |
| Release web build, `COMMUNITY_MULTI_MEDIA_ENABLED=true`, `main.dart.js` SHA256 `8dbaf1e2...f39d` | Built |
| Globe/location presentation matrix (`QA_FLOW=presentation`): Chromium and Firefox x light/dark x EN/SL x reduced/normal motion | 16 contexts, 760 checks, 0 failed |
| Map main flow (`QA_FLOW=main`, 300-marker fixture), selection survives zoom, topology change and theme switch on phone and desktop | 10 runs, 192 checks, 0 failed |
| Owner opened from a Community post (`corrective_visual_qa.mjs`, `QA_EXPECT_OWNER=true`), 390 and 1440, Chromium and Firefox, dark, EN | Opens the owner profile with Edit profile in all four contexts |
| Same flow, Slovenian UI | 1440: passed in both browsers. 390: not established, the harness lands on the map onboarding overlay instead of Community (a harness entry-state problem, no routing result) |
| Visitor opened from a Community post | Visitor profile in all four contexts |

The earlier 840-check globe/location packet in `presentation/` remains the record for
the seven-width responsive matrix against `90200b56`; this run re-checked the final
merged source with the presentation flow only (760 checks) and does not replace it.

## Corrections after the first combined run

Two statements in the first run were wrong or incomplete and are corrected here.

- **Map search was a product defect, not a harness limit.** `QA_FLOW=ui` failed "the
  search really removed the markers it claims to" at both 390 and 1440 px in both
  browsers (23 and 59 overview bubbles stayed on a map whose constraint strip said
  the search had restricted it), identically on the `febffbe5` baseline. Below zoom 8
  the map draws the server overview, which cannot express a text query. Only a marker
  reload decides to drop it, and typing never triggered one. Both map screens now
  reload when the query crosses empty and non-empty (this PR, `c3a93c7a`). After the
  fix the check passes in Chromium and Firefox at both widths (0 dots after the
  search, 23 and 59 restored by Reset all). It was present before 0.8.3 and is not a
  0.8.3 regression.
- **The 1440 px "marker available for the layout swap" failure was a harness defect.**
  The step dismissed the results dropdown by tapping a fixed point. At street zoom a
  marker sits under that point and opens its detail page, so the map was not on
  screen when the check looked for a marker. The `febffbe5` baseline fails identically.
  The step now taps a marker-free point and the check runs end to end.
- **Slovenian 390 px owner routing** (resolved on #301, `cdee7298`): the harness entered
  `/sl/community`, which the app does not serve (only bare shell routes are wrapped
  by `AppInitializer`; a language prefix exists for public entity pages), so it opened
  the Map and its first-run coach card. Slovenian shell entries now select the
  language with `lang` alone. Result below.

## Final candidate `d36d07e3` (2026-10-16)

The integration candidate is dev `332e13a9` plus #298 `c3a93c7a`, #300 `18a52e55`,
#299 `500d3185`, #301 `cdee7298` and #291 `98c42e3f`, merged `--no-ff` in that order
with no textual conflicts (local branch `chore/083-release-candidate`, never pushed).
The later #291 head `2199de0e` only adds wordmark evidence.

| Gate | Result |
| --- | --- |
| `flutter analyze` (whole repo), `dart format` on changed files, `git diff --check` | No issues |
| Generated localization against ARB source | In sync (only the hand-kept locale guard differs from a fresh `gen-l10n`) |
| `flutter test` (whole repo) at `d36d07e3` | 5129 passed, 27 skipped, 0 failed (baseline 5125) |
| Release web build, `COMMUNITY_MULTI_MEDIA_ENABLED=true` | `main.dart.js` SHA256 `26a71114d225ee3cbf46ad7790ad1912e0a9065bd2a66d992182566a93bfe396` |
| Release web build, flag at its release default (off) | `main.dart.js` SHA256 `b22bdcd9176c7f406fb202096e629c238c98b7ad4986012c026ebbb62b5f428d` |
| Mixed image and video post, flag on and off, Chromium and Firefox, 320/390/1440 px | On: "Media 1 of 2" with a "1 / 2" counter in 6 of 6; off: "Media 1 of 1" in 6 of 6 |
| Owner opened from a Community post, EN and SL, Chromium and Firefox, 390 and 1440 px, dark | 8 of 8 reach the owner profile with Edit profile / Uredi profil and no Follow, Sledi, Message or Sporoči action |
| PRODUCT motion gate (`product_motion_acceptance.mjs`), Chromium and Firefox, normal and reduced motion, plus its 10 sampling unit tests | 9 of 9 cases in each of the 4 configurations; 10 of 10 unit tests |
| Globe/location presentation matrix (`QA_FLOW=presentation`), 16 contexts | 758 of 760 checks on the first run; the one context with 2 failures (chromium, dark, EN, normal motion) passed on 3 of 3 reruns and on the earlier combined build, so it is recorded as a flake |
| Map `ui` flow, Chromium and Firefox, 390 and 1440 px | Search and layout-swap checks pass. One uncaught `Orbit fallback failed` page error at 1440 Chromium, see below |
| Wordmark captures (#291), 2 browsers x 2 themes x 2 languages x 4 to 5 surfaces | 56 of 64 first-matrix captures plus 8 of 8 settings captures; renders in `brand/` |

### Map main flow (`QA_FLOW=main`): not re-established today

Re-run on the final candidate, the main flow fails two checks in both browsers:
"the selected badge is actually drawn at far zoom (pixels)" and "all kubus layers are
re-installed after the theme switch". These are not caused by this work: the
byte-identical earlier combined build (`8dbaf1e2...f39d`, which passed 192 checks at
12:45Z) fails the same checks at 16:40Z, and so does the untouched `febffbe5` baseline.
The selection checks themselves (tapping selects, the marker stays individual at every
zoom, the badge stays pinned) pass on the candidate. The pixel check passes with the
page clock started at 12:45Z and fails at 16:40Z on the same build, so it depends on
the time of day (the night field shades the clip). The theme-switch check fails on all
three builds at the same time today; its cause was not isolated (the harness lets
public reads reach live services, which were returning 403 and 404 for some
requests). **The 192-check result stands for the unchanged map code, and no fresh
pass is claimed.** The only map code that differs from that run is the search reload
in the two map screens. A clock-pinned, fully offline main flow would settle this and
is a follow-up for the harness.

### Pre-existing page error

The map `ui` flow at 1440 px in Chromium records one uncaught
`Orbit fallback failed: <status>` page error from `BackendApiService`, raised when a
live public read returns a non-2xx status. It is identical on the `febffbe5` baseline
and is not changed here.

## Not established here

Physical Android/iOS frame rates and native compass behavior; live authenticated
Community behavior against a compatible staging backend (no authorised disposable
account was available); audible playback; the onboarding heading wordmark as a render
(it needs an authenticated new-account state); a fresh controlled performance
benchmark on the final candidate (the changes since the earlier measurements do not
touch frame-time code).
