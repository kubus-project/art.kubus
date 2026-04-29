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

enum AuthRedirectStage {
  authenticating,
  storingSession,
  ensuringWalletIdentity,
  hydratingProfile,
  checkingOnboarding,
  ready,
  failed,
}

class AuthRedirectController {
  const AuthRedirectController();

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
            walletProvider.authority.mnemonicBackupRequired;
    final resumeState =
        await AuthOnboardingService.resolveStructuredOnboardingResume(
      prefs: prefs,
      hasPendingAuthOnboarding:
          OnboardingStateService.hasPendingAuthOnboardingSync(
        prefs,
        scopeKey: flowScopeKey,
      ),
      hasAuthenticatedSession: true,
      hasHydratedProfile: profileProvider.profile != null,
      requiresWalletBackup: requiresWalletBackup,
      heuristicNextStepId: profileProvider.nextStructuredOnboardingStepId,
      persona: profileProvider.userPersona?.storageValue,
      payload: payload,
      flowScopeKey: flowScopeKey,
    );

    final nextStepId = resumeState.nextStepId;
    if (resumeState.requiresStructuredOnboarding &&
        nextStepId != null &&
        nextStepId.isNotEmpty) {
      await OnboardingStateService.markAuthOnboardingPending(
        prefs: prefs,
        scopeKey: flowScopeKey,
      );
      if (!context.mounted) return true;
      final route = MaterialPageRoute(
        builder: (_) => OnboardingFlowScreen(
          forceDesktop: isDesktop,
          initialStepId: nextStepId,
        ),
        settings: const RouteSettings(name: '/onboarding'),
      );
      if (replaceStack) {
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
    final routeName =
        (redirectRoute ?? '').trim().isEmpty ? '/main' : redirectRoute!.trim();
    if (replaceStack) {
      navigator.pushNamedAndRemoveUntil(
        routeName,
        (_) => false,
        arguments: redirectArguments,
      );
    } else {
      navigator.pushReplacementNamed(routeName, arguments: redirectArguments);
    }
    return true;
  }
}
