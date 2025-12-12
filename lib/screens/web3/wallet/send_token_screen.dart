import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
          'Send Token',
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
                  ? 'Scan QR Code' 
                  : 'QR Scanner not available on this platform',
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
              'Select Token',
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
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAddressInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recipient Address',
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
              hintText: 'Enter recipient address',
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
                      ? 'Scan QR Code' 
                      : 'QR Scanner not available',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Amount',
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
                  'MAX',
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
          'Available: ${_getTokenBalance(_selectedToken)} $_selectedToken',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionSummary() {
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
            'Transaction Summary',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Amount', '${amount.toStringAsFixed(4)} $_selectedToken'),
          if (projectFee > 0) ...[
            const SizedBox(height: 8),
            _buildSummaryRow(
              'Kubus fees (~${_projectFeePercent.toStringAsFixed(1)}%)',
              '${projectFee.toStringAsFixed(4)} $_selectedToken',
            ),
          ],
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Estimated token debit',
            '${totalTokenDebit.toStringAsFixed(4)} $_selectedToken',
            isTotal: true,
          ),
          const SizedBox(height: 12),
          Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          _buildSummaryRow('USD value', '\$${usdValue.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _buildSummaryRow('Network fee', '${_estimatedGas.toStringAsFixed(6)} SOL'),
          const SizedBox(height: 10),
          Text(
            'Network fees are paid in SOL. Keep a small SOL balance for gas.',
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
              'Connect or create a wallet to select tokens for sending.',
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
                    'Send $_selectedToken',
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
    setState(() {
      if (trimmed.isEmpty) {
        _addressError = 'Address is required';
      } else if (!_isValidSolanaAddress(trimmed)) {
        _addressError = 'Enter a valid Solana address';
      } else {
        _addressError = '';
      }
    });
  }

  void _validateAmount(String value) {
    final amount = double.tryParse(value);
    final balance = double.tryParse(_getTokenBalance(_selectedToken).replaceAll(',', '')) ?? 0.0;
    
    setState(() {
      if (value.isEmpty) {
        _amountError = 'Amount is required';
      } else if (amount == null || amount <= 0) {
        _amountError = 'Amount must be greater than 0';
      } else if (amount > balance) {
        _amountError = 'Insufficient balance';
      } else {
        _amountError = '';
      }
      _estimateGasFee();
    });
  }

  void _setMaxAmount() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final token = walletProvider.getTokenBySymbol(_selectedToken);
    final balance = token?.balance ?? double.tryParse(_getTokenBalance(_selectedToken)) ?? 0.0;
    if (balance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No balance available for this token'),
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
          content: const Text('Unable to compute max amount. Keep some balance for fees.'),
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

  String _mapSendError(Object error) {
    final message = error.toString();
    if (message.contains('Insufficient balance')) {
      return 'Insufficient balance after protocol fees. Reduce the amount or top up your wallet.';
    }
    if (message.contains('keypair')) {
      return 'No wallet keypair available. Reconnect or re-import your wallet.';
    }
    if (message.contains('valid Solana address')) {
      return 'Enter a valid Solana address before sending.';
    }
    if (message.contains('Connect wallet')) {
      return 'Connect your wallet before sending tokens.';
    }
    return message.replaceFirst('Exception: ', '');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(platformProvider.getUnsupportedFeatureMessage('QR Code scanning')),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatScannedAmount(double amount) {
    final formatted = amount >= 1 ? amount.toStringAsFixed(4) : amount.toStringAsFixed(8);
    final trimmed = formatted
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return trimmed.isEmpty ? '0' : trimmed;
  }

  void _scanQRCode() async {
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
            content: const Text('Unable to read QR code payload.'),
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
            content: const Text('QR code did not include a valid address.'),
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

      final snackSegments = <String>['Address scanned'];
      if (detectedToken != null) {
        snackSegments.add('Token: ${detectedToken.symbol}');
      }
      if (amountText != null) {
        snackSegments.add('Amount: $amountText');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snackSegments.join(' • ')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.tertiary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error scanning QR code: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _sendTransaction() async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final amount = double.tryParse(_amountController.text.trim()) ?? 0;
      final toAddress = _addressController.text.trim();

      if (amount <= 0) {
        throw Exception('Enter an amount greater than zero');
      }
      if (!_isValidSolanaAddress(toAddress)) {
        throw Exception('Please provide a valid Solana address');
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
          content: Text('Sent ${amount.toStringAsFixed(4)} $_selectedToken successfully'),
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
          content: Text(_mapSendError(e)),
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


