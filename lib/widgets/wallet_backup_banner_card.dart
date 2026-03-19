import 'dart:async';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/web3/wallet/mnemonic_reveal_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/kubus_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletBackupBannerCard extends StatefulWidget {
  const WalletBackupBannerCard({
    super.key,
    this.padding = EdgeInsets.zero,
    this.bottomSpacing = 0,
  });

  final EdgeInsetsGeometry padding;
  final double bottomSpacing;

  @override
  State<WalletBackupBannerCard> createState() => _WalletBackupBannerCardState();
}

class _WalletBackupBannerCardState extends State<WalletBackupBannerCard> {
  bool _loaded = false;
  bool _shouldShow = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<String?> _resolveWalletAddress() async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final fromProfile = (profileProvider.currentUser?.walletAddress ?? '').trim();
    if (fromProfile.isNotEmpty) return fromProfile;
    final fromWallet = (walletProvider.currentWalletAddress ?? '').trim();
    if (fromWallet.isNotEmpty) return fromWallet;
    final fromSession = (BackendApiService().getCurrentAuthWalletAddress() ?? '').trim();
    if (fromSession.isNotEmpty) return fromSession;

    final prefs = await SharedPreferences.getInstance();
    final fallback = (prefs.getString(PreferenceKeys.walletAddress) ??
            prefs.getString('wallet_address') ??
            prefs.getString('walletAddress') ??
            prefs.getString('wallet') ??
            '')
        .trim();
    return fallback.isEmpty ? null : fallback;
  }

  Future<void> _load() async {
    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final walletAddress = await _resolveWalletAddress();
      final shouldShow = (walletAddress ?? '').isNotEmpty &&
          await walletProvider.isMnemonicBackupRequired(
            walletAddress: walletAddress,
          );
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _shouldShow = shouldShow;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _shouldShow = false;
      });
    }
  }

  Future<void> _openBackupFlow() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MnemonicRevealScreen()),
    );
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || !_shouldShow) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    Widget card = KubusCard(
      padding: const EdgeInsets.all(KubusSpacing.md),
      color: scheme.surfaceContainerHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.vpn_key_outlined,
                color: scheme.onSurface.withValues(alpha: 0.85),
                size: 20,
              ),
              const SizedBox(width: KubusSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.walletBackupBannerTitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.walletBackupBannerSubtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.3,
                        color: scheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _openBackupFlow,
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: Text(
                l10n.walletBackupBannerAction,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.primary,
                side: BorderSide(color: scheme.primary.withValues(alpha: 0.45)),
                padding: const EdgeInsets.symmetric(
                  horizontal: KubusSpacing.md,
                  vertical: KubusSpacing.sm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.padding != EdgeInsets.zero) {
      card = Padding(padding: widget.padding, child: card);
    }

    final bottom = widget.bottomSpacing;
    if (bottom <= 0) return card;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        card,
        SizedBox(height: bottom),
      ],
    );
  }
}
