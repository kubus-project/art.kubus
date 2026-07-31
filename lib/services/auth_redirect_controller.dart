import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';
import '../models/user_persona.dart';
import '../providers/profile_provider.dart';
import '../providers/wallet_provider.dart';
import '../screens/desktop/desktop_shell.dart';
import '../screens/onboarding/onboarding_flow_screen.dart';
import 'auth_onboarding_service.dart';
import 'onboarding_state_service.dart';

enum AuthOrigin {
  emailPassword,
  google,
  googleOnboarding,
  wallet,
  passkey,
  restoredSession,
}

enum AuthRedirectStage {
  authenticating,
  storingSession,
  ensuringWalletIdentity,
  hydratingProfile,
  checkingOnboarding,
  ready,
  failed,
}

enum PostAuthRouteState {
  authenticating,
  storingSession,
  ensuringWalletIdentity,
  hydratingProfile,
  initializingProviders,
  checkingOnboarding,
  onboardingRequired,
  ready,
  failed,
}

class PostAuthRedirectResult {
  const PostAuthRedirectResult({
    required this.state,
    required this.routeName,
    this.removeAuthStack = true,
    this.arguments,
    this.onboardingStepId,
    this.error,
  });

  final PostAuthRouteState state;
  final String routeName;
  final bool removeAuthStack;
  final Object? arguments;
  final String? onboardingStepId;
  final String? error;
}

/// Account-branch steps a minimal account may postpone.
///
/// Deliberately excludes `verifyEmail` (identity), `walletBackupIntro` and
/// `walletBackup` (fund safety), which are never skipped for growth.
const Set<String> _deferrableAccountSteps = <String>{
  'role',
  'profile',
  'walletConnect',
  'daoReview',
  'accountPermissions',
};

class AuthRedirectController {
  const AuthRedirectController();

  Future<PostAuthRedirectResult> resolvePostAuthRedirect({
    required SharedPreferences prefs,
    required Map<String, dynamic> payload,
    required bool hasHydratedProfile,
    required bool requiresWalletBackup,
    String? walletAddress,
    String? userId,
    String? redirectRoute,
    Object? redirectArguments,
    String? heuristicNextStepId,
    String? persona,
    bool removeAuthStack = true,
    AuthOrigin origin = AuthOrigin.emailPassword,
    bool requiresWalletSetup = false,
    bool minimalAccount = false,
  }) async {
    final targetWallet = (walletAddress ?? '').toString().trim();
    final flowScopeKey = OnboardingStateService.buildAuthOnboardingScopeKey(
      walletAddress: targetWallet.isEmpty ? null : targetWallet,
      userId: userId,
    );

    // Minimal-account mode: the visitor created this account only to finish a
    // small action they already started. Role, profile, wallet setup, DAO and
    // permission steps are everything *except* what identity needs, so they
    // become progressive onboarding the visitor can complete later instead of
    // a wall between them and the thing they came to do.
    //
    // Wallet *backup* is not one of those steps. It protects funds that
    // already exist, so it is never skipped for growth: a session that still
    // owes a backup falls through to the normal resume below.
    //
    // Note: unlike the rest of this method, this branch writes — it clears the
    // pending-onboarding marker so a later cold start does not re-impose the
    // flow we just deliberately skipped.
    final owesWalletBackup = requiresWalletBackup && targetWallet.isNotEmpty;
    if (minimalAccount && !owesWalletBackup) {
      // Record the skipped steps as *deferred* rather than dropping them, so
      // "finish setting up your profile" surfaces can still find them. Clearing
      // the pending marker on its own would lose them permanently.
      await OnboardingStateService.saveFlowProgress(
        prefs: prefs,
        onboardingVersion: AuthOnboardingService.onboardingFlowVersion,
        completedSteps: const <String>{'account'},
        deferredSteps: _deferrableAccountSteps,
        flowScopeKey: flowScopeKey,
      );
      await OnboardingStateService.clearPendingAuthOnboarding(
        prefs: prefs,
        scopeKey: flowScopeKey,
      );
      return PostAuthRedirectResult(
        state: PostAuthRouteState.ready,
        routeName: (redirectRoute ?? '').trim().isEmpty
            ? '/main'
            : redirectRoute!.trim(),
        removeAuthStack: removeAuthStack,
        arguments: redirectArguments,
      );
    }

    final resumeState =
        await AuthOnboardingService.resolveStructuredOnboardingResume(
      prefs: prefs,
      hasPendingAuthOnboarding:
          origin == AuthOrigin.wallet && flowScopeKey == null
              ? false
              : OnboardingStateService.hasPendingAuthOnboardingSync(
                  prefs,
                  scopeKey: flowScopeKey,
                ),
      hasAuthenticatedSession: true,
      hasHydratedProfile: hasHydratedProfile,
      requiresWalletBackup: requiresWalletBackup && targetWallet.isNotEmpty,
      // Wallet setup applies to all Google/email account sessions without a
      // wallet — standalone sign-in/registration and onboarding alike. Wallet
      // origin sessions already proved a wallet, so they are exempt.
      requiresWalletSetup:
          (requiresWalletSetup || _payloadRequiresWalletSetup(payload)) &&
              targetWallet.isEmpty &&
              (origin == AuthOrigin.google ||
                  origin == AuthOrigin.googleOnboarding ||
                  origin == AuthOrigin.emailPassword ||
                  origin == AuthOrigin.passkey),
      heuristicNextStepId: heuristicNextStepId,
      persona: persona,
      payload: payload,
      flowScopeKey: flowScopeKey,
    );

    final nextStepId = resumeState.nextStepId;
    if (resumeState.requiresStructuredOnboarding &&
        nextStepId != null &&
        nextStepId.isNotEmpty) {
      return PostAuthRedirectResult(
        state: PostAuthRouteState.onboardingRequired,
        routeName: '/onboarding',
        removeAuthStack: removeAuthStack,
        arguments: redirectArguments,
        onboardingStepId: nextStepId,
      );
    }

    return PostAuthRedirectResult(
      state: PostAuthRouteState.ready,
      routeName: (redirectRoute ?? '').trim().isEmpty
          ? '/main'
          : redirectRoute!.trim(),
      removeAuthStack: removeAuthStack,
      arguments: redirectArguments,
    );
  }

  bool _payloadRequiresWalletSetup(Map<String, dynamic> payload) {
    bool readBool(Map<String, dynamic> source, String key) {
      final value = source[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        return normalized == 'true' || normalized == '1' || normalized == 'yes';
      }
      return false;
    }

    final data = payload['data'];
    final envelope =
        data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    return readBool(payload, 'requiresWalletSetup') ||
        readBool(envelope, 'requiresWalletSetup');
  }

  Future<bool> routeAfterAuth({
    required BuildContext context,
    required SharedPreferences prefs,
    required ProfileProvider profileProvider,
    required WalletProvider walletProvider,
    required Map<String, dynamic> payload,
    String? walletAddress,
    String? userId,
    String? redirectRoute,
    Object? redirectArguments,
    bool replaceStack = true,
    AuthOrigin origin = AuthOrigin.emailPassword,
  }) async {
    final navigator = Navigator.of(context);
    final isDesktop = DesktopBreakpoints.isDesktop(context);
    final targetWallet = (walletAddress ?? walletProvider.currentWalletAddress)
        ?.toString()
        .trim();
    final flowScopeKey = OnboardingStateService.buildAuthOnboardingScopeKey(
      walletAddress: targetWallet,
      userId: userId,
    );

    final requiresWalletBackup =
        AppConfig.isFeatureEnabled('walletBackupOnboarding') &&
            (targetWallet ?? '').isNotEmpty &&
            walletProvider.authority.mnemonicBackupRequired;
    final result = await resolvePostAuthRedirect(
      prefs: prefs,
      payload: payload,
      hasHydratedProfile: profileProvider.profile != null,
      requiresWalletBackup: requiresWalletBackup,
      walletAddress: targetWallet,
      userId: userId,
      redirectRoute: redirectRoute,
      redirectArguments: redirectArguments,
      heuristicNextStepId: profileProvider.nextStructuredOnboardingStepId,
      persona: profileProvider.userPersona?.storageValue,
      removeAuthStack: replaceStack,
      origin: origin,
    );

    if (result.state == PostAuthRouteState.onboardingRequired &&
        (result.onboardingStepId ?? '').isNotEmpty) {
      await OnboardingStateService.markAuthOnboardingPending(
        prefs: prefs,
        scopeKey: flowScopeKey,
      );
      if (!context.mounted) return true;
      final route = MaterialPageRoute(
        builder: (_) => OnboardingFlowScreen(
          forceDesktop: isDesktop,
          initialStepId: result.onboardingStepId,
        ),
        settings: const RouteSettings(name: '/onboarding'),
      );
      if (result.removeAuthStack) {
        navigator.pushAndRemoveUntil(route, (_) => false);
      } else {
        navigator.pushReplacement(route);
      }
      return true;
    }

    await OnboardingStateService.clearPendingAuthOnboarding(
      prefs: prefs,
      scopeKey: flowScopeKey,
    );
    if (!context.mounted) return true;
    if (result.removeAuthStack) {
      navigator.pushNamedAndRemoveUntil(
        result.routeName,
        (_) => false,
        arguments: result.arguments,
      );
    } else {
      navigator.pushReplacementNamed(
        result.routeName,
        arguments: result.arguments,
      );
    }
    return true;
  }
}
