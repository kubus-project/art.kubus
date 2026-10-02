import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../providers/themeprovider.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../onboarding/web3/web3_onboarding.dart' show Web3OnboardingPageBody;
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
  /// Breathing room above/below the centred page column, and the matching
  /// inset used by the sidebar so both columns share one optical centre.
  static const double _pageContentVerticalPadding = 32;

  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
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

    final roles = KubusColorRoles.of(context);

    final contentWidth = screenWidth > DesktopBreakpoints.large
        ? 1400.0
        : screenWidth > DesktopBreakpoints.expanded
            ? 1100.0
            : 900.0;

    return ColoredBox(
      color: roles.ground,
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
        body: Padding(
          // The app bar is painted behind the body (extendBodyBehindAppBar), so
          // the area we centre within is the space below the back / Skip row.
          padding: EdgeInsets.only(
            top: kToolbarHeight + MediaQuery.paddingOf(context).top,
          ),
          child: Center(
            child: Container(
              width: contentWidth,
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
      ),
    );
  }

  Widget _buildPageContent(Web3OnboardingPage page) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minHeight =
              constraints.maxHeight - _pageContentVerticalPadding * 2;
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 40,
              vertical: _pageContentVerticalPadding,
            ),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: minHeight > 0 ? minHeight : 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Web3OnboardingPageBody(
                    icon: page.icon,
                    title: page.title,
                    description: page.description,
                    features: page.features,
                    large: true,
                    accent: Web3OnboardingPageBody.accentFor(
                      KubusColorRoles.of(context),
                      widget.featureKey,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSidebar(Color accentColor, AppAnimationTheme animationTheme) {
    final l10n = AppLocalizations.of(context)!;
    final isLastPage = _currentPage == widget.pages.length - 1;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      // Symmetric vertical inset: an asymmetric one would visibly offset the
      // sidebar from the centre it now shares with the page column.
      padding: const EdgeInsets.only(
        right: 40,
        top: _pageContentVerticalPadding,
        bottom: _pageContentVerticalPadding,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: KubusColorRoles.of(context).surface,
          borderRadius: BorderRadius.circular(KubusRadius.sheet),
          border: Border.all(
            color: KubusColorRoles.of(context).rule,
            width: KubusSizes.hairline,
          ),
        ),
        // Now that the sidebar is vertically centred it is free-height, so a
        // long step list on a short window must scroll rather than overflow.
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(KubusSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The flow name heads the step list only when no step
                // already carries it; otherwise the first step and the page
                // heading would say it a second and third time.
                if (!widget.pages
                    .any((p) => p.title == widget.featureTitle)) ...[
                  Text(
                    widget.featureTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: KubusColorRoles.of(context).foreground,
                        ),
                  ),
                  const SizedBox(height: KubusSpacing.xl),
                ],
                ...widget.pages.asMap().entries.map((entry) {
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
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(KubusSpacing.md),
                        decoration: BoxDecoration(
                          color: isActive
                              ? KubusColorRoles.of(context)
                                  .active
                                  .withValues(alpha: 0.10)
                              : Colors.transparent,
                          borderRadius:
                              BorderRadius.circular(KubusRadius.surface),
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: animationTheme.short,
                              width: isActive ? 32 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? KubusColorRoles.of(context).active
                                    : isPast
                                        ? KubusColorRoles.of(context).ruleStrong
                                        : KubusColorRoles.of(context).rule,
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
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.w500,
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
                  KubusButton(
                    onPressed: _previousPage,
                    label: l10n.commonBack,
                    icon: Icons.arrow_back,
                    variant: KubusButtonVariant.secondary,
                    isFullWidth: true,
                  ),
                  const SizedBox(height: KubusSpacing.sm),
                ],
                KubusButton(
                  onPressed: _nextPage,
                  label:
                      isLastPage ? l10n.commonGetStarted : l10n.commonContinue,
                  isFullWidth: true,
                ),
              ],
            ),
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
