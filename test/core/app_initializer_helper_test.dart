import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/core/app_initializer_helper.dart';

void main() {
  test('pending auth onboarding with verification email -> onboarding:verifyEmail', () {
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

  test('pending auth onboarding without verification email -> onboarding:account', () {
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

  test('pending auth onboarding with valid session -> none (deferred to resolver)', () {
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
}

