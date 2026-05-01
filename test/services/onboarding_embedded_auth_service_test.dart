import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/services/onboarding_embedded_auth_service.dart';

void main() {
  group('OnboardingEmbeddedAuthService', () {
    test('shouldProceedWithEmbeddedAuthSuccess: no pending email -> proceed', () {
      final result = OnboardingEmbeddedAuthService.shouldProceedWithEmbeddedAuthSuccess(
        signedInEmail: 'user@example.com',
        pendingVerificationEmail: null,
      );

      expect(result, isTrue);
    });

    test('shouldProceedWithEmbeddedAuthSuccess: matching pending email -> proceed', () {
      final result = OnboardingEmbeddedAuthService.shouldProceedWithEmbeddedAuthSuccess(
        signedInEmail: 'user@example.com',
        pendingVerificationEmail: 'user@example.com',
      );

      expect(result, isTrue);
    });

    test('shouldProceedWithEmbeddedAuthSuccess: case-insensitive match -> proceed', () {
      final result = OnboardingEmbeddedAuthService.shouldProceedWithEmbeddedAuthSuccess(
        signedInEmail: 'User@Example.COM',
        pendingVerificationEmail: 'user@example.com',
      );

      expect(result, isTrue);
    });

    test('shouldProceedWithEmbeddedAuthSuccess: whitespace tolerance -> proceed', () {
      final result = OnboardingEmbeddedAuthService.shouldProceedWithEmbeddedAuthSuccess(
        signedInEmail: '  user@example.com  ',
        pendingVerificationEmail: '  user@example.com  ',
      );

      expect(result, isTrue);
    });

    test('shouldProceedWithEmbeddedAuthSuccess: mismatched email -> do not proceed', () {
      final result = OnboardingEmbeddedAuthService.shouldProceedWithEmbeddedAuthSuccess(
        signedInEmail: 'user1@example.com',
        pendingVerificationEmail: 'user2@example.com',
      );

      expect(result, isFalse);
    });

    test('shouldProceedWithEmbeddedAuthSuccess: pending email not empty but sign-in is different -> do not proceed', () {
      final result = OnboardingEmbeddedAuthService.shouldProceedWithEmbeddedAuthSuccess(
        signedInEmail: 'other@example.com',
        pendingVerificationEmail: 'user@example.com',
      );

      expect(result, isFalse);
    });

    test('validateOnboardingRemains: onboarding active -> true', () {
      final result = OnboardingEmbeddedAuthService.validateOnboardingRemains(
        isOnboardingActive: true,
      );

      expect(result, isTrue);
    });

    test('validateOnboardingRemains: onboarding inactive -> false (contract violation)', () {
      final result = OnboardingEmbeddedAuthService.validateOnboardingRemains(
        isOnboardingActive: false,
      );

      expect(result, isFalse);
    });
  });
}
