import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/services/onboarding_embedded_auth_service.dart';

void main() {
  group('Embedded onboarding auth cannot escape onboarding', () {
    test('embedded auth with no pending email -> allows account completion', () {
      // Verify that embedded auth success is allowed when there is no conflicting pending email.
      final canProceed = OnboardingEmbeddedAuthService.shouldProceedWithEmbeddedAuthSuccess(
        signedInEmail: 'user@example.com',
        pendingVerificationEmail: null,
      );

      expect(canProceed, isTrue,
          reason: 'embedded auth should allow account step completion when no pending email');
    });

    test('embedded auth with matching pending email -> allows verification completion', () {
      // Verify that embedded auth success is allowed when email matches the pending verification email.
      final canProceed = OnboardingEmbeddedAuthService.shouldProceedWithEmbeddedAuthSuccess(
        signedInEmail: 'user@example.com',
        pendingVerificationEmail: 'user@example.com',
      );

      expect(canProceed, isTrue,
          reason: 'embedded auth should complete verification step when email matches');
    });

    test('embedded auth with mismatched email -> blocks escape and forces user reconciliation', () {
      // REGRESSION: embedded auth must never allow a user to escape onboarding by signing in with
      // a different email than the one pending verification. Instead, it must force the user
      // to either reconcile the email or re-enter the account step.
      final canProceed = OnboardingEmbeddedAuthService.shouldProceedWithEmbeddedAuthSuccess(
        signedInEmail: 'user1@example.com',
        pendingVerificationEmail: 'user2@example.com',
      );

      expect(canProceed, isFalse,
          reason: 'embedded auth must block and show warning when sign-in email differs from pending email');
    });

    test('onboarding must remain active after embedded auth success', () {
      // Verify that the onboarding lifecycle is never violated by embedded auth.
      final remains = OnboardingEmbeddedAuthService.validateOnboardingRemains(
        isOnboardingActive: true,
      );

      expect(remains, isTrue,
          reason: 'embedded auth success must never allow onboarding to become inactive');
    });

    test('embedded auth is rejected if onboarding is not active (contract violation)', () {
      // Defensive check: embedded auth should only be invoked from within onboarding.
      final remains = OnboardingEmbeddedAuthService.validateOnboardingRemains(
        isOnboardingActive: false,
      );

      expect(remains, isFalse,
          reason: 'embedded auth invoked outside onboarding flow is a contract violation');
    });
  });
}

