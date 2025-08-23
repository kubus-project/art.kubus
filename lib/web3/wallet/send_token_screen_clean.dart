import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/themeprovider.dart';
import '../../providers/wallet_provider.dart';
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
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Send Token',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            onPressed: _scanQRCode,
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
        final kub8Balance = walletProvider.tokens
            .where((token) => token.symbol.toUpperCase() == 'KUB8')
            .isNotEmpty 
            ? walletProvider.tokens
                .where((token) => token.symbol.toUpperCase() == 'KUB8')
                .first.balance 
            : 0.0;
        
        final solBalance = walletProvider.tokens
            .where((token) => token.symbol.toUpperCase() == 'SOL')
            .isNotEmpty 
            ? walletProvider.tokens
                .where((token) => token.symbol.toUpperCase() == 'SOL')
                .first.balance 
            : 0.0;

        final tokens = [
          {'symbol': 'KUB8', 'name': 'art.kubus Token', 'balance': kub8Balance.toStringAsFixed(2), 'icon': '🎨'},
          {'symbol': 'SOL', 'name': 'Solana', 'balance': solBalance.toStringAsFixed(3), 'icon': '☀️'},
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Token',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final isSmallScreen = screenWidth < 400;
            final isMediumScreen = screenWidth < 600;
            
            // Calculate responsive dimensions
            int crossAxisCount;
            double childAspectRatio;
            double spacing;
            
            if (isSmallScreen) {
              crossAxisCount = 1;
              childAspectRatio = 3.5;
              spacing = 8.0;
            } else if (isMediumScreen) {
              crossAxisCount = 2;
              childAspectRatio = 2.5;
              spacing = 12.0;
            } else {
              crossAxisCount = 3;
              childAspectRatio = 2.0;
              spacing = 16.0;
            }
            
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
              ),
              itemCount: tokens.length,
              itemBuilder: (context, index) {
                final token = tokens[index];
                final isSelected = _selectedToken == token['symbol'];
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedToken = token['symbol'] as String;
                      _estimateGasFee();
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.1)
                        : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                          ? Provider.of<ThemeProvider>(context).accentColor
                          : Colors.grey[800]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          token['icon'] as String,
                          style: TextStyle(fontSize: isSmallScreen ? 20 : 24),
                        ),
                        SizedBox(height: isSmallScreen ? 4 : 8),
                        Text(
                          token['symbol'] as String,
                          style: GoogleFonts.inter(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 2 : 4),
                        Text(
                          'Balance: ${token['balance']}',
                          style: GoogleFonts.inter(
                            fontSize: isSmallScreen ? 10 : 12,
                            color: Colors.grey[400],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
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
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _addressError.isNotEmpty 
                ? Colors.red 
                : Colors.grey[800]!,
            ),
          ),
          child: TextField(
            controller: _addressController,
            style: GoogleFonts.inter(color: Colors.white),
            onChanged: _validateAddress,
            decoration: InputDecoration(
              hintText: 'Enter recipient address',
              hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner, color: Colors.grey),
                onPressed: _scanQRCode,
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
              color: Colors.red,
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
                color: Colors.white,
              ),
            ),
            GestureDetector(
              onTap: _setMaxAmount,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.1),
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
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _amountError.isNotEmpty 
                ? Colors.red 
                : Colors.grey[800]!,
            ),
          ),
          child: TextField(
            controller: _amountController,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 18),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: _validateAmount,
            decoration: InputDecoration(
              hintText: '0.0',
              hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 18),
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
              color: Colors.red,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Available: ${_getTokenBalance(_selectedToken)} $_selectedToken',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionSummary() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final usdValue = _calculateUSDValue(amount);
    
    return Container(
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
            'Transaction Summary',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Amount', '$amount $_selectedToken'),
          const SizedBox(height: 8),
          _buildSummaryRow('USD Value', '\$${usdValue.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _buildSummaryRow('Network Fee', '${_estimatedGas.toStringAsFixed(4)} ${_getNetworkCurrency()}'),
          const Divider(color: Colors.grey),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Total',
            '${(amount + _estimatedGas).toStringAsFixed(4)} $_selectedToken',
            isTotal: true,
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
            color: Colors.grey[400],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildSendButton() {
    final isValid = _addressController.text.isNotEmpty &&
                   _amountController.text.isNotEmpty &&
                   _addressError.isEmpty &&
                   _amountError.isEmpty;

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
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              'Send $_selectedToken',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
      ),
    );
  }

  void _validateAddress(String value) {
    setState(() {
      if (value.isEmpty) {
        _addressError = 'Address is required';
      } else if (value.length < 32) {
        _addressError = 'Invalid address format';
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
    final balance = _getTokenBalance(_selectedToken);
    _amountController.text = balance.replaceAll(',', '');
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

  double _calculateUSDValue(double amount) {
    final rate = {'KUB8': 0.20, 'SOL': 150.0, 'USDC': 1.0}[_selectedToken] ?? 0.0;
    return amount * rate;
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

  String _getNetworkCurrency() {
    final currencies = {
      'KUB8': 'SOL',
      'SOL': 'SOL',
      'USDC': 'SOL',
    };
    return currencies[_selectedToken] ?? 'SOL';
  }

  void _scanQRCode() async {
    // Check if platform supports camera scanning
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR scanning is not available on web platform. Please enter address manually.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const QRScannerScreen(),
        ),
      );
      
      if (result != null && result.isNotEmpty) {
        setState(() {
          _addressController.text = result;
          _addressError = '';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Address scanned: ${result.substring(0, 20)}...'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error scanning QR code: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendTransaction() async {
    setState(() => _isLoading = true);
    
    try {
      // Simulate transaction processing
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully sent ${_amountController.text} $_selectedToken'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
