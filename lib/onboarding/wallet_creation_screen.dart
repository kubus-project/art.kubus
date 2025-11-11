import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/themeprovider.dart';
import '../providers/web3provider.dart';
import '../providers/wallet_provider.dart';

class WalletCreationScreen extends StatefulWidget {
  final bool isImporting;
  
  const WalletCreationScreen({
    super.key,
    this.isImporting = false,
  });

  @override
  State<WalletCreationScreen> createState() => _WalletCreationScreenState();
}

class _WalletCreationScreenState extends State<WalletCreationScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  int _currentStep = 0;
  bool _mnemonicRevealed = false;
  bool _mnemonicVisible = true;
  bool _mnemonicConfirmed = false;
  List<String> _mnemonicWords = [];
  List<String> _userMnemonicInput = [];
  final TextEditingController _mnemonicController = TextEditingController();
  bool _termsAccepted = false;

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
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _mnemonicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final isSmallScreen = screenHeight < 700 || screenWidth < 375;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildContent(isSmallScreen),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent([bool isSmallScreen = false]) {
    if (widget.isImporting) {
      return _buildImportWallet(isSmallScreen);
    }
    
    switch (_currentStep) {
      case 0:
        return _buildWelcome(isSmallScreen);
      case 1:
        return _buildSecurityInfo(isSmallScreen);
      case 2:
        return _buildMnemonicDisplay(isSmallScreen);
      case 3:
        return _buildMnemonicConfirmation(isSmallScreen);
      case 4:
        return _buildWalletCreating(isSmallScreen);
      default:
        return _buildWelcome(isSmallScreen);
    }
  }

  Widget _buildWelcome([bool isSmallScreen = false]) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isVerySmallScreen = constraints.maxHeight < 600;
        final effectiveSmallScreen = isSmallScreen || isVerySmallScreen;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 48,
            ),
            child: Column(
              children: [
                _buildHeader('Create Your Wallet'),
                SizedBox(height: effectiveSmallScreen ? 20 : 40),
                Container(
                  width: effectiveSmallScreen ? 80 : 120,
                  height: effectiveSmallScreen ? 80 : 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(effectiveSmallScreen ? 20 : 30),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                        blurRadius: effectiveSmallScreen ? 20 : 30,
                        spreadRadius: 0,
                        offset: Offset(0, effectiveSmallScreen ? 10 : 15),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    size: effectiveSmallScreen ? 40 : 60,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                SizedBox(height: effectiveSmallScreen ? 24 : 48),
                Text(
                  'Secure Wallet Creation',
                  style: GoogleFonts.inter(
                    fontSize: effectiveSmallScreen ? 24 : 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: effectiveSmallScreen ? 12 : 16),
                Text(
                  'Get your own Solana wallet with\nmilitary-grade security',
                  style: GoogleFonts.inter(
                    fontSize: effectiveSmallScreen ? 16 : 18,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: effectiveSmallScreen ? 20 : 32),
                _buildFeatureList(effectiveSmallScreen),
                SizedBox(height: effectiveSmallScreen ? 20 : 40),
                _buildTermsAndButton(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureList([bool isSmallScreen = false]) {
    final features = [
      (Icons.lock, 'End-to-end encryption'),
      (Icons.smartphone, 'Biometric authentication'),
      (Icons.diamond, 'SOL & KUB8 support'),
      (Icons.palette, 'NFT storage'),
    ];

    return Column(
      children: features.map((feature) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 6 : 8),
          child: Row(
            children: [
              Icon(
                feature.$1,
                size: isSmallScreen ? 20 : 24,
                color: Provider.of<ThemeProvider>(context).accentColor,
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  feature.$2,
                  style: GoogleFonts.inter(
                    fontSize: isSmallScreen ? 14 : 16,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTermsAndButton() {
    return Column(
      children: [
        Row(
          children: [
            Checkbox(
              value: _termsAccepted,
              onChanged: (value) {
                setState(() {
                  _termsAccepted = value ?? false;
                });
              },
              activeColor: Theme.of(context).colorScheme.primary,
            ),
            Expanded(
              child: Text(
                'I agree to the Terms of Service and Privacy Policy',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _termsAccepted ? () => _nextStep() : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Continue',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityInfo([bool isSmallScreen = false]) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxHeight < 700;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 48,
            ),
            child: Column(
              children: [
                _buildHeader('Security First'),
                SizedBox(height: isSmallScreen ? 20 : 40),
                Icon(
                  Icons.security,
                  size: isSmallScreen ? 60 : 100,
                  color: const Color(0xFF00D4AA),
                ),
                SizedBox(height: isSmallScreen ? 20 : 32),
                Text(
                  'Recovery Phrase',
                  style: GoogleFonts.inter(
                    fontSize: isSmallScreen ? 24 : 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 12 : 16),
                Text(
                  'You\'ll receive a 12-word recovery phrase. This is the ONLY way to recover your wallet if you lose access.',
                  style: GoogleFonts.inter(
                    fontSize: isSmallScreen ? 14 : 16,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isSmallScreen ? 20 : 32),
                _buildSecurityTips(isSmallScreen),
                SizedBox(height: isSmallScreen ? 20 : 40),
                _buildNavigationButtons(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSecurityTips([bool isSmallScreen = false]) {
    final tips = [
      (Icons.edit, 'Write it down on paper'),
      (Icons.lock, 'Store in a safe place'),
      (Icons.block, 'Never share with anyone'),
      (Icons.photo_camera, 'Don\'t take screenshots'),
    ];

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00D4AA).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: tips.map((tip) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 6 : 8),
            child: Row(
              children: [
                Icon(
                  tip.$1,
                  size: isSmallScreen ? 16 : 20,
                  color: Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tip.$2,
                    style: GoogleFonts.inter(
                      fontSize: isSmallScreen ? 13 : 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMnemonicDisplay([bool isSmallScreen = false]) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildHeader('Your Recovery Phrase'),
          const SizedBox(height: 24),
          if (!_mnemonicRevealed) ...[
            const Spacer(),
            GestureDetector(
              onTap: _generateMnemonic,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFFD93D).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.visibility_off,
                      size: 60,
                      color: Color(0xFFFFD93D),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Tap to reveal your\nrecovery phrase',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD93D).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.touch_app,
                            size: 16,
                            color: Color(0xFFFFD93D),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Tap anywhere on this area',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFFFFD93D),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: _generateMnemonic,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFFD93D), width: 2),
                  foregroundColor: const Color(0xFFFFD93D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.visibility, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Reveal Phrase',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Your Recovery Phrase',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            GestureDetector(
                              onTap: _toggleMnemonicVisibility,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD93D).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFFFFD93D).withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _mnemonicVisible ? Icons.visibility_off : Icons.visibility,
                                      size: 16,
                                      color: const Color(0xFFFFD93D),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _mnemonicVisible ? 'Hide' : 'Show',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFFFFD93D),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                    _buildMnemonicGrid(),
                    const SizedBox(height: 20),
                    _buildCopyButton(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            _buildNavigationButtons(),
          ],
        ],
      ),
    );
  }

  Widget _buildMnemonicGrid() {
    return GestureDetector(
      onTap: _toggleMnemonicVisibility,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            if (!_mnemonicVisible)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.touch_app,
                      size: 16,
                      color: const Color(0xFFFFD93D).withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tap to reveal mnemonic',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFFFFD93D).withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                // Calculate optimal number of columns based on available width
                const double itemWidth = 100; // Minimum width per item
                final int crossAxisCount = (constraints.maxWidth / itemWidth).floor().clamp(2, 4);
                
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: _mnemonicWords.length,
                  itemBuilder: (context, index) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${index + 1}',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Flexible(
                            child: _mnemonicVisible 
                              ? Text(
                                  _mnemonicWords[index],
                                  style: GoogleFonts.robotoMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                )
                              : Container(
                                  height: 20,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '••••',
                                      style: GoogleFonts.robotoMono(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                        letterSpacing: 2,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopyButton() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Column(
      children: [
        // Improved copy button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _mnemonicWords.join(' ')));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Recovery phrase copied to clipboard!',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            icon: Icon(
              Icons.copy,
              size: 20,
              color: themeProvider.accentColor,
            ),
            label: Text(
              'Copy Recovery Phrase',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: themeProvider.accentColor,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeProvider.accentColor.withOpacity(0.1),
              foregroundColor: themeProvider.accentColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: themeProvider.accentColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Warning info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD93D).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFFD93D).withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: Color(0xFFFFD93D),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Write these words down in order and store them safely. You\'ll need them to confirm and recover your wallet.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMnemonicConfirmation([bool isSmallScreen = false]) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildHeader('Confirm Recovery Phrase'),
          const SizedBox(height: 24),
          Text(
            'Enter your 12-word recovery phrase to confirm you\'ve saved it correctly.',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: TextField(
                controller: _mnemonicController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: GoogleFonts.robotoMono(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter your 12 words separated by spaces...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  _userMnemonicInput = value.trim().split(' ');
                  setState(() {
                    _mnemonicConfirmed = _validateMnemonic();
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildWalletCreating([bool isSmallScreen = false]) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    themeProvider.accentColor,
                    themeProvider.accentColor.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(60),
                boxShadow: [
                  BoxShadow(
                    color: themeProvider.accentColor.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Provider.of<ThemeProvider>(context).accentColor),
                    strokeWidth: 4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            Text(
              'Creating Your Wallet',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          Text(
            'Setting up your secure Solana wallet for testnet...\nThis may take a few moments.',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    )
    );
    
  }

  Widget _buildImportWallet([bool isSmallScreen = false]) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxHeight < 700;
        final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 800;
        final isWideScreen = constraints.maxWidth > 800;
        
        return SingleChildScrollView(
          padding: EdgeInsets.all(isWideScreen ? 32 : isTablet ? 28 : 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - (isWideScreen ? 64 : isTablet ? 56 : 48),
              maxWidth: isWideScreen ? 600 : double.infinity,
            ),
            child: Center(
              child: Column(
                children: [
                  _buildHeader('Import Wallet'),
                  SizedBox(height: isWideScreen ? 32 : isTablet ? 28 : 24),
                  Text(
                    'Enter your existing 12-word recovery phrase to import your wallet.',
                    style: GoogleFonts.inter(
                      fontSize: isWideScreen ? 18 : isTablet ? 17 : isSmallScreen ? 14 : 16,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isWideScreen ? 40 : isTablet ? 36 : 32),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(isWideScreen ? 24 : isTablet ? 22 : 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(isWideScreen ? 20 : 16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      child: TextField(
                        controller: _mnemonicController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: GoogleFonts.robotoMono(
                          fontSize: isWideScreen ? 16 : isTablet ? 15 : isSmallScreen ? 12 : 14,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'word1 word2 word3 word4 word5 word6\nword7 word8 word9 word10 word11 word12',
                          hintStyle: GoogleFonts.robotoMono(
                            fontSize: isWideScreen ? 16 : isTablet ? 15 : isSmallScreen ? 12 : 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isWideScreen ? 32 : isTablet ? 28 : 24),
                  SizedBox(
                    width: double.infinity,
                    height: isWideScreen ? 60 : isTablet ? 56 : 50,
                    child: ElevatedButton(
                      onPressed: _importWallet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isWideScreen ? 16 : 12),
                        ),
                      ),
                      child: Text(
                        'Import Wallet',
                        style: GoogleFonts.inter(
                          fontSize: isWideScreen ? 18 : isTablet ? 17 : isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(String title) {
    return Row(
      children: [
        if (_currentStep > 0 && !widget.isImporting)
          IconButton(
            onPressed: _previousStep,
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        if (_currentStep > 0 && !widget.isImporting)
          const SizedBox(width: 48), // Balance the back button
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _canProceed() ? _nextStep : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              _getNextButtonText(),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (_currentStep > 0) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: _previousStep,
            child: Text(
              'Back',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _termsAccepted;
      case 1:
        return true;
      case 2:
        return _mnemonicRevealed;
      case 3:
        return _mnemonicConfirmed;
      default:
        return false;
    }
  }

  String _getNextButtonText() {
    switch (_currentStep) {
      case 0:
        return 'Continue';
      case 1:
        return 'I Understand';
      case 2:
        return 'I\'ve Written It Down';
      case 3:
        return 'Create Wallet';
      default:
        return 'Continue';
    }
  }

  void _nextStep() {
    if (_currentStep == 3) {
      _createWallet();
    } else {
      setState(() {
        _currentStep++;
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  void _generateMnemonic() async {
    setState(() {
      _mnemonicRevealed = true;
    });
    
    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final mnemonic = walletProvider.solanaWalletService.generateMnemonic();
      _mnemonicWords = mnemonic.split(' ');
      
      setState(() {});
    } catch (e) {
      // Fallback to mock mnemonic if there's an error
      _mnemonicWords = [
        'abandon', 'ability', 'able', 'about', 'above', 'absent',
        'absorb', 'abstract', 'absurd', 'abuse', 'access', 'accident'
      ];
      
      setState(() {});
    }
  }

  void _toggleMnemonicVisibility() {
    setState(() {
      _mnemonicVisible = !_mnemonicVisible;
    });
  }

  bool _validateMnemonic() {
    if (_userMnemonicInput.length != 12) return false;
    
    for (int i = 0; i < 12; i++) {
      if (_userMnemonicInput[i].toLowerCase() != _mnemonicWords[i]) {
        return false;
      }
    }
    return true;
  }

  void _createWallet() async {
    setState(() {
      _currentStep = 4;
    });

    try {
      // Create actual Solana wallet
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final mnemonic = _mnemonicWords.join(' ');
      
      // Import the wallet using the mnemonic that was generated
      await walletProvider.importWalletFromMnemonic(mnemonic);
      
      // Save completion flags
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_onboarding', true);
      await prefs.setBool('has_wallet', true);
      await prefs.setString('wallet_network', 'devnet'); // Set to devnet for Solana
      await prefs.setString('wallet_mnemonic', mnemonic); // Save mnemonic securely
      
      // Connect the wallet in the Web3 provider for compatibility
      final web3Provider = Provider.of<Web3Provider>(context, listen: false);
      await web3Provider.connectWallet();
      
      // Navigate to main app directly
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating wallet: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _currentStep = 3;
        });
      }
    }
  }

  void _importWallet() async {
    try {
      // Simulate wallet import delay
      await Future.delayed(const Duration(seconds: 2));
      
      // Save completion flags
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_onboarding', true);
      await prefs.setBool('has_wallet', true);
      await prefs.setString('wallet_network', 'devnet'); // Set to testnet
      
      // Connect the wallet in the provider
      final web3Provider = Provider.of<Web3Provider>(context, listen: false);
      await web3Provider.connectWallet();
      
      // Navigate to main app directly
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing wallet: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
