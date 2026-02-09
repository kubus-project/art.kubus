import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../services/onboarding_state_service.dart';
import '../../../services/telemetry/telemetry_service.dart';
import '../../../widgets/app_logo.dart';
import '../../../widgets/gradient_icon_card.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/locale_provider.dart';
import '../../../utils/app_animations.dart';
import '../../../widgets/glass_components.dart';
import 'desktop_permissions_screen.dart';
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

  List<OnboardingPage> _pages(AppLocalizations l10n) => [
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
    final pages = _pages(AppLocalizations.of(context)!);
    if (_currentPage < pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
      _slideController.reset();
      _slideController.forward();
    }
  }

  void _skipToEnd() {
    final pages = _pages(AppLocalizations.of(context)!);
    _pageController.animateToPage(
      pages.length - 1,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _goToPermissions() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const DesktopPermissionsScreen(),
        settings: const RouteSettings(name: '/onboarding/desktop/permissions'),
      ),
    );
  }

  void _startWalletCreation() async {
    unawaited(TelemetryService().trackOnboardingComplete(reason: 'skip_permissions'));
    final navigator = Navigator.of(context);
    final prefs = await SharedPreferences.getInstance();
    await OnboardingStateService.markCompleted(prefs: prefs);
    if (!mounted) return;
    navigator.pushReplacementNamed('/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final accentColor = themeProvider.accentColor;
    final animationTheme = context.animationTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final pages = _pages(l10n);

    final current = pages[_currentPage.clamp(0, pages.length - 1)];
    final start = current.gradient.colors.first.withValues(alpha: 0.55);
    final end = (current.gradient.colors.length > 1
            ? current.gradient.colors[1]
            : current.gradient.colors.first)
        .withValues(alpha: 0.50);
    final mid = Color.lerp(start, end, 0.55) ?? end;

    // Use larger layout for desktop
    final contentWidth = screenWidth > DesktopBreakpoints.large
        ? 1400.0
        : screenWidth > DesktopBreakpoints.expanded
            ? 1100.0
            : 900.0;

    return AnimatedGradientBackground(
      colors: <Color>[start, mid, end, start],
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
                          itemCount: pages.length,
                          itemBuilder: (context, index) {
                            return _buildPageContent(
                              pages[index],
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
      ),
    );
  }

  Widget _buildHeader(Color accentColor) {
    final l10n = AppLocalizations.of(context)!;
    final pages = _pages(l10n);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final scheme = Theme.of(context).colorScheme;
    
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
                l10n.appTitle,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          // Controls: Language, Theme, and Skip
          Row(
            children: [
              // Language selector
              PopupMenuButton<String>(
                onSelected: (value) {
                  unawaited(localeProvider.setLanguageCode(value));
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem(
                    value: 'sl',
                    child: Row(
                      children: [
                        if (localeProvider.languageCode == 'sl')
                          Icon(Icons.check, size: 18, color: scheme.primary)
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Text(l10n.languageSlovenian),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'en',
                    child: Row(
                      children: [
                        if (localeProvider.languageCode == 'en')
                          Icon(Icons.check, size: 18, color: scheme.primary)
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Text(l10n.languageEnglish),
                      ],
                    ),
                  ),
                ],
                tooltip: l10n.settingsLanguageTitle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.language,
                    size: 24,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              // Theme toggle
              IconButton(
                icon: Icon(
                  themeProvider.isDarkMode ? Icons.brightness_7 : Icons.brightness_4,
                  size: 24,
                ),
                tooltip: themeProvider.isDarkMode ? l10n.settingsThemeModeLight : l10n.settingsThemeModeDark,
                color: scheme.onSurface.withValues(alpha: 0.7),
                onPressed: () {
                  final currentMode = themeProvider.themeMode;
                  final newMode = currentMode == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
                  unawaited(themeProvider.setThemeMode(newMode));
                },
              ),
              const SizedBox(width: 16),
              // Skip button
              if (_currentPage < pages.length - 1)
                TextButton(
                  onPressed: _skipToEnd,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    l10n.commonSkip,
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
    final l10n = AppLocalizations.of(context)!;
    final pages = _pages(l10n);
    final isLastPage = _currentPage == pages.length - 1;

    return Padding(
      padding: const EdgeInsets.only(right: 40, top: 20, bottom: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          // Page indicators with labels
          ...pages.asMap().entries.map((entry) {
            final index = entry.key;
            final page = entry.value;
            final isActive = index == _currentPage;
            final isPast = index < _currentPage;
            final pageColor = page.gradient.colors.first;

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
                          // Match the dot to the page icon/gradient color.
                          color: pageColor.withValues(
                            alpha: isActive
                                ? 1.0
                                : isPast
                                    ? 0.65
                                    : 0.25,
                          ),
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
                isLastPage ? l10n.onboardingGrantPermissions : l10n.commonContinue,
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
                  l10n.onboardingSkipPermissions,
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
                l10n.commonStepOfTotal(_currentPage + 1, pages.length),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _currentPage == pages.length - 1
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
