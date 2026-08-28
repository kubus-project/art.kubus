/// Capabilities required to enter a protected action.
///
/// This is deliberately an UX model, not an authorization model. The backend
/// remains the authority for every mutation, signature and privileged action.
class ProtectedActionRequirements {
  const ProtectedActionRequirements({
    this.requiresAccount = true,
    this.requiresVerifiedIdentity = false,
    this.requiresProfile = true,
    this.requiresWallet = false,
    this.requiresWalletSecurity = false,
    this.requiresDaoEligibility = false,
  });

  /// Normal community participation: account plus a usable profile, no Web3.
  static const participant = ProtectedActionRequirements();

  /// Capability acquisition, such as Infrastructure entry. Wallet signer
  /// recovery and transaction confirmation remain specialised flows.
  static const wallet = ProtectedActionRequirements(requiresWallet: true);

  /// A governance entry point. It intentionally does not make a vote or
  /// proposal replayable; those actions must be explicitly re-confirmed.
  static const dao = ProtectedActionRequirements(
    requiresWallet: true,
    requiresDaoEligibility: true,
  );

  final bool requiresAccount;
  final bool requiresVerifiedIdentity;
  final bool requiresProfile;
  final bool requiresWallet;
  final bool requiresWalletSecurity;
  final bool requiresDaoEligibility;
}
