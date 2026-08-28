import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pending_action_intent.dart';
import '../models/protected_action_requirements.dart';
import '../providers/deferred_onboarding_provider.dart';
import '../providers/pending_action_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/telemetry/telemetry_service.dart';
import '../widgets/auth/contextual_activation_sheet.dart';
import 'backend_api_service.dart';

// The gate's own parameters are these types, so callers should not need a
// second import to describe an action. Re-exporting also keeps `part` files
// (the community screens) working through their parent's import.
export '../models/pending_action_intent.dart'
    show PendingActionType, PendingActionTargetType;
export '../models/protected_action_requirements.dart';

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
    ProtectedActionRequirements requirements =
        ProtectedActionRequirements.participant,
  }) async {
    final missingStep = _missingCapabilityStep(context, requirements);
    if (missingStep == null) return true;

    final telemetry = TelemetryService();
    final actionKey = actionType?.storageValue ?? 'other';
    final targetKey = targetType?.storageValue ?? 'other';
    final screen =
        (sourceScreen ?? '').trim().isEmpty ? 'unknown' : sourceScreen!.trim();

    unawaited(
      telemetry.trackProtectedActionClicked(
        actionType: actionKey,
        targetType: targetKey,
        sourceScreen: screen,
      ),
    );

    // A cold-start visitor with a specifically persisted incomplete account
    // (not an ordinary map browser) resumes the verified step exactly once.
    if (!BackendApiService().hasAuthSession &&
        _maybeResumeIncompleteOnboarding(context)) {
      return false;
    }

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
    } else {
      try {
        await context.read<PendingActionProvider>().clear();
      } catch (_) {
        // The provider is optional outside the application tree.
      }
    }
    if (!context.mounted) return false;

    // An authenticated account that still lacks role/profile/wallet capability
    // resumes exactly that structured step. It is not an acquisition case, so
    // never show Google/email/wallet choices again.
    if (BackendApiService().hasAuthSession) {
      await _openOnboarding(
        context,
        initialStepId: missingStep,
        returnRoute: returnRoute,
        returnArguments: returnArguments,
        requiresWalletSetup: requirements.requiresWallet,
      );
      return false;
    }

    unawaited(
      telemetry.trackAuthGateViewed(
        actionType: actionKey,
        targetType: targetKey,
        sourceScreen: screen,
      ),
    );

    final choice = await showContextualActivationSheet(
      context,
      actionType: actionType,
      targetType: targetType,
      fallbackActionLabel: actionLabel,
    );
    if (!context.mounted) return false;

    if (choice == ActivationGateChoice.dismissed) {
      unawaited(
        telemetry.trackAuthGateDismissed(
          actionType: actionKey,
          targetType: targetKey,
          sourceScreen: screen,
        ),
      );
      return false;
    }

    unawaited(
      telemetry.trackAuthMethodSelected(
        method: switch (choice) {
          ActivationGateChoice.google => 'google',
          ActivationGateChoice.email => 'email',
          ActivationGateChoice.wallet => 'wallet',
          ActivationGateChoice.signIn => 'existing_account',
          ActivationGateChoice.dismissed => 'none',
        },
        actionType: actionKey,
        targetType: targetKey,
      ),
    );

    // The same validation the intent gets. Without it an unsafe route that
    // `_buildIntent` already rejected would still reach the navigator.
    final safeReturnRoute = _safeReturnRoute(returnRoute);
    if (choice == ActivationGateChoice.signIn) {
      // Explicit existing-account sign-in remains a standalone route. Its
      // post-auth coordinator applies the same capability resolution.
      await Navigator.of(context).pushNamed(
        '/sign-in',
        arguments: <String, Object?>{
          'redirectRoute': safeReturnRoute,
          'requiresWalletSetup': requirements.requiresWallet,
          if (returnArguments.isNotEmpty)
            'redirectArguments': Map<String, String>.from(returnArguments),
        },
      );
      return false;
    }

    // Protected acquisition always enters the structured account journey.
    // The account step embeds AuthMethodsPanel, so registration is not a
    // detour through `/register` and wallet auth shares the same post-auth
    // coordinator as Google and email.
    await _openOnboarding(
      context,
      initialStepId: missingStep,
      returnRoute: safeReturnRoute,
      returnArguments: returnArguments,
      requiresWalletSetup: requirements.requiresWallet,
    );
    return false;
  }

  String _safeReturnRoute(String route) =>
      PendingActionIntent.isSafeInternalRoute(route) ? route : '/main';

  Future<void> _openOnboarding(
    BuildContext context, {
    required String initialStepId,
    required String returnRoute,
    required Map<String, String> returnArguments,
    required bool requiresWalletSetup,
  }) {
    return Navigator.of(context).pushNamed(
      '/onboarding',
      arguments: <String, Object?>{
        'initialStepId': initialStepId,
        'completionRoute': _safeReturnRoute(returnRoute),
        if (returnArguments.isNotEmpty)
          'completionArguments': Map<String, String>.from(returnArguments),
        'requiresWalletSetup': requiresWalletSetup,
      },
    );
  }

  bool _maybeResumeIncompleteOnboarding(BuildContext context) {
    try {
      return context
          .read<DeferredOnboardingProvider>()
          .maybeShowOnboardingForProtectedAction(context);
    } catch (_) {
      return false;
    }
  }

  /// Resolves the first missing capability. Provider access is intentionally
  /// best-effort so isolated widgets retain the anonymous account flow.
  String? _missingCapabilityStep(
    BuildContext context,
    ProtectedActionRequirements requirements,
  ) {
    if (requirements.requiresAccount && !BackendApiService().hasAuthSession) {
      return 'account';
    }

    try {
      final profile = context.read<ProfileProvider>();
      if (requirements.requiresProfile) {
        final hinted = profile.nextStructuredOnboardingStepId;
        if (hinted == 'verifyEmail' ||
            hinted == 'role' ||
            hinted == 'profile') {
          return hinted;
        }
        if (!profile.hasHydratedProfile || profile.currentUser == null) {
          return 'profile';
        }
      }
      if (requirements.requiresWallet &&
          !context.read<WalletProvider>().hasWalletIdentity) {
        // Role/profile checks above win when they are incomplete. Otherwise
        // resume directly at wallet setup so a complete account is not made to
        // repeat onboarding it already finished.
        return 'walletConnect';
      }
    } catch (_) {
      // Provider-less tests and route shells still need account acquisition.
    }
    return null;
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
