# Agent execution plan — SEO → public entry → WORLD map → app audit → deep polish

Status: execution plan, not implementation.
Last updated: 2026-09-21.

This file turns `PRODUCT_UX_SEO_PROGRAM.md` into bounded agent assignments. The
goal is to let several agents work without duplicating architecture or
prematurely redesigning the whole application.

## Ground rules for every agent

- Read root `CLAUDE.md`, `AGENTS.md` and the relevant nested instructions.
- Start from the repository's documented integration/base branch on a topic
  branch. Never commit directly to protected/integration branches.
- Search/reuse before creating a second service, model, map renderer or design
  primitive.
- Do not merge/deploy.
- Do not weaken CI to make a branch green.
- Visual work requires screenshot/device evidence, not only unit tests.
- Preserve EN/SL and real public/private/error states.
- "Looks coherent" is not permission to duplicate data or URL ownership.
- A public entity has one canonical owner: `app.kubus.site`.
- A marker colour/state carries data semantics; do not recolour it for visual
  harmony.
- Do not mass-deindex/recanonicalize based on intuition.
- If a prerequisite cannot be verified, stop that slice and record the blocker.

## Wave 0 — documentation baseline

**Status: prepared in the 2026-09-21 documentation branches.**

Outputs:

- current Claude/agent entrypoints;
- Design System v2 direction;
- app-native public-entry contract;
- updated domain/public-page decisions;
- updated WORLD map + marker LOD docs;
- synchronized family contract on active redesign branches;
- backend public renderer contract.

No product code belongs in Wave 0.

---

## Wave 1 — evidence and public-entry architecture

### Agent A — SEO + public-data auditor

**Repos:** `art.kubus-backend`, `art.kubus`; optional external GSC export.

**Mode:** read-only analysis plus non-destructive audit scripts/tests.

**Do:**

1. enumerate public/index-eligible counts by type + locale;
2. distinguish indexed corpus from URLs receiving impressions;
3. quantify artwork/marker duplicate ownership;
4. profile title/description/artist/image/location/provenance/localization
   completeness;
5. surface ingestion/source/quality-score distribution where available;
6. join Search Console URL performance to entity quality where identifiers can
   be mapped safely;
7. list high-ranking zero-click pages and likely snippet/content causes;
8. audit hreflang where translated content is fallback-identical;
9. inventory canonical/alias/redirect behaviour;
10. output proposed index-quality tiers **without applying them**.

**Deliverable:** versioned report + reproducible scripts/queries + recommended
rollout gates.

**Must not:** mutate DB, mass-noindex, rewrite canonicals, delete sitemap URLs.

**Exit:** enough evidence to choose indexing thresholds and identify duplicate
entity ownership.

---

### Agent B — canonical public-entry architect

**Repos:** `art.kubus-backend` + `art.kubus`.

**Dependencies:** can begin structural work in parallel with Agent A; any index
eligibility change waits for Agent A.

**Backend scope:**

- refactor normalized entity presentation into an explicit reusable contract;
- redesign semantic entity output as PRODUCT first frame;
- remove marketing-site header/footer/hero-card hierarchy from entity pages;
- preserve metadata, JSON-LD, no-JS, 404/503, privacy boundaries;
- add safe public bootstrap payload sourced from the same normalized entity
  presentation;
- add parity tests so HTML/meta/bootstrap cannot silently disagree.

**Flutter/web scope:**

- parse/validate bootstrap payload only when canonical type/id/path match;
- seed initial public entity state to avoid duplicate first fetch where safe;
- revalidate without flashing a second layout;
- remove the synthetic 1500 ms ready event in
  `web/public_flutter_takeover.js`;
- exact entity screen is the only takeover readiness authority;
- keep the exact localized canonical URL/history entry;
- make failed/slow Flutter leave semantic product frame usable.

**Visual target:**

- media-first/detail-first;
- same hierarchy as app entity detail;
- current family type/structure;
- no perceptible SEO-page → app redesign jump.

**Evidence:**

- raw no-JS HTML;
- slow JS;
- failed bundle;
- Chromium/Firefox;
- phone/desktop;
- EN/SL;
- missing/private entities.

**Exit:** canonical artwork/profile/institution/etc. is useful and coherent
before JS and becomes Flutter on the same URL without a visible architecture
jump.

---

### Agent C — canonical native-link owner

**Repo:** `art.kubus`; deployment/static association file may span web deploy
configuration.

**Can run in parallel with Agent B.**

**Do:**

- add actual localized canonical path families to Android verified App Links;
- version/serve `/.well-known/assetlinks.json` in the correct deployment
  owner;
- use real release/debug signing fingerprints as appropriate, never invented
  values;
- verify OS association;
- test cold start, warm start and running-app navigation to exact entity;
- ensure locale/type/id survives;
- preserve compact aliases only as compatibility links;
- document iOS Associated Domains/AASA requirements and implement only if the
  current iOS signing/deployment target is available.

**Exit:** a canonical search-result URL opens the installed Android app directly
and otherwise remains a normal canonical web URL.

---

## Wave 2 — design-family PRODUCT primitives

### Agent D — PRODUCT design-system migration foundation

**Repo:** `art.kubus`.

**Dependencies:** use Agent B entity hierarchy and current reference branches.

**Do not perform an app-wide restyle.**

**Do:**

- inventory existing Flutter tokens/primitives against
  `docs/DESIGN_SYSTEM_V2.md`;
- establish semantic structural roles needed by PRODUCT;
- plan/implement central typography migration path toward Sofia Sans + approved
  technical mono without per-screen font literals;
- identify which existing glass primitives remain legitimate overlapping
  product chrome and which are legacy base-surface styling;
- implement shared entity-detail structural primitives needed by Agent B and
  later polish;
- add lint/tests against new hard-coded design drift where practical.

**Exit:** new PRODUCT surfaces can be built from central primitives without
copying legacy glass/gradient patterns.

---

## Wave 3 — WORLD map convergence

### Agent E — globe capability spike

**Repo:** `art.kubus`.

**Dependency:** none on the full UI audit; depends on existing MapLibre
architecture only.

**Question to answer before feature implementation:**

Can the current Flutter `maplibre_gl ^0.26.2` stack support the required globe
projection/camera behaviour consistently on web + Android (+ iOS target when
available)?

**Do:**

- inspect plugin/native/web APIs;
- build a narrow capability adapter/spike;
- test projection/style survival across theme/style reload;
- test gestures/camera;
- record platform gaps;
- benchmark enough to reject obviously unsafe paths.

**Must not:** replace MapLibre or build a parallel map screen merely because one
platform API is inconvenient.

**Decision outputs:**

- direct shared plugin path;
- or renderer capability abstraction with minimal platform-specific bridge;
- or a clearly documented blocker requiring a separate architectural decision.

**Exit:** proven implementation route before visual globe work.

---

### Agent F — globe + marker LOD implementation

**Repo:** `art.kubus`.

**Dependency:** Agent E accepted path.

**Use existing:**

- `KubusMapController`;
- `MapLayersManager`;
- marker sync/render engine;
- cluster/same-coordinate/spiderfy logic;
- existing map filter/search/nearby systems.

**Port contract from**
`art.kubus.site@redesign/a1-foundation`, not code architecture:

- WORLD globe/regional framing;
- restrained theme/time optical treatment;
- dot → canonical pin → cover-image LOD;
- selected record persistence;
- bounded heavy close markers;
- canonical marker subject/tier/state identity;
- no marker recreation tied to camera motion.

**Also resolve UX contradictions:**

- viewport vs travel/radius filtering;
- quick filters;
- search/place framing;
- cluster activation;
- locale default world framing;
- stale marker/cache refresh.

**Exit:** one coherent map system on web/native with measured fallbacks and no
duplicated 2D/globe implementation.

---

## Wave 4 — complete app UI/UX audit

### Agent G — evidence-driven UI/UX auditor

**Repo:** `art.kubus`.
**Mode:** audit first; no broad redesign commits.

**Audit dimensions:**

- task/purpose;
- IA/navigation/back;
- primary action;
- guest/auth boundary;
- responsive/platform appropriateness;
- loading/empty/error/offline;
- copy/localization;
- accessibility;
- performance;
- duplicate screens/components/domain concepts.

**Required flow evidence:**

- guest first use;
- search/place/entity;
- map/entity/related;
- canonical external entry;
- auth/onboarding/gated-action return;
- save/follow/comment;
- contribute/correct/claim;
- artist studio;
- institution hub;
- events/exhibitions;
- community/messages;
- notifications;
- settings/privacy/analytics;
- advanced web/Web3;
- DAO/governance;
- spatial view/capture where enabled.

**Classify every major screen:**

`KEEP | REFINE | REDESIGN | MERGE | REMOVE`

Severity:

`P0 broken | P1 task friction | P2 design debt | P3 polish`

**Deliverable:** screen inventory, flow map, screenshots, prioritized backlog
and duplication map.

**Exit:** no large polish agent needs to guess what survives.

---

## Wave 5 — deep polish, split by domain

Start only from Agent G's accepted backlog. Use separate PRs/agents.

### Agent H1 — application shell + auth/onboarding

- mobile/desktop navigation;
- gated-action continuity;
- register/sign-in/onboarding sequence;
- guest vs account actions;
- settings discoverability;
- deep-link return routes.

### Agent H2 — discovery + search + entity details

- search;
- city/place navigation;
- artwork/profile/artist details;
- public/native entity parity;
- related content;
- saves/follows/shares.

### Agent H3 — community + messaging + notifications

- hierarchy/density;
- feed/detail/comment flows;
- messaging navigation;
- notification destinations;
- remove redundant interaction patterns.

### Agent H4 — creator + artist studio

- artwork/collection/exhibition creation;
- claim/correction;
- replace/refine legacy CreatorKit where audit says so;
- do not preserve wizard/stepper structure merely because it exists.

### Agent H5 — institutions

- normalize public profile vs authenticated workspace;
- team/programme/artworks/events/exhibitions/routes;
- verification/claim;
- compact useful analytics;
- institution role flows.

### Agent H6 — settings + advanced web/Web3

- privacy/analytics;
- advanced wallet/marketplace/provenance surfaces on web;
- make optional infrastructure secondary to art discovery;
- native-store restrictions remain respected.

Each slice requires mobile + desktop/native evidence appropriate to the surface.

---

## Wave 6 — editorial + institutional funnel consolidation

### Agent I — editorial pipeline auditor/implementer

**Repos:** backend, admin, art.kubus.site, kubus.site as necessary.

First audit the existing article and city-highlight pipelines. Then improve the
existing system rather than adding a third CMS.

Target:

- draft/review/fact-source/translation/approval/schedule/publish/review-due
  semantics (implemented only where schema/workflow is agreed);
- richer structured blocks;
- entity/place relations;
- production preview;
- source/image-rights/last-reviewed visibility;
- stale-content review.

### Agent J — participation/pilot funnel

Separate:

1. free/basic institution claim/create;
2. supported paid institutional pilot;
3. municipality/API/strategic integration.

Audit/adjust copy and CTAs on art.kubus.site and in PRODUCT surfaces. Preserve
existing enquiry attribution plumbing.

---

## Wave 7 — coherent QA/moderation/governance

Only after the deep product polish.

### Agent K — cultural data lifecycle

**Repos:** backend + admin + app.

Map one lifecycle for:

- contribution;
- correction;
- source/provenance;
- moderation;
- institution verification;
- dispute/review;
- publication state.

Remove contradictory admin-vs-app moderation concepts.

### Agent L — DAO/governance UX

Use the lifecycle above to decide which decisions are administrative, community
review, or actual governance. Redesign DAO proposal/review/vote surfaces only
after that boundary is explicit.

Do not use the DAO as a generic replacement for operational moderation.

---

## Wave 8 — Ljubljana field programme

Separate operational/research work package after core product stability.

- establish field protocol;
- manually verify/document records;
- selectively capture spatial scenes;
- connect existing `kubus.capture/1` → `kubus.spatial/1` objects to cultural
  entities;
- only then design Field Mode from repeated real workflow pain.

The field programme should improve the same records used by map, SEO, routes,
editorial and institution outreach.

## Suggested parallelism

Safe early parallel work:

```
Wave 1:
A SEO/data audit
B public-entry architecture ─┐
C native links              ├─ in parallel with coordination
D design primitives         ┘

Wave 3:
E globe capability spike can overlap late B/C/D

After E:
F globe/LOD

After B/F stable enough for truthful screenshots:
G full UI/UX audit

After G:
H1..H6 bounded polish slices can run partly in parallel

After polish:
I/J editorial + institutional funnel
K/L QA/governance
Ljubljana field programme continues operationally
```

Do not run multiple agents on the same foundational files without explicit file
ownership (especially `design_tokens.dart`, app routing, map controller/layer
manager, SEO presentation service and Android manifest).

## Review gates

### Gate 1 — before index changes
Agent A report reviewed.

### Gate 2 — before broad UI polish
Canonical public entry + native link architecture stable; Agent G audit
accepted.

### Gate 3 — before parallel polish
Token/primitives contract stable and file ownership assigned.

### Gate 4 — before admin/DAO consolidation
Major end-user flows no longer undergoing structural redesign.

### Gate 5 — before field-mode engineering
Several real Ljubljana field sessions completed and workflow notes available.
