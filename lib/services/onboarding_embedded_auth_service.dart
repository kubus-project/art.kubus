/// Decision logic for embedded auth success within onboarding.
/// 
/// This service ensures that embedded auth success during onboarding never
/// allows escape to /main or /sign-in before completion.
enum EmbeddedOnboardingAuthDecisionType {
  /// Email validation passed; can proceed with auth step completion.
  proceed,
  /// Email mismatch with pending verification; block and show warning.
  blockedEmailMismatch,
  /// Signed-in email is empty but pending email exists; cannot proceed.
  blockedMissingEmail,
}

class EmbeddedOnboardingAuthDecision {
  const EmbeddedOnboardingAuthDecision({
    required this.type,
    this.normalizedSignedInEmail,
    this.normalizedPendingEmail,
  });

  final EmbeddedOnboardingAuthDecisionType type;
  final String? normalizedSignedInEmail;
  final String? normalizedPendingEmail;

  bool get canProceed => type == EmbeddedOnboardingAuthDecisionType.proceed;
  bool get isEmailMismatch =>
      type == EmbeddedOnboardingAuthDecisionType.blockedEmailMismatch;
  bool get isMissingEmail =>
      type == EmbeddedOnboardingAuthDecisionType.blockedMissingEmail;
}

class OnboardingEmbeddedAuthService {
  /// Decide whether embedded auth success can proceed based on email validation.
  ///
  /// Rules:
  /// - If no pending verification email exists → proceed
  /// - If pending email exists and signed-in email matches (case-insensitive) → proceed
  /// - If pending email exists but signed-in email is missing → block (cannot verify)
  /// - If pending email exists but differs from signed-in email → block (prevent email swap)
  static EmbeddedOnboardingAuthDecision decide({
    required String? signedInEmail,
    required String? pendingVerificationEmail,
  }) {
    final normalizedSignedIn = (signedInEmail ?? '').trim().toLowerCase();
    final normalizedPending = (pendingVerificationEmail ?? '').trim().toLowerCase();

    // No pending verification email → can proceed
    if (normalizedPending.isEmpty) {
      return EmbeddedOnboardingAuthDecision(
        type: EmbeddedOnboardingAuthDecisionType.proceed,
        normalizedSignedInEmail: normalizedSignedIn.isEmpty ? null : normalizedSignedIn,
        normalizedPendingEmail: null,
      );
    }

    // Pending email exists but signed-in email is missing → cannot verify
    if (normalizedSignedIn.isEmpty) {
      return EmbeddedOnboardingAuthDecision(
        type: EmbeddedOnboardingAuthDecisionType.blockedMissingEmail,
        normalizedSignedInEmail: null,
        normalizedPendingEmail: normalizedPending,
      );
    }

    // Pending email exists; check if it matches signed-in email
    if (normalizedSignedIn == normalizedPending) {
      return EmbeddedOnboardingAuthDecision(
        type: EmbeddedOnboardingAuthDecisionType.proceed,
        normalizedSignedInEmail: normalizedSignedIn,
        normalizedPendingEmail: normalizedPending,
      );
    }

    // Pending email exists and differs from signed-in email → block
    return EmbeddedOnboardingAuthDecision(
      type: EmbeddedOnboardingAuthDecisionType.blockedEmailMismatch,
      normalizedSignedInEmail: normalizedSignedIn,
      normalizedPendingEmail: normalizedPending,
    );
  }
}

