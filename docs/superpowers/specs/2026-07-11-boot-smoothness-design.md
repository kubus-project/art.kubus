# Slice 5 — Boot Smoothness & Diagnostics Signal (network slice, recalibrated)

Date: 2026-07-11
Status: Executing under the standing UI-overhaul mandate (roadmap item 5,
scoped from live measurement instead of speculative prefetch work).

## Measurement (Playwright network capture of a guest boot, web debug)

- **16× `POST /api/diagnostics/error` per boot.** Payload capture shows the
  telemetry is *working correctly* — the app throws real framework errors on
  every launch:
  1. `setState()/markNeedsBuild() called during build` on
     `TutorialOverlayScope` — stack: `tutorial_overlay_controller.dart:187
     bindDriver` ← `map_screen.dart _syncRootTutorialBinding` ←
     `didChangeDependencies` (build phase).
  2. Same error on an `AnimatedBuilder`, same bind path.
  3. `LayoutBuilder does not support returning intrinsic dimensions` —
     framework-only stack (intrinsics chain through shifted_box); owner not
     yet identified. **Documented, deferred** (needs its own debugging
     session; candidate: dialog/OverflowBar or IntrinsicHeight measuring a
     LayoutBuilder subtree).
  4. Every exception is **double-posted** (once as `FlutterError`, once as
     `Zone`/fatal) because the dedupe signature includes the source.
- Duplicate `/api/artworks` + `?source=orbit` requests are the *intentional*
  orbit fallback after a failed primary — not a dedupe bug. No change.
- `captureHttpFailure` already has guest-401 skip + 5-min dedupe. No change.

## Design

1. **`TutorialOverlayController._notifySafely()`**: when
   `SchedulerBinding.schedulerPhase == persistentCallbacks` (build/layout in
   progress), defer `notifyListeners()` to a post-frame callback. Applied to
   all mutating entry points (`bindDriver`, `unbindDriver`,
   `deactivateOwner`, driver-change relay). Fixes errors 1–2 for both map
   screens at the controller level, no call-site changes.
2. **Cross-source dedupe in `DiagnosticsClient.captureError`**: drop
   `source` from the dedupe signature so the Zone handler re-report of the
   same exception (same message + stack head, within the 15 s window) is
   suppressed. Halves boot error volume without losing distinct errors.

## Verification bar

- Boot capture: diagnostics posts drop from 16 to ≤ 2 (the LayoutBuilder
  pair collapses to 1; bind errors gone entirely).
- Tutorial tests (`test/widgets/tutorial/`, map tutorial suites) green;
  full suite +1235 ~1 -1 baseline; analyze/custom_lint clean.
