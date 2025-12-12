import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../widgets/app_logo.dart';
import '../../../widgets/gradient_icon_card.dart';
import '../../../providers/themeprovider.dart';
import '../../../utils/app_animations.dart';
import 'desktop_permissions_screen.dart';
import '../../auth/sign_in_screen.dart';
import '../desktop_shell.dart';

/// Desktop-optimized onboarding experience with side-by-side layout
class DesktopOnboardingScreen extends StatefulWidget {
  const DesktopOnboardingScreen({super.key});

  @override
  State<DesktopOnboardingScreen> createState() => _DesktopOnboardingScreenState();
}

class _DesktopOnboardingScreenState extends State<DesktopOnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to art.kubus',
      subtitle: 'Discover and create augmented reality art in the real world',
      description:
          'Transform your surroundings with immersive AR artworks and join a global community of digital artists.',
      iconData: Icons.view_in_ar,
      gradient: const LinearGradient(
        colors: [Color.fromARGB(255, 4, 93, 148), Color(0xFF0B6E4F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    OnboardingPage(
      title: 'Explore AR Artworks',
      subtitle: 'Find amazing artworks around you',
      description:
          'Use your device to discover hidden AR artworks in your neighborhood and beyond. Every location tells a story.',
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
      description:
          'Design stunning AR experiences with our intuitive creator tools and share them with the world.',
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
      description:
          'Engage with a vibrant community of AR creators. Share ideas, collaborate on projects, and participate in exclusive events.',
      iconData: Icons.people,
      gradient: const LinearGradient(
        colors: [Color(0xFFEC4899), Color(0xFF0B6E4F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    OnboardingPage(
      title: 'Collect & Trade',
      subtitle: 'Own unique digital assets',
      description:
          'Collect rare AR artworks as NFTs on Solana blockchain. Your creativity has real value in Web3.',
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
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.1, 0),
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

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
      _slideController.reset();
      _slideController.forward();
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
        builder: (context) => const DesktopPermissionsScreen(),
      ),
    );
  }

  void _startWalletCreation() async {
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final accentColor = themeProvider.accentColor;
    final animationTheme = context.animationTheme;
    final screenWidth = MediaQuery.of(context).size.width;

    // Use larger layout for desktop
    final contentWidth = screenWidth > DesktopBreakpoints.large
        ? 1400.0
        : screenWidth > DesktopBreakpoints.expanded
            ? 1100.0
            : 900.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Container(
          width: contentWidth,
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            children: [
              _buildHeader(accentColor),
              Expanded(
                child: Row(
                  children: [
                    // Left side - Content
                    Expanded(
                      flex: 5,
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                          });
                          _slideController.reset();
                          _slideController.forward();
                        },
                        itemCount: _pages.length,
                        itemBuilder: (context, index) {
                          return _buildPageContent(
                            _pages[index],
                            animationTheme,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 40),
                    // Right side - Navigation & Actions
                    Expanded(
                      flex: 3,
                      child: _buildSidebar(accentColor, animationTheme),
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

  Widget _buildHeader(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Row(
            children: [
              const AppLogo(width: 48, height: 48),
              const SizedBox(width: 16),
              Text(
                'art.kubus',
                style: GoogleFonts.inter(
                  fontSize: 24,
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
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Skip',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPageContent(OnboardingPage page, AppAnimationTheme animationTheme) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon with gradient
              GradientIconCard(
                start: page.gradient.colors.first,
                end: page.gradient.colors.length > 1
                    ? page.gradient.colors[1]
                    : page.gradient.colors.first,
                icon: page.iconData,
                width: 140,
                height: 140,
                radius: 24,
                iconSize: 70,
              ),
              const SizedBox(height: 56),
              // Title
              Text(
                page.title,
                style: GoogleFonts.inter(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 20),
              // Subtitle
              Text(
                page.subtitle,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: page.gradient.colors.first,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 24),
              // Description
              Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Text(
                  page.description,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(Color accentColor, AppAnimationTheme animationTheme) {
    final isLastPage = _currentPage == _pages.length - 1;

    return Padding(
      padding: const EdgeInsets.only(right: 40, top: 20, bottom: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          // Page indicators with labels
          ..._pages.asMap().entries.map((entry) {
            final index = entry.key;
            final page = entry.value;
            final isActive = index == _currentPage;
            final isPast = index < _currentPage;

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutCubic,
                  );
                },
                child: AnimatedContainer(
                  duration: animationTheme.short,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive
                          ? accentColor.withValues(alpha: 0.3)
                          : Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.1),
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Dot indicator
                      AnimatedContainer(
                        duration: animationTheme.short,
                        width: isActive ? 32 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isPast || isActive
                              ? accentColor
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            page.title,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            page.title,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ] 
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 32),
          // Action buttons
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: isLastPage ? _goToPermissions : _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isLastPage ? 'Grant Permissions' : 'Continue',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (isLastPage)
            SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: _startWalletCreation,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  side: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Skip Permissions',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          const Spacer(),
          // Progress indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_currentPage + 1} of ${_pages.length}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _currentPage == _pages.length - 1
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
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
