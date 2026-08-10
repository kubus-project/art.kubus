import '../../config/config.dart';
import '../../providers/profile_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/wallet_utils.dart';

class Web3CapabilityContext {
  const Web3CapabilityContext({
    required this.authority,
    required this.profileHydrated,
    required this.profileSignedIn,
    required this.profileIsArtist,
    required this.profileIsInstitution,
    required this.web3Enabled,
    required this.governanceEnabled,
    required this.marketplaceEnabled,
    required this.editionCreationEnabled,
    required this.daoModerationEnabled,
    required this.daoTreasuryMutationEnabled,
    this.entityOwnerAddress,
    this.entityIsListed = false,
    this.proposalAllowsVoting = true,
    this.acquisitionSupported = false,
    this.mintingSupported = false,
    this.listingSupported = true,
    this.treasuryMutationSupported = false,
  });

  factory Web3CapabilityContext.fromProviders({
    required ProfileProvider profileProvider,
    required WalletProvider walletProvider,
    String? entityOwnerAddress,
    bool entityIsListed = false,
    bool proposalAllowsVoting = true,
    bool acquisitionSupported = false,
    bool mintingSupported = false,
    bool listingSupported = true,
    bool treasuryMutationSupported = false,
  }) {
    return Web3CapabilityContext(
      authority: walletProvider.authority,
      profileHydrated: profileProvider.hasHydratedProfile,
      profileSignedIn: profileProvider.isSignedIn,
      profileIsArtist: profileProvider.currentUser?.isArtist ?? false,
      profileIsInstitution: profileProvider.currentUser?.isInstitution ?? false,
      web3Enabled: AppConfig.isFeatureEnabled('web3'),
      governanceEnabled: AppConfig.isFeatureEnabled('dao'),
      marketplaceEnabled: AppConfig.isFeatureEnabled('marketplace'),
      editionCreationEnabled: AppConfig.isFeatureEnabled('nftMinting'),
      daoModerationEnabled: AppConfig.isFeatureEnabled('daoReviewDecisions'),
      daoTreasuryMutationEnabled:
          AppConfig.isFeatureEnabled('daoOnchainTreasury'),
      entityOwnerAddress: entityOwnerAddress,
      entityIsListed: entityIsListed,
      proposalAllowsVoting: proposalAllowsVoting,
      acquisitionSupported: acquisitionSupported,
      mintingSupported: mintingSupported,
      listingSupported: listingSupported,
      treasuryMutationSupported: treasuryMutationSupported,
    );
  }

  final WalletAuthoritySnapshot authority;
  final bool profileHydrated;
  final bool profileSignedIn;
  final bool profileIsArtist;
  final bool profileIsInstitution;
  final bool web3Enabled;
  final bool governanceEnabled;
  final bool marketplaceEnabled;
  final bool editionCreationEnabled;
  final bool daoModerationEnabled;
  final bool daoTreasuryMutationEnabled;
  final String? entityOwnerAddress;
  final bool entityIsListed;
  final bool proposalAllowsVoting;
  final bool acquisitionSupported;
  final bool mintingSupported;
  final bool listingSupported;
  final bool treasuryMutationSupported;
}

class Web3Capabilities {
  const Web3Capabilities({
    required this.needsAccount,
    required this.hasAccount,
    required this.hasWalletIdentity,
    required this.signerReady,
    required this.canTransact,
    required this.canViewGovernance,
    required this.canViewOwnGovernanceHistory,
    required this.canVote,
    required this.canCreateProposal,
    required this.canDelegate,
    required this.canModerateDao,
    required this.canMutateTreasury,
    required this.canViewDigitalEditions,
    required this.canCreateEdition,
    required this.canManageEdition,
    required this.canListEdition,
    required this.canUnlistEdition,
    required this.canMintEdition,
    required this.canAcquireEdition,
  });

  final bool needsAccount;
  final bool hasAccount;
  final bool hasWalletIdentity;
  final bool signerReady;
  final bool canTransact;

  final bool canViewGovernance;
  final bool canViewOwnGovernanceHistory;
  final bool canVote;
  final bool canCreateProposal;
  final bool canDelegate;
  final bool canModerateDao;
  final bool canMutateTreasury;

  final bool canViewDigitalEditions;
  final bool canCreateEdition;
  final bool canManageEdition;
  final bool canListEdition;
  final bool canUnlistEdition;
  final bool canMintEdition;
  final bool canAcquireEdition;
}

class Web3CapabilityResolver {
  const Web3CapabilityResolver._();

  static Web3Capabilities resolve(Web3CapabilityContext context) {
    final authority = context.authority;
    final hasAccount = context.profileHydrated &&
        context.profileSignedIn &&
        authority.hasAccountSession;
    final hasWalletIdentity = authority.hasWalletIdentity;
    final signerReady = authority.canTransact;
    final canTransact = hasAccount && hasWalletIdentity && signerReady;
    final accountRole = authority.accountRole.trim().toLowerCase();
    final isDaoModerator = accountRole == 'admin' || accountRole == 'moderator';
    final isEditionCreator =
        context.profileIsArtist || context.profileIsInstitution;
    final ownsEntity = hasWalletIdentity &&
        WalletUtils.equals(
          authority.walletAddress,
          context.entityOwnerAddress,
        );

    final canViewGovernance = context.web3Enabled && context.governanceEnabled;
    final canParticipateInGovernance = canViewGovernance && canTransact;
    final canViewDigitalEditions =
        context.web3Enabled && context.marketplaceEnabled;
    final canManageEdition =
        canViewDigitalEditions && canTransact && ownsEntity;

    return Web3Capabilities(
      needsAccount: !hasAccount,
      hasAccount: hasAccount,
      hasWalletIdentity: hasWalletIdentity,
      signerReady: signerReady,
      canTransact: canTransact,
      canViewGovernance: canViewGovernance,
      canViewOwnGovernanceHistory:
          canViewGovernance && hasAccount && hasWalletIdentity,
      canVote: canParticipateInGovernance && context.proposalAllowsVoting,
      canCreateProposal: canParticipateInGovernance,
      canDelegate: canParticipateInGovernance,
      canModerateDao: canParticipateInGovernance &&
          context.daoModerationEnabled &&
          isDaoModerator,
      canMutateTreasury: canParticipateInGovernance &&
          context.daoTreasuryMutationEnabled &&
          context.treasuryMutationSupported &&
          isDaoModerator,
      canViewDigitalEditions: canViewDigitalEditions,
      canCreateEdition: canViewDigitalEditions &&
          canTransact &&
          context.editionCreationEnabled &&
          isEditionCreator,
      canManageEdition: canManageEdition,
      canListEdition: canManageEdition &&
          context.listingSupported &&
          !context.entityIsListed,
      canUnlistEdition: canManageEdition &&
          context.listingSupported &&
          context.entityIsListed,
      canMintEdition: canViewDigitalEditions &&
          canTransact &&
          context.editionCreationEnabled &&
          context.mintingSupported &&
          isEditionCreator,
      canAcquireEdition: canViewDigitalEditions &&
          canTransact &&
          context.acquisitionSupported &&
          context.entityIsListed &&
          !ownsEntity,
    );
  }
}
