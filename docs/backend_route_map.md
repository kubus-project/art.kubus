# Backend Route Map (Node/Express)

This document maps the **art.kubus backend** REST API routes (mounted in `backend/src/server.js`) into a frontend-safe contract: methods + paths, auth requirements, and the core request/response shapes.

> Paths below are **absolute**, as seen by clients (e.g. `/api/auth/login`).

## Conventions

### Auth levels

| Label | Meaning | How it’s enforced |
|---|---|---|
| Public | No auth needed | No `verifyToken`/API key middleware |
| Optional | Auth optional; `req.user` may exist | `optionalAuth` middleware |
| User | JWT required | `verifyToken` middleware (Authorization: `Bearer <jwt>`) |
| Admin (doc-only) | Intended admin-only but **not always enforced** | Usually **not** enforced unless route checks `req.user.role` or uses `requireRole` |
| API key | Server-to-server | `verifyApiKey` middleware; header `X-API-KEY` |

### Global middleware notes

- `optionalAuth` + API rate limiting is applied for **all** `/api/*` (`backend/src/server.js`), so even “public” routes may have `req.user` populated when a valid JWT is present.
- Several route groups are guarded by feature flags via `featureGate('<flag>')` in `backend/src/server.js`.

### Response envelope (common pattern)

Most endpoints return one of these patterns:

- Success:
  - `{ "success": true, "data": ... }`
  - `{ "success": true, "message": "...", "data": ... }`
- Error:
  - `{ "success": false, "error": "Human readable" }`
  - Some endpoints also include `message`, `details`, or `errorId`.

## Feature-gated routers (mount points)

Mounted in `backend/src/server.js`:

| Base path | Router | Feature gate |
|---|---|---|
| `/api/community` | `backend/src/routes/community.js` | `enableCommunity` |
| `/api/upload` | `backend/src/routes/upload.js` | `enableUploads` |
| `/api/storage` | `backend/src/routes/storage.js` | `enableStorage` |
| `/api/mock` | `backend/src/routes/mockData.js` | `useMockData` *(also requires `USE_MOCK_DATA=true`)* |
| `/api/achievements` | `backend/src/routes/achievements.js` | `enableAchievements` |
| `/api/collections` | `backend/src/routes/collections.js` | `enableCollections` |
| `/api/notifications` | `backend/src/routes/notifications.js` | `enableNotifications` |
| `/api/search` | `backend/src/routes/search.js` | `enableSearch` |
| `/api/messages` | `backend/src/routes/messages.js` | `enableMessages` |
| `/api/avatar` | `backend/src/routes/avatar.js` | `enableAvatar` |
| `/api/groups` | `backend/src/routes/groups.js` | `enableGroups` |
| `/api/dao` | `backend/src/routes/dao.js` | `enableDao` |
| `/api/orbitdb` | `backend/src/routes/orbitdb.js` | `enableOrbitDb` |

Non-feature-gated:

- `/health` → `backend/src/routes/health.js`
- `/api/auth` → `backend/src/routes/auth.js`
- `/api/ar-markers` → `backend/src/routes/arMarkers.js`
- `/api/art-markers` → `backend/src/routes/artMarkers.js`
- `/api/artworks` → `backend/src/routes/artworks.js`
- `/api/profiles` → `backend/src/routes/profiles.js`
- `/api/users` → `backend/src/routes/users.js` (compat shim)

Optional debug router:

- `/api/debug/token` enabled only when `ENABLE_DEBUG_ENDPOINTS=true` in env.

---

## Health

### Routes

| Method | Path | Access | Notes |
|---|---|---|---|
| GET | `/health` | Public | Full health snapshot; returns 200 or 503 |
| GET | `/health/ready` | Public | Readiness probe; `{ ready: true/false }` |
| GET | `/health/live` | Public | Liveness probe; `{ alive: true }` |

### Response shape (health snapshot)

From `backend/src/routes/health.js`:

```json
{
  "status": "ok|degraded",
  "overallHealthy": true,
  "timestamp": "2025-...",
  "uptime": 123.45,
  "environment": "development|production",
  "services": {
    "database": { "healthy": true },
    "redis": { "enabled": false, "healthy": false, "connected": false, "mode": "memory" },
    "cache": { "hits": 0, "misses": 0, "sets": 0 },
    "storage": { "provider": "hybrid|ipfs|http", "ipfsGateway": true },
    "orbitdb": { "enabled": true, "status": "..." }
  }
}
```

---

## Auth (`/api/auth`)

### Routes

| Method | Path | Access | Purpose |
|---|---|---|---|
| POST | `/api/auth/register` | Public | Wallet-based register (may fall back to in-memory) |
| GET | `/api/auth/challenge?walletAddress=...` | Public | Get signable challenge message |
| POST | `/api/auth/login` | Public | Wallet signature login |
| POST | `/api/auth/register/email` | Public | Email/password register |
| POST | `/api/auth/login/email` | Public | Email/password login |
| POST | `/api/auth/login/google` | Public | Google ID token login |

### JWT refresh/session

No dedicated refresh endpoint was found in `backend/src/routes/auth.js`. Tokens are issued with `JWT_EXPIRES_IN` (default `7d`). Client should re-login when expired.

### Request/response shapes

#### `GET /api/auth/challenge`

Query:

- `walletAddress` (required)

Response:

```json
{ "success": true, "message": "art.kubus Login\nWallet: ...", "expiresAt": 1730000000000 }
```

#### `POST /api/auth/login` (wallet)

Body:

```json
{ "walletAddress": "<base58 pubkey>", "signature": "<base64 or base58 signature>" }
```

Response:

```json
{ "success": true, "message": "Login successful", "data": { "token": "...", "user": { "id": "...", "walletAddress": "...", "username": "...", "displayName": "...", "role": "user", "avatar_url": "..." } } }
```

#### `POST /api/auth/login/email`

Body:

```json
{ "email": "user@example.com", "password": "min 8 chars" }
```

Response:

```json
{ "success": true, "message": "Login successful", "data": { "token": "...", "user": { "id": "...", "email": "...", "walletAddress": "..." } } }
```

#### `POST /api/auth/login/google`

Body:

```json
{ "idToken": "<google id token>", "username": "optional", "walletAddress": "optional" }
```

Response: same envelope as other logins.

---

## Profiles (`/api/profiles`)

> Note: `backend/src/routes/profiles.js` currently defines **`GET /me` twice**.

### Routes

| Method | Path | Access | Notes |
|---|---|---|---|
| GET | `/api/profiles/me` | User | Current user profile (duplicate handler exists) |
| GET | `/api/profiles/:walletAddress` | Public | Profile by wallet |
| GET | `/api/profiles/:walletAddress/stats` | Public | Stats by wallet |
| POST | `/api/profiles/batch` | Public | Batch fetch `{ wallets: [] }` |
| POST | `/api/profiles` | Public | Create/update profile *(no JWT required in current code)* |
| GET | `/api/profiles/artists/list` | Public | List artist profiles |
| GET | `/api/profiles/:walletAddress/artworks` | Public | Artworks by wallet |
| POST | `/api/profiles/:walletAddress/verify` | Public (doc says admin) | Comment says admin-only, but middleware is not enforced |
| POST | `/api/profiles/issue-token` | Public | Issues a token (sensitive; review usage) |
| DELETE | `/api/profiles/me` | User | Delete own profile + related data |
| POST | `/api/profiles/avatars` | User | Avatar upload (multipart) |

### Key shapes

#### Profile object (typical)

Returned as `data`:

```json
{
  "walletAddress": "...",
  "username": "...",
  "displayName": "...",
  "bio": "...",
  "avatar": "https://...",
  "coverImage": "https://...",
  "social": { "twitter": "...", "instagram": "...", "discord": "...", "website": "..." },
  "isArtist": true,
  "isInstitution": false,
  "createdAt": "...",
  "updatedAt": "..."
}
```

#### `POST /api/profiles` create/update

Body (subset):

```json
{ "walletAddress": "...", "displayName": "...", "bio": "...", "avatar": "...", "social": {}, "preferences": {} }
```

Errors often include both `error` and `message`:

```json
{ "success": false, "error": "Validation error", "message": "Wallet address is required" }
```

---

## Users (compat shim) (`/api/users`)

### Routes

| Method | Path | Access | Purpose |
|---|---|---|---|
| GET | `/api/users/:walletAddress` | Public | Returns profile-like object (compat) |
| GET | `/api/users/:walletAddress/followers` | Public | Followers list (compat) |
| GET | `/api/users/:walletAddress/following` | Public | Following list (compat) |

---

## Artworks (`/api/artworks`)

### Routes

| Method | Path | Access | Notes |
|---|---|---|---|
| GET | `/api/artworks` | Optional | Supports filters + pagination; supports `?source=orbit` |
| GET | `/api/artworks/:id` | Optional | Supports `?source=orbit` |
| POST | `/api/artworks` | User | Multipart: `image` and optional `model` |

### Create artwork request

`POST /api/artworks` (multipart or form fields):

- Required fields: `title`, `description`, and either `image` file or `imageUrl`
- Optional fields (selected):
  - `category`, `tags` (comma-separated or array)
  - `latitude`, `longitude`, `locationName`
  - `isPublic`, `isAREnabled`, `arScale`
  - NFT/market: `isNFT`/`mintAsNFT`, `nftMintAddress`, `nftMetadataUri`, `price`, `currency` (default `KUB8`)

Response:

```json
{ "success": true, "message": "Artwork created successfully", "data": { "id": "...", "title": "...", "imageUrl": "...", "model3dUrl": "..." } }
```

---

## AR marker content (`/api/ar-markers`)

### Routes

| Method | Path | Access | Purpose |
|---|---|---|---|
| GET | `/api/ar-markers/:id/content` | Optional | Returns AR payload (model URL + config) |
| POST | `/api/ar-markers/:id/interaction` | Optional | Increments activation count |

### Response shape (`GET /:id/content`)

```json
{
  "success": true,
  "data": {
    "markerId": "...",
    "arMarkerId": "...",
    "type": "geolocation",
    "title": "...",
    "modelUrl": "https://... or https://ipfs.io/ipfs/<cid>",
    "storageProvider": "hybrid",
    "config": {
      "scale": 1,
      "rotation": { "x": 0, "y": 0, "z": 0 },
      "enableAnimation": false,
      "enableInteraction": true,
      "metadata": {}
    }
  }
}
```

---

## Geospatial markers (`/api/art-markers`)

These routes join `art_markers` with `ar_markers` and `artworks` and normalize into a frontend-friendly marker object.

### Routes

| Method | Path | Access | Notes |
|---|---|---|---|
| GET | `/api/art-markers?lat&lng&radius` | Optional | Nearby markers |
| POST | `/api/art-markers` | User | Create marker |
| GET | `/api/art-markers/:id` | Optional | Marker detail |
| PUT | `/api/art-markers/:id` | User | Update marker (owner; admin bypass via `req.user.role === 'admin'`) |
| DELETE | `/api/art-markers/:id` | User | Delete marker (owner; admin bypass via `req.user.role === 'admin'`) |
| POST | `/api/art-markers/:id/view` | Optional | Increment view counter in config.stats |
| POST | `/api/art-markers/:id/interact` | Optional | Increment interaction + activation count |

---

## Community (`/api/community`) ✅

### Routes

| Method | Path | Access | Purpose |
|---|---|---|---|
| GET | `/api/community/posts` | Optional | List posts (supports filters) |
| GET | `/api/community/art-feed` | Optional | Location-based art feed |
| GET | `/api/community/posts/:id` | Optional | Post detail (increments views) |
| POST | `/api/community/posts` | User | Create post |
| PUT | `/api/community/posts/:id` | User | Update post (author only) |
| DELETE | `/api/community/posts/:id` | User | Delete post (author only) |
| POST | `/api/community/posts/:id/like` | User | Like post |
| DELETE | `/api/community/posts/:id/like` | User | Unlike post |
| POST | `/api/community/posts/:id/share` | User | Share post (increments share count + notification) |
| GET | `/api/community/posts/:id/comments` | Optional | List comments |
| POST | `/api/community/posts/:id/comments` | User | Create comment |
| DELETE | `/api/community/comments/:id` | User | Delete comment (author only) |
| POST | `/api/community/comments/:id/like` | User | Like comment |
| DELETE | `/api/community/comments/:id/like` | User | Unlike comment |
| GET | `/api/community/posts/:id/likes` | Optional | List who liked a post |
| GET | `/api/community/comments/:id/likes` | Optional | List who liked a comment |
| POST | `/api/community/follow/:walletAddress` | User | Follow user |
| DELETE | `/api/community/follow/:walletAddress` | User | Unfollow user |
| GET | `/api/community/follow/:walletAddress/status` | User | Follow status (viewer→target) |
| GET | `/api/community/followers/:walletAddress` | Optional | Followers list |
| GET | `/api/community/following/:walletAddress` | Optional | Following list |
| GET | `/api/community/feed` | User | Personalized feed |
| GET | `/api/community/trending` | Optional | Trending posts/tags |
| POST | `/api/community/posts/repost` | User | Repost/create repost |
| POST | `/api/community/messages/share` | User | Share a post via DM (creates/uses conversation + message) |
| GET | `/api/community/posts/:id/reposts` | Optional | List reposts for a post |
| DELETE | `/api/community/posts/:id/repost` | User | Delete a repost (unrepost) |
| POST | `/api/community/analytics/event` | User | Track analytics event (server logs only) |

### Key shapes

#### Create post

`POST /api/community/posts` body (subset):

```json
{ "content": "...", "postType": "text|image|video|repost", "mediaUrls": [], "mediaCids": [], "tags": [], "mentions": [], "location": {} }
```

#### Share post via DM

`POST /api/community/messages/share` body:

```json
{ "postId": "...", "recipientWallet": "...", "message": "optional" }
```

Response:

```json
{ "success": true, "data": { "messageId": "...", "conversationId": "...", "sharedPostId": "...", "createdAt": "..." } }
```

---

## Messages (`/api/messages`) ✅

### Routes

| Method | Path | Access | Notes |
|---|---|---|---|
| GET | `/api/messages` | User | List conversations (only member conversations) |
| GET | `/api/messages/:conversationId/messages` | User | Messages in a conversation |
| POST | `/api/messages/:conversationId/messages` | User | Send message (supports multipart attachments) |
| PUT | `/api/messages/:conversationId/read` | User | Mark conversation read |
| PUT | `/api/messages/:conversationId/messages/:messageId/read` | User | Mark message read |
| POST | `/api/messages/:conversationId/messages/:messageId/reactions` | User | Add reaction `{ emoji }` |
| DELETE | `/api/messages/:conversationId/messages/:messageId/reactions` | User | Remove reaction `{ emoji }` |
| GET | `/api/messages/:conversationId/members` | User | Get members |
| POST | `/api/messages/:conversationId/members` | User | Add members |
| PATCH | `/api/messages/:conversationId/rename` | User | Rename conversation |
| POST | `/api/messages` | User | Create conversation |
| POST | `/api/messages/:conversationId/avatar` | User | Upload conversation avatar (`file`) |

---

## Notifications (`/api/notifications`) ✅

### Routes

| Method | Path | Access | Notes |
|---|---|---|---|
| GET | `/api/notifications` | User | List notifications (filters: `unreadOnly`, `type`, pagination) |
| GET | `/api/notifications/unread-count` | User | Unread count |
| POST | `/api/notifications` | User | Create notification (internal/system use) |
| PUT | `/api/notifications/:id/read` | User | Mark read |
| PUT | `/api/notifications/read-all` | User | Mark all read |
| DELETE | `/api/notifications/:id` | User | Delete one |
| DELETE | `/api/notifications` | User | Delete many (filters: `readOnly`, `type`) |

---

## Search (`/api/search`) ✅

### Routes

| Method | Path | Access | Purpose |
|---|---|---|---|
| GET | `/api/search?q=...&type=all|profiles|artworks|institutions|collections|posts` | Optional | Universal search |
| GET | `/api/search/suggestions?q=...` | Optional | Autocomplete suggestions |
| GET | `/api/search/trending` | Optional | Trending tags/artists/artworks |

---

## Achievements / POAP / KUB8 (`/api/achievements`) ✅

### Routes

| Method | Path | Access | Notes |
|---|---|---|---|
| GET | `/api/achievements` | Public | Lists achievements (`is_poap`, `reward_kub8`) |
| GET | `/api/achievements/user/:walletAddress` | Public | Unlocked + progress + total tokens |
| POST | `/api/achievements/unlock` | User | Unlock by `achievementType` |
| POST | `/api/achievements/progress` | User | Update progress |
| GET | `/api/achievements/stats/:walletAddress` | Public | Counts + totals |
| GET | `/api/achievements/leaderboard` | Public | Leaderboard |

### Notes on “POAP”

The backend models achievements with `is_poap` + `event_id`, but there is no dedicated `/poap/*` route module. Treat POAP as metadata on achievements until a mint/claim endpoint exists.

### Notes on “KUB8 endpoints”

KUB8 appears as:

- `reward_kub8` in achievements (token reward value)
- `currency` default in artworks marketplace fields
- DAO voting power is derived from SPL token balance via Solana RPC (`backend/src/routes/dao.js`)

No dedicated transfer/airdrop/mint endpoints were found in `backend/src/routes/*`.

---

## Collections (`/api/collections`) ✅

### Routes

| Method | Path | Access |
|---|---|---|
| GET | `/api/collections` | Optional |
| GET | `/api/collections/:id` | Optional |
| POST | `/api/collections` | User |
| PUT | `/api/collections/:id` | User (owner) |
| DELETE | `/api/collections/:id` | User (owner) |
| POST | `/api/collections/:id/artworks` | User |
| DELETE | `/api/collections/:id/artworks/:artworkId` | User |

---

## Uploads (`/api/upload`) ✅

### Routes

| Method | Path | Access | Notes |
|---|---|---|---|
| POST | `/api/upload` | User | Multipart field: `file` + optional `targetStorage`, `fileType`, `metadata` |
| POST | `/api/upload/multiple` | User | Multipart: `files[]` |
| GET | `/api/upload/:identifier` | Public | Fetch file by CID/path depending on `type` |

Response for single upload:

```json
{ "success": true, "message": "File uploaded successfully", "data": { "url": "https://...", "cid": "..." } }
```

---

## Storage (`/api/storage`) ✅

### Routes

| Method | Path | Access | Notes |
|---|---|---|---|
| GET | `/api/storage/info` | Public | Provider + gateway list |
| GET | `/api/storage/stats` | User *(doc says admin)* | **No role check** in current code; uses `verifyToken` only |
| POST | `/api/storage/test-gateway` | Public | Tests a gateway URL |

---

## Avatar proxy (`/api/avatar`) ✅

### Routes

| Method | Path | Access | Purpose |
|---|---|---|---|
| GET | `/api/avatar/:seed` | Public | Proxy to DiceBear with CORS + fallback image/SVG |

---

## Groups (`/api/groups`) ✅

### Routes

| Method | Path | Access | Notes |
|---|---|---|---|
| POST | `/api/groups` | User | Create group *(may return 501 if schema missing)* |
| GET | `/api/groups` | Optional | List groups *(may return 501)* |
| POST | `/api/groups/:id/join` | User | Join group *(may return 501)* |
| POST | `/api/groups/:id/leave` | User | Leave group *(may return 501)* |
| POST | `/api/groups/:id/posts` | User | Create group post *(may return 501)* |
| GET | `/api/groups/:id/posts` | Optional | List group posts *(may return 501)* |

---

## DAO (`/api/dao`) ✅

### Routes

| Method | Path | Access | Notes |
|---|---|---|---|
| GET | `/api/dao/proposals` | Optional | List proposals |
| GET | `/api/dao/proposals/:id` | Optional | Proposal detail |
| POST | `/api/dao/proposals` | User | Create proposal (may require min KUB8 via env) |
| GET | `/api/dao/votes` | Optional | List votes (filter by `proposalId`) |
| GET | `/api/dao/proposals/:id/votes` | Optional | Votes for proposal |
| POST | `/api/dao/proposals/:id/votes` | User | Cast vote (`choice`, `votingPower?`) |
| GET | `/api/dao/delegates` | Optional | Delegates |
| POST | `/api/dao/delegations` | User | Delegate voting power snapshot |
| GET | `/api/dao/transactions` | Optional | Treasury tx list |
| GET | `/api/dao/reviews` | Optional | Artist/institution review queue |
| GET | `/api/dao/reviews/:id` | Optional | Review detail |
| POST | `/api/dao/reviews` | User | Submit review application |
| POST | `/api/dao/reviews/:id/decision` | User | Decision endpoint gated by env allowlist |

---

## OrbitDB (`/api/orbitdb`) ✅

### Routes

| Method | Path | Access | Notes |
|---|---|---|---|
| POST | `/api/orbitdb/init` | API key | Initialize OrbitDB repo |
| POST | `/api/orbitdb/artworks` | Optional/User | Accept client-signed doc OR server-signed (JWT required for server-signed) |
| GET | `/api/orbitdb/artworks/:id` | Public | Read doc by id |
| POST | `/api/orbitdb/pin` | API key | Pin CID |

---

## Mock data (`/api/mock`) ✅

Enabled only when feature flag `useMockData` is on **and** env `USE_MOCK_DATA=true`.

### Routes

| Method | Path | Access |
|---|---|---|
| GET | `/api/mock/artworks` | Public (when enabled) |
| GET | `/api/mock/ar-markers` | Public (when enabled) |
| GET | `/api/mock/community-posts` | Public (when enabled) |
| GET | `/api/mock/institutions` | Public (when enabled) |
| GET | `/api/mock/daos` | Public (when enabled) |
| GET | `/api/mock/wallet` | Public (when enabled) |
| GET | `/api/mock/transactions` | Public (when enabled) |

---

## Events / Exhibitions

No dedicated `/api/events` or `/api/exhibitions` route module exists in `backend/src/routes/*`.

Current "event"-adjacent pieces:

- `POST /api/community/analytics/event` (logs analytics)
- Achievements include `event_id` + `is_poap` fields (metadata)

---

## User-facing message strings: where they come from

This backend returns user-facing text in these JSON fields:

- `error`: primary human-readable error string
- `message`: human-readable success/error message (inconsistently present)
- `details`: additional error detail (uploads)
- `errorId`: opaque id for debugging (global error handler)

### Core middleware

| File | Fields | Examples |
|---|---|---|
| `backend/src/middleware/auth.js` | `error` | `"Authentication required"`, `"Invalid or expired token"`, `"Insufficient permissions"` |
| `backend/src/middleware/errorHandler.js` | `error`, `errorId` (and sometimes `stack`) | Normalizes `Validation error`, `Token expired`, etc. |
| `backend/src/server.js` | `error` (socket events) | Socket emits `auth:error` with `"Authentication required"` |

### Route modules (primary)

| File | Typical fields |
|---|---|
| `backend/src/routes/auth.js` | `message`, `error` |
| `backend/src/routes/profiles.js` | `message`, `error` (often both) |
| `backend/src/routes/artworks.js` | `message`, `error` |
| `backend/src/routes/arMarkers.js` | `message`, `error` |
| `backend/src/routes/artMarkers.js` | `message`, `error` |
| `backend/src/routes/community.js` | `message`, `error` |
| `backend/src/routes/messages.js` | `message`, `error` |
| `backend/src/routes/notifications.js` | `message`, `error` |
| `backend/src/routes/upload.js` | `message`, `error`, `details` |
| `backend/src/routes/search.js` | `error` and sometimes `message` |
| `backend/src/routes/mockData.js` | `error`, `message` |

If you need a comprehensive list of exact string literals, search the backend for:

- `res\.json\(\{[^}]*message:`
- `res\.status\([^)]*\)\.json\(\{[^}]*error:`

(Those patterns are widely used across route modules.)
