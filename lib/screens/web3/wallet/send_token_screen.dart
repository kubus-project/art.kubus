import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:solana/solana.dart' show Ed25519HDPublicKey;
import '../../../providers/themeprovider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/platform_provider.dart';
import '../../../widgets/inline_loading.dart';
import '../../../config/api_keys.dart';
import '../../../models/qr_scan_result.dart';
import '../../../models/wallet.dart';
import 'qr_scanner_screen.dart';

class SendTokenScreen extends StatefulWidget {
  const SendTokenScreen({super.key});

  @override
  State<SendTokenScreen> createState() => _SendTokenScreenState();
}

class _SendTokenScreenState extends State<SendTokenScreen> 
    with TickerProviderStateMixin {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String _selectedToken = 'KUB8';
  bool _isLoading = false;
  String _addressError = '';
  String _amountError = '';
  double _estimatedGas = 0.0;
  
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _estimateGasFee();
    _animationController.forward();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          l10n.sendTokenTitle,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          Consumer<PlatformProvider>(
            builder: (context, platformProvider, child) {
              return IconButton(
                icon: Icon(
                  platformProvider.getQRScannerIcon(),
                  color: platformProvider.supportsQRScanning 
                    ? Theme.of(context).colorScheme.onPrimary 
                    : platformProvider.getUnsupportedFeatureColor(context),
                ),
                onPressed: platformProvider.supportsQRScanning 
                  ? _scanQRCode 
                  : () => _showUnsupportedFeature(context, platformProvider),
                tooltip: platformProvider.supportsQRScanning 
                  ? l10n.sendTokenScanQrTooltip
                  : l10n.sendTokenQrScannerUnavailableTooltip,
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 800;
          final isWideScreen = constraints.maxWidth > 800;
          
          return SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isWideScreen ? 32 : isTablet ? 28 : 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWideScreen ? 600 : double.infinity,
                ),
                child: Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTokenSelector(),
                      SizedBox(height: isWideScreen ? 32 : isTablet ? 28 : 24),
                      _buildAddressInput(),
                      SizedBox(height: isWideScreen ? 32 : isTablet ? 28 : 24),
                      _buildAmountInput(),
                      SizedBox(height: isWideScreen ? 32 : isTablet ? 28 : 24),
                      _buildTransactionSummary(),
                      SizedBox(height: isWideScreen ? 40 : isTablet ? 36 : 32),
                      _buildSendButton(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTokenSelector() {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
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
              _estimateGasFee();
            });
          });
        }

        final theme = Theme.of(context);
        final accent = Provider.of<ThemeProvider>(context).accentColor;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sendTokenSelectTokenTitle,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: tokens.map((token) {
                final isSelected = token.symbol == _selectedToken;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedToken = token.symbol;
                      _estimateGasFee();
                      _validateAmount(_amountController.text);
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accent.withValues(alpha: 0.15)
                          : theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? accent : theme.colorScheme.outline,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTokenAvatar(token, isSelected: isSelected),
                        const SizedBox(width: 10),
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
                              l10n.receiveTokenBalanceLabel(
                                token.balance.toStringAsFixed(token.decimals >= 3 ? 3 : 2),
                              ),
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
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAddressInput() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.sendTokenRecipientAddressTitle,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _addressError.isNotEmpty 
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.outline,
            ),
          ),
          child: TextField(
            controller: _addressController,
            style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onPrimary),
            onChanged: _validateAddress,
            decoration: InputDecoration(
              hintText: l10n.sendTokenRecipientAddressHint,
              hintStyle: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              suffixIcon: Consumer<PlatformProvider>(
                builder: (context, platformProvider, child) {
                  return IconButton(
                    icon: Icon(
                      platformProvider.getQRScannerIcon(),
                      color: platformProvider.supportsQRScanning 
                        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
                        : platformProvider.getUnsupportedFeatureColor(context),
                    ),
                    onPressed: platformProvider.supportsQRScanning 
                      ? _scanQRCode 
                      : () => _showUnsupportedFeature(context, platformProvider),
                    tooltip: platformProvider.supportsQRScanning 
                      ? l10n.sendTokenScanQrTooltip
                      : l10n.sendTokenQrScannerUnavailableTooltip,
                  );
                },
              ),
            ),
          ),
        ),
        if (_addressError.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _addressError,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAmountInput() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.sendTokenAmountTitle,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            GestureDetector(
              onTap: _setMaxAmount,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Provider.of<ThemeProvider>(context).accentColor,
                  ),
                ),
                child: Text(
                  l10n.sendTokenMaxButton,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Provider.of<ThemeProvider>(context).accentColor,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _amountError.isNotEmpty 
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.outline,
            ),
          ),
          child: TextField(
            controller: _amountController,
            style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onPrimary, fontSize: 18),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: _validateAmount,
            decoration: InputDecoration(
              hintText: '0.0',
              hintStyle: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    _selectedToken,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Provider.of<ThemeProvider>(context).accentColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_amountError.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _amountError,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          l10n.sendTokenAvailableLabel(_getTokenBalance(_selectedToken), _selectedToken),
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionSummary() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final usdValue = _calculateUSDValue(amount);
    final projectFee = amount > 0 ? _calculateProjectFee(amount) : 0.0;
    final totalTokenDebit = amount + projectFee;

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
          Text(
            l10n.sendTokenTransactionSummaryTitle,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(l10n.sendTokenSummaryAmountLabel, '${amount.toStringAsFixed(4)} $_selectedToken'),
          if (projectFee > 0) ...[
            const SizedBox(height: 8),
            _buildSummaryRow(
              l10n.sendTokenSummaryFeesLabel(_projectFeePercent.toStringAsFixed(1)),
              '${projectFee.toStringAsFixed(4)} $_selectedToken',
            ),
          ],
          const SizedBox(height: 8),
          _buildSummaryRow(
            l10n.sendTokenSummaryEstimatedDebitLabel,
            '${totalTokenDebit.toStringAsFixed(4)} $_selectedToken',
            isTotal: true,
          ),
          const SizedBox(height: 12),
          Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          _buildSummaryRow(l10n.sendTokenSummaryUsdValueLabel, '\$${usdValue.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _buildSummaryRow(l10n.sendTokenSummaryNetworkFeeLabel, '${_estimatedGas.toStringAsFixed(6)} SOL'),
          const SizedBox(height: 10),
          Text(
            l10n.sendTokenNetworkFeeNote,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildTokenSelectorEmptyState() {
    final l10n = AppLocalizations.of(context)!;
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
              l10n.sendTokenNoTokensMessage,
              style: GoogleFonts.inter(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }

  bool _tokenExists(List<Token> tokens, String symbol) {
    return tokens.any((token) => token.symbol == symbol);
  }

  Widget _buildTokenAvatar(Token token, {bool isSelected = false}) {
    final theme = Theme.of(context);
    final accent = Provider.of<ThemeProvider>(context, listen: false).accentColor;
    final background = isSelected
        ? accent.withValues(alpha: 0.25)
        : theme.colorScheme.surfaceContainerHighest;

    if (token.logoUrl != null && token.logoUrl!.isNotEmpty) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
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
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
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

  Widget _buildSendButton() {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        final l10n = AppLocalizations.of(context)!;
        final isValid = _addressController.text.isNotEmpty &&
            _amountController.text.isNotEmpty &&
            _addressError.isEmpty &&
            _amountError.isEmpty &&
            walletProvider.isConnected &&
            walletProvider.hasActiveKeyPair;

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isValid && !_isLoading ? _sendTransaction : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: InlineLoading(
                      shape: BoxShape.circle,
                      tileSize: 4.0,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : Text(
                    l10n.sendTokenButtonLabel(_selectedToken),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
          ),
        );
      },
    );
  }

  void _validateAddress(String value) {
    final trimmed = value.trim();
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      if (trimmed.isEmpty) {
        _addressError = l10n.sendTokenAddressRequiredError;
      } else if (!_isValidSolanaAddress(trimmed)) {
        _addressError = l10n.sendTokenAddressInvalidError;
      } else {
        _addressError = '';
      }
    });
  }

  void _validateAmount(String value) {
    final l10n = AppLocalizations.of(context)!;
    final amount = double.tryParse(value);
    final balance = double.tryParse(_getTokenBalance(_selectedToken).replaceAll(',', '')) ?? 0.0;
    
    setState(() {
      if (value.isEmpty) {
        _amountError = l10n.sendTokenAmountRequiredError;
      } else if (amount == null || amount <= 0) {
        _amountError = l10n.sendTokenAmountGreaterThanZeroError;
      } else if (amount > balance) {
        _amountError = l10n.sendTokenInsufficientBalanceError;
      } else {
        _amountError = '';
      }
      _estimateGasFee();
    });
  }

  void _setMaxAmount() {
    final l10n = AppLocalizations.of(context)!;
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final token = walletProvider.getTokenBySymbol(_selectedToken);
    final balance = token?.balance ?? double.tryParse(_getTokenBalance(_selectedToken)) ?? 0.0;
    if (balance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.sendTokenNoBalanceToast),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final feeMultiplier = 1 + (ApiKeys.kubusTeamFeePct + ApiKeys.kubusTreasuryFeePct);
    final maxSendable = balance / feeMultiplier;
    if (maxSendable <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.sendTokenMaxAmountComputeFailedToast),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final decimals = token?.decimals ?? 3;
    final displayPrecision = decimals < 2
        ? 2
        : (decimals > 6 ? 6 : decimals);
    _amountController.text = maxSendable.toStringAsFixed(displayPrecision);
    _validateAmount(_amountController.text);
  }

  String _getTokenBalance(String token) {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    switch (token) {
      case 'KUB8': 
        final kub8Tokens = walletProvider.tokens.where((t) => t.symbol.toUpperCase() == 'KUB8');
        return kub8Tokens.isNotEmpty ? kub8Tokens.first.balance.toStringAsFixed(2) : '0.00';
      case 'SOL': 
        final solTokens = walletProvider.tokens.where((t) => t.symbol.toUpperCase() == 'SOL');
        return solTokens.isNotEmpty ? solTokens.first.balance.toStringAsFixed(3) : '0.000';
      default: return '0.00';
    }
  }

  double get _projectFeePercent => (ApiKeys.kubusTeamFeePct + ApiKeys.kubusTreasuryFeePct) * 100;

  double _calculateProjectFee(double amount) {
    final totalFeeFraction = ApiKeys.kubusTeamFeePct + ApiKeys.kubusTreasuryFeePct;
    return amount * totalFeeFraction;
  }

  double _calculateUSDValue(double amount) {
    final rate = {'KUB8': 0.20, 'SOL': 150.0, 'USDC': 1.0}[_selectedToken] ?? 0.0;
    return amount * rate;
  }

  bool _isValidSolanaAddress(String value) {
    try {
      Ed25519HDPublicKey.fromBase58(value);
      return true;
    } catch (_) {
      return false;
    }
  }

  String _mapSendError(AppLocalizations l10n, Object error) {
    if (kDebugMode) {
      debugPrint('SendTokenScreen: send error: $error');
    }

    final message = error.toString();
    if (message.contains('Insufficient balance')) {
      return l10n.sendTokenInsufficientAfterFeesToast;
    }
    if (message.contains('keypair')) {
      return l10n.sendTokenNoKeypairToast;
    }
    if (message.contains('valid Solana address')) {
      return l10n.sendTokenInvalidAddressBeforeSendToast;
    }
    if (message.contains('Connect wallet')) {
      return l10n.sendTokenConnectWalletBeforeSendToast;
    }
    return l10n.sendTokenSendFailedToast;
  }

  void _estimateGasFee() {
    // Estimate gas fees for different tokens
    final fees = {
      'KUB8': 0.001, // SOL fee for SPL token
      'SOL': 0.000005, // Base SOL fee
      'USDC': 0.001, // SOL fee for SPL token
    };
    
    setState(() {
      _estimatedGas = fees[_selectedToken] ?? 0.001;
    });
  }

  // ignore: unused_element
  String _getNetworkCurrency() {
    final currencies = {
      'KUB8': 'SOL',
      'SOL': 'SOL',
      'USDC': 'SOL',
    };
    return currencies[_selectedToken] ?? 'SOL';
  }

  void _showUnsupportedFeature(BuildContext context, PlatformProvider platformProvider) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_qrScannerUnsupportedMessage(l10n, platformProvider)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _qrScannerUnsupportedMessage(AppLocalizations l10n, PlatformProvider platformProvider) {
    if (platformProvider.isWeb) return l10n.sendTokenQrScannerUnsupportedWeb;
    if (platformProvider.isDesktop) return l10n.sendTokenQrScannerUnsupportedDesktop;
    return l10n.sendTokenQrScannerUnsupportedPlatform;
  }

  String _formatScannedAmount(double amount) {
    final formatted = amount >= 1 ? amount.toStringAsFixed(4) : amount.toStringAsFixed(8);
    final trimmed = formatted
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return trimmed.isEmpty ? '0' : trimmed;
  }

  void _scanQRCode() async {
    final l10n = AppLocalizations.of(context)!;
    final platformProvider = Provider.of<PlatformProvider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    // Check if platform supports QR scanning
    if (!platformProvider.supportsQRScanning) {
      _showUnsupportedFeature(context, platformProvider);
      return;
    }
    
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const QRScannerScreen(),
        ),
      );
      if (!mounted) return;
      if (result == null) return;

      QRScanResult? structured;
      String? fallbackAddress;

      if (result is QRScanResult) {
        structured = result;
      } else if (result is String && result.trim().isNotEmpty) {
        fallbackAddress = result.trim();
        structured = QRScanResult.tryParse(fallbackAddress);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.sendTokenQrUnreadableToast),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      final address = structured?.address ?? fallbackAddress;
      if (address == null || address.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.sendTokenQrInvalidAddressToast),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      final Token? detectedToken = structured?.tokenMint != null
          ? walletProvider.getTokenByMint(structured!.tokenMint!)
          : null;
      final bool hasAmount = structured?.hasAmount ?? false;
      final String? amountText = hasAmount ? _formatScannedAmount(structured!.amount!) : null;

      setState(() {
        _addressController.text = address;
        if (detectedToken != null) {
          _selectedToken = detectedToken.symbol;
        }
        if (amountText != null) {
          _amountController.text = amountText;
        }
      });

      _validateAddress(address);
      if (amountText != null) {
        _validateAmount(amountText);
      }
      _estimateGasFee();

      final snackSegments = <String>[l10n.sendTokenQrScannedAddressLabel];
      if (detectedToken != null) {
        snackSegments.add(l10n.sendTokenQrScannedTokenLabel(detectedToken.symbol));
      }
      if (amountText != null) {
        snackSegments.add(l10n.sendTokenQrScannedAmountLabel(amountText));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snackSegments.join(' • ')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.tertiary,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SendTokenScreen: QR scan error: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.sendTokenQrScanErrorToast),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _sendTransaction() async {
    final l10n = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final amount = double.tryParse(_amountController.text.trim()) ?? 0;
      final toAddress = _addressController.text.trim();

      if (amount <= 0) {
        throw Exception('invalid_amount');
      }
      if (!_isValidSolanaAddress(toAddress)) {
        throw Exception('invalid_address');
      }

      await walletProvider.sendTransaction(
        token: _selectedToken,
        amount: amount,
        toAddress: toAddress,
      );

      await walletProvider.refreshData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.sendTokenSendSuccessToast(amount.toStringAsFixed(4), _selectedToken)),
          backgroundColor: Theme.of(context).colorScheme.tertiary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mapSendError(l10n, e)),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}


