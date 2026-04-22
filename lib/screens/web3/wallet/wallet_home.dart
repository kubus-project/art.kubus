import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
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
import '../../../utils/app_color_utils.dart';
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
            bool isSmallScreen = constraints.maxWidth < 600;

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
                    icon: Icon(Icons.vpn_key,
                        color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const WalletBackupProtectionScreen(),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.settings,
                        color: Theme.of(context).colorScheme.onSurface),
                    onPressed: _showWalletSettings,
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: EdgeInsets.all(
                  isSmallScreen
                      ? KubusSpacing.lg
                      : KubusChromeMetrics.cardPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LiquidGlassCard(
                      padding: EdgeInsets.zero,
                      borderRadius: BorderRadius.circular(KubusRadius.xl),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(
                          isSmallScreen
                              ? KubusSpacing.lg
                              : KubusChromeMetrics.cardPadding,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.94),
                              Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.82),
                              Theme.of(context)
                                  .colorScheme
                                  .surface
                                  .withValues(alpha: 0.72),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l10n.walletHomeTotalBalanceLabel,
                                  style: KubusTextStyles.sectionSubtitle.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.76),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    final address =
                                        wallet?.address ?? walletAddress ?? '';
                                    ScaffoldMessenger.of(context)
                                        .showKubusSnackBar(
                                      SnackBar(
                                        content: Text(
                                          l10n.walletHomeAddressLabel(address),
                                        ),
                                        action: SnackBarAction(
                                          label: l10n.commonCopy,
                                          onPressed: () async {
                                            await Clipboard.setData(
                                              ClipboardData(text: address),
                                            );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showKubusSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    l10n
                                                        .walletHomeAddressCopiedToast,
                                                  ),
                                                  duration: const Duration(
                                                    seconds: 2,
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: KubusSpacing.md,
                                      vertical: KubusSpacing.xs,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surface
                                          .withValues(alpha: 0.62),
                                      borderRadius:
                                          BorderRadius.circular(KubusRadius.xl),
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withValues(alpha: 0.12),
                                      ),
                                    ),
                                    child: Text(
                                      wallet?.shortAddress ??
                                          _shortenAddress(walletAddress ?? ''),
                                      style:
                                          KubusTextStyles.detailLabel.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: isSmallScreen
                                  ? KubusSpacing.md
                                  : KubusChromeMetrics.compactCardPadding,
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _getKub8Balance().toStringAsFixed(2),
                                  style: KubusTextStyles.heroTitle.copyWith(
                                    fontSize: isSmallScreen
                                        ? KubusChromeMetrics.heroTitle +
                                            KubusSpacing.md
                                        : KubusChromeMetrics.heroTitle +
                                            KubusSpacing.lg,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                                ),
                                const SizedBox(width: KubusSpacing.sm),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: KubusSpacing.sm,
                                  ),
                                  child: Text(
                                    'KUB8',
                                    style:
                                        KubusTextStyles.detailCardTitle.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.88),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: KubusSpacing.sm),
                            Wrap(
                              spacing: KubusSpacing.sm,
                              runSpacing: KubusSpacing.sm,
                              children: [
                                _buildBalanceMetaPill(
                                  '${_getSolBalance().toStringAsFixed(3)} SOL',
                                ),
                                _buildBalanceMetaPill(
                                  l10n.walletHomeApproxTotalValue(
                                    '\$${wallet?.totalValue.toStringAsFixed(2) ?? '0.00'}',
                                  ),
                                ),
                                if (isReadOnlySession)
                                  _buildBalanceMetaPill(
                                    l10n.walletReconnectManualRequiredToast,
                                    emphasized: true,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(
                      height: isSmallScreen ? KubusSpacing.md : KubusSpacing.lg,
                    ),

                    WalletCustodyStatusPanel(
                      authority: authority,
                      compact: isSmallScreen,
                      onRestoreSigner: authority.canRestoreFromEncryptedBackup
                              ? () => _handleReadOnlyReconnect(walletProvider)
                              : null,
                      onConnectExternalWallet: !authority.canTransact
                          ? () =>
                              Navigator.of(context).pushNamed('/connect-wallet')
                          : null,
                    ),

                    SizedBox(
                      height: isSmallScreen ? KubusSpacing.md : KubusSpacing.lg,
                    ),

                    _buildWalletSectionHeader(
                      title: l10n.walletHomeQuickActionsTitle,
                      subtitle: l10n.walletHomeQuickActionsSubtitle,
                    ),
                    const SizedBox(height: KubusSpacing.md),

                    // Action Buttons (Separated from balance card)
                    LiquidGlassCard(
                      padding: EdgeInsets.all(
                        isSmallScreen
                            ? KubusSpacing.lg
                            : KubusChromeMetrics.cardPadding,
                      ),
                      child: LayoutBuilder(
                        builder: (context, actionConstraints) {
                          final columns =
                              actionConstraints.maxWidth < 420 ? 2 : 4;
                          final spacing =
                              isSmallScreen ? KubusSpacing.sm : KubusSpacing.md;
                          final itemWidth = (actionConstraints.maxWidth -
                                  spacing * (columns - 1)) /
                              columns;
                          final actions = <Widget>[
                            _buildActionButton(
                              l10n.walletHomeActionSend,
                              Icons.arrow_upward,
                              Theme.of(context).colorScheme.error,
                              () {
                                if (!canTransact) {
                                  _handleReadOnlyReconnect(walletProvider);
                                  return;
                                }
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const SendTokenScreen()),
                                );
                              },
                              isSmallScreen,
                              buttonKey: const Key('wallet_home_action_send'),
                              enabled: canTransact,
                            ),
                            _buildActionButton(
                              l10n.walletHomeActionReceive,
                              Icons.arrow_downward,
                              Theme.of(context).colorScheme.secondary,
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const ReceiveTokenScreen()),
                              ),
                              isSmallScreen,
                              buttonKey:
                                  const Key('wallet_home_action_receive'),
                            ),
                            _buildActionButton(
                              l10n.walletHomeActionSwap,
                              Icons.swap_horiz,
                              Theme.of(context).colorScheme.tertiary,
                              () {
                                if (!canTransact) {
                                  _handleReadOnlyReconnect(walletProvider);
                                  return;
                                }
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const TokenSwap()),
                                );
                              },
                              isSmallScreen,
                              buttonKey: const Key('wallet_home_action_swap'),
                              enabled: canTransact,
                            ),
                            _buildActionButton(
                              l10n.walletHomeActionNfts,
                              Icons.image,
                              Theme.of(context).colorScheme.primary,
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const NFTGallery()),
                              ),
                              isSmallScreen,
                              buttonKey: const Key('wallet_home_action_nfts'),
                            ),
                          ];
                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: [
                              for (final action in actions)
                                SizedBox(width: itemWidth, child: action),
                            ],
                          );
                        },
                      ),
                    ),

                    SizedBox(
                      height: isSmallScreen ? KubusSpacing.lg : KubusSpacing.xl,
                    ),

                    _buildWalletSectionHeader(
                      title: l10n.walletHomeYourTokensTitle,
                      subtitle: l10n.walletHomeYourTokensSubtitle,
                    ),

                    SizedBox(
                      height: isSmallScreen ? KubusSpacing.md : KubusSpacing.lg,
                    ),

                    // Token List
                    if (tokens.isEmpty)
                      EmptyStateCard(
                        icon: Icons.token_outlined,
                        title: l10n.walletHomeNoTokensTitle,
                        description: l10n.walletHomeNoTokensDescription,
                      )
                    else
                      Column(
                        children: tokens
                            .map((token) => LiquidGlassCard(
                                  margin: EdgeInsets.only(
                                      bottom: isSmallScreen
                                          ? KubusSpacing.sm
                                          : KubusSpacing.md),
                                  padding: EdgeInsets.all(
                                    isSmallScreen
                                        ? KubusSpacing.md
                                        : KubusSpacing.lg,
                                  ),
                                  child: Row(
                                    children: [
                                      _buildTokenAvatar(token),
                                      const SizedBox(width: KubusSpacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              token.name,
                                              style: KubusTypography.inter(
                                                fontSize: KubusHeaderMetrics
                                                    .sectionSubtitle,
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                              ),
                                            ),
                                            Text(
                                              token.symbol,
                                              style: KubusTypography.inter(
                                                fontSize: KubusHeaderMetrics
                                                    .sectionSubtitle,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.7),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            token.balance.toStringAsFixed(4),
                                            style: KubusTypography.inter(
                                              fontSize: KubusHeaderMetrics
                                                  .sectionSubtitle,
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                            ),
                                          ),
                                          Text(
                                            '\$${token.value.toStringAsFixed(2)}',
                                            style: KubusTypography.inter(
                                              fontSize: KubusHeaderMetrics
                                                  .sectionSubtitle,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),

                    SizedBox(
                        height:
                            isSmallScreen ? KubusSpacing.lg : KubusSpacing.xl),

                    // Recent Transactions
                    _buildRecentTransactions(isSmallScreen: isSmallScreen),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBalanceMetaPill(String label, {bool emphasized = false}) {
    final scheme = Theme.of(context).colorScheme;
    final tint = emphasized ? scheme.primary : scheme.surface;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: KubusSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: emphasized ? 0.16 : 0.62),
        borderRadius: BorderRadius.circular(KubusRadius.xl),
        border: Border.all(
          color: (emphasized ? scheme.primary : scheme.outline)
              .withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        label,
        style: KubusTextStyles.detailCaption.copyWith(
          color: scheme.onSurface.withValues(alpha: emphasized ? 0.92 : 0.76),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildWalletSectionHeader({
    required String title,
    required String subtitle,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: KubusTypography.inter(
            fontSize: KubusHeaderMetrics.sectionTitle,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: KubusSpacing.xs),
        Text(
          subtitle,
          style: KubusTypography.inter(
            fontSize: KubusHeaderMetrics.sectionSubtitle,
            color: scheme.onSurface.withValues(alpha: 0.68),
            height: 1.35,
          ),
        ),
      ],
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

  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onPressed,
    bool isSmallScreen, {
    Key? buttonKey,
    bool enabled = true,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveColor = enabled ? color : color.withValues(alpha: 0.45);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: isSmallScreen ? 72 : 84),
      child: Container(
        key: buttonKey,
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: enabled ? 0.5 : 0.35),
          borderRadius: BorderRadius.circular(KubusRadius.md),
          border: Border.all(color: effectiveColor, width: 1.5),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(KubusRadius.md),
            onTap: onPressed,
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: isSmallScreen ? 12 : 16,
                horizontal: 8,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: effectiveColor,
                    size: isSmallScreen ? 20 : 24,
                  ),
                  SizedBox(height: isSmallScreen ? 4 : 8),
                  Text(
                    title,
                    style: KubusTypography.inter(
                      fontSize: isSmallScreen ? 10 : 12,
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? scheme.onSurface
                          : scheme.onSurface.withValues(alpha: 0.65),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildWalletSectionHeader(
                title: l10n.walletHomeRecentTransactionsTitle,
                subtitle: l10n.walletHomeRecentTransactionsSubtitle,
              ),
            ),
            const SizedBox(width: KubusSpacing.sm),
            TextButton(
              onPressed: _showTransactionHistorySheet,
              child: Text(
                l10n.commonViewAll,
                style: KubusTypography.inter(
                  fontSize: isSmallScreen ? 12 : 14,
                  color: AppColorUtils.amberAccent,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isSmallScreen ? KubusSpacing.md : KubusSpacing.lg),
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
