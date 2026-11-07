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

  static WalletPresentationState resolve(
    WalletAuthoritySnapshot authority, {
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
      WalletAuthorityState.signedOut => WalletPresentationState.signedOut,
      WalletAuthorityState.accountShellOnly =>
        WalletPresentationState.accountShellOnly,
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
}
