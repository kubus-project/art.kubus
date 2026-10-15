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
