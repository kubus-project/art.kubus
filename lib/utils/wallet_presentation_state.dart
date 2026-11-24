import '../providers/wallet_provider.dart';

/// UI-facing wallet state shared by mobile and desktop wallet surfaces.
enum WalletPresentationState {
  unknown,
  restoring,
  accountLinkInProgress,
  accountLinkFailed,
  signedOut,
  accountShellOnly,
  walletReadOnly,
  localSignerReady,
  externalWalletReady,
  encryptedBackupAvailableSignerMissing,
  recoveryNeeded,
}

class WalletPresentationStateResolver {
  const WalletPresentationStateResolver._();

  /// [isSignedIn] is the profile provider's answer, passed in: the wallet
  /// authority knows the wallet only, so a device with no wallet reads as
  /// "account only" or "signed out" by who is signed in, not by the wallet.
  static WalletPresentationState resolve(
    WalletAuthoritySnapshot authority, {
    required bool isSignedIn,
    WalletSessionPhase sessionPhase = WalletSessionPhase.ready,
    WalletAccountLinkPhase accountLinkPhase = WalletAccountLinkPhase.unknown,
  }) {
    switch (accountLinkPhase) {
      case WalletAccountLinkPhase.inProgress:
        return WalletPresentationState.accountLinkInProgress;
      case WalletAccountLinkPhase.failed:
        return WalletPresentationState.accountLinkFailed;
      case WalletAccountLinkPhase.unknown:
        break;
    }

    switch (sessionPhase) {
      case WalletSessionPhase.idle:
        return WalletPresentationState.unknown;
      case WalletSessionPhase.restoring:
        return WalletPresentationState.restoring;
      case WalletSessionPhase.error:
      case WalletSessionPhase.ready:
        break;
    }

    return switch (authority.state) {
      WalletAuthorityState.noWallet => isSignedIn
          ? WalletPresentationState.accountShellOnly
          : WalletPresentationState.signedOut,
      WalletAuthorityState.walletReadOnly =>
        WalletPresentationState.walletReadOnly,
      WalletAuthorityState.localSignerReady =>
        WalletPresentationState.localSignerReady,
      WalletAuthorityState.externalWalletReady =>
        WalletPresentationState.externalWalletReady,
      WalletAuthorityState.encryptedBackupAvailableSignerMissing =>
        WalletPresentationState.encryptedBackupAvailableSignerMissing,
      WalletAuthorityState.recoveryNeeded =>
        WalletPresentationState.recoveryNeeded,
    };
  }

  static bool hasWalletIdentity(WalletAuthoritySnapshot authority) =>
      authority.hasWalletIdentity;

  /// True while the account-to-wallet linkage is still being established
  /// (provider not yet ready, a session restore, or a link attempt in flight).
  /// Until it settles, no copy may claim that the account has no wallet.
  static bool isLinkagePending(WalletPresentationState state) =>
      switch (state) {
        WalletPresentationState.unknown ||
        WalletPresentationState.restoring ||
        WalletPresentationState.accountLinkInProgress =>
          true,
        WalletPresentationState.signedOut ||
        WalletPresentationState.accountLinkFailed ||
        WalletPresentationState.accountShellOnly ||
        WalletPresentationState.walletReadOnly ||
        WalletPresentationState.localSignerReady ||
        WalletPresentationState.externalWalletReady ||
        WalletPresentationState.encryptedBackupAvailableSignerMissing ||
        WalletPresentationState.recoveryNeeded =>
          false,
      };

  /// [isLinkagePending] for the live provider, resolved the same way the
  /// wallet home resolves its own loading state.
  static bool linkagePendingFor(WalletProvider walletProvider) =>
      isLinkagePending(
        resolve(
          walletProvider.authority,
          // Linkage pending is decided by the session and link phases, which
          // return before the authority mapping, and every non-pending state
          // is non-pending whatever [isSignedIn] says, so it is not an input.
          isSignedIn: false,
          sessionPhase: walletProvider.sessionPhase,
          accountLinkPhase: walletProvider.accountLinkPhase,
        ),
      );
}
