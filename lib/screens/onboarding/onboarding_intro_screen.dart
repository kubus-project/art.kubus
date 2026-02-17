import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/screens/desktop/desktop_shell.dart';
import 'package:art_kubus/screens/onboarding/onboarding_flow_screen.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/app_logo.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/gradient_icon_card.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:flutter/material.dart';

class OnboardingIntroScreen extends StatefulWidget {
  const OnboardingIntroScreen({
    super.key,
    this.forceDesktop = false,
  });

  final bool forceDesktop;

  @override
  State<OnboardingIntroScreen> createState() => _OnboardingIntroScreenState();
}

class _OnboardingIntroScreenState extends State<OnboardingIntroScreen> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;

  bool get _isDesktop =>
      widget.forceDesktop || DesktopBreakpoints.isDesktop(context);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_pageIndex >= _pagesCount - 1) {
      _goToOnboardingFlow();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _goBack() {
    if (_pageIndex <= 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _goToOnboardingFlow() {
    final navigator = Navigator.of(context);
    final route = MaterialPageRoute(
      builder: (_) => OnboardingFlowScreen(
        forceDesktop: _isDesktop,
        initialStepId: 'account',
      ),
      settings: const RouteSettings(name: '/onboarding/flow'),
    );
    navigator.pushReplacement(route);
  }

  void _goToSignIn() {
    Navigator.of(context).pushNamed('/sign-in');
  }

  int get _pagesCount => 3;

  List<_IntroPage> _pages(AppLocalizations l10n, ColorScheme scheme) {
    final roles = KubusColorRoles.of(context);
    return <_IntroPage>[
      _IntroPage(
        icon: Icons.auto_awesome_outlined,
        title: l10n.onboardingFlowWelcomeTitle,
        body: l10n.onboardingFlowWelcomeBody,
        iconStart: roles.statTeal,
        iconEnd: roles.statBlue,
        backgroundColors: <Color>[
          roles.statTeal.withValues(alpha: 0.92),
          scheme.primary.withValues(alpha: 0.88),
          roles.statBlue.withValues(alpha: 0.82),
          roles.statTeal.withValues(alpha: 0.92),
        ],
      ),
      _IntroPage(
        icon: Icons.map_outlined,
        title: l10n.permissionsLocationSubtitle,
        body: l10n.permissionsLocationBenefit1,
        iconStart: roles.statBlue,
        iconEnd: roles.statGreen,
        backgroundColors: <Color>[
          roles.statBlue.withValues(alpha: 0.90),
          roles.statGreen.withValues(alpha: 0.86),
          roles.positiveAction.withValues(alpha: 0.82),
          roles.statBlue.withValues(alpha: 0.90),
        ],
      ),
      _IntroPage(
        icon: Icons.view_in_ar_outlined,
        title: l10n.permissionsCameraSubtitle,
        body: l10n.permissionsCameraBenefit1,
        iconStart: roles.statAmber,
        iconEnd: roles.statCoral,
        backgroundColors: <Color>[
          roles.statAmber.withValues(alpha: 0.90),
          roles.statCoral.withValues(alpha: 0.86),
          roles.negativeAction.withValues(alpha: 0.82),
          roles.statAmber.withValues(alpha: 0.90),
        ],
      ),
    ];
  }

  Widget _buildDots({
    required int count,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(count, (index) {
        final active = index == _pageIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final pages = _pages(l10n, scheme);
    final page = pages[_pageIndex.clamp(0, pages.length - 1)];
    final bgColors = page.backgroundColors;

    final horizontalPadding = _isDesktop ? KubusSpacing.xl : KubusSpacing.lg;

    return AnimatedGradientBackground(
      animate: true,
      intensity: 0.22,
      colors: bgColors,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              KubusSpacing.md,
              horizontalPadding,
              KubusSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppLogo(
                    width: _isDesktop ? 44 : 38,
                    height: _isDesktop ? 44 : 38,
                  ),
                ),
                const SizedBox(height: KubusSpacing.md),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(maxWidth: _isDesktop ? 720 : 520),
                      child: LiquidGlassPanel(
                        borderRadius: BorderRadius.circular(KubusRadius.xl),
                        padding: const EdgeInsets.fromLTRB(
                          KubusSpacing.lg,
                          KubusSpacing.lg,
                          KubusSpacing.lg,
                          KubusSpacing.lg,
                        ),
                        fallbackMinOpacity: 0.28,
                        backgroundColor: scheme.surface.withValues(alpha: 0.12),
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: pages.length,
                          onPageChanged: (index) {
                            setState(() => _pageIndex = index);
                          },
                          itemBuilder: (context, index) {
                            return _IntroPageView(page: pages[index]);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: KubusSpacing.md),
                _buildDots(count: pages.length),
                const SizedBox(height: KubusSpacing.md),
                KubusButton(
                  onPressed: _goNext,
                  label: l10n.commonContinue,
                  backgroundColor: Colors.black.withValues(alpha: 0.28),
                  foregroundColor: Colors.white,
                  isFullWidth: true,
                ),
                const SizedBox(height: KubusSpacing.xs),
                Row(
                  children: [
                    if (_pageIndex > 0)
                      TextButton(
                        onPressed: _goBack,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.14),
                          padding: const EdgeInsets.symmetric(
                            horizontal: KubusSpacing.sm,
                            vertical: KubusSpacing.xs,
                          ),
                        ),
                        child: Text(l10n.commonBack),
                      )
                    else
                      const SizedBox(width: 72),
                    const Spacer(),
                    TextButton(
                      onPressed: _goToSignIn,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.14),
                        padding: const EdgeInsets.symmetric(
                          horizontal: KubusSpacing.sm,
                          vertical: KubusSpacing.xs,
                        ),
                      ),
                      child: Text(l10n.commonSignIn),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroPage {
  const _IntroPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.iconStart,
    required this.iconEnd,
    required this.backgroundColors,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color iconStart;
  final Color iconEnd;
  final List<Color> backgroundColors;
}

class _IntroPageView extends StatelessWidget {
  const _IntroPageView({required this.page});

  final _IntroPage page;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final compact = height < 360;
        final tight = height < 300;

        final iconCardSize = tight ? 78.0 : (compact ? 92.0 : 112.0);
        final iconSize = tight ? 38.0 : (compact ? 46.0 : 56.0);

        final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: compact ? 22 : null,
              color: Colors.white,
            );

        final bodyStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.35,
              fontSize: compact ? 14 : null,
            );

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GradientIconCard(
              start: page.iconStart,
              end: page.iconEnd,
              icon: page.icon,
              width: iconCardSize,
              height: iconCardSize,
              radius: KubusRadius.lg,
              iconSize: iconSize,
            ),
            SizedBox(height: compact ? KubusSpacing.md : KubusSpacing.lg),
            Text(
              page.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
            const SizedBox(height: KubusSpacing.sm),
            Text(
              page.body,
              textAlign: TextAlign.center,
              maxLines: tight ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: bodyStyle,
            ),
          ],
        );
      },
    );
  }
}
