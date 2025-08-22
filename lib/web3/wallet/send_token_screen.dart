import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/themeprovider.dart';

class SendTokenScreen extends StatefulWidget {
  const SendTokenScreen({super.key});

  @override
  State<SendTokenScreen> createState() => _SendTokenScreenState();
}

class _SendTokenScreenState extends State<SendTokenScreen> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  
  String _selectedToken = 'KUB8';
  bool _isAdvancedMode = false;
  double _gasPrice = 5.0;
  int _gasLimit = 21000;
  
  final List<Map<String, dynamic>> _recentContacts = [
    {'name': 'Alice Cooper', 'address': '0x742d35Cc6634C0532925a3b8d3e3d3456789...', 'avatar': '🎨'},
    {'name': 'Bob Smith', 'address': '0x123e35Cc6634C0532925a3b8d3e3d3456789...', 'avatar': '🖼️'},
    {'name': 'Gallery DAO', 'address': '0x456d35Cc6634C0532925a3b8d3e3d3456789...', 'avatar': '🏛️'},
    {'name': 'ArtistHub', 'address': '0x789f35Cc6634C0532925a3b8d3e3d3456789...', 'avatar': '🎭'},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _recipientController.dispose();
    _amountController.dispose();
    _memoController.dispose();
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
            'Send Tokens',
            style: GoogleFonts.inter(
              fontSize: 24,
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
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTokenSelector(),
              const SizedBox(height: 24),
              _buildRecentContacts(),
              const SizedBox(height: 24),
              _buildRecipientField(),
              const SizedBox(height: 24),
              _buildAmountField(),
              const SizedBox(height: 24),
              _buildMemoField(),
              const SizedBox(height: 24),
              _buildAdvancedOptions(),
              const SizedBox(height: 24),
              _buildTransactionSummary(),
              const SizedBox(height: 32),
              _buildSendButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTokenSelector() {
    final tokens = [
      {'symbol': 'KUB8', 'name': 'art.kubus Token', 'balance': '1,250.00', 'icon': '🎨'},
      {'symbol': 'SOL', 'name': 'Solana', 'balance': '12.5', 'icon': '☀️'},
      {'symbol': 'ETH', 'name': 'Ethereum', 'balance': '0.85', 'icon': '💎'},
      {'symbol': 'USDC', 'name': 'USD Coin', 'balance': '500.00', 'icon': '💵'},
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
            final cardWidth = isSmallScreen ? 100.0 : isMediumScreen ? 110.0 : 130.0;
            final cardSpacing = isSmallScreen ? 8.0 : 12.0;
            final totalCardsWidth = (tokens.length * cardWidth) + ((tokens.length - 1) * cardSpacing);
            
            if (totalCardsWidth <= screenWidth) {
              // Cards fit in available width - use centered layout
              return Center(
                child: Wrap(
                  spacing: cardSpacing,
                  children: tokens.map((token) {
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
                              token['balance']!,
                              style: GoogleFonts.inter(
                                fontSize: isSmallScreen ? 10 : 12,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              maxLines: 1,
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
                  children: tokens.asMap().entries.map((entry) {
                    final index = entry.key;
                    final token = entry.value;
                    final isSelected = _selectedToken == token['symbol'];
                    
                    return GestureDetector(
                      onTap: () => setState(() => _selectedToken = token['symbol']!),
                      child: Container(
                        width: cardWidth,
                        margin: EdgeInsets.only(
                          right: index < tokens.length - 1 ? cardSpacing : 0,
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
                              token['balance']!,
                              style: GoogleFonts.inter(
                                fontSize: isSmallScreen ? 10 : 12,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              maxLines: 1,
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

  Widget _buildRecentContacts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Contacts',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _recentContacts.length,
            itemBuilder: (context, index) {
              final contact = _recentContacts[index];
              
              return GestureDetector(
                onTap: () => _selectContact(contact),
                child: Container(
                  width: 70,
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Provider.of<ThemeProvider>(context).accentColor,
                              Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Center(
                          child: Text(
                            contact['avatar'],
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        contact['name'].split(' ')[0],
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecipientField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recipient Address',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _recipientController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter wallet address or ENS name',
            hintStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[800]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[800]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Provider.of<ThemeProvider>(context).accentColor),
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.grey),
                  onPressed: _scanQRCode,
                ),
                IconButton(
                  icon: const Icon(Icons.contacts, color: Colors.grey),
                  onPressed: _showContactList,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Amount',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _setMaxAmount,
              child: Text(
                'MAX',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Provider.of<ThemeProvider>(context).accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  Text(
                    _selectedToken,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Provider.of<ThemeProvider>(context).accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '≈ \$${_calculateUSDValue()}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Balance: ${_getTokenBalance()}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemoField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Memo (Optional)',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _memoController,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add a note for this transaction...',
            hintStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[800]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[800]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Provider.of<ThemeProvider>(context).accentColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Advanced Options',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Switch(
              value: _isAdvancedMode,
              onChanged: (value) => setState(() => _isAdvancedMode = value),
              activeColor: Provider.of<ThemeProvider>(context).accentColor,
            ),
          ],
        ),
        if (_isAdvancedMode) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gas Price (GWEI)',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          Slider(
                            value: _gasPrice,
                            min: 1.0,
                            max: 100.0,
                            divisions: 99,
                            activeColor: Provider.of<ThemeProvider>(context).accentColor,
                            onChanged: (value) => setState(() => _gasPrice = value),
                          ),
                          Text(
                            '${_gasPrice.toStringAsFixed(1)} GWEI',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gas Limit',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          TextFormField(
                            initialValue: _gasLimit.toString(),
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onChanged: (value) => _gasLimit = int.tryParse(value) ?? 21000,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTransactionSummary() {
    final networkFee = _calculateNetworkFee();
    final feeCurrency = _getNetworkFeeCurrency();
    final totalAmount = _calculateTotalAmount();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaction Summary',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Amount', '${_amountController.text} $_selectedToken'),
          _buildSummaryRow('Network Fee', '$networkFee $feeCurrency'),
          _buildSummaryRow('Total', '$totalAmount $_selectedToken', isTotal: true),
          if (feeCurrency != _selectedToken)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Note: Network fee is paid in $feeCurrency',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.yellow.withOpacity(0.8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isTotal ? Provider.of<ThemeProvider>(context).accentColor : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isFormValid() ? _sendTransaction : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: Colors.grey[600],
        ),
        child: Text(
          'Send Transaction',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _selectContact(Map<String, dynamic> contact) {
    _recipientController.text = contact['address'];
  }

  void _scanQRCode() {
    // Simulate QR code scanning
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('QR Scanner', style: GoogleFonts.inter(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.qr_code_scanner, size: 80, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Point camera at QR code',
              style: GoogleFonts.inter(color: Colors.grey[400]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showContactList() {
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
              'Select Contact',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ..._recentContacts.map((contact) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
                child: Text(contact['avatar']),
              ),
              title: Text(
                contact['name'],
                style: GoogleFonts.inter(color: Colors.white),
              ),
              subtitle: Text(
                contact['address'],
                style: GoogleFonts.inter(color: Colors.grey[400]),
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                _selectContact(contact);
                Navigator.pop(context);
              },
            )).toList(),
          ],
        ),
      ),
    );
  }

  void _setMaxAmount() {
    final balance = _getTokenBalance();
    _amountController.text = balance;
  }

  String _getTokenBalance() {
    switch (_selectedToken) {
      case 'KUB8': return '1,250.00';
      case 'SOL': return '12.5';
      case 'ETH': return '0.85';
      case 'USDC': return '500.00';
      default: return '0.00';
    }
  }

  String _calculateUSDValue() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final rate = {'KUB8': 0.20, 'SOL': 150.0, 'ETH': 2500.0, 'USDC': 1.0}[_selectedToken] ?? 0.0;
    return (amount * rate).toStringAsFixed(2);
  }

  String _calculateNetworkFee() {
    // Define network fees for different tokens
    final networkFees = {
      'KUB8': 0.0001, // KUB8 fee
      'SOL': (_gasPrice * _gasLimit / 1e9), // SOL fee (original calculation)
      'ETH': 0.005, // ETH fee
      'USDC': 0.0001, // USDC fee (usually same as base chain)
    };
    
    final fee = networkFees[_selectedToken] ?? 0.0;
    return fee.toStringAsFixed(6);
  }

  String _getNetworkFeeCurrency() {
    // Return the currency symbol for network fees
    final feeCurrencies = {
      'KUB8': 'KUB8',
      'SOL': 'SOL',
      'ETH': 'ETH',
      'USDC': 'SOL', // USDC usually pays fees in the base chain currency
    };
    
    return feeCurrencies[_selectedToken] ?? _selectedToken;
  }

  String _calculateTotalAmount() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final networkFee = double.tryParse(_calculateNetworkFee()) ?? 0.0;
    
    // If network fee is in the same currency as the selected token, add it to the total
    final feeCurrency = _getNetworkFeeCurrency();
    if (feeCurrency == _selectedToken) {
      return (amount + networkFee).toStringAsFixed(6);
    } else {
      // If fee is in different currency, just return the amount
      return amount.toStringAsFixed(6);
    }
  }

  bool _isFormValid() {
    return _recipientController.text.isNotEmpty &&
           _amountController.text.isNotEmpty &&
           double.tryParse(_amountController.text) != null &&
           double.parse(_amountController.text) > 0;
  }

  void _sendTransaction() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Confirm Transaction', style: GoogleFonts.inter(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send ${_amountController.text} $_selectedToken to:', 
                 style: GoogleFonts.inter(color: Colors.grey[400])),
            const SizedBox(height: 8),
            Text(_recipientController.text, 
                 style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Text('Network fee: ${_calculateNetworkFee()} ${_getNetworkFeeCurrency()}', 
                 style: GoogleFonts.inter(color: Colors.grey[400])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _processSend();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _processSend() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Simulate transaction processing
    await Future.delayed(const Duration(seconds: 3));

    Navigator.pop(context); // Close loading
    Navigator.pop(context); // Close send screen

    // Show success
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transaction sent successfully!'),
        backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
      ),
    );
  }
}
