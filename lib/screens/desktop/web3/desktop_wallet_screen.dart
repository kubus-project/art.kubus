import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/web3provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../models/wallet.dart';
import '../../../utils/app_animations.dart';
import '../components/desktop_widgets.dart';
import '../../../services/backend_api_service.dart';
import '../../../widgets/empty_state_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../web3/wallet/token_swap.dart';

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isLarge = screenWidth >= 1200;

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF8F9FA),
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
                      child: _buildMainContent(themeProvider, isLarge),
                    ),

                    // Right panel - Quick actions & recent
                    if (isLarge)
                      Container(
                        width: 360,
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        child: _buildRightPanel(themeProvider),
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
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
                child: _buildBalanceCard(themeProvider, web3Provider),
              ),
            ),

            // Quick actions (on smaller screens)
            if (!isLarge)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
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
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: themeProvider.accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 56,
                color: themeProvider.accentColor,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Connect Your Wallet',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Connect your Solana wallet to access your assets, send & receive tokens, and interact with the marketplace.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                height: 1.6,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 40),
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
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/import-wallet');
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Import Wallet'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    side: BorderSide(color: themeProvider.accentColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () {},
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
      padding: const EdgeInsets.all(32),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Wallet',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4ADE80),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Connected to ${web3Provider.currentNetwork}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          // Network selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
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
          const SizedBox(width: 12),
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
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  themeProvider.accentColor,
                  themeProvider.accentColor.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
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
                          Clipboard.setData(ClipboardData(text: web3Provider.walletAddress));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Address copied to clipboard')),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
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
                              const SizedBox(width: 8),
                              const Icon(Icons.copy, size: 14, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      solBalance.toStringAsFixed(4),
                      style: GoogleFonts.inter(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'SOL',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '≈ \$${(solBalance * 150).toStringAsFixed(2)} USD',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),
                // KUB8 balance
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
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
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KUB8 Token',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          Text(
                            '${kub8Balance.toStringAsFixed(2)} KUB8',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {},
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
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            'Receive',
            Icons.arrow_downward,
            const Color(0xFF4ECDC4),
            () => setState(() => _showReceiveDialog = true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            'Swap',
            Icons.swap_horiz,
            const Color(0xFFFF9A8B),
            () {},
          ),
        ),
        const SizedBox(width: 12),
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32),
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
        labelStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 15),
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
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No assets yet',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(32),
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
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () {},
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: themeProvider.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                token.symbol.substring(0, 1).toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.accentColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  token.name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  token.symbol.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                token.formattedBalance,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                token.formattedValue,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isPositive
                  ? const Color(0xFF4ADE80).withValues(alpha: 0.1)
                  : const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
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
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null || userId.isEmpty) {
        throw Exception('Connect your wallet to fetch collectibles.');
      }
      final backend = BackendApiService();
      final items = await backend.getUserNFTs(userId: userId);
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
              padding: const EdgeInsets.all(24),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          itemBuilder: (context, index) {
            final tx = transactions[index];
            final color = _transactionColor(tx.type);
            return DesktopCard(
              onTap: () => Clipboard.setData(ClipboardData(text: tx.txHash)),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _transactionIcon(tx.type),
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.displayTitle,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tx.shortAddress.isNotEmpty ? tx.shortAddress : tx.txHash.substring(0, 10),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${tx.formattedAmount} ${tx.token}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      Text(
                        tx.timeAgo,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 12),
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
          padding: const EdgeInsets.all(24),
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
          padding: const EdgeInsets.all(24),
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
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
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
                  borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (creator.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'by $creator',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
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
          padding: const EdgeInsets.all(24),
          children: [
            DesktopCard(
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: themeProvider.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.savings,
                      color: themeProvider.accentColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KUB8 Rewards',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '$rewardBalance KUB8 available from achievements',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
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
                      style: GoogleFonts.inter(
                        color: themeProvider.accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DesktopCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stake SOL for gas savings',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lock SOL to cover future transaction fees and keep your gallery publishing smooth.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _showSendDialog = true),
                        icon: const Icon(Icons.safety_check),
                        label: const Text('Stake now'),
                      ),
                      const SizedBox(width: 12),
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
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),

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
            const Color(0xFF4ECDC4),
            () => setState(() => _showReceiveDialog = true),
          ),
          _buildQuickActionTile(
            'Swap',
            'Exchange tokens',
            Icons.swap_horiz,
            const Color(0xFFFF9A8B),
            () {},
          ),
          _buildQuickActionTile(
            'Buy Crypto',
            'Add funds',
            Icons.add_card,
            const Color(0xFF667eea),
            () {},
          ),

          const SizedBox(height: 32),

          Text(
            'Recent Activity',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // Show empty state for transaction history (will be populated from backend)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.history,
                  size: 32,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'No recent transactions',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your transaction history will appear here',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
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
          Text('Recipient Address', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              hintText: 'Enter Solana address',
              filled: true,
              fillColor: Theme.of(context).colorScheme.primaryContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Amount', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              hintText: '0.00',
              suffixText: 'SOL',
              filled: true,
              fillColor: Theme.of(context).colorScheme.primaryContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
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
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(Icons.qr_code_2, size: 120),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
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
                    Clipboard.setData(ClipboardData(text: web3Provider.walletAddress));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Address copied')),
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
              width: 440,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: iconColor),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: onCancel,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  content,
                  if (onConfirm != null) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onCancel,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: onConfirm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeProvider.accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Send'),
                          ),
                        ),
                      ],
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
