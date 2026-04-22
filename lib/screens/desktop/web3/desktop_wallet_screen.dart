import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../config/config.dart';
import '../../../models/collectible.dart';
import '../../../providers/collectibles_provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../models/wallet.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/media_url_resolver.dart';
import '../../../utils/wallet_reconnect_action.dart';
import '../../../widgets/detail/detail_shell_components.dart';
import '../components/desktop_widgets.dart';
import '../../../widgets/empty_state_card.dart';
import '../../web3/wallet/token_swap.dart';
import '../../web3/wallet/send_token_screen.dart';
import '../../web3/wallet/receive_token_screen.dart';
import '../../web3/wallet/connectwallet_screen.dart';
import '../../../widgets/glass_components.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../widgets/common/kubus_screen_header.dart';
import '../../../widgets/wallet_custody_status_panel.dart';
import '../../../widgets/wallet_transaction_card.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import '../../web3/wallet/wallet_backup_protection_screen.dart';

/// Desktop wallet screen with professional dashboard layout
/// Web-optimized with hover states and keyboard shortcuts
class DesktopWalletScreen extends StatefulWidget {
  const DesktopWalletScreen({super.key});

  @override
  State<DesktopWalletScreen> createState() => _DesktopWalletScreenState();
}

class _DesktopWalletScreenState extends State<DesktopWalletScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late TabController _tabController;

  final List<String> _tabs = ['assets', 'activity', 'nfts', 'staking'];
  List<Map<String, dynamic>> _nfts = [];
  bool _isLoadingNfts = false;
  String? _nftError;
  bool _attemptedNftLoad = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _tabController = TabController(length: _tabs.length, vsync: this);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _copyWalletAddress(String address) async {
    if (address.isEmpty) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: address));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showKubusSnackBar(
      SnackBar(content: Text(l10n.walletHomeAddressCopiedToast)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final animationTheme = context.animationTheme;
    final scheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLarge = screenWidth >= 1200;

    final sidebarGlassStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.sidebarBackground,
      tintBase: scheme.surface,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: CurvedAnimation(
                  parent: _animationController,
                  curve: animationTheme.fadeCurve,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main content
                    Expanded(
                      flex: isLarge ? 3 : 2,
                      child: LiquidGlassPanel(
                        padding: EdgeInsets.zero,
                        child: _buildMainContent(themeProvider, isLarge),
                      ),
                    ),

                    // Right panel - Quick actions & recent
                    if (isLarge)
                      SizedBox(
                        width: 360,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                          child: LiquidGlassPanel(
                            padding: EdgeInsets.zero,
                            borderRadius: BorderRadius.zero,
                            showBorder: false,
                            blurSigma: sidebarGlassStyle.blurSigma,
                            fallbackMinOpacity:
                                sidebarGlassStyle.fallbackMinOpacity,
                            backgroundColor: sidebarGlassStyle.tintColor,
                            child: _buildRightPanel(themeProvider),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(ThemeProvider themeProvider, bool isLarge) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        if (!walletProvider.hasWalletIdentity) {
          return _buildConnectWalletView(themeProvider);
        }

        return CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: _buildHeader(themeProvider, walletProvider),
            ),

            // Balance card
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    DetailSpacing.xxl, 0, DetailSpacing.xxl, DetailSpacing.xl),
                child: _buildBalanceCard(themeProvider, walletProvider),
              ),
            ),

            // Quick actions (on smaller screens)
            if (!isLarge)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(DetailSpacing.xxl, 0,
                      DetailSpacing.xxl, DetailSpacing.xl),
                  child: _buildQuickActionsRow(themeProvider, walletProvider),
                ),
              ),

            // Tabs
            SliverToBoxAdapter(
              child: _buildTabs(themeProvider),
            ),

            // Tab content
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAssetsTab(themeProvider),
                  _buildActivityTab(themeProvider),
                  _buildNFTsTab(themeProvider),
                  _buildStakingTab(themeProvider),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConnectWalletView(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final walletProvider = context.watch<WalletProvider>();
    final authority = walletProvider.authority;
    final isAccountShellOnly =
        authority.state == WalletAuthorityState.accountShellOnly;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: EdgeInsets.all(DetailSpacing.xxl + DetailSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: themeProvider.accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 64,
                color: themeProvider.accentColor,
              ),
            ),
            SizedBox(height: DetailSpacing.xxl),
            Text(
              isAccountShellOnly
                  ? l10n.walletHomeAccountShellTitle
                  : l10n.walletHomeSignedOutTitle,
              style: DetailTypography.screenTitle(context),
            ),
            SizedBox(height: DetailSpacing.md),
            Text(
              isAccountShellOnly
                  ? l10n.walletHomeAccountShellDescription
                  : l10n.walletHomeSignedOutDescription,
              textAlign: TextAlign.center,
              style: DetailTypography.body(context).copyWith(height: 1.7),
            ),
            SizedBox(height: DetailSpacing.xxl + DetailSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/connect-wallet');
                  },
                  icon: const Icon(Icons.add),
                  label: Text(
                    isAccountShellOnly
                        ? l10n.walletHomeRestoreWalletAction
                        : l10n.walletHomeCreateWalletAction,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeProvider.accentColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: KubusSpacing.xxl,
                      vertical: KubusSpacing.lg,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KubusRadius.md),
                    ),
                  ),
                ),
                SizedBox(width: DetailSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/import-wallet');
                  },
                  icon: const Icon(Icons.download),
                  label: Text(l10n.walletHomeImportWalletAction),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: KubusSpacing.xxl,
                      vertical: KubusSpacing.lg,
                    ),
                    side: BorderSide(color: themeProvider.accentColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KubusRadius.md),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: DetailSpacing.xl),
            TextButton.icon(
              onPressed: () {
                final l10n = AppLocalizations.of(context)!;
                if (!AppConfig.enableWalletConnect || !AppConfig.enableWeb3) {
                  ScaffoldMessenger.of(context).showKubusSnackBar(
                    SnackBar(content: Text(l10n.authWalletConnectionDisabled)),
                  );
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ConnectWallet(initialStep: 3),
                  ),
                );
              },
              icon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
              label: Text(l10n.walletSecurityConnectExternalAction),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSendScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SendTokenScreen(),
      ),
    );
  }

  Future<void> _openReceiveScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ReceiveTokenScreen(),
      ),
    );
  }

  Future<void> _openSwapScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TokenSwap(),
      ),
    );
  }

  Future<void> _openBackupProtection() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const WalletBackupProtectionScreen(),
      ),
    );
  }

  Widget _buildHeader(
      ThemeProvider themeProvider, WalletProvider walletProvider) {
    final l10n = AppLocalizations.of(context)!;
    final authority = walletProvider.authority;
    final canTransact = authority.canTransact;
    final network = walletProvider.currentSolanaNetwork;
    final walletAddress = (walletProvider.currentWalletAddress ?? '').trim();
    final statusColor = canTransact
        ? Theme.of(context).colorScheme.tertiary
        : authority.hasWalletIdentity
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.secondary;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        DetailSpacing.xxl,
        DetailSpacing.xxl,
        DetailSpacing.xxl,
        DetailSpacing.lg,
      ),
      child: DesktopCard(
        child: Padding(
          padding: EdgeInsets.all(DetailSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: KubusScreenHeaderBar(
                      title: l10n.walletHomeTitle,
                      subtitle: canTransact
                          ? '${l10n.settingsWalletConnectionConnected} · $network'
                          : '${l10n.walletSessionSignerMissing} · $network',
                      padding: EdgeInsets.zero,
                      minHeight: KubusHeaderMetrics.headerMinHeight,
                      subtitleStyle: KubusTextStyles.screenSubtitle.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                  const SizedBox(width: DetailSpacing.lg),
                  Wrap(
                    spacing: DetailSpacing.sm,
                    runSpacing: DetailSpacing.sm,
                    alignment: WrapAlignment.end,
                    children: [
                      _buildNetworkSelector(themeProvider, walletProvider),
                      _buildHeaderActionButton(
                        icon: Icons.shield_outlined,
                        label: l10n.walletHomeSecureWalletAction,
                        onPressed: _openBackupProtection,
                      ),
                      _buildHeaderActionButton(
                        icon: Icons.refresh,
                        label: l10n.commonRefresh,
                        onPressed: () async {
                          final walletProvider = Provider.of<WalletProvider>(
                              context,
                              listen: false);
                          await walletProvider.refreshData();
                        },
                      ),
                    ],
                  ),
                ],
              ),
              if (walletAddress.isNotEmpty) ...[
                SizedBox(height: DetailSpacing.md),
                Wrap(
                  spacing: DetailSpacing.sm,
                  runSpacing: DetailSpacing.sm,
                  children: [
                    _buildWalletStatusChip(
                      label: canTransact
                          ? l10n.walletSessionSignerReady
                          : l10n.walletSessionSignerMissing,
                      icon: canTransact ? Icons.lock_open : Icons.visibility,
                      color: statusColor,
                    ),
                    _buildWalletStatusChip(
                      label: network,
                      icon: Icons.wifi_tethering,
                      color: themeProvider.accentColor,
                    ),
                    _buildCopyAddressChip(walletAddress),
                  ],
                ),
                SizedBox(height: DetailSpacing.md),
                WalletCustodyStatusPanel(
                  authority: authority,
                  compact: true,
                  onRestoreSigner: authority.canRestoreFromEncryptedBackup
                      ? () => WalletReconnectAction.handleReadOnlyReconnect(
                            context: context,
                            walletProvider: walletProvider,
                          )
                      : null,
                  onConnectExternalWallet: !authority.canTransact
                      ? () => Navigator.of(context).pushNamed('/connect-wallet')
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(
    ThemeProvider themeProvider,
    WalletProvider walletProvider,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final solBalance = walletProvider.tokens
            .where((t) => t.symbol.toUpperCase() == 'SOL')
            .firstOrNull
            ?.balance ??
        0.0;
    final kub8Balance = walletProvider.tokens
            .where((t) => t.symbol.toUpperCase() == 'KUB8')
            .firstOrNull
            ?.balance ??
        0.0;
    final walletAddress = (walletProvider.currentWalletAddress ?? '').trim();

    return DesktopCard(
      padding: EdgeInsets.zero,
      child: Container(
        padding: EdgeInsets.all(DetailSpacing.xl + DetailSpacing.sm),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              roles.statAmber,
              roles.statAmber.withValues(alpha: 0.84),
              Theme.of(context).colorScheme.surface,
            ],
            stops: const [0.0, 0.58, 1.0],
          ),
          borderRadius: BorderRadius.circular(DetailRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.walletHomeTotalBalanceLabel,
                      style: KubusTextStyles.sectionSubtitle.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                    SizedBox(height: DetailSpacing.xs),
                    Text(
                      l10n.walletHomeDesktopSurfaceLabel,
                      style: DetailTypography.caption(context).copyWith(
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: walletAddress.isEmpty
                        ? null
                        : () => _copyWalletAddress(walletAddress),
                    borderRadius: BorderRadius.circular(KubusRadius.sm),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: KubusSpacing.md,
                        vertical: KubusSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(KubusRadius.sm),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _truncateAddress(walletAddress),
                            style: KubusTypography.inter(
                              fontSize: KubusChromeMetrics.navMetaLabel,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: KubusSpacing.sm),
                          const Icon(Icons.copy, size: 14, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KubusSpacing.sm + KubusSpacing.xxs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  solBalance.toStringAsFixed(4),
                  style: KubusTypography.inter(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: DetailSpacing.md),
                Padding(
                  padding: EdgeInsets.only(bottom: DetailSpacing.md),
                  child: Text(
                    'SOL',
                    style: KubusTextStyles.sectionTitle.copyWith(
                      fontSize: 22,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: DetailSpacing.sm),
            Text(
              '≈ \$${(solBalance * 150).toStringAsFixed(2)} USD',
              style: KubusTextStyles.sectionSubtitle.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            SizedBox(height: DetailSpacing.lg),
            Wrap(
              spacing: DetailSpacing.sm,
              runSpacing: DetailSpacing.sm,
              children: [
                _buildBalanceStatChip(
                  label: 'KUB8',
                  value: kub8Balance.toStringAsFixed(2),
                  icon: Icons.bolt,
                ),
                _buildBalanceStatChip(
                  label: 'SOL',
                  value: solBalance.toStringAsFixed(3),
                  icon: Icons.currency_bitcoin,
                ),
                _buildBalanceStatChip(
                  label: 'Network',
                  value: walletProvider.currentSolanaNetwork,
                  icon: Icons.wifi_tethering,
                ),
              ],
            ),
            SizedBox(height: DetailSpacing.lg),
            Wrap(
              spacing: DetailSpacing.sm,
              runSpacing: DetailSpacing.sm,
              children: [
                TextButton.icon(
                  onPressed: _openReceiveScreen,
                  icon: const Icon(Icons.arrow_downward_rounded),
                  label: Text(l10n.walletHomeReceiveAction),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    padding: EdgeInsets.symmetric(
                      horizontal: KubusSpacing.lg,
                      vertical: KubusSpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KubusRadius.md),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: walletProvider.refreshData,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.commonRefresh),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    padding: EdgeInsets.symmetric(
                      horizontal: KubusSpacing.lg,
                      vertical: KubusSpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KubusRadius.md),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsRow(
    ThemeProvider themeProvider,
    WalletProvider walletProvider,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final canTransact = walletProvider.canTransact;
    final roles = KubusColorRoles.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = constraints.maxWidth >= 980
            ? (constraints.maxWidth - (DetailSpacing.md * 2)) / 3
            : (constraints.maxWidth - DetailSpacing.md) / 2;
        final resolvedTileWidth = tileWidth.clamp(164.0, 240.0);
        return Wrap(
          spacing: DetailSpacing.md,
          runSpacing: DetailSpacing.md,
          children: [
            SizedBox(
              width: resolvedTileWidth,
              child: _buildActionButton(
                l10n.walletHomeSendAction,
                l10n.walletHomeDesktopSendSubtitle,
                Icons.arrow_upward,
                roles.negativeAction,
                _openSendScreen,
                enabled: canTransact,
              ),
            ),
            SizedBox(
              width: resolvedTileWidth,
              child: _buildActionButton(
                l10n.walletHomeReceiveAction,
                l10n.walletHomeDesktopReceiveSubtitle,
                Icons.arrow_downward,
                roles.statBlue,
                _openReceiveScreen,
              ),
            ),
            SizedBox(
              width: resolvedTileWidth,
              child: _buildActionButton(
                l10n.walletHomeSwapAction,
                l10n.walletHomeDesktopSwapSubtitle,
                Icons.swap_horiz,
                roles.positiveAction,
                _openSwapScreen,
                enabled: canTransact,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButton(
    String label,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    return DesktopCard(
      onTap: enabled ? onTap : null,
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: enabled ? 0.12 : 0.04),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(DetailSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 122),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: enabled ? 0.14 : 0.06),
                      borderRadius: BorderRadius.circular(DetailRadius.md),
                    ),
                    child: Icon(
                      icon,
                      color: enabled
                          ? color
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.35),
                    ),
                  ),
                  SizedBox(height: DetailSpacing.md),
                  Text(
                    label,
                    style: DetailTypography.cardTitle(context).copyWith(
                      color: enabled
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.45),
                    ),
                  ),
                  SizedBox(height: DetailSpacing.xs),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DetailTypography.caption(context).copyWith(
                      color: enabled
                          ? Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6)
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final tabLabels = <String>[
      l10n.walletHomeDesktopTabAssets,
      l10n.walletHomeDesktopTabActivity,
      l10n.walletHomeDesktopTabNfts,
      l10n.walletHomeDesktopTabStaking,
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DetailSpacing.xxl,
        DetailSpacing.lg,
        DetailSpacing.xxl,
        DetailSpacing.sm,
      ),
      child: DesktopCard(
        padding: EdgeInsets.all(DetailSpacing.sm),
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: themeProvider.accentColor,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          labelStyle: KubusTextStyles.navLabel.copyWith(
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: KubusTextStyles.navLabel,
          indicator: BoxDecoration(
            color: themeProvider.accentColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(KubusRadius.md),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelPadding: EdgeInsets.symmetric(
            horizontal: KubusSpacing.lg,
            vertical: KubusSpacing.sm,
          ),
          tabs: tabLabels.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
    );
  }

  Widget _buildNetworkSelector(
    ThemeProvider themeProvider,
    WalletProvider walletProvider,
  ) {
    final network = walletProvider.currentSolanaNetwork.toLowerCase();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: KubusSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: themeProvider.accentColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(
          color: themeProvider.accentColor.withValues(alpha: 0.18),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: network,
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: themeProvider.accentColor,
          ),
          isDense: true,
          dropdownColor: Theme.of(context).colorScheme.surface,
          style: KubusTextStyles.navLabel.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          items: const [
            DropdownMenuItem(value: 'mainnet', child: Text('Mainnet')),
            DropdownMenuItem(value: 'devnet', child: Text('Devnet')),
            DropdownMenuItem(value: 'testnet', child: Text('Testnet')),
          ],
          onChanged: (value) {
            if (value != null) {
              walletProvider.switchSolanaNetwork(value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(KubusRadius.md),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: KubusSpacing.md,
              vertical: KubusSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(KubusRadius.md),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: scheme.onSurface),
                const SizedBox(width: KubusSpacing.sm),
                Text(
                  label,
                  style: KubusTextStyles.navLabel.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWalletStatusChip({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: KubusSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: KubusSpacing.xs),
          Text(
            label,
            style: KubusTextStyles.navMetaLabel.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyAddressChip(String address) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _copyWalletAddress(address),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: KubusSpacing.md,
            vertical: KubusSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.44),
            borderRadius: BorderRadius.circular(KubusRadius.md),
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.copy, size: 16, color: scheme.onSurface),
              const SizedBox(width: KubusSpacing.xs),
              Text(
                _truncateAddress(address),
                style: KubusTextStyles.navMetaLabel.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceStatChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: KubusSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: KubusSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: KubusTextStyles.navMetaLabel.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              Text(
                value,
                style: KubusTextStyles.navLabel.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssetsTab(ThemeProvider themeProvider) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        final tokens = walletProvider.tokens;

        if (tokens.isEmpty) {
          final l10n = AppLocalizations.of(context)!;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 72,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.25),
                ),
                SizedBox(height: DetailSpacing.lg),
                Text(
                  l10n.walletHomeNoTokensTitle,
                  style: DetailTypography.cardTitle(context).copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(DetailSpacing.xxl),
          itemCount: tokens.length,
          itemBuilder: (context, index) {
            return _buildTokenRow(tokens[index], themeProvider);
          },
        );
      },
    );
  }

  Widget _buildTokenRow(Token token, ThemeProvider themeProvider) {
    final isPositive = token.changePercentage >= 0;

    return DesktopCard(
      margin: EdgeInsets.only(bottom: DetailSpacing.md),
      onTap: () {},
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: themeProvider.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(DetailRadius.md),
            ),
            child: Center(
              child: Text(
                token.symbol.substring(0, 1).toUpperCase(),
                style: DetailTypography.cardTitle(context).copyWith(
                  color: themeProvider.accentColor,
                ),
              ),
            ),
          ),
          SizedBox(width: DetailSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  token.name,
                  style: DetailTypography.cardTitle(context),
                ),
                SizedBox(height: DetailSpacing.xs),
                Text(
                  token.symbol.toUpperCase(),
                  style: DetailTypography.caption(context),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                token.formattedBalance,
                style: DetailTypography.cardTitle(context),
              ),
              SizedBox(height: DetailSpacing.xs),
              Text(
                token.formattedValue,
                style: DetailTypography.caption(context),
              ),
            ],
          ),
          SizedBox(width: DetailSpacing.lg),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: DetailSpacing.md, vertical: DetailSpacing.sm),
            decoration: BoxDecoration(
              color: isPositive
                  ? const Color(0xFF4ADE80).withValues(alpha: 0.1)
                  : const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(DetailRadius.sm),
            ),
            child: Text(
              token.formattedChange,
              style: KubusTextStyles.navMetaLabel.copyWith(
                fontWeight: FontWeight.w600,
                color: isPositive
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadNftsIfNeeded() async {
    if (_attemptedNftLoad) return;
    _attemptedNftLoad = true;
    await _loadNfts();
  }

  Future<void> _loadNfts() async {
    setState(() {
      _isLoadingNfts = true;
      _nftError = null;
    });
    try {
      final walletProvider =
          Provider.of<WalletProvider>(context, listen: false);
      final walletAddress = (walletProvider.currentWalletAddress ?? '').trim();
      if (walletAddress.isEmpty) {
        throw Exception('Connect your wallet to fetch collectibles.');
      }

      final collectiblesProvider =
          Provider.of<CollectiblesProvider>(context, listen: false);
      if (!collectiblesProvider.isLoading &&
          collectiblesProvider.allSeries.isEmpty &&
          collectiblesProvider.allCollectibles.isEmpty) {
        await collectiblesProvider.initialize(
          loadMockIfEmpty: AppConfig.isDevelopment,
        );
      }

      final seriesById = <String, CollectibleSeries>{
        for (final series in collectiblesProvider.allSeries) series.id: series,
      };

      final owned = collectiblesProvider
          .getCollectiblesByOwner(walletAddress)
          .where((collectible) {
        final series = seriesById[collectible.seriesId];
        return series?.type == CollectibleType.nft;
      }).toList();

      final items = owned.map((collectible) {
        final series = seriesById[collectible.seriesId];
        final rawImage = series?.imageUrl ?? series?.animationUrl;
        final resolvedImage = rawImage == null
            ? null
            : (MediaUrlResolver.resolve(rawImage) ?? rawImage);
        return <String, dynamic>{
          'id': collectible.id,
          'tokenId': collectible.tokenId,
          'token_id': collectible.tokenId,
          'status': collectible.status.name,
          'transactionHash': collectible.transactionHash,
          'transaction_hash': collectible.transactionHash,
          'name': series?.name ?? 'Collectible',
          'title': series?.name ?? 'Collectible',
          'imageUrl': resolvedImage,
          'image': resolvedImage,
          'creator': series?.creatorAddress,
          'artist': series?.creatorAddress,
          'rarity': series?.rarity.name,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _nfts = items;
          _isLoadingNfts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _nftError = e.toString();
          _isLoadingNfts = false;
        });
      }
    }
  }

  Widget _buildActivityTab(ThemeProvider themeProvider) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        final l10n = AppLocalizations.of(context)!;
        final transactions = walletProvider.transactions;
        if (transactions.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(DetailSpacing.xl),
              child: EmptyStateCard(
                icon: Icons.history,
                title: l10n.settingsNoTransactionsTitle,
                description: l10n.settingsNoTransactionsDescription,
                showAction: true,
                actionLabel: l10n.commonRefresh,
                onAction: walletProvider.refreshData,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.symmetric(
              horizontal: DetailSpacing.xl, vertical: DetailSpacing.lg),
          itemBuilder: (context, index) {
            final tx = transactions[index];
            return WalletTransactionCard(
              transaction: tx,
              margin: EdgeInsets.zero,
            );
          },
          separatorBuilder: (_, __) => SizedBox(height: DetailSpacing.md),
          itemCount: transactions.length,
        );
      },
    );
  }

  Widget _buildNFTsTab(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    _loadNftsIfNeeded();
    if (_isLoadingNfts) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: themeProvider.accentColor,
        ),
      );
    }

    if (_nftError != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(DetailSpacing.xl),
          child: EmptyStateCard(
            icon: Icons.error_outline,
            title: l10n.walletHomeNftLoadFailedTitle,
            description: _nftError!,
            showAction: true,
            actionLabel: l10n.commonRetry,
            onAction: _loadNfts,
          ),
        ),
      );
    }

    if (_nfts.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(DetailSpacing.xl),
          child: EmptyStateCard(
            icon: Icons.auto_awesome_motion,
            title: l10n.marketplaceEmptyCollectionTitle,
            description: l10n.walletHomeNoCollectiblesDescription,
            showAction: true,
            actionLabel: l10n.commonRefresh,
            onAction: _loadNfts,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(DetailSpacing.xl),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: DetailSpacing.lg,
        mainAxisSpacing: DetailSpacing.lg,
        childAspectRatio: 0.85,
      ),
      itemCount: _nfts.length,
      itemBuilder: (context, index) {
        final nft = _nfts[index];
        final title = (nft['name'] ?? nft['title'] ?? 'NFT').toString();
        final imageUrl =
            (nft['image'] ?? nft['imageUrl'] ?? nft['preview'])?.toString();
        final creator = (nft['creator'] ?? nft['artist'] ?? '').toString();
        return DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(DetailRadius.md),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.image_outlined,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.4),
                          ),
                        ),
                ),
              ),
              SizedBox(height: DetailSpacing.md),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DetailTypography.cardTitle(context),
              ),
              if (creator.isNotEmpty) ...[
                SizedBox(height: DetailSpacing.xs),
                Text(
                  l10n.walletHomeCollectibleByline(creator),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DetailTypography.caption(context),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStakingTab(ThemeProvider themeProvider) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        final l10n = AppLocalizations.of(context)!;
        final rewardBalance =
            walletProvider.achievementTokenTotal.toStringAsFixed(2);
        return ListView(
          padding: EdgeInsets.all(DetailSpacing.xl),
          children: [
            DesktopCard(
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: themeProvider.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(DetailRadius.md),
                    ),
                    child: Icon(
                      Icons.savings,
                      color: themeProvider.accentColor,
                    ),
                  ),
                  SizedBox(width: DetailSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.walletHomeRewardsTitle,
                          style: DetailTypography.cardTitle(context),
                        ),
                        SizedBox(height: DetailSpacing.xs),
                        Text(
                          l10n.walletHomeRewardsDescription(rewardBalance),
                          style: DetailTypography.caption(context),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _openSwapScreen,
                    child: Text(
                      l10n.walletHomeSwapAction,
                      style: DetailTypography.label(context).copyWith(
                        color: themeProvider.accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: DetailSpacing.lg),
            DesktopCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.walletHomeStakeTitle,
                    style: DetailTypography.cardTitle(context),
                  ),
                  SizedBox(height: DetailSpacing.sm),
                  Text(
                    l10n.walletHomeStakeDescription,
                    style: DetailTypography.body(context),
                  ),
                  SizedBox(height: DetailSpacing.lg),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed:
                            walletProvider.canTransact ? _openSwapScreen : null,
                        icon: const Icon(Icons.safety_check),
                        label: Text(l10n.walletHomeStakeAction),
                      ),
                      SizedBox(width: DetailSpacing.md),
                      OutlinedButton(
                        onPressed: walletProvider.refreshData,
                        child: Text(l10n.walletHomeRefreshRatesAction),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRightPanel(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final walletProvider = Provider.of<WalletProvider>(context);
    final authority = walletProvider.authority;
    final canTransact = walletProvider.canTransact;
    final roles = KubusColorRoles.of(context);
    final recentTransactions = walletProvider.transactions.take(5).toList();

    return ListView(
      padding: EdgeInsets.all(DetailSpacing.xl),
      children: [
        Text(
          l10n.walletHomeQuickActionsTitle,
          style: DetailTypography.sectionTitle(context),
        ),
        SizedBox(height: DetailSpacing.lg + DetailSpacing.xs),
        _buildQuickActionTile(
          l10n.walletHomeSendAction,
          l10n.walletHomeDesktopSendSubtitle,
          Icons.arrow_upward,
          roles.negativeAction,
          _openSendScreen,
          enabled: canTransact,
        ),
        _buildQuickActionTile(
          l10n.walletHomeReceiveAction,
          l10n.walletHomeDesktopReceiveSubtitle,
          Icons.arrow_downward,
          roles.statBlue,
          _openReceiveScreen,
        ),
        _buildQuickActionTile(
          l10n.walletHomeSwapAction,
          l10n.walletHomeDesktopSwapSubtitle,
          Icons.swap_horiz,
          roles.positiveAction,
          _openSwapScreen,
          enabled: canTransact,
        ),
        SizedBox(height: DetailSpacing.xxl),
        Text(
          l10n.walletHomeDesktopRecentActivityTitle,
          style: DetailTypography.sectionTitle(context),
        ),
        SizedBox(height: DetailSpacing.lg),
        if (recentTransactions.isEmpty)
          Container(
            padding: EdgeInsets.all(DetailSpacing.xl),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(DetailRadius.md),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.history,
                  size: 36,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.25),
                ),
                SizedBox(height: DetailSpacing.md),
                Text(
                  l10n.daoRecentTransactionsEmptyTitle,
                  style: DetailTypography.label(context).copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
                SizedBox(height: DetailSpacing.xs),
                Text(
                  l10n.settingsNoTransactionsDescription,
                  style: DetailTypography.caption(context),
                ),
              ],
            ),
          )
        else
          ...recentTransactions.map((tx) {
            return WalletTransactionCard(
              transaction: tx,
              compact: true,
              margin: EdgeInsets.only(bottom: DetailSpacing.md),
            );
          }),
        SizedBox(height: DetailSpacing.xxl),
        Text(
          l10n.walletHomeSecurityTitle,
          style: DetailTypography.sectionTitle(context),
        ),
        SizedBox(height: DetailSpacing.lg),
        DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.walletHomeSecuritySubtitle,
                style: DetailTypography.caption(context),
              ),
              SizedBox(height: DetailSpacing.lg),
              WalletCustodyStatusPanel(
                authority: authority,
                compact: true,
                onRestoreSigner: authority.canRestoreFromEncryptedBackup
                    ? () => WalletReconnectAction.handleReadOnlyReconnect(
                          context: context,
                          walletProvider: walletProvider,
                        )
                    : null,
                onConnectExternalWallet: !authority.canTransact
                    ? () => Navigator.of(context).pushNamed('/connect-wallet')
                    : null,
              ),
              SizedBox(height: DetailSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openBackupProtection,
                  icon: const Icon(Icons.shield_outlined),
                  label: Text(l10n.walletHomeSecureWalletAction),
                ),
              ),
              if (authority.canRestoreFromEncryptedBackup) ...[
                SizedBox(height: DetailSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        WalletReconnectAction.handleReadOnlyReconnect(
                      context: context,
                      walletProvider: walletProvider,
                    ),
                    icon: const Icon(Icons.login_outlined),
                    label: Text(l10n.walletSecurityRestoreSignerAction),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    return DesktopCard(
      margin: EdgeInsets.only(bottom: DetailSpacing.md),
      onTap: enabled ? onTap : null,
      child: Stack(
        children: [
          Positioned(
            right: -12,
            top: -12,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: enabled ? 0.12 : 0.04),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(DetailSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 126),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: enabled ? 0.14 : 0.06),
                      borderRadius: BorderRadius.circular(DetailRadius.md),
                    ),
                    child: Icon(
                      icon,
                      color: enabled
                          ? color
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.35),
                      size: 22,
                    ),
                  ),
                  SizedBox(height: DetailSpacing.md),
                  Text(
                    title,
                    style: DetailTypography.cardTitle(context).copyWith(
                      color: enabled
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.45),
                    ),
                  ),
                  SizedBox(height: DetailSpacing.xs),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DetailTypography.caption(context).copyWith(
                      color: enabled
                          ? Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6)
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _truncateAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}
