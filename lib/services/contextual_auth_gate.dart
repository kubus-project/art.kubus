import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pending_action_intent.dart';
import '../providers/deferred_onboarding_provider.dart';
import '../providers/pending_action_provider.dart';
import '../services/telemetry/telemetry_service.dart';
import '../widgets/auth/contextual_activation_sheet.dart';
import 'backend_api_service.dart';

/// Gates identity-required actions without blocking public content viewing.
///
/// Public art stays public: this is only reached when a visitor attempts an
/// action that needs an identity. When that happens they get a contextual,
/// value-first surface explaining what an account gives them — not a demand to
/// sign in — and the attempted action is remembered so it can be offered back
/// to them afterwards.
///
/// The gate still never replays work itself. It returns `false` for an
/// unauthenticated visitor, and any captured [PendingActionIntent] is surfaced
/// after authentication as an explicit confirmation. Actions that are
/// financial, wallet, DAO, claim-related or otherwise privileged simply omit
/// the intent descriptors, so nothing about them is ever carried across the
/// auth boundary.
class ContextualAuthGate {
  const ContextualAuthGate();

  /// Returns true when the caller may proceed immediately.
  ///
  /// [actionLabel] is the human verb used for the generic fallback headline and
  /// for accessibility. Supply [actionType], [targetType] and [targetId]
  /// together to capture a replayable intent; omit them for privileged actions.
  Future<bool> ensureAuthenticated(
    BuildContext context, {
    required String actionLabel,
    required String returnRoute,
    PendingActionType? actionType,
    PendingActionTargetType? targetType,
    String? targetId,
    String? targetLabel,
    String? markerId,
    String? sourceScreen,
    Map<String, String> returnArguments = const <String, String>{},
  }) async {
    if (BackendApiService().hasAuthSession) return true;

    final telemetry = TelemetryService();
    final actionKey = actionType?.storageValue ?? 'other';
    final targetKey = targetType?.storageValue ?? 'other';
    final screen =
        (sourceScreen ?? '').trim().isEmpty ? 'unknown' : sourceScreen!.trim();

    unawaited(telemetry.trackProtectedActionClicked(
      actionType: actionKey,
      targetType: targetKey,
      sourceScreen: screen,
    ));

    // A visitor who already started an account and left it unverified should
    // finish that account rather than be offered a new one.
    final resumed = _maybeResumeIncompleteOnboarding(context);
    if (resumed) return false;

    final intent = _buildIntent(
      actionType: actionType,
      targetType: targetType,
      targetId: targetId,
      targetLabel: targetLabel,
      returnRoute: returnRoute,
      returnArguments: returnArguments,
      markerId: markerId,
      sourceScreen: screen,
    );

    if (intent != null) {
      try {
        await context.read<PendingActionProvider>().capture(intent);
      } catch (_) {
        // Outside the app provider tree (tests, isolated widgets): the gate
        // still works, it just cannot offer a continuation afterwards.
      }
    }
    if (!context.mounted) return false;

    unawaited(telemetry.trackAuthGateViewed(
      actionType: actionKey,
      targetType: targetKey,
      sourceScreen: screen,
    ));

    final choice = await showContextualActivationSheet(
      context,
      actionType: actionType,
      targetType: targetType,
      fallbackActionLabel: actionLabel,
    );
    if (!context.mounted) return false;

    if (choice == ActivationGateChoice.dismissed) {
      unawaited(telemetry.trackAuthGateDismissed(
        actionType: actionKey,
        targetType: targetKey,
        sourceScreen: screen,
      ));
      return false;
    }

    unawaited(telemetry.trackAuthMethodSelected(
      method: switch (choice) {
        ActivationGateChoice.google => 'google',
        ActivationGateChoice.email => 'email',
        ActivationGateChoice.signIn => 'existing_account',
        ActivationGateChoice.dismissed => 'none',
      },
      actionType: actionKey,
      targetType: targetKey,
    ));

    // The same validation the intent gets. Without it an unsafe route that
    // `_buildIntent` already rejected would still reach the navigator.
    final safeReturnRoute = PendingActionIntent.isSafeInternalRoute(returnRoute)
        ? returnRoute
        : '/main';
    final arguments = <String, Object?>{'redirectRoute': safeReturnRoute};
    if (returnArguments.isNotEmpty) {
      arguments['redirectArguments'] = Map<String, String>.from(
        returnArguments,
      );
    }

    // Pushed, not replaced: the browsing stack underneath stays intact so the
    // system back gesture returns the visitor to the entity they came from.
    await Navigator.of(context).pushNamed(
      choice == ActivationGateChoice.signIn ? '/sign-in' : '/register',
      arguments: arguments,
    );
    return false;
  }

  /// Resumes a half-finished account instead of offering a fresh one.
  bool _maybeResumeIncompleteOnboarding(BuildContext context) {
    try {
      final deferred = context.read<DeferredOnboardingProvider>();
      return deferred.maybeShowOnboardingForProtectedAction(context);
    } catch (_) {
      // Contexts outside the application provider tree keep the normal
      // contextual activation behavior.
      return false;
    }
  }

  PendingActionIntent? _buildIntent({
    required PendingActionType? actionType,
    required PendingActionTargetType? targetType,
    required String? targetId,
    required String? targetLabel,
    required String returnRoute,
    required Map<String, String> returnArguments,
    required String? markerId,
    required String sourceScreen,
  }) {
    if (actionType == null || targetType == null) return null;
    final id = (targetId ?? '').trim();
    if (id.isEmpty) return null;

    return PendingActionIntent.create(
      actionType: actionType,
      targetType: targetType,
      targetId: id,
      targetLabel: targetLabel,
      returnRoute: returnRoute,
      returnArguments: returnArguments,
      markerId: markerId,
      sourceScreen: sourceScreen,
    );
  }
}
