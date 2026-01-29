# App Architecture & Performance Audit

## Summary
Multiple providers/services are well-structured with caching and in-flight dedupe in key places (notably marker and stats services). However, several independent timers and global refresh triggers overlap, which can cause repeated fetch loops, fan-out refresh storms, and unnecessary backend load—especially on startup and when map/chat/notification flows run concurrently.

## Findings

### AK-AUD-001 — Startup warm-up fan-out + global refresh broadcast
**Evidence:** `lib/services/app_bootstrap_service.dart` lines 39–132; `lib/core/app_initializer.dart` lines 238–244.
- Warm-up spawns many provider initializes/fetches concurrently and then calls `appRefreshProvider.triggerAll()` (global refresh broadcast).
- This can trigger multiple downstream refresh handlers in providers/screens (some of which already do their own initialization/polling), amplifying network load and UI churn.

**Fix strategy:**
- Split warm-up into priority tiers (P0 UI-critical, P1 secondary), staggering noncritical calls.
- Replace `triggerAll()` with targeted refresh triggers (notifications/chat/community) and/or compare last-fetched timestamps to skip redundant fetches.
- Add “cooldown” guard in refresh listeners to avoid immediate repeats after warm-up.

---

### AK-AUD-002 — Map screen polling + proximity timers add recurring load
**Evidence:** `lib/screens/map_screen.dart` lines 686–743, 1963–1972.
- Map initialization starts a 10s location polling timer and also starts a 10s proximity check timer.
- Location stream is also enabled when available (lines 1925–1993), meaning both stream updates and periodic timers can fire, potentially triggering marker refreshes.

**Fix strategy:**
- Prefer stream-driven location updates and disable periodic polling when stream is active.
- Gate proximity checks behind app visibility and/or reduce frequency based on movement distance.
- Use a shared scheduler (or a single timer) to coalesce location + proximity checks.

---

### AK-AUD-003 — Chat open-conversation polling every 5s duplicates socket events
**Evidence:** `lib/providers/chat_provider.dart` lines 1675–1714; subscription monitor at lines 722–739.
- `openConversation` starts a 5s polling loop to fetch messages, even though socket events already deliver updates.
- This is a tight cadence and can keep polling even when no changes occur.

**Fix strategy:**
- Only poll when socket is disconnected or in a “missed events” state.
- Use incremental fetch by last message id/time; backoff on empty responses.
- Stop polling when app is backgrounded or when conversation view is not visible.

---

### AK-AUD-004 — Notifications auto-refresh + subscription monitor + activity refresh cascade
**Evidence:** `lib/providers/notification_provider.dart` lines 173–213, 225–245; `lib/providers/recent_activity_provider.dart` lines 56–109, 66–78.
- Notifications refresh loop runs every 45s, with a subscription monitor every 25s and scheduled sync with an 8s minimum interval. This can cause frequent refreshes.
- RecentActivityProvider refreshes when notifications report new content, pulling remote + local notifications and recent actions each time.

**Fix strategy:**
- Use a single notifications sync cadence; reserve frequent checks for active foreground only.
- Push-only updates where possible; refresh activity feed incrementally (diff by id/timestamp).
- Debounce recent activity refresh more aggressively or only refresh the section impacted.

---

### AK-AUD-005 — Presence auto-refresh every 10s plus heartbeat every 30s
**Evidence:** `lib/providers/presence_provider.dart` lines 11–199, 225–248.
- Presence auto-refresh runs every 10s for watched wallets; heartbeat runs every 30s for signed-in users. With many watched wallets, this can generate frequent batch calls.

**Fix strategy:**
- Scale refresh interval by watched wallet count (e.g., 10s → 30–60s for large lists).
- Pause auto-refresh when no screens need presence or app is backgrounded.
- Use exponential backoff when responses are unchanged.

---

### AK-AUD-006 — Marker + stats caching/dedupe are good mitigations (keep & reuse patterns)
**Evidence:**
- Marker caching and in-flight dedupe: `lib/services/map_marker_service.dart` lines 66–188, 205–239.
- Stats cache/dedupe: `lib/services/stats_api_service.dart` lines 11–187.
- Artwork in-flight dedupe: `lib/providers/artwork_provider.dart` lines 27–99.

**Fix strategy:**
- Reuse these patterns for other providers with repeated fetch loops (notifications, chat message polling, activity refresh).

## Top P0/P1 Hotspots

### P0
1) Chat open-conversation polling every 5s (backend load + redundant with sockets). Evidence: `lib/providers/chat_provider.dart` lines 1675–1714.
2) Map screen dual timers (location + proximity) while streams are active. Evidence: `lib/screens/map_screen.dart` lines 686–743, 1963–1972.

### P1
1) Warm-up fan-out + global refresh broadcast (startup thundering herd). Evidence: `lib/services/app_bootstrap_service.dart` lines 39–132; `lib/core/app_initializer.dart` lines 238–244.
2) Notification auto-refresh + activity refresh cascade. Evidence: `lib/providers/notification_provider.dart` lines 173–245; `lib/providers/recent_activity_provider.dart` lines 56–109.
3) Presence auto-refresh cadence. Evidence: `lib/providers/presence_provider.dart` lines 11–199.

## Files Reviewed
- `lib/services/app_bootstrap_service.dart`
- `lib/core/app_initializer.dart`
- `lib/providers/app_refresh_provider.dart`
- `lib/screens/map_screen.dart`
- `lib/screens/desktop/desktop_map_screen.dart`
- `lib/providers/notification_provider.dart`
- `lib/providers/recent_activity_provider.dart`
- `lib/providers/chat_provider.dart`
- `lib/providers/presence_provider.dart`
- `lib/services/map_marker_service.dart`
- `lib/services/stats_api_service.dart`
- `lib/providers/artwork_provider.dart`

## Updates & Evidence (Jan 29, 2026)

### AK-AUD-001 — Warm-up fan-out + view-aware refresh
**Change:** Warm-up now runs in two tiers (P0 then P1 with a short delay), and global `triggerAll()` was replaced by targeted, view-aware refresh triggers.

**Evidence:**
- `lib/services/app_bootstrap_service.dart` now splits warm-up into `p0`/`p1`, adds a 650ms stagger, and calls `triggerNotifications/Chat/Community/Profile(onlyIfActive: true)`.
- `lib/providers/app_refresh_provider.dart` now tracks view visibility + foreground state, includes trigger cooldowns, and exposes debug counters.
- `lib/main_app.dart` marks active views on tab changes.
- `lib/main.dart` sets foreground state and uses `triggerForegroundRefresh()` on resume.

**Dev-only evidence hooks:**
- `AppRefreshProvider.debugCounters` increments for trigger/skip/cooldown paths.
- `AppBootstrapService` logs tier counts in debug builds.

---

### AK-AUD-002 — Map polling + proximity timers
**Change:** Proximity checks are now adaptive and visibility-aware (only scheduled when the map is visible + app foreground). Interval adjusts based on movement.

**Evidence:**
- `lib/screens/map_screen.dart` now uses `_scheduleProximityCheck()` and a movement-based interval (8–20s).

**Dev-only evidence hooks:**
- Debug counters `_debugProximityChecks`/`_debugProximitySkips`, periodic debug logging every 20 checks.

---

### AK-AUD-004 — Notifications refresh cadence + overlap reduction
**Change:** Consolidated to a single cadence timer that also handles subscription checks; sync scheduling now avoids overlaps and re-schedules intelligently.

**Evidence:**
- `lib/providers/notification_provider.dart` removes dual timers and uses `_ensureCadenceTimer()` + `_maybeCheckSubscription()`.
- `_scheduleServerSync()` now tracks due-at time to avoid longer replacements; skips when in-flight.
- `RecentActivityProvider` now throttles refresh calls to prevent cascades.

**Dev-only evidence hooks:**
- `NotificationProvider.debugCounters` (`cadenceTicks`, `syncs`, `skippedSyncs`).
- `RecentActivityProvider.debugCounters` (`refreshCount`, `refreshSkipped`).

---

### AK-AUD-005 — Presence cadence
**Change:** Presence auto-refresh now adapts based on watched-wallet count, app foreground, and relevant view activity. Heartbeat pauses when backgrounded.

**Evidence:**
- `lib/providers/presence_provider.dart` computes adaptive interval and restarts timers on view/foreground changes.

**Dev-only evidence hooks:**
- `PresenceProvider.debugCounters` (`autoRefreshTicks`, `autoRefreshSkipped`, `heartbeats`).

## Verification
- Not run in this update (no automated test run requested). Manual verification suggested:
	- Launch app, switch tabs to community/profile and observe debug counters/logs.
	- Background/foreground app and confirm notification cadence resumes with targeted refresh.
