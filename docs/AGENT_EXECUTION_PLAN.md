# Bounded implementation packages

Status: documentation only, 2026-09-22. The one master dependency sequence is `PRODUCT_UX_SEO_PROGRAM.md`. Read it, `CLAUDE.md`, root/nested `AGENTS.md`, and the named domain contract before accepting a package. Re-fetch and report branch/SHA drift. Create a topic branch from each repo's current integration base; never commit to `dev`/`master`, merge, deploy or change production data without the appropriate later authorization. A package is complete only with its stated tests and evidence.

## Shared ownership rules

One owner at a time for `lib/utils/design_tokens.dart`, app routing/deep-link parser, `KubusMapController`, `MapLayersManager`, `AndroidManifest.xml` and backend SEO presentation. Assign an explicit file owner before parallel implementation. Preserve current MapLibre, marker semantics, public/private boundaries, EN/SL and website family v5. Do not use old public-site `master` visuals. Record the actual base SHA, test output, screenshots, failures and changed data contract in each PR. An uncertain schema field, association fingerprint, private/public boundary or platform capability is a stop condition, not permission to guess.

### Measurement shared across packages

Track indexed → visible → clicked → useful PRODUCT interaction. The event dictionary must distinguish search impression/click, entity useful engagement, related navigation, map/artwork open, route start/completion, save, follow, claim, correction, contribution, institution action, spatial view, account creation **after intent**, pilot enquiry and qualified lead. Keep UTM/referrer attribution and consent; do not mix `node.kubus.site` visitor analytics with `kubus-node` runtime/fleet telemetry. Measurement instrumentation is a later owned change, not a reason to mutate analytics in Wave 0/1.

## Wave 0 — source-of-truth reconciliation

- **Goal / repos / base:** finish docs only in `art.kubus` PR #176 against `dev`; update relevant site docs from current WORLD/TIME heads. Re-fetch all named repositories.
- **Dependencies:** none. **Likely owned:** `CLAUDE.md`, root agent instructions and `docs/PRODUCT_UX_SEO_PROGRAM.md`, this file, design/public-entry/SEO/domain docs; narrow site addenda.
- **Not owned:** product code, indexing rules, DB schema/content, public canonicals, website design, production.
- **Known → target:** PR #176 existed but machine-only Space Mono and older 0–8 sequence contradicted current web family v5. Replace with v5 distinction and Waves 0–12, retain existing useful contracts.
- **Acceptance / visual QA:** fetched SHA matrix, all links resolve, `git diff --check`, contradiction search, no non-doc product diff; visually inspect current reference pages/docs where a visual assertion is made, without claiming new design QA.
- **Stop / done:** stop if a reference head changes during edit and inspect it; done when committed/pushed topic docs have consistent cross-links and stale docs PRs are safely superseded or rebased.

## Wave 1 — SEO + PUBLIC DATA AUDIT (first implementation package)

### Scope, bases and ownership

- **Goal:** explain the gap from indexed to visible to clicked to useful interaction, and identify which entity characteristics correlate with visibility. Produce evidence and proposed thresholds; apply **no** thresholds.
- **Domain detail:** `PLACES_ROUTES_FIELD.md` for conceptual place and quality maturity; it does not authorize schema/index changes.
- **Repos/base:** `art.kubus-backend` from current `master` (unless updated repo instructions say otherwise), `art.kubus` from current `dev` for route inspection and optional local audit scripts. Search Console exports only through approved read access. Document fetched SHAs and export dates.
- **Dependencies:** Wave 0. Wave 2 may do structural presentation work in parallel; eligibility/canonical decisions wait for this report.
- **Likely owned:** new read-only audit scripts under an audit/docs path, report and schema dictionary; tests for URL classification and report joins. Inspect `src/services/seoPublicPagesRepository.js`, `seoIndexingPolicy.js`, `seoPublicPagesService.js`, SEO routes/sitemap and migrations/schema snapshots, app `web/seo-proxy.php` and canonical parser.
- **Explicitly not owned:** mutations, migrations, `seoIndexingPolicy.js` behaviour, sitemap generation, canonical/hreflang changes, production data, Google Search Console property settings, existing website indexing policy, UI.

### Safe extraction procedure

1. Inventory actual schema and source columns from checked-in migrations/schema and read-only database introspection; publish a column mapping. Do **not** assume proposed `qualityScore`, place or tier fields exist. Use a dedicated read-only DB credential with `default_transaction_read_only=on`, `BEGIN READ ONLY`, a short statement timeout, bounded pages/keyset pagination and one consistent snapshot. Never run DDL/DML, `EXPLAIN ANALYZE`, wide joins on the primary without a query plan, or log credentials/raw private rows. If a read-only replica/export is available, prefer it; request an approved extract if direct safe access is unavailable.
2. Build a deterministic public-eligibility extract using the **current** `seoIndexingPolicy.js` and repository query filters. Preserve the difference among stored, public, eligible, sitemap-listed, indexed, impressed and clicked. Count by type, locale and source. Do not label a sitemap entry as Google-indexed.
3. Import Search Console page-level and query/page exports with property, search type, date range, export timestamp, URL, impressions, clicks, CTR and average position. Keep aggregate property counts separately. Normalize scheme/host/trailing slash/percent-encoding and locale; classify compact aliases and redirects, but retain raw URL. Join only to exact current canonical stable-ID routes through the actual parser. Emit unmatched/ambiguous rows; never infer identity from title. Distinguish the earlier “875 URLs” as **URLs with impressions**, not indexed count. Reconcile the near-10k indexed aggregate only to an actual current Indexing export/date, with coverage caveats.
4. Compare index/visibility/click distributions by type, locale, source, quality bands and position bands. Produce high-impression low-CTR and high-position zero-click lists, with dates and anonymized IDs where needed. Treat correlation as correlation; do not claim causation or choose a cutoff from a small subset.

### Entity quality and duplication matrix

For every eligible/public entity collect only safely disclosable fields or derived flags: stable ID/type/locale; source and import batch; `qualityScore` **if present**; real vs generated title; title and description completeness/length/duplicate pattern; artwork author known/attributed/unknown; image presence, verified image and image credit; coordinates, city/parent place; source URL/ID and provenance/verification; localization source vs true translation vs fallback; last reviewed/verified; public/active/moderation status; linked artwork/marker IDs; canonical/robots/sitemap status; GSC metrics. Use null plus `field_available=false` rather than inventing values. Protect non-public data and limit report excerpts.

- **Artwork vs marker:** join using actual `artwork_id` relation and reverse links. Count one-to-one, one-to-many, orphan, standalone place, and potential independent semantic marker. Compare canonical/sitemap/index entries for each pair. Flag duplicate indexable representations when marker has no independent identity. Review examples manually; do not redirect/deindex now.
- **Authorship:** trace `COALESCE(p.display_name, p.username, a.artist_name)` in `seoPublicPagesRepository.js` and `creator` selection in `seoPublicPagesService.js`. Sample importer/owner accounts vs actual artwork artist; distinguish artist/attributed/unknown, uploaded/documented/managed by, source/source ID/URL/verification. Audit Commons/imported image photographer credit separately so it cannot become artwork author. Output discrepancy counts and source paths, without changing data.
- **Open-data/generated records:** stratify by import/source, generated title/description, quality score if real, image rights/verification, coordinates, locality and provenance. Sample records across each stratum and record reviewer confidence. Broad geographic ingestion does not imply publishable city pages.
- **Localization:** compare EN/SL source fields and rendered title/description/body; flag fallback-identical pages, missing translations, incorrect `lang`, alternate targets and false “translated” claims.
- **Index mechanics:** test sampled public, private, missing, duplicate, alias, empty-hub and 503 cases for status, canonical, reciprocal hreflang, x-default, robots, sitemap membership, metadata and JSON-LD. Verify one-hop alias behaviour and no crawler-only branch. Audit existing Ljubljana URLs before proposing place changes.
- **Place inventory:** enumerate current city/place representations and editorial ownership; record names, slug, geometry/centroid/parent, mapped/verified works, artists, institutions, routes and review state **where fields exist**. Propose DATA ONLY → MAPPED → INDEXABLE → EDITORIAL → FIELD VERIFIED → PILOT as conceptual maturity, without migration/schema commitment.

### Output contract and proof

Write a dated `audit-manifest.json` with repo SHAs, DB snapshot/export date, GSC property/date range, query version/hash, row counts and redaction policy; `entity-quality.csv` (or approved private aggregate equivalent) keyed `entity_type,entity_id,locale` with the fields above; `url-performance.csv` keyed raw URL/date window plus canonical join status; `artwork-marker-pairs.csv`; `attribution-cases.csv`; `localization-cases.csv`; and a Markdown report containing method, coverage gaps, funnel table, cohorts, examples, candidate tiers and **proposed** experiment/rollback gates. Keep private row-level exports outside Git; commit only safe aggregate/redacted artifacts and reproducible read-only query definitions.

Minimum `entity-quality` columns: `entity_type,entity_id,locale,canonical_url,source,import_batch,quality_score,quality_score_available,title_origin,title_length,description_length,artist_status,image_present,image_verified,image_credit_status,coordinates_present,city,source_url_present,source_id_present,provenance_status,translation_status,last_reviewed_at,public_state,moderation_state,linked_artwork_id,linked_marker_count,index_eligible,sitemap_listed,gsc_impressions,gsc_clicks,gsc_ctr,gsc_position,join_status`. Use empty/null plus an availability flag when a source field does not exist. Minimum `url-performance` columns: `property,search_type,date_from,date_to,raw_url,normalized_url,canonical_url,entity_type,entity_id,locale,join_status,impressions,clicks,ctr,average_position`. `join_status` is one of `exact,alias,unmatched,ambiguous`; never coerce unmatched/ambiguous to an entity. Report sections: source/method; coverage/limits; funnel counts; quality-by-visibility cohorts; artwork-marker duplicates; authorship/photo-credit cases; localization/canonical/hreflang failures; place inventory; recommended human-reviewed thresholds and rollout/rollback proposal.

- **Tests:** parser/URL join fixtures for every EN/SL entity family, aliases, encoded IDs, unmatched URLs; repeatable query/output schema test on synthetic fixture; sample renderer/status/hreflang checks against a non-production environment; count reconciliation checks. Review query plans/limits before database execution.
- **Visual QA:** screenshot a representative high-position zero-click entity, generated/open-data entity, known-artist entity and localized pair as currently served at phone and desktop widths; label current-state evidence, not redesign approval.
- **Stop:** no safe read-only access/export; undocumented private fields; join ambiguity above a reported threshold; GSC and DB periods incomparable; query plan too costly; policy recommendation would mass-deindex without staged evidence. Record partial coverage instead of fabricating PASS.
- **Done:** report lets reviewers explain indexed ≠ impressed (including the 875 distinction), inspect artist/contributor and artwork/marker risks, reproduce aggregates, and make an explicit later policy decision. No production mutation or index/canonical change.

## Wave 2 — APP-NATIVE PUBLIC ENTITY ENTRY (second implementation package)

### Scope, bases and ownership

- **Goal:** same localized canonical URL → useful semantic PRODUCT frame → exact Flutter entity continuation; installed native app handoff is Wave 3.
- **Repos/base:** `art.kubus-backend` current `master`, `art.kubus` current `dev`; align file ownership before work. Use `APP_NATIVE_PUBLIC_ENTRY.md`, `seo-public-pages.md` and `seo/domain-ownership.md`.
- **Dependencies:** Wave 0; consume Wave 1 attribution/index findings before changing eligibility. Do not change index policy in this package.
- **Backend owned:** `src/services/seoPublicPagesService.js`, `seoPublicPagesRepository.js` and presentation tests. **Inspect but do not alter policy** in `seoIndexingPolicy.js`. Existing renderer is Inter HTML with its own header/footer, hero/cards/shadows and “Explore/Open interactive” CTAs; `COALESCE` can make uploader outrank artist.
- **App owned:** `web/public_flutter_takeover.js`; actual canonical parser `lib/services/share/share_deep_link_parser.dart`, `lib/core/deep_link_startup_routing.dart`, `lib/core/deep_link_bootstrap_screen.dart`; `lib/providers/public_entity_takeover_provider.dart`, `lib/widgets/public_entity_takeover_ready.dart`, `lib/services/public_entity_takeover_bridge_*.dart`; corresponding detail screens/tests and `web/seo-proxy.php` transport as needed.
- **Explicitly not owned:** `AndroidManifest.xml` and signing/association files (Wave 3), broad app shell redesign (Waves 4/8), map controllers, editorial website shell, DB content/schema, mass recanonicalization/noindex, private account bootstrap.

### Exact data and rendering contract

1. Inventory each current canonical EN/SL route and its actual type/ID parser. Keep stable-ID paths in `APP_NATIVE_PUBLIC_ENTRY.md`. Compact aliases remain one-hop compatibility/share links; do not add canonical → compact → `/app` hops.
2. Define one normalized **public presentation** per type with explicit `type, id, locale, canonicalPath, title, description, primaryMedia, facts, related, provenance` and type-specific fields. For artwork, separate `authorship` (artist/attributed/unknown) from `contribution` (uploaded/documented/managed by) and `source` (URL/ID/verification/image photographer). Do not silently populate author from profile owner. Follow current public/private/moderation filters and Wave 1 evidence.
3. Generate semantic PRODUCT hierarchy from that presentation: product navigation; media; title/artist/place; compact facts; meaningful actions; description; map relation; related records; contribution/provenance/correction. Remove generic marketing header/footer, hero/card/shadow default and bridge CTA strings from canonical entity frames. Do not copy the WORLD editorial two-thirds layout. Use v5 family type roles and PRODUCT density. Human and crawler get the **same** response.
4. From the same presentation derive visible HTML, metadata, canonical, reciprocal hreflang/x-default, OG/Twitter and JSON-LD. Embed a versioned, escaped, size-bounded JSON bootstrap containing **public fields only**; include type/ID/locale/path and a safe revision/expiry marker. Escape script terminators; no session/auth, private moderation, tokens, unpublished data or untrusted executable markup. A mismatched/expired payload is ignored and fetched normally.
5. Flutter consumes bootstrap only after exact route/type/ID/path validation and seeds the existing public entity provider/screen. Revalidate when appropriate without replacing a useful first frame with a loader. Keep initial browser path/query/fragment and navigation history; auth begins at action and returns to that action.
6. Remove the 1500 ms synthetic `kubus:public-entity-ready` emission from `web/public_flutter_takeover.js`. The correct detail screen alone declares readiness after meaningful media/text/fallback is painted; the controller checks exact type, ID and pathname. Engine/route readiness, elapsed time or generic shell never counts. Slow/failed Flutter leaves SSR accessible. Only one layer is focusable/ARIA-visible at each transition; reduced motion switches without animation.
7. Preserve real public 200/private-or-missing 404/backend-failure 503, no-JS usability, safe cache/CSP and root-relative bootstrap assets. Confirm `web/seo-proxy.php` still forwards only its allowlisted public routes/headers and no credentials. Do not create a crawler-specific UI.

### Proof and stop

- **Tests:** backend presentation parity for HTML/metadata/JSON-LD/bootstrap; escaping/privacy/oversize and attribution fixtures; public/private/missing/error HTTP tests; EN/SL canonical/hreflang/alias tests; app parser/bootstrap mismatch/expiry tests; takeover tests proving route/engine/time cannot activate and exact painted screen can; history/back and action-return tests.
- **Visual QA:** screenshot SSR with JS disabled, slow Flutter, failed bundle and post-takeover on artwork, artist/profile and institution plus representative other type; Chromium/Firefox, 390px and 1440px, EN/SL, light/dark, 200% zoom, keyboard and reduced motion. Compare information order and visual geometry; capture any unavoidable difference. No-JS primary actions must work or be honestly marked as interactive-only.
- **Stop:** presentation requires private/ambiguous data; canonical parser disagrees with backend; a screen cannot signal exact readiness; bootstrap needs a new auth exposure; proposed visual parity requires an app-wide redesign; a change would modify indexing without Wave 1 decision. Document blocker and keep SSR usable.
- **Done:** external canonical entity opens directly into useful PRODUCT content, remains on the same URL, transitions only on exact screen readiness, and still works without Flutter; status/SEO/privacy contracts and screenshots pass.

## Wave 3 — canonical Android App Links

- **Goal / repos / base:** exact localized canonical links open native art.kubus; `art.kubus@dev` and the current owner of `app.kubus.site/.well-known/assetlinks.json`.
- **Dependencies:** Wave 2 route contract. **Likely owned:** `android/app/src/main/AndroidManifest.xml`, link parser/tests, association file/deploy contract. Current manifest claims compact/legacy paths but not all EN/SL canonical families.
- **Not owned:** SSR renderer, index policy, map, iOS release without active signing target.
- **Target:** add narrowly scoped path families for artwork/profile/event/exhibition/post/collection/collectible/map; verified HTTPS association with real release signing fingerprint; parse exact locale/type/ID; preserve aliases for compatibility. Document future iOS Associated Domains/AASA, implement only with available target.
- **Tests / visual QA:** `adb shell pm get-app-links` or OS equivalent plus cold/warm/running app opens for every family, missing/private fallbacks, browser without app, Android phone screenshot/video showing exact entity and back stack.
- **Stop / done:** stop if signing fingerprint or host association ownership is unavailable; done only when OS reports verified association and actual installed build navigates correctly.

## Wave 4 — PRODUCT design primitives

- **Goal / repos / base:** centralize v5 PRODUCT typography, semantic structural roles and reusable entity primitives in `art.kubus@dev`; read `DESIGN_SYSTEM_V2.md` and current WORLD/TIME family v5.
- **Dependencies:** Wave 2 public presentation and v5 reference. **Likely owned:** `lib/utils/design_tokens.dart`, shared type/style/components and public detail primitives. Current app uses Inter and established category/signal marker colours.
- **Not owned:** routing, backend SEO service, map controllers, whole-screen restyles or marker category recolouring. Keep current working screens until Wave 7 classification.
- **Target:** Sofia Sans for primary PRODUCT type and selective Space Mono for approved structural roles, with lowercase brand names; semantic ground/surface/foreground/rule/active roles, hairlines, spacing and restrained elevation. Preserve native controls, touch targets, theme and existing marker data colours. Do not mechanically upper-case or monospacify all controls.
- **Tests / visual QA:** token/widget tests for EN/SL, light/dark, text scaling and focus; screenshots of public detail primitives on phone and desktop beside SSR and current site references.
- **Stop / done:** stop if asset licensing/font support or central ownership is unresolved; done when primitives are reusable, documented and visually compared without broad app screen churn.

## Wave 5 — WORLD globe capability spike

- **Goal / repos / base:** prove a MapLibre globe path in `art.kubus@dev`, using `art.kubus.site@redesign/a1-foundation` as **behaviour reference**, not code/layout to paste.
- **Dependencies:** Wave 0 and map inventory. **Likely owned:** a small throwaway/test harness or capability adapter around current `maplibre_gl ^0.26.2`; inspect `KubusMapController`, `MapLayersManager`, `KubusMapMarkerSyncEngine`, web MapLibre registration and native plugin APIs.
- **Not owned:** replacing MapLibre, new map screen, production marker rendering or WORLD's editorial layout.
- **Known → target:** Flutter already has map architecture. Verify projection/globe availability and camera, gestures, style/theme and layer compatibility on Flutter web, Android and iOS if build target is available. If APIs differ, specify a **small** renderer capability boundary with one existing controller owner. Include fallback path and measured frame/memory impact.
- **Tests / visual QA:** capability matrix with exact package/OS/device/build SHA; test pan, pinch, zoom, theme, return from detail, reduced motion and unavailable globe; paired captures at world/region/city. Separate emulator from physical-device evidence.
- **Stop / done:** stop if globe requires replacing MapLibre or architectural fork; done when supported/unsupported behaviour and adaptation cost are proven, not guessed.

## Wave 6 — globe and marker LOD in existing map

- **Goal / repos / base:** port WORLD behaviour to `art.kubus@dev`; read WORLD `src/map/recordLayers.ts`, `src/home/storyState.ts`, `IsometricMap.vue` and QA evidence at current head.
- **Dependencies:** Wave 5 feasible path. **Likely owned:** `lib/features/map/controller/kubus_map_controller.dart`, `lib/features/map/map_layers_manager.dart`, `lib/features/map/engine/kubus_map_marker_sync_engine.dart`, existing marker rendering/cluster/viewport/filter/target utilities, mobile/desktop map wiring.
- **Not owned:** parallel renderer or map screen, public WORLD editorial composition, backend indexing, global tokens, unrelated entity details.
- **Known → target:** one continuous world → Europe/region → country → city → street. SL may frame Slovenia, EN wider Europe, but both use one WORLD. Far cheap data-coloured dots, mid canonical markers, close cover **within canonical geometry**, selected always represented, heavy covers bounded; keep complete archive GPU-native. Reference values `5/7/10/10.5/32` are device-tuning inputs. Preserve clusters, same-coordinate stacks, spiderfy, hover/press, selection, promotion, signal tier, subject semantics, viewport loading and caching. Camera ownership prevents gesture/narrative conflict. Theme updates in place where supported.
- **Result constraints:** make viewport, travel radius, nearby mode, quick filters, search and place framing visible as separate active constraints with a clear reset; no silent result restriction.
- **Tests / visual QA:** marker identity/LOD/selection/cluster/spiderfy, same-coordinate and filter tests; world-to-street gestures, rapid zoom/theme, offline/WebGL fallback and frame/memory profiling. Screenshots/video at world, regional, city and street on phone/desktop, EN/SL, themes; physical Android proof for performance claims.
- **Stop / done:** stop if capability/marker API forces a new map system or device memory exceeds measured budget; done with one map implementation, meaningful constraint UI and no selected-marker loss.

## Wave 7 — complete task and screen UI/UX audit

- **Goal / repos / base:** produce evidence-backed classification in `art.kubus@dev`; inspect backend/admin only to verify task contracts. No broad restyle.
- **Dependencies:** Waves 2–6 sufficiently stable to review. **Likely owned:** audit matrix, screenshot artifacts and bounded backlog, not implementation files.
- **Not owned:** polishing screens, deleting flows, DAO/schema redesign or declaring untested device acceptance.
- **Current → target:** inventory all navigation/screens and tasks for guest, registered, artist, institution and advanced/Web3; mobile, desktop web and Android; EN/SL, light/dark; loading, empty, error, offline, permission denied, auth states. Walk: external canonical entity; guest/map; search→place→entity; map→artwork→artist→institution; protected action→contextual auth→conditional onboarding→**original action**; save, follow, comment, contribute, correct, claim, artist studio, institution hub, events/exhibitions, community, messages, notifications, settings, privacy/analytics, advanced Web3, DAO and spatial viewing/capture.
- **Output:** each major screen KEEP/REFINE/REDESIGN/MERGE/REMOVE; each issue P0/P1/P2/P3 with task, role/state/platform, current screenshot, exact failure, target flow, owning files, acceptance scenario and dependency. Identify duplicate controls and obsolete flows. Screens marked REMOVE receive no cosmetic task.
- **Tests / visual QA:** manual scripted journeys and screenshot index at phone/desktop/native, EN/SL/themes; browser console and keyboard evidence, Android safe areas/permissions. Label unavailable test surfaces.
- **Stop / done:** stop claiming full coverage where an account/device/feature flag is unavailable; done when every listed journey has a disposition and bounded Wave 8 assignment.

## Wave 8 — bounded PRODUCT polish slices

- **Goal / repos / base:** implement only approved Wave 7 P0/P1 then P2 slices in `art.kubus@dev`, with backend change only for a verified contract gap.
- **Dependencies:** Wave 7 classification and explicit file-owner ledger. **Likely owned slices:** H1 shell/navigation; H2 auth/onboarding/action return; H3 discovery/search/map controls; H4 artwork/profile/institution public detail; H5 community/messages/notifications; H6 contribution/creator/artist studio; H7 authenticated institution workspace; H8 settings/privacy/analytics; H9 advanced web/Web3/wallet/marketplace. A slice PR names exact screens/providers/services; do not combine all slices into one PR.
- **Not owned:** another slice's files; Wave 9 institution schema/editorial funnel, Wave 10 DAO lifecycle, canonical/index changes. Foundational files named in Shared ownership rules have one owner and integration sequence.
- **Known → target:** contextual auth preserves intended action; email/Google are low-friction, wallet optional for cultural use; role-specific controls and states become clear; removed/merged screens stop competing with kept flows. Maintain mobile/desktop parity and store-app advanced capability boundaries.
- **Tests / visual QA:** per-slice task regression including auth cancel/resume, guest, error/offline, EN/SL, light/dark, phone/desktop/Android as applicable; before/after screenshots for every changed screen and original task, not just component snapshots.
- **Stop / done:** stop if the audit does not decide ownership or a backend contract is ambiguous; done only when the named task completes in all applicable states with no foundation conflict.

## Wave 9 — institutions v2, editorial and participation

- **Goal / repos / base:** model public institution vs authenticated workspace and evolve existing editorial/funnel systems in `art.kubus@dev`, `art.kubus-backend@master`, `admin.kubus` current integration branch, and acquisition site current WORLD head.
- **Domain detail:** `INSTITUTION_EDITORIAL_LIFECYCLE.md`.
- **Dependencies:** Wave 8 relevant detail/auth flows; inspect current schema/adapters first. **Likely owned:** Flutter `lib/models/institution.dart`, institution provider/detail/hub; backend institution table/profile-`is_institution` fallback and `editorialArticleService.js`; admin `EditorialArticlesView.vue` and `CityEditorialView.vue`; public participation forms/attribution plumbing.
- **Not owned:** third CMS, blind status/schema migration, generic beauty pass on `InstitutionDetailScreen`, DAO moderation, paid-only participation.
- **Known → target:** current Flutter Institution is shallow; backend may use institution table and profile fallback. Public entity fields: identity, logo/cover, type, verification, mission, location/map, hours/accessibility, website/public contact/social, exhibitions/events, works/artists/collections/routes/spatial, languages/provenance/update/claim. Workspace fields: programme, works, exhibitions/events/routes, team, QR/deep links, spatial, analytics, integrations/settings. Map compatibility before migration. Existing editorial statuses are `draft/scheduled/published/archived`; audit current site scope, locale, category, canonical group, SEO, blocks, tags and scheduling before proposing review/fact/translation steps or richer blocks. Admin preview must match production. Three separate intents: open claim/create/publish; supported pilot request; municipality/strategic collaboration. Preserve UTM/referrer.
- **Tests / visual QA:** institution fallback/model compatibility, role permission and public/private tests; editorial draft/schedule/publish/preview/translation tests; all three CTA paths with attribution; public/workspace screenshots on phone/desktop, EN/SL/themes, real data and empty/error states.
- **Stop / done:** stop if institution identity resolution or editorial migration rules are ambiguous; done when participation is open without a paid pilot, previews match production and roles/data contracts are proven.

## Wave 10 — cultural lifecycle, admin moderation and DAO

- **Goal / repos / base:** one cultural-data lifecycle in `art.kubus-backend@master`, `admin.kubus` current integration branch and `art.kubus@dev`.
- **Dependencies:** Waves 8–9. **Likely owned:** contribution/correction/provenance/verification/dispute/publication policy and associated admin views; governance proposal/review/vote/delegation only after ownership decisions.
- **Not owned:** treating DAO votes as routine content moderation, public index policy by accident, website visitor analytics as node fleet, local kubus-node private telemetry.
- **Known → target:** map each transition and actor for contribution, correction, source check, institution verification, moderation, dispute and publication. Assign operational admin, community review and actual governance to distinct decisions. Then redesign DAO UX around the verified governance subset.
- **Tests / visual QA:** transition/permission/audit-trail and privacy tests; admin and product role scenarios; screenshots of review, dispute, vote and delegate flows with status/empty/error states and EN/SL where public.
- **Stop / done:** stop if governance authority/legal policy is undecided; done with one documented state machine and demonstrated separation of moderation and DAO.

## Wave 11 — Ljubljana field programme

- **Goal / repos / base:** make Ljubljana the verified reference dataset through real sessions; `art.kubus@dev` tools and current backend data, plus WORLD editorial output only after review.
- **Domain detail:** `PLACES_ROUTES_FIELD.md`.
- **Dependencies:** coherent core PRODUCT and field-safe contribution/correction path. **Likely owned:** field protocol, session log, candidate list, reviewed corrections/media/provenance; later narrow app fixes arising from sessions.
- **Not owned:** automatic bulk publication, a giant Field Mode, splat capture for every mural or unverified field PASS.
- **Known → target:** per artwork/place verify existence, coordinates, artist attribution, title, category, condition, photos, source/signage, institution/place/neighbourhood and review date. Capture levels 0 verify, 1 document, 2 spatial, 3 immersive/aligned. Prefer sculpture, installation, architectural/context-heavy, ephemeral or temporal-comparison candidates for spatial. Existing `kubus.capture/1` → reconstruction → `kubus.spatial/1` remains the path.
- **Tests / visual QA:** timestamped real-session records with location/device/media rights, reviewer signoff and before/after entity/map screenshots; distinguish simulator from physical sessions.
- **Stop / done:** stop Field Mode design until several sessions reveal recurring friction; done with reviewed reference records, clear spatial candidates and a measured workflow backlog.

## Wave 12 — spatial derivative, streaming and replication

- **Goal / repos / base:** implement usage-driven delivery in `kubus-node` current integration branch, with app viewer/backend coordination after Wave 11 evidence.
- **Domain detail:** `SPATIAL_DELIVERY_ROADMAP.md`.
- **Dependencies:** real field asset sizes/usage, capacity policy and privacy/security review. **Likely owned:** kubus-node `src/spatial/`, worker, `src/gui/spatialGuiApi.ts`, viewer transport, replication/retention; app `lib/widgets/spatial/` and spatial transport; backend spatial publication contract.
- **Not owned:** changing canonical archive integrity, silently publishing private captures, automatic full PLY delivery, unrelated network analytics.
- **Known → target:** runtime accepts `spatial.optimize`/`spatial.generate_preview` types but current worker only reconstructs; `kubus.spatial/1` already models variants, and GUI stream has Range support while current viewer still fetches `blob()`. Implement CAPTURE → master reconstruction → HOT small `spatial_preview`, WARM streamed/paged `spatial_mobile` runtime LOD, COLD canonical `spatial_archive` PLY. Archive is preservation/reprocessing, never automatic normal viewing. Spark receives direct paged URL, no giant PLY→Blob→object URL. Where auth requires it, short-lived read-only viewer capability URLs; Range, ETag, cache semantics. Capacity-aware HOT broad / WARM moderate / COLD sparse replication and source/work-directory retention. Do not fabricate variants from one PLY.
- **Tests / visual QA:** compare peak memory, first meaningful frame, range requests and network bytes on representative field assets; expiry/auth/privacy and cache tests; variant integrity/fallback, replication under disk limits and work cleanup; phone/desktop viewer captures for preview/runtime/archive explicit opt-in. Preserve physical/GPU evidence class separately from unit tests.
- **Stop / done:** stop if candidate assets or capability security/capacity rules are missing; done when runtime viewing is measured as streamed, archive remains cold and canonical, and failures degrade without full-buffer fallback.

## Review gate summary

Wave 1 evidence precedes policy thresholds. Wave 2 visual/semantic parity precedes native-link release claim. Wave 5 capability precedes Wave 6 map implementation. Wave 7 classification precedes broad polish. Wave 10 lifecycle ownership precedes DAO redesign. Several real Wave 11 sessions precede dedicated Field Mode or Wave 12 sizing decisions. Each later agent must state **what is true now, what remains, exact change and owner, data contract, exclusions, test, screenshot, and stop condition** in its PR.
