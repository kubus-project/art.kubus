# art.kubus product / SEO / UI-UX consolidation programme

Status: **canonical execution plan**
Last updated: 2026-09-21.

This is the ordered programme for the next major art.kubus work. Agents must
not collapse the phases into one giant redesign PR.

For dependency/file-ownership sequencing, use
[`AGENT_EXECUTION_PLAN.md`](AGENT_EXECUTION_PLAN.md).

## 0. Repository baselines

### Product repositories

- `kubus-project/art.kubus` — Flutter application, web artifact, native links.
- `kubus-project/art.kubus-backend` — API, PostgreSQL, public entity renderer,
  SEO policy/sitemaps, editorial/institution services.
- `kubus-project/art.kubus.site` — public archive/acquisition/editorial website.
- `kubus-project/kubus.site` — kubus research/project site.
- `kubus-project/admin.kubus` — internal operations/editorial/moderation console.
- `kubus-project/kubus-node` — distributed node + spatial processing/runtime.

### Current visual references

Use these, not the obsolete master-site appearance:

- `art.kubus.site@redesign/a1-foundation` — WORLD.
- `kubus.site@redesign/k1-foundation` — TIME.
- current kubus Node operator UI — INFRASTRUCTURE.

The application becomes the PRODUCT sibling.

## 1. Phase A — evidence baseline: SEO, public data and entry

Before changing index policy or doing broad UI work, produce a reproducible
baseline.

### A1. Search/index audit

Join Search Console exports to public entities where possible and report:

- indexed/eligible counts by entity type and locale;
- URLs with impressions vs indexed URLs;
- clicks/CTR/position distribution;
- high-ranking zero-click entities;
- title/meta pattern quality;
- hreflang/fallback duplication;
- canonical/alias behaviour;
- artwork ↔ marker duplicate ownership;
- thin-content patterns.

Existing known baseline from the current Search Console export:

- almost 10k URLs are indexed overall;
- only a much smaller subset receives impressions;
- app.kubus.site entity CTR is materially below art.kubus.site acquisition CTR;
- some artwork canonicals rank well but receive no clicks.

Treat these as hypotheses to refresh, not hard-coded permanent metrics.

### A2. Data-quality audit

Report public records by:

- source/import provenance;
- quality score where present;
- meaningful title;
- known/unknown artist;
- description length/quality;
- verified image;
- place/city;
- category/medium/year;
- localization;
- last review/verification;
- moderation/publication state.

Do not mutate production data in the audit.

### A3. Public-entry audit

Trace canonical routes through:

- backend renderer;
- `seo-proxy.php`;
- Flutter canonical route parsing;
- bootstrap/takeover;
- history/back;
- auth return route;
- Android App Links.

Output a concrete route/ownership matrix and current violations.

## 2. Phase B — app-native canonical public entities

Implement `docs/APP_NATIVE_PUBLIC_ENTRY.md`.

### B1. Native semantic renderer

Recompose artwork/profile/institution/event/exhibition/etc. HTML to match the
product family and actual Flutter detail hierarchy.

Do not redesign all Flutter screens yet. First establish the shared public
entity primitives and enough target detail-screen structure to make HTML ↔
Flutter continuous.

### B2. Shared bootstrap payload

Avoid redundant initial entity fetching where safe. One normalized public
presentation should feed:

- visible semantic HTML;
- metadata/JSON-LD;
- bootstrap payload;
- initial Flutter detail.

### B3. Exact readiness

Remove the synthetic 1500 ms entity-ready fallback from
`web/public_flutter_takeover.js`. Never hide a valid semantic frame behind a
generic engine frame.

### B4. Platform-native links

Make canonical localized entity URLs the Android verified link surface.
Version/test `assetlinks.json`; add iOS equivalent when that build target is
ready.

## 3. Phase C — WORLD map convergence

Do not copy/paste the Vue map. Port the proven contracts into the existing
Flutter map architecture.

Current Flutter sources of truth:

- `lib/features/map/controller/kubus_map_controller.dart`;
- `lib/features/map/map_layers_manager.dart`;
- marker sync/rendering utilities under `lib/features/map` and
  `lib/widgets/map`.

Reference implementation:

- `art.kubus.site@redesign/a1-foundation/src/map/recordLayers.ts`;
- `src/map/globeFraming.ts`;
- `src/map/globePerformance.ts`;
- `src/map/globeShading.ts`;
- `src/components/shared/IsometricMap.vue`;
- canonical marker asset manifest.

### C1. Capability spike first

The Flutter app currently uses `maplibre_gl ^0.26.2`. Prove globe capability
separately on:

- Flutter web;
- Android;
- iOS target if available.

If the Flutter plugin does not expose the required globe API uniformly, do not
fork the whole map architecture immediately. Implement a renderer capability
adapter and use platform-specific MapLibre access only behind that boundary.

### C2. Globe behaviour

Target:

- globe at world/regional scales;
- smooth transition to local map framing;
- real map remains interactive;
- page/native gestures do not fight;
- theme/time effect is restrained and fails safely;
- no per-frame marker recreation.

### C3. Marker LOD parity

Reference progression:

- distant: dots;
- mid: canonical kubus pin identity;
- close: cover image inside canonical marker silhouette;
- selected record persists;
- DOM/widget-heavy covers bounded;
- cluster/spiderfy and same-coordinate behaviour remain coherent.

Marker cover images should be a discovery affordance at close zoom, not generic
floating image cards.

### C4. Filters and viewport semantics

Resolve the existing conflict among:

- current viewport;
- travel/radius;
- quick filters;
- search;
- locale default framing;
- clustering;
- marker loading/caching.

The user should always understand whether results are constrained by what is on
screen, by a travel radius, or by an explicit place/filter.

## 4. Phase D — complete app UI/UX audit

Audit before broad polish.

### D1. Inventory

Inventory every major screen and reusable shell for:

- mobile;
- desktop web;
- native;
- guest;
- logged in;
- artist;
- institution;
- relevant Web3/advanced mode.

### D2. Flow audit

At minimum:

- first launch / guest exploration;
- search → city/place → entity;
- map → entity → related entity;
- canonical external entity entry;
- gated action → auth → onboarding → return to intended action;
- save/follow/comment;
- contribution/create/correct/claim;
- artist studio;
- institution hub;
- events/exhibitions;
- community/messages;
- notifications/deep links;
- settings/privacy/analytics;
- wallet/Web3 advanced surfaces;
- DAO/governance;
- spatial capture/view where enabled.

### D3. Classification

Every major screen: KEEP / REFINE / REDESIGN / MERGE / REMOVE.

Every issue: P0 broken / P1 task friction / P2 design debt / P3 polish.

### D4. Evidence

Produce screenshots and notes, not just source-code opinions. Check responsive
composition, copy, localization, keyboard, focus, empty/loading/error states and
actual device constraints.

## 5. Phase E — deep product polish

Only after Phase D findings are agreed.

Expected work includes:

- shell/navigation hierarchy;
- search/filter consolidation;
- artwork/profile/institution detail;
- auth/onboarding/gated actions;
- creator flows;
- institution workspace;
- community density;
- settings discoverability;
- responsive desktop layout;
- removal of role simulation from release builds where still present;
- component/token consolidation;
- copy/localization cleanup.

Do not preserve a poor screen merely because it already has a shared widget.

## 6. Phase F — institutions, editorial and pilot funnels

### Institution model

Normalize institution identity and management before simply adding more UI.
Public profile and authenticated workspace are separate information
architectures.

Public profile should support, as data exists:

- identity/verification;
- logo/cover;
- description/mission;
- location/opening/accessibility;
- programme;
- current/upcoming events/exhibitions;
- artworks/artists/collections/routes;
- website/contact/social;
- provenance/last update;
- claim/correction.

### CTA separation

Keep three distinct intents:

1. join/claim/create a public institution profile;
2. request a supported institutional pilot;
3. discuss municipality/API/strategic integration.

Do not make a paid pilot the only path into institutional participation.

### Editorial

Consolidate around the backend/admin editorial services already present. Audit
the current article + city-highlight pipelines before adding another CMS layer.
Improve review states, source handling, translation readiness, entity links,
production previews and stale-content review.

## 7. Phase G — systemic QA + governance/admin coherence

This is deliberately after the deep polish.

Then align:

- public data QA;
- admin moderation;
- editorial QA;
- contribution correction;
- provenance;
- institutional verification;
- DAO proposal/review/vote surfaces.

The goal is one coherent lifecycle for contested/edited cultural data rather
than separate moderation concepts in admin and DAO.

## 8. Phase H — Ljubljana field programme

After the core product is coherent, use Ljubljana as the reference dataset.

Field capture tiers:

- verify;
- document;
- spatial capture;
- immersive/aligned capture when justified.

A field session should update metadata, provenance, coordinates, condition,
photography, institution/place relations and verification date. Spatial capture
uses the existing kubus Node `kubus.capture/1` → `kubus.spatial/1` pipeline,
not a second archive format.

Build a dedicated field mode only after manual field sessions reveal the real
workflow.

## 9. Agent work packages

Keep PRs independently reviewable.

### Agent 1 — SEO/data auditor
Read-only analysis + scripts/report. No index-policy mutation.

### Agent 2 — public-entry architect
Backend renderer + shared presentation/bootstrap contract + takeover correctness.

### Agent 3 — native-link/platform entry
Android canonical App Links, assetlinks verification, cold/warm deep-link tests.

### Agent 4 — design-family primitives
App token/primitives migration plan and shared public entity visual primitives.
No app-wide screen rewrite.

### Agent 5 — globe capability spike
MapLibre capability adapter + platform matrix. No marker redesign yet.

### Agent 6 — marker LOD / map interaction
Port dot→pin→cover semantics, preserve cluster/spiderfy/selection behaviour.

### Agent 7 — UI/UX auditor
Screenshot/task-flow audit and classification only.

### Agents 8+ — bounded polish slices
Implement agreed audit slices by domain: shell/auth, discovery/map, entities,
community, creator/institution, settings, advanced/Web3.

### Later — QA/governance consolidation
Admin + DAO + provenance/moderation lifecycle after product polish.

## 10. Cross-agent stop conditions

An agent must stop and report rather than silently invent when:

- a repository reference branch moved materially from the documented baseline;
- a schema/data assumption cannot be verified;
- globe support requires replacing the map library rather than adapting it;
- signing fingerprints or platform association details are unavailable;
- a public entity field is private/ambiguous;
- a visual change would require carrying two competing design systems;
- a change would mass-deindex or recanonicalize large URL sets without a
  measured rollout.

## 11. Definition of success for the first programme slice

Before the broad app polish begins, we should have:

- evidence-based SEO/index audit;
- canonical public entity pages that already look like the product;
- seamless same-URL Flutter continuation;
- verified native canonical deep links on Android;
- no fake readiness fallback;
- a proven globe capability path;
- map marker LOD parity design/spec ready or implemented;
- a complete app audit backlog with evidence.

That creates the stable baseline for the larger UI/UX redesign.
