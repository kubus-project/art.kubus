import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/web3provider.dart';

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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF3F51B5)],
                ),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.link,
                color: Colors.white,
                size: 50,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Connect Your Existing Wallet',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Choose your preferred wallet provider to connect securely',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey[400],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            if (_isLoading) ...[
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
              ),
              const SizedBox(height: 16),
              Text(
                _connectionStatus,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              Expanded(
                child: Column(
                  children: [
                    _buildWalletOption(
                      'MetaMask',
                      'Most popular multi-chain wallet',
                      Icons.account_balance_wallet,
                      const Color(0xFFFF6B35),
                      () => _connectWallet(web3Provider, 'MetaMask'),
                      isRecommended: true,
                    ),
                    const SizedBox(height: 16),
                    _buildWalletOption(
                      'WalletConnect',
                      'Connect with 100+ supported wallets',
                      Icons.qr_code_scanner,
                      const Color(0xFF3B99FC),
                      () => _connectWallet(web3Provider, 'WalletConnect'),
                    ),
                    const SizedBox(height: 16),
                    _buildWalletOption(
                      'Coinbase Wallet',
                      'Simple and secure by Coinbase',
                      Icons.currency_bitcoin,
                      const Color(0xFF0052FF),
                      () => _connectWallet(web3Provider, 'Coinbase'),
                    ),
                    const SizedBox(height: 16),
                    _buildWalletOption(
                      'Phantom',
                      'Solana-focused wallet for NFTs',
                      Icons.flash_on,
                      const Color(0xFF9945FF),
                      () => _connectWallet(web3Provider, 'Phantom'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                ),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.add_circle_outline,
                color: Colors.white,
                size: 50,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Create Your First Wallet',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'New to Web3? We\'ll help you create your first wallet safely and securely.',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey[400],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            _buildCreateWalletStep(
              1,
              'Choose Wallet Type',
              'Select the best wallet for your needs',
              Icons.account_balance_wallet,
              true,
            ),
            const SizedBox(height: 20),
            _buildCreateWalletStep(
              2,
              'Secure Your Wallet',
              'Save your recovery phrase safely',
              Icons.security,
              false,
            ),
            const SizedBox(height: 20),
            _buildCreateWalletStep(
              3,
              'Start Exploring',
              'Begin your Web3 journey with art.kubus',
              Icons.explore,
              false,
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _showWalletCreationOptions(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
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
                      'Create Wallet',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => setState(() => _currentStep = 1),
              child: Text(
                'Already have a wallet? Go back to connect it',
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
    );
  }

  Widget _buildCreateWalletStep(
    int stepNumber,
    String title,
    String description,
    IconData icon,
    bool isActive,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive 
          ? const Color(0xFF4CAF50).withOpacity(0.1)
          : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive 
            ? const Color(0xFF4CAF50)
            : Colors.grey[800]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive 
                ? const Color(0xFF4CAF50)
                : Colors.grey[700],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: isActive
                ? Icon(icon, color: Colors.white, size: 20)
                : Text(
                    stepNumber.toString(),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            ),
          ),
          const SizedBox(width: 16),
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
        ],
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
            onPressed: () => web3Provider.disconnectWallet(),
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
      // Simulate realistic wallet connection process
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

  void _showWalletCreationOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Choose Your Wallet Type',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select the best wallet option for your needs',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey[400],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Column(
                  children: [
                    _buildWalletCreationOption(
                      'MetaMask',
                      'Most popular choice for beginners',
                      'Create account with MetaMask',
                      const Color(0xFFFF6B35),
                      () => _createWalletWithProvider('MetaMask'),
                    ),
                    const SizedBox(height: 16),
                    _buildWalletCreationOption(
                      'Coinbase Wallet',
                      'Simple and user-friendly',
                      'Easy setup with Coinbase',
                      const Color(0xFF0052FF),
                      () => _createWalletWithProvider('Coinbase'),
                    ),
                    const SizedBox(height: 16),
                    _buildWalletCreationOption(
                      'Trust Wallet',
                      'Mobile-first experience',
                      'Download Trust Wallet app',
                      const Color(0xFF3375BB),
                      () => _createWalletWithProvider('Trust'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletCreationOption(
    String name,
    String description,
    String actionText,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[700]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: color,
                    size: 24,
                  ),
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  actionText,
                  style: GoogleFonts.inter(
                    fontSize: 14,
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

  void _createWalletWithProvider(String provider) {
    Navigator.pop(context); // Close bottom sheet
    
    // Show creation guidance
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Create $provider Wallet',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To create your $provider wallet:',
              style: GoogleFonts.inter(color: Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            _buildGuideStep('1', 'Download the $provider app or browser extension'),
            const SizedBox(height: 8),
            _buildGuideStep('2', 'Create a new wallet account'),
            const SizedBox(height: 8),
            _buildGuideStep('3', 'Securely save your recovery phrase'),
            const SizedBox(height: 8),
            _buildGuideStep('4', 'Return here to connect your new wallet'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.grey[400]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _currentStep = 1); // Go to connect existing
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
            ),
            child: Text(
              'Continue',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF),
            borderRadius: BorderRadius.circular(10),
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
              color: Colors.grey[300],
            ),
          ),
        ),
      ],
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
