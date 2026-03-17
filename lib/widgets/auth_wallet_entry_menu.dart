import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/screens/desktop/desktop_shell.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
        return Icons.qr_code_2_outlined;
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
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(KubusSpacing.lg),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.authConnectWalletModalTitle,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.xs),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.45,
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
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(option),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.22),
            ),
          ),
          padding: const EdgeInsets.all(KubusSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  option.icon,
                  color: scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: KubusSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            option.label(l10n),
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        if (option.isAdvanced)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: KubusSpacing.sm,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.secondary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              l10n.connectWalletAdvancedBadge,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: scheme.secondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.description(l10n),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.35,
                        color: scheme.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KubusSpacing.sm),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: scheme.onSurface.withValues(alpha: 0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
