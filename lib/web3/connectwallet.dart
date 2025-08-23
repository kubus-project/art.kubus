import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/web3provider.dart';
import '../providers/wallet_provider.dart';
import '../onboarding/wallet_creation_screen.dart';

class ConnectWallet extends StatefulWidget {
  const ConnectWallet({super.key});

  @override
  State<ConnectWallet> createState() => _ConnectWalletState();
}

class _ConnectWalletState extends State<ConnectWallet> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  bool _isLoading = false;
  String _connectionStatus = '';
  int _currentStep = 0; // 0: Choose option, 1: Connect existing, 2: Create new

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep > 0 
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => setState(() => _currentStep--),
            )
          : IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
        title: Text(
          _getStepTitle(),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Consumer<Web3Provider>(
        builder: (context, web3Provider, child) {
          if (web3Provider.isConnected) {
            return _buildConnectedView(web3Provider);
          } else {
            return _buildStepContent(web3Provider);
          }
        },
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Connect Wallet';
      case 1:
        return 'Connect Existing Wallet';
      case 2:
        return 'Create New Wallet';
      default:
        return 'Connect Wallet';
    }
  }

  Widget _buildStepContent(Web3Provider web3Provider) {
    switch (_currentStep) {
      case 0:
        return _buildChooseOptionView();
      case 1:
        return _buildConnectExistingView(web3Provider);
      case 2:
        return _buildCreateWalletView(web3Provider);
      default:
        return _buildChooseOptionView();
    }
  }

  Widget _buildChooseOptionView() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6C63FF), Color(0xFF4CAF50)],
                  ),
                  borderRadius: BorderRadius.circular(60),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 0,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 60,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome to Web3',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Choose how you\'d like to access the art.kubus ecosystem',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey[400],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              _buildOptionCard(
                'Connect Existing Wallet',
                'Use your existing Web3 wallet',
                Icons.link,
                const Color(0xFF6C63FF),
                () => setState(() => _currentStep = 1),
              ),
              const SizedBox(height: 16),
              _buildOptionCard(
                'Create New Wallet',
                'Set up a new wallet for beginners',
                Icons.add_circle_outline,
                const Color(0xFF4CAF50),
                () => setState(() => _currentStep = 2),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () => _showWeb3Guide(),
                child: Text(
                  'Learn more about Web3 wallets',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF6C63FF),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[800]!),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectExistingView(Web3Provider web3Provider) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isSmallScreen = constraints.maxWidth < 600;
          
          return SingleChildScrollView(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - (isSmallScreen ? 32 : 48),
              ),
              child: Column(
                children: [
                  SizedBox(height: isSmallScreen ? 20 : 40),
                  Container(
                    width: isSmallScreen ? 80 : 100,
                    height: isSmallScreen ? 80 : 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                      ),
                      borderRadius: BorderRadius.circular(isSmallScreen ? 40 : 50),
                    ),
                    child: Icon(
                      Icons.link,
                      color: Colors.white,
                      size: isSmallScreen ? 40 : 50,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 24 : 32),
                  Text(
                    'Connect Your Wallet',
                    style: GoogleFonts.inter(
                      fontSize: isSmallScreen ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  Text(
                    'Connect your preferred wallet to access the art.kubus ecosystem',
                    style: GoogleFonts.inter(
                      fontSize: isSmallScreen ? 14 : 16,
                      color: Colors.grey[400],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isSmallScreen ? 32 : 48),
                  if (_isLoading) ...[
                    Center(
                      child: Container(
                        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: isSmallScreen ? 40 : 50,
                              height: isSmallScreen ? 40 : 50,
                              child: CircularProgressIndicator(
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                                strokeWidth: isSmallScreen ? 3 : 4,
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 16 : 20),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: isSmallScreen ? 280 : 400,
                              ),
                              child: Text(
                                _connectionStatus,
                                style: GoogleFonts.inter(
                                  fontSize: isSmallScreen ? 13 : 14,
                                  color: Colors.grey[400],
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Column(
                      children: [
                        _buildWalletOption(
                          'WalletConnect',
                          'Connect 300+ wallets securely',
                          Icons.qr_code_scanner,
                          const Color(0xFF3B99FC),
                          () => _connectWallet(web3Provider, 'WalletConnect'),
                          isRecommended: true,
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        _buildWalletOption(
                          'art.kubus Wallet',
                          'Built-in wallet for seamless experience',
                          Icons.account_balance_wallet,
                          const Color(0xFF8B5CF6),
                          () => _connectWallet(web3Provider, 'ArtKubus'),
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        _buildWalletOption(
                          'Solana Wallets',
                          'Phantom, Solflare & more',
                          Icons.flash_on,
                          const Color(0xFF9945FF),
                          () => _connectWallet(web3Provider, 'Solana'),
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        _buildWalletOption(
                          'Mobile Wallets',
                          'Trust Wallet, Coinbase & others',
                          Icons.phone_android,
                          const Color(0xFF00D4AA),
                          () => _connectWallet(web3Provider, 'Mobile'),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: isSmallScreen ? 24 : 32),
                  Text(
                    'New to crypto wallets?',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(() => _currentStep = 2),
                    child: Text(
                      'Create your first wallet here →',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF8B5CF6),
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWalletOption(
    String name,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isRecommended = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRecommended ? color : Colors.grey[800]!,
            width: isRecommended ? 2 : 1,
          ),
          boxShadow: isRecommended ? [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Stack(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                  size: 16,
                ),
              ],
            ),
            if (isRecommended)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Recommended',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateWalletView(Web3Provider web3Provider) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isSmallScreen = constraints.maxWidth < 600;
          
          return SingleChildScrollView(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - (isSmallScreen ? 32 : 48),
              ),
              child: Column(
                children: [
                  SizedBox(height: isSmallScreen ? 20 : 40),
                  Container(
                    width: isSmallScreen ? 80 : 100,
                    height: isSmallScreen ? 80 : 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                      ),
                      borderRadius: BorderRadius.circular(isSmallScreen ? 40 : 50),
                    ),
                    child: Icon(
                      Icons.add_circle_outline,
                      color: Colors.white,
                      size: isSmallScreen ? 40 : 50,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 24 : 32),
                  Text(
                    'Create Your Wallet',
                    style: GoogleFonts.inter(
                      fontSize: isSmallScreen ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  Text(
                    'Choose how you\'d like to create your secure wallet for art.kubus',
                    style: GoogleFonts.inter(
                      fontSize: isSmallScreen ? 14 : 16,
                      color: Colors.grey[400],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isSmallScreen ? 32 : 48),
                  
                  // Wallet Creation Options
                  _buildWalletCreationCard(
                    'Generate Mnemonic Wallet',
                    'Create a new wallet with 12-word recovery phrase',
                    Icons.key,
                    const Color(0xFF8B5CF6),
                    () => _navigateToMnemonicCreation(),
                    isRecommended: true,
                    isSmallScreen: isSmallScreen,
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  _buildWalletCreationCard(
                    'Import Existing Wallet',
                    'Restore wallet using your seed phrase',
                    Icons.import_export,
                    const Color(0xFF4CAF50),
                    () => _navigateToWalletImport(),
                    isSmallScreen: isSmallScreen,
                  ),
                  
                  SizedBox(height: isSmallScreen ? 32 : 48),
                  
                  // Security Notice
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.security,
                              color: const Color(0xFF4CAF50),
                              size: isSmallScreen ? 20 : 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Security First',
                                style: GoogleFonts.inter(
                                  fontSize: isSmallScreen ? 16 : 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 8 : 12),
                        Text(
                          'Your wallet is completely secure and private. We never store your recovery phrase or private keys.',
                          style: GoogleFonts.inter(
                            fontSize: isSmallScreen ? 12 : 14,
                            color: Colors.grey[400],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: isSmallScreen ? 24 : 32),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _currentStep = 1),
                        child: Text(
                          'Already have a wallet? ',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _currentStep = 1),
                        child: Text(
                          'Connect it here',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF8B5CF6),
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWalletCreationCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isRecommended = false,
    bool isSmallScreen = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRecommended ? color : Colors.grey[800]!,
            width: isRecommended ? 2 : 1,
          ),
          boxShadow: isRecommended ? [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Stack(
          children: [
            Row(
              children: [
                Container(
                  width: isSmallScreen ? 44 : 48,
                  height: isSmallScreen ? 44 : 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(isSmallScreen ? 22 : 24),
                  ),
                  child: Icon(icon, color: color, size: isSmallScreen ? 20 : 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: GoogleFonts.inter(
                          fontSize: isSmallScreen ? 12 : 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: color,
                  size: isSmallScreen ? 16 : 20,
                ),
              ],
            ),
            if (isRecommended)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 6 : 8, 
                    vertical: isSmallScreen ? 2 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Recommended',
                    style: GoogleFonts.inter(
                      fontSize: isSmallScreen ? 8 : 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _navigateToMnemonicCreation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WalletCreationScreen(isImporting: false),
      ),
    );
  }

  void _navigateToWalletImport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WalletCreationScreen(isImporting: true),
      ),
    );
  }

  Widget _buildConnectedView(Web3Provider web3Provider) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF00D4AA), Color(0xFF4CAF50)],
              ),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 60,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Wallet Connected!',
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Your wallet is now connected to art.kubus. You can now explore AR art, trade NFTs, and participate in the ecosystem.',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey[400],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Continue to App',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              web3Provider.disconnectWallet();
              Provider.of<WalletProvider>(context, listen: false).disconnectWallet();
            },
            child: Text(
              'Disconnect Wallet',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _connectWallet(Web3Provider web3Provider, String walletType) async {
    setState(() {
      _isLoading = true;
      _connectionStatus = 'Connecting to $walletType...';
    });

    try {
      // final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      
      if (walletType == 'Solana') {
        // Handle Solana wallet connection
        await Future.delayed(const Duration(milliseconds: 500));
        setState(() => _connectionStatus = 'Establishing secure connection...');
        
        await Future.delayed(const Duration(milliseconds: 800));
        setState(() => _connectionStatus = 'Connecting to Solana network...');
        
        await Future.delayed(const Duration(milliseconds: 700));
        setState(() => _connectionStatus = 'Initializing wallet...');
        
        // Show options for Solana wallets
        final result = await _showSolanaWalletOptions();
        
        setState(() {
          _isLoading = false;
          _connectionStatus = '';
        });
        
        // The individual wallet methods handle the actual connection
        // and navigation, so we don't need to do anything else here
        if (result == null) {
          // User cancelled - nothing to do
        }
      } else {
        // Handle other wallet types with existing logic
        await Future.delayed(const Duration(milliseconds: 500));
        setState(() => _connectionStatus = 'Establishing secure connection...');
        
        await Future.delayed(const Duration(milliseconds: 800));
        setState(() => _connectionStatus = 'Verifying wallet credentials...');
        
        await Future.delayed(const Duration(milliseconds: 700));
        setState(() => _connectionStatus = 'Finalizing connection...');
        
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Actually connect the wallet through provider
        await web3Provider.connectWallet();
        
        setState(() {
          _isLoading = false;
          _connectionStatus = '';
        });
        
        if (web3Provider.isConnected) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$walletType connected successfully!'),
              backgroundColor: const Color(0xFF00D4AA),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _connectionStatus = '';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect $walletType: ${e.toString()}'),
          backgroundColor: const Color(0xFFFF6B6B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<String?> _showSolanaWalletOptions() async {
    return await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = MediaQuery.of(context).size.height;
          final screenWidth = MediaQuery.of(context).size.width;
          final isMobile = screenWidth < 600;
          
          // Calculate responsive height - ensure we don't exceed safe area
          final maxHeight = screenHeight * (isMobile ? 0.85 : 0.7);
          final minHeight = isMobile ? 400.0 : 500.0;
          final calculatedHeight = maxHeight < minHeight ? maxHeight : minHeight.clamp(minHeight, maxHeight);
          
          return Container(
            constraints: BoxConstraints(
              maxHeight: calculatedHeight,
              minHeight: isMobile ? 350.0 : 400.0,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(top: isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 20 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: isMobile ? 8 : 16),
                        Text(
                          'Connect Solana Wallet',
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isMobile ? 6 : 8),
                        Text(
                          'Choose your preferred Solana wallet option',
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 13 : 14,
                            color: Colors.grey[400],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isMobile ? 24 : 32),
                        _buildSolanaWalletOption(
                          'Create New Solana Wallet',
                          'Generate a new wallet with mnemonic phrase',
                          Icons.add_circle_outline,
                          const Color(0xFF9945FF),
                          () async {
                            Navigator.pop(context, 'create');
                            await _createNewSolanaWallet();
                          },
                          isMobile: isMobile,
                        ),
                        SizedBox(height: isMobile ? 12 : 16),
                        _buildSolanaWalletOption(
                          'Import Existing Wallet',
                          'Import using mnemonic phrase',
                          Icons.file_download,
                          const Color(0xFF14F195),
                          () async {
                            Navigator.pop(context, 'import');
                            await _importSolanaWallet();
                          },
                          isMobile: isMobile,
                        ),
                        SizedBox(height: isMobile ? 12 : 16),
                        _buildSolanaWalletOption(
                          'Connect with Address',
                          'Watch-only mode with public address',
                          Icons.visibility,
                          const Color(0xFFFFB74D),
                          () async {
                            Navigator.pop(context, 'connect');
                            await _connectSolanaAddress();
                          },
                          isMobile: isMobile,
                        ),
                        SizedBox(height: isMobile ? 16 : 24),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontSize: isMobile ? 14 : 16,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                        // Add bottom padding for mobile safe area
                        if (isMobile) SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSolanaWalletOption(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isMobile = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 8 : 12,
        ),
        leading: Container(
          width: isMobile ? 40 : 48,
          height: isMobile ? 40 : 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
          ),
          child: Icon(icon, color: color, size: isMobile ? 20 : 24),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: isMobile ? 11 : 13,
            color: Colors.grey[400],
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey[600],
          size: isMobile ? 14 : 16,
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _createNewSolanaWallet() async {
    if (!mounted) return;
    
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final web3Provider = Provider.of<Web3Provider>(context, listen: false);
    
    try {
      final result = await walletProvider.createWallet();
      
      // Show the mnemonic to the user
      if (mounted) {
        await _showMnemonicDialog(result['mnemonic']!, result['address']!);
        
        // Connect the wallet in Web3Provider as well
        await web3Provider.connectWallet();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Wallet created and connected successfully!'),
              backgroundColor: const Color(0xFF00D4AA),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        
        // Navigate back to indicate successful connection
        if (mounted) {
          Navigator.pop(context);
        }
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create wallet: ${e.toString()}'),
            backgroundColor: const Color(0xFFFF6B6B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _importSolanaWallet() async {
    final controller = TextEditingController();
    
    final mnemonic = await showDialog<String>(
      context: context,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isMobile = screenWidth < 600;
          
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 40,
              vertical: isMobile ? 24 : 40,
            ),
            title: Text(
              'Import Wallet',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: isMobile ? 18 : 20,
              ),
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 400,
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Enter your 12-word mnemonic phrase:',
                      style: GoogleFonts.inter(
                        color: Colors.grey[400],
                        fontSize: isMobile ? 13 : 14,
                      ),
                    ),
                    SizedBox(height: isMobile ? 12 : 16),
                    TextField(
                      controller: controller,
                      maxLines: isMobile ? 4 : 3,
                      decoration: InputDecoration(
                        hintText: 'word1 word2 word3 ...',
                        hintStyle: GoogleFonts.inter(
                          color: Colors.grey[600],
                          fontSize: isMobile ? 13 : 14,
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF9945FF)),
                        ),
                        contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
                      ),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: isMobile ? 13 : 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: isMobile ? 13 : 14,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9945FF),
                ),
                child: Text(
                  'Import',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: isMobile ? 13 : 14,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    
    if (mnemonic != null && mnemonic.isNotEmpty) {
      if (!mounted) return;
      
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final web3Provider = Provider.of<Web3Provider>(context, listen: false);
      
      try {
        final address = await walletProvider.importWalletFromMnemonic(mnemonic);
        
        // Connect the wallet in Web3Provider as well
        await web3Provider.connectWallet();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Wallet imported successfully!\nAddress: ${address.substring(0, 8)}...'),
              backgroundColor: const Color(0xFF00D4AA),
              behavior: SnackBarBehavior.floating,
            ),
          );
          
          // Navigate back to indicate successful connection
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to import wallet: ${e.toString()}'),
              backgroundColor: const Color(0xFFFF6B6B),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _connectSolanaAddress() async {
    final controller = TextEditingController();
    
    final address = await showDialog<String>(
      context: context,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isMobile = screenWidth < 600;
          
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 40,
              vertical: isMobile ? 24 : 40,
            ),
            title: Text(
              'Connect with Address',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: isMobile ? 18 : 20,
              ),
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 400,
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Enter Solana wallet address (watch-only):',
                      style: GoogleFonts.inter(
                        color: Colors.grey[400],
                        fontSize: isMobile ? 13 : 14,
                      ),
                    ),
                    SizedBox(height: isMobile ? 12 : 16),
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'Enter Solana address...',
                        hintStyle: GoogleFonts.inter(
                          color: Colors.grey[600],
                          fontSize: isMobile ? 13 : 14,
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF9945FF)),
                        ),
                        contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
                      ),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: isMobile ? 13 : 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: isMobile ? 13 : 14,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9945FF),
                ),
                child: Text(
                  'Connect',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: isMobile ? 13 : 14,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    
    if (address != null && address.isNotEmpty) {
      if (!mounted) return;
      
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final web3Provider = Provider.of<Web3Provider>(context, listen: false);
      
      try {
        await walletProvider.connectWalletWithAddress(address);
        
        // Connect the wallet in Web3Provider as well
        await web3Provider.connectWallet();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to wallet successfully!\nAddress: ${address.substring(0, 8)}...'),
              backgroundColor: const Color(0xFF00D4AA),
              behavior: SnackBarBehavior.floating,
            ),
          );
          
          // Navigate back to indicate successful connection
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to connect wallet: ${e.toString()}'),
              backgroundColor: const Color(0xFFFF6B6B),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _showMnemonicDialog(String mnemonic, String address) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = MediaQuery.of(context).size.width;
          final screenHeight = MediaQuery.of(context).size.height;
          final isMobile = screenWidth < 600;
          
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 40,
              vertical: isMobile ? 24 : 40,
            ),
            title: Text(
              'Wallet Created Successfully!',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 18 : 20,
              ),
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 500,
                maxHeight: screenHeight * (isMobile ? 0.7 : 0.6),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your new Solana wallet has been created. Please save your mnemonic phrase securely:',
                      style: GoogleFonts.inter(
                        color: Colors.grey[400],
                        fontSize: isMobile ? 13 : 14,
                      ),
                    ),
                    SizedBox(height: isMobile ? 12 : 16),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: SelectableText(
                        mnemonic,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                    SizedBox(height: isMobile ? 12 : 16),
                    Text(
                      'Address: ${address.substring(0, isMobile ? 6 : 8)}...${address.substring(address.length - (isMobile ? 6 : 8))}',
                      style: GoogleFonts.inter(
                        color: Colors.grey[400],
                        fontSize: isMobile ? 11 : 12,
                      ),
                    ),
                    SizedBox(height: isMobile ? 12 : 16),
                    Container(
                      padding: EdgeInsets.all(isMobile ? 10 : 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning,
                            color: const Color(0xFF856404),
                            size: isMobile ? 18 : 20,
                          ),
                          SizedBox(width: isMobile ? 6 : 8),
                          Expanded(
                            child: Text(
                              'Keep this mnemonic phrase safe! It\'s the only way to recover your wallet.',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF856404),
                                fontSize: isMobile ? 11 : 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Remove the snackbar since the calling method will handle success feedback
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9945FF),
                ),
                child: Text(
                  'I\'ve Saved It',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: isMobile ? 13 : 14,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showWeb3Guide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'What is a Web3 Wallet?',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A Web3 wallet is your gateway to the decentralized internet:',
                style: GoogleFonts.inter(color: Colors.grey[400]),
              ),
              const SizedBox(height: 16),
              _buildFeaturePoint('🔐', 'Secure', 'Your keys, your crypto'),
              _buildFeaturePoint('🎨', 'NFTs', 'Store and trade digital art'),
              _buildFeaturePoint('🗳️', 'Governance', 'Vote on platform decisions'),
              _buildFeaturePoint('💰', 'DeFi', 'Access decentralized finance'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
            ),
            child: Text(
              'Got it!',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePoint(String emoji, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
