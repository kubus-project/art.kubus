import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/screens/desktop/desktop_shell.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/wallet/wallet_option_tile.dart';
import 'package:art_kubus/widgets/common/kubus_screen_header.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/material.dart';

enum AuthWalletEntryOption {
  walletConnect,
  createNewWallet,
  linkExistingWallet,
}

extension AuthWalletEntryOptionX on AuthWalletEntryOption {
  int get initialStep {
    switch (this) {
      case AuthWalletEntryOption.walletConnect:
        return 3;
      case AuthWalletEntryOption.createNewWallet:
        return 2;
      case AuthWalletEntryOption.linkExistingWallet:
        return 1;
    }
  }

  String get routeName {
    switch (this) {
      case AuthWalletEntryOption.walletConnect:
        return '/connect-wallet/walletconnect';
      case AuthWalletEntryOption.createNewWallet:
        return '/connect-wallet/create';
      case AuthWalletEntryOption.linkExistingWallet:
        return '/connect-wallet/link';
    }
  }

  bool get isAdvanced => this != AuthWalletEntryOption.walletConnect;

  IconData get icon {
    switch (this) {
      case AuthWalletEntryOption.walletConnect:
        return Icons.account_balance_wallet_outlined;
      case AuthWalletEntryOption.createNewWallet:
        return Icons.add_circle_outline_rounded;
      case AuthWalletEntryOption.linkExistingWallet:
        return Icons.link_rounded;
    }
  }

  String label(AppLocalizations l10n) {
    switch (this) {
      case AuthWalletEntryOption.walletConnect:
        return l10n.connectWalletOptionWalletConnectTitle;
      case AuthWalletEntryOption.createNewWallet:
        return l10n.connectWalletCreateTitle;
      case AuthWalletEntryOption.linkExistingWallet:
        return l10n.connectWalletLinkExistingTitle;
    }
  }

  String description(AppLocalizations l10n) {
    switch (this) {
      case AuthWalletEntryOption.walletConnect:
        return l10n.connectWalletOptionWalletConnectDescription;
      case AuthWalletEntryOption.createNewWallet:
        return l10n.connectWalletCreateDescription;
      case AuthWalletEntryOption.linkExistingWallet:
        return l10n.connectWalletImportDescription;
    }
  }
}

Future<AuthWalletEntryOption?> showAuthWalletEntryMenu({
  required BuildContext context,
  required String description,
}) async {
  final isDesktop = DesktopBreakpoints.isDesktop(context);

  Widget buildMenu(BuildContext menuContext) {
    return _AuthWalletEntryMenuContent(description: description);
  }

  if (isDesktop) {
    return showKubusDialog<AuthWalletEntryOption>(
      context: context,
      builder: (dialogContext) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: buildMenu(dialogContext),
      ),
    );
  }

  return showModalBottomSheet<AuthWalletEntryOption>(
    context: context,
    isScrollControlled: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(KubusRadius.xl)),
    ),
    builder: buildMenu,
  );
}

class _AuthWalletEntryMenuContent extends StatelessWidget {
  const _AuthWalletEntryMenuContent({
    required this.description,
  });

  final String description;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final options = AuthWalletEntryOption.values;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(KubusSpacing.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: LiquidGlassPanel(
            borderRadius: BorderRadius.circular(KubusRadius.xl),
            padding: const EdgeInsets.all(KubusSpacing.lg),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KubusHeaderText(
                    title: l10n.authConnectWalletModalTitle,
                    subtitle: description,
                    titleStyle: KubusTextStyles.sheetTitle.copyWith(
                      fontSize: KubusChromeMetrics.heroTitle,
                      color: scheme.onSurface,
                    ),
                    subtitleStyle: KubusTextStyles.sheetSubtitle.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.lg),
                  for (final option in options) ...[
                    _WalletEntryOptionTile(option: option),
                    if (option != options.last)
                      const SizedBox(height: KubusSpacing.sm),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletEntryOptionTile extends StatelessWidget {
  const _WalletEntryOptionTile({
    required this.option,
  });

  final AuthWalletEntryOption option;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return WalletOptionTile(
      title: option.label(l10n),
      description: option.description(l10n),
      icon: option.icon,
      isAdvanced: option.isAdvanced,
      onTap: () => Navigator.of(context).pop(option),
    );
  }
}
