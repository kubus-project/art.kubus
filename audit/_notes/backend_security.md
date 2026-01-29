# Backend Security Baseline Audit (Jan 29, 2026)

## Summary
Baseline review of backend authN/authZ coverage, input validation, rate limiting, headers, error handling, secret handling, and audit logging. Several authZ gaps exist in messaging routes (conversation membership not enforced), and some endpoints expose data or allow actions without sufficient authorization or validation. Marker edit/delete permissions are enforced but can 403 due to identifier mismatches between stored `createdBy` and token payloads.

## Top P0/P1
- **P0:** Conversation messages + membership endpoints lack membership checks, enabling authenticated users to read/post/modify conversations they are not part of.
- **P1:** Notifications create endpoint is open to any authenticated user (spam/abuse vector).
- **P1:** Achievements user/stats endpoints are public (no auth) and expose user progress.
- **P1:** JWT secret fallback to `dev-secret` when `JWT_SECRET` is unset; production misconfig yields weak auth.
- **P1:** Input validation gaps on messages/notifications/achievements routes (no schema validation/limits).

## Findings

### AK-AUD-001 — Missing conversation membership authorization (messages read/write/metadata) **(P0)**
**Evidence:**
- `backend/src/routes/messages.js` lines **228–239**: `GET /:conversationId/messages` is gated by `verifyToken` but **does not** call `ensureConversationMember` (lines 56–64) or verify membership before returning messages.
- `backend/src/routes/messages.js` lines **471–625**: `POST /:conversationId/messages` inserts messages and emits socket events without membership checks.
- `backend/src/routes/messages.js` lines **628–676**: `PUT /:conversationId/read` marks a conversation as read without membership checks.
- `backend/src/routes/messages.js` lines **846–899**: `GET /:conversationId/members` returns member lists without membership checks.
- `backend/src/routes/messages.js` lines **902–949**: `POST /:conversationId/members` allows adding members to any conversation without verifying requester’s membership or role.
- `backend/src/routes/messages.js` lines **1088–1134**: `POST /:conversationId/avatar` allows avatar updates without membership checks.
- `backend/src/routes/messages.js` lines **744–808** show `ensureConversationMember(...)` is only used for reactions, not for read/write/member management.

**Impact:** Any authenticated user who can guess/obtain a conversation ID can read messages, post messages, modify read state, list members, add members, or change avatars.

**Root cause:** Membership enforcement exists but is not wired into most message-related routes.

---

### AK-AUD-002 — Notifications creation is broadly authorized (spam/abuse risk) **(P1)**
**Evidence:**
- `backend/src/routes/notifications.js` lines **149–188**: `POST /api/notifications` requires only `verifyToken` and accepts arbitrary `targetWallet`, with no role/permission gating or anti-abuse checks beyond global rate limiting.

**Impact:** Any authenticated user can generate notifications for any wallet, enabling spam or social-engineering signals.

**Root cause:** “Internal use” endpoint is exposed with general auth but no authorization policy.

---

### AK-AUD-003 — Achievements user data endpoints are public **(P1)**
**Evidence:**
- `backend/src/routes/achievements.js` lines **29–72**: `GET /api/achievements/user/:walletAddress` has no `verifyToken` and returns unlocked achievements and progress for any wallet.
- `backend/src/routes/achievements.js` lines **195–234**: `GET /api/achievements/stats/:walletAddress` has no `verifyToken` and returns per-user stats.

**Impact:** Any client can enumerate achievement progress for any wallet (privacy leakage).

**Root cause:** Public endpoints without authN or access controls.

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
**Evidence:**
- Validation middleware exists but is not applied to these routes: `backend/src/middleware/validation.js` lines **1–200** (no message/notification/achievement schemas).
- Messages accept arbitrary bodies/attachments without schema validation: `backend/src/routes/messages.js` lines **228–625**.
- Notifications creation accepts arbitrary `data` without schema validation: `backend/src/routes/notifications.js` lines **149–188**.
- Achievement `unlock`/`progress` accept raw body fields without schema validation: `backend/src/routes/achievements.js` lines **78–187**.

**Impact:** Malformed or unexpected payloads can be persisted; inconsistent data increases downstream risk and can cause client crashes or noisy logs.

**Root cause:** Missing express-validator schemas and validation enforcement for these routes.

---

### AK-AUD-006 — JWT secret fallback to a hardcoded default **(P1)**
**Evidence:**
- `backend/src/middleware/auth.js` line **45** uses `process.env.JWT_SECRET || 'dev-secret'` (also in optionalAuth at line **121**).
- `backend/src/server.js` lines **344–353** allow admin sessions to fall back to a dev secret in non-prod; session secret fallback is set at line **395** if not provided.

**Impact:** If `JWT_SECRET` is unset in production, authentication can be forged using the default secret, compromising all protected endpoints.

**Root cause:** Default secret value without a hard-fail guard outside admin sessions.

---

### AK-AUD-007 — Error details exposed in non-production, risk if NODE_ENV mis-set **(P2)**
**Evidence:**
- `backend/src/middleware/errorHandler.js` lines **67–75** include error message and stack when `NODE_ENV` is not `production`.

**Impact:** If environment configuration is incorrect, stack traces and internal error messages can leak to clients.

**Root cause:** Conditional error exposure based on `NODE_ENV` without defense-in-depth.

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
