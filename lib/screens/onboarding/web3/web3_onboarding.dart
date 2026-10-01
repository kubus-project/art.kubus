import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../config/config.dart';
import '../../../services/onboarding_state_service.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../widgets/common/kubus_context_icon.dart';
import '../../../widgets/kubus_button.dart';
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

    final roles = KubusColorRoles.of(context);
    return ColoredBox(
      color: roles.ground,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
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
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final currentStep = _currentPage + 1;
    final totalSteps = widget.pages.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        KubusSpacing.lg,
        KubusSpacing.sm,
        KubusSpacing.sm,
        KubusSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: roles.rule, width: KubusSizes.hairline),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.featureTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: roles.foreground,
                  ),
            ),
          ),
          if (totalSteps > 0)
            Text(
              '$currentStep / $totalSteps',
              style: KubusTextStyles.machineValue.copyWith(
                color: roles.foregroundMuted,
              ),
            ),
          const SizedBox(width: KubusSpacing.xs),
          TextButton(
            onPressed: _skipOnboarding,
            style: TextButton.styleFrom(
              foregroundColor: roles.foreground,
              minimumSize: const Size(48, 44),
            ),
            child: Text(l10n.commonSkip),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            isTablet ? KubusSpacing.xl : KubusSpacing.lg,
            KubusSpacing.xl,
            isTablet ? KubusSpacing.xl : KubusSpacing.lg,
            KubusSpacing.lg,
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Web3OnboardingPageBody(
                icon: page.icon,
                title: page.title,
                description: page.description,
                features: page.features,
                large: isTablet,
                accent: Web3OnboardingPageBody.accentFor(
                  KubusColorRoles.of(context),
                  widget.featureKey,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigation() {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        KubusSpacing.lg,
        KubusSpacing.md,
        KubusSpacing.lg,
        KubusSpacing.md,
      ),
      decoration: BoxDecoration(
        color: roles.surface,
        border: Border(
          top: BorderSide(color: roles.rule, width: KubusSizes.hairline),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Web3OnboardingProgress(
            count: widget.pages.length,
            current: _currentPage,
            label:
                l10n.commonStepOfTotal(_currentPage + 1, widget.pages.length),
          ),
          const SizedBox(height: KubusSpacing.md),
          Row(
            children: [
              if (_currentPage > 0) ...[
                Expanded(
                  child: KubusButton(
                    onPressed: _previousPage,
                    label: l10n.commonBack,
                    variant: KubusButtonVariant.secondary,
                    isFullWidth: true,
                  ),
                ),
                const SizedBox(width: KubusSpacing.sm),
              ],
              Expanded(
                flex: _currentPage == 0 ? 1 : 2,
                child: KubusButton(
                  onPressed: _nextPage,
                  label: _currentPage == widget.pages.length - 1
                      ? l10n.commonGetStarted
                      : l10n.commonNext,
                  isFullWidth: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Page body shared by the mobile and desktop feature introductions: the
/// feature's hero context tile, title, lede and a plain check list. The
/// colour belongs to
/// the feature ([accentFor]: governance green, studio coral, institution
/// blue, marketplace orange), not to the page, so a four-page intro does not
/// cycle through a rainbow.
class Web3OnboardingPageBody extends StatelessWidget {
  const Web3OnboardingPageBody({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.features,
    this.large = false,
    this.accent,
  });

  /// Feature colour; see [accentFor]. Defaults to the family active colour.
  final Color? accent;

  /// The intro colour for a feature key (`DAO`, `Artist Studio`, …).
  static Color accentFor(KubusColorRoles roles, String featureKey) {
    final key = featureKey.trim().toLowerCase().replaceAll(' ', '_');
    const known = {'dao', 'artist_studio', 'institution_hub', 'marketplace'};
    return known.contains(key) ? roles.web3AccentForKey(key) : roles.active;
  }

  final IconData icon;
  final String title;
  final String description;
  final List<String> features;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final textTheme = Theme.of(context).textTheme;
    final tone = accent ?? roles.active;
    // No ghost glyph here: the body is reading text from edge to edge.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        KubusContextIcon(
          icon: icon,
          accent: tone,
          size: KubusContextIconSize.hero,
        ),
        const SizedBox(height: KubusSpacing.lg),
        Semantics(
          header: true,
          child: Text(
            title,
            style: (large ? textTheme.displaySmall : textTheme.headlineMedium)
                ?.copyWith(
              color: roles.foreground,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        Text(
          description,
          style: textTheme.bodyLarge?.copyWith(
            color: roles.foregroundMuted,
            height: 1.5,
          ),
        ),
        if (features.isNotEmpty) ...[
          const SizedBox(height: KubusSpacing.xl),
          Text(
            // Structural labels carry no trailing punctuation.
            l10n.web3OnboardingKeyFeaturesTitle
                .replaceAll(RegExp(r'[:\s]+$'), '')
                .toUpperCase(),
            style: KubusTextStyles.structuralLabel.copyWith(
              color: roles.foregroundMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: KubusSpacing.sm),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.check, size: 18, color: roles.success),
                  ),
                  const SizedBox(width: KubusSpacing.sm),
                  Expanded(
                    child: Text(
                      feature,
                      style: textTheme.bodyMedium?.copyWith(
                        color: roles.foreground,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// Neutral step indicator: the current step is wider and uses the family
/// active role; the text label carries the same information for readers.
class Web3OnboardingProgress extends StatelessWidget {
  const Web3OnboardingProgress({
    super.key,
    required this.count,
    required this.current,
    required this.label,
  });

  final int count;
  final int current;
  final String label;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              count,
              (index) => AnimatedContainer(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: index == current ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: index == current
                      ? roles.active
                      : index < current
                          ? roles.ruleStrong
                          : roles.rule,
                  borderRadius: BorderRadius.circular(KubusRadius.pill),
                ),
              ),
            ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          Text(
            label,
            style: KubusTextStyles.machineValue.copyWith(
              color: roles.foregroundSubtle,
            ),
          ),
        ],
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
