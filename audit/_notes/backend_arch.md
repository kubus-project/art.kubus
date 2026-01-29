# Backend Architecture Audit

## Summary
- Express server entry is centralized in `backend/src/server.js` with middleware, feature gates, and route wiring. DB access is a thin `pg` pool wrapper. Redis is used for admin sessions and cache with memory fallback. 
- Primary heavy DB work is concentrated in `publicSyncService.fullSync()` (full-table reads + row-by-row sync) and stats snapshot/series endpoints that fan out into multiple COUNT queries.
- One potential N+1 pattern exists in `publicSyncService.syncCommunityPostRow()` where missing hydrated fields triggers an extra query per row.
- Analytics ingestion utilities (IP masking, ingest path normalization, and event shaping) are duplicated between `statsService` and `webAnalyticsService`, increasing drift risk.

## Findings

### AK-AUD-001 — Server entry + middleware stack is centralized
**Evidence:** `backend/src/server.js` lines 1–35 (imports), 249–517 (middleware), 528–598 (route wiring).

### AK-AUD-002 — Routing graph is mapped in `server.js`
**Evidence:** `backend/src/server.js` lines 36–75 (router imports) and 558–598 (route registrations).

### AK-AUD-003 — DB access layer is a thin `pg` pool wrapper
**Evidence:** `backend/src/db/index.js` lines 1–128 (pool init, `query`, `getClient`, `testConnection`).

### AK-AUD-004 — Redis usage (sessions + cache + health)
- Admin session store uses Redis when `REDIS_URL` is configured.  
  **Evidence:** `backend/src/server.js` lines 362–386.
- Cache layer uses Redis with memory fallback.  
  **Evidence:** `backend/src/services/redisClient.js` lines 1–44 and `backend/src/services/cacheService.js` lines 51–117.
- Health endpoint pings Redis and includes cache metrics.  
  **Evidence:** `backend/src/routes/health.js` lines 13–40, 72–77.

### AK-AUD-005 — Heavy full-table scans in OrbitDB full sync
`fullSync()` pulls entire tables (`artworks`, `profiles`, posts, collections) and iterates per row to sync into OrbitDB; this is a large, unpaginated, row-by-row workload.
**Evidence:** `backend/src/services/publicSyncService.js` lines 639–675.

### AK-AUD-006 — Potential N+1 query in community post sync
`syncCommunityPostRow()` re-fetches a post if profile fields are missing, which can trigger an extra query per row during batch sync.
**Evidence:** `backend/src/services/publicSyncService.js` lines 555–560.

### AK-AUD-007 — Stats snapshot endpoints fan out to multiple COUNT queries
Platform snapshots and per-entity snapshots issue multiple COUNT queries (including `analytics_events`) and additional per-entity counts (e.g., bookmarks).
**Evidence:** `backend/src/services/statsService.js` lines 708–735 (bookmark count), 800–819 (view/share counts), 842–855 (platform multi-COUNT fanout).

### AK-AUD-008 — Web analytics ingestion performs inserts per event
Analytics ingestion writes to `analytics_events` and optionally mirrors to `public.web_analytics_events`.
**Evidence:** `backend/src/services/webAnalyticsService.js` lines 186–243.

### AK-AUD-009 — Analytics helper duplication across services
Both `statsService` and `webAnalyticsService` implement overlapping helpers for IP masking and ingest-path normalization, creating drift risk when behavior changes in one service but not the other.
**Evidence:** `backend/src/services/statsService.js` lines 2035–2104 (`maskIpForAnalytics`, ingest path inference in `trackAnalyticsEvent()`); `backend/src/services/webAnalyticsService.js` lines 24–120 (`maskIp`, ingest path inference in `trackWebEvent()`).

## Top P0/P1
- **P1:** OrbitDB full sync does full-table reads + row-by-row processing (high DB load / long runtime).  
  **Evidence:** `backend/src/services/publicSyncService.js` lines 639–675.
- **P1:** Potential N+1 per-row fetch in `syncCommunityPostRow()` during batch sync.  
  **Evidence:** `backend/src/services/publicSyncService.js` lines 555–560.
- **P1:** Stats snapshot fanout of COUNT queries on hot tables (e.g., `analytics_events`).  
  **Evidence:** `backend/src/services/statsService.js` lines 708–735, 800–819, 842–855.

## Follow-up status (2026-01-29)
- **AK-AUD-005 (full sync load)**: **Resolved** — `fullSync()` now paginates with `ORBITDB_SYNC_BATCH_SIZE` and bounded concurrency.
- **AK-AUD-006 (N+1 in community posts)**: **Mitigated** — batch sync skips per-row hydration when data is already pre-joined.
- **AK-AUD-007 (stats fanout)**: **Mitigated** — platform snapshot counts now use a single aggregate query to reduce query fanout.
- **AK-AUD-009 (analytics helper duplication)**: **Resolved** — shared helpers extracted into `backend/src/utils/analyticsUtils.js` and reused by stats + web analytics services.

## Fix Evidence (2026-01-29)
- `backend/src/services/publicSyncService.js`: `fullSync()` now uses batch paging + concurrency, and community post sync can skip hydration with `hydrateIfNeeded: false` during batch runs.
- `backend/src/services/statsService.js`: platform snapshot counts now come from a single aggregate query.
- `backend/src/utils/analyticsUtils.js`: shared `clampText`, `maskIp`, and `normalizeIngestPath` helpers.
- `backend/src/services/statsService.js` + `backend/src/services/webAnalyticsService.js`: reuse shared analytics helpers.

## Files Reviewed
- `backend/src/server.js`
- `backend/src/db/index.js`
- `backend/src/routes/health.js`
- `backend/src/routes/stats.js`
- `backend/src/services/redisClient.js`
- `backend/src/services/cacheService.js`
- `backend/src/services/publicSyncService.js`
- `backend/src/services/statsService.js`
- `backend/src/services/webAnalyticsService.js`
