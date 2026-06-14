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
  bool hasActiveGoogleOnboardingGuard = false,
  bool hasActiveAccountLinkGuard = false,
  bool hasWallet = false,
  String? structuredOnboardingStepId,
}) {
  // While either onboarding guard is active the account already exists (or a
  // Google registration is mid-flight): never route to /sign-in. Recover into
  // onboarding at the step that matches the session/wallet state instead.
  if (hasActiveGoogleOnboardingGuard || hasActiveAccountLinkGuard) {
    if (!hasValidSession) {
      return const StartupDecision(
        route: StartupRouteType.onboarding,
        onboardingInitialStepId: 'account',
      );
    }
    if (!hasWallet) {
      return const StartupDecision(
        route: StartupRouteType.onboarding,
        onboardingInitialStepId: 'walletConnect',
      );
    }
    final step = (structuredOnboardingStepId ?? '').trim();
    return StartupDecision(
      route: StartupRouteType.onboarding,
      onboardingInitialStepId: step.isEmpty ? null : step,
    );
  }

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
    return StartupDecision(
        route: StartupRouteType.onboarding, onboardingInitialStepId: initial);
  }

  // Pending verification flag true but empty email -> use account, not verifyEmail
  // (This is a defensive check; normally both flags are set together)

  // Returning/skip onboarding behavior
  if (shouldSkipOnboarding) {
    if (shouldShowSignIn) {
      return const StartupDecision(route: StartupRouteType.signIn);
    }
    return const StartupDecision(route: StartupRouteType.main);
  }

  return const StartupDecision(route: StartupRouteType.none);
}

/// Whether the synchronous, pre-shell profile load in `AppInitializer` can be
/// skipped because `ProfileProvider.initialize()` already hydrated the profile
/// for the exact wallet we are routing for.
///
/// `ProfileProvider.initialize()` performs a backend `loadProfile()` (+ stats)
/// for the persisted wallet. The startup route decision only consumes hydrated
/// profile state (role selection / profile completion / persona). When the
/// hydrated wallet matches the routing wallet, repeating the network load on
/// the critical path cannot change the route, so it is deferred to keep the
/// splash short. A cache miss, a different wallet, an empty wallet, or a failed
/// hydration must still load synchronously so behavior is unchanged.
bool canSkipRedundantCriticalProfileLoad({
  required bool hasHydratedProfile,
  required String? hydratedWalletAddress,
  required String? routeWalletAddress,
}) {
  if (!hasHydratedProfile) return false;
  final hydrated = (hydratedWalletAddress ?? '').trim();
  final route = (routeWalletAddress ?? '').trim();
  if (hydrated.isEmpty || route.isEmpty) return false;
  return hydrated == route;
}
