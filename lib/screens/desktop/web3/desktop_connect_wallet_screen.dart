import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/design_tokens.dart';
import '../../../widgets/glass_components.dart';
import '../../web3/wallet/connectwallet_screen.dart';

/// Desktop composition for the shared wallet connect/create/import flow.
///
/// Instead of dropping the mobile full-screen [ConnectWallet] experience inside
/// the desktop shell, this wraps the flow in its embedded mode and pairs it with
/// a calm left-hand security/account explanation column on wide viewports.
class DesktopConnectWalletScreen extends StatelessWidget {
  final int initialStep;
  final String? telemetryAuthFlow;
  final String? requiredWalletAddress;

  const DesktopConnectWalletScreen({
    super.key,
    this.initialStep = 0,
    this.telemetryAuthFlow,
    this.requiredWalletAddress,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final flowCard = LiquidGlassCard(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: ConnectWallet(
        embedded: true,
        initialStep: initialStep,
        telemetryAuthFlow: telemetryAuthFlow,
        requiredWalletAddress: requiredWalletAddress,
      ),
    );

    final explanation = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(KubusRadius.lg),
          ),
          child: Icon(
            Icons.account_balance_wallet_outlined,
            size: 32,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: KubusSpacing.lg),
        Text(
          l10n.walletHomeSignedOutTitle,
          style: KubusTextStyles.sectionTitle.copyWith(
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: KubusSpacing.sm),
        Text(
          l10n.connectWalletChooseDescription,
          style: KubusTextStyles.detailBody.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.72),
            height: 1.6,
          ),
        ),
        if ((requiredWalletAddress ?? '').trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: KubusSpacing.md),
          _InfoRow(
            icon: Icons.link_rounded,
            text: l10n.walletHomeAddressLabel(requiredWalletAddress!.trim()),
            scheme: scheme,
          ),
        ],
        const SizedBox(height: KubusSpacing.md),
        _InfoRow(
          icon: Icons.shield_outlined,
          text: l10n.walletSecurityBackendBackupClarifier,
          scheme: scheme,
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Padding(
              padding: const EdgeInsets.all(KubusSpacing.xl),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 880) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(width: 320, child: explanation),
                        const SizedBox(width: KubusSpacing.xxl),
                        Expanded(child: flowCard),
                      ],
                    );
                  }
                  // Embedded ConnectWallet uses Expanded/SizedBox.expand and
                  // needs a bounded height; give it the available viewport
                  // height instead of an unbounded scroll view.
                  return SizedBox(
                    height: constraints.maxHeight,
                    child: flowCard,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    required this.scheme,
  });

  final IconData icon;
  final String text;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: KubusSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: KubusTextStyles.detailCaption.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.68),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
