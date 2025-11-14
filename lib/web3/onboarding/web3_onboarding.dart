import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/config.dart';
import 'package:provider/provider.dart';
import '../../providers/themeprovider.dart';

class Web3OnboardingScreen extends StatefulWidget {
  final String featureName;
  final List<OnboardingPage> pages;
  final VoidCallback onComplete;

  const Web3OnboardingScreen({
    super.key,
    required this.featureName,
    required this.pages,
    required this.onComplete,
  });

  @override
  State<Web3OnboardingScreen> createState() => _Web3OnboardingScreenState();
}

class _Web3OnboardingScreenState extends State<Web3OnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
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
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < widget.pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${widget.featureName}_onboarding_completed', true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
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
                        itemCount: widget.pages.length,
                        itemBuilder: (context, index) {
                          return _buildPage(widget.pages[index]);
                        },
                      ),
                    ),
                    _buildBottomNavigation(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 400;
        final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 800;
        final isWideScreen = constraints.maxWidth > 800;
        
        return Padding(
          padding: EdgeInsets.all(isWideScreen ? 32 : isTablet ? 28 : 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  widget.featureName,
                  style: GoogleFonts.inter(
                    fontSize: isWideScreen ? 28 : isTablet ? 26 : isSmallScreen ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: _skipOnboarding,
                child: Text(
                  'Skip',
                  style: GoogleFonts.inter(
                    fontSize: isWideScreen ? 18 : isTablet ? 17 : isSmallScreen ? 14 : 16,
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

  Widget _buildPage(OnboardingPage page) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxHeight < 700;
        final isVerySmallScreen = constraints.maxHeight < 600;
        final isWideScreen = constraints.maxWidth > 800;
        final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 800;
        
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isWideScreen ? 48 : isTablet ? 32 : 24,
            vertical: isVerySmallScreen ? 12 : 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - (isVerySmallScreen ? 24 : 48),
              maxWidth: isWideScreen ? 600 : double.infinity,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: isVerySmallScreen ? 80 : isSmallScreen ? 100 : isTablet ? 140 : isWideScreen ? 160 : 120,
                    height: isVerySmallScreen ? 80 : isSmallScreen ? 100 : isTablet ? 140 : isWideScreen ? 160 : 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: page.gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: page.gradientColors.first.withValues(alpha: 0.3),
                          blurRadius: isWideScreen ? 40 : isTablet ? 30 : 20,
                          spreadRadius: 0,
                          offset: Offset(0, isWideScreen ? 20 : isTablet ? 15 : 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      page.icon,
                      size: isVerySmallScreen ? 40 : isSmallScreen ? 50 : isTablet ? 70 : isWideScreen ? 80 : 60,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: isVerySmallScreen ? 20 : isSmallScreen ? 30 : isTablet ? 48 : isWideScreen ? 56 : 40),
                  Text(
                    page.title,
                    style: GoogleFonts.inter(
                      fontSize: isVerySmallScreen ? 20 : isSmallScreen ? 24 : isTablet ? 32 : isWideScreen ? 36 : 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isVerySmallScreen ? 8 : isSmallScreen ? 12 : isTablet ? 20 : isWideScreen ? 24 : 16),
                  Text(
                    page.description,
                    style: GoogleFonts.inter(
                      fontSize: isVerySmallScreen ? 14 : isSmallScreen ? 15 : isTablet ? 18 : isWideScreen ? 20 : 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isVerySmallScreen ? 16 : isSmallScreen ? 24 : isTablet ? 40 : isWideScreen ? 48 : 32),
                  if (page.features.isNotEmpty) ...[
                    ...page.features.map((feature) => _buildFeatureItem(feature, isSmallScreen, isTablet, isWideScreen)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureItem(String feature, [bool isSmallScreen = false, bool isTablet = false, bool isWideScreen = false]) {
    return Padding(
      padding: EdgeInsets.only(
        left: isWideScreen ? 24 : isTablet ? 20 : 16, 
        top: isSmallScreen ? 6 : isTablet ? 10 : isWideScreen ? 12 : 8, 
        bottom: isSmallScreen ? 6 : isTablet ? 10 : isWideScreen ? 12 : 8
      ),
      child: Row(
        children: [
          Container(
            width: isSmallScreen ? 5 : isTablet ? 7 : isWideScreen ? 8 : 6,
            height: isSmallScreen ? 5 : isTablet ? 7 : isWideScreen ? 8 : 6,
            decoration: BoxDecoration(
              color: Provider.of<ThemeProvider>(context).accentColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: isWideScreen ? 20 : isTablet ? 18 : 16),
          Expanded(
            child: Text(
              feature,
              style: GoogleFonts.inter(
                fontSize: isSmallScreen ? 13 : isTablet ? 16 : isWideScreen ? 18 : 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 400;
        final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 800;
        final isWideScreen = constraints.maxWidth > 800;
        
        return Padding(
          padding: EdgeInsets.all(isWideScreen ? 32 : isTablet ? 28 : isSmallScreen ? 20 : 24),
          child: Column(
            children: [
              // Page indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.pages.length,
                  (index) => Container(
                    margin: EdgeInsets.symmetric(horizontal: isWideScreen ? 6 : isTablet ? 5 : 4),
                    width: index == _currentPage 
                        ? (isWideScreen ? 32 : isTablet ? 28 : isSmallScreen ? 20 : 24) 
                        : (isWideScreen ? 10 : isTablet ? 9 : isSmallScreen ? 6 : 8),
                    height: isWideScreen ? 10 : isTablet ? 9 : isSmallScreen ? 6 : 8,
                    decoration: BoxDecoration(
                      color: index == _currentPage
                          ? Provider.of<ThemeProvider>(context).accentColor
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              SizedBox(height: isWideScreen ? 40 : isTablet ? 36 : isSmallScreen ? 24 : 32),
              // Navigation buttons
              Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousPage,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Theme.of(context).colorScheme.outline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                          padding: EdgeInsets.symmetric(
                            vertical: isWideScreen ? 18 : isTablet ? 16 : isSmallScreen ? 12 : 14,
                          ),
                        ),
                        child: Text(
                          'Back',
                          style: GoogleFonts.inter(
                            fontSize: isWideScreen ? 18 : isTablet ? 17 : isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  if (_currentPage > 0) SizedBox(width: isWideScreen ? 20 : isTablet ? 18 : 16),
                  Expanded(
                    flex: _currentPage == 0 ? 1 : 2,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: isWideScreen ? 18 : isTablet ? 16 : isSmallScreen ? 12 : 14,
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage == widget.pages.length - 1 ? 'Get Started' : 'Next',
                        style: GoogleFonts.inter(
                          fontSize: isWideScreen ? 18 : isTablet ? 17 : isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  final List<String> features;

  const OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradientColors,
    this.features = const [],
  });
}

// Utility function to check if onboarding is needed
Future<bool> isOnboardingNeeded(String featureName) async {
  final prefs = await SharedPreferences.getInstance();
  
  // Check user preference for skipping Web3 onboarding (defaults to config setting)
  final userSkipWeb3Onboarding = prefs.getBool('skipOnboardingForReturningUsers') ?? AppConfig.skipWeb3OnboardingForReturningUsers;
  
  // Check if Web3 onboarding should be skipped for returning users
  if (userSkipWeb3Onboarding) {
    final hasSeenWelcome = prefs.getBool(PreferenceKeys.hasSeenWelcome) ?? false;
    final isFirstLaunch = prefs.getBool(PreferenceKeys.isFirstLaunch) ?? true;
    final isFirstTime = prefs.getBool('first_time') ?? true;
    
    // If user is a returning user, skip Web3 onboarding
    if (!isFirstTime || hasSeenWelcome || !isFirstLaunch) {
      return false;
    }
  }
  
  // Otherwise, check if this specific feature onboarding was completed
  return !(prefs.getBool('${featureName}_onboarding_completed') ?? false);
}





