import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/app_logo.dart';
import 'permissions_screen.dart';
import '../main_app.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to art.kubus',
      subtitle: 'Discover and create augmented reality art in the real world',
      description: 'Transform your surroundings with immersive AR artworks and join a global community of digital artists.',
      iconData: Icons.view_in_ar,
      gradient: const LinearGradient(
        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    OnboardingPage(
      title: 'Explore AR Artworks',
      subtitle: 'Find amazing artworks around you',
      description: 'Use your device to discover hidden AR artworks in your neighborhood and beyond. Every location tells a story.',
      iconData: Icons.explore,
      gradient: const LinearGradient(
        colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    OnboardingPage(
      title: 'Create & Share',
      subtitle: 'Express your creativity',
      description: 'Design stunning AR experiences with our intuitive creator tools and share them with the world.',
      iconData: Icons.palette,
      gradient: const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    OnboardingPage(
      title: 'Join the Community',
      subtitle: 'Connect with fellow artists',
      description: 'Engage with a vibrant community of AR creators. Share ideas, collaborate on projects, and participate in exclusive events.',
      iconData: Icons.people,
      gradient: const LinearGradient(
        colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    OnboardingPage(
      title: 'Collect & Trade',
      subtitle: 'Own unique digital assets',
      description: 'Collect rare AR artworks as NFTs on Solana blockchain. Your creativity has real value in Web3.',
      iconData: Icons.account_balance_wallet,
      gradient: const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pageController.dispose();
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
        child: Column(
          children: [
            _buildHeader(isSmallScreen),
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
                  return _buildPage(_pages[index], isSmallScreen);
                },
              ),
            ),
            _buildBottomSection(isSmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader([bool isSmallScreen = false]) {
    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Row(
            children: [
              AppLogo(
                width: isSmallScreen ? 36 : 40,
                height: isSmallScreen ? 36 : 40,
              ),
              SizedBox(width: isSmallScreen ? 8 : 12),
              Text(
                'art.kubus',
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 18 : 20,
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
                  fontSize: isSmallScreen ? 14 : 16,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingPage page, [bool isSmallScreen = false]) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final constraintSmallScreen = constraints.maxHeight < 700;
          final isVerySmallScreen = constraints.maxHeight < 600;
          final effectiveSmallScreen = isSmallScreen || constraintSmallScreen;
          
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: effectiveSmallScreen ? 20 : 24),
                child: Column(
                  children: [
                    SizedBox(height: isVerySmallScreen ? 20 : effectiveSmallScreen ? 40 : 60),
                    // Icon with gradient background
                    Container(
                      width: isVerySmallScreen ? 100 : effectiveSmallScreen ? 110 : 120,
                      height: isVerySmallScreen ? 100 : effectiveSmallScreen ? 110 : 120,
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
                        size: isVerySmallScreen ? 50 : effectiveSmallScreen ? 55 : 60,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: isVerySmallScreen ? 30 : effectiveSmallScreen ? 40 : 48),
                    // Title
                    Text(
                      page.title,
                      style: GoogleFonts.inter(
                        fontSize: isVerySmallScreen ? 26 : effectiveSmallScreen ? 28 : 32,
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
                        fontSize: isVerySmallScreen ? 20 : effectiveSmallScreen ? 22 : 24,
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
      ),
    );
  }

  Widget _buildBottomSection([bool isSmallScreen = false]) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final constraintSmallScreen = MediaQuery.of(context).size.height < 700;
        final effectiveSmallScreen = isSmallScreen || constraintSmallScreen;
        
        return Padding(
          padding: EdgeInsets.all(effectiveSmallScreen ? 20 : 24),
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
              SizedBox(height: effectiveSmallScreen ? 24 : 32),
              // Action button
              SizedBox(
                width: double.infinity,
                height: effectiveSmallScreen ? 50 : 56,
                child: ElevatedButton(
                  onPressed: _currentPage == _pages.length - 1 
                      ? _goToPermissions
                      : _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1 ? 'Grant Permissions' : 'Continue',
                    style: GoogleFonts.inter(
                      fontSize: effectiveSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: effectiveSmallScreen ? 12 : 16),
              // Alternative action
              if (_currentPage == _pages.length - 1)
                TextButton(
                  onPressed: _startWalletCreation,
                  child: Text(
                    'Skip Permissions',
                    style: GoogleFonts.inter(
                      fontSize: effectiveSmallScreen ? 14 : 16,
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
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
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

  void _goToPermissions() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const PermissionsScreen(),
      ),
    );
  }

  void _startWalletCreation() async {
    // Mark onboarding as completed but don't force wallet creation
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('completed_onboarding', true);
    await prefs.setBool('has_seen_onboarding', true);
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MainApp(),
        ),
      );
    }
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




