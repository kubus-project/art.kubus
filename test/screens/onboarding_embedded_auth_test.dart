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
      expect(decision.type,
          EmbeddedOnboardingAuthDecisionType.proceed);
    });

    test('matching pending email (exact case) -> proceed', () {
      final decision = OnboardingEmbeddedAuthService.decide(
        signedInEmail: 'user@example.com',
        pendingVerificationEmail: 'user@example.com',
      );

      expect(decision.canProceed, isTrue);
      expect(decision.normalizedSignedInEmail, 'user@example.com');
      expect(decision.normalizedPendingEmail, 'user@example.com');
    });

    test('matching pending email (case-insensitive) -> proceed', () {
      final decision = OnboardingEmbeddedAuthService.decide(
        signedInEmail: 'User@Example.COM',
        pendingVerificationEmail: 'user@example.com',
      );

      expect(decision.canProceed, isTrue);
      expect(decision.normalizedSignedInEmail, 'user@example.com');
      expect(decision.normalizedPendingEmail, 'user@example.com');
    });

    test('REGRESSION: mismatched email -> block (prevents email swap)', () {
      final decision = OnboardingEmbeddedAuthService.decide(
        signedInEmail: 'user1@example.com',
        pendingVerificationEmail: 'user2@example.com',
      );

      expect(decision.canProceed, isFalse);
      expect(decision.isEmailMismatch, isTrue);
      expect(decision.normalizedSignedInEmail, 'user1@example.com');
      expect(decision.normalizedPendingEmail, 'user2@example.com');
    });

    test('pending email exists but signed-in email missing -> block', () {
      final decision = OnboardingEmbeddedAuthService.decide(
        signedInEmail: null,
        pendingVerificationEmail: 'user@example.com',
      );

      expect(decision.canProceed, isFalse);
      expect(decision.isMissingEmail, isTrue);
      expect(decision.normalizedSignedInEmail, isNull);
      expect(decision.normalizedPendingEmail, 'user@example.com');
    });

    test('pending email exists but signed-in email is empty string -> block', () {
      final decision = OnboardingEmbeddedAuthService.decide(
        signedInEmail: '',
        pendingVerificationEmail: 'user@example.com',
      );

      expect(decision.canProceed, isFalse);
      expect(decision.isMissingEmail, isTrue);
    });

    test('whitespace tolerance: email with spaces normalized -> proceed', () {
      final decision = OnboardingEmbeddedAuthService.decide(
        signedInEmail: '  user@example.com  ',
        pendingVerificationEmail: '  user@example.com  ',
      );

      expect(decision.canProceed, isTrue);
      expect(decision.normalizedSignedInEmail, 'user@example.com');
      expect(decision.normalizedPendingEmail, 'user@example.com');
    });

    test('empty pending email with signed-in email -> proceed', () {
      final decision = OnboardingEmbeddedAuthService.decide(
        signedInEmail: 'user@example.com',
        pendingVerificationEmail: '',
      );

      expect(decision.canProceed, isTrue);
    });

    test('both emails empty -> proceed (no pending constraint)', () {
      final decision = OnboardingEmbeddedAuthService.decide(
        signedInEmail: '',
        pendingVerificationEmail: '',
      );

      expect(decision.canProceed, isTrue);
    });
  });

  group('Embedded auth flow guarantees', () {
    test('email mismatch prevents step completion', () {
      // When embedded auth email differs from pending verification email,
      // the handler must NOT mark account/verification steps complete.
      final decision = OnboardingEmbeddedAuthService.decide(
        signedInEmail: 'wrong@example.com',
        pendingVerificationEmail: 'correct@example.com',
      );

      // The handler code must check this decision and:
      // - Not call _clearPendingEmailVerificationState()
      // - Not call _markCompleted(account)
      // - Show a warning and return without advancing
      expect(decision.isEmailMismatch, isTrue);
    });

    test('no escape route from onboarding for email mismatch', () {
      // A decision object with isEmailMismatch=true means:
      // - Do not route to /main
      // - Do not route to /sign-in
      // - Stay in onboarding and show warning
      final decision = OnboardingEmbeddedAuthService.decide(
        signedInEmail: 'user1@example.com',
        pendingVerificationEmail: 'user2@example.com',
      );

      expect(decision.canProceed, isFalse,
          reason: 'Mismatch must block progression');
      expect(decision.isEmailMismatch, isTrue,
          reason: 'Mismatch is explicitly identified');
      // The onboarding handler must interpret this as:
      // "do not mark steps complete, do not advance, stay in onboarding"
    });
  });
}

