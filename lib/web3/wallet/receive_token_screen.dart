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
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  final String _walletAddress = '0x742d35Cc6634C0532925a3b8d3e3d3456789abcd';
  String _selectedToken = 'KUB8';
  
  final List<Map<String, dynamic>> _tokens = [
    {'symbol': 'KUB8', 'name': 'art.kubus Token', 'balance': '1,250.00', 'icon': '🎨'},
    {'symbol': 'SOL', 'name': 'Solana', 'balance': '12.5', 'icon': '☀️'},
    {'symbol': 'ETH', 'name': 'Ethereum', 'balance': '0.85', 'icon': '�'},
    {'symbol': 'USDC', 'name': 'USD Coin', 'balance': '500.00', 'icon': '�'},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Receive Tokens',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: _shareAddress,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              _buildTokenSelector(),
              const SizedBox(height: 32),
              _buildQRCode(),
              const SizedBox(height: 32),
              _buildAddressSection(),
              const SizedBox(height: 32),
              _buildInstructions(),
              const SizedBox(height: 32),
              _buildRecentTransactions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTokenSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            'Select Token to Receive',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final isSmallScreen = screenWidth < 400;
            final isMediumScreen = screenWidth < 600;
            
            // Calculate responsive dimensions
            final cardWidth = isSmallScreen ? 100.0 : isMediumScreen ? 110.0 : 130.0;
            final cardSpacing = isSmallScreen ? 8.0 : 12.0;
            final totalCardsWidth = (_tokens.length * cardWidth) + ((_tokens.length - 1) * cardSpacing);
            
            if (totalCardsWidth <= screenWidth) {
              // Cards fit in available width - use centered layout
              return Center(
                child: Wrap(
                  spacing: cardSpacing,
                  children: _tokens.map((token) {
                    final isSelected = _selectedToken == token['symbol'];
                    
                    return GestureDetector(
                      onTap: () => setState(() => _selectedToken = token['symbol']!),
                      child: Container(
                        width: cardWidth,
                        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected 
                                ? Provider.of<ThemeProvider>(context).accentColor
                                : Colors.white.withOpacity(0.1),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  token['icon']!,
                                  style: TextStyle(fontSize: isSmallScreen ? 20 : 24),
                                ),
                                const Spacer(),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: Provider.of<ThemeProvider>(context).accentColor,
                                    size: isSmallScreen ? 16 : 20,
                                  ),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 6 : 8),
                            Text(
                              token['symbol']!,
                              style: GoogleFonts.inter(
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              token['name']!,
                              style: GoogleFonts.inter(
                                fontSize: isSmallScreen ? 9 : 10,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            } else {
              // Cards don't fit - use horizontal scroll
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _tokens.asMap().entries.map((entry) {
                    final index = entry.key;
                    final token = entry.value;
                    final isSelected = _selectedToken == token['symbol'];
                    
                    return GestureDetector(
                      onTap: () => setState(() => _selectedToken = token['symbol']!),
                      child: Container(
                        width: cardWidth,
                        margin: EdgeInsets.only(
                          right: index < _tokens.length - 1 ? cardSpacing : 0,
                        ),
                        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected 
                                ? Provider.of<ThemeProvider>(context).accentColor
                                : Colors.white.withOpacity(0.1),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  token['icon']!,
                                  style: TextStyle(fontSize: isSmallScreen ? 20 : 24),
                                ),
                                const Spacer(),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: Provider.of<ThemeProvider>(context).accentColor,
                                    size: isSmallScreen ? 16 : 20,
                                  ),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 6 : 8),
                            Text(
                              token['symbol']!,
                              style: GoogleFonts.inter(
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              token['name']!,
                              style: GoogleFonts.inter(
                                fontSize: isSmallScreen ? 9 : 10,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }
          },
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Simulated QR Code pattern
                  Container(
                    width: 160,
                    height: 160,
                    child: CustomPaint(
                      painter: QRCodePainter(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Scan to Send $_selectedToken',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              'to this wallet',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
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
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Your $_selectedToken Address',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _selectedToken,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Provider.of<ThemeProvider>(context).accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _walletAddress,
                    style: GoogleFonts.sourceCodePro(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _copyAddress,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.copy,
                      color: Provider.of<ThemeProvider>(context).accentColor,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _copyAddress,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy Address'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _shareAddress,
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue[300],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'How to Receive Tokens',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[300],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInstructionItem(
            '1',
            'Share your wallet address or QR code with the sender',
          ),
          _buildInstructionItem(
            '2',
            'Make sure they select the correct token ($_selectedToken)',
          ),
          _buildInstructionItem(
            '3',
            'Tokens will appear in your wallet after confirmation',
          ),
          _buildInstructionItem(
            '4',
            'Transaction may take a few seconds to several minutes',
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue[300],
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
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.blue[200],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    final recentTxs = [
      {'from': '0x123...abc', 'amount': '50.00 KUB8', 'time': '2 hours ago', 'status': 'Completed'},
      {'from': '0x456...def', 'amount': '0.5 SOL', 'time': '1 day ago', 'status': 'Completed'},
      {'from': '0x789...ghi', 'amount': '100.00 USDC', 'time': '3 days ago', 'status': 'Completed'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Received Transactions',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ...recentTxs.map((tx) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
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
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.arrow_downward,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Received ${tx['amount']}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'From ${tx['from']}',
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tx['status']!,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tx['time']!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )).toList(),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _shareAddress() {
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
              'Share Address',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(Icons.message, 'Messages', () {}),
                _buildShareOption(Icons.email, 'Email', () {}),
                _buildShareOption(Icons.share, 'Other', () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              icon,
              color: Provider.of<ThemeProvider>(context).accentColor,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for QR code simulation
class QRCodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final blockSize = size.width / 21; // 21x21 grid for QR code

    // Generate a simple QR-like pattern
    final pattern = [
      [1,1,1,1,1,1,1,0,1,0,1,0,1,0,1,1,1,1,1,1,1],
      [1,0,0,0,0,0,1,0,0,1,0,1,0,0,1,0,0,0,0,0,1],
      [1,0,1,1,1,0,1,0,1,0,1,0,1,0,1,0,1,1,1,0,1],
      [1,0,1,1,1,0,1,0,0,1,0,1,0,0,1,0,1,1,1,0,1],
      [1,0,1,1,1,0,1,0,1,0,1,0,1,0,1,0,1,1,1,0,1],
      [1,0,0,0,0,0,1,0,0,1,0,1,0,0,1,0,0,0,0,0,1],
      [1,1,1,1,1,1,1,0,1,0,1,0,1,0,1,1,1,1,1,1,1],
      [0,0,0,0,0,0,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0],
      [1,0,1,0,1,0,1,1,1,0,1,0,1,1,1,0,1,0,1,0,1],
      [0,1,0,1,0,1,0,0,0,1,0,1,0,0,0,1,0,1,0,1,0],
      [1,0,1,0,1,0,1,1,1,0,1,0,1,1,1,0,1,0,1,0,1],
      [0,1,0,1,0,1,0,0,0,1,0,1,0,0,0,1,0,1,0,1,0],
      [1,0,1,0,1,0,1,1,1,0,1,0,1,1,1,0,1,0,1,0,1],
      [0,0,0,0,0,0,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0],
      [1,1,1,1,1,1,1,0,1,0,1,0,1,0,1,1,1,1,1,1,1],
      [1,0,0,0,0,0,1,0,0,1,0,1,0,0,1,0,0,0,0,0,1],
      [1,0,1,1,1,0,1,0,1,0,1,0,1,0,1,0,1,1,1,0,1],
      [1,0,1,1,1,0,1,0,0,1,0,1,0,0,1,0,1,1,1,0,1],
      [1,0,1,1,1,0,1,0,1,0,1,0,1,0,1,0,1,1,1,0,1],
      [1,0,0,0,0,0,1,0,0,1,0,1,0,0,1,0,0,0,0,0,1],
      [1,1,1,1,1,1,1,0,1,0,1,0,1,0,1,1,1,1,1,1,1],
    ];

    for (int i = 0; i < pattern.length; i++) {
      for (int j = 0; j < pattern[i].length; j++) {
        if (pattern[i][j] == 1) {
          canvas.drawRect(
            Rect.fromLTWH(
              j * blockSize,
              i * blockSize,
              blockSize,
              blockSize,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
