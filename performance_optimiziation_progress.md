# Desktop Web Performance Optimization Progress

_Last updated: 2026-04-14_

## Scope
Reduce desktop web map/shell jank, background network noise, unnecessary rebuilds, and DOM/style pressure while preserving:
- feature flags
- provider-first initialization
- desktop/mobile parity
- socket-first behavior with safe fallbacks
- backend readiness/writable route contracts

## Completed

- [x] Preflight completed across all required `AGENTS.md` files (`root`, `lib/**`, `backend/**`).
- [x] Multi-angle hotspot analysis completed (frontend rebuilds/timers, map hover/anchor updates, backend route pressure, QA/regression, security constraints).
- [x] Socket-first + fallback cadence refactor landed for:
  - `lib/providers/collab_provider.dart`
  - `lib/providers/notification_provider.dart`
  - `lib/providers/presence_provider.dart`
- [x] Desktop shell refresh visibility propagation tightened in:
  - `lib/screens/desktop/desktop_shell.dart`
  - `lib/main_app.dart`
  - `lib/main.dart`
- [x] Auth/session resilience hardening for socket-first reconnect:
  - `lib/main.dart` now attempts refresh-token renewal on app resume before reconnecting socket.
- [x] Map interaction pressure reduced in:
  - `lib/features/map/controller/kubus_map_controller.dart`
  - `lib/widgets/map_overlay_blocker.dart`
- [x] Backend hot endpoint pressure reduced in:
  - `backend/src/routes/health.js` (`/health/ready` lean caching)
  - `backend/src/routes/notifications.js` (`/unread-count` caching + invalidation)
- [x] Backend writable-role safety tightened for socket-first rollout:
  - `backend/src/routes/messages.js` write routes now enforce `requireWritableNode`
  - `backend/src/routes/collab.js` mutation routes now enforce `requireWritableNode`
  - `backend/src/routes/notifications.js` mutation routes now enforce `requireWritableNode`
  - `backend/src/routes/presence.js` write routes (`visit`, `ping`) now enforce `requireWritableNode`
- [x] Focused validation completed after the main implementation wave:
  - focused Flutter tests passed
  - touched-file analyze passed
  - targeted backend tests passed

## Remaining / Continuing Now

- [x] Tighten remaining chat fallback polling behavior (`ChatProvider`) to be fully socket-health + visibility aware.
- [x] Reduce residual desktop nav rebuild scope in `desktop_navigation.dart` (badge/profile sections) where broad provider watches still repaint too much.
- [x] Re-run focused validation after continuation edits:
  - focused Flutter tests
  - touched-file analyze
  - targeted backend tests
- [x] Final pass on handoff notes and residual risk checklist.

## Active Work Log

### Current focus
1. Final handoff and risk/checklist confirmation.

### Verification notes captured
- Focused Flutter task (`Flutter: Safe test (focused community+desktop)`): passed.
- `flutter analyze` on touched files: passed (`No issues found`).
- Targeted backend tests (`healthWritableRoute`, `corsAllowedHeaders`): passed.
- Extended backend route regression tests passed:
  - `messagesRoutesAuth`
  - `collabRoutesSocketEmits`
  - `notificationsRoutesAuth`
  - `presenceRoutes`
  - plus `healthWritableRoute` and `corsAllowedHeaders`
