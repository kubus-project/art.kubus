# 084-J1 Data integrity, provenance and content-freshness audit

Task: 084-J1 (Workstream J). Read-only. Date: 2026-10-18.
Sources: backend `origin/master` b2dfef5 (contains PR #84, merged via #86); app `origin/dev` 2190782e.
Method: static reading with `git show` / `git grep` only. No database, no running service, nothing reproduced here. Where a claim rests on reading rather than a run it says so ("static").
Skills used: engineering:architecture (ADR format), superpowers:systematic-debugging (trace each claim to the write site before concluding).

Severity: P1 = wrong or unstable public data today, or a decision the release needs; P2 = real defect, contained; P3 = drift or latent.
"Migration" = needs a schema or data migration. "0.9" = depends on 0.9 work (versioned public contracts, identity model).

---

## 1. Findings table

| ID | Sev | file:line | Finding | Fix | Migration | 0.9 |
|---|---|---|---|---|---|---|
| F-01 | P1 | `src/db/schema.sql:2829-2832` (artworks), `:2892-2895` (community_posts), `:2899-2902` (profiles), `:2836-2839` (collections), `:2822-2825` (art_markers), `:2920-2930` (events/exhibitions); same set in `schema_complete.sql:2887-2890, 2950-2953, 2957-2960, 2894-2897, 2880-2883, 2978-2988`; function `schema.sql:143-148`, `schema_complete.sql:148-153`. Consumers: `src/routes/seoPublicPages.js:170,177,259-260,266`, `src/services/seoPublicPagesService.js:765,1136-1140` | `update_updated_at_column()` is a `BEFORE UPDATE ... FOR EACH ROW` trigger with no `WHEN` and no column test. Any UPDATE sets `updated_at = CURRENT_TIMESTAMP`, whatever the code does. So counters bump it even where the SQL has no explicit `updated_at`: `community.js:1426` (views), `:2148,3400,3878` (shares), `:2340` (comments), `publicActionMutationService.js:307,344` (post likes). Explicit bumps on artworks: `artworks.js:1203-1205` (view), `:1424-1427,1551-1554,1681-1684` (comments), `publicActionMutationService.js:182-184,219-221,265-267` (like, unlike, discovery), `attendanceService.js:433-437` (discovery). Read paths also write: `GET /api/artworks` calls `publicSync.syncArtworkRow` per row (`artworks.js:304-308`), which can run `UPDATE artworks SET image_cid` (`publicSyncService.js:296-300`) and `persistPublicationState` (`publicPublicationService.js:353-366`), both trigger-bumped. The sitemap `<lastmod>`, the sitemap-index lastmod and the bootstrap `revision` hash (`freshnessRevision`) all read `updated_at`. Result: lastmod moves with traffic, not with edits. | ADR option (b), section 3. | y (additive) | n |
| F-02 | P1 | `src/services/publicSyncService.js:133` (COLLECTION_BASE_QUERY), `:1246` (toCollectionDoc), `src/services/publicSnapshotService.js:86` | Public collection docs emit `artistWallet` = `artworks.wallet_address`, the uploading account's wallet, labelled as the artist. These docs go to the Orbit mirror (`syncCollectionRow` -> `toCollectionDoc`, `publicSyncService.js:1644`) and to the public IPFS snapshot (`publicSnapshotService.js:145-147`). Backend API surfaces (search, collections route) already avoid it (`__tests__/artworkAuthorshipSurfaces.test.js:43`). App side, `artwork_creator_byline.dart:328-331` treats metadata `artistWallet` as an explicit artist identity and links the profile. Currently unreachable (`extractMetadata`, `backend_api_service.dart:10693-10760`, does not copy it), so the chain is latent, but the mirror carries a false role label in a permanent public dataset. | Stop emitting `artistWallet`; emit `uploaderWalletAddress` (additive) for consumers that need it. Grep kubus-node and admin for consumers first (not in this audit's sources). | n | y (snapshot/Orbit doc contract is versioned; label change must ride a version bump) |
| F-03 | P1 (decision pending) | PR #84 body "Known historical-data limitation"; `src/routes/profiles.js:1634-1637` (write fixed); candidate query in PR #84; read-side coupling `src/services/seoPublicPagesRepository.js:24-28` (`ATTRIBUTED_TO_PROFILE`) | Before PR #84, a profile save wrote the uploader's display name into `artworks.artist_name` for every artwork of that wallet. The write is fixed; the rows were not repaired (owner decision). Consequence on the read side: `ATTRIBUTED_TO_PROFILE` matches `artist_name` to the profile's `display_name`/`username`, so overwritten rows count as "authored" and feed `authored_artwork_count`, the profile index decision and the "Public artworks" fact. Public artwork pages still print the uploader as the artist for those rows. Size is unknown (no DB access here). | Owner decision on the PR #84 candidate query: (1) size it read-only; (2) produce a review list (id, title, artist_name, uploader profile, created_at); (3) NULL `artist_name` only for rows the owner confirms, in a one-off script with a dated backup, not a numbered migration. | y (data repair, not schema) | n |
| F-04 | P2 | `src/routes/profiles.js:805` (`mintedAt`), `:815-816` (`ownerAddress`, `creatorAddress`), `:831-838` (`provenance.creatorWallet`, `indexedOwner`) | Collectible index sets `mintedAt = updated_at \|\| created_at`, so a view or like moves the "mint" time (and `listedAt`). `creatorAddress` and `ownerAddress` are both the uploader wallet. The payload is honest that ownership is unverified (`currentOwnerVerified:false`, `:822-828`) but not that `creatorAddress` is the uploader, not an attested creator. | Use a stable time: `created_at` labelled `indexedAt`, or a real mint timestamp from the mint/attestation record. Rename `creatorAddress` -> `uploaderAddress` in a versioned shape. | y if a `nft_minted_at` column is added; n for the `created_at` interim | partly (creator identity) |
| F-05 | P2 | `src/services/seoPublicPagesRepository.js:271,277,303,306,308,311,321,336` | Sitemap pages are `ORDER BY updated_at DESC ... LIMIT/OFFSET` (`routes/seoPublicPages.js:253-256`, page size `SITEMAP_PAGE_SIZE`). With F-01, a view or like reorders rows between pages while a crawler walks them, so URLs can be skipped or repeated. No tiebreaker on equal timestamps. Static. | Order by the content timestamp, then `id`. | n (ordering only) | n |
| F-06 | P2 | App: `lib/widgets/common/kubus_cached_image.dart:65-68` (`versionTokenFromDate`), `withStableVersion :70-` appends `?v=<ms>`. Callers using `artwork.updatedAt`: `lib/widgets/map/panels/marker_info_detail_view.dart:253`, `lib/features/map/detail/marker_info_detail_presentation.dart:127-130`, `lib/widgets/common/kubus_marker_overlay_card.dart:240-242`, `lib/widgets/map/nearby/kubus_nearby_art_panel_items.dart:143-145,328`, `lib/screens/desktop/desktop_map_screen.dart:3431-3433,3905,4146` | The cover image URL is versioned by `Artwork.updatedAt`. Every like or view changes `updatedAt`, so the URL changes and the HTTP and image caches miss for a picture that did not change. | Version by `imageCid` when present, else by the new content timestamp once the API carries it (see ADR). | n | n |
| F-07 | P2 | `src/services/publicSnapshotService.js:121,136,145,185` against the intent at `:115-119, 195-199` | The snapshot strips `stats` and `updatedAt` so engagement does not change a dataset CID, but the datasets are still read `ORDER BY updated_at DESC`. `stableStringify` (`:402`) sorts object keys, not arrays, so a like moves one artwork to the front and the dataset hash changes anyway. Static; not reproduced (needs two snapshot runs around one like). | `ORDER BY created_at, id` (or sort by id in JS) for snapshot datasets. | n | n |
| F-08 | P2 | App: `lib/utils/artwork_authorship.dart:13`, `lib/widgets/artwork_creator_byline.dart:391-394`, `lib/utils/home_rail_creator_identity.dart:49`, `lib/utils/creator_display_format.dart:52-60`; backend `src/utils/artworkAuthorship.js:56-67` | Four app lists of "no recorded artist" and one backend list, all different. Backend: unknown, unknown artist, artist unknown, anonymous, n/a, na, not known, neznan umetnik, neznana umetnica, neznano. App authorship and byline: only `unknown`, `unknown artist`. So `artist_name = "Anonymous"` or `"N/A"` is unattributed in search, collections, SEO and sitemap but renders as "by Anonymous" in the app byline, rail and edit field. | One Dart list mirroring the backend list, used by all three authorship call sites; add a contract test that compares them to a fixture copied from `UNATTRIBUTED_ARTIST_NAMES`. | n | n |
| F-09 | P2 | `lib/widgets/artwork_creator_byline.dart:183-184` (profile name replaces a non-recorded label), `:261-267` (compact wallet becomes the label), `:282-312` (`artists`/`creators`: `map['id']`, `walletAddress`, `wallet` become `userId`), `:318-322` (`creatorWallets`), fed by `lib/services/backend_api_service.dart:10705-10709` | The byline resolves a platform profile and links to it when artwork metadata carries `artists`, `creators` or `creatorWallets`. A wallet string becomes a compact-wallet byline, and with no recorded label the resolved profile display name stands in as the artist. The authorship normalizer (`recordedArtist`) and the empty-creators branch (`:324-345`) are clean: no uploader or wallet fallback. The leak is only this metadata branch. Backend does not emit `artists`/`creators` on artwork docs today (no match in `src`), so it is latent, reachable via Orbit/legacy docs. | Treat these fields as explicit-artist-identity only when each entry has a recorded name; never show a wallet label as byline (fall back to the localized unknown label). | n | y (identity model) |
| F-10 | P2 | `lib/screens/art/ar_screen.dart:2961` (`createdBy: walletAddress ?? selectedArtwork.artist`), `lib/services/ar_integration_service.dart:167`, `lib/services/ar_marker_service.dart:102` (`createdBy ?? artwork.artist`); backend reads it as owner at `src/utils/markerOwnership.js:45-48,123-125` | Reverse inference: the artist's display name is written into the marker owner field when no wallet is available. Owner and artist are different roles; an artist string in `createdBy` is not an owner identity. | Send no `createdBy` (let the backend set the owner from the authenticated actor) instead of the artist name. | n | n |
| F-11 | P2 | `lib/screens/desktop/desktop_home_screen.dart:2663-2685` | "Creators" fallback derived from artworks keys on the uploader wallet (`art.walletAddress`), and the resolved uploader profile name wins over the recorded artist (`resolved?.displayName ?? art.artist`). Fine if the rail means "uploaders"; wrong if it means artists. | Decide the rail's meaning; if artists, key on recorded artist name only. | n | n |
| F-12 | P3 | `src/services/promotionService.js:3261,3287,3311,3346` (home_score 72h recency), `src/routes/publicMarkers.js:142,222,241` (organic candidate window by `updated_at`), `src/routes/search.js:612` (trending artists: profile updated in 7 days), `src/routes/adminModeration.js:425,605,627,873,1183,1222,1439,1573,1589,1721,1739,1898,2026,2152` (moderation queues), `src/routes/community.js:322`, `src/services/seoPublicPagesRepository.js:90` | Other consumers read `updated_at` as an activity signal. Engagement currently lifts rank and reorders queues. This is why option (a) is not a safe local change. Informational. | None now; keep `updated_at` semantics unchanged (ADR). | n | n |
| F-13 | P3 | `lib/screens/events/exhibition_detail_screen.dart:763,1568` (id as subtitle), `lib/screens/community/profile_screen.dart:901`, `lib/screens/desktop/community/desktop_profile_screen.dart:635`, `lib/screens/desktop/desktop_map_screen.dart:3395`, `lib/services/search_service.dart:174-176`, `lib/features/map/shared/map_artwork_filtering.dart:51` | Raw `artwork.artist` is rendered without `recordedArtist`, so stored placeholders print as names; exhibition tile falls back to the artwork id. | Use `recordedArtist` plus the localized unknown label. | n | n |
| F-14 | P3 | `src/db/schema.sql:1023`, `schema_complete.sql:1059` (`searchable_content` view) | View subtitle is `COALESCE(artist_name, wallet_address)`: wallet as artist. `searchable_content` has no reference in `src` (static), so dead today. | Drop the view or change the subtitle in a later migration. | y | n |
| F-15 | P3 | `src/services/publicSyncService.js:346-347` (`walletAddress`, `artistName: row.artist_name`) | The artwork doc (API detail/list and Orbit) returns raw `artist_name`, so placeholders pass through; search, collections and SEO normalize but detail does not. Uploader wallet is always present as `walletAddress` (correct role name). | Normalize at the API mapper (`artworks.js:65-69`, `mapRow`) only, never in the portable payload (digest). | n | n |
| F-16 | P3 | `src/services/seoPublicPagesRepository.js:24-31,40-41` and many `lower(a.wallet_address) = lower(p.wallet_address)` | Association is by wallet, case-folded. Solana addresses are base58 and case-sensitive; folding is a theoretical collision. Authorship counting is name equality (CI) between `artist_name` and the profile's own name, only for works that profile's wallet uploaded, so a user can self-assert any name. No cross-wallet link exists. | Document as self-asserted; revisit with an explicit artist identity (0.9). | n | y |

### Positive confirmations (no finding)

- `artworks.artist_name` is only written from an explicit `artistName` in the request (`routes/artworks.js:472-474, 787, 1777-1782, 1885, 1981`) and is never filled from uploader, profile or wallet (`utils/artworkAuthorship.js:1-12`). `PUT /api/profiles` no longer touches it (`routes/profiles.js:1634-1637`).
- SEO renderer: byline only from `recordedArtistName` (`seoPublicPagesService.js:184-185, 618-624`), "wallet-associated profile is not evidence of authorship" (`:618-619`); post byline is the stored post `author_name` (`:704`), a different role, labelled "Posted by".
- Home rail SQL keeps `creator_*` separate from `artist_name` (`promotionService.js:3234-3246`); rail subtitle excludes wallet-shaped values.
- App parse boundary: `parseArtworkFromBackendJson` takes the artist only from `artist|artistName|artist_name` (`backend_api_service.dart:10773-10783`), covered by `test/utils/artwork_authorship_contract_test.dart`.
- Publication digest strips `updatedAt` (`publicPublicationService.js:411-416`) and the artwork portable payload has no counters, so counters do not create new manifest versions. The time fallback (`:436-452`) only runs when a digest is missing.

---

## 2. Answers to the questions

### Q1. What bumps `updated_at`, and who reads it

Writers: see F-01. Rule of thumb: on artworks, community_posts, profiles, collections, art_markers, events and exhibitions the trigger makes every UPDATE a bump; explicit `updated_at = CURRENT_TIMESTAMP` in code is redundant. Counters are on artworks (`views/likes/comments/shares/discovery_count`) and community_posts (`likes/comments/shares/views_count`). Profiles have no counters (bumps come from edits, identity linking at `auth.js:1889,1899`, role approval `dao.js:427-431,466-470`, `promotionService.js:1342-1346`, avatar `profiles.js:2270`, and the display-name cascade over all of a wallet's posts, `profiles.js:1640,1654`). Collections bump when membership changes (`update_collection_artwork_count`, `schema.sql:91-99`), which is a real content change.

Sitemap: yes, lastmod is `updated_at` (else `created_at`): urlset entry via `presentation.freshnessRevision` (`seoPublicPages.js:177`, `seoPublicPagesService.js:765`), index entry as the max of the page (`seoPublicPages.js:259-260`).

Consumers of `updated_at` (file:line):

| Consumer | file:line | Effect of a counter bump |
|---|---|---|
| Sitemap lastmod, index lastmod | `seoPublicPages.js:170,177,259-266` | lastmod churn (F-01) |
| Sitemap page order | `seoPublicPagesRepository.js:271-336` | page reshuffle (F-05) |
| Bootstrap revision hash | `seoPublicPagesService.js:1136-1143` | new revision per engagement |
| Orbit mirror doc `updatedAt` + `stats` | `publicSyncService.js:404,441,480,507,574,610,1016,1063,1087,1123,1209,1255`; sync after like/unlike/discovery `publicActionMutationService.js:192-196,234-238,278-282` | doc rewrite per engagement |
| Publication source time | `publicSyncService.js:1369,1380,1392,1403,1416,1428` -> `publicPublicationService.js:497-543`, registry `source_updated_at` `publicObjectRegistryService.js:548,568,585` | recorded as `sourceUpdatedAt`; digest compare is primary so no new version |
| Publication currency fallback | `publicPublicationService.js:419-452` | only when no digest |
| Public snapshot | `publicSnapshotService.js:121,136,145,185` | ordering (F-07) |
| Home rail score and organic windows | `promotionService.js:3261-3346`, `publicMarkers.js:142,222,241` | engagement acts as recency |
| Search trending | `search.js:612` | profiles only |
| Admin queues | `adminModeration.js` (14 sites in F-12) | queue order |
| Collectibles index | `profiles.js:805` | falsified mint time (F-04) |
| App | `Artwork.updatedAt` `lib/models/artwork.dart:112,369-370`; cover cache token (F-06); `map_marker_overlay_presentation.dart:149-153` | image cache miss |
| App cache invalidation by `updatedAt` comparison | none found | n/a |

Admin console UI (separate repo) not in the sources; it consumes the admin routes above.

### Q3. Provenance: how the three roles are stored and exposed

| Role | Storage | Exposed as | Notes |
|---|---|---|---|
| Recorded cultural artist | `artworks.artist_name` (free text, nullable, no FK); markers: `marker_data.metadata.artistName` | API/Orbit `artistName` (raw, F-15); search, collections, SEO normalized via `artworkArtistNameOrNull`; admin `artist_display_name` (PR #84 I-19) | Written only from an explicit request field. Blank = NULL = unattributed. |
| Uploading account | `artworks.wallet_address` (NOT NULL), `artworks.creator_id` (user FK); `art_markers.marker_data.createdBy/ownerWalletAddress`; migration 085 uses `'system'` when a street-art marker has no owner | API/Orbit `walletAddress` (correct role name); home rail `creator_display_name/username/wallet_address`; admin `created_by_display_name`, `uploader_*`; collection docs mislabel it `artistWallet` (F-02); collectibles call it `creatorAddress` (F-04) | `creator_id` is not exposed. |
| Contributor | Access role: `collaboration_members.role` (owner, admin, editor, commenter, viewer; `collabService.js:86-93`, owner seeded at `artworks.js:2040-2046`). Credit role: photographer `image_author`, `image_license`, `image_attribution`, `image_source_url` (migration 081) | `imageAuthor/...` in artwork docs (`publicSyncService.js:350-353`) | There is no public contributor-credit field; collab roles are permissions, not credit. |

Inference paths: backend renderer and write path are clean (see confirmations). Remaining inferences are F-02, F-03 (stored data), F-04, F-14, and on the app side F-09, F-10, F-11.

App byline: `recordedArtist` (`artwork_authorship.dart:16-25`) never falls back to uploader or wallet. `ArtworkCreatorByline` with no metadata creators shows the recorded artist or the localized unknown label (`artwork_creator_byline.dart:129-141`, `:324-345`). It can show a wallet-derived or profile-derived label only through the metadata branch (F-09).

### Q4. Cross-wallet attribution

No code path links an artwork whose uploader wallet differs from a profile's wallet to that profile by name. Searches that use `LIKE`/`ILIKE` on `artist_name` (`search.js:124`, `adminModeration.js:1858,2111`) are text matching for discovery, not association. The only name-based association is `ATTRIBUTED_TO_PROFILE` (`seoPublicPagesRepository.js:24-28`), which also requires the uploader wallet to equal the profile wallet, so it is same-wallet and self-asserted (F-16). PR #84 states cross-wallet authorship is deliberately unlinked and needs an explicit artist identity; confirmed. Unverified-wallet association: collectibles `ownerAddress/creatorAddress = wallet_address` flagged unverified in payload (F-04); collection docs `artistWallet` (F-02).

---

## 3. ADR

# ADR-084-J1: Content-only freshness timestamp for public pages

**Status:** Proposed
**Date:** 2026-10-18
**Deciders:** Owner (rok@kubus.site); backend reviewer for the migration

## Context

`updated_at` on artworks and community_posts is set by an unconditional `BEFORE UPDATE` trigger. View, like, comment, share and discovery counters, publication metadata self-writes (`persistPublicationState`) and `image_cid` backfills therefore all bump it, and GET list reads can trigger the last two. Sitemap `<lastmod>` (added by PR #84, I-03), the sitemap-index lastmod, the sitemap ordering and the bootstrap revision read it, so lastmod follows traffic. A lastmod that moves without a content change is a known reason crawlers stop trusting the field. `updated_at` also feeds ranking, Orbit docs, admin queues, the collectibles `mintedAt` and the app image cache token (F-12, F-04, F-06), so changing its meaning has side effects. PR #84 left this as an owner decision.

Constraints: schema changes follow `migrations/README.md` (new idempotent migration with the next prefix, `schema.sql` and `schema_complete.sql` in the same commit, `schema:parity` and `schema:bootstrap:ci` green). Highest committed prefix on master is 106, so the next is 107, unless an open PR claims it first.

## Options considered

### (a) Stop bumping `updated_at` on counters

| Dimension | Assessment |
|---|---|
| Complexity | Medium. Removing explicit `SET updated_at` is not enough; the trigger must also skip counter-only updates (column comparison) on artworks and community_posts. |
| Blast radius | High. Changes ranking recency (`promotionService.js:3261`), map organic window (`publicMarkers.js:241`), admin queue order, Orbit `updatedAt` vs `stats` consistency, snapshot order, collectibles `mintedAt`. |
| Migration | Trigger function change only (no column), but still both snapshots plus a migration. |
| Rollback | Restore the old function; behavior returns. |

Pros: no new column. Cons: silently redefines a column six consumers read as activity; engagement can no longer lift rank unless re-added elsewhere; publication self-writes and `image_cid` backfills still need separate handling.

### (b) Additive `content_updated_at`, maintained on meaningful edits

| Dimension | Assessment |
|---|---|
| Complexity | Medium. One column, one trigger function per table, a backfill, reads switched in the SEO layer. |
| Blast radius | Low. `updated_at` unchanged, so ranking, Orbit, admin, publication keep today's behavior. Only the SEO freshness/ordering and (optionally) the app cache token move. |
| Migration | Yes, additive. |
| Rollback | Revert code first; column and trigger are harmless to leave in place. |

Pros: fixes the cause where it matters, isolates the change. Cons: a second timestamp to explain; allow-list must be maintained when public-page columns are added.

### (c) Compute lastmod from a max over content tables

| Dimension | Assessment |
|---|---|
| Complexity | High per request or a materialized view. |
| Blast radius | Low. |
| Migration | None, or a view. |

Cons: does not solve the problem. Counters live on the same row as the content, so a max over tables that include that row still moves. It helps only for relations (collection membership, markers, linked posts) and can be layered on (b) later for derived pages such as profiles.

### (d) Stopgap, not a decision: use `public_record_published_at`

Publication already has a content-identity notion (payload digest excludes counters). `artworks.public_record_published_at` and the equivalent on posts change only when the digest changes. It needs no migration, but it is the time the sync ran, not the edit time, depends on `ENABLE_CID_PUBLICATION` (default true, `publicPublicationService.js:12-13`) and on IPFS success, and is empty until first publication. Acceptable only as a temporary lastmod source if (b) cannot ship in 0.8.4. Not recommended as the end state.

## Decision (recommended): option (b), phase 1 on `artworks` and `community_posts`

Those are the only two tables with engagement counters; profiles, collections, markers, events and exhibitions have no counter writes, so their `updated_at` is already a content signal and stays the SEO source (`COALESCE(content_updated_at, updated_at, created_at)` makes the read path uniform).

Design:

1. Column: `content_updated_at timestamptz` on `artworks` and `community_posts`; `DEFAULT CURRENT_TIMESTAMP` so inserts and old code keep working.
2. Maintenance by trigger, not by editing 25 write sites: a `BEFORE UPDATE` function per table sets `NEW.content_updated_at = CURRENT_TIMESTAMP` only when a public-page column changed (`IS DISTINCT FROM` on an explicit allow-list: title, description, artist_name, image_url, image_cid transitions that change the displayed image, category, tags, location_*, is_public, is_active, is_nft and mint fields, gallery_*, media_urls, content, author_name, and so on), otherwise keeps `OLD.content_updated_at`. Allow-list, not deny-list: a forgotten new column makes lastmod stale (safe), a forgotten counter would bring the churn back (unsafe). Not on the list: all `*_count`, `public_manifest_*`, `public_record_*`, `updated_at`, and `image_cid`/`model_3d_cid`/`media_cids` going from NULL to a value (pinning, not editing).
3. Reads: `seoPublicPagesService.js:765` and `seoPublicPages.js:170` use `COALESCE(content_updated_at, updated_at, created_at)`; sitemap list queries order by that expression then `id` (fixes F-05). Snapshot datasets order by `created_at, id` (F-07).
4. API: add `contentUpdatedAt` to the artwork and post docs at the API mapper only (additive, unknown keys are ignored by the app). Do not add it to the portable/published payload: that would change every artwork's payload digest and force a re-publication of the whole catalog. If it is ever added there, exclude it from `portablePayloadDigest` next to `updatedAt` (`publicPublicationService.js:411-416`). The Orbit doc may carry it additively. App: switch `versionTokenFromDate` callers to `imageCid` or `contentUpdatedAt` once present (F-06).

### Consequences for installs and upgrades

- Fresh install: add the column, function and trigger to both `src/db/schema.sql` and `src/db/schema_complete.sql` (column last in the table to keep parity ordering simple); `schema:parity` and `schema:bootstrap:ci` compare columns, triggers and functions after applying migrations, so the migration and both snapshots must match exactly.
- Upgrade migration (107, idempotent): `ALTER TABLE ... ADD COLUMN IF NOT EXISTS content_updated_at timestamptz`; set default; backfill `content_updated_at = COALESCE(updated_at, created_at)` where NULL; create function and trigger (`CREATE OR REPLACE`, `DROP TRIGGER IF EXISTS` then create). Trap: the backfill is an UPDATE and the existing `update_*_updated_at` trigger would set `updated_at = now()` on every row, destroying the data being copied. Disable that trigger for the backfill (`ALTER TABLE ... DISABLE TRIGGER update_artworks_updated_at` ... `ENABLE`) inside the same transaction, or backfill in a way that does not fire it. The disable takes a table lock briefly; row counts are in the thousands.
- Backfill value: `updated_at` is an upper bound (it includes past counter bumps). Accept it: lastmod is frozen at a value that is no earlier than the true edit time and moves only on real edits afterward. Using `created_at` would understate edits; there is no per-row signal to do better.
- Orbit mirror: additive field only, no payload digest change, no re-publication. Existing mirrored docs keep `updatedAt`.
- Rollback: deploy code that reads `updated_at` again (the COALESCE already falls back), then optionally drop trigger and column in a follow-up. Leaving them is harmless. Old code inserting rows works because of the default.
- Cost: one extra column comparison per UPDATE on a hot path (views); negligible at current volume. Index not needed for ordering at the current row counts (thousands); add a partial index on `(content_updated_at DESC)` for public rows only if sitemap queries show up in slow-query logs.

### Trade-off

(b) costs one column and a trigger and buys isolation: nothing that reads `updated_at` today changes behavior. (a) is smaller on paper and larger in effect. (c) does not address the cause.

### Action items

1. [ ] Owner: approve (b) and the 0.8.4 vs 0.9 target. Additive and rollback-safe, so 0.8.4 is feasible if the release train accepts a migration; otherwise ship (d) as a stopgap and (b) in 0.9.
2. [ ] Backend: migration 107 + both snapshots + trigger functions + backfill with trigger disabled; jest tests for the trigger (counter update leaves it, title update bumps it, `image_cid` NULL->value leaves it) in a `*.postgres.test.js` suite; extend the sitemap test to assert lastmod does not move on a view.
3. [ ] Backend: switch SEO reads and sitemap ordering; add `contentUpdatedAt` to the API mapper; snapshot dataset order.
4. [ ] App: version cover URLs by `imageCid` / `contentUpdatedAt`.
5. [ ] After deploy: re-fetch `/sitemap.xml` twice around a view and confirm lastmod is identical.

---

## 4. Not verified here

- No production or test database was read; F-03 size, row counts, and F-07 CID instability are static conclusions.
- kubus-node, admin.kubus and the Orbit consumers of `artistWallet` were not in the sources; check them before F-02.
- The app `desktop_home_screen` rail meaning (F-11) is inferred from the code comment "derive creators from artworks".
