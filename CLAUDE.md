# art.kubus — agent entrypoint

Read `AGENTS.md` and nested instructions before editing. The **single canonical master roadmap** is `docs/PRODUCT_UX_SEO_PROGRAM.md`; `docs/AGENT_EXECUTION_PLAN.md` supplies the bounded wave package and stop conditions. Read both before SEO, public entry, map, broad UI, institution, editorial, admin/DAO or spatial-delivery work. This documentation pass is Wave 0; it does not implement the product redesign.

## Source of truth

1. Current explicit user instruction and fetched repository/source state.
2. `docs/PRODUCT_UX_SEO_PROGRAM.md` — dependencies and ownership; `docs/AGENT_EXECUTION_PLAN.md` — scoped work and acceptance.
3. `docs/DESIGN_SYSTEM_V2.md` — final family v5 application; public websites' mirrored `docs/WEB-FAMILY.md` v5 is the approved type/visual reference.
4. `docs/APP_NATIVE_PUBLIC_ENTRY.md`, `docs/seo-public-pages.md`, `docs/seo/domain-ownership.md`, `docs/public-entry-access-policy.md` — entity, renderer, URL and auth boundaries.
5. `docs/engineering/branching-and-deployment.md` — branch/CI/release rules.

Re-fetch before implementation: branch heads, open PRs and release state change daily, so this file records none. The WORLD (`art.kubus.site`) and TIME (`kubus.site`) redesigns are merged and are the visual references; the SHAs of the September 2026 foundation branches (`a1-foundation`, `k1-foundation`) are historical only. **Old public-site master visuals are not references.**

## Family and PRODUCT

TIME (`kubus.site`), WORLD (`art.kubus.site`), PRODUCT (`app.kubus.site`/native art.kubus) and INFRASTRUCTURE (`node.kubus.site` public website; `kubus-node` runtime) are siblings. PRODUCT uses platform-native app bars, navigation, rails, safe areas, sheets, forms and map chrome. It does not copy WORLD's right-two-thirds editorial layout. Sofia Sans carries content and major interface text. Space Mono is an approved **structural/system register** for current family identity/controls/notions/ordinals/selected metadata and exact machine values; it is neither machine-only nor a blanket uppercase style. Brand prose remains lowercase.

WORLD's proven MapLibre globe, explicit camera ownership, continuous drag/pinch/scroll, canonical markers, dot→pin→cover LOD, bounded covers, selection continuity and in-place theme switching are behaviour references. Flutter's existing `KubusMapController`, `MapLayersManager` and `KubusMapMarkerSyncEngine` remain the technical owners. Test globe capability before implementation; never create a parallel map.

## Public ownership and sequence

`kubus.site` owns research/history. `art.kubus.site` owns acquisition, geography, guides, city/editorial and participation explanation. `app.kubus.site` owns canonical public entities and product interactions. `node.kubus.site` visitors are not `kubus-node` fleet telemetry.

Start with the **read-only** SEO/data audit. Keep semantic entity HTML, metadata, JSON-LD, no-JS and true 404/503, but make it the first PRODUCT frame. Current backend HTML is a generic Inter/header/card/CTA renderer; current web takeover has a synthetic 1500 ms readiness event; current artwork creator query can prefer uploader profile to artist. These are documented implementation defects. Exact entity screen readiness, separated authorship/contribution/provenance, same canonical URL and later verified Android links are target work, not completed facts.

Audit every task/screen before broad polish. Classify KEEP/REFINE/REDESIGN/MERGE/REMOVE; do not polish REMOVE. Institution model/workspace, existing editorial CMS, participation funnels, admin/DAO lifecycle, Ljubljana field sessions and spatial derivative delivery follow the roadmap gates. Do not mass-deindex, change canonical policy, mutate production data or build a third CMS as incidental work.

Agents must name the current state, files owned and excluded, exact data contract, tests, screenshot evidence and a stop condition before changing code. Do not merge or deploy without authorization.

## Multi-agent orchestration and cost discipline

Canonical detail: `docs/engineering/agent-orchestration.md`. The short form for Claude Code:

- **One lead coordinator** (Sonnet by default) owns design, security-sensitive and SQL decisions, cross-repository integration, merges, deployments and the final acceptance. Specialists never merge, deploy or change HA state.
- **Delegate bounded, independent work to Haiku 5.5** (`model: haiku`): focused searches, diff reviews, targeted tests, CI/log summaries, screenshot inspection, read-only diagnostics. Confirm the model a worker resolved to and report deviations. Do not escalate to the largest model automatically.
- **At most three concurrent workers** normally; spawn only for genuinely independent work. If a task is one or two tool calls, do it directly.
- **Explicit ownership:** before delegating, state role, model, repository, starting SHA, read-only or writable, exact files owned, tests and completion condition. Writers get exclusive files and separate worktrees; never two writers in one worktree.
- **Lifecycle:** five minutes idle is a checkpoint, not an expiry. Resume a worker (`SendMessage`) when its context is useful, otherwise start a fresh one with a short checkpoint. No keepalives; do not kill running builds or tests on an idle-time assumption; retire finished workers.
- **Context and tests:** narrow reads (`rg`, `git diff`, line ranges), concise worker handoffs with evidence on disk, progressive tests (focused, module, analyzer, CI, browser QA), reuse of immutable evidence for an unchanged SHA. Never skip a required final gate.
- **Preflight every session:** `git fetch`, `git worktree list`, open PR heads and threads, `ListAgents` for peers on the same branch. Brief SHAs go stale; the remote is the truth.
- **Truthful status:** report implemented / merged / deployed / tested / owner-accepted / released separately; never claim the last two on inference.

