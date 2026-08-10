# Web3 desktop completion — 0.7.4

## Scope

- Canonical account, wallet, signer, governance, and Digital Editions capabilities.
- Capability-safe mobile and desktop governance.
- Native desktop Governance workspace.
- Canonical desktop Digital Editions discovery and owner management.
- Consolidated desktop Wallet with canonical Owned Editions inventory.
- Backend DAO review-decision authorization.

## Architecture decisions

- `Web3CapabilityResolver` is the single UI capability source. It derives from hydrated profile state, `WalletAuthoritySnapshot`, account role, feature flags, signer readiness, and entity ownership/listing state.
- Widgets hide unavailable privileged actions; `WalletActionGuard`, provider checks, signed envelopes, and backend authorization remain mandatory mutation boundaries.
- `GovernanceWorkspace` is reusable mobile/desktop composition. Desktop no longer embeds the mobile hub beside a second rail.
- Digital Editions use `CollectiblesProvider.marketplaceEntries`; Wallet inventory uses `WalletEditionInventory` over the same provider-owned records.
- Acquisition and mint capabilities fail closed because no production-ready settlement or mint path exists.

## Completed phases

- [x] Phase A — capability resolver and matrix tests.
- [x] Phase B — DAO gating, shared workspace, native desktop composition, direct-route and transition tests.
- [x] Phase C — desktop Digital Editions search, filters, reset, sort, grid/list renderers, details, and genuine list/unlist actions.
- [x] Phase D — one wallet action model, three-tab information architecture, Owned Editions, duplicate removal, and lifecycle-safe provider consumption.
- [ ] Phase E — full integration verification, visual QA, staging, and release workflow.

## Removed unsupported functionality

- Legacy Artifacts terminology on touched Digital Editions and Wallet surfaces.
- Fake local mint/acquisition UI, Buy Now, offers, auctions, favorites, and generic Ethereum/Polygon filters.
- Fake Staking tab and Stake-to-Swap behavior.
- Duplicate wallet address, network, Refresh, Receive, and custody/security presentations.
- Simulated delegation success; delegation now calls the signed DAO provider mutation.

## Backend

- `kubus-project/art.kubus-backend` PR #30 merged as `96f35ba1a64f1daa99aa2e8c67e9d6cb19171550`; it restricts DAO review decisions to authenticated admin/moderator roles or an explicit reviewer allowlist.
- Existing proposal, vote, delegation, and review submission routes were verified to require authenticated wallet-signed envelopes bound to the authenticated wallet.
- No backend treasury mutation route exists.

## Verification evidence

- `npm run verify:toolchain` — passed.
- `npm run guard:architecture` — passed.
- Focused Flutter analyze for capability, governance, marketplace, and wallet files — passed.
- Capability, desktop governance, Digital Editions parity/controls, wallet action, Owned Editions, and locale-guard tests — 20 passed.
- Backend DAO review route tests — 8 passed.
- Backend lint — passed.
- Remaining repository-wide CI, web QA, responsive visual QA, staging, and release evidence will be appended after completion.
