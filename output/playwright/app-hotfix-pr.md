## What changed

- Make newly created street-art markers create and retain a canonical linked artwork.
- Route marker selection and “View details” through the shared artwork side panel.
- Give app-created and scripted street art the same save, like, comment, share, directions, and detail behavior.
- Require and carry photo-author and license attribution through marker creation.
- Default fresh installs to English while preserving saved locale choices and explicit Slovenian URL overrides.
- Update the backend submodule to the already merged attribution/migration hotfix from backend PR #19.

## Root cause

App-created street-art markers and scripted markers followed different data and navigation paths. The former could remain marker-only and open a reduced modal, while the latter could resolve to artwork UI but lacked complete attribution. The initial locale also still defaulted to Slovenian.

## Impact

All street-art origins now converge on the canonical artwork presentation and engagement model. Existing marker-only records are handled by backend migration `085_unify_street_art_artworks.sql`. New users start in English; returning users keep their persisted locale.

## Validation

- 25 focused Flutter tests passed, including marker creation, map controller behavior, overlay/detail routing, attribution, and locale entry behavior.
- Scoped Flutter analysis passed with no issues.
- Production Flutter web release build succeeded.
- Backend focused tests and full backend CI passed in PR #19.
- Both database schema snapshots and the editorial migration contract passed.
- Street-art data validation passed for 13,029 entries with zero errors and zero warnings.
- Responsive desktop/mobile visual validation completed; evidence files are intentionally excluded from this commit.

## Backend dependency

Backend PR #19 is merged to `master`: https://github.com/kubus-project/art.kubus-backend/pull/19
