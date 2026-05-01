enum StartupRouteType { onboarding, signIn, main, none }

class StartupDecision {
  final StartupRouteType route;
  final String? onboardingInitialStepId;

  const StartupDecision({required this.route, this.onboardingInitialStepId});
}

/// Lightweight decision helper used by tests to reproduce AppInitializer routing
/// choices for the specific branches we care about in unit tests.
StartupDecision decideStartupRoute({
  required bool hasPendingAuthOnboarding,
  required bool hasValidSession,
  required bool hasPendingVerificationEmailFlag,
  required String? pendingVerificationEmail,
  required bool shouldSkipOnboarding,
  required bool shouldShowSignIn,
}) {
  // Pending auth onboarding without a valid session -> onboarding
  if (hasPendingAuthOnboarding && !hasValidSession) {
    var initial = 'account';
    if (hasPendingVerificationEmailFlag &&
        (pendingVerificationEmail?.trim() ?? '').isNotEmpty) {
      initial = 'verifyEmail';
    }
    return StartupDecision(route: StartupRouteType.onboarding, onboardingInitialStepId: initial);
  }

  // Returning/skip onboarding behavior
  if (shouldSkipOnboarding) {
    if (shouldShowSignIn) return const StartupDecision(route: StartupRouteType.signIn);
    return const StartupDecision(route: StartupRouteType.main);
  }

  return const StartupDecision(route: StartupRouteType.none);
}
