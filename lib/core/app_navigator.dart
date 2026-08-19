import 'dart:async';

import 'package:flutter/material.dart';

/// Global navigator key used for cross-cutting flows (e.g. deep links, auth).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Serializes startup navigation behind [AppInitializer]'s routing decision.
///
/// `AppInitializer` hydrates providers and decides the deterministic cold-start
/// destination asynchronously (auth/session restore, config, wallet — this can
/// take several seconds). Independent startup listeners that are wired up
/// immediately in `initState` (notification-tap routing, the live app-links
/// stream) used to be free to push/replace routes on top of the still-loading
/// splash during that window. Whichever fired last won, non-deterministically
/// landing the visitor on an unrelated screen instead of `AppInitializer`'s own
/// decision — this is the cold-start route class Part 15 targets.
///
/// Cold-start deep links are unaffected: they are seeded into `DeepLinkProvider`
/// / `AuthDeepLinkProvider` for `AppInitializer` to consume directly, not routed
/// through this gate.
class AppStartupGate {
  AppStartupGate._();

  static Completer<void> _completer = Completer<void>();
  static bool _ready = false;

  /// True once `AppInitializer` has completed its routing decision.
  static bool get isReady => _ready;

  /// Resolves once `AppInitializer` has completed its routing decision.
  static Future<void> get ready => _completer.future;

  /// Marks startup routing complete. Idempotent — safe to call from every
  /// `AppInitializer` exit path (including the watchdog timeout).
  static void markReady() {
    if (_ready) return;
    _ready = true;
    _completer.complete();
  }

  /// Runs [action] once startup routing has completed, immediately if it
  /// already has.
  static void runWhenReady(void Function() action) {
    if (_ready) {
      action();
      return;
    }
    unawaited(_completer.future.then((_) => action()));
  }

  /// Restores pristine (not-ready) state. This is process-lifetime state in
  /// production — one cold start, one gate — so only a test harness spanning
  /// multiple simulated app starts needs this.
  @visibleForTesting
  static void reset() {
    _completer = Completer<void>();
    _ready = false;
  }
}

