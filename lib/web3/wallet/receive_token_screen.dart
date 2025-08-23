import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/themeprovider.dart';

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
  
  final List<Map<String, String>> _tokens = [
    {'symbol': 'KUB8', 'name': 'art.kubus Token', 'balance': '1,250.00', 'icon': '🎨'},
    {'symbol': 'SOL', 'name': 'Solana', 'balance': '12.5', 'icon': '☀️'},
    {'symbol': 'USDC', 'name': 'USD Coin', 'balance': '500.00', 'icon': '💵'},
  ];

  final String _walletAddress = 'Bm7s9F8zXqJ3rV2kH4nL6pA8dC5eR9tY1mN3vB6xK0w';

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
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Receive Tokens',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
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
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _tokens.map((token) {
              final isSelected = _selectedToken == token['symbol'];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedToken = token['symbol']!;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.2)
                        : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                          ? Provider.of<ThemeProvider>(context).accentColor
                          : Colors.grey[800]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          token['icon']!,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          token['symbol']!,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
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
  }

  Widget _buildQRCode() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Column(
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'QR CODE\nWOULD BE\nHERE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Scan to send $_selectedToken',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Anyone can send $_selectedToken to this address',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[400],
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
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
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
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: _copyAddress,
                icon: const Icon(
                  Icons.copy,
                  color: Colors.grey,
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
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: Text(
              _walletAddress,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _copyAddress,
              style: ElevatedButton.styleFrom(
                backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.copy, color: Colors.white, size: 18),
              label: Text(
                'Copy Address',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
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
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
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
                  color: Colors.white,
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
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
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
                color: Colors.white,
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
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey[400],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _copyAddress() {
    Clipboard.setData(ClipboardData(text: _walletAddress));
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
