/// Decision logic for embedded auth success within onboarding.
/// 
/// This service models the decision tree for when embedded sign-in succeeds
/// during the onboarding flow. It ensures that embedded auth success never
/// allows the user to escape onboarding before it is completed.
class OnboardingEmbeddedAuthService {
  /// Given the current onboarding state and auth payload, determine what action to take.
  /// 
  /// Returns true if onboarding can proceed normally (mark steps complete, refresh auth).
  /// Returns false if the sign-in email differs from pending verification email
  /// (requires user intervention to reconcile).
  static bool shouldProceedWithEmbeddedAuthSuccess({
    required String signedInEmail,
    required String? pendingVerificationEmail,
  }) {
    final normalizedSignedInEmail = signedInEmail.trim().toLowerCase();
    final normalizedPendingEmail = (pendingVerificationEmail ?? '').trim().toLowerCase();

    // If there's a pending verification email and it doesn't match the signed-in email,
    // we cannot proceed. Return false so the UI shows a warning and lets the user resolve.
    if (normalizedPendingEmail.isNotEmpty &&
        normalizedSignedInEmail != normalizedPendingEmail) {
      return false;
    }

    // All checks passed; embedded sign-in can proceed.
    return true;
  }

  /// Validate that embedded auth will not cause escape from onboarding.
  /// 
  /// Always returns true as long as onboarding is active. This is a defensive check
  /// to ensure the onboarding lifecycle is never violated by embedded auth success.
  static bool validateOnboardingRemains({
    required bool isOnboardingActive,
  }) {
    // Embedded auth should only be invoked from within an active onboarding flow.
    // If onboarding is not active, this is a contract violation.
    return isOnboardingActive;
  }
}
