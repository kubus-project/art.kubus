import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/onboarding_completion_navigation.dart';
import '../models/pending_action_intent.dart';
import '../models/preferred_auth_method.dart';
import '../models/protected_action_requirements.dart';
import '../providers/deferred_onboarding_provider.dart';
import '../providers/pending_action_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/telemetry/telemetry_service.dart';
import '../widgets/auth/contextual_activation_sheet.dart';
import 'backend_api_service.dart';
import '../core/startup_trace.dart';

// The gate's own parameters are these types, so callers should not need a
// second import to describe an action. Re-exporting also keeps `part` files
// (the community screens) working through their parent's import.
export '../models/pending_action_intent.dart'
    show PendingActionType, PendingActionTargetType;
export '../models/preferred_auth_method.dart' show PreferredAuthMethod;
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

  /// Gates on screen right now, keyed by the navigator they were opened on.
  ///
  /// A second request while one is open (a double tap, or a second entry point
  /// reached before the first sheet appears) is dropped rather than stacking a
  /// second sheet or capturing a second intent over the first. The flag is
  /// released before any account journey starts, so a long onboarding never
  /// holds it, and it is keyed per navigator so a torn-down tree cannot leave
  /// it stuck for the next one.
  static final Expando<bool> _presentingOn =
      Expando<bool>('ContextualAuthGate.presenting');

  /// Returns true when the caller may proceed immediately.
  ///
  /// [actionLabel] is the human verb used for the generic fallback headline and
  /// for accessibility. Supply [actionType], [targetType] and [targetId]
  /// together to capture a replayable intent; omit them for privileged actions.
  ///
  /// [requirements] names the capability the action actually needs and defaults
  /// to [ProtectedActionRequirements.accountOnly]: a visitor who only wants to
  /// save, like, follow or comment is asked for an account and for nothing
  /// else, and returns to the screen they came from the moment it exists.
  /// Actions that need more (a public identity, a creator role, a wallet) pass
  /// the matching named requirement and acquire exactly that.
  ///
  /// [onAuthJourneyStarted] runs only when the visitor actually continues into
  /// sign-in or onboarding (never when they dismiss the surface), so a caller
  /// can remember a non-replayable surface, such as a composer, to reopen
  /// once the account exists.
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
        ProtectedActionRequirements.accountOnly,
    VoidCallback? onAuthJourneyStarted,
  }) async {
    final missingStep = _missingCapabilityStep(context, requirements);
    if (missingStep == null) return true;

    final navigator = Navigator.maybeOf(context);
    if (navigator != null && _presentingOn[navigator] == true) return false;
    if (navigator != null) _presentingOn[navigator] = true;
    var presenting = navigator != null;
    void endPresentation() {
      if (!presenting || navigator == null) return;
      presenting = false;
      _presentingOn[navigator] = false;
    }

    try {
      return await _ensureAuthenticated(
        context,
        missingStep: missingStep,
        actionLabel: actionLabel,
        returnRoute: returnRoute,
        actionType: actionType,
        targetType: targetType,
        targetId: targetId,
        targetLabel: targetLabel,
        markerId: markerId,
        sourceScreen: sourceScreen,
        returnArguments: returnArguments,
        requirements: requirements,
        onAuthJourneyStarted: onAuthJourneyStarted,
        endPresentation: endPresentation,
      );
    } finally {
      endPresentation();
    }
  }

  Future<bool> _ensureAuthenticated(
    BuildContext context, {
    required String missingStep,
    required String actionLabel,
    required String returnRoute,
    required PendingActionType? actionType,
    required PendingActionTargetType? targetType,
    required String? targetId,
    required String? targetLabel,
    required String? markerId,
    required String? sourceScreen,
    required Map<String, String> returnArguments,
    required ProtectedActionRequirements requirements,
    required VoidCallback? onAuthJourneyStarted,
    required VoidCallback endPresentation,
  }) async {
    StartupTrace.publicEntry('auth_gate_triggered',
        route: returnRoute, caller: sourceScreen ?? 'ContextualAuthGate');

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

    // An interrupted account journey is resumed only now, after the attempted
    // action and its return route are captured: the visitor stays on the entity
    // they were viewing, the journey opens above it, and completing it returns
    // there for the explicit confirmation. Resuming first replaced the entity
    // and lost the mutation.
    if (!BackendApiService().hasAuthSession &&
        _maybeResumeIncompleteOnboarding(
          context,
          returnRoute: _safeReturnRoute(returnRoute),
          returnArguments: returnArguments,
          requirements: requirements,
          onAuthJourneyStarted: onAuthJourneyStarted,
        )) {
      endPresentation();
      return false;
    }

    // An authenticated account that still lacks role/profile/wallet capability
    // resumes exactly that structured step. It is not an acquisition case, so
    // never show Google/email/wallet choices again.
    if (BackendApiService().hasAuthSession) {
      endPresentation();
      onAuthJourneyStarted?.call();
      await _openOnboarding(
        context,
        initialStepId: missingStep,
        returnRoute: returnRoute,
        returnArguments: returnArguments,
        requiresWalletSetup: requirements.requiresWallet,
        requirements: requirements,
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
      // Declining the gate ends the attempt: the intent captured on the way in
      // must not survive to be offered after an unrelated later sign-in.
      await _dropCapturedIntent(context);
      return false;
    }

    // The visitor chose a way into the account journey, so the presentation is
    // over; a repeated tap from here on belongs to the journey, not the gate.
    endPresentation();

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

    onAuthJourneyStarted?.call();

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
          'requirements': requirements.storageValue,
          if (returnArguments.isNotEmpty)
            'redirectArguments': Map<String, String>.from(returnArguments),
        },
      );
      return false;
    }

    // Protected acquisition always enters the structured account journey.
    // The account step embeds AuthMethodsPanel, so registration is not a
    // detour through `/register` and wallet auth shares the same post-auth
    // coordinator as Google and email. The method the visitor just chose is
    // carried along so the account step can enter that method's state
    // directly instead of asking them to pick Google/email/wallet again.
    await _openOnboarding(
      context,
      initialStepId: missingStep,
      returnRoute: safeReturnRoute,
      returnArguments: returnArguments,
      requiresWalletSetup: requirements.requiresWallet,
      requirements: requirements,
      preferredAuthMethod: switch (choice) {
        ActivationGateChoice.google => PreferredAuthMethod.google,
        ActivationGateChoice.email => PreferredAuthMethod.email,
        ActivationGateChoice.wallet => PreferredAuthMethod.wallet,
        ActivationGateChoice.signIn || ActivationGateChoice.dismissed => null,
      },
    );
    return false;
  }

  String _safeReturnRoute(String route) =>
      PendingActionIntent.isSafeInternalRoute(route) ? route : '/main';

  Future<void> _dropCapturedIntent(BuildContext context) async {
    try {
      await context.read<PendingActionProvider>().clear();
    } catch (_) {
      // Outside the application provider tree nothing was captured either.
    }
  }

  Future<void> _openOnboarding(
    BuildContext context, {
    required String initialStepId,
    required String returnRoute,
    required Map<String, String> returnArguments,
    required bool requiresWalletSetup,
    required ProtectedActionRequirements requirements,
    PreferredAuthMethod? preferredAuthMethod,
  }) {
    // Always a push, never a replace: the entity/screen the visitor was on
    // stays in the stack directly beneath onboarding, so completion can
    // reveal it instead of pushing a duplicate (see
    // OnboardingCompletionNavigation.returnToOrigin).
    return Navigator.of(context).pushNamed(
      '/onboarding',
      arguments: <String, Object?>{
        'initialStepId': initialStepId,
        'completionRoute': _safeReturnRoute(returnRoute),
        if (returnArguments.isNotEmpty)
          'completionArguments': Map<String, String>.from(returnArguments),
        'requiresWalletSetup': requiresWalletSetup,
        'requirements': requirements.storageValue,
        if (preferredAuthMethod != null)
          'preferredAuthMethod': preferredAuthMethod.storageValue,
        'completionNavigation':
            OnboardingCompletionNavigation.returnToOrigin.storageValue,
      },
    );
  }

  bool _maybeResumeIncompleteOnboarding(
    BuildContext context, {
    required String returnRoute,
    required Map<String, String> returnArguments,
    required ProtectedActionRequirements requirements,
    VoidCallback? onAuthJourneyStarted,
  }) {
    try {
      final resumed = context
          .read<DeferredOnboardingProvider>()
          .maybeShowOnboardingForProtectedAction(
            context,
            returnRoute: returnRoute,
            returnArguments: returnArguments,
            requirements: requirements,
          );
      if (resumed) onAuthJourneyStarted?.call();
      return resumed;
    } catch (_) {
      return false;
    }
  }

  /// Resolves the first missing capability, in the order a visitor would
  /// acquire them: account, role, profile, wallet. Only what [requirements]
  /// names is ever considered, so an account-only action can never resolve to
  /// a role, profile or wallet step. Provider access is intentionally
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
      if (requirements.requiresRole && profile.needsStructuredRoleSelection) {
        return 'role';
      }
      if (requirements.requiresProfile) {
        // The same rule the post-auth resolver uses (`isUsablePublicProfile`).
        if (!profile.hasUsablePublicProfile) return 'profile';
      }
      if (requirements.requiresWallet &&
          !context.read<WalletProvider>().hasWalletIdentity) {
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
