# Backend Security Baseline Audit (Jan 29, 2026)

## Summary
Baseline review of backend authN/authZ coverage, input validation, rate limiting, headers, error handling, secret handling, and audit logging. Several authZ gaps exist in messaging routes (conversation membership not enforced), and some endpoints expose data or allow actions without sufficient authorization or validation. Marker edit/delete permissions are enforced but can 403 due to identifier mismatches between stored `createdBy` and token payloads.

## Top P0/P1
- **P0 (resolved):** Conversation messages + membership endpoints now enforce membership checks.
- **P1 (resolved):** Notifications create endpoint restricted to admin/system for cross-user targets.
- **P1 (resolved):** Achievements user/stats endpoints require auth and ownership.
- **P1 (resolved):** JWT secret missing in production fails fast via runtime config validation.
- **P1 (resolved):** Input validation added for messages/notifications/achievements routes.

## Findings

### AK-AUD-001 — Missing conversation membership authorization (messages read/write/metadata) **(P0)**
**Status:** Resolved.

---

### AK-AUD-002 — Notifications creation is broadly authorized (spam/abuse risk) **(P1)**
**Status:** Resolved.

---

### AK-AUD-003 — Achievements user data endpoints are public **(P1)**
**Status:** Resolved.

---

### AK-AUD-004 — Marker edit/delete 403s caused by identifier mismatch between token and `createdBy` **(P2)**
**Evidence:**
- Ownership checks use `marker_data.createdBy/created_by` (art marker data) matched against wallet or user id: `requesterOwnsMarker` in `backend/src/routes/artMarkers.js` lines **262–282**.
- Fallbacks attempt to resolve wallet/user mappings, but only if token fields align or users table contains mappings: `resolveRequesterForManage` lines **171–247** and `requesterOwnsMarkerByLegacyAlias` lines **285–346**.
- Legacy fallback only allowed when owner is empty or `system`: `canManageMarkerWithFallback` lines **415–433**.
- Create route sets `createdBy` using wallet or user id from token: lines **1051–1073**.
- Update/DELETE return 403 when checks fail: lines **1286–1318** and **1616–1646**.

**Impact:** Users may receive 403 on marker edit/delete if:
- Their token carries wallet in a different field than expected (`id` vs `walletAddress`),
- The `users` table does not map the wallet to a user id,
- `createdBy` is stored as an email/username that no longer matches the requester, or
- `createdBy` is non-empty but not “system,” blocking artwork-owner fallback.

**Root cause:** Ownership is strictly tied to `createdBy` stored values with limited legacy mappings.

---

### AK-AUD-005 — Input validation gaps on messages/notifications/achievements **(P1)**
**Status:** Resolved.

---

### AK-AUD-006 — JWT secret fallback to a hardcoded default **(P1)**
**Status:** Resolved.

---

### AK-AUD-007 — Error details exposed in non-production, risk if NODE_ENV mis-set **(P2)**
**Status:** Mitigated — behavior unchanged, but production config is validated and documented.

## Fix Evidence (2026-01-29)
- **AK-AUD-001**: Conversation-scoped routes now apply `requireConversationMember` on list, create, read, members, and avatar update endpoints in `backend/src/routes/messages.js`.
- **AK-AUD-002**: `POST /api/notifications` now blocks cross-user creation unless caller has admin/system role (`backend/src/routes/notifications.js`).
- **AK-AUD-003**: Achievement user + stats endpoints require auth and enforce ownership (`backend/src/routes/achievements.js`).
- **AK-AUD-005**: Validation schemas for messages, notifications, and achievements are defined in `backend/src/middleware/validation.js` and applied in their routes.
- **AK-AUD-006**: Runtime config validation enforces `JWT_SECRET` in production (`backend/src/config/validateEnv.js`), and auth middleware no longer uses a dev-secret fallback.
- **AK-AUD-007**: Error handler still exposes stacks in non-prod; keep `NODE_ENV=production` in deployments.

## Follow-up status (2026-01-29)
- **AK-AUD-001**: Resolved.
- **AK-AUD-002**: Resolved.
- **AK-AUD-003**: Resolved.
- **AK-AUD-004**: Open (ownership mismatch handling; see marker audit follow-ups).
- **AK-AUD-005**: Resolved.
- **AK-AUD-006**: Resolved.
- **AK-AUD-007**: Mitigated (requires correct production env).

---

## Files Reviewed
- `backend/src/server.js`
- `backend/src/middleware/auth.js`
- `backend/src/middleware/validation.js`
- `backend/src/middleware/errorHandler.js`
- `backend/src/routes/artMarkers.js`
- `backend/src/routes/arMarkers.js`
- `backend/src/routes/messages.js`
- `backend/src/routes/notifications.js`
- `backend/src/routes/achievements.js`
- `backend/src/utils/logger.js`
