# Backend Analytics / Telemetry Audit

## Summary
Backend telemetry is split between legacy `analytics_events` (stats snapshots/series) and unified `public.analytics_events` (web/app/admin dashboards). Ingestion is strict (UUID `event_id` + `session_id`) and depends on schema guards/migrations for dedupe indexes. Several validation and schema/index conditions can explain missing telemetry and double counts.

## Findings

### AK-AUD-001 — Web ingest rejects valid sites due to app-property allowlist check
**Impact:** Web telemetry can be dropped with `400 Invalid property` when `body.site` is a valid web site (e.g., `kubus.site`) but not present in `ANALYTICS_APP_ALLOWED_PROPERTIES` (default only `app.kubus.site`). This blocks updates for web analytics.

**Evidence:**
- `backend/src/routes/analytics.js` lines 115–119 define `allowedAppProperties` from `ANALYTICS_APP_ALLOWED_PROPERTIES`.
- `backend/src/routes/analytics.js` lines 460–463 validate `rawProperty` (derived from `body.property` **or** `body.site`) against `allowedAppProperties`, causing web sites to fail the check.

### AK-AUD-002 — Strict UUID/session requirements drop telemetry when clients omit IDs or required fields
**Impact:** Telemetry appears “not updating” if clients do not send stable UUID `event_id` and `session_id` (web) or required app metadata fields (app). Events are silently filtered or rejected.

**Evidence:**
- Web ingress requires UUID event IDs and session IDs: `backend/src/routes/analytics.js` lines 506–514 (filters out missing `sessionId`, non-UUID `eventId`, missing `path` for `page_view`).
- Web service enforces fail-closed rules: `backend/src/services/webAnalyticsService.js` lines 137–143 (drop if no `sessionId` or invalid UUID `eventId`).
- App telemetry requires UUID `event_id` + `session_id`: `backend/src/routes/analytics.js` lines 178–189.
- App telemetry requires core metadata fields: `backend/src/routes/analytics.js` lines 221–227.

### AK-AUD-003 — Dedupe relies on unique indexes; missing/blocked indexes allow double counts
**Impact:** If migrations/schema guards do not create unique indexes (or are skipped due to existing duplicates), retries can generate duplicate rows. `ON CONFLICT DO NOTHING` does not dedupe unless a unique index/constraint exists.

**Evidence:**
- Insert path uses `ON CONFLICT DO NOTHING` with `event_id`/`dedupe_hash`: `backend/src/services/statsService.js` lines 2219–2278.
- Web dedupe hash computed only for `page_view`: `backend/src/services/webAnalyticsService.js` lines 170–183.
- Unique index creation is conditional and **skipped** if duplicates already exist: `backend/src/db/schemaGuards.js` lines 633–666.
- Migration 031 defines unique indexes for `event_id` and `dedupe_hash`: `backend/migrations/031_analytics_events_ingest_and_dedupe.sql` lines 33–43.

### AK-AUD-004 — Legacy vs unified table mismatch causes “stats” views to stagnate
**Impact:** Stats snapshots/series query legacy `analytics_events` for views, while web/app telemetry writes primarily to `public.analytics_events`. If `ANALYTICS_LEGACY_INSERT_ENABLED` is false (default) or `skipLegacyInsert` is used, stats views will not update.

**Evidence:**
- Legacy insert is opt-in: `backend/src/services/statsService.js` lines 2181–2205 (`ANALYTICS_LEGACY_INSERT_ENABLED` gate).
- Web/app ingestion explicitly skips legacy insert: `backend/src/services/webAnalyticsService.js` lines 186–213 (`skipLegacyInsert: true`); `backend/src/routes/analytics.js` lines 585–596 (`skipLegacyInsert: true`).
- Stats snapshots use legacy `analytics_events` for views: `backend/src/services/statsService.js` lines 570–608 (visitor counts) and 799–855 (event/exhibition views + platform views).

## Top P0/P1
- **P0:** Fix web ingestion allowlist validation so `body.site` is validated against `allowedSites`, not `allowedAppProperties` (AK-AUD-001).
- **P0:** Ensure unique indexes for `event_id` and `dedupe_hash` are created (or enforce via data cleanup) so `ON CONFLICT DO NOTHING` actually dedupes (AK-AUD-003).
- **P1:** Align stats counters with unified `public.analytics_events` (or re-enable legacy writes deliberately) to prevent stale view metrics (AK-AUD-004).
- **P1:** Validate client telemetry payloads to include UUID `event_id`/`session_id` and required app metadata; otherwise ingestion will drop events (AK-AUD-002).

## Files Reviewed
- `backend/src/services/statsService.js`
- `backend/src/middleware/apiTelemetry.js`
- `backend/src/routes/analytics.js`
- `backend/src/routes/adminAnalytics.js`
- `backend/src/services/webAnalyticsService.js`
- `backend/src/db/schemaGuards.js`
- `backend/src/server.js`
- `backend/migrations/026_web_analytics.sql`
- `backend/migrations/027_analytics_events.sql`
- `backend/migrations/028_analytics_events_expand.sql`
- `backend/migrations/030_analytics_events_hardening.sql`
- `backend/migrations/031_analytics_events_ingest_and_dedupe.sql`
- `backend/migrations/032_backfill_web_analytics_events.sql`
- `backend/src/db/schema.sql`
