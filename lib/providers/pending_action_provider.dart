import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pending_action_intent.dart';
import '../providers/artwork_provider.dart';
import '../providers/saved_items_provider.dart';
import '../services/pending_action_executor.dart';
import '../services/pending_action_service.dart';
import '../services/telemetry/telemetry_config.dart';
import '../services/telemetry/telemetry_service.dart';

/// Owns the "what were you trying to do?" continuation across authentication.
///
/// The flow is deliberately explicit at every step:
///
/// 1. A guest attempts an identity-dependent action -> [capture].
/// 2. They authenticate; the app returns to the captured route.
/// 3. [restore] surfaces the intent as *awaiting confirmation* — it is never
///    replayed automatically.
/// 4. The visitor confirms -> [confirm] runs the mutation exactly once.
/// 5. Cancelling ([cancel]) drops the intent and leaves browsing untouched.
///
/// Expiry, malformed storage and unsafe routes are handled in
/// [PendingActionService] / [PendingActionIntent], so this provider only ever
/// sees an intent that is safe to act on.
class PendingActionProvider extends ChangeNotifier {
  PendingActionProvider({
    PendingActionService service = const PendingActionService(),
    PendingActionExecutor executor = const PendingActionExecutor(),
    TelemetryService? telemetry,
  })  : _service = service,
        _executor = executor,
        _telemetry = telemetry ?? TelemetryService();

  final PendingActionService _service;
  final PendingActionExecutor _executor;
  final TelemetryService _telemetry;

  PendingActionIntent? _pending;
  bool _awaitingConfirmation = false;
  bool _executing = false;

  /// In-memory exactly-once guard. Complements the persisted marker so a
  /// double tap within one session cannot start two mutations.
  final Set<String> _executedKeys = <String>{};

  PendingActionIntent? get pending => _pending;

  /// True when an intent was restored after authentication and the visitor has
  /// not yet confirmed or cancelled it.
  bool get isAwaitingConfirmation => _awaitingConfirmation && _pending != null;

  bool get isExecuting => _executing;

  /// Persists the action a guest just attempted.
  Future<void> capture(PendingActionIntent intent) async {
    if (!intent.isValid) return;
    final stamped = intent.copyWith(
      sessionId: intent.sessionId ?? _telemetry.currentSessionId,
      // Pin an intent captured while signed in to that account, so a later
      // sign-out and sign-in on the same device cannot inherit it.
      capturedByUserId: intent.capturedByUserId ?? await _currentUserId(),
    );
    final saved = await _service.save(stamped);
    if (!saved) return;
    _pending = stamped;
    _awaitingConfirmation = false;
    _executedKeys.remove(stamped.identityKey);
    notifyListeners();
  }

  /// Loads a stored intent after authentication and marks it for confirmation.
  ///
  /// Returns the intent when one is ready to be confirmed, otherwise null.
  Future<PendingActionIntent?> restore() async {
    final intent = await _service.read();
    if (intent == null) {
      if (_pending != null || _awaitingConfirmation) {
        _pending = null;
        _awaitingConfirmation = false;
        notifyListeners();
      }
      return null;
    }

    if (await _service.isCompleted(intent) ||
        _executedKeys.contains(intent.identityKey)) {
      await _service.clear();
      _pending = null;
      _awaitingConfirmation = false;
      notifyListeners();
      return null;
    }

    // An intent captured by a different account must never be offered to this
    // one — that would let one person's pending action run under another's
    // identity on a shared device.
    if (!intent.isClaimableBy(await _currentUserId())) {
      await _service.clear();
      _pending = null;
      _awaitingConfirmation = false;
      notifyListeners();
      return null;
    }

    _pending = intent;
    _awaitingConfirmation = true;
    notifyListeners();

    unawaited(_telemetry.trackPendingActionRestored(
      actionType: intent.actionType.storageValue,
      targetType: intent.targetType.storageValue,
      sourceScreen: intent.sourceScreen,
    ));
    return intent;
  }

  /// Records that the confirmation surface was shown to the visitor.
  void markConfirmationViewed() {
    final intent = _pending;
    if (intent == null) return;
    unawaited(_telemetry.trackPendingActionConfirmationViewed(
      actionType: intent.actionType.storageValue,
      targetType: intent.targetType.storageValue,
    ));
  }

  /// Runs the confirmed action exactly once and clears the intent on success.
  Future<PendingActionExecutionResult> confirm({
    required ArtworkProvider artworkProvider,
    required SavedItemsProvider savedItemsProvider,
  }) async {
    final intent = _pending;
    if (intent == null) {
      return const PendingActionExecutionResult(PendingActionOutcome.failed);
    }
    if (_executing) {
      return const PendingActionExecutionResult(PendingActionOutcome.failed);
    }
    if (_executedKeys.contains(intent.identityKey) ||
        await _service.isCompleted(intent)) {
      await _finish(intent);
      return const PendingActionExecutionResult(PendingActionOutcome.completed);
    }

    _executing = true;
    _executedKeys.add(intent.identityKey);
    notifyListeners();

    PendingActionExecutionResult result;
    try {
      result = await _executor.execute(
        intent: intent,
        artworkProvider: artworkProvider,
        savedItemsProvider: savedItemsProvider,
      );
    } finally {
      _executing = false;
    }

    if (result.didSucceed) {
      await _service.markCompleted(intent);
      unawaited(_telemetry.trackPendingActionCompleted(
        actionType: intent.actionType.storageValue,
        targetType: intent.targetType.storageValue,
      ));
      final milestone = _milestoneFor(intent.actionType);
      if (milestone != null) {
        unawaited(_telemetry.trackFirstEngagement(
          milestone: milestone,
          targetType: intent.targetType.storageValue,
        ));
      }
      await _finish(intent);
      return result;
    }

    // A failed attempt must stay retryable: release the one-shot guard so the
    // visitor can confirm again once the cause is gone.
    _executedKeys.remove(intent.identityKey);
    unawaited(_telemetry.trackPendingActionFailed(
      actionType: intent.actionType.storageValue,
      targetType: intent.targetType.storageValue,
      failureStage: result.failureStage,
    ));

    if (result.outcome == PendingActionOutcome.targetUnavailable) {
      // The target is gone; keeping the intent would only re-offer a dead
      // action on every return to the screen.
      await _finish(intent);
    } else {
      notifyListeners();
    }
    return result;
  }

  /// Visitor declined the continuation. Browsing context is untouched.
  Future<void> cancel() async {
    final intent = _pending;
    await _service.clear();
    _pending = null;
    _awaitingConfirmation = false;
    if (intent != null) _executedKeys.remove(intent.identityKey);
    notifyListeners();
  }

  /// Drops any captured intent without reporting a cancellation, e.g. on
  /// sign-out.
  Future<void> clear() async {
    await _service.clear();
    if (_pending == null && !_awaitingConfirmation) return;
    _pending = null;
    _awaitingConfirmation = false;
    notifyListeners();
  }

  /// The signed-in account, or null for a guest.
  Future<String?> _currentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = (prefs.getString('user_id') ?? '').trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  Future<void> _finish(PendingActionIntent intent) async {
    await _service.clear();
    _pending = null;
    _awaitingConfirmation = false;
    notifyListeners();
  }

  PendingActionMilestone? _milestoneFor(PendingActionType type) =>
      switch (type) {
        PendingActionType.save => PendingActionMilestone.save,
        PendingActionType.follow => PendingActionMilestone.follow,
        PendingActionType.contribute => PendingActionMilestone.contribution,
        PendingActionType.like => null,
        PendingActionType.comment => null,
      };
}
