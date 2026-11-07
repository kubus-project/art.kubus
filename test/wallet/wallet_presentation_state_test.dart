import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/utils/wallet_presentation_state.dart';
import 'package:flutter_test/flutter_test.dart';

WalletAuthoritySnapshot _authority(WalletAuthorityState state) {
  final hasWallet = state != WalletAuthorityState.signedOut &&
      state != WalletAuthorityState.accountShellOnly;
  return WalletAuthoritySnapshot(
    state: state,
    signerSource: switch (state) {
      WalletAuthorityState.localSignerReady => WalletSignerSource.local,
      WalletAuthorityState.externalWalletReady => WalletSignerSource.external,
      _ => WalletSignerSource.none,
    },
    accountSignedIn: state != WalletAuthorityState.signedOut,
    signInMethod: AuthSignInMethod.email,
    accountEmail: 'wallet-test@example.com',
    walletAddress: hasWallet ? 'test-wallet-address' : null,
    hasLocalSigner: state == WalletAuthorityState.localSignerReady,
    hasExternalSigner: state == WalletAuthorityState.externalWalletReady,
    externalWalletConnected: state == WalletAuthorityState.externalWalletReady,
    externalWalletName: null,
    hasEncryptedBackup:
        state == WalletAuthorityState.encryptedBackupAvailableSignerMissing,
    encryptedBackupStatusKnown: true,
    hasPasskeyProtection: false,
    mnemonicBackupRequired: false,
    recoveryNeeded: state == WalletAuthorityState.recoveryNeeded,
  );
}

void main() {
  test('resolves every authority state for shared wallet presentation', () {
    const expectedStates = <WalletAuthorityState, WalletPresentationState>{
      WalletAuthorityState.signedOut: WalletPresentationState.signedOut,
      WalletAuthorityState.accountShellOnly:
          WalletPresentationState.accountShellOnly,
      WalletAuthorityState.walletReadOnly:
          WalletPresentationState.walletReadOnly,
      WalletAuthorityState.localSignerReady:
          WalletPresentationState.localSignerReady,
      WalletAuthorityState.externalWalletReady:
          WalletPresentationState.externalWalletReady,
      WalletAuthorityState.encryptedBackupAvailableSignerMissing:
          WalletPresentationState.encryptedBackupAvailableSignerMissing,
      WalletAuthorityState.recoveryNeeded:
          WalletPresentationState.recoveryNeeded,
    };
    for (final entry in expectedStates.entries) {
      expect(
        WalletPresentationStateResolver.resolve(_authority(entry.key)),
        entry.value,
      );
    }
  });

  test('guest and account shell are walletless', () {
    expect(
      WalletPresentationStateResolver.hasWalletIdentity(
        _authority(WalletAuthorityState.signedOut),
      ),
      isFalse,
    );
    final authority = _authority(WalletAuthorityState.accountShellOnly);

    expect(
      WalletPresentationStateResolver.hasWalletIdentity(authority),
      isFalse,
    );
  });

  test('known wallet without signer remains a wallet identity', () {
    for (final state in [
      WalletAuthorityState.walletReadOnly,
      WalletAuthorityState.encryptedBackupAvailableSignerMissing,
      WalletAuthorityState.recoveryNeeded,
    ]) {
      expect(
        WalletPresentationStateResolver.hasWalletIdentity(_authority(state)),
        isTrue,
      );
    }
  });

  test('wallet identity comes from the snapshot, not its presentation label',
      () {
    final inconsistentSnapshot = _authority(WalletAuthorityState.signedOut);
    final walletSnapshotWithMissingSigner = WalletAuthoritySnapshot(
      state: inconsistentSnapshot.state,
      signerSource: inconsistentSnapshot.signerSource,
      accountSignedIn: inconsistentSnapshot.accountSignedIn,
      signInMethod: inconsistentSnapshot.signInMethod,
      accountEmail: inconsistentSnapshot.accountEmail,
      walletAddress: 'known-wallet-address',
      hasLocalSigner: false,
      hasExternalSigner: false,
      externalWalletConnected: false,
      externalWalletName: null,
      hasEncryptedBackup: false,
      encryptedBackupStatusKnown: false,
      hasPasskeyProtection: false,
      mnemonicBackupRequired: false,
      recoveryNeeded: false,
    );
    expect(
      WalletPresentationStateResolver.hasWalletIdentity(
        walletSnapshotWithMissingSigner,
      ),
      isTrue,
    );
  });

  test('unresolved and restoring sessions do not render a walletless state',
      () {
    final authority = _authority(WalletAuthorityState.accountShellOnly);

    expect(
      WalletPresentationStateResolver.resolve(
        authority,
        sessionPhase: WalletSessionPhase.idle,
      ),
      WalletPresentationState.unknown,
    );
    expect(
      WalletPresentationStateResolver.resolve(
        authority,
        sessionPhase: WalletSessionPhase.restoring,
      ),
      WalletPresentationState.restoring,
    );
    expect(
      WalletPresentationStateResolver.resolve(
        authority,
        sessionPhase: WalletSessionPhase.error,
      ),
      WalletPresentationState.accountShellOnly,
    );
  });

  test('account-link lifecycle takes precedence over wallet authority', () {
    final authority = _authority(WalletAuthorityState.accountShellOnly);

    expect(
      WalletPresentationStateResolver.resolve(
        authority,
        accountLinkPhase: WalletAccountLinkPhase.inProgress,
      ),
      WalletPresentationState.accountLinkInProgress,
    );
    expect(
      WalletPresentationStateResolver.resolve(
        authority,
        accountLinkPhase: WalletAccountLinkPhase.failed,
      ),
      WalletPresentationState.accountLinkFailed,
    );
  });
}
