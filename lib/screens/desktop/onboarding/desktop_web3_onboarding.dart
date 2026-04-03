import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../providers/themeprovider.dart';
import '../../../widgets/gradient_icon_card.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/design_tokens.dart';
import '../../../widgets/glass_components.dart';
import '../../../widgets/kubus_button.dart';
import '../desktop_shell.dart';

/// Desktop-optimized Web3 feature onboarding
class DesktopWeb3OnboardingScreen extends StatefulWidget {
  final String featureKey;
  final String featureTitle;
  final List<Web3OnboardingPage> pages;
  final VoidCallback onComplete;

  const DesktopWeb3OnboardingScreen({
    super.key,
    required this.featureKey,
    required this.featureTitle,
    required this.pages,
    required this.onComplete,
  });

  @override
  State<DesktopWeb3OnboardingScreen> createState() =>
      _DesktopWeb3OnboardingScreenState();
}

class _DesktopWeb3OnboardingScreenState
    extends State<DesktopWeb3OnboardingScreen> with TickerProviderStateMixin {
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
      begin: const Offset(0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
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
      _animationController.reset();
      _animationController.forward();
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
      _animationController.reset();
      _animationController.forward();
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
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final accentColor = themeProvider.accentColor;
    final animationTheme = context.animationTheme;
    final screenWidth = MediaQuery.of(context).size.width;

    final current = widget.pages.isEmpty
        ? null
        : widget.pages[_currentPage.clamp(0, widget.pages.length - 1)];
    final fallbackStart = Theme.of(context).colorScheme.primary;
    final fallbackEnd = accentColor;
    final start = (current?.gradientColors.isNotEmpty ?? false)
        ? current!.gradientColors.first
        : fallbackStart;
    final end = (current?.gradientColors.length ?? 0) > 1
        ? current!.gradientColors[1]
        : (current?.gradientColors.isNotEmpty ?? false)
            ? current!.gradientColors.first
            : fallbackEnd;

    final bgStart = start.withValues(alpha: 0.55);
    final bgEnd = end.withValues(alpha: 0.50);
    final bgMid =
        (Color.lerp(bgStart, bgEnd, 0.55) ?? bgEnd).withValues(alpha: 0.52);
    final bgColors = <Color>[bgStart, bgMid, bgEnd, bgStart];

    final contentWidth = screenWidth > DesktopBreakpoints.large
        ? 1400.0
        : screenWidth > DesktopBreakpoints.expanded
            ? 1100.0
            : 900.0;

    return AnimatedGradientBackground(
      duration: const Duration(seconds: 10),
      intensity: 0.25,
      colors: bgColors,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            TextButton(
              onPressed: _skipOnboarding,
              child: Text(
                l10n.commonSkip,
                style: KubusTextStyles.navLabel.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: Center(
          child: Container(
            width: contentWidth,
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side - Content
                Expanded(
                  flex: 5,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                      _animationController.reset();
                      _animationController.forward();
                    },
                    itemCount: widget.pages.length,
                    itemBuilder: (context, index) =>
                        _buildPageContent(widget.pages[index]),
                  ),
                ),
                const SizedBox(width: 40),
                // Right side - Navigation & Actions
                SizedBox(
                  width: 440,
                  child: _buildSidebar(accentColor, animationTheme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageContent(Web3OnboardingPage page) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GradientIconCard(
                  start: page.gradientColors.first,
                  end: page.gradientColors.length > 1
                      ? page.gradientColors[1]
                      : page.gradientColors.first,
                  icon: page.icon,
                  width: 88,
                  height: 88,
                  radius: 24,
                  iconSize: 42,
                ),
                const SizedBox(height: KubusSpacing.xl),
                Text(
                  page.title,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                        height: 1.02,
                      ),
                ),
                const SizedBox(height: KubusSpacing.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Text(
                    page.description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.76),
                          height: 1.55,
                        ),
                  ),
                ),
                const SizedBox(height: KubusSpacing.xl),
                Wrap(
                  spacing: KubusSpacing.sm,
                  runSpacing: KubusSpacing.sm,
                  children: page.features
                      .take(4)
                      .map(
                        (feature) => DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surface.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Text(
                              feature,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.84),
                                  ),
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: KubusSpacing.xl),
                LiquidGlassPanel(
                  padding: const EdgeInsets.all(KubusSpacing.xl),
                  borderRadius: BorderRadius.circular(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.web3OnboardingKeyFeaturesTitle,
                        style: KubusTextStyles.sectionTitle.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: KubusSpacing.lg),
                      ...page.features.map(
                        (feature) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: KubusSpacing.md),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: page.gradientColors,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: KubusSpacing.md),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: KubusTextStyles.detailBody.copyWith(
                                    fontSize: KubusHeaderMetrics.screenSubtitle,
                                    color:
                                        scheme.onSurface.withValues(alpha: 0.8),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
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
      ),
    );
  }

  Widget _buildSidebar(Color accentColor, AppAnimationTheme animationTheme) {
    final l10n = AppLocalizations.of(context)!;
    final isLastPage = _currentPage == widget.pages.length - 1;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 40, top: 20, bottom: 40),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: isDark ? 0.18 : 0.84),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color:
                scheme.outlineVariant.withValues(alpha: isDark ? 0.18 : 0.12),
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
          padding: const EdgeInsets.all(KubusSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KubusSpacing.lg,
                  vertical: KubusSpacing.md,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.pages[_currentPage].gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                ),
                child: Text(
                  widget.featureTitle,
                  style: KubusTextStyles.navLabel.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: KubusSpacing.xl),
              ...widget.pages.asMap().entries.map((entry) {
                final index = entry.key;
                final page = entry.value;
                final isActive = index == _currentPage;
                final isPast = index < _currentPage;
                final pageColor = page.gradientColors.first;

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
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(KubusSpacing.md),
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(
                          alpha: isActive ? 0.12 : 0.06,
                        ),
                        borderRadius: BorderRadius.circular(KubusRadius.xl),
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: animationTheme.short,
                            width: isActive ? 32 : 8,
                            height: 8,
                            decoration: BoxDecoration(
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              page.title,
                              style: (isActive
                                      ? KubusTextStyles.navLabel
                                      : KubusTextStyles.navMetaLabel)
                                  .copyWith(
                                fontWeight:
                                    isActive ? FontWeight.w600 : FontWeight.w500,
                                color: scheme.onSurface.withValues(
                                  alpha: isActive ? 1.0 : 0.58,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: KubusSpacing.lg),
              Text(
                l10n.commonStepOfTotal(_currentPage + 1, widget.pages.length),
                style: KubusTextStyles.navMetaLabel.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: KubusSpacing.lg),
              if (_currentPage > 0) ...[
                KubusOutlineButton(
                  onPressed: _previousPage,
                  label: l10n.commonBack,
                  icon: Icons.arrow_back,
                  isFullWidth: true,
                ),
                const SizedBox(height: KubusSpacing.sm),
              ],
              KubusButton(
                onPressed: _nextPage,
                label: isLastPage ? l10n.commonGetStarted : l10n.commonContinue,
                isFullWidth: true,
                backgroundColor:
                    widget.pages[_currentPage].gradientColors.first,
                foregroundColor: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Onboarding page data model
class Web3OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  final List<String> features;

  const Web3OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradientColors,
    required this.features,
  });
}
