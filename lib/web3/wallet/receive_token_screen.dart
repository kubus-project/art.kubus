import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/themeprovider.dart';
import '../../providers/wallet_provider.dart';
import '../../config/api_keys.dart';

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

  // Getter for wallet address that uses the provider
  String get _walletAddress {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    return walletProvider.currentWalletAddress ?? ApiKeys.mockReceiveAddress;
  }

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
                    _buildQRCode(),
                    SizedBox(height: isWideScreen ? 40 : isTablet ? 36 : 32),
                    _buildAddressSection(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Token to Receive',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Consumer<WalletProvider>(
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
                {'symbol': 'KUB8', 'name': 'art.kubus Token', 'balance': kub8Balance.toStringAsFixed(2), 'icon': Icons.palette},
                {'symbol': 'SOL', 'name': 'Solana', 'balance': solBalance.toStringAsFixed(3), 'icon': Icons.wb_sunny},
              ];

              return Row(
                children: tokens.map((token) {
              final isSelected = _selectedToken == token['symbol'];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedToken = token['symbol'] as String;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.2)
                        : Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                          ? Provider.of<ThemeProvider>(context).accentColor
                          : Theme.of(context).colorScheme.outline,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          token['icon'] as IconData,
                          size: 20,
                          color: isSelected 
                            ? Provider.of<ThemeProvider>(context).accentColor
                            : Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          token['symbol'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQRCode() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: QrImageView(
                  data: _walletAddress,
                  version: QrVersions.auto,
                  size: 184.0,
                  backgroundColor: Theme.of(context).colorScheme.onPrimary,
                  eyeStyle: const QrEyeStyle(color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(color: Colors.black),
                  errorStateBuilder: (cxt, err) {
                    return const Center(
                      child: Text(
                        'QR Error\nGeneration\nFailed',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Scan to send $_selectedToken',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Anyone can send $_selectedToken to this address',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your $_selectedToken Address',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: () => _copyAddress(_walletAddress),
                icon: Icon(
                  Icons.copy,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
            ),
            child: Text(
              _walletAddress,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _copyAddress(_walletAddress),
              style: ElevatedButton.styleFrom(
                backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(Icons.copy, color: Theme.of(context).colorScheme.onSurface, size: 18),
              label: Text(
                'Copy Address',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
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
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Only send $_selectedToken and compatible tokens to this address',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.orange,
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

  void _copyAddress(String walletAddress) {
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
}





