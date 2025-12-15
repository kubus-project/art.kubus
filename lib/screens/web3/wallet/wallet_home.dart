import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/navigation_provider.dart';
import '../../../widgets/app_loading.dart';
import 'mnemonic_reveal_screen.dart';
import '../../../providers/web3provider.dart';
import '../../../models/wallet.dart';
import 'nft_gallery.dart';
import 'token_swap.dart';
import 'send_token_screen.dart';
import 'receive_token_screen.dart';
import '../../settings_screen.dart';
import '../../../widgets/empty_state_card.dart';
import '../../../utils/app_color_utils.dart';

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
      Provider.of<NavigationProvider>(context, listen: false).trackScreenVisit('wallet');
    });
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
        
        // Show loading indicator while wallet is loading
        if (isLoading) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
              title: Text(
                l10n.walletHomeTitle,
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
                  const AppLoading(),
                  const SizedBox(height: 16),
                  Text(
                    l10n.walletHomeLoadingLabel,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
                l10n.walletHomeTitle,
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: EmptyStateCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: l10n.settingsNoWalletConnected,
                  description: l10n.walletHomeNoWalletDescription,
                  showAction: true,
                  actionLabel: l10n.authConnectWalletButton,
                  onAction: () {
                    final web3Provider = Provider.of<Web3Provider>(context, listen: false);
                    if (!web3Provider.isConnected) {
                      Navigator.pushReplacementNamed(context, '/connect_wallet');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.walletHomeAlreadyConnectedToast)),
                      );
                    }
                  },
                ),
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
                  l10n.walletHomeTitle,
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
                                l10n.walletHomeTotalBalanceLabel,
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
                                      content: Text(l10n.walletHomeAddressLabel(address)),
                                      action: SnackBarAction(
                                        label: l10n.commonCopy,
                                        onPressed: () async {
                                          await Clipboard.setData(ClipboardData(text: address));
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(l10n.walletHomeAddressCopiedToast),
                                                duration: const Duration(seconds: 2),
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
                              l10n.walletHomeActionSend,
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
                              l10n.walletHomeActionReceive,
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
                              l10n.walletHomeActionSwap,
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
                              l10n.walletHomeActionNfts,
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
                          l10n.walletHomeYourTokensTitle,
                          style: GoogleFonts.inter(
                            fontSize: isSmallScreen ? 18 : 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
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
                            _buildTokenAvatar(token),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
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
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          _getTokenInitial(token),
          style: GoogleFonts.inter(
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                l10n.walletHomeRecentTransactionsTitle,
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: _showTransactionHistorySheet,
              child: Text(
                l10n.commonViewAll,
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
                        _transactionTypeLabel(transaction.type, l10n),
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
                        color: _getTransactionColor(transaction.type),
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
    final scheme = Theme.of(context).colorScheme;
    switch (type) {
      case TransactionType.send:
        return scheme.error;
      case TransactionType.receive:
        return scheme.primary;
      case TransactionType.swap:
        return scheme.secondary;
      case TransactionType.stake:
        return AppColorUtils.shiftLightness(scheme.primary, -0.08);
      case TransactionType.unstake:
        return AppColorUtils.shiftLightness(scheme.primary, 0.10);
      case TransactionType.governanceVote:
        return scheme.primary;
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
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return l10n.walletHomeTimeAgoDays(difference.inDays);
    } else if (difference.inHours > 0) {
      return l10n.walletHomeTimeAgoHours(difference.inHours);
    } else {
      return l10n.walletHomeTimeAgoMinutes(difference.inMinutes);
    }
  }

  void _showWalletSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  String _transactionTypeLabel(TransactionType type, AppLocalizations l10n) {
    switch (type) {
      case TransactionType.send:
        return l10n.settingsTxSentLabel;
      case TransactionType.receive:
        return l10n.settingsTxReceivedLabel;
      case TransactionType.swap:
        return l10n.walletHomeTxSwapLabel;
      case TransactionType.stake:
        return l10n.walletHomeTxStakeLabel;
      case TransactionType.unstake:
        return l10n.walletHomeTxUnstakeLabel;
      case TransactionType.governanceVote:
        return l10n.walletHomeTxGovernanceVoteLabel;
    }
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
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
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface),
                        tooltip: l10n.commonClose,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (transactions.isEmpty)
                    Expanded(
                      child: Center(
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
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _getTransactionColor(tx.type).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    _getTransactionIcon(tx.type),
                                    color: _getTransactionColor(tx.type),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _transactionTypeLabel(tx.type, l10n),
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${tx.txHash.substring(0, 10)}...',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${tx.amount.toStringAsFixed(4)} ${tx.token}',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _getTransactionColor(tx.type),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatTime(tx.timestamp),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
