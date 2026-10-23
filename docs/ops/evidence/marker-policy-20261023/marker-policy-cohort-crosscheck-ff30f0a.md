# Marker cohort capture cross-check

This is a read-only review of the saved capture artifacts, not a production query. It cross-checks the final candidate backend SHA `27b6c94f158b0452a56c53ea56a1cd4d58c9e034` on `codex/085-marker-legacy-visibility-20261023`.

The saved capture is from source commit `46c9b84fed42aff21463c788e5e13994689c7f73`, observed `2026-10-23 00:36:18.098224Z`, with cutoff `2026-10-22T23:31:10Z`. Its provenance says PostgreSQL 15.19, `transaction_read_only=on`, and `in_recovery=false`. The full checksums are:

- Query SHA-256: `be7bcde9bdd7f3ff9184a64f13ec52672475fc531a8c7ab20a6c40c7f4b662c9`
- Projection SHA-256: `ef1bf5142a46e095e2b49c34407cb3f5ce91f2e26974a209eb9bcbe80d4ec2ce`
- UUID/fingerprint manifest SHA-256: `b03f5aed213206c614877189f61736d1d36597ae87582a802fbde06a7652454b`

Independent checks of the saved files confirmed the query file matches its recorded SHA, the manifest has 8,955 rows and 8,955 unique UUIDs, every fingerprint is lowercase 64-hex, and recomputing the canonical `uuid:fingerprint` newline stream yields the recorded manifest SHA. The capture query builds the manifest and `eligible_by_cutoff` from the same `frozen` CTE; the capture runner checks manifest row count equals that aggregate. The saved counts are 9,050 raw active/owner-public/unreviewed rows, 8,955 eligible rows, 8,955 eligible by cutoff, and zero eligible rows after cutoff or with missing creation time. The candidate migration contains 8,955 tuple rows and validates count/checksum, current marker state/privacy/activity/coordinates, linked-artwork visibility, and material fingerprint before seeding.

The type-sensitive follow-up has its own recorded query SHA-256 `863ea93a4c05b35f934391ad92a6b9a7c4fd2efb37977dae652585dc4099ac5a` and projection SHA-256 `7e7d90dbcd70b67b68e58eb8f4c8afc143192f1621cc4eeebd5fac073b3d3197`. Its separate repeatable-read, read-only primary comparison at `2026-10-23 09:46:44.987945Z` used aggregate query SHA-256 `f29ee8cf219661e8d022df6acd5c9eace40f7f759fdcdc1c152f77f7b19b331f`, the same source commit and cutoff, and found 8,955 eligible by cutoff with zero changed fingerprints. The migration header records this compatibility lineage. Independently, the material projection, fingerprint, and three revocation function blocks are byte-identical across migration 113, `schema.sql`, and `schema_complete.sql` after newline normalization.

The earlier aggregate-only reconciliation at `2026-10-22T23:31:10Z` found 9,050 raw rows and 8,955 under the existing public map/API rule; its sanitized breakdown attributes the 95-row difference to linked artwork failing public/active visibility. All 8,955 eligible rows were linked to public, active, non-collectible artwork and remained unreviewed. The capture query further requires marker editorial state `unreviewed`, marker active/public flags, coordinates, and linked artwork public/active and not rejected/archived. The frozen manifest is a fixed UUID/hash list, so post-cutoff IDs are not added by runtime data or caller flags.

The 9,046 readiness value cannot be compared row-by-row: its saved proof has no reproducible result or timestamp, and the readiness query artifact does not apply the current linked-artwork/coordinate rule. A separate historical audit used 9,046 for the `artwork_not_ar` subset, not the total eligible set. Therefore this review makes no claim that a 91-row change from 9,046 to 8,955 is an intentional row-level delta. The defensible count from the saved current-rule evidence is 8,955.

## Final candidate review boundary

On exact SHA `27b6c94f158b0452a56c53ea56a1cd4d58c9e034`, the focused PostgreSQL suite passed independently 12/12 using task-local loopback PostgreSQL 60245 and a reviewer-owned temporary database that the test dropped. Schema parity independently reported zero table drift and passed migration filename policy. The type-sensitive tests cover malformed numeric counter values and timestamps, valid numeric engagement no-op cases, and retention of unknown public stats keys.

The evidence supports candidate-only integration of the reviewed source policy. It does not authorize production migration or publish. Current DNSLink snapshots can remain stale until explicit republish, and historic immutable CIDs remain fetchable; that is a separate release gate. This memo does not claim whole-release clearance or a row-wise 9,046-to-8,955 delta.
