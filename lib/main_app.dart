import 'package:art_kubus/services/share/share_deep_link_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'providers/profile_provider.dart';
import 'providers/deep_link_provider.dart';
import 'providers/deferred_onboarding_provider.dart';
import 'providers/main_tab_provider.dart';
import 'providers/app_refresh_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/collab_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/presence_provider.dart';
import 'core/mobile_shell_registry.dart';
import 'services/telemetry/telemetry_service.dart';
import 'utils/share_deep_link_navigation.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/art/ar_screen.dart';
import 'screens/community/community_screen.dart';
import 'screens/community/profile_screen.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/desktop/desktop_shell.dart';
import 'utils/design_tokens.dart';
import 'utils/keyboard_inset_resolver.dart';
import 'widgets/glass_components.dart';
import 'widgets/kubus_button.dart';
import 'utils/kubus_color_roles.dart';
import 'widgets/navigation/kubus_mobile_navigation_bar.dart';
import 'widgets/mobile_shell_exit_scope.dart';
import 'widgets/user_persona_onboarding_gate.dart';
import 'widgets/tutorial/tutorial_overlay_controller.dart';
import 'widgets/tutorial/tutorial_overlay_presenter.dart';
import 'widgets/tutorial/tutorial_overlay_scope.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  MainTabProvider? _tabProvider;
  int _lastTelemetryIndex = -1;
  bool _didConsumeInitialDeepLink = false;

  late final TutorialOverlayController _tutorialOverlayController;

  // Lazy-mount tabs to avoid initializing heavy surfaces (MapLibre, marker
  // polling, etc.) before the user actually visits them.
  //
  // NOTE: AR is handled separately and is intentionally NOT kept alive when
  // inactive so camera resources are released.
  final Set<int> _mountedTabs = <int>{};

  @override
  void initState() {
    super.initState();
    _tutorialOverlayController = TutorialOverlayController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final index = context.read<MainTabProvider>().currentIndex;
      _syncRefreshVisibility(index);
      _syncTelemetryForIndex(index);
      _lastTelemetryIndex = index;
    });

    // If we arrived via a cold-start deep link, AppInitializer leaves the
    // target pending so the shell can open it using an in-shell context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Desktop is handled inside DesktopShell (it needs DesktopShellScope).
      if (DesktopBreakpoints.isDesktop(context)) return;
      if (_didConsumeInitialDeepLink) return;
      _didConsumeInitialDeepLink = true;

      ShareDeepLinkTarget? target;
      try {
        target = context.read<DeepLinkProvider>().consumePending();
      } catch (_) {
        target = null;
      }
      if (target == null) return;

      // ignore: discarded_futures
      ShareDeepLinkNavigation.open(context, target);
      try {
        context.read<DeferredOnboardingProvider>().markInitialDeepLinkHandled();
      } catch (_) {}
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<MainTabProvider>(context);
    if (_tabProvider == provider) return;
    _tabProvider?.removeListener(_handleTabProviderChanged);
    _tabProvider = provider;
    _tabProvider?.addListener(_handleTabProviderChanged);
  }

  void _handleTabProviderChanged() {
    if (!mounted) return;
    final index = _tabProvider?.currentIndex ?? 0;
    if (_lastTelemetryIndex == 0 && index != 0) {
      _tutorialOverlayController.deactivateOwner(
        'mobile-map',
        reason: 'mobile-shell-tab-change',
      );
    }
    if (index == _lastTelemetryIndex) return;
    _lastTelemetryIndex = index;

    // Track that this tab has been visited so the widget can be mounted.
    _mountedTabs.add(index);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncRefreshVisibility(index);
      _syncTelemetryForIndex(index);
    });
  }

  @override
  void dispose() {
    MobileShellRegistry.instance.unregister(context);
    _tabProvider?.removeListener(_handleTabProviderChanged);
    _tabProvider = null;
    _tutorialOverlayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use screen-based breakpoints (not platform) so large tablets get desktop
    // UI and mobile browsers on web stay on the phone layout.
    final useDesktopLayout = DesktopBreakpoints.isDesktop(context);

    if (useDesktopLayout) {
      return const DesktopShell();
    }

    MobileShellRegistry.instance.register(context);

    final currentIndex = context.watch<MainTabProvider>().currentIndex;
    final keyboardVisible = KeyboardInsetResolver.isKeyboardVisible(context);

    // Ensure the currently visible tab is mounted.
    _mountedTabs.add(currentIndex);

    final mapNeedsPlatformViewBackgroundPassthrough =
        kIsWeb && currentIndex == 0;

    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      resizeToAvoidBottomInset: true,
      body: IndexedStack(
        index: currentIndex,
        // Keep heavy AR resources out of the tree unless the AR tab is active.
        children: _buildScreens(currentIndex),
      ),
      bottomNavigationBar: keyboardVisible ? null : _buildBottomNavigationBar(),
    );

    // On web, MapLibre is rendered via a platform view (MapLibre GL JS).
    // When using the CanvasKit renderer, any full-screen Flutter-painted
    // background can end up covering the DOM-based map surface.
    //
    // Keep the kubus gradient everywhere else, but let the map tab "punch
    // through" so the web map remains visible.
    final shell = UserPersonaOnboardingGate(
      child: MobileShellExitScope(
        child: mapNeedsPlatformViewBackgroundPassthrough
            ? scaffold
            : KubusProductBackground(child: scaffold),
      ),
    );

    return TutorialOverlayScope(
      controller: _tutorialOverlayController,
      child: Stack(
        children: [
          shell,
          Positioned.fill(
            child: TutorialOverlayPresenter(
              controller: _tutorialOverlayController,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildScreens(int currentIndex) {
    const screens = <Widget>[
      MapScreen(),
      ARScreen(),
      CommunityScreen(),
      HomeScreen(),
      ProfileScreenWrapper(),
    ];

    return List<Widget>.generate(screens.length, (tabIndex) {
      // Only build AR when selected so the camera is released when not in use.
      if (tabIndex == 1 && currentIndex != 1) {
        return const SizedBox.shrink(key: ValueKey('ar-placeholder'));
      }

      // For all other tabs: mount lazily to avoid expensive init work at app
      // startup.
      if (!_mountedTabs.contains(tabIndex)) {
        return SizedBox.shrink(
            key: ValueKey<String>('tab-$tabIndex-placeholder'));
      }

      // IndexedStack keeps inactive tabs alive but does NOT mute their
      // tickers: every ambient animation (gradient backgrounds, pulses)
      // on a hidden tab kept running at frame rate, burning CPU/battery
      // with zero visible output. TickerMode silences them while hidden;
      // state is preserved and animations resume when the tab is shown.
      return TickerMode(
        enabled: tabIndex == currentIndex,
        child: screens[tabIndex],
      );
    });
  }

  Widget _buildBottomNavigationBar() {
    final l10n = AppLocalizations.of(context)!;
    final currentIndex = context.watch<MainTabProvider>().currentIndex;
    final isSignedIn =
        context.select<ProfileProvider, bool>((p) => p.isSignedIn);
    return KubusMobileNavigationBar(
      semanticLabel: l10n.mobileNavSemanticLabel,
      selectedIndex: currentIndex,
      onSelected: _handleNavTap,
      destinations: [
        KubusMobileNavigationDestination(
          key: const Key('mobile_nav_map'),
          icon: Icons.explore_outlined,
          selectedIcon: Icons.explore,
          label: l10n.mobileNavMap,
        ),
        KubusMobileNavigationDestination(
          key: const Key('mobile_nav_ar'),
          icon: Icons.view_in_ar_outlined,
          selectedIcon: Icons.view_in_ar,
          label: l10n.mobileNavAr,
        ),
        KubusMobileNavigationDestination(
          key: const Key('mobile_nav_community'),
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          label: l10n.mobileNavCommunity,
        ),
        KubusMobileNavigationDestination(
          key: const Key('mobile_nav_home'),
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          label: l10n.mobileNavHome,
        ),
        KubusMobileNavigationDestination(
          key: const Key('mobile_nav_profile'),
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: isSignedIn ? l10n.mobileNavProfile : l10n.mobileNavAccount,
        ),
      ],
    );
  }

  void _handleNavTap(int index) {
    final tabs = context.read<MainTabProvider>();
    if (tabs.currentIndex == index) return;

    // If onboarding is deferred due to a cold-start deep link, show it
    // once the user tries to navigate away from the deep-linked surface.
    final deferredOnboarding = context.read<DeferredOnboardingProvider>();
    if (deferredOnboarding.maybeShowOnboarding(context)) return;

    if (tabs.currentIndex == 0 && index != 0) {
      _tutorialOverlayController.deactivateOwner(
        'mobile-map',
        reason: 'mobile-shell-nav-tap',
      );
    }
    tabs.setIndex(index);
  }

  void _syncTelemetryForIndex(int index) {
    if (DesktopBreakpoints.isDesktop(context)) return;
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);

    String name;
    String route;

    switch (index) {
      case 0:
        name = 'MainTabMap';
        route = '/main/tab/map';
        break;
      case 1:
        name = 'MainTabAR';
        route = '/main/tab/ar';
        break;
      case 2:
        name = 'MainTabCommunity';
        route = '/main/tab/community';
        break;
      case 3:
        name = 'MainTabHome';
        route = '/main/tab/home';
        break;
      case 4:
        if (!profileProvider.isSignedIn) {
          name = 'GuestAccount';
          route = '/main/tab/account';
        } else {
          name = 'MainTabProfile';
          route = '/main/tab/profile';
        }
        break;
      default:
        name = 'MainTabUnknown';
        route = '/main/tab/unknown';
    }

    TelemetryService().setActiveScreen(screenName: name, screenRoute: route);
  }

  void _syncRefreshVisibility(int index) {
    if (DesktopBreakpoints.isDesktop(context)) return;
    try {
      final refreshProvider =
          Provider.of<AppRefreshProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final notificationProvider =
          Provider.of<NotificationProvider>(context, listen: false);
      final presenceProvider =
          Provider.of<PresenceProvider>(context, listen: false);
      final collabProvider =
          Provider.of<CollabProvider>(context, listen: false);
      final isCommunity = index == 2;
      final isProfile = index == 4;

      refreshProvider.setViewActive(
          AppRefreshProvider.viewCommunity, isCommunity);
      refreshProvider.setViewActive(AppRefreshProvider.viewChat, isCommunity);
      refreshProvider.setViewActive(
          AppRefreshProvider.viewNotifications, isCommunity);
      refreshProvider.setViewActive(AppRefreshProvider.viewProfile, isProfile);
      chatProvider.handleViewVisibilityChanged();
      notificationProvider.handleViewVisibilityChanged();
      presenceProvider.handleViewVisibilityChanged();
      collabProvider.handleViewVisibilityChanged();
    } catch (_) {}
  }
}

/// Wrapper widget that checks authentication before showing profile screen
class ProfileScreenWrapper extends StatelessWidget {
  const ProfileScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);

    if (!profileProvider.isSignedIn) {
      return const GuestAccountScreen();
    }

    return const ProfileScreen();
  }
}

/// Wrapper widget for sign-in screen with proper theming
class SignInScreenWrapper extends StatelessWidget {
  const SignInScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const SignInScreen();
  }
}

/// A real account destination for guests. It deliberately retains the fifth
/// tab so primary navigation indexes and deep-link contracts stay stable.
class GuestAccountScreen extends StatelessWidget {
  const GuestAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations)!;
    final roles = KubusColorRoles.of(context);
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Align(
        alignment: const Alignment(0, -0.2),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            KubusSpacing.lg,
            KubusSpacing.lg,
            KubusSpacing.lg,
            KubusLayout.mainBottomNavBarHeight + KubusSpacing.lg,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.authSignInTitle,
                    style: textTheme.headlineSmall?.copyWith(
                      color: roles.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: KubusSpacing.sm),
                Text(
                  l10n.activationGateBody,
                  style: textTheme.bodyLarge?.copyWith(
                    color: roles.foregroundMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: KubusSpacing.lg),
                KubusButton(
                  key: const Key('guest_account_sign_in'),
                  label: l10n.commonSignIn,
                  isFullWidth: true,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                  ),
                ),
                const SizedBox(height: KubusSpacing.sm),
                KubusButton(
                  key: const Key('guest_account_create_account'),
                  label: l10n.commonCreateAccount,
                  variant: KubusButtonVariant.secondary,
                  isFullWidth: true,
                  onPressed: () => Navigator.of(context).pushNamed('/register'),
                ),
                const SizedBox(height: KubusSpacing.md),
                Text(
                  l10n.activationGateKeepBrowsingHint,
                  style: textTheme.bodySmall?.copyWith(
                    color: roles.foregroundSubtle,
                  ),
                ),
                const SizedBox(height: KubusSpacing.lg),
                Divider(height: 1, thickness: 1, color: roles.rule),
                const SizedBox(height: KubusSpacing.xs),
                // Language, appearance, accessibility and analytics consent
                // apply without an account, so settings stay reachable.
                KubusButton(
                  key: const Key('guest_account_settings'),
                  label: l10n.settingsTitle,
                  icon: Icons.settings_outlined,
                  variant: KubusButtonVariant.quiet,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
