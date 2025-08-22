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
        title: Text(
          'Connect Wallet',
          style: GoogleFonts.inter(
            fontSize: 24,
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
            return _buildConnectView(web3Provider);
          }
        },
      ),
    );
  }

  Widget _buildConnectView(Web3Provider web3Provider) {
    return ScaleTransition(
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
              'Connect Your Wallet',
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Connect your Web3 wallet to access the AR art ecosystem, trade NFTs, and participate in governance.',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey[400],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            Column(
              children: [
                _buildWalletOption(
                  'MetaMask',
                  'The most popular Web3 wallet',
                  Icons.account_balance_wallet,
                  const Color(0xFFFF6B35),
                  () => _connectWallet(web3Provider, 'MetaMask'),
                ),
                const SizedBox(height: 16),
                _buildWalletOption(
                  'WalletConnect',
                  'Connect with 100+ wallets',
                  Icons.qr_code_scanner,
                  const Color(0xFF3B99FC),
                  () => _connectWallet(web3Provider, 'WalletConnect'),
                ),
                const SizedBox(height: 16),
                _buildWalletOption(
                  'Coinbase Wallet',
                  'Simple and secure',
                  Icons.currency_bitcoin,
                  const Color(0xFF0052FF),
                  () => _connectWallet(web3Provider, 'Coinbase'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'New to Web3? Learn more about wallets',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF6C63FF),
                decoration: TextDecoration.underline,
              ),
            ),
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
        ),
        child: Row(
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
    try {
      // Show loading state
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
          ),
        ),
      );

      // Simulate wallet connection
      await Future.delayed(const Duration(seconds: 2));
      await web3Provider.connectWallet();
      
      Navigator.of(context).pop(); // Close loading dialog
      
      if (web3Provider.isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$walletType connected successfully!'),
            backgroundColor: const Color(0xFF00D4AA),
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect $walletType'),
          backgroundColor: const Color(0xFFFF6B6B),
        ),
      );
    }
  }
}
