import 'package:flutter/material.dart';
import '../../../widgets/inline_loading.dart';
import 'package:flutter/services.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../../config/config.dart';
import '../../../config/api_keys.dart';
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
import '../../../widgets/dashboard/kubus_dashboard_chrome.dart';
import '../../../widgets/kubus_button.dart';
import '../../../widgets/common/keyboard_inset_padding.dart';
import '../../../widgets/wallet_custody_status_panel.dart';
import '../../../widgets/wallet_transaction_card.dart';
import '../../../widgets/attestation_badge_panel.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../widgets/wallet/kubus_token_identity.dart';
import '../../../widgets/wallet/kubus_wallet_shell.dart';
import '../../../widgets/wallet/wallet_action_controller.dart';
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
      Provider.of<NavigationProvider>(
        context,
        listen: false,
      ).trackScreenVisit('wallet');
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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
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
                  icon: Icon(
                    Icons.settings,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  tooltip: AppLocalizations.of(context)!.settingsTitle,
                  onPressed: _showWalletSettings,
                ),
              ],
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 24.0,
                ),
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
                      final walletProvider = Provider.of<WalletProvider>(
                        context,
                        listen: false,
                      );
                      if (!walletProvider.hasWalletIdentity) {
                        Navigator.pushReplacementNamed(
                          context,
                          '/connect-wallet',
                        );
                      } else {
                        ScaffoldMessenger.of(context).showKubusSnackBar(
                          SnackBar(
                            content: Text(l10n.walletHomeAlreadyConnectedToast),
                          ),
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
            final roles = KubusColorRoles.of(context);
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
                  IconButton(
                    icon: Icon(
                      Icons.settings,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    tooltip: AppLocalizations.of(context)!.settingsTitle,
                    onPressed: _showWalletSettings,
                  ),
                ],
              ),
              // Hierarchy: identity/status, balances, actions, transactions,
              // then technical controls. No vanity counters, no glow.
              body: KubusWalletResponsiveShell(
                wideBreakpoint: 1120,
                mainChildren: <Widget>[
                  _buildWalletIdentityPanel(
                    wallet: wallet,
                    walletAddress: walletAddress,
                    walletProvider: walletProvider,
                    isReadOnlySession: isReadOnlySession,
                  ),
                  const SizedBox(height: KubusSpacing.lg),
                  _buildBalancesCard(
                    wallet: wallet,
                    isCompact: isCompact,
                  ),
                  const SizedBox(height: KubusSpacing.lg),
                  _buildTokensCard(tokens: tokens),
                  const SizedBox(height: KubusSpacing.lg),
                  KubusWalletSectionCard(
                    title: l10n.walletActionsTitle,
                    subtitle: l10n.walletHomeQuickActionsSubtitle,
                    child: _buildQuickActionsGrid(
                      walletProvider: walletProvider,
                      authority: authority,
                      canTransact: canTransact,
                      isCompact: isCompact,
                      roles: roles,
                      swapEnabled: swapEnabled,
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.lg),
                  _buildRecentTransactionsCard(isSmallScreen: isCompact),
                  const SizedBox(height: KubusSpacing.lg),
                  _buildSecurityZone(
                    walletProvider: walletProvider,
                    roles: roles,
                  ),
                  const SizedBox(height: KubusSpacing.lg),
                  AttestationBadgePanel(
                    title: l10n.walletBadgesVerificationTitle,
                    subtitle: l10n.walletBadgesVerificationSubtitle,
                  ),
                ],
                sideChildren: <Widget>[
                  WalletCustodyStatusPanel(authority: authority, compact: true),
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
    final fallback = KubusTokenAvatar(
      symbol: token.symbol,
      mint: token.contractAddress,
      imageUrl: token.logoUrl,
    );

    // KUB8 and SOL have canonical marks; KUB8's metadata image is handled
    // (with the bundled-logo fallback) by the avatar itself. Everything else
    // may carry its own logo.
    //
    // The mint decides this, not the symbol. Any SPL token can name itself
    // KUB8, and one that does must show its own logo rather than be handed
    // ours: deciding on the symbol meant an airdropped impostor was rendered
    // with the house mark throughout the wallet list.
    final hasCanonicalMark =
        KubusTokenIdentity.isCanonicalKub8(token.contractAddress) ||
            KubusTokenIdentity.isCanonicalSol(token.contractAddress);
    if (hasCanonicalMark || !_isValidLogoUrl(token.logoUrl)) {
      return fallback;
    }

    return Container(
      width: KubusSizes.tokenAvatarMd,
      height: KubusSizes.tokenAvatarMd,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
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
              child: InlineLoading(
                tileSize: 4,
                progress: progress,
                color: theme.colorScheme.primary,
              ),
            ),
          );
        },
      ),
    );
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
    // KUB8 is identified by its canonical mint. A token that merely calls itself "KUB8" is a
    // different token and must never be counted here.
    return walletProvider.getTokenByMint(ApiKeys.kub8MintAddress)?.balance ??
        0.0;
  }

  double _getSolBalance() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final solTokens = walletProvider.tokens.where(
      (token) => token.symbol.toUpperCase() == 'SOL',
    );
    return solTokens.isNotEmpty ? solTokens.first.balance : 0.0;
  }

  String _shortenAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
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

  /// Identity and connection status: the address as a machine value (Space
  /// Mono, truncated, full value spoken, copy action), the network, and
  /// whether this session can sign.
  Widget _buildWalletIdentityPanel({
    required Wallet? wallet,
    required String? walletAddress,
    required WalletProvider walletProvider,
    required bool isReadOnlySession,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final address = (wallet?.address ?? walletAddress ?? '').trim();
    final network = walletProvider.currentSolanaNetwork.trim();

    return KubusWalletSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          KubusNotionLabel(l10n.walletHomeTitle),
          const SizedBox(height: KubusSpacing.sm),
          if (address.isNotEmpty)
            Row(
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    label: l10n.walletAddressSemantic(address),
                    excludeSemantics: true,
                    child: Text(
                      _shortenAddress(address),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KubusTypography.machine(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: roles.foreground,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.walletCopyAddressTooltip,
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  onPressed: () => _copyAddress(address),
                ),
              ],
            ),
          if (network.isNotEmpty) ...<Widget>[
            const SizedBox(height: KubusSpacing.xs),
            Text(
              '${l10n.walletNetworkLabel.toUpperCase()} · $network',
              style: KubusTextStyles.machineValue.copyWith(
                color: roles.foregroundMuted,
              ),
            ),
          ],
          const SizedBox(height: KubusSpacing.sm),
          KubusStatusText(
            label: isReadOnlySession
                ? l10n.walletReadOnlyStatus
                : l10n.walletSecuritySignerLocalReadyValue,
            tone: isReadOnlySession
                ? KubusStatusTone.warning
                : KubusStatusTone.positive,
          ),
          if (isReadOnlySession) ...<Widget>[
            const SizedBox(height: KubusSpacing.xs),
            Text(
              l10n.walletReconnectManualRequiredToast,
              style: KubusTextStyles.detailCaption.copyWith(
                color: roles.foregroundMuted,
              ),
            ),
            const SizedBox(height: KubusSpacing.sm),
            KubusButton(
              onPressed: () => _handleReadOnlyReconnect(walletProvider),
              label: l10n.commonReconnect,
              icon: Icons.link,
              variant: KubusButtonVariant.secondary,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _copyAddress(String address) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: address));
    if (!mounted) return;
    messenger.showKubusSnackBar(
      SnackBar(
        content: Text(l10n.walletHomeAddressCopiedToast),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Real on-chain balances only: KUB8 by canonical mint, SOL, then every
  /// token the wallet holds. A fiat figure appears only when a real price
  /// source backs it (`hasFiatValuation`).
  Widget _buildBalancesCard({
    required Wallet? wallet,
    required bool isCompact,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final kub8 = _getKub8Balance().toStringAsFixed(2);
    final sol = _getSolBalance().toStringAsFixed(3);

    final kub8Token = walletProvider.getTokenByMint(ApiKeys.kub8MintAddress);

    Widget amount(String label, String value, String unit,
        {bool lead = false}) {
      final figure = Semantics(
        label: l10n.walletBalanceAmountSemantic(label, value, unit),
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: KubusTextStyles.detailCaption.copyWith(
                color: roles.foregroundMuted,
              ),
            ),
            const SizedBox(height: KubusSpacing.xxs),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: KubusSpacing.xs,
              children: <Widget>[
                // KUB8 leads at hero size; SOL steps down. A balance is
                // never broken or ellipsised: a long one scales down.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    softWrap: false,
                    style: (lead
                            ? KubusTextStyles.heroMetric
                            : KubusTextStyles.statValue.copyWith(
                                fontSize: KubusChromeMetrics.statValue * 0.75,
                              ))
                        .copyWith(color: roles.foreground),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: KubusSpacing.xxs),
                  child: Text(
                    unit,
                    style: KubusTextStyles.machineValue.copyWith(
                      color: roles.foregroundMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      if (!lead) return figure;
      // The leading KUB8 balance wears the canonical mark (metadata image
      // first, bundled kubus logo otherwise).
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          KubusTokenAvatar(
            symbol: KubusTokenIdentity.kub8Symbol,
            mint: ApiKeys.kub8MintAddress,
            imageUrl: kub8Token?.logoUrl,
            size: KubusTokenAvatarSize.lg,
          ),
          const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
          Flexible(child: figure),
        ],
      );
    }

    return KubusWalletSectionCard(
      // The asset hero: wallet amber with the wallet symbol.
      accent: roles.statAmber,
      glyph: Icons.account_balance_wallet_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Same notion label as the desktop hero: names the figure, adds no
          // second sentence.
          KubusNotionLabel(l10n.walletHomeTotalBalanceLabel),
          const SizedBox(height: KubusSpacing.md),
          Wrap(
            spacing: KubusSpacing.xl,
            runSpacing: KubusSpacing.md,
            children: <Widget>[
              amount(l10n.walletKub8BalanceLabel, kub8, 'KUB8', lead: true),
              amount(l10n.walletSolBalanceLabel, sol, 'SOL'),
            ],
          ),
          if (walletProvider.hasFiatValuation) ...<Widget>[
            const SizedBox(height: KubusSpacing.sm),
            Text(
              l10n.walletHomeApproxTotalValue(
                '\$${wallet?.totalValue.toStringAsFixed(2) ?? '0.00'}',
              ),
              style: KubusTextStyles.detailCaption.copyWith(
                color: roles.foregroundMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The wallet's holdings, every token including KUB8 and SOL. It is its
  /// own section, not part of the balance hero: the hero summarises the
  /// principal balances, this lists what the wallet holds.
  Widget _buildTokensCard({required List<Token> tokens}) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    return KubusWalletSectionCard(
      key: const ValueKey<String>('wallet_tokens_section'),
      title: l10n.walletHomeYourTokensTitle,
      subtitle: l10n.walletHomeYourTokensSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (tokens.isEmpty) ...<Widget>[
            // Plain text inside the section: no card inside the card.
            Text(
              l10n.walletHomeNoTokensTitle,
              style: KubusTextStyles.detailCardTitle.copyWith(
                color: roles.foreground,
              ),
            ),
            const SizedBox(height: KubusSpacing.xxs),
            Text(
              l10n.walletHomeNoTokensDescription,
              style: KubusTextStyles.detailCaption.copyWith(
                color: roles.foregroundMuted,
              ),
            ),
          ] else
            for (final token in tokens) _buildTokenRow(token, walletProvider),
        ],
      ),
    );
  }

  Widget _buildTokenRow(Token token, WalletProvider walletProvider) {
    final roles = KubusColorRoles.of(context);
    final l10n = AppLocalizations.of(context)!;
    final balance = token.balance.toStringAsFixed(4);
    final symbol = token.symbol.toUpperCase();
    return Semantics(
      container: true,
      label: l10n.walletBalanceAmountSemantic(token.name, balance, symbol),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: KubusSpacing.sm),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: roles.rule)),
        ),
        child: Row(
          children: <Widget>[
            _buildTokenAvatar(token),
            const SizedBox(width: KubusSpacing.md),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    token.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KubusTextStyles.detailCardTitle.copyWith(
                      color: roles.foreground,
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.xxs),
                  Text(
                    symbol,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KubusTextStyles.machineValue.copyWith(
                      color: roles.foregroundMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: KubusSpacing.md),
            // A balance is never ellipsised: the column takes the number's
            // width (up to 55 % of the row) and a number wider than that
            // scales down. The token name gives way first.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.55,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      balance,
                      maxLines: 1,
                      softWrap: false,
                      style: KubusTextStyles.detailCardTitle.copyWith(
                        color: roles.foreground,
                      ),
                    ),
                  ),
                  // A per-token fiat figure only when a real price source
                  // backs it; the balance above is always real.
                  if (walletProvider.hasFiatValuation) ...<Widget>[
                    const SizedBox(height: KubusSpacing.xxs),
                    Text(
                      '\$${token.value.toStringAsFixed(2)}',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: KubusTextStyles.detailCaption.copyWith(
                        color: roles.foregroundMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid({
    required WalletProvider walletProvider,
    required WalletAuthoritySnapshot authority,
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

        final configs = WalletActionController.buildPrimaryActions(
          l10n: l10n,
          roles: roles,
          authority: authority,
          onSend: () => _openSendScreen(walletProvider, canTransact),
          onReceive: _openReceiveScreen,
          onSwap: () => _openSwapScreen(walletProvider, canTransact),
          onSecureWallet: _openBackupProtection,
          onRestoreSigner: () => _handleReadOnlyReconnect(walletProvider),
          onConnectExternalWallet: () =>
              Navigator.of(context).pushNamed('/connect-wallet'),
          onCreateLocalWallet: () =>
              Navigator.of(context).pushNamed('/connect-wallet'),
          onImportWallet: () =>
              Navigator.of(context).pushNamed('/import-wallet'),
          onNfts: _openNftGallery,
          includeNfts: true,
          swapEnabled: swapEnabled,
        );

        final actions = <Widget>[
          ...configs.map(
            (config) => SizedBox(
              width: actionWidth,
              child: KubusWalletActionCard.fromConfig(
                key: Key('wallet_home_action_${config.type.name}'),
                config: config,
                minHeight: 88,
                density: isCompact
                    ? KubusWalletDensity.compact
                    : KubusWalletDensity.regular,
              ),
            ),
          ),
          SizedBox(
            width: actionWidth,
            child: KubusWalletActionCard(
              title: l10n.availabilityNodeNavTitle,
              subtitle: l10n.availabilityNodeNavSubtitle,
              icon: Icons.dns_outlined,
              color: roles.foregroundMuted,
              minHeight: 88,
              density: isCompact
                  ? KubusWalletDensity.compact
                  : KubusWalletDensity.regular,
              onTap: () =>
                  Navigator.of(context).pushNamed('/wallet/availability-node'),
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
            color: KubusColorRoles.of(context).foreground,
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
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ],
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const ReceiveTokenScreen()));
  }

  void _openNftGallery() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const NFTGallery()));
  }

  void _openSendScreen(WalletProvider walletProvider, bool canTransact) {
    if (!canTransact) {
      _handleReadOnlyReconnect(walletProvider);
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SendTokenScreen()));
  }

  void _openSwapScreen(WalletProvider walletProvider, bool canTransact) {
    if (!canTransact) {
      _handleReadOnlyReconnect(walletProvider);
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const TokenSwap()));
  }

  void _showWalletSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SettingsScreen()));
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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(KubusRadius.xl),
        ),
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
                            style: KubusTextStyles.sheetTitle.copyWith(
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
