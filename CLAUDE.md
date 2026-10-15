# art.kubus Claude entry point

Read [AGENTS.md](AGENTS.md) and applicable nested instructions before editing.
The same permanent contracts govern every tool:

- [Design system](docs/DESIGN_SYSTEM.md), including PRODUCT hover and reduced motion.
- [Roadmap](docs/ROADMAP.md), organized by product domain and evidence gates.
- [Architecture](docs/ARCHITECTURE.md) and [Map system](docs/map-system.md).
- [Branching/deployment](docs/engineering/branching-and-deployment.md) and
  [Agent orchestration](docs/engineering/agent-orchestration.md).
- [Documentation index](docs/README.md) for security and domain-specific contracts.

Follow explicit user model/worker configuration. Claude-specific routing and lifecycle
are described in the orchestration guide; do not maintain a second design philosophy,
roadmap or release policy here. Fetch current heads, inspect existing worktrees and
preserve previous work. Keep task ownership exclusive and use bounded workers with
concise evidence-based handoffs. Production actions and PR merges require authorization;
implementation, tests, merge, deployment, owner acceptance and release are separate states.

## Official wordmark convention

Official wordmarks are art.***kubus***, ***kubus*** and ***kubus*** Node: only `kubus` is bold
italic; `art.` and capitalized `Node` are regular upright. Apply this beside the existing
graphical logo in headers and explicitly designed brand compositions. Running text stays plain
(art.kubus, kubus, kubus Node); technical identifiers retain exact spelling. Future frontend,
redesign and branding work must preserve the [canonical wordmark
specification](docs/DESIGN_SYSTEM.md#brand-identity--wordmark-typography), including genuine
font faces, responsive alignment and one combined accessible name.
