# art.kubus 0.8.5 (proposed)

**Status: proposed release notes. v0.8.5 has not been released.** These notes
describe the candidate scope and must be reconciled with the final merged
release-candidate diff before publication.

## Public entry and navigation

- The app candidate updates public-entry routing and browser history behavior
  for shared links. Final browser coverage and exact-head artifact qualification
  are still pending; do not describe the candidate as fully qualified yet.
- Public-entry pages continue to use the app's public entity routes and signed
  out entry behavior. The final scope must follow the merged candidate, not the
  draft PR description alone.

## Services and administration

- Backend work under review covers the SSR language fallback and related
  server-rendered public-entry behavior. Separate backend test-only work covers
  restored-role and lock-race regressions. Neither open PR is a deployment.
- The admin candidate includes source compatibility changes. Browser acceptance
  remains pending.
- Production marker review remains owner-controlled. The current eligible
  marker set is unreviewed; no bulk approval or deindex action is part of this
  release packet.

## Release qualification

The app PR #358 candidate (`085726e76b24c1a240f37a99d469e897aba17098`) has a
full-tier CI run in progress (run `39835198150`). At the time this packet was
prepared, that run had produced no release artifact. Prior build-only output
from an earlier app SHA is not the final candidate. Android signing, iOS
signing, final web artifact checksums, end-to-end release qualification,
production deployment, and publication are not asserted here.
