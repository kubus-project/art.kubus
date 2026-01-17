import 'dart:async';

import 'package:art_kubus/utils/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../providers/themeprovider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/recent_activity_provider.dart';
import '../../providers/deep_link_provider.dart';
import '../../providers/deferred_onboarding_provider.dart';
import '../../config/config.dart';
import '../../models/recent_activity.dart';
import '../../utils/activity_navigation.dart';
import '../../services/telemetry/telemetry_service.dart';
import '../../utils/kubus_color_roles.dart';
import 'desktop_home_screen.dart';
import 'desktop_map_screen.dart';
import 'community/desktop_community_screen.dart';
import 'web3/desktop_marketplace_screen.dart';
import 'web3/desktop_wallet_screen.dart';
import 'web3/desktop_artist_studio_screen.dart';
import 'web3/desktop_institution_hub_screen.dart';
import 'web3/desktop_governance_hub_screen.dart';
import 'desktop_settings_screen.dart';
import 'components/desktop_navigation.dart';
import 'community/desktop_profile_screen.dart';
import '../auth/sign_in_screen.dart';
import '../onboarding/web3/web3_onboarding.dart' as web3;
import '../onboarding/web3/onboarding_data.dart';
import '../web3/wallet/connectwallet_screen.dart';
import '../collab/invites_inbox_screen.dart';
import '../../widgets/user_persona_onboarding_gate.dart';
import '../../widgets/recent_activity_tile.dart';
import '../../widgets/glass_components.dart';
import '../../utils/share_deep_link_navigation.dart';
import '../../services/share/share_deep_link_parser.dart';

/// Provides in-shell navigation for subscreens that should appear in the main
/// content area instead of pushing a fullscreen route.
///
/// Usage:
/// ```dart
/// DesktopShellScope.of(context)?.pushScreen(const MySubScreen());
/// // or pop back:
/// DesktopShellScope.of(context)?.popScreen();
/// // or switch tabs:
/// DesktopShellScope.of(context)?.navigateToRoute('/community');
/// ```
class DesktopShellScope extends InheritedWidget {
  final void Function(Widget screen) pushScreen;
  final VoidCallback popScreen;
  final void Function(String route) navigateToRoute;
  final VoidCallback openNotifications;
  final void Function(DesktopFunctionsPanel panel, {Widget? content})
      openFunctionsPanel;
  final void Function(Widget content) setFunctionsPanelContent;
  final VoidCallback closeFunctionsPanel;
  final bool canPop;

  const DesktopShellScope({
    super.key,
    required this.pushScreen,
    required this.popScreen,
    required this.navigateToRoute,
    required this.openNotifications,
    required this.openFunctionsPanel,
    required this.setFunctionsPanelContent,
    required this.closeFunctionsPanel,
    required this.canPop,
    required super.child,
  });

  static DesktopShellScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DesktopShellScope>();
  }

  @override
  bool updateShouldNotify(DesktopShellScope oldWidget) {
    return canPop != oldWidget.canPop;
  }
}

enum DesktopFunctionsPanel {
  none,
  notifications,
  exploreNearby,
}

/// Responsive breakpoints for layout switching
class DesktopBreakpoints {
  static const double compact = 600;
  static const double medium = 900;
  static const double expanded = 1200;
  static const double large = 1600;

  static bool isCompact(BuildContext context) =>
      MediaQuery.of(context).size.width < compact;
  static bool isMedium(BuildContext context) =>
      MediaQuery.of(context).size.width >= compact &&
      MediaQuery.of(context).size.width < medium;
  static bool isExpanded(BuildContext context) =>
      MediaQuery.of(context).size.width >= medium &&
      MediaQuery.of(context).size.width < expanded;
  static bool isLarge(BuildContext context) =>
      MediaQuery.of(context).size.width >= expanded;
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= medium;
}

/// Main desktop shell that provides the sleek sidebar navigation
/// inspired by Twitter/X, Google Maps, and Instagram
class DesktopShell extends StatefulWidget {
  final int initialIndex;

  const DesktopShell({super.key, this.initialIndex = 0});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell>
    with TickerProviderStateMixin {
  static const String _walletRoute = '/wallet';
  static const String _web3EntryRoute = '/web3';
  late String _activeRoute;
  bool _isNavigationExpanded = true;
  late AnimationController _navExpandController;
  late Animation<double> _navExpandAnimation;

  DesktopFunctionsPanel _functionsPanel = DesktopFunctionsPanel.none;
  Widget? _functionsPanelContent;

  /// Stack of screens pushed via DesktopShellScope.pushScreen
  /// When empty, shows the route-based screen from _buildCurrentScreen
  final List<Widget> _screenStack = [];

  BuildContext? _shellScopeContext;
  bool _didConsumeInitialDeepLink = false;

  static const List<DesktopNavItem> _signedInNavItems = [
    DesktopNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
      route: '/home',
    ),
    DesktopNavItem(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
      label: 'Explore',
      route: '/explore',
    ),
    DesktopNavItem(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: 'Connect',
      route: '/community',
    ),
    DesktopNavItem(
      icon: Icons.palette_outlined,
      activeIcon: Icons.palette,
      label: 'Create',
      route: '/artist-studio',
    ),
    DesktopNavItem(
      icon: Icons.apartment_outlined,
      activeIcon: Icons.apartment,
      label: 'Organize',
      route: '/institution',
    ),
    DesktopNavItem(
      icon: Icons.account_balance_outlined,
      activeIcon: Icons.account_balance,
      label: 'Govern',
      route: '/governance',
    ),
    DesktopNavItem(
      icon: Icons.storefront_outlined,
      activeIcon: Icons.storefront,
      label: 'Trade',
      route: '/marketplace',
    ),
  ];

  static const List<DesktopNavItem> _guestNavItems = [
    DesktopNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
      route: '/home',
    ),
    DesktopNavItem(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
      label: 'Explore',
      route: '/explore',
    ),
    DesktopNavItem(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: 'Connect',
      route: '/community',
    ),
    DesktopNavItem(
      icon: Icons.hub_outlined,
      activeIcon: Icons.hub,
      label: 'Web3',
      route: _web3EntryRoute,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _activeRoute = _signedInNavItems[
            widget.initialIndex.clamp(0, _signedInNavItems.length - 1)]
        .route;
    _navExpandController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _navExpandAnimation = CurvedAnimation(
      parent: _navExpandController,
      curve: Curves.easeOutCubic,
    );
    if (_isNavigationExpanded) {
      _navExpandController.value = 1.0;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncTelemetry();
    });
  }

  @override
  void dispose() {
    _navExpandController.dispose();
    super.dispose();
  }

  /// Push a screen onto the in-shell stack (stays within main content area)
  void _pushScreenToStack(Widget screen) {
    // If we are leaving the Explore map surface, make sure the map-specific
    // functions panel (Nearby) does not linger.
    if (_activeRoute == '/explore' &&
        _functionsPanel == DesktopFunctionsPanel.exploreNearby) {
      _closeFunctionsPanel();
    }
    setState(() {
      _screenStack.add(screen);
    });
    _syncTelemetry();
  }

  /// Pop a screen from the in-shell stack
  void _popScreenFromStack() {
    if (_screenStack.isNotEmpty) {
      setState(() {
        _screenStack.removeLast();
      });
      _syncTelemetry();
    }
  }

  /// Navigate to a specific route within the shell (clears screen stack)
  void _navigateToRoute(String route) {
    final leavingExplore = _activeRoute == '/explore' && route != '/explore';
    if (leavingExplore &&
        _functionsPanel == DesktopFunctionsPanel.exploreNearby) {
      _closeFunctionsPanel();
    }
    setState(() {
      _activeRoute = route;
      _screenStack.clear();
    });
    _syncTelemetry();
  }

  void _toggleNavigation() {
    setState(() {
      _isNavigationExpanded = !_isNavigationExpanded;
    });
    if (_isNavigationExpanded) {
      _navExpandController.forward();
    } else {
      _navExpandController.reverse();
    }
  }

  void _closeFunctionsPanel() {
    if (_functionsPanel == DesktopFunctionsPanel.none) return;
    setState(() {
      _functionsPanel = DesktopFunctionsPanel.none;
      _functionsPanelContent = null;
    });
    try {
      context.read<RecentActivityProvider>().markAllReadLocally();
    } catch (_) {}
  }

  Future<void> _toggleNotificationsPanel() async {
    if (_functionsPanel == DesktopFunctionsPanel.notifications) {
      _closeFunctionsPanel();
      return;
    }

    final activityProvider = context.read<RecentActivityProvider>();
    final notificationProvider = context.read<NotificationProvider>();

    if (activityProvider.initialized) {
      await activityProvider.refresh(force: true);
    } else {
      await activityProvider.initialize(force: true);
    }

    if (!mounted) return;
    await notificationProvider.markViewed();
    if (!mounted) return;

    setState(() {
      _functionsPanel = DesktopFunctionsPanel.notifications;
      _functionsPanelContent = null;
    });
  }

  void _openFunctionsPanel(DesktopFunctionsPanel panel, {Widget? content}) {
    if (panel == DesktopFunctionsPanel.none) {
      _closeFunctionsPanel();
      return;
    }

    setState(() {
      _functionsPanel = panel;
      if (panel == DesktopFunctionsPanel.exploreNearby) {
        _functionsPanelContent = content ?? _functionsPanelContent;
      } else {
        _functionsPanelContent = null;
      }
    });
  }

  void _setFunctionsPanelContent(Widget content) {
    if (_functionsPanel != DesktopFunctionsPanel.exploreNearby) return;
    setState(() {
      _functionsPanelContent = content;
    });
  }

  void _onNavItemSelected(
      int index, List<DesktopNavItem> navItems, bool isSignedIn) {
    if (index < 0 || index >= navItems.length) return;
    final item = navItems[index];

    if (!isSignedIn && item.route == _web3EntryRoute) {
      _startWeb3OnboardingFlow();
      return;
    }

    final leavingExplore = _activeRoute == '/explore' && item.route != '/explore';
    if (leavingExplore &&
        _functionsPanel == DesktopFunctionsPanel.exploreNearby) {
      _closeFunctionsPanel();
    }

    setState(() {
      _activeRoute = item.route;
      // Clear any pushed subscreens when navigating to a new main tab
      _screenStack.clear();
    });
    _syncTelemetry();
  }

  List<Color>? _backgroundColorsForRoute(BuildContext context, String route) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final roles = KubusColorRoles.of(context);
    final themeProvider = context.read<ThemeProvider>();

    Color? accent;
    switch (route) {
      case '/artist-studio':
        accent = roles.web3ArtistStudioAccent;
        break;
      case '/governance':
        accent = roles.web3DaoAccent;
        break;
      case '/institution':
        accent = roles.web3InstitutionAccent;
        break;
      case '/marketplace':
        accent = roles.web3MarketplaceAccent;
        break;
      case '/community':
        accent = themeProvider.accentColor;
        break;
      case _walletRoute:
        accent = scheme.primary;
        break;
      case _web3EntryRoute:
        accent = scheme.secondary;
        break;
      default:
        accent = null;
        break;
    }

    if (accent == null) return null;
    return _blendAccentIntoAnimatedBase(
      base: isDark
          ? KubusGradients.animatedDarkColors
          : KubusGradients.animatedLightColors,
      accent: accent,
      isDark: isDark,
    );
  }

  List<Color> _blendAccentIntoAnimatedBase({
    required List<Color> base,
    required Color accent,
    required bool isDark,
  }) {
    if (base.isEmpty) return <Color>[accent];
    if (base.length == 1) return <Color>[base.first, accent];

    // Blend factors tuned to keep the background subtle while still matching
    // the screen's accent.
    final f1 = isDark ? 0.16 : 0.10;
    final f2 = isDark ? 0.22 : 0.14;
    final f3 = isDark ? 0.14 : 0.10;

    Color lerp(Color a, Color b, double t) => Color.lerp(a, b, t) ?? b;

    final c0 = base[0];
    final c1 = lerp(base.length > 1 ? base[1] : base[0], accent, f1);
    final c2 = lerp(base.length > 2 ? base[2] : base.last, accent, f2);
    final c3 = lerp(base.length > 3 ? base[3] : base.last, accent, f3);
    return <Color>[c0, c1, c2, c3];
  }

  Widget _buildCurrentScreen(String route) {
    switch (route) {
      case '/explore':
        return const DesktopMapScreen();
      case '/community':
        return const DesktopCommunityScreen();
      case '/artist-studio':
        return const DesktopArtistStudioScreen();
      case '/institution':
        return const DesktopInstitutionHubScreen();
      case '/governance':
        return const DesktopGovernanceHubScreen();
      case '/marketplace':
        return const DesktopMarketplaceScreen();
      case _walletRoute:
        return const DesktopWalletScreen();
      case '/home':
      default:
        return const DesktopHomeScreen();
    }
  }

  String _telemetryScreenNameForRoute(String route) {
    switch (route) {
      case '/home':
        return 'DesktopHome';
      case '/explore':
        return 'DesktopExplore';
      case '/community':
        return 'DesktopCommunity';
      case '/artist-studio':
        return 'DesktopArtistStudio';
      case '/institution':
        return 'DesktopInstitutionHub';
      case '/governance':
        return 'DesktopGovernanceHub';
      case '/marketplace':
        return 'DesktopMarketplace';
      case _walletRoute:
        return 'DesktopWallet';
      case _web3EntryRoute:
        return 'DesktopWeb3';
      default:
        return 'DesktopShell';
    }
  }

  void _syncTelemetry() {
    final hasStack = _screenStack.isNotEmpty;
    final screenRoute = hasStack ? '$_activeRoute#sub' : _activeRoute;
    final screenName = hasStack ? _screenStack.last.runtimeType.toString() : _telemetryScreenNameForRoute(_activeRoute);
    TelemetryService().setActiveScreen(screenName: screenName, screenRoute: screenRoute);
  }

  List<DesktopNavItem> _navItemsForState(bool isSignedIn,
      {required bool isArtist, required bool isInstitution}) {
    if (!isSignedIn) {
      return _guestNavItems;
    }

    // Start with all signed-in items
    var items = List<DesktopNavItem>.of(_signedInNavItems);

    // If user has both badges, hide Organize (Institution Hub)
    // If only Institution badge is active, hide Create (Artist Studio)
    // If only Artist badge is active, hide Organize (Institution Hub)
    if (isArtist && isInstitution) {
      // Both badges are active - hide Organize, keep Create
      items = items.where((item) => item.route != '/institution').toList();
    } else if (isInstitution && !isArtist) {
      // Only institution badge is active - hide Create
      items = items.where((item) => item.route != '/artist-studio').toList();
    } else if (isArtist && !isInstitution) {
      // Only artist badge is active - hide Organize
      items = items.where((item) => item.route != '/institution').toList();
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final isSignedIn = profileProvider.isSignedIn;
    final currentUser = profileProvider.currentUser;
    final isArtist = currentUser?.isArtist ?? false;
    final isInstitution = currentUser?.isInstitution ?? false;
    final navItems = _navItemsForState(isSignedIn,
        isArtist: isArtist, isInstitution: isInstitution);
    final isWalletRoute = _activeRoute == _walletRoute;
    final hasActiveRoute = navItems.any((item) => item.route == _activeRoute);
    final effectiveRoute =
        hasActiveRoute || isWalletRoute ? _activeRoute : navItems.first.route;
    if (!hasActiveRoute &&
        !isWalletRoute &&
        _activeRoute != navItems.first.route) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _activeRoute = navItems.first.route;
        });
        _syncTelemetry();
      });
    }
    final selectedIndex =
        navItems.indexWhere((item) => item.route == effectiveRoute);

    final isLarge = DesktopBreakpoints.isLarge(context);
    final isExpanded = DesktopBreakpoints.isExpanded(context);
    final theme = Theme.of(context);

    // Auto-collapse navigation on medium screens
    if (!isLarge && _isNavigationExpanded && !isExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isNavigationExpanded) {
          _toggleNavigation();
        }
      });
    }

    return UserPersonaOnboardingGate(
      child: DesktopShellScope(
        pushScreen: _pushScreenToStack,
        popScreen: _popScreenFromStack,
        navigateToRoute: _navigateToRoute,
        openNotifications: () => unawaited(_toggleNotificationsPanel()),
        openFunctionsPanel: _openFunctionsPanel,
        setFunctionsPanelContent: _setFunctionsPanelContent,
        closeFunctionsPanel: _closeFunctionsPanel,
        canPop: _screenStack.isNotEmpty,
        child: Builder(
          builder: (shellContext) {
            _shellScopeContext ??= shellContext;
            _maybeConsumePendingDeepLink(shellContext);

            return Stack(
              children: [
                Positioned.fill(
                  child: AnimatedGradientBackground(
                    duration: const Duration(seconds: 12),
                    intensity: 0.25,
                    colors: _backgroundColorsForRoute(context, effectiveRoute),
                    child: const SizedBox.expand(),
                  ),
                ),
                Scaffold(
                  backgroundColor: Colors.transparent,
                  body: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _navExpandAnimation,
                        builder: (context, child) {
                          final expandedWidth = isLarge
                              ? DesktopNavigation.expandedWidthLarge
                              : DesktopNavigation.expandedWidthMedium;
                          final collapsedWidth = DesktopNavigation.collapsedWidth;
                          final currentWidth = collapsedWidth +
                              (expandedWidth - collapsedWidth) * _navExpandAnimation.value;

                          final scheme = theme.colorScheme;
                          final glassTint = theme.brightness == Brightness.dark
                              ? Colors.black.withValues(alpha: 0.22)
                              : Colors.white.withValues(alpha: 0.26);

                          return ClipRRect(
                            child: Container(
                              width: currentWidth,
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: theme.brightness == Brightness.dark
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : scheme.outline.withValues(alpha: 0.15),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: LiquidGlassPanel(
                                padding: EdgeInsets.zero,
                                margin: EdgeInsets.zero,
                                borderRadius: BorderRadius.zero,
                                blurSigma: KubusGlassEffects.blurSigmaLight,
                                showBorder: false,
                                backgroundColor: glassTint,
                                child: DesktopNavigation(
                                  items: navItems,
                                  selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
                                  onItemSelected: (index) =>
                                      _onNavItemSelected(index, navItems, isSignedIn),
                                  isExpanded: _isNavigationExpanded,
                                  expandAnimation: _navExpandAnimation,
                                  onToggleExpand: _toggleNavigation,
                                  onProfileTap: () => _showProfileMenu(context),
                                  onSettingsTap: () => _showSettingsScreen(context),
                                  onNotificationsTap: () =>
                                      unawaited(_toggleNotificationsPanel()),
                                  onWalletTap: () => _handleWalletTap(isSignedIn),
                                  onCollabInvitesTap: isSignedIn &&
                                          AppConfig.isFeatureEnabled('collabInvites')
                                      ? () => _showCollabInvites()
                                      : null,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Main content area (takes most space)
                      Expanded(
                        child: _screenStack.isNotEmpty
                            ? _screenStack.last
                            : _buildCurrentScreen(effectiveRoute),
                      ),

                      // Functions sidebar (contextual panels like Notifications)
                      if (isExpanded || isLarge)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          width: _functionsPanel == DesktopFunctionsPanel.none
                              ? 0
                              : (isLarge ? 380 : 320),
                          child: ClipRect(
                            child: IgnorePointer(
                              ignoring: _functionsPanel == DesktopFunctionsPanel.none,
                              child: AnimatedOpacity(
                                opacity: _functionsPanel == DesktopFunctionsPanel.none ? 0 : 1,
                                duration: const Duration(milliseconds: 150),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(
                                        color: theme.brightness == Brightness.dark
                                            ? Colors.white.withValues(alpha: 0.06)
                                            : theme.colorScheme.outline.withValues(alpha: 0.10),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: LiquidGlassPanel(
                                    padding: EdgeInsets.zero,
                                    margin: EdgeInsets.zero,
                                    borderRadius: BorderRadius.zero,
                                    blurSigma: KubusGlassEffects.blurSigmaLight,
                                    showBorder: false,
                                    backgroundColor: theme.colorScheme.surface.withValues(
                                      alpha: theme.brightness == Brightness.dark ? 0.16 : 0.10,
                                    ),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 220),
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      child: switch (_functionsPanel) {
                                        DesktopFunctionsPanel.notifications => _NotificationsPanel(
                                            key: const ValueKey<String>('functions_notifications'),
                                            onClose: _closeFunctionsPanel,
                                            onActivitySelected: (activity) async {
                                              final parentContext = context;
                                              _closeFunctionsPanel();
                                              await ActivityNavigation.open(parentContext, activity);
                                            },
                                          ),
                                        DesktopFunctionsPanel.exploreNearby =>
                                          _functionsPanelContent ?? const SizedBox.shrink(
                                            key: ValueKey<String>('functions_explore_nearby_empty'),
                                          ),
                                        DesktopFunctionsPanel.none => const SizedBox.shrink(
                                          key: ValueKey<String>('functions_empty'),
                                        ),
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _maybeConsumePendingDeepLink(BuildContext shellContext) {
    if (_didConsumeInitialDeepLink) return;

    final ShareDeepLinkTarget? pending;
    try {
      pending = shellContext.read<DeepLinkProvider>().consumePending();
    } catch (_) {
      return;
    }
    if (pending == null) return;

    final ShareDeepLinkTarget target = pending;

    _didConsumeInitialDeepLink = true;
    final DeferredOnboardingProvider? deferredOnboardingProvider = (() {
      try {
        return shellContext.read<DeferredOnboardingProvider>();
      } catch (_) {
        return null;
      }
    })();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ShareDeepLinkNavigation.open(shellContext, target);
      if (!mounted) return;
      try {
        deferredOnboardingProvider?.markInitialDeepLinkHandled();
      } catch (_) {}
    });
  }

  void _showProfileMenu(BuildContext context) {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);

    if (!profileProvider.isSignedIn) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const SignInScreen(),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ProfileScreen(),
      ),
    );
  }

  void _showSettingsScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DesktopSettingsScreen(),
      ),
    );
  }

  // Notifications are handled in the functions sidebar via [_toggleNotificationsPanel].

  void _showCollabInvites() {
    _pushScreenToStack(
      DesktopSubScreen(
        title: 'Collaboration Invites',
        child: const InvitesInboxScreen(),
      ),
    );
  }

  void _handleWalletTap(bool isSignedIn) {
    if (!isSignedIn) {
      _startWeb3OnboardingFlow();
      return;
    }

    setState(() {
      _activeRoute = _walletRoute;
      _screenStack.clear();
    });
    _syncTelemetry();
  }

  void _startWeb3OnboardingFlow() {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute(
        builder: (_) => const SignInScreen(),
        settings: const RouteSettings(name: '/sign-in'),
      ),
    );

    // Layer Web3 onboarding over the sign-in screen so users see context before connecting wallets
    Future.microtask(() {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => web3.Web3OnboardingScreen(
            featureKey: Web3FeaturesOnboardingData.featureKey,
            featureTitle: Web3FeaturesOnboardingData.featureTitle(l10n),
            pages: Web3FeaturesOnboardingData.pages(l10n),
            onComplete: () {
              if (mounted) {
                setState(() {
                  _activeRoute = _walletRoute;
                  _screenStack.clear();
                });
                _syncTelemetry();
              }
              navigator.push(
                MaterialPageRoute(
                  builder: (_) => const ConnectWallet(),
                  settings: const RouteSettings(name: '/connect-wallet'),
                ),
              );
            },
          ),
        ),
      );
    });
  }
}

class _NotificationsPanel extends StatelessWidget {
  final VoidCallback onClose;
  final Future<void> Function(RecentActivity activity) onActivitySelected;

  const _NotificationsPanel({
    super.key,
    required this.onClose,
    required this.onActivitySelected,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final hasUnread =
        context.select<RecentActivityProvider, bool>((p) => p.hasUnread);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                l10n.commonNotifications,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: l10n.commonRefresh,
                onPressed: () => unawaited(context
                    .read<RecentActivityProvider>()
                    .refresh(force: true)),
                icon: Icon(
                  Icons.refresh,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.8),
                ),
              ),
              TextButton(
                onPressed: !hasUnread
                    ? null
                    : () async {
                        final activityProvider =
                            context.read<RecentActivityProvider>();
                        await context
                            .read<NotificationProvider>()
                            .markViewed(syncServer: true);
                        activityProvider.markAllReadLocally();
                      },
                child: Text(
                  l10n.homeMarkAllReadButton,
                  style: GoogleFonts.inter(
                    color: hasUnread
                        ? themeProvider.accentColor
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: Icon(
                  Icons.close,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),

        // Notifications list
        Expanded(
          child: Consumer<RecentActivityProvider>(
            builder: (context, activityProvider, _) {
              final activities = activityProvider.activities;
              final scheme = Theme.of(context).colorScheme;

              if (activityProvider.isLoading && activities.isEmpty) {
                return Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: themeProvider.accentColor,
                  ),
                );
              }

              if (activityProvider.error != null && activities.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: scheme.error),
                        const SizedBox(height: 12),
                        Text(
                          activityProvider.error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: scheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () =>
                              unawaited(activityProvider.refresh(force: true)),
                          child: Text(
                            l10n.commonRetry,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: themeProvider.accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (activities.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: scheme.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.homeNoNotificationsTitle,
                        style: GoogleFonts.inter(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  return RecentActivityTile(
                    activity: activity,
                    onTap: () => unawaited(onActivitySelected(activity)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A wrapper for subscreen content that provides a back button and title bar
/// when displayed within the DesktopShellScope.
///
/// Usage:
/// ```dart
/// DesktopShellScope.of(context)?.pushScreen(
///   DesktopSubScreen(
///     title: 'My Gallery',
///     child: const MyGalleryContent(),
///   ),
/// );
/// ```
class DesktopSubScreen extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;

  const DesktopSubScreen({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final shellScope = DesktopShellScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Header with back button
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(
              bottom: BorderSide(
                color: scheme.outline.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              if (shellScope?.canPop ?? false) ...[
                IconButton(
                  onPressed: () => shellScope?.popScreen(),
                  icon: Icon(
                    Icons.arrow_back,
                    color: scheme.onSurface,
                  ),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              if (actions != null) ...actions!,
            ],
          ),
        ),
        // Content
        Expanded(child: child),
      ],
    );
  }
}
