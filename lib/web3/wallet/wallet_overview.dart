import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/web3provider.dart';
import '../../providers/wallet_provider.dart';
import 'wallet_transactions.dart';
import 'nft_gallery.dart';
import 'token_swap.dart';

class WalletOverview extends StatefulWidget {
  const WalletOverview({super.key});

  @override
  State<WalletOverview> createState() => _WalletOverviewState();
}

class _WalletOverviewState extends State<WalletOverview> {
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Wallet & Assets',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            onPressed: _showQRScanner,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildWalletHeader(),
          _buildBalanceBreakdown(),
          _buildActionButtons(),
          _buildNavigationTabs(),
          Expanded(
            child: _buildCurrentTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletHeader() {
    return Consumer<Web3Provider>(
      builder: (context, web3Provider, child) {
        return Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6C63FF), Color(0xFF4CAF50)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Balance',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Consumer<WalletProvider>(
                        builder: (context, walletProvider, child) {
                          if (!web3Provider.isConnected) {
                            return Text(
                              '\$0.00',
                              style: GoogleFonts.inter(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }

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

                          final totalValue = kub8Balance * 1.0 + solBalance * 20.0;

                          return Text(
                            '\$${totalValue.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Consumer<WalletProvider>(
                builder: (context, walletProvider, child) {
                  final walletAddress = walletProvider.currentWalletAddress;
                  
                  if (walletAddress != null && walletAddress.isNotEmpty)
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${walletAddress.substring(0, 6)}...${walletAddress.substring(walletAddress.length - 4)}',
                        style: GoogleFonts.robotoMono(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    );
                  else
                    return GestureDetector(
                      onTap: () async {
                        try {
                          await walletProvider.createWallet();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Wallet created successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error creating wallet: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Create Wallet',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6C63FF),
                          ),
                        ),
                      ),
                    );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalanceBreakdown() {
    return Consumer<Web3Provider>(
      builder: (context, web3Provider, child) {
        if (!web3Provider.isConnected) return const SizedBox.shrink();
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Asset Breakdown',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Consumer<WalletProvider>(
                builder: (context, walletProvider, child) {
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

                  return Column(
                    children: [
                      _buildAssetRow('KUB8', 'Kubit Token', kub8Balance, '\$${(kub8Balance * 1.0).toStringAsFixed(2)}', const Color(0xFF8B5CF6)),
                      const SizedBox(height: 12),
                      _buildAssetRow('SOL', 'Solana', solBalance, '\$${(solBalance * 20).toStringAsFixed(2)}', const Color(0xFF9945FF)),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAssetRow(String symbol, String name, double balance, String usdValue, Color color) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              symbol == 'SOL' ? 'S' : 'K8',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                symbol,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              balance.toStringAsFixed(2),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              usdValue,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              'Send',
              Icons.arrow_upward,
              const Color(0xFFFF6B6B),
              _showSendDialog,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              'Receive',
              Icons.arrow_downward,
              const Color(0xFF00D4AA),
              _showReceiveDialog,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              'Swap',
              Icons.swap_horiz,
              const Color(0xFFFFD93D),
              () {
                setState(() {
                  _currentTabIndex = 2;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              'Buy',
              Icons.add,
              const Color(0xFF9C27B0),
              _showBuyDialog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        children: [
          _buildTabButton('Transactions', 0),
          _buildTabButton('NFTs', 1),
          _buildTabButton('Swap', 2),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _currentTabIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentTabIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : Colors.grey[400],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    switch (_currentTabIndex) {
      case 0:
        return const WalletTransactions();
      case 1:
        return const NFTGallery();
      case 2:
        return const TokenSwap();
      default:
        return const WalletTransactions();
    }
  }

  void _showBuyDialog() {
    // Implement buy dialog
  }

  void _showQRScanner() {
    // Implement QR scanner
  }

  void _showSendDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSendSheet(),
    );
  }

  void _showReceiveDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildReceiveSheet(),
    );
  }

  Widget _buildSendSheet() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Send Tokens',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          // Add send form here
        ],
      ),
    );
  }

  Widget _buildReceiveSheet() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Receive Tokens',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          // Add QR code here
        ],
      ),
    );
  }
}
