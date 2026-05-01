enum StartupRouteType { onboarding, signIn, main, none }

class StartupDecision {
  final StartupRouteType route;
  final String? onboardingInitialStepId;

  const StartupDecision({required this.route, this.onboardingInitialStepId});
}

/// Lightweight decision helper used by tests to reproduce AppInitializer routing
/// choices for the specific branches we care about in unit tests.
/// 
/// This helper does NOT make decisions about:
/// - Deep links / auth links (handled separately in AppInitializer)
/// - Valid-session structured onboarding resume (handled separately with resolver)
/// - First-run vs returning user detection (uses shouldSkipOnboarding parameter)
StartupDecision decideStartupRoute({
  required bool hasPendingAuthOnboarding,
  required bool hasValidSession,
  required bool hasPendingVerificationEmailFlag,
  required String? pendingVerificationEmail,
  required bool shouldSkipOnboarding,
  required bool shouldShowSignIn,
}) {
  // Pending auth onboarding WITH a valid session: defer to AppInitializer's
  // structured resume logic (resolver). Return none so AppInitializer continues.
  if (hasPendingAuthOnboarding && hasValidSession) {
    return const StartupDecision(route: StartupRouteType.none);
  }

  // Pending auth onboarding without a valid session -> onboarding
  if (hasPendingAuthOnboarding && !hasValidSession) {
    var initial = 'account';
    if (hasPendingVerificationEmailFlag &&
        (pendingVerificationEmail?.trim() ?? '').isNotEmpty) {
      initial = 'verifyEmail';
    }
    return StartupDecision(route: StartupRouteType.onboarding, onboardingInitialStepId: initial);
  }

  // Pending verification flag true but empty email -> use account, not verifyEmail
  // (This is a defensive check; normally both flags are set together)

  // Returning/skip onboarding behavior
  if (shouldSkipOnboarding) {
    if (shouldShowSignIn) return const StartupDecision(route: StartupRouteType.signIn);
    return const StartupDecision(route: StartupRouteType.main);
  }

  return const StartupDecision(route: StartupRouteType.none);
}
