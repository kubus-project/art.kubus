# Marker policy review: 1fac612

Reviewed exact pushed SHA `1fac612a6334bd48e90ad0d5bf63c6998990239a` on `codex/085-marker-legacy-visibility-20261023`, read-only.

## Finding: do not clear this SHA yet

`migrations/113_marker_legacy_visibility_cohort.sql:66-72` removes the entire `stats` object from marker data before fingerprinting; lines 91-95 do the same for AR config. Current public mapper output retains raw `markerData` and `config` (`src/services/publicSyncService.js:557,1085,1107`). No schema/validator constrains nested `stats` to engagement counters; a changed unknown public property under either object can alter a public DTO without revoking the legacy grant. This conflicts with the agreed requirement to fingerprint all emitted public keys except specifically identified counters/sync/timestamps. Backend author acknowledged and is preparing a follow-up that excludes only enumerated counter members and adds a regression assertion. Review the next immutable SHA before clearance.

## Checks on 1fac612

- Parent `220ca1d1a4ab8352587cafc25ea7059fa62829e7`; exact HEAD and clean at start of review.
- Independently parsed the SQL manifests: 8,955 rows in both versions, 0 UUIDs added/removed; sorted UUID-set SHA-256 `d0cbc84ec259c1ae7a75d186e61ad0000d275a4ad7e1a6260c7ffca791a2703e`. All fingerprints changed because the linked artwork model/NFT fields were added; this closes the earlier known omission.
- `npm run schema:parity`: pass, zero table drift; `git diff --check`: pass.
- Author reports focused PostgreSQL tests 11/11, schema parity, clean schema bootstraps (103 migrations/144 tables), and changed-file ESLint pass. I could not rerun PostgreSQL or ESLint locally because database test URLs and `@eslint/js` are unavailable in this environment.
- The test/schema follow-up covers newly created unreviewed markers, linked artwork material and AR changes, monotonic revocation on reject/archive/hide/revert, and cache/Orbit/registry/CID-version/exhibition/SEO/fresh-snapshot reads.

## Separate operational boundary

`docs/EDITORIAL_REVIEW_STATE.md:61-67` explicitly states the current DNSLink snapshot can remain stale until explicit republish and old IPFS CIDs remain fetchable. This is not resolved by current API read-time filtering; treat snapshot freshness and historic-copy retention as a separate owner/release gate, not a clean source-review claim.
