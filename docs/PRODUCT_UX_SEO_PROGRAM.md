# art.kubus master product programme

Status: canonical roadmap, documentation baseline 2026-09-22. This is the **one** cross-repository sequence. `AGENT_EXECUTION_PLAN.md` contains bounded packages and acceptance gates; the linked domain documents own detailed contracts. No large product redesign is authorized by this document alone.

## Verified source baseline

| Owner | Reference | Role and current fact |
| --- | --- | --- |
| `kubus-project/art.kubus` | `dev@35db11ee`; programme PR #176 head `90e50b26` before this pass | Flutter PRODUCT, web transport and Android links; `maplibre_gl ^0.26.2` |
| `kubus-project/art.kubus.site` | `redesign/a1-foundation@1ca922c6`, PR #17 | Authoritative WORLD behaviour, `src/map/recordLayers.ts`, camera ownership, in-place theme, optical veil and public editorial composition |
| `kubus-project/kubus.site` | `redesign/k1-foundation@8174330c`, PR #3 | Authoritative TIME composition, scroll-linked field and family typography |
| `kubus-project/node.kubus.site` | `feat/initial-node-site@0d31a8bd` | INFRASTRUCTURE public website and its visitor analytics |
| `kubus-project/kubus-node` | `docs/agent-contract@5a67403c` | Local/distributed runtime, operator GUI, spatial processing, storage and fleet participation |
| `kubus-project/art.kubus-backend` | `master@d6f015e5` | Public renderer, indexing policy, entities, editorial and institution services |
| `kubus-project/admin.kubus` | `feat/node-site-analytics-property@c39c9b04` | Editorial, moderation and analytics operations; website visitors and platform nodes remain distinct |

These SHAs are a dated evidence snapshot, not permanent branch pins. Re-fetch before each package. Preserve unrelated local work. Current WORLD/TIME heads, not old `master` visuals, are the reference. The public websites' mirrored `WEB-FAMILY.md` **v5** is the typography/family authority; see `DESIGN_SYSTEM_V2.md` for PRODUCT application.

## Ownership and invariants

- `kubus.site` owns research, history, monograph, manifesto, project development and critical/theoretical writing.
- `art.kubus.site` owns acquisition, cultural geography, city guides, routes/guides, field notes and participation explanation. It links to, never duplicates, canonical product entities.
- `app.kubus.site` owns canonical public artworks, profiles, events, exhibitions, posts, collections, collectibles and distinct map/place entities, plus the interactive product. Localized stable-ID routes are preferred; compact paths are share/compatibility aliases. See `seo/domain-ownership.md`.
- `node.kubus.site` explains/distributes the runtime; `kubus-node` runs it. Keep their analytics and architecture separate.
- The semantic entity renderer remains for crawlability, metadata, no-JS content and real 404/503. It must become a useful PRODUCT first frame; exact Flutter entity continuation occurs on the **same canonical URL**, with no generic bridge, user-agent cloaking or synthetic readiness. See `APP_NATIVE_PUBLIC_ENTRY.md` and `seo-public-pages.md`.
- Artwork is a cultural entity; a marker is a spatial representation. Where `marker.artwork_id` links a marker without independent semantics, artwork owns search canonicalization.
- Artist/attributed/unknown authorship, platform contributor/owner and provenance/photographer credit are separate. Do not infer artist from uploader. No index policy, canonical or production data changes until Wave 1 evidence is reviewed.
- PRODUCT inherits the family grammar, not WORLD's right-two-thirds editorial page layout. Its map normally owns the viewport. Preserve the existing Flutter map architecture.
- Auth begins at protected actions and returns users to the **original intended action**; ordinary discovery/account creation must not require a wallet.
- Do not build a third CMS, replace admin moderation with DAO, or engineer dedicated Field Mode before evidence.

## Dependencies and gates

| Wave | Bounded outcome | Entry gate → exit evidence |
| --- | --- | --- |
| **0** Docs/source of truth | Reconcile PR #176, v5 family, WORLD/TIME references and stale docs PRs | Current fetched heads → committed docs, consistent links, no product code |
| **1** SEO + public data evidence | Read-only entity/GSC/index/attribution/place audit | Wave 0 → reproducible reports, quality correlations and policy proposals only |
| **2** App-native entity entry | Normalized public presentation, semantic PRODUCT frame, safe bootstrap, exact takeover | Wave 0; Wave 1 findings for policy decisions → HTML/Flutter parity, no-JS/error/visual proof |
| **3** Android canonical links | Verified association and exact localized entity navigation | Wave 2 route/identity contract → real signing proof and cold/warm/running-app tests |
| **4** PRODUCT primitives | Central type/colour/structure roles and public detail primitives | v5 contract + Wave 2 parity → component tests and screenshot evidence; no broad restyle |
| **5** WORLD globe capability spike | Prove MapLibre globe path on Flutter web/Android and iOS if available | Current map inventory → platform matrix, minimal adapter only if necessary |
| **6** Globe + marker LOD | Continuous world-to-street map through existing controllers | Wave 5 feasible path → device performance, map/LOD/selection/filter acceptance |
| **7** Complete UI/UX audit | Task/screen inventory, classification and screenshot-backed backlog | Entry/map foundations stable → role/platform/state matrix and approved bounded slices |
| **8** Product polish | Owned slices for shell/auth, discovery, entities, community, creator, workspace, settings and advanced web | Wave 7 decisions → task regression, EN/SL, responsive/device evidence |
| **9** Institution v2 + editorial + funnels | Public/workspace institution distinction; existing CMS evolution; three participation intents | Wave 8 relevant flows + model audit → real data/preview/attribution and user-flow proof |
| **10** Admin/moderation/DAO | One contribution/provenance/verification/dispute lifecycle, then governance UX | Waves 8–9 → operational/community/governance ownership and role tests |
| **11** Ljubljana field programme | Real sessions, verified reference dataset and capture maturity evidence | Core PRODUCT coherent → logged field records and several sessions before Field Mode design |
| **12** Spatial delivery | Preview HOT, paged runtime WARM, archive PLY COLD; replication/retention from usage | Wave 11 usage + capacity/security review → measured streamed viewing and preservation tests |

Some field verification can start operationally when PRODUCT supports it; **dedicated Field Mode waits for several real sessions**. Wave 12 architecture is recorded now, not implemented in this docs pass. Cross-wave stop conditions and exact package ownership are in `AGENT_EXECUTION_PLAN.md`.

## Domain contracts

| Topic | Owner document and current implementation to inspect |
| --- | --- |
| Family/design | `DESIGN_SYSTEM_V2.md`; WORLD/TIME `docs/WEB-FAMILY.md` v5, site `docs/DESIGN-SYSTEM.md` |
| Public URL/renderer | `APP_NATIVE_PUBLIC_ENTRY.md`, `seo-public-pages.md`, `seo/domain-ownership.md`; backend `seoPublicPagesService.js`, `seoPublicPagesRepository.js`, `seoIndexingPolicy.js` |
| Map | `AGENT_EXECUTION_PLAN.md` Waves 5–6; WORLD `src/map/recordLayers.ts`; Flutter `KubusMapController`, `MapLayersManager`, `KubusMapMarkerSyncEngine` |
| Places/routes/field | `PLACES_ROUTES_FIELD.md`; current city/place representations and Ljubljana evidence |
| Editorial/institutions/DAO | `INSTITUTION_EDITORIAL_LIFECYCLE.md`; existing backend `editorialArticleService.js` and admin `EditorialArticlesView.vue` / `CityEditorialView.vue`; Flutter `Institution` model and backend fallbacks |
| Spatial | `SPATIAL_DELIVERY_ROADMAP.md`; kubus-node `docs/SPATIAL.md`, `kubus.capture/1` → `kubus.spatial/1`, current app viewer/capture |
| Analytics | `AGENT_EXECUTION_PLAN.md` measurement contract; admin `CLAUDE.md` website analytics vs PLATFORM/Nodes distinction |

## Outcome measures

Measure indexed → visible → clicked → useful product interaction, with entity type, locale, source and quality. Registration is one downstream signal. Also track related navigation, map/artwork open, route start/completion, save, follow, claim, correction, contribution, institution action, spatial view, meaningful-intent account creation, pilot enquiry and qualified institutional/municipal lead. Preserve UTM/referrer attribution and consent boundaries. Never present `node.kubus.site` visitors as kubus network nodes.
