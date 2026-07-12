# Slice 7 — God-file Decomposition (community + settings screens)

Date: 2026-07-12
Status: Executed under the standing UI-overhaul mandate (roadmap item 6).

## Measurement

The four largest screens were single monolithic `State` classes, not
collections of extractable widgets:

| Screen | before | State class |
|---|---|---|
| desktop_community_screen.dart | 8,040 L | 7,546 L, 144 methods |
| community_screen.dart | 6,743 L | 6,627 L, 110 methods |
| settings_screen.dart | 4,701 L | 4,628 L, 75 methods |
| desktop_settings_screen.dart | 3,732 L | 3,658 L, 58 methods |

## Design

Behavior-preserving mechanical split: non-override, non-static,
non-annotated methods move verbatim into `part` files as private
`extension _XPartN on _XState` (same library → private state access
intact). Because `State.setState` is `@protected` (not callable from
extensions), each State gains a one-line `_applyState` shim and moved
bodies call it instead. Overrides, fields, constructors, and annotated/
static members stay in the main file.

Result: main files now 855 / 584 / 297 / 278 lines, with 6 / 5 / 4 / 3
part files of ~1,200 lines each under `<name>_parts/`.

## Fallout handled

- The split exposed a ~950-line **dead comment-dialog subsystem** in
  community_screen (`openPostById` → `_showComments` →
  `_showCommentLikes`/`_resolveCommentAuthorContext` + 2 fields +
  `_CommentAuthorContext` + 2 imports): zero references anywhere,
  removed. (Public members inside a class never trigger `unused_element`;
  extensions do — a nice side effect of the split.)
- Two source-scanning guard tests
  (`test/architecture/profile_package_mutation_contract_test.dart`,
  `test/ui/upload_spinner_source_regression_test.dart`) scanned per-file;
  updated to treat a screen library (main + `<name>_parts/*`) as one unit.

## Verification

- Repo-wide analyze clean; custom_lint clean; ratchet 0 across all rules.
- Full suite +1239 ~1 -1 (identical to baseline; the one failure is the
  known pre-existing TabBar/Material assert under pinned Flutter 3.38.5).
- Visual: guest community screen (split library) renders on web —
  header/search/tabs/empty state/FAB all intact.
