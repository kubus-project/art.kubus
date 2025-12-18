import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/gradient_icon_card.dart';
import '../../screens/desktop/desktop_shell.dart';
import '../desktop/onboarding/desktop_onboarding_screen.dart';
import 'permissions_screen.dart';
import '../auth/sign_in_screen.dart';
import '../../utils/app_color_utils.dart';

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

  List<OnboardingPage> get _pages {
    final l10n = AppLocalizations.of(context)!;
    return [
      OnboardingPage(
        title: l10n.onboardingWelcomeTitle,
        subtitle: l10n.onboardingWelcomeSubtitle,
        description: l10n.onboardingWelcomeDescription,
        iconData: Icons.view_in_ar,
        gradient: const LinearGradient(
          colors: [Color.fromARGB(255, 4, 93, 148), Color(0xFF0B6E4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      OnboardingPage(
        title: l10n.onboardingExploreTitle,
        subtitle: l10n.onboardingExploreSubtitle,
        description: l10n.onboardingExploreDescription,
        iconData: Icons.explore,
        gradient: const LinearGradient(
          colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      OnboardingPage(
        title: l10n.onboardingCreateTitle,
        subtitle: l10n.onboardingCreateSubtitle,
        description: l10n.onboardingCreateDescription,
        iconData: Icons.palette,
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      OnboardingPage(
        title: l10n.onboardingCommunityTitle,
        subtitle: l10n.onboardingCommunitySubtitle,
        description: l10n.onboardingCommunityDescription,
        iconData: Icons.people,
        gradient: const LinearGradient(
          colors: [Color(0xFFEC4899), Color(0xFF0B6E4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      OnboardingPage(
        title: l10n.onboardingCollectiblesTitle,
        subtitle: l10n.onboardingCollectiblesSubtitle,
        description: l10n.onboardingCollectiblesDescription,
        iconData: Icons.account_balance_wallet,
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    ];
  }

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
    // Redirect to desktop onboarding if on desktop
    if (DesktopBreakpoints.isDesktop(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DesktopOnboardingScreen()),
          );
        }
      });
    }

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
    final l10n = AppLocalizations.of(context)!;
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
                l10n.appTitle,
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
                l10n.commonSkip,
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
                    // Icon with gradient background (shared widget)
                    GradientIconCard(
                      start: page.gradient.colors.first,
                      end: page.gradient.colors.length > 1 ? page.gradient.colors[1] : page.gradient.colors.first,
                      icon: page.iconData,
                      width: isVerySmallScreen ? 100 : effectiveSmallScreen ? 110 : 120,
                      height: isVerySmallScreen ? 100 : effectiveSmallScreen ? 110 : 120,
                      radius: 20,
                      iconSize: isVerySmallScreen ? 50 : effectiveSmallScreen ? 55 : 60,
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
    final l10n = AppLocalizations.of(context)!;
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
                    _currentPage == _pages.length - 1 ? l10n.onboardingGrantPermissions : l10n.commonContinue,
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
                    l10n.onboardingSkipPermissions,
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
            ? AppColorUtils.amberAccent
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
          builder: (context) => const SignInScreen(),
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



