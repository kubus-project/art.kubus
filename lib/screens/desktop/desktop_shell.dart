import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/themeprovider.dart';
import '../../providers/notification_provider.dart';
import 'desktop_home_screen.dart';
import 'desktop_map_screen.dart';
import 'community/desktop_community_screen.dart';
import 'web3/desktop_marketplace_screen.dart';
import 'web3/desktop_wallet_screen.dart';
import 'desktop_settings_screen.dart';
import 'components/desktop_navigation.dart';
import 'community/desktop_profile_screen.dart';

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
  int _selectedIndex = 0;
  bool _isNavigationExpanded = true;
  late AnimationController _navExpandController;
  late Animation<double> _navExpandAnimation;
  
  final List<DesktopNavItem> _navItems = [
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
      label: 'Community',
      route: '/community',
    ),
    DesktopNavItem(
      icon: Icons.storefront_outlined,
      activeIcon: Icons.storefront,
      label: 'Marketplace',
      route: '/marketplace',
    ),
    DesktopNavItem(
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet,
      label: 'Wallet',
      route: '/wallet',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, _navItems.length - 1);
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

  void _onNavItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return const DesktopHomeScreen();
      case 1:
        return const DesktopMapScreen();
      case 2:
        return const DesktopCommunityScreen();
      case 3:
        return const DesktopMarketplaceScreen();
      case 4:
        return const DesktopWalletScreen();
      default:
        return const DesktopHomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
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
            child: _buildCurrentScreen(),
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
                  items: _navItems,
                  selectedIndex: _selectedIndex,
                  onItemSelected: _onNavItemSelected,
                  isExpanded: _isNavigationExpanded,
                  expandAnimation: _navExpandAnimation,
                  onToggleExpand: _toggleNavigation,
                  onProfileTap: () => _showProfileMenu(context),
                  onSettingsTap: () => _showSettingsScreen(context),
                  onNotificationsTap: () => _showNotificationsPanel(context),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
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
