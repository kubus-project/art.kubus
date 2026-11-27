# Product roadmap

This is the living product roadmap. Organize work by product outcome, not design
versions or implementation waves. [Design system](DESIGN_SYSTEM.md) owns visual
contracts; [Architecture](ARCHITECTURE.md) and the linked domain specifications own
technical contracts. A roadmap item does not authorize a production change.

**Status vocabulary:** Implemented means a capability exists in the current source,
subject to feature flags, permissions and backend support. It does not imply every
deployment enables it or that device acceptance passed. In progress means an owned
implementation is being validated. Planned means a defined outcome awaits its
dependencies. Exploratory means evidence is required before committing to a design.
Release readiness belongs in PRs and engineering handoffs, not permanent completion
claims here. Revalidate status when the implementing PR merges.

**Release boundary:** v0.8.8 remains the active integration, original
227-requirement deep-research remediation, profile gallery/basic owner curation
(including persistent artwork and section ordering), and acceptance release.
**v0.9 begins only after v0.8.8 release verification and cleanup.** It extends
accepted foundations with [curator collaboration](https://github.com/kubus-project/art.kubus/issues/441),
[Web2.5 platform infrastructure, cultural imports, spatial, native distribution,
portfolios and MCP](https://github.com/kubus-project/art.kubus/issues/443).
The October 2026 implementation directive is historical planning input, not an
authority to defer unfinished v0.8.8 work or reuse outdated PR/migration states.

## Discovery and mapping

| Status | Outcome | Dependencies and completion criteria |
| --- | --- | --- |
| Implemented | Public MapLibre map, search, filters, nearby discovery, marker details, geographic LOD and supported web globe | Shared controller/manager/engine contracts in [Map system](map-system.md); enabled capabilities must preserve selection, real coordinates and flat-platform fallback. |
| In progress | Mobile controls follow Nearby Art; stable information control; contextual panel glass; marker/media continuity | [0.8.2 stabilization](https://github.com/kubus-project/art.kubus/pull/282) includes the integrated motion foundation. Remaining UI/performance work requires responsive captures, browser/native regression checks and measured cover/source latency. PR #282 alone does not complete stabilization. |
| Planned | Reliable routes and nearby exploration across cultural places | [Places and routes](PLACES_ROUTES_FIELD.md); verify route start/completion, location permissions, public place identities and return navigation with representative records. |
| Exploratory | Dedicated field experience | Several documented real field sessions must establish tasks, capture maturity and device/network constraints before a separate Field Mode is designed. |

## Artworks and creators

| Status | Outcome | Dependencies and completion criteria |
| --- | --- | --- |
| Implemented | Artwork records, media, visibility, creator drafts/publication, profiles and portfolio surfaces | Artwork publication is independent of optional digital editions; source references are in [Features](FEATURES.md). Backend publication policy controls public availability. |
| Implemented | Authored artworks and collections on walletless public profiles (Head of Flowers, v0.8.7.2) | Backend [#223](https://github.com/kubus-project/art.kubus-backend/pull/223) and Flutter [#432](https://github.com/kubus-project/art.kubus/pull/432)/[#436](https://github.com/kubus-project/art.kubus/pull/436) were merged and web/backend released. Damjan's six works were reported visible in EN/SL; browser-native and other-author sample acceptance remain separate. This fix is general, **not** a Damjan-specific hardcode, and is **not** outstanding v0.8.8 implementation. |
| In progress | Shared owner/visitor identity hierarchy and authored-cover framing on mobile | Preserve actions, permissions, source media and desktop composition; verify widths 320–430, long names, text scale, failed covers and crop fixtures. |
| Planned | Consistent authorship, attribution, contributor and provenance presentation | Revalidate renderer/client data together. Never infer artist from uploader. Completion requires attributed/unknown authorship and contributor/photographer cases with canonical-ID parity. |
| Planned | Creator task continuity across drafts, portfolio and public detail | Existing providers/services and real backend contracts; prove save/publish/edit/return journeys, permissions and error recovery without duplicate creation flows. |
| Planned | **v0.8.8 profile gallery, 2.5D showcase and basic curation** | **Complete before v0.8.8 release acceptance, not after release.** Prepare 2–3 genuinely distinct visual directions using permitted real works (including Damjan's six), get owner selection, then implement reusable artist/exhibition/institution presentation primitives. Authorized owners/editors can arrange artworks and sections with persisted order, previews, filters and version/concurrency/permission checks. Verify light/dark, desktop/phone, EN/SL, reduced motion, accessibility, provenance and media holds. This is ordinary profile/exhibition curation; dedicated curator accounts, independent pop-ups and institutional multi-editor collaboration remain v0.9. |

## Community

| Status | Outcome | Dependencies and completion criteria |
| --- | --- | --- |
| Implemented | Profiles, follows, posts, comments, messaging, notifications, groups and enabled participation records | Existing community screens and backend services; deployment availability remains feature-dependent. |
| Planned | Account and protected-action continuity | Public discovery remains guest-first. Authentication begins at a protected action and returns to the intended action. Validate account-only and wallet-connected identities against actual service contracts. |
| Planned | Reliable media, group and conversation lifecycle | Prove feed/detail/fullscreen return, socket authorization, correct participant identity and media cleanup on navigation; do not invent unsupported social or reward actions. |
| Exploratory | Community discovery and participation improvements | Use observed task failures and real community feedback; define measurable completion before extending features. |

## Institutions

| Status | Outcome | Dependencies and completion criteria |
| --- | --- | --- |
| Implemented | Institution, exhibition and event surfaces, linked artworks and enabled attendance tools | Account roles, feature flags and backend support govern availability. |
| Planned | Coherent public institution versus operational workspace experience | [Institution/editorial lifecycle](INSTITUTION_EDITORIAL_LIFECYCLE.md); verify public discovery, authorized editing, preview, attribution and moderation handoffs. |
| Planned | Cultural datasets, partnerships and existing editorial integrations | Evolve existing backend/admin systems rather than introduce a third CMS. Require source ownership, freshness, publication permissions and representative real-data acceptance. |
| Exploratory | Municipal/institutional pilots | Establish qualified enquiries, useful product journeys and operational capacity; avoid promised partnerships or completion dates without agreements. |

## Curatorial collaboration and virtual exhibitions

| Status | Outcome | Dependencies and completion criteria |
| --- | --- | --- |
| Planned | v0.9 curator professional identities and affiliations | [Curatorial infrastructure scope](https://github.com/kubus-project/art.kubus/issues/441); one existing account can be artist, curator and authorized institution collaborator. Define verified roles, invitations, revocation, visibility and auditability without a new login system. Depends on accepted v0.8.8 account/profile contracts. |
| Planned | v0.9 independent virtual pop-ups and institution-linked exhibitions | Curators can create standalone exhibition drafts and, separately, propose or accept institutional collaboration. Support independent, institutional and multi-curator models without transferring artwork ownership or publication/reproduction rights. Require drafts, scoped review/publication, withdrawal, attribution, EN/SL and canonical public behavior. |
| Planned | v0.9 collaborative exhibition curation and durable arrangements | Reuse the v0.8.8 gallery/2.5D composition, filters, ordering and accessible fallbacks rather than build a second gallery or CMS. Add scoped multi-editor permissions, versioned arrangements, concurrent edit handling, editorial history, proposal/approval flows, backend publication/outbox safety, and Admin integration. Mockups and written data/authz design require owner approval before implementation. |

## Governance and infrastructure

| Status | Outcome | Dependencies and completion criteria |
| --- | --- | --- |
| Implemented | Feature-gated wallet, digital-edition and governance surfaces; optional public availability infrastructure | [Open platform](OPEN_PLATFORM.md), [Features](FEATURES.md) and actual backend/runtime capabilities define the boundary. Content addressing does not make private account data public or decentralized. |
| Planned | Contribution, provenance, verification, dispute and governance lifecycle | Preserve distinct admin moderation and community governance responsibilities; prove role/permission transitions and real operational ownership before expanding DAO UX. |
| Planned | Reliable decentralized synchronization and distributed-node availability | Backend `publicSyncService`, publication policy, IPFS/OrbitDB and runtime contracts; require integrity, visibility, failure recovery and bounded retention evidence. |
| Exploratory | Settlement and economic capabilities | A displayed contribution/pending KUB8 record is not a payout. Implement only with an explicit provider, security and settlement contract; no guaranteed return claims. |

## Platform quality

| Status | Outcome | Dependencies and completion criteria |
| --- | --- | --- |
| In progress | **v0.8.8 deep-review completion, integration and release stabilization** | Finish remaining original 227 requirements and nine recorded amendments with verified acceptance, not just reconciliation. Track actual implemented/tested/reviewed/merged/deployed/production-accepted rungs; close walletless community E2E, session/cookie/security, media preview/Admin/client caching, publication-sync recovery, spatial/analytics/legal/HA gates and any further original programme items. Do not treat successful draft CI or a historical 0.8.7.2 fix as full v0.8.8 acceptance. Release cleanup and approved operational handoff precede 0.9. |
| Implemented | Shared themes/tokens, EN/SL localization, provider-first initialization and feature gating | Preserve these foundations; implementation presence does not establish complete accessibility or localization coverage. |
| In progress | **v0.8.8 Top Artists visibility and truthful identity** | Resolve [AMEND-TOPART-001] homepage rail production regression: eligible artists returned by the public artist directory must actually paint and link to the correct canonical profile, with real avatar/name and reliable loading/error/retry. The live list reportedly contained Damjan even while the rail did not show him; do not misdiagnose this as absent artist approval. Test Chromium/Firefox, 320–430px and desktop, EN/SL, anonymous/authorized users. Verify a second eligible artist, without ranking hacks or artist-specific code. |
| Planned | **v0.8.8 canonical artist profile first-frame parity** | The public semantic profile frame and hydrated Flutter profile must be visually continuous, use the correct real avatar/cover and artwork composition, and never show the unwanted visible eyebrow/eyebrow label. Preserve factual semantic HTML, canonical URLs, accessibility and no-JS first-frame value; do not delete SSR or replace it with a generic SEO bridge. Measure real rendered transitions and prevent duplicate-looking inconsistent profile layouts. |
| In progress | **v0.8.8 marker recovery and distributed publication consistency** | Historical pilot restoration is distinct from the later owner-authorized bounded wider recovery. Verify actual approved/restored/rejected/review/excluded counts against current production journal; never infer success from a running hourly loop. Independently verify PostgreSQL/public API eligibility, IPFS/OrbitDB store availability, durable outbox synced generation and peer visibility. Kubo pubsub and backend auto-init reportedly recovered, but mirror publication later still failed; no destructive store rebuild without reviewed recovery/rollback and explicit approval. |

| Planned | Accessibility, responsive and navigation regression coverage | Verify light/dark, EN/SL, guest/signed-in, owner/visitor, text scale, reduced motion, portrait/landscape, deep links/refresh and system/browser Back. Browser emulation is distinct from physical-device evidence. |
| Planned | Measured rendering/media reliability | Measure first usable map, first marker paint, cover latency, p50/p95/p99 frames, misses, fetch/decode/cache behavior, source writes and memory under documented cold/warm conditions. Compare identical fixtures and preserve selection/cache bounds. |
| Planned | Security and deployment reliability backlog | [Security policy](../SECURITY.md), independent domain security contracts and [branch/deployment guide](engineering/branching-and-deployment.md); retain exact-SHA artifacts, rollback and protected credentials. |

## Adoption and sustainability

| Status | Outcome | Dependencies and completion criteria |
| --- | --- | --- |
| Implemented | Public entity routes and semantic renderer/client continuation infrastructure | [Public entry](APP_NATIVE_PUBLIC_ENTRY.md), [SEO pages](seo-public-pages.md) and [domain ownership](seo/domain-ownership.md); real status codes and canonical stable IDs remain required. |
| Planned | Evidence-led public discovery and SEO quality | [Organic baseline](seo/organic-baseline-2026-10.md); measure indexed → visible → clicked → useful interaction by entity/locale/source/quality. Index-policy or canonical changes require reviewed evidence. |
| Planned | Useful onboarding and participation funnels | Track intended action continuation, artwork open, save/follow/contribution and qualified enquiries with consent/referrer boundaries. Registration is a downstream signal rather than the only outcome. |
| Exploratory | Sustainable funding and revenue | Validate service demand, cost and provider/financial contracts before shipping economic promises. Separate website visitor analytics from runtime fleet telemetry. |

## Research and longer-term exploration

| Status | Outcome | Dependencies and completion criteria |
| --- | --- | --- |
| Implemented | Optional mobile AR and current spatial capture/library/viewer integration | Feature/media/runtime dependent; compilation alone does not prove AR device behavior. |
| Planned | Progressive spatial viewing and preservation | [Spatial delivery specification](SPATIAL_DELIVERY_ROADMAP.md) retains variant/streaming/retention details. Real field assets must prove meaningful first frame, memory, transferred bytes, Range/ETag, scoped access, integrity and fallback. |
| Exploratory | XR, spatial archives and cultural infrastructure interoperability | Require realistic device/GPU trials, publication/privacy contracts and a clear user task. Do not label reconstruction output as streamed LOD without actual derivatives. |
| Exploratory | Experimental decentralized capabilities | Evaluate capacity, security, operator policy and interoperability before architecture commitments. Preserve private/unpublished inputs and canonical archives. |

## v0.9 programme — after v0.8.8 acceptance

The owner-supplied October 18 master engineering and visual implementation
directive is reconciled in [the v0.9 technical programme](https://github.com/kubus-project/art.kubus/issues/443),
with the distinct [curatorial programme](https://github.com/kubus-project/art.kubus/issues/441).
This is **planned scope, not implemented or authorized work**. Its older PR
references and implementation commands are historical; current evidence and
repository contracts take precedence. Reuse everything accepted in v0.8.8
rather than reopening the remediation programme.

| Status | Outcome | Dependencies and completion criteria |
| --- | --- | --- |
| Planned | Wallet-optional cultural identity and mature real-time participation | One account principal across web, native and optional wallet; correct artist/contributor/rights distinctions, revocable creator and institution roles, account-bound messaging and isolation. Build on existing v0.8.8 identity/community implementations and prove any additional 0.9 deltas with real E2E. |
| Planned | Store-safe native app capability separation | Full cultural experience without a wallet; restricted financial routes unreachable through UI, router, deep links, notifications or remotely enabled flags. Reuse Flutter capability gates and preserve common account/content IDs between native and web. |
| Planned | Canonical web-to-native entry and distribution readiness | Same-route semantic SSR→Flutter continuation, accurate EN/SL public URLs, 200/404/503, factual metadata and private bootstrap isolation; verified Android App Links and iOS Universal Links; native signing/store submissions remain owner-gated. Retain any verified v0.8.8 contract rather than rebuilding it. |
| Planned | Progressive Spatial capture-to-archive integration | Existing kubus Node/backend/Flutter pipeline; real SPZ previews and RAD/runtime derivatives when supported; manifests, private capture protection, capability expiry, retry/recovery, retention, Range/ETag, renderer fallback, licensing and representative actual hardware tests. No fake streamed LOD. |
| Planned | Verified institution programme and event persistence | Public institution identity separate from authenticated workspace; verified representatives, revocation and distinct organizer/venue/rights authority; accurate event data and supported relationships, not inferred institution-event ownership. |
| Planned | Secure cultural import pipeline | Reuse backend/operations infrastructure for staged source→extract→normalize→review→authorized publication; bounded CSV, ICS (recurrence/timezones/cancellation), approved structured URLs, provenance and idempotent reimport. Require SSRF/parser/tenant isolation tests and no parallel CMS. |
| Planned | Independent nonspatial creator portfolio projects | Account-owned draft/published projects with cover, media, collaborators, attribution/rights and optional public-art relationships; reviewed PDFs/media and bounded external embeds, no mandatory coordinates or fabricated markers. Integrate with the **v0.8.8 gallery** and Artist Studio. |
| Planned | Curator identity, independent pop-up exhibitions and institutional collaboration | [Detailed curatorial scope](https://github.com/kubus-project/art.kubus/issues/441): one account may be artist/curator/institution collaborator; proposals/invitations, scoped multi-editor permissions, independently published virtual exhibitions, revision/versioned layouts and copyright/withdrawal safeguards. Reuse 0.8.8 2.5D gallery/curation; visual and technical designs require owner selection. |
| Planned | Public read-only art discovery MCP | [Technical programme](https://github.com/kubus-project/art.kubus/issues/443); bounded canonical public discovery tools over existing domain services, schema validation, visibility and moderation fences, EN/SL, rate limits, prompt-injection resilience, current official MCP protocol, interoperability checks and immediate disable/rollback. No direct public DB credential or writes. |
| Exploratory | Protected MCP and local operator adapters | Separately gated OAuth-protected personal reads (PKCE, scopes, audience, revocation and per-record auth), private aggregate-only Admin MCP, local-only read-only kubus Node MCP. Validate handler side effects; keep disabled unless their trust boundaries are proven. |
| Planned | Continuous security, privacy and operational reliability | Cross-repository negative tests for authorization, sockets, uploads/imports, Spatial/IPFS, OAuth/MCP, public SSR and native feature exclusions; migration/schema parity, controlled retention, exact-head CI, isolation and rollback. Owner gates for production migration, deployment and external distribution. |
| Planned | Complete visual implementation and acceptance | Separate technical integration followed by real cross-screen design/UX implementation: map, discovery, profile/portfolio, community, Artist Studio, Institution Hub, exhibitions, SSR, native and Spatial. Enforce existing Sofia Sans/Space Mono tokens, actual mobile/desktop, EN/SL, light/dark, text scaling, reduced motion, accessibility, meaningful painted screenshots and measured performance. |

**0.9 beta release cutline:** a coherent working Web2.5 cultural platform with
the required v0.9 technical and curator outcomes, public read-only art MCP,
store-safe native engineering profile, real E2E/security and visual QA. Optional
authenticated/Admin/Node MCP, hardware-dependent Spatial/AR and externally
approved app-store publication may be separately gated or disabled. Major
tokenomics, KUB8 settlement, marketplace/DAO expansion, autonomous moderation,
new consensus, unrestricted MCP writes, private Spatial Workspace and Node
operator/GPU-network expansions remain **0.10+ or separately approved**.

**Execution:** first verify v0.8.8 release completion, then owner-approved
visual/architecture design and small backend-first PRs. Technical integration
precedes a dedicated visual implementation pass. Distinguish implemented,
tested, reviewed, merged, deployed, production verified and accepted. No
protected merge, production migration/deployment or store submission is
authorized by roadmap status.

## Maintaining this roadmap

Update the domain row when implementation or evidence changes, linking the relevant
issue/PR instead of copying every issue. Record dependencies and measurable exit
criteria, not speculative dates. Current source and reviewed requirements outrank
historical implementation notes. Short-lived work ownership, test logs and release
checkpoints belong in issues/PRs and engineering evidence.
