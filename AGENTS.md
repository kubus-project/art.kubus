# art.kubus agent entry point

Read this file, applicable nested `AGENTS.md`, and the relevant canonical contracts
before editing. Current explicit user requirements take precedence; verified source
and functioning behavior distinguish implementation reality from intended behavior.
Active security/data/engineering contracts come next, followed by the design system,
architecture and roadmap. Historical research explains decisions and is not authority.

## Canonical references

- [Architecture](docs/ARCHITECTURE.md): boot, state, API, identity and media boundaries.
- [Design system](docs/DESIGN_SYSTEM.md): type, color, composition, controls and motion.
- [Roadmap](docs/ROADMAP.md): product outcomes, dependencies and measurable completion.
- [Map system](docs/map-system.md): controller, renderer, selection, covers and continuity.
- [Branching and deployment](docs/engineering/branching-and-deployment.md): exact-SHA CI, deployment and release rules.
- [Agent orchestration](docs/engineering/agent-orchestration.md): bounded delegation and evidence.
- [Security policy](SECURITY.md): security reporting and repository security boundaries.
- [Documentation index](docs/README.md): setup and independent domain contracts.

## Work and release discipline

`master` is production-only; `dev` is integration. Never develop directly on either.
Fetch first, inspect worktrees/status/current branch, preserve unrelated changes,
and use an isolated topic branch from current `origin/dev`. Ordinary PRs target
`dev`; release and emergency hotfix PRs alone may target `master`. Reconcile release
ancestry back into `dev` according to the branching guide.

Name one coordinator and exclusive file owners. Independent writers use separate
worktrees. Delegate bounded tasks with start SHA, owned/excluded files, acceptance
criteria, tests and concrete output. Follow explicitly requested model/worker limits;
report unavailable configurations instead of silently substituting an expensive model.
Do not repeat completed investigations or restart idle workers without cause.

Merges, production deployment, protected approvals, secrets changes and release
publication require explicit authorization. Required checks and review findings must
pass on the exact head; never weaken CI to obtain green. Keep immutable artifacts,
verified hosts/paths, credentials protected, revision-aware smoke checks and rollback.
A merge is not deployment proof. Report implemented, tested, pushed, merged, deployed,
owner-accepted and released separately.

## Essential guardrails

- Providers own state. Create them in `lib/main.dart`; initialize centrally through
  `app_initializer.dart` / `app_bootstrap_service.dart`, idempotently. No widget-level
  provider initialization or refresh binding. Reuse shared models/services/widgets.
- Honor `AppConfig.isFeatureEnabled` and backend toggles; do not fake unavailable
  capabilities, success, rewards, balances or data. No placeholder/dead actions.
- Use shared theme, semantic color, typography, spacing and border tokens. Domain
  models contain no UI colors. Preserve desktop/mobile feature and permission parity.
- Use `BackendApiService`, `StorageConfig.resolveUrl(raw)`, `MediaUrlResolver`,
  `ArtworkMediaResolver`, safe avatar helpers and established AR services. No inline
  gateway construction. Keep local cache/fallback behavior; see Architecture.
- Map sources/layers go through `MapLayersManager`; camera/selection go through
  `KubusMapController`. Preserve style epochs, bounded cover work, selected markers,
  map session memory and gesture/engagement semantics. No parallel map architecture.
- Public entities retain canonical stable IDs, real renderer status codes and exact
  client continuation. Artwork authorship, contribution/ownership and provenance
  are separate. Preserve guest discovery and protected-action auth continuation.
- Backend public-entity mutations use `publicSyncService` and `ORBITDB_SYNC_MODE`.
  Schema changes update both `schema.sql` and `schema_complete.sql`. Private backend
  gitlink and production data are independent boundaries, not incidental cleanup.
- Guard `BuildContext` after awaits, dispose listeners/timers, gate polling by
  visibility and feature flags, and never return from `finally`. Web-only code uses
  conditional `*_web.dart` imports and `package:web`, not `dart:html`.
- **No legacy code paths:** do not introduce duplicate obsolete implementations or
  migration shims unless explicitly required. Explain substantial function-contract
  changes and caller/test/data follow-up in the handoff. Useful debug logs are guarded.

## Verification and documentation

Completion requires relevant regression tests, formatting and that `flutter analyze passes`,
plus exact-head required CI. Appearance changes require inspected responsive visual
proof; browser emulation, compilation, emulator and physical-device evidence differ.
PRODUCT hover changes update the Design system, primitives, widget tests and painted
Chromium/Firefox gate together. Verify reduced motion first; honor OS preferences.

Update an existing document before creating another. A new Markdown file needs an
independent purpose. Keep living documents unversioned, historical analysis separate,
entry points concise, and requirements in one canonical owner. Do not create permanent
implementation waves. Use issues/PRs for transient work; validate references and migrate
meaningful contract tests when documentation moves. Never discard security, compatibility
or measured engineering knowledge merely to reduce a file count.
