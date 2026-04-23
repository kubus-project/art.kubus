import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../../config/config.dart';
import '../../../utils/design_tokens.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/navigation_provider.dart';
import '../../../widgets/app_loading.dart';
import 'wallet_backup_protection_screen.dart';
import '../../../models/wallet.dart';
import 'nft_gallery.dart';
import 'token_swap.dart';
import 'send_token_screen.dart';
import 'receive_token_screen.dart';
import '../../settings_screen.dart';
import '../../../widgets/empty_state_card.dart';
import '../../../widgets/common/keyboard_inset_padding.dart';
import '../../../widgets/glass_components.dart';
import '../../../widgets/wallet_custody_status_panel.dart';
import '../../../widgets/wallet_transaction_card.dart';
import '../../../widgets/attestation_badge_panel.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../widgets/kubus_action_sidebar.dart';
import '../../../widgets/wallet/kubus_wallet_shell.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/utils/wallet_reconnect_action.dart';

class WalletHome extends StatefulWidget {
  const WalletHome({super.key});

  @override
  State<WalletHome> createState() => _WalletHomeState();
}

class _WalletHomeState extends State<WalletHome> {
  @override
  void initState() {
    super.initState();
    // Track this screen visit for quick actions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NavigationProvider>(context, listen: false)
          .trackScreenVisit('wallet');
    });
  }

  Future<void> _handleReadOnlyReconnect(WalletProvider walletProvider) async {
    await WalletReconnectAction.handleReadOnlyReconnect(
      context: context,
      walletProvider: walletProvider,
      refreshBackendSession: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        final l10n = AppLocalizations.of(context)!;
        final wallet = walletProvider.wallet;
        final walletAddress = walletProvider.currentWalletAddress;
        final tokens = walletProvider.tokens;
        final isLoading = walletProvider.isLoading;
        final isReadOnlySession = walletProvider.isReadOnlySession;
        final canTransact = walletProvider.canTransact;
        final authority = walletProvider.authority;

        // Show loading indicator while wallet is loading
        if (isLoading) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Text(
                l10n.walletHomeTitle,
                style: KubusTextStyles.mobileAppBarTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppLoading(),
                  const SizedBox(height: 16),
                  Text(
                    l10n.walletHomeLoadingLabel,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Show empty state when there is no wallet identity on this device.
        if (!authority.hasWalletIdentity) {
          final isAccountShellOnly =
              authority.state == WalletAuthorityState.accountShellOnly;
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Text(
                l10n.walletHomeTitle,
                style: KubusTextStyles.mobileAppBarTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.settings,
                      color: Theme.of(context).colorScheme.onSurface),
                  onPressed: _showWalletSettings,
                ),
              ],
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 24.0),
                child: SizedBox(
                  width: double.infinity,
                  child: EmptyStateCard(
                    icon: Icons.account_balance_wallet_outlined,
                    title: isAccountShellOnly
                        ? l10n.walletHomeAccountShellTitle
                        : l10n.walletHomeSignedOutTitle,
                    description: isAccountShellOnly
                        ? l10n.walletHomeAccountShellDescription
                        : l10n.walletHomeSignedOutDescription,
                    showAction: true,
                    actionLabel: isAccountShellOnly
                        ? l10n.walletHomeRestoreWalletAction
                        : l10n.authConnectWalletButton,
                    onAction: () {
                      final walletProvider =
                          Provider.of<WalletProvider>(context, listen: false);
                      if (!walletProvider.hasWalletIdentity) {
                        Navigator.pushReplacementNamed(
                            context, '/connect-wallet');
                      } else {
                        ScaffoldMessenger.of(context).showKubusSnackBar(
                          SnackBar(
                              content:
                                  Text(l10n.walletHomeAlreadyConnectedToast)),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 720;
            final isWide = constraints.maxWidth >= 1100;
            final roles = KubusColorRoles.of(context);
            final analytics = walletProvider.getWalletAnalytics();
            final swapEnabled = AppConfig.isFeatureEnabled('tokenSwap');

            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                title: Text(
                  l10n.walletHomeTitle,
                  style: KubusTextStyles.mobileAppBarTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                actions: [
                  TextButton.icon(
                    onPressed: _openBackupProtection,
                    icon: Icon(
                      Icons.shield_outlined,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    label: Text(
                      l10n.walletHomeSecureWalletAction,
                      style: KubusTextStyles.detailButton.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.settings,
                        color: Theme.of(context).colorScheme.onSurface),
                    onPressed: _showWalletSettings,
                  ),
                ],
              ),
              body: KubusWalletResponsiveShell(
                wideBreakpoint: 1120,
                mainChildren: <Widget>[
                  _buildWalletHeroCard(
                    wallet: wallet,
                    walletAddress: walletAddress,
                    isReadOnlySession: isReadOnlySession,
                    stats: <KubusWalletStatsStripItem>[
                      KubusWalletStatsStripItem(
                        label: l10n.walletHomeYourTokensTitle,
                        value: tokens.length.toString(),
                        accent: roles.statAmber,
                      ),
                      KubusWalletStatsStripItem(
                        label: l10n.walletHomeRecentTransactionsTitle,
                        value: (analytics['totalTransactions'] as int? ?? 0)
                            .toString(),
                        accent: roles.statTeal,
                      ),
                      KubusWalletStatsStripItem(
                        label: l10n.walletHomeReceiveAction,
                        value: (analytics['receivedTransactions'] as int? ?? 0)
                            .toString(),
                        accent: roles.statBlue,
                      ),
                      KubusWalletStatsStripItem(
                        label: l10n.walletHomeSwapAction,
                        value: (analytics['swapTransactions'] as int? ?? 0)
                            .toString(),
                        accent: roles.positiveAction,
                      ),
                    ],
                  ),
                  const SizedBox(height: KubusSpacing.lg),
                  KubusWalletSectionCard(
                    title: l10n.walletHomeQuickActionsTitle,
                    subtitle: l10n.walletHomeQuickActionsSubtitle,
                    child: _buildQuickActionsGrid(
                      walletProvider: walletProvider,
                      canTransact: canTransact,
                      isCompact: isCompact,
                      roles: roles,
                      swapEnabled: swapEnabled,
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.lg),
                  const AttestationBadgePanel(
                    title: 'Attestation badges',
                  ),
                  const SizedBox(height: KubusSpacing.lg),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: _buildTokensCard(
                            tokens: tokens,
                            isCompact: isCompact,
                          ),
                        ),
                        const SizedBox(width: KubusSpacing.lg),
                        Expanded(
                          child: _buildRecentTransactionsCard(
                            isSmallScreen: isCompact,
                          ),
                        ),
                      ],
                    )
                  else ...<Widget>[
                    _buildTokensCard(
                      tokens: tokens,
                      isCompact: isCompact,
                    ),
                    const SizedBox(height: KubusSpacing.lg),
                    _buildRecentTransactionsCard(
                      isSmallScreen: isCompact,
                    ),
                  ],
                  const SizedBox(height: KubusSpacing.lg),
                  _buildSecurityZone(
                    walletProvider: walletProvider,
                    roles: roles,
                  ),
                ],
                sideChildren: <Widget>[
                  WalletCustodyStatusPanel(
                    authority: authority,
                    compact: true,
                    onRestoreSigner: authority.canRestoreFromEncryptedBackup
                        ? () => _handleReadOnlyReconnect(walletProvider)
                        : null,
                    onConnectExternalWallet: !authority.canTransact
                        ? () =>
                            Navigator.of(context).pushNamed('/connect-wallet')
                        : null,
                  ),
                  const SizedBox(height: KubusSpacing.lg),
                  KubusWalletSectionCard(
                    title: l10n.walletHomeDesktopSurfaceLabel,
                    subtitle: l10n.walletHomeDesktopRailSubtitle,
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: KubusSidebarStatCard(
                                title: l10n.walletHomeSendAction,
                                value:
                                    '${analytics['sentTransactions'] as int? ?? 0}',
                                icon: Icons.arrow_upward_rounded,
                                accent: roles.negativeAction,
                              ),
                            ),
                            const SizedBox(width: KubusSpacing.md),
                            Expanded(
                              child: KubusSidebarStatCard(
                                title: l10n.walletHomeReceiveAction,
                                value:
                                    '${analytics['receivedTransactions'] as int? ?? 0}',
                                icon: Icons.arrow_downward_rounded,
                                accent: roles.statBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: KubusSpacing.md),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: KubusSidebarStatCard(
                                title: l10n.walletHomeSwapAction,
                                value:
                                    '${analytics['swapTransactions'] as int? ?? 0}',
                                icon: Icons.swap_horiz_rounded,
                                accent: roles.positiveAction,
                              ),
                            ),
                            const SizedBox(width: KubusSpacing.md),
                            Expanded(
                              child: KubusSidebarStatCard(
                                title: 'SOL',
                                value: _getSolBalance().toStringAsFixed(3),
                                icon: Icons.bolt_outlined,
                                accent: roles.statAmber,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTokenAvatar(Token token) {
    final theme = Theme.of(context);
    final fallback = _buildTokenFallbackAvatar(token);

    if (!_isValidLogoUrl(token.logoUrl)) {
      return fallback;
    }

    return Container(
      width: 40,
      height: 40,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KubusRadius.xl),
        border:
            Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Image.network(
        token.logoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          final expectedBytes = loadingProgress.expectedTotalBytes;
          final progress = expectedBytes == null
              ? null
              : loadingProgress.cumulativeBytesLoaded / expectedBytes;
          return Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: progress,
                color: theme.colorScheme.primary,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTokenFallbackAvatar(Token token) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _getTokenColor(token.symbol),
        borderRadius: BorderRadius.circular(KubusRadius.xl),
      ),
      child: Center(
        child: Text(
          _getTokenInitial(token),
          style: KubusTypography.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  String _getTokenInitial(Token token) {
    if (token.symbol.isNotEmpty) {
      return token.symbol.substring(0, 1).toUpperCase();
    }
    if (token.name.isNotEmpty) {
      return token.name.substring(0, 1).toUpperCase();
    }
    return '?';
  }

  bool _isValidLogoUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }
    return uri.hasScheme && (uri.scheme == 'https' || uri.scheme == 'http');
  }

  // Helper methods to get specific token balances
  double _getKub8Balance() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final kub8Tokens = walletProvider.tokens
        .where((token) => token.symbol.toUpperCase() == 'KUB8');
    return kub8Tokens.isNotEmpty ? kub8Tokens.first.balance : 0.0;
  }

  double _getSolBalance() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final solTokens = walletProvider.tokens
        .where((token) => token.symbol.toUpperCase() == 'SOL');
    return solTokens.isNotEmpty ? solTokens.first.balance : 0.0;
  }

  String _shortenAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  Color _getTokenColor(String symbol) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.primary;
    switch (symbol.toUpperCase()) {
      case 'KUB8':
        return base;
      case 'ETH':
        return AppColorUtils.shiftLightness(base, 0.12);
      case 'BTC':
        return AppColorUtils.shiftLightness(base, 0.20);
      case 'SOL':
        return base;
      case 'MATIC':
        return AppColorUtils.shiftLightness(base, -0.10);
      default:
        return scheme.onSurface.withValues(alpha: 0.6);
    }
  }

  Widget _buildRecentTransactions({bool isSmallScreen = false}) {
    final l10n = AppLocalizations.of(context)!;
    // Use provider data for transactions
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final recentTransactions = walletProvider.getRecentTransactions(limit: 5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recentTransactions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: EmptyStateCard(
              icon: Icons.history,
              title: l10n.settingsNoTransactionsTitle,
              description: l10n.settingsNoTransactionsDescription,
              showAction: true,
              actionLabel: l10n.settingsTransactionHistoryDialogTitle,
              onAction: _showTransactionHistorySheet,
            ),
          )
        else
          ...recentTransactions.map(
            (transaction) => WalletTransactionCard(
              transaction: transaction,
              compact: isSmallScreen,
              margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
            ),
          ),
      ],
    );
  }

  Widget _buildWalletHeroCard({
    required Wallet? wallet,
    required String? walletAddress,
    required bool isReadOnlySession,
    required List<KubusWalletStatsStripItem> stats,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final address = wallet?.address ?? walletAddress ?? '';

    return LiquidGlassCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(KubusRadius.xl),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(KubusChromeMetrics.cardPadding),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              roles.statAmber.withValues(alpha: 0.14),
              scheme.primaryContainer.withValues(alpha: 0.86),
              scheme.surface.withValues(alpha: 0.74),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.walletHomeTotalBalanceLabel,
                        style: KubusTextStyles.sectionSubtitle.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: KubusSpacing.sm),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: KubusSpacing.sm,
                        runSpacing: KubusSpacing.xs,
                        children: <Widget>[
                          Text(
                            _getKub8Balance().toStringAsFixed(2),
                            style: KubusTextStyles.heroTitle.copyWith(
                              fontSize: KubusChromeMetrics.heroTitle +
                                  KubusSpacing.lg,
                              color: scheme.onSurface,
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: KubusSpacing.sm),
                            child: Text(
                              'KUB8',
                              style: KubusTextStyles.detailCardTitle.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.88),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: KubusSpacing.sm),
                      Wrap(
                        spacing: KubusSpacing.sm,
                        runSpacing: KubusSpacing.sm,
                        children: <Widget>[
                          KubusWalletMetaPill(
                            label: '${_getSolBalance().toStringAsFixed(3)} SOL',
                            icon: Icons.bolt_outlined,
                            tintColor: roles.statAmber,
                          ),
                          KubusWalletMetaPill(
                            label: l10n.walletHomeApproxTotalValue(
                              '\$${wallet?.totalValue.toStringAsFixed(2) ?? '0.00'}',
                            ),
                            icon: Icons.account_balance_wallet_outlined,
                            tintColor: roles.statTeal,
                          ),
                          if (isReadOnlySession)
                            KubusWalletMetaPill(
                              label: l10n.walletReconnectManualRequiredToast,
                              icon: Icons.visibility_outlined,
                              tintColor: roles.warningAction,
                              emphasized: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: KubusSpacing.md),
                InkWell(
                  onTap:
                      address.isEmpty ? null : () => _showAddressToast(address),
                  borderRadius: BorderRadius.circular(KubusRadius.xl),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KubusSpacing.md,
                      vertical: KubusSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(KubusRadius.xl),
                      border: Border.all(
                        color: scheme.outline.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      wallet?.shortAddress ??
                          _shortenAddress(walletAddress ?? ''),
                      style: KubusTextStyles.detailLabel.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KubusSpacing.lg),
            KubusWalletStatsStrip(items: stats),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid({
    required WalletProvider walletProvider,
    required bool canTransact,
    required bool isCompact,
    required KubusColorRoles roles,
    required bool swapEnabled,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = swapEnabled ? 4 : 3;
        final actionWidth = constraints.maxWidth >= 920
            ? (constraints.maxWidth - (KubusSpacing.md * (columns - 1))) /
                columns
            : constraints.maxWidth >= 560
                ? (constraints.maxWidth - KubusSpacing.md) / 2
                : constraints.maxWidth;

        final actions = <Widget>[
          SizedBox(
            width: actionWidth,
            child: KubusWalletActionCard(
              title: l10n.walletHomeSendAction,
              subtitle: l10n.walletHomeDesktopSendSubtitle,
              icon: Icons.arrow_upward_rounded,
              color: roles.negativeAction,
              onTap: () => _openSendScreen(walletProvider, canTransact),
              enabled: canTransact,
              minHeight: isCompact ? 132 : 150,
            ),
          ),
          SizedBox(
            width: actionWidth,
            child: KubusWalletActionCard(
              title: l10n.walletHomeReceiveAction,
              subtitle: l10n.walletHomeDesktopReceiveSubtitle,
              icon: Icons.arrow_downward_rounded,
              color: roles.statBlue,
              onTap: _openReceiveScreen,
              minHeight: isCompact ? 132 : 150,
            ),
          ),
          if (swapEnabled)
            SizedBox(
              width: actionWidth,
              child: KubusWalletActionCard(
                title: l10n.walletHomeSwapAction,
                subtitle: l10n.walletHomeDesktopSwapSubtitle,
                icon: Icons.swap_horiz_rounded,
                color: roles.positiveAction,
                onTap: () => _openSwapScreen(walletProvider, canTransact),
                enabled: canTransact,
                minHeight: isCompact ? 132 : 150,
              ),
            ),
          SizedBox(
            width: actionWidth,
            child: KubusWalletActionCard(
              title: l10n.walletHomeActionNfts,
              subtitle: l10n.walletHomeDesktopNftsSubtitle,
              icon: Icons.collections_outlined,
              color: roles.statAmber,
              onTap: _openNftGallery,
              minHeight: isCompact ? 132 : 150,
            ),
          ),
        ];

        return Wrap(
          spacing: KubusSpacing.md,
          runSpacing: KubusSpacing.md,
          children: actions,
        );
      },
    );
  }

  Widget _buildTokensCard({
    required List<Token> tokens,
    required bool isCompact,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return KubusWalletSectionCard(
      title: l10n.walletHomeYourTokensTitle,
      subtitle: l10n.walletHomeYourTokensSubtitle,
      child: tokens.isEmpty
          ? EmptyStateCard(
              icon: Icons.token_outlined,
              title: l10n.walletHomeNoTokensTitle,
              description: l10n.walletHomeNoTokensDescription,
            )
          : Column(
              children: tokens
                  .map(
                    (token) => LiquidGlassCard(
                      margin: EdgeInsets.only(
                        bottom: isCompact ? KubusSpacing.sm : KubusSpacing.md,
                      ),
                      padding: EdgeInsets.all(
                        isCompact ? KubusSpacing.md : KubusSpacing.lg,
                      ),
                      child: Row(
                        children: <Widget>[
                          _buildTokenAvatar(token),
                          const SizedBox(width: KubusSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  token.name,
                                  style:
                                      KubusTextStyles.detailCardTitle.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: KubusSpacing.xxs),
                                Text(
                                  token.symbol,
                                  style: KubusTextStyles.detailCaption.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.68),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                token.balance.toStringAsFixed(4),
                                style: KubusTextStyles.detailCardTitle.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: KubusSpacing.xxs),
                              Text(
                                '\$${token.value.toStringAsFixed(2)}',
                                style: KubusTextStyles.detailCaption.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.68),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildRecentTransactionsCard({bool isSmallScreen = false}) {
    final l10n = AppLocalizations.of(context)!;
    return KubusWalletSectionCard(
      title: l10n.walletHomeRecentTransactionsTitle,
      subtitle: l10n.walletHomeRecentTransactionsSubtitle,
      headerTrailing: TextButton(
        onPressed: _showTransactionHistorySheet,
        child: Text(
          l10n.commonViewAll,
          style: KubusTextStyles.detailButton.copyWith(
            color: AppColorUtils.amberAccent,
          ),
        ),
      ),
      child: _buildRecentTransactions(isSmallScreen: isSmallScreen),
    );
  }

  Widget _buildSecurityZone({
    required WalletProvider walletProvider,
    required KubusColorRoles roles,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final authority = walletProvider.authority;
    final needsAttention = authority.recoveryNeeded ||
        !authority.hasEncryptedBackup ||
        walletProvider.isReadOnlySession;
    final accent = needsAttention ? roles.warningAction : roles.positiveAction;

    return KubusWalletSectionCard(
      title: l10n.walletHomeSecurityTitle,
      subtitle: l10n.walletHomeSecuritySubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: KubusSpacing.sm,
            runSpacing: KubusSpacing.sm,
            children: <Widget>[
              KubusWalletMetaPill(
                label: authority.canTransact
                    ? l10n.walletSecuritySignerLocalReadyValue
                    : authority.canRestoreFromEncryptedBackup
                        ? l10n.walletSecuritySignerRestoreAvailableValue
                        : l10n.walletSecuritySignerMissingValue,
                icon: Icons.draw_outlined,
                tintColor:
                    authority.canTransact ? roles.positiveAction : accent,
                emphasized: needsAttention,
              ),
              KubusWalletMetaPill(
                label: authority.hasEncryptedBackup
                    ? l10n.walletSecurityAvailable
                    : authority.encryptedBackupStatusKnown
                        ? l10n.walletSecurityUnavailable
                        : l10n.walletSecurityUnknown,
                icon: Icons.cloud_done_outlined,
                tintColor: authority.hasEncryptedBackup
                    ? roles.positiveAction
                    : accent,
                emphasized: !authority.hasEncryptedBackup,
              ),
              KubusWalletMetaPill(
                label: authority.hasPasskeyProtection
                    ? l10n.walletSecurityConfigured
                    : l10n.walletSecurityNotConfigured,
                icon: Icons.fingerprint,
                tintColor: authority.hasPasskeyProtection
                    ? roles.statBlue
                    : roles.statAmber,
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.md),
          Text(
            l10n.walletSecurityBackendBackupClarifier,
            style: KubusTextStyles.detailBody.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openBackupProtection,
                  icon: const Icon(Icons.shield_outlined),
                  label: Text(l10n.walletHomeSecureWalletAction),
                ),
              ),
              if (authority.canRestoreFromEncryptedBackup) ...<Widget>[
                const SizedBox(width: KubusSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => _handleReadOnlyReconnect(walletProvider),
                  icon: const Icon(Icons.login_outlined),
                  label: Text(l10n.walletSecurityRestoreSignerAction),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showAddressToast(String address) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showKubusSnackBar(
      SnackBar(
        content: Text(l10n.walletHomeAddressLabel(address)),
        action: SnackBarAction(
          label: l10n.commonCopy,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: address));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showKubusSnackBar(
              SnackBar(
                content: Text(l10n.walletHomeAddressCopiedToast),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openBackupProtection() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const WalletBackupProtectionScreen(),
      ),
    );
  }

  void _openReceiveScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ReceiveTokenScreen()),
    );
  }

  void _openNftGallery() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const NFTGallery()),
    );
  }

  void _openSendScreen(WalletProvider walletProvider, bool canTransact) {
    if (!canTransact) {
      _handleReadOnlyReconnect(walletProvider);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SendTokenScreen()),
    );
  }

  void _openSwapScreen(WalletProvider walletProvider, bool canTransact) {
    if (!canTransact) {
      _handleReadOnlyReconnect(walletProvider);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const TokenSwap()),
    );
  }

  void _showWalletSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _showTransactionHistorySheet() {
    final l10n = AppLocalizations.of(context)!;
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final transactions = walletProvider.getRecentTransactions(limit: 200);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(KubusRadius.xl)),
      ),
      builder: (context) {
        return SafeArea(
          child: KeyboardInsetPadding(
            extraBottom: 16,
            child: Padding(
              padding: const EdgeInsets.all(KubusSpacing.md),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.settingsTransactionHistoryDialogTitle,
                            style: KubusTypography.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.close,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          tooltip: l10n.commonClose,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (transactions.isEmpty)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: KubusSpacing.sm,
                          ),
                          child: EmptyStateCard(
                            icon: Icons.receipt_long,
                            title: l10n.settingsNoTransactionsTitle,
                            description: l10n.settingsNoTransactionsDescription,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            final tx = transactions[index];
                            return WalletTransactionCard(
                              transaction: tx,
                              margin: const EdgeInsets.only(
                                bottom: KubusSpacing.sm,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
