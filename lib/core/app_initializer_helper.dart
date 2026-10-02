import 'package:shared_preferences/shared_preferences.dart';

import '../services/onboarding_state_service.dart';

enum StartupRouteType { onboarding, none }

class StartupDecision {
  final StartupRouteType route;
  final String? onboardingInitialStepId;

  const StartupDecision({required this.route, this.onboardingInitialStepId});
}

/// Public map entry is intentionally available before authentication or
/// onboarding. Identity setup is deferred until a protected map action.
bool shouldOpenPublicMapBeforeOnboarding({
  required String? preferredShellRoute,
  required bool hasValidSession,
}) {
  return !hasValidSession && (preferredShellRoute ?? '').trim() == '/map';
}

/// Where a cold start with no explicit intent (no auth callback, no deep link,
/// no account journey already in flight) lands.
///
/// Guest-first is the default anonymous behaviour, not a campaign exception: a
/// visitor without a valid server session opens public discovery (the map) and
/// is never shown an alpha notice, a welcome/onboarding flow, a role picker, a
/// wallet step, a permissions flow or a sign-in wall first. Identity is asked
/// for only when they attempt something that needs it
/// (`ContextualAuthGate`), and only for the capability that action needs.
///
/// A signed-in returning user keeps their useful destination: the shell route
/// they entered on, `/main` by default.
///
/// An expired or missing *server* session is not an app lock. A visitor whose
/// token lapsed can still browse public art; they re-authenticate when they
/// open Account or attempt a protected action. The local security gate (PIN /
/// biometric) is a separate overlay owned by `SecurityGateProvider` and is not
/// affected by this decision.
ColdStartEntry resolveColdStartEntry({
  required String? preferredShellRoute,
  required bool hasValidSession,
  required bool hasLocalAccount,
}) {
  final preferred = (preferredShellRoute ?? '').trim();
  if (hasValidSession) {
    final route = switch (preferred) {
      '/map' => '/map',
      '/community' => '/community',
      _ => '/main',
    };
    return ColdStartEntry(shellRoute: route, activateGuestMode: false);
  }
  return ColdStartEntry(
    // `/community` is a public destination in its own right; every other
    // anonymous entry (`/`, `/main`, `/map`, an unknown path) opens discovery.
    shellRoute: preferred == '/community' ? '/community' : '/map',
    // Guest mode is the "no account yet" flag. A returning account whose
    // session merely lapsed is not a guest and must not be relabelled as one.
    activateGuestMode: !hasLocalAccount,
  );
}

class ColdStartEntry {
  const ColdStartEntry({
    required this.shellRoute,
    required this.activateGuestMode,
  });

  final String shellRoute;
  final bool activateGuestMode;
}

/// Decides only the *explicit account continuations* a cold start must not
/// strand: an email verification left pending, a pending structured journey, or
/// an active Google-registration / account-link guard. None of these is a fresh
/// anonymous visitor; each one is a journey the visitor genuinely began.
///
/// This helper does NOT make decisions about:
/// - Deep links / auth callbacks (handled separately in AppInitializer)
/// - Valid-session structured onboarding resume (handled separately with the
///   resolver)
/// - Fresh anonymous entry, which is never onboarding (see
///   [resolveColdStartEntry])
StartupDecision decideStartupRoute({
  required bool hasPendingAuthOnboarding,
  required bool hasValidSession,
  required bool hasPendingVerificationEmailFlag,
  required String? pendingVerificationEmail,
  bool hasActiveGoogleOnboardingGuard = false,
  bool hasActiveAccountLinkGuard = false,
  bool hasWallet = false,
  String? structuredOnboardingStepId,
}) {
  // While either onboarding guard is active the account already exists (or a
  // Google registration is mid-flight): never route to /sign-in. Only the
  // account-link guard represents an explicit wallet-link operation; a Google
  // registration remains wallet-optional until an action asks for it.
  if (hasActiveGoogleOnboardingGuard || hasActiveAccountLinkGuard) {
    if (!hasValidSession) {
      return const StartupDecision(
        route: StartupRouteType.onboarding,
        onboardingInitialStepId: 'account',
      );
    }
    if (hasActiveAccountLinkGuard && !hasWallet) {
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
  return const StartupDecision(route: StartupRouteType.none);
}

/// The degraded-startup decision (initialisation threw, or the watchdog fired).
///
/// There is no session to derive an account scope from, so a recorded interrupted
/// journey is looked up under the unscoped key *and* every user/wallet scope
/// (`OnboardingStateService.hasAnyPendingAuthOnboardingSync`). No journey, or
/// only stale markers, means public discovery.
StartupDecision decideDegradedStartup(SharedPreferences prefs) {
  return decideStartupRoute(
    hasPendingAuthOnboarding:
        OnboardingStateService.hasAnyPendingAuthOnboardingSync(prefs),
    hasValidSession: false,
    hasPendingVerificationEmailFlag:
        prefs.getBool('onboarding_pending_email_verification_v1') ?? false,
    pendingVerificationEmail:
        prefs.getString('onboarding_verification_email_v3'),
    hasActiveGoogleOnboardingGuard:
        OnboardingStateService.hasActiveGoogleOnboardingRegistrationGuardSync(
      prefs,
    ),
    hasActiveAccountLinkGuard:
        OnboardingStateService.hasActiveAccountLinkGuardSync(prefs),
  );
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
