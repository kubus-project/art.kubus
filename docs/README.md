# Documentation

Start with [Getting started](GETTING_STARTED.md). The permanent active hierarchy is:

| Reference | Responsibility |
| --- | --- |
| [Roadmap](ROADMAP.md) | Product domains, status, dependencies and measurable completion |
| [Design system](DESIGN_SYSTEM.md) | Visual semantics, typography, surfaces, responsive composition and motion |
| [Architecture](ARCHITECTURE.md) | Flutter state, boot, routing, backend, identity and media boundaries |
| [Map system](map-system.md) | Detailed shared MapLibre, marker, cover and continuity contract |
| [Branching/deployment](engineering/branching-and-deployment.md) | Branches, exact-head CI, immutable artifacts, rollback and release gates |
| [Agent orchestration](engineering/agent-orchestration.md) | Coordinator, exclusive ownership, workers and evidence |

[AGENTS.md](../AGENTS.md) and [CLAUDE.md](../CLAUDE.md) are concise entry points to
these same contracts. Historical implementation notes are not additional design
requirements. Update existing documentation first; use issues and PRs for temporary
implementation tracking. New documents require an independent purpose; no new living
design versions or permanent implementation waves.

## Developer references

- [Local verification](LOCAL_VERIFICATION.md): tools, docs doctor and QA commands.
- [Features](FEATURES.md), [screen inventory](SCREENS.md), [screenshots](SCREENSHOTS.md).
- [Open platform boundary](OPEN_PLATFORM.md) and [licensing](licensing.md).
- [Backend setup](../backend/README.md): the private backend gitlink is independently
  validated; unprivileged frontend jobs need not materialize it.
- [Contribution](../CONTRIBUTING.md), [support](../SUPPORT.md), [security](../SECURITY.md)
  and the domain-specific [node threat model](node/threat-model.md).

## Independent domain contracts

- [Guest-first discovery](GUEST_FIRST_ENTRY.md) and [public entry](APP_NATIVE_PUBLIC_ENTRY.md).
- [SEO/public pages](seo-public-pages.md), [domain ownership](seo/domain-ownership.md)
  and [public access policy](public-entry-access-policy.md).
- [Places, routes and field evidence](PLACES_ROUTES_FIELD.md).
- [Institution/editorial lifecycle](INSTITUTION_EDITORIAL_LIFECYCLE.md).
- [Spatial delivery specification](SPATIAL_DELIVERY_ROADMAP.md): future derivative,
  streaming, preservation and access details; product status belongs in Roadmap.
- [Draft terms](legal/TERMS_OF_SERVICE.md) and [draft developer API terms](legal/DEVELOPER_API_TERMS.md).

## Historical records and research

Release records retain software versions and their historical statements. Dated
[organic discovery baseline](seo/organic-baseline-2026-10.md), benchmark artifacts,
QA tools and evidence directories describe their pinned revisions/environments.
Use their limitations when comparing results; do not infer current deployment,
physical-device acceptance or a permanent performance guarantee.

The former PRODUCT design/audit documents are consolidated into the permanent
contracts above. Their original research remains available in Git history; retained
[spatial evidence](evidence/product-v5-spatial/README.md) and existing capture/report
artifacts provide reproducibility without a parallel active design hierarchy.
