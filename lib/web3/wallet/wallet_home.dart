import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/themeprovider.dart';
import '../../providers/wallet_provider.dart';
import '../../models/wallet.dart';
import 'nft_gallery.dart';
import 'token_swap.dart';
import 'send_token_screen.dart';
import 'receive_token_screen.dart';

class WalletHome extends StatefulWidget {
  const WalletHome({super.key});

  @override
  _WalletHomeState createState() => _WalletHomeState();
}

class _WalletHomeState extends State<WalletHome> {
  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        final wallet = walletProvider.wallet;
        final tokens = walletProvider.tokens;
        
        return LayoutBuilder(
          builder: (context, constraints) {
            bool isSmallScreen = constraints.maxWidth < 600;
            
            return Scaffold(
              backgroundColor: const Color(0xFF121212),
              appBar: AppBar(
                backgroundColor: const Color(0xFF121212),
                elevation: 0,
                title: Text(
                  'My Wallet',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: _showWalletSettings,
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wallet Balance Card
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withOpacity(0.3),
                            blurRadius: 20,
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
                              Text(
                                'Total Balance',
                                style: GoogleFonts.inter(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  wallet?.shortAddress ?? 'No Address',
                                  style: GoogleFonts.inter(
                                    fontSize: isSmallScreen ? 12 : 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isSmallScreen ? 8 : 12),
                          Text(
                            '\$${wallet?.totalValue.toStringAsFixed(2) ?? '0.00'}',
                            style: GoogleFonts.inter(
                              fontSize: isSmallScreen ? 28 : 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 16 : 20),
                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionButton(
                                  'Send',
                                  Icons.arrow_upward,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const SendTokenScreen()),
                                  ),
                                  isSmallScreen,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildActionButton(
                                  'Receive',
                                  Icons.arrow_downward,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const ReceiveTokenScreen()),
                                  ),
                                  isSmallScreen,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildActionButton(
                                  'Swap',
                                  Icons.swap_horiz,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const TokenSwap()),
                                  ),
                                  isSmallScreen,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildActionButton(
                                  'NFTs',
                                  Icons.image,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const NFTGallery()),
                                  ),
                                  isSmallScreen,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: isSmallScreen ? 24 : 32),
                    
                    // Tokens Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Your Tokens',
                          style: GoogleFonts.inter(
                            fontSize: isSmallScreen ? 18 : 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showComingSoon('Token Management'),
                          child: Text(
                            'Manage',
                            style: GoogleFonts.inter(
                              fontSize: isSmallScreen ? 12 : 14,
                              color: Provider.of<ThemeProvider>(context).accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    
                    // Token List
                    Column(
                      children: tokens.map((token) => Container(
                        margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
                        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _getTokenColor(token.symbol),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Text(
                                  token.symbol.substring(0, 1).toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
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
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    token.symbol,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  token.balance.toStringAsFixed(4),
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '\$${token.value.toStringAsFixed(2)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                    
                    SizedBox(height: isSmallScreen ? 24 : 32),
                    
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

  Widget _buildActionButton(String title, IconData icon, VoidCallback onPressed, bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: isSmallScreen ? 12 : 16,
              horizontal: 8,
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: isSmallScreen ? 20 : 24,
                ),
                SizedBox(height: isSmallScreen ? 4 : 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: isSmallScreen ? 12 : 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getTokenColor(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'KUB8':
        return const Color(0xFF8B5CF6);
      case 'ETH':
        return const Color(0xFF627EEA);
      case 'BTC':
        return const Color(0xFFF7931A);
      case 'SOL':
        return const Color(0xFF00D4AA);
      case 'MATIC':
        return const Color(0xFF8247E5);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Widget _buildRecentTransactions({bool isSmallScreen = false}) {
    // Use provider data for transactions
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final recentTransactions = walletProvider.getRecentTransactions(limit: 5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Recent Transactions',
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => _showComingSoon('Transaction History'),
              child: Text(
                'View All',
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 12 : 14,
                  color: Provider.of<ThemeProvider>(context).accentColor,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isSmallScreen ? 12 : 16),
        if (recentTransactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.history,
                    color: Colors.white.withOpacity(0.5),
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions yet',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...recentTransactions.map((transaction) => Container(
            margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getTransactionColor(transaction.type).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    _getTransactionIcon(transaction.type),
                    color: _getTransactionColor(transaction.type),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.type.toString().split('.').last.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${transaction.txHash.substring(0, 10)}...',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${transaction.amount.toStringAsFixed(4)} ${transaction.token}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: transaction.type == TransactionType.receive 
                            ? Colors.green 
                            : Colors.white,
                      ),
                    ),
                    Text(
                      _formatTime(transaction.timestamp),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )),
      ],
    );
  }

  Color _getTransactionColor(TransactionType type) {
    switch (type) {
      case TransactionType.send:
        return Colors.red;
      case TransactionType.receive:
        return Colors.green;
      case TransactionType.swap:
        return Colors.blue;
      case TransactionType.stake:
        return Colors.purple;
      case TransactionType.unstake:
        return Colors.orange;
      case TransactionType.governance_vote:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  IconData _getTransactionIcon(TransactionType type) {
    switch (type) {
      case TransactionType.send:
        return Icons.arrow_upward;
      case TransactionType.receive:
        return Icons.arrow_downward;
      case TransactionType.swap:
        return Icons.swap_horiz;
      case TransactionType.stake:
        return Icons.lock;
      case TransactionType.unstake:
        return Icons.lock_open;
      case TransactionType.governance_vote:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }

  void _showWalletSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Wallet Settings',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            _buildSettingsItem(Icons.security, 'Security', () {}),
            _buildSettingsItem(Icons.backup, 'Backup Wallet', () {}),
            _buildSettingsItem(Icons.network_check, 'Network Settings', () {}),
            _buildSettingsItem(Icons.history, 'Transaction History', () {}),
            _buildSettingsItem(Icons.help_outline, 'Help & Support', () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: GoogleFonts.inter(color: Colors.white),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
      onTap: onTap,
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
