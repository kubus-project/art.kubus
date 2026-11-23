import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/utils/wallet_presentation_state.dart';
import 'package:flutter_test/flutter_test.dart';

WalletAuthoritySnapshot _authority(WalletAuthorityState state) {
  final hasWallet = state != WalletAuthorityState.noWallet;
  return WalletAuthoritySnapshot(
    state: state,
    signerSource: switch (state) {
      WalletAuthorityState.localSignerReady => WalletSignerSource.local,
      WalletAuthorityState.externalWalletReady => WalletSignerSource.external,
      _ => WalletSignerSource.none,
    },
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
  test('resolves every wallet state for shared wallet presentation', () {
    const expectedStates = <WalletAuthorityState, WalletPresentationState>{
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
      // A wallet state reads the same whether or not an account is signed in.
      for (final signedIn in const [true, false]) {
        expect(
          WalletPresentationStateResolver.resolve(
            _authority(entry.key),
            isSignedIn: signedIn,
          ),
          entry.value,
        );
      }
    }
  });

  test(
      'a device with no wallet reads as signed out or account only by who is '
      'signed in', () {
    final authority = _authority(WalletAuthorityState.noWallet);

    expect(
      WalletPresentationStateResolver.resolve(authority, isSignedIn: false),
      WalletPresentationState.signedOut,
    );
    expect(
      WalletPresentationStateResolver.resolve(authority, isSignedIn: true),
      WalletPresentationState.accountShellOnly,
    );
  });

  test('no wallet is walletless', () {
    expect(
      WalletPresentationStateResolver.hasWalletIdentity(
        _authority(WalletAuthorityState.noWallet),
      ),
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
    final inconsistentSnapshot = _authority(WalletAuthorityState.noWallet);
    final walletSnapshotWithMissingSigner = WalletAuthoritySnapshot(
      state: inconsistentSnapshot.state,
      signerSource: inconsistentSnapshot.signerSource,
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
    final authority = _authority(WalletAuthorityState.noWallet);

    expect(
      WalletPresentationStateResolver.resolve(
        authority,
        isSignedIn: true,
        sessionPhase: WalletSessionPhase.idle,
      ),
      WalletPresentationState.unknown,
    );
    expect(
      WalletPresentationStateResolver.resolve(
        authority,
        isSignedIn: true,
        sessionPhase: WalletSessionPhase.restoring,
      ),
      WalletPresentationState.restoring,
    );
    expect(
      WalletPresentationStateResolver.resolve(
        authority,
        isSignedIn: true,
        sessionPhase: WalletSessionPhase.error,
      ),
      WalletPresentationState.accountShellOnly,
    );
  });

  test('account-link lifecycle takes precedence over wallet authority', () {
    final authority = _authority(WalletAuthorityState.noWallet);

    expect(
      WalletPresentationStateResolver.resolve(
        authority,
        isSignedIn: true,
        accountLinkPhase: WalletAccountLinkPhase.inProgress,
      ),
      WalletPresentationState.accountLinkInProgress,
    );
    expect(
      WalletPresentationStateResolver.resolve(
        authority,
        isSignedIn: true,
        accountLinkPhase: WalletAccountLinkPhase.failed,
      ),
      WalletPresentationState.accountLinkFailed,
    );
  });
}
