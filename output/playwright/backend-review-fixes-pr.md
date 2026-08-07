## What changed

This follow-up addresses every actionable review thread from merged backend PR #19:

- resolve migrated creator UUIDs through `users` so deleted-account markers cannot violate the artwork foreign key;
- preserve existing marker tags while guaranteeing the canonical `street art` tag;
- restrict inferred placeholder author/license values to artworks linked to street/public-art markers;
- update supplied attribution, or clear stale attribution, when an artwork cover is genuinely replaced;
- use the same `imageSourceUrl || sourceUrl` rule for seed inserts and idempotent updates.

The clean-schema bootstrap now seeds migration fixtures and verifies these migration behaviors against both schema snapshots.

## Validation

- 16 focused route, seed, create, and public-sync tests passed.
- Changed-file ESLint passed with zero warnings.
- Schema snapshot parity passed with zero table drift.
- `git diff --check` passed.

Full-repository lint continues to report ten pre-existing errors in untouched files; this PR does not modify or bypass them. The affected-surface CI lint job remains authoritative.

## Review source

Addresses all unresolved inline threads on https://github.com/kubus-project/art.kubus-backend/pull/19
