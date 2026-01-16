# Season 0 Contract (art.kubus)

Season 0 is the baseline product/engineering contract for shipping and iterating without breaking the app's identity, safety, or runtime stability.

## Pillar 1 - Exhibition + Community Platform

Season 0 is an **exhibition experience** with a **community layer**.

- Primary surfaces: artwork discovery, maps/markers, artist profiles, community posts, messaging/conversations.
- Success criteria: the app remains useful in read-only mode, and core browsing/community flows do not depend on XR/Web3 being enabled.

Checklist (when adding features):
- [ ] The feature improves exhibition discovery, participation, or community connection.
- [ ] The feature has a clear entry point in existing navigation/surfaces (no "hidden" flows that fragment UX).
- [ ] When the backend endpoint is missing/disabled, UI behavior remains functional (hide/disable gracefully; prefer local-first where applicable).

## Pillar 2 - Cooperation Ideology (Collaboration by Default)

Season 0 assumes cooperation: collaboration features should exist **wherever sensible**.

Guiding rules:
- Prefer "share/participate" over "own/lock" unless security/privacy requires it.
- If a feature naturally supports multiple people, design it that way first (permissions and UX included).

Checklist:
- [ ] The feature supports collaboration (sharing, invitations, co-curation, group participation) when it makes sense.
- [ ] Permission boundaries are explicit (public / optional-auth / user-auth / admin-only).
- [ ] Collaboration does not fork new state models; it reuses existing providers/services/models.

## Pillar 3 - XR/Web3 Are Additive Layers

XR and Web3 are **enhancements**, not prerequisites.

Checklist:
- [ ] The non-XR/non-Web3 experience remains complete for Season 0's core use cases.
- [ ] XR/Web3 paths are behind feature flags (`AppConfig.isFeatureEnabled('<flag>')`) and have safe fallbacks.
- [ ] XR launch flows go through `ARService` / `ARManager` and do not embed gateway/URL logic in UI.
- [ ] Web3 features do not block community/exhibition flows when disabled.

## Pillar 4 - KUB8 Is Offchain Points (Season 0 Language)

In Season 0, **KUB8 is points**: offchain, non-transferable framing, and strictly non-financial language.

Allowed phrasing:
- `points`, `season points`, `reputation`, `progress`, `recognition`, `unlock`, `badge`

Avoid (Season 0):
- `token`, `currency`, `value`, `worth`, `profit`, `ROI`, `investment`, `earn money`, `cash out`, `price`

Checklist:
- [ ] UI copy and docs describe KUB8 as points/progression (not a financial instrument).
- [ ] No implication of convertibility, transferability, or market value in Season 0.
- [ ] Any rewards are framed as access/recognition (e.g., badges/POAP-style collectibles) rather than payment.

## Pillar 5 - Backend "Must Harden" Routes (Security-Critical)

These routes directly affect identity, trust, or system integrity and must be treated as **high-risk** changes.

Targets (current paths):
- Profiles write: `POST /api/profiles` (`backend/src/routes/profiles.js`)
- Profiles verify: `POST /api/profiles/:walletAddress/verify` (`backend/src/routes/profiles.js`)
- Issue token: `POST /api/profiles/issue-token` (`backend/src/routes/profiles.js`)
- Storage stats: `GET /api/storage/stats` (`backend/src/routes/storage.js`)

Hardening checklist (apply per route as relevant):
- [ ] AuthZ is explicit and enforced (JWT/API key/admin role as appropriate; "doc-only admin" is not acceptable).
- [ ] Input is validated and normalized (wallet casing/format, payload size limits, allowed fields).
- [ ] Rate limits exist for abuse-prone actions (token issuance, profile writes, verification).
- [ ] Responses follow a stable envelope (`success`, `data` / `error`) and avoid leaking internals.
- [ ] Auditing is available for sensitive actions (who did what, when; correlation IDs if present).
- [ ] Operations are idempotent where applicable (retries don't duplicate side effects).

Reference: `docs/backend_route_map.md` for current route shapes and auth expectations.

## Season 0 Change Checklist (PR Gate)

- [ ] Aligns with Season 0 pillars (exhibition/community first; cooperation by default).
- [ ] XR/Web3 additions are optional and gated; core app remains usable without them.
- [ ] KUB8 is described and implemented as offchain points in Season 0 (non-financial language).
- [ ] Any touches to "must harden" routes include a security review pass and do not loosen auth/validation.
- [ ] Desktop/mobile parity is preserved for any screen changes.
