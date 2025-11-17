Summary of changes performed on Nov 14, 2025

Purpose
- Implement server-side notifications, de-duplication, reliable per-user realtime delivery, and client wiring.
- Fix notification visibility (should only go to intended recipient), resolve sender identity in notifications, and harden socket subscription/authentication.
- Update Flutter UI to show notification badge with accent color, shake animation and badge bubble; make recent activity entries tappable and include likes/comments activity.

High-level changes (what, where)

1) Backend — realtime + notifications
- File: `backend/src/routes/notifications.js`
  - Added dedupe-aware inserts using `dedupe_key` and `ON CONFLICT (dedupe_key) DO NOTHING`.
  - Notification helper functions added/updated: `createLikeNotification`, `createCommentNotification`, `createMentionNotification`, `createReplyNotification`, `createFollowNotification`, `createAchievementNotification`.
  - Each helper resolves `sender_wallet` to a canonical wallet address (tries `profiles` by wallet, then `users.id -> users.wallet_address`) and resolves a human-friendly `senderName` (display_name or username) for notification text.
  - Emits use `io.to(`user:${wallet.toLowerCase()}`)` (normalized to lowercase) and call an `emitNotificationAudit(io, ...)` helper to log audit info.

- File: `backend/src/server.js`
  - Socket handshake auth middleware already present (decodes JWT and attaches `socket.data.user`).
  - Reworked `subscribe:user`/`unsubscribe:user` handlers to:
    - Require/validate handshake auth (`socket.data.user`), resolve token wallet (token.walletAddress or users.id -> wallet_address), and only allow joining `user:<wallet>` if authorized.
    - Normalize room names to lowercase when joining/leaving.
    - Add structured logs: `subscribe:ok`, `subscribe:error`, `subscribe:leave` with socket id and wallet.
  - Guarded `io.emit` to prevent accidental global broadcast of `notification:new`.

- DB migration/schema
  - Ensured `notifications` table includes `dedupe_key VARCHAR(255)` and unique index `ux_notifications_dedupe_key` (applied via ALTER/CREATE INDEX when migrating).
  - Performed a DB backfill attempt to replace any historical `users.id` text occurrences in notification `sender_wallet` / `user_wallet` columns with `users.wallet_address`. The query ran safely and reported zero rows affected (no mismatches at that time).

2) Backend — small operational helpers
- Added `emitNotificationAudit(io, targetWallet, dedupeKey)` to log when a notification is emitted (id, user, sender, type).
- Ensured every emit goes to canonical lowercase room names.

3) Flutter client — socket & UI
- File: `lib/services/socket_service.dart`
  - New singleton `SocketService` that sends JWT token in handshake `auth` and `Authorization` header.
  - `connect(baseUrl)` sets up the socket and `subscribeUser(walletAddress)` emits `subscribe:user` then registers `notification:new` handler only after `subscribe:ok`. `unsubscribeUser` removes handler and emits unsubscribe request.

- File: `lib/providers/web3provider.dart`
  - Wired to call `SocketService.connect()` and `SocketService.subscribeUser(address)` after successful backend sync.
  - Pushes incoming server notifications into `PushNotificationService.showCommunityInteractionNotification` (local display logic already available).

- UI: Notification visual and interactions
  - File: `lib/main_app.dart`
    - Added `_NavItemWithBadge` for the Community tab (index == 3). It
      - Polls `BackendApiService().getUnreadNotificationCount()` every 10s (initial fetch on init).
      - Displays a circular badge (accent color) with unread count above the icon.
      - Triggers a shake animation when new unread notifications arrive.
      - Badge and icon use `ThemeProvider.accentColor` so they match app accent.

  - File: `lib/web3/artist/artist_analytics.dart`
    - Enhanced `_buildRecentActivity()` to:
      - Include a summary "likes" activity entry per artwork when `likesCount > 0`.
      - Keep comment activity extraction (most recent comment per artwork).
      - Make each activity row tappable: if `activity['artwork']` exists, tapping navigates to `ArtDetailScreen(artworkId: ...)`.

  - File: `lib/screens/community_screen.dart`
    - Interaction handlers for posts (like, comment, share) were left intact; the optimistic UI toggles and service calls are used.
    - The notifications modal (`_showNotifications`) already normalized local + remote notifications and provides navigation to post/comments when tapped.

Files changed (concise list)
- backend/src/routes/notifications.js
- backend/src/server.js
- backend/src/db/migrate.js (migration adjustments earlier)
- lib/services/socket_service.dart
- lib/services/backend_api_service.dart (exposed/getUnreadNotificationCount used)
- lib/main_app.dart
- lib/web3/artist/artist_analytics.dart
- lib/screens/community_screen.dart (no major structural changes, but logic was confirmed)

Why these changes
- Users were receiving notifications globally and with placeholder sender text. Root causes:
  - Socket rooms were inconsistent (case mismatches) and `subscribe:user` allowed unauthorized joins.
  - Some notification rows could contain non-canonical sender identifiers.
  - Clients sometimes listened to global `notification:new` events before verifying subscription.

What I did to fix
- Forced canonical, lowercase per-user rooms and emitted only to those rooms.
- Handshake-level token validation used by `subscribe:user` (server resolves wallet from token when needed).
- Client sends JWT in handshake `auth` and waits for `subscribe:ok` before registering `notification:new` handlers.
- Resolved sender display names server-side and ensured `sender_wallet` stores the canonical wallet address when creating notifications.
- Added dedupe semantics so repeated identical notifications don't spam users.
- Added UI feedback (badge, accent color, shake) so notification state is visible and obvious.

How to test (quick steps)
1) Backend
- Restart backend (inside repo root):

```powershell
cd backend
docker-compose up -d --build backend
# or if running locally: npm run dev (adjust to your dev script)
```

- Watch logs for subscribe events and notification emits:
  - Look for `subscribe:ok` / `subscribe:error` messages and `Emitting notification` audit entries.

2) Client
- Rebuild the Flutter app (physical device for AR features):

```powershell
cd G:\WorkingDATA\art.kubus\art.kubus
flutter pub get
flutter run -d <your-device>
```

- Steps to reproduce a notification:
  - Login as User A on device 1 and ensure it calls `SocketService.subscribeUser(wallet)` (check logs).
  - Login as User B on device 2 and like a post by User A (or comment and mention `@username`).
  - Verify:
    - Backend logs show notification insertion and `Emitting notification` audit log.
    - Socket logs show `io.to('user:<a_wallet>')` emit (no global `notification:new` broadcasts).
    - Device 1 shows badge count update and shake animation, modal shows the notification colored with accent color, tapping notification opens the post/comments.

Notes, caveats, and next steps
- The `Nav` badge uses polling (every 10s). For real-time UX, wire the `SocketService` to update unread count on `notification:new` events instead of polling.
- The "likes" activity in `ArtistAnalytics` is a summary derived from `likesCount` and uses `createdAt` as an approximate timestamp. For accurate "when liked" events the backend should store `last_liked_at` or per-like events with timestamps.
- Ensure every user has a `profiles` row so `sender_display_name` is always available. Consider auto-create profile on first login or a migration to backfill from `users`.
- CI/lint: After these changes run `flutter analyze` and your backend linter. I ran local edits and adjusted imports/Math usage, but please run the project's full static analysis in your environment.

If you want I can:
- Run an automated end-to-end smoke test (create two test users, like/comment, validate DB + socket logs + client badge reception).
- Replace polling with socket-driven unread count updates in the app.
- Add a small debugging endpoint to the backend to list active socket rooms for easier debugging.

---
Detailed file-by-file diffs and larger context are present in the repository (I edited the files listed above). If you'd like, I can open a PR, run unit/integration tests, and attach logs from a smoke run.

# Debug Menu (Dev-only)

Purpose: provide a global developer/debug menu (visible only in non-release builds) to simulate notifications and other flows for QA without requiring a second device or special backend scripts.

Where to add it
- Widget: `lib/widgets/debug_menu.dart` — create a `DebugMenu` widget offering buttons and small forms to simulate events.
- Integration: expose the menu in `lib/main_app.dart` via a debug-only FAB, long-press on the app title, or a shake gesture. Guard with `kDebugMode` / `kReleaseMode` checks so it never appears in production.

Suggested features
- Simulate Notification: let QA supply a type (`like`, `comment`, `mention`, `reply`) and payload (sender, postId, snippet) and dispatch it locally through the same app code path (via a dev-only helper).
- Clear Unreads: reset the unread badge counter used by `CommunityScreen` (expose `clearBadge()` on the screen state or a provider method).
- Emit Like / Comment / Mention Templates: quick buttons that populate useful test payloads.
- Restart Socket: disconnect and reconnect the socket and re-subscribe the current wallet.
- Toggle Mock Backend: switch between mock vs. real backend data for quicker offline testing.

Implementation notes
- Add a dev-only helper on `SocketService`: `simulateIncomingNotification(Map<String,dynamic> payload)` which iterates `_notificationListeners` and calls each with the payload. Ensure the helper is only callable in debug builds (use `assert` or `if (kDebugMode)` guards).
- `DebugMenu` should call the dev helpers (simulate notification, clear unreads, restart socket) and provide quick UI to craft payloads.
- For clearing UI state like unreads, use safe public APIs: expose `CommunityScreen.globalKey` and a `clearBadge()` method on its state, or use a provider method on `Web3Provider` that the screen subscribes to.

Safety
- Guard debug code with `kDebugMode` or `assert(() { ...; return true; }());` so it cannot be compiled into release builds.
- Avoid performing irreversible actions on production accounts (e.g., real transfers); scope debug actions to UI/state-only simulations where possible.

Quick implementation checklist
1. Create `lib/widgets/debug_menu.dart` with `DebugMenu` UI (buttons/forms for test payloads).
2. Add `SocketService.simulateIncomingNotification(payload)` (dev-only) that forwards payloads to registered listeners.
3. Add debug trigger in `main_app.dart` (FAB or long-press) guarded by `kDebugMode`.
4. Wire clear/reset actions to `CommunityScreen` and provider methods.
5. Test locally and confirm no debug artifacts exist in release builds.

If you want, I can implement the `DebugMenu` and the `simulateIncomingNotification` helper now and wire the debug FAB into `main_app.dart` behind a debug guard. Tell me whether you prefer a floating debug button, long-press opener, or shake-to-open gesture and I'll implement accordingly.
