# App Telemetry (app.kubus.site)

This document describes how to verify the Flutter client telemetry pipeline end-to-end:

`Flutter app -> POST /api/analytics/app -> public.analytics_events -> Admin Console charts`.

## Event types (client telemetry)

All events are inserted into `public.analytics_events` with:
- `event_category = 'app'`
- `property = 'app.kubus.site'` and `metadata.property = 'app.kubus.site'`
- `event_id` (UUID v4), `session_id` (UUID v4), `ts` (UTC)

Event types emitted by the Flutter app:
- `screen_view`
- `screen_duration` (`metadata.duration_ms`)
- `onboarding_enter`
- `onboarding_complete` (`metadata.onboarding_reason`)
- `signin_view`
- `signin_attempt` (`metadata.method`)
- `signin_success` (`metadata.method`)
- `signin_failure` (`metadata.method`, `metadata.error_class`)
- `signup_view`
- `signup_attempt` (`metadata.method`)
- `signup_success` (`metadata.method`)
- `signup_failure` (`metadata.method`, `metadata.error_class`)

## Privacy guarantees

- No PII in app telemetry payloads.
- App-category analytics (`event_category = 'app'`) do **not** store IP address or User-Agent in `public.analytics_events`.
- `actor_user_id` is only stored when it is a UUID; otherwise omitted.

## Feature flag

Client telemetry is controlled by the existing feature flag system:
- Build-time: `-DANALYTICS_APP_ENABLED=true|false`
- Runtime preference: `SharedPreferences['enableAnalytics']`

In production builds, telemetry defaults to enabled unless `ANALYTICS_APP_ENABLED` is explicitly disabled.

## Manual verification checklist

### 1) App emits telemetry

1. Launch the app.
2. Navigate through:
   - Onboarding screens (enter + complete)
   - Sign-in screen
   - Attempt sign-in with at least one method (email / google / wallet / guest)
   - Complete a successful sign-in (if possible)
3. Navigate between a few screens/tabs so `screen_view` and `screen_duration` events are produced.

Expected:
- `onboarding_enter` exists once per session.
- `signin_view` exists when the sign-in route is visited.
- `signin_attempt` emitted per attempted method (no duplicates on rebuild).
- `screen_duration` events have `metadata.duration_ms > 0`.

### 2) Verify DB inserts (`public.analytics_events`)

Run these SQL snippets against the Postgres DB:

```sql
-- Latest client telemetry events
SELECT
  ts,
  event_type,
  ingest_path,
  session_id,
  actor_user_id,
  metadata->>'screen_name' AS screen,
  metadata->>'flow_stage' AS flow_stage,
  metadata->>'method' AS method,
  metadata->>'success' AS success,
  metadata->>'duration_ms' AS duration_ms
FROM public.analytics_events
WHERE event_category = 'app'
  AND COALESCE(property, metadata->>'property') = 'app.kubus.site'
  AND ingest_path = '/analytics'
ORDER BY ts DESC
LIMIT 100;

-- Dedupe check: event_id must be unique
SELECT event_id, COUNT(*) AS n
FROM public.analytics_events
WHERE event_category = 'app'
  AND ingest_path = '/analytics'
  AND event_id IS NOT NULL
GROUP BY event_id
HAVING COUNT(*) > 1;
```

Expected:
- Dedupe query returns zero rows.
- All rows show `metadata.property = 'app.kubus.site'` and required metadata fields (`screen_name`, `flow_stage`, `app_version`, `build_number`, `platform`, `env`).

### 3) Verify Admin Console charts

1. Open the Admin Console.
2. Go to Analytics and select site `app.kubus.site`.
3. Pick a range like `7d` and set ingest filter to `/analytics` (client telemetry).

Expected panels under **App Telemetry**:
- Funnel overview:
  - Bars for onboarding -> sign-in view -> attempt -> success.
  - Table includes sign-up stages (view/attempt/success).
- Sign-in methods:
  - Attempts/successes/failures per method.
- Top screens:
  - Most viewed screens (`screen_view`) + route.
- Time spent:
  - Avg duration chart + overall stats (avg/p50/p95) + table.
- Duration distribution:
  - Histogram buckets (0-5s, 5-15s, ..., 300s+).
- Retention (proxy):
  - New vs returning users and sessions per day + table.

## Troubleshooting

- If Admin shows no data, confirm ingest filter is `/analytics` and the selected date range includes your test session.
- If the app appears to emit events but DB is empty, verify `/api/analytics/app` is reachable and `ANALYTICS_EVENTS_ENABLED` is not disabled on the backend.
- If session context (screen/flow/session_id) is missing from server-side app events, ensure the app is sending headers:
  - `x-kubus-session-id`
  - `x-kubus-screen-name`
  - `x-kubus-screen-route`
  - `x-kubus-flow-stage`

