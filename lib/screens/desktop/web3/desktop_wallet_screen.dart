import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../config/config.dart';
import '../../../models/collectible.dart';
import '../../../providers/collectibles_provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/web3provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../models/wallet.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/media_url_resolver.dart';
import '../../../widgets/detail/detail_shell_components.dart';
import '../components/desktop_widgets.dart';
import '../../../widgets/empty_state_card.dart';
import '../../web3/wallet/token_swap.dart';
import '../../web3/wallet/connectwallet_screen.dart';
import '../../../widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
 

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

  final List<String> _tabs = ['Assets', 'Activity', 'NFTs', 'Staking'];
  bool _showSendDialog = false;
  bool _showReceiveDialog = false;
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final animationTheme = context.animationTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLarge = screenWidth >= 1200;

    final sidebarGlassTint = scheme.surface.withValues(alpha: isDark ? 0.16 : 0.10);

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
                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                          child: LiquidGlassPanel(
                            padding: EdgeInsets.zero,
                            borderRadius: BorderRadius.zero,
                            showBorder: false,
                            backgroundColor: sidebarGlassTint,
                            child: _buildRightPanel(themeProvider),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // Send dialog
          if (_showSendDialog) _buildSendDialog(themeProvider),

          // Receive dialog
          if (_showReceiveDialog) _buildReceiveDialog(themeProvider),
        ],
      ),
    );
  }

  Widget _buildMainContent(ThemeProvider themeProvider, bool isLarge) {
    return Consumer<Web3Provider>(
      builder: (context, web3Provider, _) {
        if (!web3Provider.isConnected) {
          return _buildConnectWalletView(themeProvider);
        }

        return CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: _buildHeader(themeProvider, web3Provider),
            ),

            // Balance card
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(DetailSpacing.xxl, 0, DetailSpacing.xxl, DetailSpacing.xl),
                child: _buildBalanceCard(themeProvider, web3Provider),
              ),
            ),

            // Quick actions (on smaller screens)
            if (!isLarge)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(DetailSpacing.xxl, 0, DetailSpacing.xxl, DetailSpacing.xl),
                  child: _buildQuickActionsRow(themeProvider),
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
              'Connect Your Wallet',
              style: DetailTypography.screenTitle(context),
            ),
            SizedBox(height: DetailSpacing.md),
            Text(
              'Connect your Solana wallet to access your assets, send & receive tokens, and interact with the marketplace.',
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
                  label: const Text('Create Wallet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeProvider.accentColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: DetailSpacing.xxl, vertical: DetailSpacing.lg),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DetailRadius.md),
                    ),
                  ),
                ),
                SizedBox(width: DetailSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/import-wallet');
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Import Wallet'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: DetailSpacing.xxl, vertical: DetailSpacing.lg),
                    side: BorderSide(color: themeProvider.accentColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DetailRadius.md),
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
              icon: const Icon(Icons.qr_code_scanner, size: 20),
              label: const Text('Connect with WalletConnect'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeProvider themeProvider, Web3Provider web3Provider) {
    return Container(
      padding: EdgeInsets.all(DetailSpacing.xxl),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Wallet',
                style: DetailTypography.screenTitle(context),
              ),
              SizedBox(height: DetailSpacing.xs),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4ADE80),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: DetailSpacing.sm),
                  Text(
                    'Connected to ${web3Provider.currentNetwork}',
                    style: DetailTypography.caption(context),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          // Network selector
          Container(
            padding: EdgeInsets.symmetric(horizontal: DetailSpacing.lg, vertical: DetailSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(DetailRadius.md),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: DropdownButton<String>(
              value: web3Provider.currentNetwork.toLowerCase(),
              underline: const SizedBox.shrink(),
              icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              isDense: true,
              items: const [
                DropdownMenuItem(value: 'mainnet', child: Text('Mainnet')),
                DropdownMenuItem(value: 'devnet', child: Text('Devnet')),
                DropdownMenuItem(value: 'testnet', child: Text('Testnet')),
              ],
              onChanged: (value) {
                if (value != null) {
                  web3Provider.switchNetwork(value);
                }
              },
            ),
          ),
          SizedBox(width: DetailSpacing.md),
          IconButton(
            onPressed: () async {
              // Refresh wallet data
              final walletProvider = Provider.of<WalletProvider>(context, listen: false);
              await walletProvider.refreshData();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh balances',
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(ThemeProvider themeProvider, Web3Provider web3Provider) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        final solBalance = walletProvider.tokens
            .where((t) => t.symbol.toUpperCase() == 'SOL')
            .firstOrNull?.balance ?? 0.0;
        final kub8Balance = walletProvider.tokens
            .where((t) => t.symbol.toUpperCase() == 'KUB8')
            .firstOrNull?.balance ?? 0.0;

        return DesktopCard(
          padding: EdgeInsets.zero,
          showBorder: false,
          child: Container(
            padding: EdgeInsets.all(DetailSpacing.xxl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  themeProvider.accentColor,
                  themeProvider.accentColor.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(DetailRadius.xl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Balance',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    // Copy address button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          final l10n = AppLocalizations.of(context)!;
                          Clipboard.setData(ClipboardData(text: web3Provider.walletAddress));
                          ScaffoldMessenger.of(context).showKubusSnackBar(
                            SnackBar(content: Text(l10n.walletHomeAddressCopiedToast)),
                          );
                        },
                        borderRadius: BorderRadius.circular(DetailRadius.sm),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: DetailSpacing.md, vertical: DetailSpacing.sm),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(DetailRadius.sm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _truncateAddress(web3Provider.walletAddress),
                                style: GoogleFonts.robotoMono(
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: DetailSpacing.sm),
                              const Icon(Icons.copy, size: 14, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      solBalance.toStringAsFixed(4),
                      style: GoogleFonts.inter(
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
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: DetailSpacing.sm),
                Text(
                  '≈ \$${(solBalance * 150).toStringAsFixed(2)} USD',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                SizedBox(height: DetailSpacing.xl),
                // KUB8 balance
                Container(
                  padding: EdgeInsets.all(DetailSpacing.lg),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(DetailRadius.md),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(DetailRadius.md),
                        ),
                        child: Center(
                          child: Text(
                            'K',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.accentColor,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: DetailSpacing.lg),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KUB8 Token',
                            style: DetailTypography.caption(context).copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          Text(
                            '${kub8Balance.toStringAsFixed(2)} KUB8',
                            style: DetailTypography.cardTitle(context).copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TokenSwap(),
                            ),
                          );
                        },
                        child: Text(
                          'Buy KUB8',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsRow(ThemeProvider themeProvider) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            'Send',
            Icons.arrow_upward,
            themeProvider.accentColor,
            () => setState(() => _showSendDialog = true),
          ),
        ),
        SizedBox(width: DetailSpacing.md),
        Expanded(
          child: _buildActionButton(
            'Receive',
            Icons.arrow_downward,
            const Color(0xFF4ECDC4),
            () => setState(() => _showReceiveDialog = true),
          ),
        ),
        SizedBox(width: DetailSpacing.md),
        Expanded(
          child: _buildActionButton(
            'Swap',
            Icons.swap_horiz,
            const Color(0xFFFF9A8B),
            () {},
          ),
        ),
        SizedBox(width: DetailSpacing.md),
        Expanded(
          child: _buildActionButton(
            'Buy',
            Icons.add,
            const Color(0xFF667eea),
            () {},
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return DesktopCard(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(DetailRadius.md),
            ),
            child: Icon(icon, color: color),
          ),
          SizedBox(height: DetailSpacing.md),
          Text(
            label,
            style: DetailTypography.label(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(ThemeProvider themeProvider) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: DetailSpacing.xxl),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: themeProvider.accentColor,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        labelStyle: DetailTypography.label(context),
        unselectedLabelStyle: DetailTypography.body(context),
        indicatorColor: themeProvider.accentColor,
        indicatorWeight: 3,
        dividerColor: Colors.transparent,
        tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  Widget _buildAssetsTab(ThemeProvider themeProvider) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        final tokens = walletProvider.tokens;

        if (tokens.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 72,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
                ),
                SizedBox(height: DetailSpacing.lg),
                Text(
                  'No assets yet',
                  style: DetailTypography.cardTitle(context).copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
            padding: EdgeInsets.symmetric(horizontal: DetailSpacing.md, vertical: DetailSpacing.sm),
            decoration: BoxDecoration(
              color: isPositive
                  ? const Color(0xFF4ADE80).withValues(alpha: 0.1)
                  : const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(DetailRadius.sm),
            ),
            child: Text(
              token.formattedChange,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isPositive ? const Color(0xFF4ADE80) : const Color(0xFFEF4444),
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
      final web3Provider = Provider.of<Web3Provider>(context, listen: false);
      final walletAddress = web3Provider.walletAddress.trim();
      if (walletAddress.isEmpty) {
        throw Exception('Connect your wallet to fetch collectibles.');
      }

      final collectiblesProvider = Provider.of<CollectiblesProvider>(context, listen: false);
      if (!collectiblesProvider.isLoading &&
          collectiblesProvider.allSeries.isEmpty &&
          collectiblesProvider.allCollectibles.isEmpty) {
        await collectiblesProvider.initialize(loadMockIfEmpty: AppConfig.isDevelopment);
      }

      final seriesById = <String, CollectibleSeries>{
        for (final series in collectiblesProvider.allSeries) series.id: series,
      };

      final owned = collectiblesProvider.getCollectiblesByOwner(walletAddress).where((collectible) {
        final series = seriesById[collectible.seriesId];
        return series?.type == CollectibleType.nft;
      }).toList();

      final items = owned.map((collectible) {
        final series = seriesById[collectible.seriesId];
        final rawImage = series?.imageUrl ?? series?.animationUrl;
        final resolvedImage = rawImage == null ? null : (MediaUrlResolver.resolve(rawImage) ?? rawImage);
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
        final transactions = walletProvider.transactions;
        if (transactions.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(DetailSpacing.xl),
              child: EmptyStateCard(
                icon: Icons.history,
                title: 'No transactions yet',
                description: 'Your recent on-chain activity will appear here.',
                showAction: true,
                actionLabel: 'Refresh',
                onAction: walletProvider.refreshData,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: DetailSpacing.xl, vertical: DetailSpacing.lg),
          itemBuilder: (context, index) {
            final tx = transactions[index];
            final color = _transactionColor(tx.type);
            return DesktopCard(
              onTap: () => Clipboard.setData(ClipboardData(text: tx.txHash)),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(DetailRadius.md),
                    ),
                    child: Icon(
                      _transactionIcon(tx.type),
                      color: color,
                    ),
                  ),
                  SizedBox(width: DetailSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.displayTitle,
                          style: DetailTypography.cardTitle(context),
                        ),
                        SizedBox(height: DetailSpacing.xs),
                        Text(
                          tx.shortAddress.isNotEmpty ? tx.shortAddress : tx.txHash.substring(0, 10),
                          style: DetailTypography.caption(context),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${tx.formattedAmount} ${tx.token}',
                        style: DetailTypography.cardTitle(context).copyWith(
                          color: color,
                        ),
                      ),
                      SizedBox(height: DetailSpacing.xs),
                      Text(
                        tx.timeAgo,
                        style: DetailTypography.caption(context),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          separatorBuilder: (_, __) => SizedBox(height: DetailSpacing.md),
          itemCount: transactions.length,
        );
      },
    );
  }

  Widget _buildNFTsTab(ThemeProvider themeProvider) {
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
            title: 'Could not load NFTs',
            description: _nftError!,
            showAction: true,
            actionLabel: 'Retry',
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
            title: 'No collectibles yet',
            description: 'Mint or purchase NFTs to see them here.',
            showAction: true,
            actionLabel: 'Refresh',
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
        final imageUrl = (nft['image'] ?? nft['imageUrl'] ?? nft['preview'])?.toString();
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
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
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
                  'by $creator',
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
        final rewardBalance = walletProvider.achievementTokenTotal.toStringAsFixed(2);
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
                          'KUB8 Rewards',
                          style: DetailTypography.cardTitle(context),
                        ),
                        SizedBox(height: DetailSpacing.xs),
                        Text(
                          '$rewardBalance KUB8 available from achievements',
                          style: DetailTypography.caption(context),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TokenSwap(),
                        ),
                      );
                    },
                    child: Text(
                      'Swap',
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
                    'Stake SOL for gas savings',
                    style: DetailTypography.cardTitle(context),
                  ),
                  SizedBox(height: DetailSpacing.sm),
                  Text(
                    'Lock SOL to cover future transaction fees and keep your gallery publishing smooth.',
                    style: DetailTypography.body(context),
                  ),
                  SizedBox(height: DetailSpacing.lg),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _showSendDialog = true),
                        icon: const Icon(Icons.safety_check),
                        label: const Text('Stake now'),
                      ),
                      SizedBox(width: DetailSpacing.md),
                      OutlinedButton(
                        onPressed: walletProvider.refreshData,
                        child: const Text('Refresh rates'),
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
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: EdgeInsets.all(DetailSpacing.xl),
      children: [
          Text(
            'Quick Actions',
            style: DetailTypography.sectionTitle(context),
          ),
          SizedBox(height: DetailSpacing.lg + DetailSpacing.xs),

          _buildQuickActionTile(
            'Send',
            'Transfer tokens',
            Icons.arrow_upward,
            themeProvider.accentColor,
            () => setState(() => _showSendDialog = true),
          ),
          _buildQuickActionTile(
            'Receive',
            'Get your address',
            Icons.arrow_downward,
            scheme.secondary,
            () => setState(() => _showReceiveDialog = true),
          ),
          _buildQuickActionTile(
            'Swap',
            'Exchange tokens',
            Icons.swap_horiz,
            scheme.tertiary,
            () {},
          ),
          _buildQuickActionTile(
            'Buy Crypto',
            'Add funds',
            Icons.add_card,
            scheme.primary,
            () {},
          ),

          SizedBox(height: DetailSpacing.xxl),

          Text(
            'Recent Activity',
            style: DetailTypography.sectionTitle(context),
          ),
          SizedBox(height: DetailSpacing.lg),

          // Show empty state for transaction history (will be populated from backend)
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
                ),
                SizedBox(height: DetailSpacing.md),
                Text(
                  'No recent transactions',
                  style: DetailTypography.label(context).copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                SizedBox(height: DetailSpacing.xs),
                Text(
                  'Your transaction history will appear here',
                  style: DetailTypography.caption(context),
                ),
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
    VoidCallback onTap,
  ) {
    return DesktopCard(
      margin: EdgeInsets.only(bottom: DetailSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(DetailRadius.md),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          SizedBox(width: DetailSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DetailTypography.cardTitle(context),
                ),
                SizedBox(height: DetailSpacing.xs),
                Text(
                  subtitle,
                  style: DetailTypography.caption(context),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildSendDialog(ThemeProvider themeProvider) {
    return _buildDialog(
      themeProvider,
      title: 'Send Tokens',
      icon: Icons.arrow_upward,
      iconColor: themeProvider.accentColor,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Recipient Address', style: DetailTypography.label(context)),
          SizedBox(height: DetailSpacing.sm),
          TextField(
            decoration: InputDecoration(
              hintText: 'Enter Solana address',
              filled: true,
              fillColor: Theme.of(context).colorScheme.primaryContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DetailRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SizedBox(height: DetailSpacing.lg + DetailSpacing.xs),
          Text('Amount', style: DetailTypography.label(context)),
          SizedBox(height: DetailSpacing.sm),
          TextField(
            decoration: InputDecoration(
              hintText: '0.00',
              suffixText: 'SOL',
              filled: true,
              fillColor: Theme.of(context).colorScheme.primaryContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DetailRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      onConfirm: () {
        setState(() => _showSendDialog = false);
      },
      onCancel: () {
        setState(() => _showSendDialog = false);
      },
    );
  }

  Widget _buildReceiveDialog(ThemeProvider themeProvider) {
    final web3Provider = Provider.of<Web3Provider>(context);

    return _buildDialog(
      themeProvider,
      title: 'Receive Tokens',
      icon: Icons.arrow_downward,
      iconColor: const Color(0xFF4ECDC4),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(DetailRadius.lg),
            ),
            child: const Center(
              child: Icon(Icons.qr_code_2, size: 140),
            ),
          ),
          SizedBox(height: DetailSpacing.xl),
          Container(
            padding: EdgeInsets.all(DetailSpacing.lg),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(DetailRadius.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    web3Provider.walletAddress,
                    style: GoogleFonts.robotoMono(
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    final l10n = AppLocalizations.of(context)!;
                    Clipboard.setData(ClipboardData(text: web3Provider.walletAddress));
                    ScaffoldMessenger.of(context).showKubusSnackBar(
                      SnackBar(content: Text(l10n.walletHomeAddressCopiedToast)),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
      onCancel: () {
        setState(() => _showReceiveDialog = false);
      },
    );
  }

  Widget _buildDialog(
    ThemeProvider themeProvider, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget content,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    return GestureDetector(
      onTap: onCancel,
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 480,
              padding: EdgeInsets.all(DetailSpacing.xxl),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(DetailRadius.xl),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(DetailRadius.md),
                        ),
                        child: Icon(icon, color: iconColor),
                      ),
                      SizedBox(width: DetailSpacing.lg),
                      Text(
                        title,
                        style: DetailTypography.sectionTitle(context),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: onCancel,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  SizedBox(height: DetailSpacing.xl),
                  content,
                  if (onConfirm != null) ...[
                    SizedBox(height: DetailSpacing.xl),
                    Builder(
                      builder: (context) {
                        final l10n = AppLocalizations.of(context)!;
                        return Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: onCancel,
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: DetailSpacing.md + 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(DetailRadius.md),
                                  ),
                                ),
                                child: Text(l10n.commonCancel),
                              ),
                            ),
                            SizedBox(width: DetailSpacing.md),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: onConfirm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeProvider.accentColor,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: DetailSpacing.md + 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(DetailRadius.md),
                                  ),
                                ),
                                child: Text(l10n.commonSend),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _transactionIcon(TransactionType type) {
    switch (type) {
      case TransactionType.send:
        return Icons.arrow_outward;
      case TransactionType.receive:
        return Icons.arrow_downward;
      case TransactionType.swap:
        return Icons.swap_horiz;
      case TransactionType.stake:
        return Icons.savings;
      case TransactionType.unstake:
        return Icons.lock_open;
      case TransactionType.governanceVote:
        return Icons.how_to_vote;
    }
  }

  Color _transactionColor(TransactionType type) {
    switch (type) {
      case TransactionType.send:
        return const Color(0xFFEF4444);
      case TransactionType.receive:
        return const Color(0xFF22C55E);
      case TransactionType.swap:
        return const Color(0xFF6366F1);
      case TransactionType.stake:
        return const Color(0xFF10B981);
      case TransactionType.unstake:
        return const Color(0xFFEAB308);
      case TransactionType.governanceVote:
        return const Color(0xFF3B82F6);
    }
  }

  String _truncateAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}
