# Institutions, editorial and cultural-data lifecycle

Status: staged target, not a schema migration. Read master `PRODUCT_UX_SEO_PROGRAM.md` and Wave 9–10 packages in `AGENT_EXECUTION_PLAN.md`. Reviewed 2026-09-22.

## Institution identity before screen polish

Current Flutter `lib/models/institution.dart` is shallow. Backend institution-table records and `profile.is_institution` compatibility may both feed public presentation. Audit actual identity/fallback/permission mapping before extending data or restyling `InstitutionDetailScreen`.

**Public institution entity:** identity, logo, cover, name, type, verification, description/mission, location/map, hours, accessibility, website, public contact/social, current exhibitions, upcoming events, artworks, artists, collections, routes, spatial assets, languages, provenance, last update and claim/correction. Render only verified public fields; missing values remain absent rather than invented.

**Authenticated workspace:** programme, artworks, exhibitions, events, routes, team, QR/deep links, spatial, analytics, integrations and settings. Membership/roles govern operations. This is a separate information architecture from the public profile.

Participation has **three distinct intents**: (1) open claim/create/publish, (2) supported institutional pilot request for digitisation, route design, QR/deep links, spatial/AR, analytics, visitor engagement or onboarding, and (3) municipality/strategic city-level collaboration, API/data integration, routes and network partnership. A paid pilot is not the only participation path. Keep existing UTM/referrer attribution.

## Existing editorial infrastructure

Do not build a third CMS. Backend `src/services/editorialArticleService.js` and admin `EditorialArticlesView.vue` / `CityEditorialView.vue` already exist. Current status set is `draft`, `scheduled`, `published`, `archived`. Inventory site scope, locale, category, template, canonical group, SEO metadata, content blocks, tags, reading time and schedule before changing workflow.

Possible future workflow: draft → review → fact/source checked → translation ready → approved → scheduled → published → review due → archived. These are **review tasks**, not approved DB states. Candidate richer blocks: paragraph, heading, image, gallery, quote, fact, entity/artist/institution card, artwork grid, map, route, timeline, sources, CTA, spatial viewer and related content. Audit existing block rendering and permissions first. Admin preview must eventually match production rendering.

## Cultural-data lifecycle before DAO

Define actor, evidence, state and transition for contribution → correction → provenance/source check → verification → moderation → institution verification → dispute/review → publication/withdrawal. Decide which transitions are operational admin actions, which can use community review, and which are true governance. Only then redesign proposal, review, vote and delegate UX. DAO is not routine moderation. Keep public/private disclosure and spatial withdrawal semantics intact.
