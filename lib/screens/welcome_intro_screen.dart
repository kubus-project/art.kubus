import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/themeprovider.dart';
import '../config/config.dart';
import '../main_app.dart';
import '../widgets/app_logo.dart';

class WelcomeIntroScreen extends StatefulWidget {
  const WelcomeIntroScreen({super.key});

  @override
  State<WelcomeIntroScreen> createState() => _WelcomeIntroScreenState();
}

class _WelcomeIntroScreenState extends State<WelcomeIntroScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  int _currentPage = 0;
  late PageController _pageController;
  
  final List<WelcomePageData> _pages = [
    const WelcomePageData(
      title: 'Welcome to art.kubus',
      subtitle: 'Discover and create augmented reality art in the real world',
      description: 'Transform your surroundings with immersive AR artworks and join a global community of digital artists.',
      icon: Icons.view_in_ar,
      gradient: [Color(0xFF6366F1), Colors.white],
    ),
    const WelcomePageData(
      title: 'Explore AR Artworks',
      subtitle: 'Find amazing artworks around you',
      description: 'Use your device to discover hidden AR artworks in your neighborhood and beyond. Every location tells a story.',
      icon: Icons.explore,
      gradient: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    ),
    const WelcomePageData(
      title: 'Create & Share',
      subtitle: 'Express your creativity',
      description: 'Design stunning AR experiences with our intuitive creator tools and share them with the world.',
      icon: Icons.palette,
      gradient: [Color(0xFF10B981), Color(0xFF059669)],
    ),
    const WelcomePageData(
      title: 'Collect & Trade',
      subtitle: 'Own unique digital assets',
      description: 'Collect rare AR artworks as NFTs and trade them in our Web3 marketplace. Your creativity has value.',
      icon: Icons.account_balance_wallet,
      gradient: [Color(0xFFF59E0B), Color(0xFFEF4444)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    _fadeController = AnimationController(
      duration: AppConfig.longAnimationDuration,
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: AppConfig.mediumAnimationDuration,
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: AnimatedBuilder(
        animation: Listenable.merge([_fadeAnimation, _slideAnimation]),
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SafeArea(
                child: Column(
                  children: [
                    // Skip button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: TextButton(
                          onPressed: _skipIntro,
                          child: Text(
                            'Skip',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Page view
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
                    
                    // Page indicators
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (index) => _buildPageIndicator(index),
                        ),
                      ),
                    ),
                    
                    // Navigation buttons
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          if (_currentPage > 0)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _previousPage,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Previous',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          
                          if (_currentPage > 0) const SizedBox(width: 16),
                          
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _currentPage == _pages.length - 1 
                                ? _completeIntro 
                                : _nextPage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeProvider.accentColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                _currentPage == _pages.length - 1 
                                  ? 'Get Started' 
                                  : 'Next',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
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
          );
        },
      ),
    );
  }

  Widget _buildPage(WelcomePageData page) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 
              MediaQuery.of(context).padding.top - 140, // Account for header and navigation
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
                  // Reduced top spacing to ensure content fits better
                  SizedBox(height: MediaQuery.of(context).size.height * 0.08),
                  
                  // Icon with gradient background or AppLogo for welcome page
                  page.title == 'Welcome to art.kubus' 
                    ? Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.grey[900] 
                              : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 0,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: AppLogo(width: 60, height: 60),
                        ),
                      )
                    : Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: page.gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: page.gradient.first.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 0,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          page.icon,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                  
                  const SizedBox(height: 32),
                  
                  // Title
                  Text(
                    page.title,
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Subtitle
                  Text(
                    page.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      page.description,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        height: 1.5,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  // Add flexible bottom spacing
                  SizedBox(height: MediaQuery.of(context).size.height * 0.08),
                ],
              ),
            ),
        );
  }

  Widget _buildPageIndicator(int index) {
    final isActive = index == _currentPage;
    
    return AnimatedContainer(
      duration: AppConfig.shortAnimationDuration,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive 
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: AppConfig.mediumAnimationDuration,
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: AppConfig.mediumAnimationDuration,
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipIntro() async {
    await _completeIntro();
  }

  Future<void> _completeIntro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PreferenceKeys.hasSeenWelcome, true);
    await prefs.setBool(PreferenceKeys.isFirstLaunch, false);
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const MainApp(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: AppConfig.longAnimationDuration,
        ),
      );
    }
  }
}

class WelcomePageData {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final List<Color> gradient;

  const WelcomePageData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.gradient,
  });
}


