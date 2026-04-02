import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../config/config.dart';
import '../../../services/onboarding_state_service.dart';
import 'package:provider/provider.dart';
import '../../../utils/design_tokens.dart';
import '../../../providers/themeprovider.dart';
import '../../../widgets/gradient_icon_card.dart';
import '../../../widgets/glass_components.dart';
import '../../../widgets/kubus_button.dart';
import '../../../widgets/common/kubus_screen_header.dart';
import '../../desktop/desktop_shell.dart';
import '../../desktop/onboarding/desktop_web3_onboarding.dart'
    show DesktopWeb3OnboardingScreen, Web3OnboardingPage;

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

    final fallbackStart = Theme.of(context).colorScheme.primary;
    final fallbackEnd = Provider.of<ThemeProvider>(context).accentColor;
    final currentPage = widget.pages.isEmpty
        ? null
        : widget.pages[_currentPage.clamp(0, widget.pages.length - 1)];
    final start = (currentPage?.gradientColors.isNotEmpty ?? false)
        ? currentPage!.gradientColors.first
        : fallbackStart;
    final end = (currentPage?.gradientColors.length ?? 0) > 1
        ? currentPage!.gradientColors[1]
        : (currentPage?.gradientColors.isNotEmpty ?? false)
            ? currentPage!.gradientColors.first
            : fallbackEnd;

    final bgStart = start.withValues(alpha: 0.55);
    final bgEnd = end.withValues(alpha: 0.50);
    final bgMid =
        (Color.lerp(bgStart, bgEnd, 0.55) ?? bgEnd).withValues(alpha: 0.52);
    final bgColors = <Color>[bgStart, bgMid, bgEnd, bgStart];

    return AnimatedGradientBackground(
      duration: const Duration(seconds: 10),
      intensity: 0.22,
      colors: bgColors,
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final currentStep = _currentPage + 1;
    final totalSteps = widget.pages.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KubusSpacing.lg,
        KubusSpacing.lg,
        KubusSpacing.lg,
        KubusSpacing.md,
      ),
      child: LiquidGlassPanel(
        padding: const EdgeInsets.symmetric(
          horizontal: KubusSpacing.md,
          vertical: KubusSpacing.sm,
        ),
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        child: KubusScreenHeaderBar(
          title: widget.featureTitle,
          subtitle: totalSteps > 0 ? '$currentStep / $totalSteps' : null,
          compact: true,
          titleStyle: KubusTextStyles.screenTitle,
          subtitleStyle: KubusTextStyles.sectionSubtitle.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.68),
          ),
          actions: [
            TextButton(
              onPressed: _skipOnboarding,
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurface,
                padding: const EdgeInsets.symmetric(
                  horizontal: KubusSpacing.md,
                  vertical: KubusSpacing.sm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KubusRadius.sm),
                ),
              ),
              child: Text(
                l10n.commonSkip,
                style: KubusTextStyles.navLabel.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.76),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isVerySmallScreen = constraints.maxHeight < 600;
        final isTablet = constraints.maxWidth > 600;
        final scheme = Theme.of(context).colorScheme;
        final titleStyle = (isTablet
                ? Theme.of(context).textTheme.displaySmall
                : Theme.of(context).textTheme.headlineMedium)
            ?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
          height: 1.05,
        );
        final subtitleStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.76),
                  height: 1.55,
                ) ??
            KubusTextStyles.heroSubtitle.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.76),
            );

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            isTablet ? KubusSpacing.xl : KubusSpacing.lg,
            isVerySmallScreen ? KubusSpacing.sm : KubusSpacing.md,
            isTablet ? KubusSpacing.xl : KubusSpacing.lg,
            KubusSpacing.lg,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - KubusSpacing.xxl,
              maxWidth: isTablet ? 720 : double.infinity,
            ),
            child: Center(
              child: LiquidGlassPanel(
                padding: EdgeInsets.all(
                  isTablet ? KubusSpacing.xl : KubusSpacing.lg,
                ),
                borderRadius: BorderRadius.circular(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GradientIconCard(
                      start: page.gradientColors.first,
                      end: page.gradientColors.length > 1
                          ? page.gradientColors[1]
                          : page.gradientColors.first,
                      icon: page.icon,
                      width: isVerySmallScreen ? 76 : 88,
                      height: isVerySmallScreen ? 76 : 88,
                      iconSize: isVerySmallScreen ? 36 : 42,
                      radius: 24,
                    ),
                    SizedBox(
                      height:
                          isVerySmallScreen ? KubusSpacing.md : KubusSpacing.xl,
                    ),
                    Text(page.title, style: titleStyle),
                    const SizedBox(height: KubusSpacing.md),
                    Text(page.description, style: subtitleStyle),
                    if (page.features.isNotEmpty) ...[
                      const SizedBox(height: KubusSpacing.xl),
                      Wrap(
                        spacing: KubusSpacing.sm,
                        runSpacing: KubusSpacing.sm,
                        children: page.features
                            .take(isTablet ? 4 : 3)
                            .map(
                                (feature) => _buildFeatureChip(feature, scheme))
                            .toList(growable: false),
                      ),
                      const SizedBox(height: KubusSpacing.xl),
                      LiquidGlassPanel(
                        padding: const EdgeInsets.all(KubusSpacing.lg),
                        borderRadius: BorderRadius.circular(KubusRadius.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.web3OnboardingKeyFeaturesTitle,
                              style: KubusTextStyles.sectionTitle.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: KubusSpacing.md),
                            ...page.features.map(_buildFeatureItem),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureChip(String feature, ColorScheme scheme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          feature,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.84),
              ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String feature) {
    final scheme = Theme.of(context).colorScheme;
    final colors = widget.pages[_currentPage].gradientColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 16, color: Colors.white),
          ),
          const SizedBox(width: KubusSpacing.md),
          Expanded(
            child: Text(
              feature,
              style: KubusTextStyles.detailBody.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.82),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KubusSpacing.lg,
        KubusSpacing.sm,
        KubusSpacing.lg,
        KubusSpacing.lg,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: isDark ? 0.18 : 0.84),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
              blurRadius: 28,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(KubusSpacing.lg),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin:
                        const EdgeInsets.symmetric(horizontal: KubusSpacing.xs),
                    width: index == _currentPage ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color:
                          widget.pages[index].gradientColors.first.withValues(
                        alpha: index == _currentPage ? 1.0 : 0.25,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: KubusSpacing.md),
              Text(
                l10n.commonStepOfTotal(_currentPage + 1, widget.pages.length),
                style: KubusTextStyles.navMetaLabel.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: KubusSpacing.lg),
              Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: KubusOutlineButton(
                        onPressed: _previousPage,
                        label: l10n.commonBack,
                        isFullWidth: true,
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: KubusSpacing.md),
                  Expanded(
                    flex: _currentPage == 0 ? 1 : 2,
                    child: KubusButton(
                      onPressed: _nextPage,
                      label: _currentPage == widget.pages.length - 1
                          ? l10n.commonGetStarted
                          : l10n.commonNext,
                      isFullWidth: true,
                      backgroundColor:
                          widget.pages[_currentPage].gradientColors.first,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
  final userSkipWeb3Onboarding =
      prefs.getBool('skipOnboardingForReturningUsers') ??
          AppConfig.skipWeb3OnboardingForReturningUsers;

  // Check if Web3 onboarding should be skipped for returning users
  if (userSkipWeb3Onboarding) {
    final onboardingState = await OnboardingStateService.load(prefs: prefs);
    if (onboardingState.isReturningUser) return false;
  }

  // Otherwise, check if this specific feature onboarding was completed
  return !(prefs.getBool('${featureKey}_onboarding_completed') ?? false);
}
