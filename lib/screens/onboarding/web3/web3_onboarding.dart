import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../config/config.dart';
import 'package:provider/provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../widgets/gradient_icon_card.dart';
import '../../desktop/desktop_shell.dart';
import '../../desktop/onboarding/desktop_web3_onboarding.dart' show DesktopWeb3OnboardingScreen, Web3OnboardingPage;

class Web3OnboardingScreen extends StatefulWidget {
  final String featureKey;
  final String featureTitle;
  final List<OnboardingPage> pages;
  final VoidCallback onComplete;

  const Web3OnboardingScreen({
    super.key,
    required this.featureKey,
    required this.featureTitle,
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
    await prefs.setBool('${widget.featureKey}_onboarding_completed', true);
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    // Redirect to desktop Web3 onboarding if on desktop
    if (DesktopBreakpoints.isDesktop(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Convert mobile OnboardingPage to desktop Web3OnboardingPage
          final desktopPages = widget.pages.map((page) {
            return Web3OnboardingPage(
              title: page.title,
              description: page.description,
              icon: page.icon,
              gradientColors: page.gradientColors,
              features: page.features,
            );
          }).toList();

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => DesktopWeb3OnboardingScreen(
                featureKey: widget.featureKey,
                featureTitle: widget.featureTitle,
                pages: desktopPages,
                onComplete: widget.onComplete,
              ),
            ),
          );
        }
      });
    }

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
    final l10n = AppLocalizations.of(context)!;
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
                  widget.featureTitle,
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
                  l10n.commonSkip,
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
                  GradientIconCard(
                    start: page.gradientColors.first,
                    end: page.gradientColors.length > 1 ? page.gradientColors[1] : page.gradientColors.first,
                    icon: page.icon,
                    width: isVerySmallScreen ? 100 : isSmallScreen ? 110 : isTablet ? 140 : isWideScreen ? 160 : 120,
                    height: isVerySmallScreen ? 100 : isSmallScreen ? 110 : isTablet ? 140 : isWideScreen ? 160 : 120,
                    iconSize: isVerySmallScreen ? 50 : isSmallScreen ? 55 : isTablet ? 70 : isWideScreen ? 80 : 60,
                    radius: 20,
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
    final l10n = AppLocalizations.of(context)!;
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
                          foregroundColor: Theme.of(context).colorScheme.onSurface,
                          padding: EdgeInsets.symmetric(
                            vertical: isWideScreen ? 18 : isTablet ? 16 : isSmallScreen ? 12 : 14,
                          ),
                        ),
                        child: Text(
                          l10n.commonBack,
                          style: GoogleFonts.inter(
                            fontSize: isWideScreen ? 18 : isTablet ? 17 : isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w600,
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
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: isWideScreen ? 18 : isTablet ? 16 : isSmallScreen ? 12 : 14,
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage == widget.pages.length - 1 ? l10n.commonGetStarted : l10n.commonNext,
                        style: GoogleFonts.inter(
                          fontSize: isWideScreen ? 18 : isTablet ? 17 : isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w600,
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
Future<bool> isOnboardingNeeded(String featureKey) async {
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
  return !(prefs.getBool('${featureKey}_onboarding_completed') ?? false);
}


