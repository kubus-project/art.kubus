## What changed

- Store photo author and license metadata consistently when artworks are created.
- Preserve attribution through public-sync mapping and scripted street-art seeding.
- Add migration `085_unify_street_art_artworks.sql` to materialize canonical artwork rows for legacy marker-only street art.
- Cover artwork creation, public-sync attribution, and seed attribution with focused tests.

## Why

Street-art markers created through the app and markers created by scripts did not share one canonical artwork/attribution contract. That caused app-created markers to open a reduced marker modal without engagement actions, while scripted markers could open richer artwork UI but lacked license and photo-author metadata.

## Impact

The frontend can resolve every street-art marker to the same artwork detail flow, including likes, saves, comments, sharing, and the side panel. Existing marker-only data is backfilled by the migration.

## Validation

- Focused backend Jest suites passed.
- Both checked-in schema snapshots are in sync.
- Street-art dataset validation passed for 13,029 entries with zero errors and zero warnings.
- Changed backend files passed syntax/lint checks.
