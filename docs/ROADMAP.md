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
| In progress | Shared owner/visitor identity hierarchy and authored-cover framing on mobile | Preserve actions, permissions, source media and desktop composition; verify widths 320–430, long names, text scale, failed covers and crop fixtures. |
| Planned | Consistent authorship, attribution, contributor and provenance presentation | Revalidate renderer/client data together. Never infer artist from uploader. Completion requires attributed/unknown authorship and contributor/photographer cases with canonical-ID parity. |
| Planned | Creator task continuity across drafts, portfolio and public detail | Existing providers/services and real backend contracts; prove save/publish/edit/return journeys, permissions and error recovery without duplicate creation flows. |

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
| In progress | Stable 0.8.2 candidate: mobile composition, Analytics return navigation, map/media performance and documentation consolidation | Reviewable UI, performance and docs PRs; full required exact-head CI; inspected responsive evidence; no P0 blocker. Merge, deployment, owner acceptance and release remain separate gates. |
| Implemented | Shared themes/tokens, EN/SL localization, provider-first initialization and feature gating | Preserve these foundations; implementation presence does not establish complete accessibility or localization coverage. |
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

## Maintaining this roadmap

Update the domain row when implementation or evidence changes, linking the relevant
issue/PR instead of copying every issue. Record dependencies and measurable exit
criteria, not speculative dates. Current source and reviewed requirements outrank
historical implementation notes. Short-lived work ownership, test logs and release
checkpoints belong in issues/PRs and engineering evidence.
