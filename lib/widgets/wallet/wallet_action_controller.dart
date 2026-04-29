import 'package:flutter/material.dart';

import '../../config/config.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/kubus_color_roles.dart';
import 'kubus_wallet_shell.dart';

class WalletActionController {
  const WalletActionController._();

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
    bool includeNfts = false,
    bool swapEnabled = false,
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
      if (authority.canRestoreFromEncryptedBackup)
        WalletActionConfig(
          type: WalletActionType.restoreSigner,
          title: l10n.walletSecurityRestoreSignerAction,
          subtitle: l10n.walletSecuritySignerRestoreAvailableValue,
          icon: Icons.login_outlined,
          color: roles.positiveAction,
          run: onRestoreSigner,
        ),
    ];
  }
}
