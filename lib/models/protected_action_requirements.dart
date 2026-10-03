/// Capabilities required to enter a protected action.
///
/// This is deliberately an UX model, not an authorization model. The backend
/// remains the authority for every mutation, signature and privileged action.
///
/// Capabilities are acquired progressively: a visitor is only ever asked for
/// the capability the action they attempted actually needs. Public browsing
/// needs nothing; saving, liking, following and commenting need an account;
/// composing under a public identity needs a usable profile; creator surfaces
/// need a chosen role; wallet and DAO entry need a wallet. Nothing is collected
/// in advance.
class ProtectedActionRequirements {
  const ProtectedActionRequirements({
    this.requiresAccount = true,
    this.requiresProfile = false,
    this.requiresRole = false,
    this.requiresWallet = false,
  });

  /// An authenticated account and nothing else. Save, like, follow, comment and
  /// joining a group: the backend only checks the account token, so no profile,
  /// role or wallet UX may stand in front of them.
  static const accountOnly = ProtectedActionRequirements();

  /// Normal community participation under a public identity: an account plus a
  /// usable profile (a display name), no role and no Web3.
  static const participant = ProtectedActionRequirements(requiresProfile: true);

  /// Creator surfaces (artist studio, institution hub, promotion): account,
  /// usable profile and a chosen role. No wallet, no DAO review; those remain
  /// their own explicit requests.
  static const creator = ProtectedActionRequirements(
    requiresProfile: true,
    requiresRole: true,
  );

  /// Capability acquisition, such as Infrastructure entry. Wallet signer
  /// recovery and transaction confirmation remain specialised flows.
  static const wallet = ProtectedActionRequirements(requiresWallet: true);

  /// A governance entry point. It intentionally does not make a vote or
  /// proposal replayable; those actions must be explicitly re-confirmed, and
  /// DAO role eligibility itself is enforced by the DAO screens/backend, not
  /// by this UX-only gate.
  static const dao = ProtectedActionRequirements(requiresWallet: true);

  /// The narrowest scope that satisfies both: a resumed journey must never
  /// drop a capability the action in front of the visitor needs.
  static ProtectedActionRequirements merge(
    ProtectedActionRequirements a,
    ProtectedActionRequirements b,
  ) =>
      ProtectedActionRequirements(
        requiresAccount: a.requiresAccount || b.requiresAccount,
        requiresProfile: a.requiresProfile || b.requiresProfile,
        requiresRole: a.requiresRole || b.requiresRole,
        requiresWallet: a.requiresWallet || b.requiresWallet,
      );

  final bool requiresAccount;
  final bool requiresProfile;
  final bool requiresRole;
  final bool requiresWallet;

  /// Whether acquiring this action stops once the account exists.
  bool get isAccountOnly =>
      !requiresProfile && !requiresRole && !requiresWallet;

  /// Stable name carried through route arguments and persisted with an
  /// interrupted account journey. Unknown values never widen the scope: they
  /// resolve to `null` so the caller keeps its own default.
  ///
  /// The four named scopes keep their names. A scope that merged several
  /// capabilities (an action that needs a profile and a wallet, say) is written
  /// as its capabilities joined with `+`, so an interrupted journey restores
  /// exactly what the action needed instead of the strongest single name.
  String get storageValue {
    if (this == accountOnly) return 'accountOnly';
    if (this == participant) return 'participant';
    if (this == creator) return 'creator';
    if (this == wallet) return 'wallet';
    return <String>[
      if (requiresAccount) 'account',
      if (requiresProfile) 'profile',
      if (requiresRole) 'role',
      if (requiresWallet) 'wallet',
    ].join('+');
  }

  static ProtectedActionRequirements? fromStorage(String? value) {
    final text = (value ?? '').trim();
    switch (text) {
      case 'accountOnly':
        return accountOnly;
      case 'participant':
        return participant;
      case 'creator':
        return creator;
      case 'wallet':
      case 'dao':
        return wallet;
    }
    if (!text.contains('+')) return null;
    final parts = text.split('+');
    const known = <String>{'account', 'profile', 'role', 'wallet'};
    if (parts.any((part) => !known.contains(part))) return null;
    return ProtectedActionRequirements(
      requiresAccount: parts.contains('account'),
      requiresProfile: parts.contains('profile'),
      requiresRole: parts.contains('role'),
      requiresWallet: parts.contains('wallet'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProtectedActionRequirements &&
      other.requiresAccount == requiresAccount &&
      other.requiresProfile == requiresProfile &&
      other.requiresRole == requiresRole &&
      other.requiresWallet == requiresWallet;

  @override
  int get hashCode => Object.hash(
        requiresAccount,
        requiresProfile,
        requiresRole,
        requiresWallet,
      );
}
