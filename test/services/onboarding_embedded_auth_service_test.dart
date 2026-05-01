import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/services/onboarding_embedded_auth_service.dart';

void main() {
  group('OnboardingEmbeddedAuthService.decide()', () {
    test('no pending email -> proceed', () {
      final decision = OnboardingEmbeddedAuthService.decide(
        signedInEmail: 'user@example.com',
        pendingVerificationEmail: null,
      );

      expect(decision.canProceed, isTrue);
      expect(decision.type, EmbeddedOnboardingAuthDecisionType.proceed);
    });

    test('matching pending email (case-insensitive) -> proceed', () {
      final decision = OnboardingEmbeddedAuthService.decide(
        signedInEmail: 'User@Example.COM',
        pendingVerificationEmail: 'user@example.com',
      );

      expect(decision.canProceed, isTrue);
      expect(decision.type, EmbeddedOnboardingAuthDecisionType.proceed);
      expect(decision.normalizedSignedInEmail, 'user@example.com');
      expect(decision.normalizedPendingEmail, 'user@example.com');
    });

    test('whitespace tolerance: emails normalized -> proceed', () {
      final decision = OnboardingEmbeddedAuthService.decide(
        signedInEmail: '  user@example.com  ',
        pendingVerificationEmail: '  user@example.com  ',
      );

      expect(decision.canProceed, isTrue);
    });

    test('mismatched email -> blockedEmailMismatch', () {
      final decision = OnboardingEmbeddedAuthService.decide(
        signedInEmail: 'user1@example.com',
        pendingVerificationEmail: 'user2@example.com',
      );

      expect(decision.canProceed, isFalse);
      expect(decision.type, EmbeddedOnboardingAuthDecisionType.blockedEmailMismatch);
      expect(decision.isEmailMismatch, isTrue);
    });

    test('pending email exists but signed-in email missing -> blockedMissingEmail', () {
      final decision = OnboardingEmbeddedAuthService.decide(
        signedInEmail: null,
        pendingVerificationEmail: 'user@example.com',
      );

      expect(decision.canProceed, isFalse);
      expect(decision.type, EmbeddedOnboardingAuthDecisionType.blockedMissingEmail);
      expect(decision.isMissingEmail, isTrue);
    });

    test('pending email exists but signed-in email is empty string -> blockedMissingEmail', () {
      final decision = OnboardingEmbeddedAuthService.decide(
        signedInEmail: '',
        pendingVerificationEmail: 'user@example.com',
      );

      expect(decision.canProceed, isFalse);
      expect(decision.isMissingEmail, isTrue);
    });

    test('empty pending email and empty signed-in email -> proceed (no constraint)', () {
      final decision = OnboardingEmbeddedAuthService.decide(
        signedInEmail: '',
        pendingVerificationEmail: '',
      );

      expect(decision.canProceed, isTrue);
    });
  });
}

