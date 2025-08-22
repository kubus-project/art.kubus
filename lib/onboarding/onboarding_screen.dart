import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/themeprovider.dart';
import '../providers/web3provider.dart';
import 'wallet_creation_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to art.kubus',
      subtitle: 'Discover, Create & Trade\nAR Art with KUB8',
      description: 'Experience immersive augmented reality art in the real world. Create, discover, and trade unique digital artworks using blockchain technology.',
      iconData: Icons.view_in_ar,
      gradient: const LinearGradient(
        colors: [Color(0xFF6C63FF), Color(0xFF9C27B0)],
      ),
    ),
    OnboardingPage(
      title: 'Secure Wallet',
      subtitle: 'Your Digital Assets\nSafe & Secure',
      description: 'Get your own secure Solana wallet with automatic creation. Store SOL, KUB8 tokens, and NFTs with military-grade encryption.',
      iconData: Icons.account_balance_wallet_outlined,
      gradient: const LinearGradient(
        colors: [Color(0xFF00D4AA), Color(0xFF4ECDC4)],
      ),
    ),
    OnboardingPage(
      title: 'Social Community',
      subtitle: 'Connect with Artists\n& Collectors',
      description: 'Join a vibrant community of artists and collectors. Share your work, discover new talent, and build lasting connections.',
      iconData: Icons.people_outline,
      gradient: const LinearGradient(
        colors: [Color(0xFFFFD93D), Color(0xFFFFBE0B)],
      ),
    ),
    OnboardingPage(
      title: 'AR Experience',
      subtitle: 'Art Comes to Life\nEverywhere',
      description: 'Place and view stunning AR artworks in your environment. Transform any space into a gallery with cutting-edge technology.',
      iconData: Icons.view_in_ar_outlined,
      gradient: const LinearGradient(
        colors: [Color(0xFFFF6B6B), Color(0xFF9C27B0)],
      ),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: themeProvider.isDarkMode 
          ? const Color(0xFF0A0A0A) 
          : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),
            _buildBottomSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: _pages[_currentPage].gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'art.kubus',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          // Skip button
          if (_currentPage < _pages.length - 1)
            TextButton(
              onPressed: _skipToEnd,
              child: Text(
                'Skip',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxHeight < 700;
        final isVerySmallScreen = constraints.maxHeight < 600;
        
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 20 : 24),
              child: Column(
                children: [
                  SizedBox(height: isVerySmallScreen ? 20 : isSmallScreen ? 40 : 60),
                  // Icon with gradient background
                  Container(
                    width: isVerySmallScreen ? 100 : isSmallScreen ? 110 : 120,
                    height: isVerySmallScreen ? 100 : isSmallScreen ? 110 : 120,
                    decoration: BoxDecoration(
                      gradient: page.gradient,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: page.gradient.colors.first.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 0,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Icon(
                      page.iconData,
                      size: isVerySmallScreen ? 50 : isSmallScreen ? 55 : 60,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: isVerySmallScreen ? 30 : isSmallScreen ? 40 : 48),
                  // Title
                  Text(
                    page.title,
                    style: GoogleFonts.inter(
                      fontSize: isVerySmallScreen ? 26 : isSmallScreen ? 28 : 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isVerySmallScreen ? 12 : 16),
                  // Subtitle
                  Text(
                    page.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: isVerySmallScreen ? 20 : isSmallScreen ? 22 : 24,
                      fontWeight: FontWeight.w600,
                      color: page.gradient.colors.first,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isVerySmallScreen ? 16 : isSmallScreen ? 20 : 24),
                  // Description
                  Text(
                    page.description,
                    style: GoogleFonts.inter(
                      fontSize: isVerySmallScreen ? 14 : 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isVerySmallScreen ? 40 : isSmallScreen ? 60 : 80),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = MediaQuery.of(context).size.height < 700;
        
        return Padding(
          padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
          child: Column(
            children: [
              // Page indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => _buildDot(index),
                ),
              ),
              SizedBox(height: isSmallScreen ? 24 : 32),
              // Action button
              SizedBox(
                width: double.infinity,
                height: isSmallScreen ? 50 : 56,
                child: ElevatedButton(
                  onPressed: _currentPage == _pages.length - 1 
                      ? _startWalletCreation 
                      : _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pages[_currentPage].gradient.colors.first,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1 ? 'Create Wallet' : 'Continue',
                    style: GoogleFonts.inter(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              // Alternative action
              if (_currentPage == _pages.length - 1)
                TextButton(
                  onPressed: _importExistingWallet,
                  child: Text(
                    'Import Existing Wallet',
                    style: GoogleFonts.inter(
                      fontSize: isSmallScreen ? 14 : 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDot(int index) {
    final isActive = index == _currentPage;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive 
            ? _pages[_currentPage].gradient.colors.first
            : Colors.grey[400],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipToEnd() {
    _pageController.animateToPage(
      _pages.length - 1,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _startWalletCreation() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const WalletCreationScreen(),
      ),
    );
  }

  void _importExistingWallet() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const WalletCreationScreen(isImporting: true),
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String subtitle;
  final String description;
  final IconData iconData;
  final LinearGradient gradient;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.iconData,
    required this.gradient,
  });
}
