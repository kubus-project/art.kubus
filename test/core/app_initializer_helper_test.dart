import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/core/app_initializer_helper.dart';

void main() {
  test(
      'pending auth onboarding with verification email -> onboarding:verifyEmail',
      () {
    final decision = decideStartupRoute(
      hasPendingAuthOnboarding: true,
      hasValidSession: false,
      hasPendingVerificationEmailFlag: true,
      pendingVerificationEmail: 'user@example.com',
      shouldSkipOnboarding: false,
      shouldShowSignIn: false,
    );

    expect(decision.route, StartupRouteType.onboarding);
    expect(decision.onboardingInitialStepId, 'verifyEmail');
  });

  test(
      'pending auth onboarding without verification email -> onboarding:account',
      () {
    final decision = decideStartupRoute(
      hasPendingAuthOnboarding: true,
      hasValidSession: false,
      hasPendingVerificationEmailFlag: false,
      pendingVerificationEmail: null,
      shouldSkipOnboarding: false,
      shouldShowSignIn: false,
    );

    expect(decision.route, StartupRouteType.onboarding);
    expect(decision.onboardingInitialStepId, 'account');
  });

  test(
      'pending auth onboarding with valid session -> none (deferred to resolver)',
      () {
    final decision = decideStartupRoute(
      hasPendingAuthOnboarding: true,
      hasValidSession: true,
      hasPendingVerificationEmailFlag: false,
      pendingVerificationEmail: null,
      shouldSkipOnboarding: false,
      shouldShowSignIn: false,
    );

    expect(decision.route, StartupRouteType.none);
    expect(decision.onboardingInitialStepId, isNull);
  });

  test('pending verification flag true but empty email -> account', () {
    final decision = decideStartupRoute(
      hasPendingAuthOnboarding: true,
      hasValidSession: false,
      hasPendingVerificationEmailFlag: true,
      pendingVerificationEmail: null,
      shouldSkipOnboarding: false,
      shouldShowSignIn: false,
    );

    expect(decision.route, StartupRouteType.onboarding);
    expect(decision.onboardingInitialStepId, 'account');
  });

  test('shouldSkipOnboarding + shouldShowSignIn -> signIn', () {
    final decision = decideStartupRoute(
      hasPendingAuthOnboarding: false,
      hasValidSession: false,
      hasPendingVerificationEmailFlag: false,
      pendingVerificationEmail: null,
      shouldSkipOnboarding: true,
      shouldShowSignIn: true,
    );

    expect(decision.route, StartupRouteType.signIn);
  });

  test('shouldSkipOnboarding + !shouldShowSignIn -> main', () {
    final decision = decideStartupRoute(
      hasPendingAuthOnboarding: false,
      hasValidSession: false,
      hasPendingVerificationEmailFlag: false,
      pendingVerificationEmail: null,
      shouldSkipOnboarding: true,
      shouldShowSignIn: false,
    );

    expect(decision.route, StartupRouteType.main);
  });

  test('Google onboarding guard without session routes to account', () {
    final decision = decideStartupRoute(
      hasPendingAuthOnboarding: false,
      hasValidSession: false,
      hasPendingVerificationEmailFlag: false,
      pendingVerificationEmail: null,
      shouldSkipOnboarding: true,
      shouldShowSignIn: true,
      hasActiveGoogleOnboardingGuard: true,
    );

    expect(decision.route, StartupRouteType.onboarding);
    expect(decision.onboardingInitialStepId, 'account');
  });

  test(
      'Google onboarding guard with session and missing wallet routes to walletConnect',
      () {
    final decision = decideStartupRoute(
      hasPendingAuthOnboarding: true,
      hasValidSession: true,
      hasPendingVerificationEmailFlag: false,
      pendingVerificationEmail: null,
      shouldSkipOnboarding: false,
      shouldShowSignIn: false,
      hasActiveGoogleOnboardingGuard: true,
      hasWallet: false,
    );

    expect(decision.route, StartupRouteType.onboarding);
    expect(decision.onboardingInitialStepId, 'walletConnect');
  });

  test('account-link guard without session never routes to sign-in', () {
    final decision = decideStartupRoute(
      hasPendingAuthOnboarding: false,
      hasValidSession: false,
      hasPendingVerificationEmailFlag: false,
      pendingVerificationEmail: null,
      shouldSkipOnboarding: true,
      shouldShowSignIn: true,
      hasActiveAccountLinkGuard: true,
    );

    expect(decision.route, StartupRouteType.onboarding);
    expect(decision.onboardingInitialStepId, 'account');
  });

  test('account-link guard with session and no wallet routes to walletConnect',
      () {
    final decision = decideStartupRoute(
      hasPendingAuthOnboarding: false,
      hasValidSession: true,
      hasPendingVerificationEmailFlag: false,
      pendingVerificationEmail: null,
      shouldSkipOnboarding: false,
      shouldShowSignIn: true,
      hasActiveAccountLinkGuard: true,
      hasWallet: false,
    );

    expect(decision.route, StartupRouteType.onboarding);
    expect(decision.onboardingInitialStepId, 'walletConnect');
  });

  test(
      'account-link guard with session and wallet resumes structured onboarding',
      () {
    final decision = decideStartupRoute(
      hasPendingAuthOnboarding: false,
      hasValidSession: true,
      hasPendingVerificationEmailFlag: false,
      pendingVerificationEmail: null,
      shouldSkipOnboarding: false,
      shouldShowSignIn: false,
      hasActiveAccountLinkGuard: true,
      hasWallet: true,
      structuredOnboardingStepId: 'walletBackupIntro',
    );

    expect(decision.route, StartupRouteType.onboarding);
    expect(decision.onboardingInitialStepId, 'walletBackupIntro');
  });

  group('canSkipRedundantCriticalProfileLoad', () {
    test('skips when hydrated profile matches the routing wallet', () {
      expect(
        canSkipRedundantCriticalProfileLoad(
          hasHydratedProfile: true,
          hydratedWalletAddress: 'Wallet123',
          routeWalletAddress: 'Wallet123',
        ),
        isTrue,
      );
    });

    test('tolerates surrounding whitespace on either wallet', () {
      expect(
        canSkipRedundantCriticalProfileLoad(
          hasHydratedProfile: true,
          hydratedWalletAddress: '  Wallet123 ',
          routeWalletAddress: 'Wallet123',
        ),
        isTrue,
      );
    });

    test('does not skip when the profile is not hydrated', () {
      expect(
        canSkipRedundantCriticalProfileLoad(
          hasHydratedProfile: false,
          hydratedWalletAddress: 'Wallet123',
          routeWalletAddress: 'Wallet123',
        ),
        isFalse,
      );
    });

    test('does not skip when the hydrated wallet differs from routing wallet',
        () {
      expect(
        canSkipRedundantCriticalProfileLoad(
          hasHydratedProfile: true,
          hydratedWalletAddress: 'WalletA',
          routeWalletAddress: 'WalletB',
        ),
        isFalse,
      );
    });

    test('does not skip when either wallet is null or empty', () {
      expect(
        canSkipRedundantCriticalProfileLoad(
          hasHydratedProfile: true,
          hydratedWalletAddress: null,
          routeWalletAddress: 'Wallet123',
        ),
        isFalse,
      );
      expect(
        canSkipRedundantCriticalProfileLoad(
          hasHydratedProfile: true,
          hydratedWalletAddress: 'Wallet123',
          routeWalletAddress: '   ',
        ),
        isFalse,
      );
    });
  });
}
