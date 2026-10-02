import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/core/app_initializer_helper.dart';

void main() {
  group('shouldOpenPublicMapBeforeOnboarding', () {
    test('opens a signed-out direct map entry before onboarding', () {
      expect(
        shouldOpenPublicMapBeforeOnboarding(
          preferredShellRoute: '/map',
          hasValidSession: false,
        ),
        isTrue,
      );
    });

    test('does not override authenticated or non-map startup routing', () {
      expect(
        shouldOpenPublicMapBeforeOnboarding(
          preferredShellRoute: '/map',
          hasValidSession: true,
        ),
        isFalse,
      );
      expect(
        shouldOpenPublicMapBeforeOnboarding(
          preferredShellRoute: '/community',
          hasValidSession: false,
        ),
        isFalse,
      );
    });
  });

  test(
      'pending auth onboarding with verification email -> onboarding:verifyEmail',
      () {
    final decision = decideStartupRoute(
      hasPendingAuthOnboarding: true,
      hasValidSession: false,
      hasPendingVerificationEmailFlag: true,
      pendingVerificationEmail: 'user@example.com',
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
    );

    expect(decision.route, StartupRouteType.onboarding);
    expect(decision.onboardingInitialStepId, 'account');
  });

  test('a fresh anonymous visitor with no journey in flight is never onboarding',
      () {
    final decision = decideStartupRoute(
      hasPendingAuthOnboarding: false,
      hasValidSession: false,
      hasPendingVerificationEmailFlag: false,
      pendingVerificationEmail: null,
    );

    expect(decision.route, StartupRouteType.none);
    expect(decision.onboardingInitialStepId, isNull);
  });

  group('resolveColdStartEntry (guest-first)', () {
    for (final route in <String?>[null, '', '/', '/main', '/map', '/unknown']) {
      test('fresh anonymous entry on "$route" opens public discovery', () {
        final entry = resolveColdStartEntry(
          preferredShellRoute: route,
          hasValidSession: false,
          hasLocalAccount: false,
        );

        expect(entry.shellRoute, '/map');
        expect(entry.activateGuestMode, isTrue);
      });
    }

    test('anonymous /community stays on the public community feed', () {
      final entry = resolveColdStartEntry(
        preferredShellRoute: '/community',
        hasValidSession: false,
        hasLocalAccount: false,
      );

      expect(entry.shellRoute, '/community');
      expect(entry.activateGuestMode, isTrue);
    });

    test('a lapsed server session is not an app lock and not a guest', () {
      final entry = resolveColdStartEntry(
        preferredShellRoute: '/main',
        hasValidSession: false,
        hasLocalAccount: true,
      );

      expect(entry.shellRoute, '/map');
      expect(entry.activateGuestMode, isFalse);
    });

    test('a signed-in returning user keeps their shell destination', () {
      expect(
        resolveColdStartEntry(
          preferredShellRoute: null,
          hasValidSession: true,
          hasLocalAccount: true,
        ).shellRoute,
        '/main',
      );
      expect(
        resolveColdStartEntry(
          preferredShellRoute: '/map',
          hasValidSession: true,
          hasLocalAccount: true,
        ).shellRoute,
        '/map',
      );
      expect(
        resolveColdStartEntry(
          preferredShellRoute: '/community',
          hasValidSession: true,
          hasLocalAccount: true,
        ).shellRoute,
        '/community',
      );
    });
  });

  test('Google onboarding guard without session routes to account', () {
    final decision = decideStartupRoute(
      hasPendingAuthOnboarding: false,
      hasValidSession: false,
      hasPendingVerificationEmailFlag: false,
      pendingVerificationEmail: null,
      hasActiveGoogleOnboardingGuard: true,
    );

    expect(decision.route, StartupRouteType.onboarding);
    expect(decision.onboardingInitialStepId, 'account');
  });

  test('Google onboarding guard keeps wallet optional during account setup',
      () {
    final decision = decideStartupRoute(
      hasPendingAuthOnboarding: true,
      hasValidSession: true,
      hasPendingVerificationEmailFlag: false,
      pendingVerificationEmail: null,
      hasActiveGoogleOnboardingGuard: true,
      hasWallet: false,
    );

    expect(decision.route, StartupRouteType.onboarding);
    expect(decision.onboardingInitialStepId, isNull);
  });

  test('account-link guard without session never routes to sign-in', () {
    final decision = decideStartupRoute(
      hasPendingAuthOnboarding: false,
      hasValidSession: false,
      hasPendingVerificationEmailFlag: false,
      pendingVerificationEmail: null,
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
