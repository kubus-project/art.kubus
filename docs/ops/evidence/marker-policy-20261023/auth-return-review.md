# Auth return preservation review

Date: 2026-10-23
Review type: read-only source review
App source: `G:\kubus-build-084\s27-public-entry-app` at `085726e76b24c1a240f37a99d469e897aba17098` (clean worktree)

## Finding

`PendingActionIntent.create` intentionally removes the query and fragment from `returnRoute` before validating and persisting the route (`lib/models/pending_action_intent.dart:338-343`). The regression test asserts that `/a/artwork-1?next=https://evil.example#frag` round-trips as `/a/artwork-1` (`test/services/pending_action_intent_test.dart:95-107`). `isSafeInternalRoute` establishes that a route stays local and rejects path separator/traversal tricks; it does not validate the meaning of application query keys (`lib/models/pending_action_intent.dart:148-190`). The path-only rule is therefore a defensible boundary against carrying attacker-controlled routing, callback, proof, or token parameters through a persisted auth return. Restoring arbitrary query/fragment strings is not a safe way to satisfy continuity.

This drops more than hostile values. Public entity return routes can come directly from `PublicEntityTakeoverProvider.returnRouteFor` (`lib/screens/art/art_detail_screen.dart:140-148`; `lib/providers/public_entity_takeover_provider.dart:265-273`), and `PostAuthCoordinator` uses a restored pending intent's `returnRoute` and paired `returnArguments` for the post-auth redirect (`lib/services/post_auth_coordinator.dart:407-416`). Thus query and fragment context on that serialized path is lost. The app also has a safe typed map-entry contract for `lat`, `lng`, and `z`, which validates coordinate ranges and clamps zoom (`lib/features/map/shared/map_entry_camera.dart:6-47`; `lib/main.dart:1367-1374`). The generic path-only mechanism does not preserve that typed state.

The continuation behavior itself remains explicit: `PendingActionContinuationHost` asks for confirmation and only then calls `provider.confirm` (`lib/widgets/auth/pending_action_continuation.dart:88-115`); `PendingActionExecutor` performs the confirmed action (`lib/services/pending_action_executor.dart:97-125`). Coordinator-supplied browser evidence reports entity return and an explicit like prompt with no automatic replay. That evidence does not cover broad query/fragment auth-state preservation.

## Acceptance recommendation

The owner accepted option A for 0.8.5: accept canonical entity/auth return plus explicit action confirmation; arbitrary navigation query/fragment preservation across persisted auth return is excluded from this acceptance. This is an explicit contract exception, not a claim that arbitrary query parameters or fragments are preserved. No app source change is requested. The coordinator reports mock-UI auth flow evidence; real-backend end-to-end proof remains a separate boundary and must not be inferred from that mock evidence.

A neighboring route path should be reconciled if code is changed: `ContextualAuthGate._safeReturnRoute` accepts a full local route, including query/fragment, and forwards it to onboarding (`lib/services/contextual_auth_gate.dart:308-345`), while `PendingActionIntent.create` strips those fields. This review records the inconsistency; it does not establish an exploit or authorize an auth redesign.

## Scope and evidence limits

Read the app root, `lib`, `lib/services`, `lib/providers`, `lib/screens`, and `lib/screens/desktop` agent instructions. No source files were changed. No tests were run by this reviewer. The direct-refresh, browser Back/Forward, map, and auth-flow passes above are coordinator-provided evidence, not independently rerun here.
