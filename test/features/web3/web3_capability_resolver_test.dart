import 'package:art_kubus/features/web3/web3_capabilities.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

WalletAuthoritySnapshot authority({
  bool accountSignedIn = true,
  String? walletAddress = 'wallet-owner',
  bool signerReady = true,
  String accountRole = 'user',
}) {
  return WalletAuthoritySnapshot(
    state: !accountSignedIn
        ? WalletAuthorityState.signedOut
        : walletAddress == null
            ? WalletAuthorityState.accountShellOnly
            : signerReady
                ? WalletAuthorityState.localSignerReady
                : WalletAuthorityState.walletReadOnly,
    signerSource:
        signerReady ? WalletSignerSource.local : WalletSignerSource.none,
    accountSignedIn: accountSignedIn,
    signInMethod: AuthSignInMethod.email,
    accountEmail: accountSignedIn ? 'person@example.test' : null,
    accountRole: accountRole,
    walletAddress: walletAddress,
    hasLocalSigner: signerReady,
    hasExternalSigner: false,
    externalWalletConnected: false,
    externalWalletName: null,
    hasEncryptedBackup: false,
    encryptedBackupStatusKnown: true,
    hasPasskeyProtection: false,
    mnemonicBackupRequired: false,
    recoveryNeeded: false,
  );
}

Web3CapabilityContext contextFor({
  WalletAuthoritySnapshot? walletAuthority,
  bool profileHydrated = true,
  bool profileSignedIn = true,
  bool profileIsArtist = false,
  bool profileIsInstitution = false,
  bool web3Enabled = true,
  bool governanceEnabled = true,
  bool marketplaceEnabled = true,
  bool editionCreationEnabled = true,
  bool daoModerationEnabled = true,
  bool entityIsListed = false,
  String? entityOwnerAddress,
  bool acquisitionSupported = false,
  bool mintingSupported = false,
  bool daoReviewAuthority = false,
  bool treasuryMutationSupported = false,
}) {
  return Web3CapabilityContext(
    authority: walletAuthority ?? authority(),
    profileHydrated: profileHydrated,
    profileSignedIn: profileSignedIn,
    profileIsArtist: profileIsArtist,
    profileIsInstitution: profileIsInstitution,
    web3Enabled: web3Enabled,
    governanceEnabled: governanceEnabled,
    marketplaceEnabled: marketplaceEnabled,
    editionCreationEnabled: editionCreationEnabled,
    daoModerationEnabled: daoModerationEnabled,
    daoTreasuryMutationEnabled: true,
    daoReviewAuthority: daoReviewAuthority,
    treasuryMutationSupported: treasuryMutationSupported,
    entityOwnerAddress: entityOwnerAddress,
    entityIsListed: entityIsListed,
    acquisitionSupported: acquisitionSupported,
    mintingSupported: mintingSupported,
  );
}

void main() {
  test('guest can browse enabled public surfaces but cannot mutate', () {
    final capabilities = Web3CapabilityResolver.resolve(
      contextFor(
        walletAuthority: authority(
          accountSignedIn: false,
          walletAddress: null,
          signerReady: false,
        ),
        profileHydrated: true,
        profileSignedIn: false,
      ),
    );

    expect(capabilities.needsAccount, isTrue);
    expect(capabilities.canViewGovernance, isTrue);
    expect(capabilities.canViewDigitalEditions, isTrue);
    expect(capabilities.canVote, isFalse);
    expect(capabilities.canCreateProposal, isFalse);
    expect(capabilities.canDelegate, isFalse);
    expect(capabilities.canModerateDao, isFalse);
    expect(capabilities.canMutateTreasury, isFalse);
    expect(capabilities.canAcquireEdition, isFalse);
  });

  test('account without wallet identity cannot participate', () {
    final capabilities = Web3CapabilityResolver.resolve(
      contextFor(
        walletAuthority: authority(walletAddress: null, signerReady: false),
      ),
    );

    expect(capabilities.hasAccount, isTrue);
    expect(capabilities.hasWalletIdentity, isFalse);
    expect(capabilities.canTransact, isFalse);
    expect(capabilities.canCreateProposal, isFalse);
    expect(capabilities.canCreateEdition, isFalse);
  });

  test('wallet identity without signer is read-only', () {
    final capabilities = Web3CapabilityResolver.resolve(
      contextFor(walletAuthority: authority(signerReady: false)),
    );

    expect(capabilities.hasWalletIdentity, isTrue);
    expect(capabilities.signerReady, isFalse);
    expect(capabilities.canVote, isFalse);
    expect(capabilities.canDelegate, isFalse);
    expect(capabilities.canListEdition, isFalse);
  });

  test('signer-ready creator can create and manage owned editions', () {
    final capabilities = Web3CapabilityResolver.resolve(
      contextFor(
        profileIsArtist: true,
        entityOwnerAddress: 'wallet-owner',
      ),
    );

    expect(capabilities.canCreateProposal, isTrue);
    expect(capabilities.canVote, isTrue);
    expect(capabilities.canDelegate, isTrue);
    expect(capabilities.canCreateEdition, isTrue);
    expect(capabilities.canManageEdition, isTrue);
    expect(capabilities.canListEdition, isTrue);
    expect(capabilities.canUnlistEdition, isFalse);
  });

  test('owner listing actions switch deterministically with listing state', () {
    final listed = Web3CapabilityResolver.resolve(
      contextFor(
        entityOwnerAddress: 'wallet-owner',
        entityIsListed: true,
      ),
    );
    final nonOwner = Web3CapabilityResolver.resolve(
      contextFor(
        entityOwnerAddress: 'different-wallet',
        entityIsListed: true,
        acquisitionSupported: false,
      ),
    );

    expect(listed.canListEdition, isFalse);
    expect(listed.canUnlistEdition, isTrue);
    expect(nonOwner.canManageEdition, isFalse);
    expect(nonOwner.canAcquireEdition, isFalse);
  });

  test('moderation requires signer, feature, and moderator role', () {
    final ordinary = Web3CapabilityResolver.resolve(contextFor());
    final moderator = Web3CapabilityResolver.resolve(
      contextFor(walletAuthority: authority(accountRole: 'moderator')),
    );
    final disabled = Web3CapabilityResolver.resolve(
      Web3CapabilityContext(
        authority: authority(accountRole: 'admin'),
        profileHydrated: true,
        profileSignedIn: true,
        profileIsArtist: false,
        profileIsInstitution: false,
        web3Enabled: true,
        governanceEnabled: true,
        marketplaceEnabled: true,
        editionCreationEnabled: true,
        daoModerationEnabled: false,
        daoTreasuryMutationEnabled: true,
      ),
    );

    expect(ordinary.canModerateDao, isFalse);
    expect(moderator.canModerateDao, isTrue);
    expect(disabled.canModerateDao, isFalse);
  });

  test('server-derived reviewer authority enables allowlisted moderators', () {
    final capabilities = Web3CapabilityResolver.resolve(
      contextFor(
        daoReviewAuthority: true,
        treasuryMutationSupported: true,
      ),
    );

    expect(capabilities.canModerateDao, isTrue);
    expect(capabilities.canMutateTreasury, isFalse);
  });

  test('feature-disabled surfaces expose no capabilities', () {
    final capabilities = Web3CapabilityResolver.resolve(
      contextFor(
        web3Enabled: false,
        governanceEnabled: false,
        marketplaceEnabled: false,
        profileIsArtist: true,
        entityOwnerAddress: 'wallet-owner',
        acquisitionSupported: true,
        mintingSupported: true,
      ),
    );

    expect(capabilities.canViewGovernance, isFalse);
    expect(capabilities.canViewDigitalEditions, isFalse);
    expect(capabilities.canCreateProposal, isFalse);
    expect(capabilities.canCreateEdition, isFalse);
    expect(capabilities.canAcquireEdition, isFalse);
    expect(capabilities.canMintEdition, isFalse);
  });

  test('profile hydration fails closed without flashing privileged actions',
      () {
    final capabilities = Web3CapabilityResolver.resolve(
      contextFor(profileHydrated: false, profileSignedIn: true),
    );

    expect(capabilities.hasAccount, isFalse);
    expect(capabilities.canTransact, isFalse);
    expect(capabilities.canCreateProposal, isFalse);
  });
}
