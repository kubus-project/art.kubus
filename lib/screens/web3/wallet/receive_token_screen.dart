import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../models/wallet.dart';

class ReceiveTokenScreen extends StatefulWidget {
  const ReceiveTokenScreen({super.key});

  @override
  State<ReceiveTokenScreen> createState() => _ReceiveTokenScreenState();
}

class _ReceiveTokenScreenState extends State<ReceiveTokenScreen> 
    with TickerProviderStateMixin {
  
  String _selectedToken = 'KUB8';
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context);
    final walletAddress = walletProvider.currentWalletAddress;
    final hasWalletAddress = walletAddress != null && walletAddress.isNotEmpty;
    final selectedToken = _currentToken(walletProvider.tokens);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Receive Tokens',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 800;
          final isWideScreen = constraints.maxWidth > 800;
          
          return SingleChildScrollView(
            padding: EdgeInsets.all(isWideScreen ? 32 : isTablet ? 28 : 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWideScreen ? 600 : double.infinity,
              ),
              child: Center(
                child: Column(
                  children: [
                    _buildTokenSelector(),
                    SizedBox(height: isWideScreen ? 40 : isTablet ? 36 : 32),
                    _buildQRCode(walletAddress, hasWalletAddress, selectedToken),
                    SizedBox(height: isWideScreen ? 40 : isTablet ? 36 : 32),
                    _buildAddressSection(walletAddress, hasWalletAddress, selectedToken),
                    SizedBox(height: isWideScreen ? 40 : isTablet ? 36 : 32),
                    _buildInstructions(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTokenSelector() {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        final tokens = walletProvider.tokens
            .where((token) => token.type != TokenType.nft)
            .toList();

        if (tokens.isEmpty) {
          return _buildTokenSelectorEmptyState();
        }

        if (!_tokenExists(tokens, _selectedToken)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _selectedToken = tokens.first.symbol;
            });
          });
        }

        final theme = Theme.of(context);
        final accent = Provider.of<ThemeProvider>(context).accentColor;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select token to receive',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: tokens.map((token) {
                  final isSelected = token.symbol == _selectedToken;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedToken = token.symbol);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accent.withValues(alpha: 0.2)
                              : theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? accent : theme.colorScheme.outline,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTokenAvatar(token, isSelected: isSelected),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  token.symbol,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Bal. ${token.balance.toStringAsFixed(token.decimals >= 3 ? 3 : 2)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQRCode(String? walletAddress, bool hasWalletAddress, Token? token) {
    final theme = Theme.of(context);
    final tokenSymbol = token?.symbol ?? _selectedToken;
    final qrData = hasWalletAddress && walletAddress != null
        ? _buildQrPayload(walletAddress, token)
        : '';

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: hasWalletAddress
                    ? QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 184.0,
                        backgroundColor: theme.colorScheme.onPrimary,
                        eyeStyle: QrEyeStyle(color: theme.colorScheme.onSurface),
                        dataModuleStyle: QrDataModuleStyle(color: theme.colorScheme.onSurface),
                        errorStateBuilder: (cxt, err) {
                          final theme = Theme.of(cxt);
                          return Center(
                            child: Text(
                              'QR Error\nGeneration\nFailed',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Text(
                          'Create or import a wallet\nto generate a QR code',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
                    'Scan to send $tokenSymbol',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasWalletAddress
                        ? 'Anyone can send $tokenSymbol to this address'
                  : 'Finish wallet setup to share your address',
              style: GoogleFonts.inter(
                fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection(String? walletAddress, bool hasWalletAddress, Token? token) {
    final theme = Theme.of(context);
    final accent = Provider.of<ThemeProvider>(context).accentColor;
    final tokenSymbol = token?.symbol ?? _selectedToken;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your $tokenSymbol address',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Share address',
                    onPressed: hasWalletAddress && walletAddress != null
                        ? () => _shareAddress(walletAddress, token)
                        : null,
                    icon: Icon(
                      Icons.share_outlined,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy address',
                    onPressed: hasWalletAddress ? () => _copyAddress(walletAddress) : null,
                    icon: Icon(
                      Icons.copy,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
            ),
            child: hasWalletAddress
                ? SelectableText(
                    walletAddress!,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  )
                : Text(
                    'Create or import a wallet to receive tokens',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: hasWalletAddress ? () => _copyAddress(walletAddress) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(Icons.content_copy, color: theme.colorScheme.onSurface, size: 18),
              label: Text(
                'Copy address',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Provider.of<ThemeProvider>(context).accentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'How to Receive $_selectedToken',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInstructionStep(
            '1',
            'Share your address',
            'Send your wallet address to the person who wants to send you $_selectedToken',
          ),
          const SizedBox(height: 12),
          _buildInstructionStep(
            '2',
            'Or show QR code',
            'Let them scan the QR code above with their wallet app',
          ),
          const SizedBox(height: 12),
          _buildInstructionStep(
            '3',
            'Receive tokens',
            'Tokens will appear in your wallet once the transaction is confirmed',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_outlined, color: Theme.of(context).colorScheme.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Only send $_selectedToken and compatible tokens to this address',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Provider.of<ThemeProvider>(context).accentColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
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
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _copyAddress(String? walletAddress) {
    if (walletAddress == null || walletAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No wallet address available yet'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: walletAddress));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Address copied to clipboard'),
        backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareAddress(String address, Token? token) async {
    final tokenSymbol = token?.symbol ?? _selectedToken;
    final payload = _buildQrPayload(address, token);
    await Share.share('Send $tokenSymbol to $address\n$payload');
  }

  String _buildQrPayload(String address, Token? token) {
    if (address.isEmpty) return '';
    if (token == null || token.symbol.toUpperCase() == 'SOL' || token.contractAddress.toLowerCase() == 'native') {
      return 'solana:$address';
    }

    final uri = Uri(
      scheme: 'solana',
      path: address,
      queryParameters: {
        'spl-token': token.contractAddress,
        'label': token.symbol,
      },
    );
    return uri.toString();
  }

  Token? _currentToken(List<Token> tokens) {
    for (final token in tokens) {
      if (token.symbol == _selectedToken) return token;
    }
    return tokens.isNotEmpty ? tokens.first : null;
  }

  bool _tokenExists(List<Token> tokens, String symbol) {
    return tokens.any((token) => token.symbol == symbol);
  }

  Widget _buildTokenSelectorEmptyState() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined, color: theme.colorScheme.onSurface),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Connect or import a wallet to display available tokens.',
              style: GoogleFonts.inter(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenAvatar(Token token, {bool isSelected = false}) {
    final theme = Theme.of(context);
    final accent = Provider.of<ThemeProvider>(context, listen: false).accentColor;
    final background = isSelected
        ? accent.withValues(alpha: 0.25)
        : theme.colorScheme.surfaceVariant;

    if (token.logoUrl != null && token.logoUrl!.isNotEmpty) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? accent : background),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          token.logoUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _tokenInitialAvatar(token, background, theme),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _tokenInitialAvatar(token, background, theme);
          },
        ),
      );
    }

    return _tokenInitialAvatar(token, background, theme);
  }

  Widget _tokenInitialAvatar(Token token, Color background, ThemeData theme) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          token.symbol.isNotEmpty ? token.symbol.substring(0, 1).toUpperCase() : '?',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}





