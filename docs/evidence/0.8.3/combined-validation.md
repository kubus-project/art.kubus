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

## Not a regression

`QA_FLOW=ui` fails "the search really removed the markers it claims to" (markers 0,
dots/clusters present) on the combined build and identically on the `febffbe5`
baseline build at 390 px Chromium, so it is a limitation of that check against this
fixture. The 1440 px "marker available for the layout swap" failure was not compared
against the baseline.

## Not established here

Physical Android/iOS frame rates and native compass behavior; live authenticated
Community behavior; Slovenian mobile owner routing on the final merge (the Slovenian
mobile owner screen was verified earlier against `90200b56`); audible playback.
