import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/themeprovider.dart';
import '../../providers/wallet_provider.dart';
import '../../screens/mnemonic_reveal_screen.dart';
import '../../providers/web3provider.dart';
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
        final walletAddress = walletProvider.currentWalletAddress;
        final tokens = walletProvider.tokens;
        final isLoading = walletProvider.isLoading;
        
        // Show loading indicator while wallet is loading
        if (isLoading) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
              title: Text(
                'My Wallet',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Provider.of<ThemeProvider>(context).accentColor,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading your wallet...',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        // Show empty state if no wallet data AND no address
        if (wallet == null && walletAddress == null) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
              title: Text(
                'My Wallet',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.onPrimary),
                  onPressed: _showWalletSettings,
                ),
              ],
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    size: 64,
                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.38),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No wallet connected',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect a wallet to get started',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      // Navigate to wallet connection screen
                      final web3Provider = Provider.of<Web3Provider>(context, listen: false);
                      if (!web3Provider.isConnected) {
                        // Navigate to ConnectWallet screen
                        Navigator.pushReplacementNamed(context, '/connect_wallet');
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Wallet already connected!'),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Connect Wallet'),
                  ),
                ],
              ),
            ),
          );
        }
        
        return LayoutBuilder(
          builder: (context, constraints) {
            bool isSmallScreen = constraints.maxWidth < 600;
            
            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              appBar: AppBar(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                elevation: 0,
                title: Text(
                  'My Wallet',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.vpn_key, color: Theme.of(context).colorScheme.onPrimary),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MnemonicRevealScreen()),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.onPrimary),
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
                        gradient: LinearGradient(
                          colors: [
                            Provider.of<ThemeProvider>(context).accentColor,
                            Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.3),
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
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  // Show full address and copy to clipboard
                                  final address = wallet?.address ?? walletAddress ?? '';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Address: $address'),
                                      action: SnackBarAction(
                                        label: 'Copy',
                                        onPressed: () async {
                                          await Clipboard.setData(ClipboardData(text: address));
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Address copied to clipboard!'),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    wallet?.shortAddress ?? _shortenAddress(walletAddress ?? ''),
                                    style: GoogleFonts.inter(
                                      fontSize: isSmallScreen ? 12 : 14,
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          // Main KUB8 Balance
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _getKub8Balance().toStringAsFixed(2),
                                style: GoogleFonts.inter(
                                  fontSize: isSmallScreen ? 36 : 48,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'KUB8',
                                style: GoogleFonts.inter(
                                  fontSize: isSmallScreen ? 16 : 20,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isSmallScreen ? 8 : 12),
                          // Secondary balances (SOL and USD)
                          Row(
                            children: [
                              Text(
                                '${_getSolBalance().toStringAsFixed(3)} SOL',
                                style: GoogleFonts.inter(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '≈ \$${wallet?.totalValue.toStringAsFixed(2) ?? '0.00'}',
                                style: GoogleFonts.inter(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: isSmallScreen ? 16 : 20),
                    
                    // Action Buttons (Separated from balance card)
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              'Send',
                              Icons.arrow_upward,
                              const Color(0xFFFF6B6B), // Red for Send
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
                              const Color(0xFF4ECDC4), // Teal for Receive
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
                              const Color(0xFF45B7D1), // Blue for Swap
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
                              const Color(0xFF96CEB4), // Green for NFTs
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const NFTGallery()),
                              ),
                              isSmallScreen,
                            ),
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
                            color: Theme.of(context).colorScheme.onSurface,
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
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
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
                                    color: Theme.of(context).colorScheme.onSurface,
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
                                    token.symbol,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  '\$${token.value.toStringAsFixed(2)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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

  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onPressed, bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
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
                  color: color,
                  size: isSmallScreen ? 20 : 24,
                ),
                SizedBox(height: isSmallScreen ? 4 : 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: isSmallScreen ? 10 : 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
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
    );
  }

  // Helper methods to get specific token balances
  double _getKub8Balance() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final kub8Tokens = walletProvider.tokens.where((token) => token.symbol.toUpperCase() == 'KUB8');
    return kub8Tokens.isNotEmpty ? kub8Tokens.first.balance : 0.0;
  }

  double _getSolBalance() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final solTokens = walletProvider.tokens.where((token) => token.symbol.toUpperCase() == 'SOL');
    return solTokens.isNotEmpty ? solTokens.first.balance : 0.0;
  }

  String _shortenAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
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
                  color: Theme.of(context).colorScheme.onSurface,
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
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.history,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions yet',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getTransactionColor(transaction.type).withValues(alpha: 0.2),
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
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${transaction.txHash.substring(0, 10)}...',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      _formatTime(transaction.timestamp),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
      case TransactionType.governanceVote:
        return const Color(0xFF8B5CF6);
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
      case TransactionType.governanceVote:
        return Icons.how_to_vote;
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
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
                color: Theme.of(context).colorScheme.onSurface,
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
      leading: Icon(icon, color: Theme.of(context).colorScheme.onPrimary),
      title: Text(
        title,
        style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onPrimary),
      ),
      trailing: Icon(Icons.arrow_forward_ios, color: Theme.of(context).colorScheme.onSurface, size: 16),
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


