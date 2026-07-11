// ignore_for_file: kubus_no_raw_progress_indicator
// Grandfathered kubus design-token violations. Remove this header
// when migrating this file to tokens (see docs/superpowers/specs/2026-07-10-ui-kit-token-enforcement-design.md).
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
import 'desktop_connect_wallet_screen.dart';
import '../../../widgets/glass_components.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../widgets/common/kubus_screen_header.dart';
import '../../../widgets/wallet_custody_status_panel.dart';
import '../../../widgets/wallet_transaction_card.dart';
import '../../../widgets/attestation_badge_panel.dart';
import '../../../widgets/wallet/kubus_wallet_shell.dart';
import '../../../widgets/wallet/wallet_action_controller.dart';
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
    // Adaptive rail: compact on smaller desktops so it never dominates, a touch
    // wider on large displays where there is room for more detail.
    final double railWidth = screenWidth >= 1360 ? 340 : 300;

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
                        width: railWidth,
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

    final explanation = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: themeProvider.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(DetailRadius.lg),
          ),
          child: Icon(
            Icons.account_balance_wallet_outlined,
            size: 32,
            color: themeProvider.accentColor,
          ),
        ),
        SizedBox(height: DetailSpacing.lg),
        Text(
          isAccountShellOnly
              ? l10n.walletHomeAccountShellTitle
              : l10n.walletHomeSignedOutTitle,
          style: DetailTypography.sectionTitle(context),
        ),
        SizedBox(height: DetailSpacing.sm),
        Text(
          isAccountShellOnly
              ? l10n.walletHomeAccountShellDescription
              : l10n.walletHomeSignedOutDescription,
          style: DetailTypography.body(context).copyWith(height: 1.6),
        ),
      ],
    );

    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pushNamed('/connect-wallet'),
          icon: const Icon(Icons.add),
          label: Text(
            isAccountShellOnly
                ? l10n.walletHomeRestoreWalletAction
                : l10n.walletHomeCreateWalletAction,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: themeProvider.accentColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: KubusSpacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(KubusRadius.md),
            ),
          ),
        ),
        SizedBox(height: DetailSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pushNamed('/import-wallet'),
          icon: const Icon(Icons.download),
          label: Text(l10n.walletHomeImportWalletAction),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: KubusSpacing.md),
            side: BorderSide(color: themeProvider.accentColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(KubusRadius.md),
            ),
          ),
        ),
        SizedBox(height: DetailSpacing.xs),
        TextButton.icon(
          onPressed: () {
            if (!AppConfig.enableWalletConnect || !AppConfig.enableWeb3) {
              ScaffoldMessenger.of(context).showKubusSnackBar(
                SnackBar(content: Text(l10n.authWalletConnectionDisabled)),
              );
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const DesktopConnectWalletScreen(initialStep: 3),
              ),
            );
          },
          icon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
          label: Text(l10n.walletSecurityConnectExternalAction),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.all(DetailSpacing.xxl),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: DesktopCard(
            padding: EdgeInsets.all(DetailSpacing.xl),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 640) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: explanation),
                      SizedBox(width: DetailSpacing.xxl),
                      SizedBox(width: 240, child: actions),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    explanation,
                    SizedBox(height: DetailSpacing.xl),
                    actions,
                  ],
                );
              },
            ),
          ),
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
        padding: EdgeInsets.all(DetailSpacing.xl),
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
                        border: KubusBorders.onDark(),
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
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: DetailSpacing.sm),
                Padding(
                  padding: EdgeInsets.only(bottom: DetailSpacing.xs),
                  child: Text(
                    'SOL',
                    style: KubusTextStyles.sectionTitle.copyWith(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
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
    final roles = KubusColorRoles.of(context);
    final swapEnabled = AppConfig.isFeatureEnabled('tokenSwap');
    final configs = WalletActionController.buildPrimaryActions(
      l10n: l10n,
      roles: roles,
      authority: walletProvider.authority,
      onSend: _openSendScreen,
      onReceive: _openReceiveScreen,
      onSwap: _openSwapScreen,
      onSecureWallet: _openBackupProtection,
      onRestoreSigner: () => WalletReconnectAction.handleReadOnlyReconnect(
        context: context,
        walletProvider: walletProvider,
      ),
      onConnectExternalWallet: () =>
          Navigator.of(context).pushNamed('/connect-wallet'),
      onCreateLocalWallet: () =>
          Navigator.of(context).pushNamed('/connect-wallet'),
      onImportWallet: () => Navigator.of(context).pushNamed('/import-wallet'),
      swapEnabled: swapEnabled,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final actionCount = configs.length;
        final tileWidth = constraints.maxWidth >= 980
            ? (constraints.maxWidth - (DetailSpacing.md * (actionCount - 1))) /
                actionCount
            : (constraints.maxWidth - DetailSpacing.md) / 2;
        final resolvedTileWidth = tileWidth.clamp(164.0, 240.0);
        return Wrap(
          spacing: DetailSpacing.md,
          runSpacing: DetailSpacing.md,
          children: configs
              .map(
                (config) => SizedBox(
                  width: resolvedTileWidth,
                  child: KubusWalletActionCard.fromConfig(
                    config: config,
                    minHeight: 96,
                    density: KubusWalletDensity.compact,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
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
        border: KubusBorders.onDark(),
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
        final l10n = AppLocalizations.of(context)!;

        if (tokens.isEmpty) {
          return ListView(
            padding: EdgeInsets.all(DetailSpacing.xxl),
            children: [
              SizedBox(
                height: 240,
                child: Center(
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
                ),
              ),
              SizedBox(height: DetailSpacing.xxl),
              _buildSecuritySectionCard(walletProvider),
            ],
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(DetailSpacing.xxl),
          itemCount: tokens.length + 1,
          itemBuilder: (context, index) {
            if (index == tokens.length) {
              return Padding(
                padding: EdgeInsets.only(top: DetailSpacing.xxl),
                child: _buildSecuritySectionCard(walletProvider),
              );
            }
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
              color: (isPositive
                      ? KubusColorRoles.of(context).positiveAction
                      : KubusColorRoles.of(context).negativeAction)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(DetailRadius.sm),
            ),
            child: Text(
              token.formattedChange,
              style: KubusTextStyles.navMetaLabel.copyWith(
                fontWeight: FontWeight.w600,
                color: isPositive
                    ? KubusColorRoles.of(context).positiveAction
                    : KubusColorRoles.of(context).negativeAction,
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
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isLoadingNfts = true;
      _nftError = null;
    });
    try {
      final walletProvider =
          Provider.of<WalletProvider>(context, listen: false);
      final walletAddress = (walletProvider.currentWalletAddress ?? '').trim();
      if (walletAddress.isEmpty) {
        setState(() {
          _nftError = l10n.walletHomeConnectWalletToFetchCollectibles;
          _isLoadingNfts = false;
        });
        return;
      }

      final collectiblesProvider =
          Provider.of<CollectiblesProvider>(context, listen: false);
      if (!collectiblesProvider.isLoading &&
          collectiblesProvider.allSeries.isEmpty &&
          collectiblesProvider.allCollectibles.isEmpty) {
        await collectiblesProvider.initialize();
      }

      if (walletAddress.isNotEmpty) {
        await collectiblesProvider.refreshWalletCollectibleIndex(walletAddress);
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
          'name': series?.name ?? l10n.walletHomeCollectibleFallbackTitle,
          'title': series?.name ?? l10n.walletHomeCollectibleFallbackTitle,
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
        final title = (nft['name'] ??
                nft['title'] ??
                l10n.walletHomeArchiveObjectFallbackTitle)
            .toString();
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
        final swapEnabled = AppConfig.isFeatureEnabled('tokenSwap');
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
                  if (swapEnabled)
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
                      if (swapEnabled)
                        ElevatedButton.icon(
                          onPressed: walletProvider.canTransact
                              ? _openSwapScreen
                              : null,
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
    final recentTransactions = walletProvider.transactions.take(5).toList();

    return ListView(
      padding: EdgeInsets.all(DetailSpacing.lg),
      children: [
        WalletCustodyStatusPanel(
          authority: walletProvider.authority,
          compact: true,
        ),
        SizedBox(height: DetailSpacing.lg),
        AttestationBadgePanel(
          title: l10n.walletBadgesVerificationTitle,
          subtitle: l10n.walletBadgesVerificationSubtitle,
          compact: true,
        ),
        SizedBox(height: DetailSpacing.lg),
        Text(
          l10n.walletHomeDesktopRecentActivityTitle,
          style: DetailTypography.sectionTitle(context),
        ),
        SizedBox(height: DetailSpacing.md),
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
      ],
    );
  }

  Widget _buildSecuritySectionCard(WalletProvider walletProvider) {
    final l10n = AppLocalizations.of(context)!;
    final authority = walletProvider.authority;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _truncateAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}
