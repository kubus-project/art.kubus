# 0.8.2 creator capabilities: visual evidence

Two sources, both reviewed by eye.

## Widget captures (fixtures, every account stage)

`*.png` in this folder, from
`KUBUS_RUN_VISUAL_QA=1 flutter test test/qa/creator_capability_visual_matrix_test.dart`
at code commit `f04c458c` (`report-all.json`; `treeDirty` is true only
because the release notes were still uncommitted). 28 captures, 0 render
errors, Sofia Sans and Space Mono loaded.

| Prefix | State |
| --- | --- |
| `guest-*` | No session: discovery panel, home strips, account sheet (`guest-gate-studio-phone`), 320 px, 200 % text, Slovenian, dark |
| `lover-*` | Signed in, no role, wallet linked: *Apply for governance review* |
| `nowallet-*` | Signed in, no wallet: active *Create or link a wallet to apply* |
| `artist-*`, `institution-*` | Role held: workspace tools open, mobile and desktop |
| `dual-*` | Both roles: both workspaces open, both home cards *Open* |

The `Exception: Request failed: 400` line in `artist-studio-desktop.png` is
the fixture harness's unmocked portfolio request, not product behaviour.

## Browser captures (release web build)

`browser/`, produced by `browser/creator_qa.mjs` against
`flutter build web --release` served locally. Guest only: public reads went
to the live API, every write (only analytics was attempted) was answered
locally, see `browser/log.txt`.

- Cold start and refresh on `/artist-studio` and `/institution-hub`
  (390, 320, 768, 1024, 1440; light, dark, Slovenian).
- *Start as an artist* opens the account sheet; *Not now* leaves the
  visitor on the studio.
- Back from a cold-started workspace lands on Home at `/main`.
- Desktop guest sidebar: Create, Organize and Node are destinations.

## Known, not changed here

- At 320 px with 200 % text the shared dashboard header breaks
  "Institution" mid-word (`guest-hub-narrow-320-a11y200.png`): the header
  reserves 72 px for its glyph. Pre-existing component behaviour.
- The Artist Studio header lede ("Create AR markers…") is existing copy.
