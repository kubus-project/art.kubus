import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/themeprovider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/profile_provider.dart';
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
      widget.initialIndex.clamp(0, _signedInNavItems.length - 1)
    ].route;
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
  }

  @override
  void dispose() {
    _navExpandController.dispose();
    super.dispose();
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

  void _onNavItemSelected(int index, List<DesktopNavItem> navItems, bool isSignedIn) {
    if (index < 0 || index >= navItems.length) return;
    final item = navItems[index];

    if (!isSignedIn && item.route == _web3EntryRoute) {
      _startWeb3OnboardingFlow();
      return;
    }

    setState(() {
      _activeRoute = item.route;
    });
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

  List<DesktopNavItem> _navItemsForState(bool isSignedIn) {
    return isSignedIn ? _signedInNavItems : _guestNavItems;
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final isSignedIn = profileProvider.isSignedIn;
    final navItems = _navItemsForState(isSignedIn);
    final hasActiveRoute = navItems.any((item) => item.route == _activeRoute);
    final effectiveRoute = hasActiveRoute ? _activeRoute : navItems.first.route;
    if (!hasActiveRoute && _activeRoute != navItems.first.route) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _activeRoute = navItems.first.route;
          });
        }
      });
    }
    final selectedIndex = navItems.indexWhere((item) => item.route == effectiveRoute);

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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          // Main content area (takes most space)
          Expanded(
            child: _buildCurrentScreen(effectiveRoute),
          ),
          
          // Right sidebar navigation (Twitter/X style)
          AnimatedBuilder(
            animation: _navExpandAnimation,
            builder: (context, child) {
              final expandedWidth = isLarge ? 280.0 : 240.0;
              final collapsedWidth = 72.0;
              final currentWidth = collapsedWidth + 
                  (expandedWidth - collapsedWidth) * _navExpandAnimation.value;
              
              return Container(
                width: currentWidth,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    left: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: DesktopNavigation(
                  items: navItems,
                  selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
                  onItemSelected: (index) => _onNavItemSelected(index, navItems, isSignedIn),
                  isExpanded: _isNavigationExpanded,
                  expandAnimation: _navExpandAnimation,
                  onToggleExpand: _toggleNavigation,
                  onProfileTap: () => _showProfileMenu(context),
                  onSettingsTap: () => _showSettingsScreen(context),
                  onNotificationsTap: () => _showNotificationsPanel(context),
                  onWalletTap: () => _handleWalletTap(isSignedIn),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    
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

  void _showNotificationsPanel(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 400,
          height: double.infinity,
          margin: const EdgeInsets.only(right: 80),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(-4, 0),
              ),
            ],
          ),
          child: _NotificationsPanel(
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
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
    });
  }

  void _startWeb3OnboardingFlow() {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
    );

    // Layer Web3 onboarding over the sign-in screen so users see context before connecting wallets
    Future.microtask(() {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => web3.Web3OnboardingScreen(
            featureName: Web3FeaturesOnboardingData.featureName,
            pages: Web3FeaturesOnboardingData.pages,
            onComplete: () {
              if (navigator.canPop()) {
                navigator.pop(); // Close onboarding sheet
              }
              if (mounted) {
                setState(() {
                  _activeRoute = _walletRoute;
                });
              }
              navigator.push(
                MaterialPageRoute(builder: (_) => const ConnectWallet()),
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

  const _NotificationsPanel({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Notifications',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // Mark all as read
                },
                child: Text(
                  'Mark all read',
                  style: GoogleFonts.inter(
                    color: themeProvider.accentColor,
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
          child: Consumer<NotificationProvider>(
            builder: (context, np, _) {
              if (np.unreadCount == 0) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: GoogleFonts.inter(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              // Show unread count indicator since NotificationProvider doesn't expose full list
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: themeProvider.accentColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${np.unreadCount}',
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.accentColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'unread notifications',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'View full notifications in the mobile app',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
