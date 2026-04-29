import 'package:flutter/material.dart';

import '../../config/config.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/kubus_color_roles.dart';
import 'kubus_wallet_shell.dart';

enum WalletActionSurface {
  walletHome,
  desktopWallet,
  secureWallet,
}

class WalletActionController {
  const WalletActionController._();

  static List<WalletActionConfig> buildPrimaryActionsForProvider({
    required BuildContext context,
    required WalletProvider walletProvider,
    required VoidCallback onSend,
    required VoidCallback onReceive,
    required VoidCallback onSwap,
    required VoidCallback onSecureWallet,
    required VoidCallback onRestoreSigner,
    VoidCallback? onNfts,
    VoidCallback? onConnectExternalWallet,
    VoidCallback? onCreateLocalWallet,
    VoidCallback? onImportWallet,
    bool includeNfts = false,
    bool swapEnabled = false,
    WalletActionSurface surface = WalletActionSurface.walletHome,
  }) {
    return buildPrimaryActions(
      l10n: AppLocalizations.of(context)!,
      roles: KubusColorRoles.of(context),
      authority: walletProvider.authority,
      onSend: onSend,
      onReceive: onReceive,
      onSwap: onSwap,
      onSecureWallet: onSecureWallet,
      onRestoreSigner: onRestoreSigner,
      onNfts: onNfts,
      onConnectExternalWallet: onConnectExternalWallet,
      onCreateLocalWallet: onCreateLocalWallet,
      onImportWallet: onImportWallet,
      includeNfts: includeNfts,
      swapEnabled: swapEnabled,
      surface: surface,
    );
  }

  static List<WalletActionConfig> buildPrimaryActions({
    required AppLocalizations l10n,
    required KubusColorRoles roles,
    required WalletAuthoritySnapshot authority,
    required VoidCallback onSend,
    required VoidCallback onReceive,
    required VoidCallback onSwap,
    required VoidCallback onSecureWallet,
    required VoidCallback onRestoreSigner,
    VoidCallback? onNfts,
    VoidCallback? onConnectExternalWallet,
    VoidCallback? onCreateLocalWallet,
    VoidCallback? onImportWallet,
    bool includeNfts = false,
    bool swapEnabled = false,
    WalletActionSurface surface = WalletActionSurface.walletHome,
  }) {
    final actions = <WalletActionConfig>[];
    final canTransact = authority.canTransact;
    final hasWallet = authority.hasWalletIdentity;
    final hasAccount = authority.hasAccountSession;
    final shouldShowWalletSetup =
        !hasWallet || authority.state == WalletAuthorityState.accountShellOnly;

    if (shouldShowWalletSetup && onCreateLocalWallet != null) {
      actions.add(
        WalletActionConfig(
          type: WalletActionType.createLocalWallet,
          title: l10n.walletHomeCreateWalletAction,
          subtitle: l10n.connectWalletCreateDescription,
          icon: Icons.add_card_outlined,
          color: roles.positiveAction,
          run: onCreateLocalWallet,
          enabled: hasAccount,
          disabledReason: l10n.commonSignIn,
        ),
      );
    }

    if (shouldShowWalletSetup && onImportWallet != null) {
      actions.add(
        WalletActionConfig(
          type: WalletActionType.importWallet,
          title: l10n.walletHomeImportWalletAction,
          subtitle: l10n.connectWalletImportDescription,
          icon: Icons.file_upload_outlined,
          color: roles.statAmber,
          run: onImportWallet,
          enabled: hasAccount,
          disabledReason: l10n.commonSignIn,
        ),
      );
    }

    if (!canTransact && onConnectExternalWallet != null) {
      actions.add(
        WalletActionConfig(
          type: WalletActionType.connectExternalWallet,
          title: l10n.walletSecurityConnectExternalAction,
          subtitle: l10n.connectWalletChooseDescription,
          icon: Icons.account_balance_wallet_outlined,
          color: roles.statBlue,
          run: onConnectExternalWallet,
          enabled: hasAccount,
          disabledReason: l10n.commonSignIn,
        ),
      );
    }

    actions.addAll(<WalletActionConfig>[
      if (authority.canRestoreFromEncryptedBackup)
        WalletActionConfig(
          type: WalletActionType.restoreSigner,
          title: l10n.walletSecurityRestoreSignerAction,
          subtitle: l10n.walletSecuritySignerRestoreAvailableValue,
          icon: Icons.login_outlined,
          color: roles.positiveAction,
          run: onRestoreSigner,
        ),
      ..._transactionActions(
        l10n: l10n,
        roles: roles,
        authority: authority,
        onSend: onSend,
        onReceive: onReceive,
        onSwap: onSwap,
        onSecureWallet: onSecureWallet,
        onNfts: onNfts,
        includeNfts: includeNfts,
        swapEnabled: swapEnabled,
        surface: surface,
      ),
    ]);

    return _dedupeByType(actions);
  }

  static List<WalletActionConfig> _transactionActions({
    required AppLocalizations l10n,
    required KubusColorRoles roles,
    required WalletAuthoritySnapshot authority,
    required VoidCallback onSend,
    required VoidCallback onReceive,
    required VoidCallback onSwap,
    required VoidCallback onSecureWallet,
    VoidCallback? onNfts,
    bool includeNfts = false,
    bool swapEnabled = false,
    WalletActionSurface surface = WalletActionSurface.walletHome,
  }) {
    final canTransact = authority.canTransact;
    return <WalletActionConfig>[
      WalletActionConfig(
        type: WalletActionType.send,
        title: l10n.walletHomeSendAction,
        subtitle: l10n.walletHomeDesktopSendSubtitle,
        icon: Icons.arrow_upward_rounded,
        color: roles.negativeAction,
        run: onSend,
        enabled: canTransact,
        disabledReason: l10n.walletSessionSignerMissing,
      ),
      WalletActionConfig(
        type: WalletActionType.receive,
        title: l10n.walletHomeReceiveAction,
        subtitle: l10n.walletHomeDesktopReceiveSubtitle,
        icon: Icons.arrow_downward_rounded,
        color: roles.statBlue,
        run: onReceive,
        enabled: authority.hasWalletIdentity,
        disabledReason: l10n.walletHomeSignedOutTitle,
      ),
      if (swapEnabled || AppConfig.isFeatureEnabled('tokenSwap'))
        WalletActionConfig(
          type: WalletActionType.swap,
          title: l10n.walletHomeSwapAction,
          subtitle: l10n.walletHomeDesktopSwapSubtitle,
          icon: Icons.swap_horiz_rounded,
          color: roles.positiveAction,
          run: onSwap,
          enabled: canTransact,
          disabledReason: l10n.walletSessionSignerMissing,
        ),
      if (includeNfts && onNfts != null)
        WalletActionConfig(
          type: WalletActionType.nfts,
          title: l10n.walletHomeActionNfts,
          subtitle: l10n.walletHomeDesktopNftsSubtitle,
          icon: Icons.collections_outlined,
          color: roles.statAmber,
          run: onNfts,
        ),
      WalletActionConfig(
        type: WalletActionType.secureWallet,
        title: l10n.walletHomeSecureWalletAction,
        subtitle: l10n.walletHomeSecuritySubtitle,
        icon: Icons.shield_outlined,
        color: roles.warningAction,
        run: onSecureWallet,
        enabled: authority.hasWalletIdentity,
        disabledReason: l10n.walletHomeSignedOutTitle,
      ),
    ];
  }

  static List<WalletActionConfig> buildSecurityActions({
    required AppLocalizations l10n,
    required KubusColorRoles roles,
    required WalletAuthoritySnapshot authority,
    required VoidCallback onSecureWallet,
    required VoidCallback onRestoreSigner,
    VoidCallback? onConnectExternalWallet,
  }) {
    return _dedupeByType(<WalletActionConfig>[
      WalletActionConfig(
        type: WalletActionType.secureWallet,
        title: l10n.walletHomeSecureWalletAction,
        subtitle: l10n.walletHomeSecuritySubtitle,
        icon: Icons.shield_outlined,
        color: roles.warningAction,
        run: onSecureWallet,
        enabled: authority.hasWalletIdentity,
        disabledReason: l10n.walletHomeSignedOutTitle,
      ),
      if (authority.canRestoreFromEncryptedBackup)
        WalletActionConfig(
          type: WalletActionType.restoreSigner,
          title: l10n.walletSecurityRestoreSignerAction,
          subtitle: l10n.walletSecuritySignerRestoreAvailableValue,
          icon: Icons.login_outlined,
          color: roles.positiveAction,
          run: onRestoreSigner,
        ),
      if (!authority.canTransact && onConnectExternalWallet != null)
        WalletActionConfig(
          type: WalletActionType.connectExternalWallet,
          title: l10n.walletSecurityConnectExternalAction,
          subtitle: l10n.connectWalletChooseDescription,
          icon: Icons.account_balance_wallet_outlined,
          color: roles.statBlue,
          run: onConnectExternalWallet,
          enabled: authority.hasAccountSession,
          disabledReason: l10n.commonSignIn,
        ),
    ]);
  }

  static List<WalletActionConfig> buildRecoveryActions({
    required AppLocalizations l10n,
    required KubusColorRoles roles,
    required WalletAuthoritySnapshot authority,
    required VoidCallback onRestoreSigner,
    VoidCallback? onImportWallet,
  }) {
    return _dedupeByType(<WalletActionConfig>[
      if (authority.canRestoreFromEncryptedBackup)
        WalletActionConfig(
          type: WalletActionType.restoreSigner,
          title: l10n.walletSecurityRestoreSignerAction,
          subtitle: l10n.walletSecuritySignerRestoreAvailableValue,
          icon: Icons.login_outlined,
          color: roles.positiveAction,
          run: onRestoreSigner,
        ),
      if (!authority.canTransact && onImportWallet != null)
        WalletActionConfig(
          type: WalletActionType.importWallet,
          title: l10n.walletHomeImportWalletAction,
          subtitle: l10n.connectWalletImportDescription,
          icon: Icons.file_upload_outlined,
          color: roles.statAmber,
          run: onImportWallet,
          enabled: authority.hasAccountSession,
          disabledReason: l10n.commonSignIn,
        ),
    ]);
  }

  static List<WalletActionConfig> _dedupeByType(
    List<WalletActionConfig> actions,
  ) {
    final seen = <WalletActionType>{};
    return actions.where((action) => seen.add(action.type)).toList();
  }
}
