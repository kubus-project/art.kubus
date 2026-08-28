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
    this.requiresWalletSetup = false,
    this.completionRoute,
    this.error,
  });

  final PostAuthRouteState state;
  final String routeName;
  final bool removeAuthStack;
  final Object? arguments;
  final String? onboardingStepId;
  final bool requiresWalletSetup;
  final String? completionRoute;
  final String? error;
}

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
    @Deprecated('Pending actions must not alter onboarding requirements.')
    bool minimalAccount = false,
  }) async {
    final targetWallet = (walletAddress ?? '').toString().trim();
    final flowScopeKey = OnboardingStateService.buildAuthOnboardingScopeKey(
      walletAddress: targetWallet.isEmpty ? null : targetWallet,
      userId: userId,
    );

    // `minimalAccount` is deliberately ignored. Pending work remembers where
    // to return; it never weakens the normal role/profile capability checks.
    final effectiveRequiresWalletSetup =
        (requiresWalletSetup || _payloadRequiresWalletSetup(payload)) &&
            targetWallet.isEmpty &&
            origin != AuthOrigin.wallet;

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
      // Wallet setup is requested only by the protected action or a trusted
      // backend requirement. A wallet-authenticated session already has the
      // wallet identity it needs and must not be asked to connect again.
      requiresWalletSetup: effectiveRequiresWalletSetup,
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
        requiresWalletSetup: effectiveRequiresWalletSetup,
        completionRoute: (redirectRoute ?? '').trim().isEmpty
            ? '/main'
            : redirectRoute!.trim(),
      );
    }

    return PostAuthRedirectResult(
      state: PostAuthRouteState.ready,
      routeName: (redirectRoute ?? '').trim().isEmpty
          ? '/main'
          : redirectRoute!.trim(),
      removeAuthStack: removeAuthStack,
      arguments: redirectArguments,
      completionRoute: (redirectRoute ?? '').trim().isEmpty
          ? '/main'
          : redirectRoute!.trim(),
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
          completionRoute: result.completionRoute,
          completionArguments: result.arguments,
          requiresWalletSetup: result.requiresWalletSetup,
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
