import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/web3provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/themeprovider.dart';
import '../config/config.dart';
import 'wallet/wallet_home.dart';
import 'marketplace/marketplace.dart';

class Web3Dashboard extends StatefulWidget {
  const Web3Dashboard({super.key});

  @override
  State<Web3Dashboard> createState() => _Web3DashboardState();
}

class _Web3DashboardState extends State<Web3Dashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<Web3Provider, ThemeProvider>(
      builder: (context, web3Provider, themeProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Web3 Dashboard'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.account_balance_wallet), text: 'Wallet'),
                Tab(icon: Icon(Icons.store), text: 'Marketplace'),
                Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  web3Provider.isConnected 
                    ? Icons.account_balance_wallet 
                    : Icons.account_balance_wallet_outlined,
                  color: web3Provider.isConnected 
                    ? Colors.green 
                    : null,
                ),
                onPressed: () {
                  if (web3Provider.isConnected) {
                    _showWalletInfo(context, web3Provider);
                  } else {
                    _connectWallet(context, web3Provider);
                  }
                },
              ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Wallet Tab
              web3Provider.isConnected
                ? const WalletHome()
                : _buildConnectWalletPrompt(context, web3Provider),
              
              // Marketplace Tab
              AppConfig.enableMarketplace
                ? const Marketplace()
                : _buildFeatureDisabled('Marketplace'),
              
              // Analytics Tab
              _buildAnalyticsTab(context, web3Provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectWalletPrompt(BuildContext context, Web3Provider web3Provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 120,
              color: Theme.of(context).primaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Connect Your Wallet',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Connect a Web3 wallet to access your tokens, NFTs, and participate in the marketplace.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _connectWallet(context, web3Provider),
              icon: const Icon(Icons.link),
              label: const Text('Connect Wallet'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Browse without wallet'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureDisabled(String featureName) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 80,
              color: Theme.of(context).primaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '$featureName Coming Soon',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'This feature is currently disabled in the configuration.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab(BuildContext context, Web3Provider web3Provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Web3 Analytics',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          _buildAnalyticsCard(
            context,
            'Portfolio Value',
            web3Provider.isConnected || AppConfig.useMockData ? '\$${_calculatePortfolioValue()}' : '--',
            Icons.account_balance,
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildAnalyticsCard(
            context,
            'NFTs Owned',
            web3Provider.isConnected ? '${_getNFTCount()}' : '--',
            Icons.image,
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildAnalyticsCard(
            context,
            'Transactions',
            web3Provider.isConnected ? '${_getTransactionCount()}' : '--',
            Icons.swap_horiz,
            Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildAnalyticsCard(
            context,
            'Network',
            web3Provider.isConnected ? _getCurrentNetwork() : '--',
            Icons.network_cell,
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _connectWallet(BuildContext context, Web3Provider web3Provider) {
    // Simulate wallet connection for now
    if (AppConfig.useMockData) {
      web3Provider.connectWallet();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mock wallet connected!')),
      );
    } else {
      // Navigate to wallet connection screen
      Navigator.of(context).pushNamed('/wallet_connect');
    }
  }

  void _showWalletInfo(BuildContext context, Web3Provider web3Provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wallet Info'),
        content: Consumer<WalletProvider>(
          builder: (context, walletProvider, child) {
            // Get SOL balance
            final solBalance = walletProvider.tokens
                .where((token) => token.symbol.toUpperCase() == 'SOL')
                .isNotEmpty 
                ? walletProvider.tokens
                    .where((token) => token.symbol.toUpperCase() == 'SOL')
                    .first.balance 
                : 0.0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Address: ${web3Provider.walletAddress}'),
                const SizedBox(height: 8),
                Text('Balance: ${solBalance.toStringAsFixed(3)} SOL'),
                const SizedBox(height: 8),
                Text('Network: ${_getCurrentNetwork()}'),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              web3Provider.disconnectWallet();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Wallet disconnected')),
              );
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  String _calculatePortfolioValue() {
    final web3Provider = Provider.of<Web3Provider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    if (AppConfig.useMockData || web3Provider.isConnected) {
      // Get KUB8 balance
      final kub8Balance = walletProvider.tokens
          .where((token) => token.symbol.toUpperCase() == 'KUB8')
          .isNotEmpty 
          ? walletProvider.tokens
              .where((token) => token.symbol.toUpperCase() == 'KUB8')
              .first.balance 
          : 0.0;
      
      // Get SOL balance  
      final solBalance = walletProvider.tokens
          .where((token) => token.symbol.toUpperCase() == 'SOL')
          .isNotEmpty 
          ? walletProvider.tokens
              .where((token) => token.symbol.toUpperCase() == 'SOL')
              .first.balance 
          : 0.0;

      // Calculate based on KUB8 and SOL balances like in wallet_home
      final kub8Value = kub8Balance * 1.0; // 1 KUB8 = $1 USD
      final solValue = solBalance * 20.0; // 1 SOL = $20 USD (mock rate)
      return (kub8Value + solValue).toStringAsFixed(2);
    }
    return '0.00';
  }

  int _getNFTCount() {
    if (AppConfig.useMockData) {
      return 12;
    }
    return 0;
  }

  int _getTransactionCount() {
    if (AppConfig.useMockData) {
      return 34;
    }
    return 0;
  }

  String _getCurrentNetwork() {
    if (AppConfig.useMockData) {
      return 'Polygon';
    }
    return 'Unknown';
  }
}
