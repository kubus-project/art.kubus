import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../widgets/avatar_widget.dart';
import '../../../widgets/app_logo.dart';
import '../../../utils/app_animations.dart';

/// Navigation item data model
class DesktopNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  final int badgeCount;

  const DesktopNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
    this.badgeCount = 0,
  });
}

/// Sleek right-side navigation bar inspired by Twitter/X
class DesktopNavigation extends StatefulWidget {
  final List<DesktopNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final bool isExpanded;
  final Animation<double> expandAnimation;
  final VoidCallback onToggleExpand;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onNotificationsTap;

  const DesktopNavigation({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.isExpanded,
    required this.expandAnimation,
    required this.onToggleExpand,
    required this.onProfileTap,
    required this.onSettingsTap,
    required this.onNotificationsTap,
  });

  @override
  State<DesktopNavigation> createState() => _DesktopNavigationState();
}

class _DesktopNavigationState extends State<DesktopNavigation> 
    with SingleTickerProviderStateMixin {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final animationTheme = context.animationTheme;

    return Column(
      children: [
        // App logo and branding header
        _buildHeader(themeProvider),
        
        const SizedBox(height: 8),
        
        // Navigation items
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: widget.items.length,
            itemBuilder: (context, index) => _buildNavItem(
              widget.items[index],
              index,
              themeProvider,
              animationTheme,
            ),
          ),
        ),
        
        // Bottom actions (notifications, settings, profile)
        _buildBottomActions(themeProvider, animationTheme),
      ],
    );
  }

  Widget _buildHeader(ThemeProvider themeProvider) {
    // When collapsed, use a column layout to prevent overflow
    if (!widget.isExpanded) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(width: 32, height: 32),
            const SizedBox(height: 8),
            IconButton(
              onPressed: widget.onToggleExpand,
              icon: Icon(
                Icons.chevron_left,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                size: 20,
              ),
              tooltip: 'Expand navigation',
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const AppLogo(width: 36, height: 36),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedOpacity(
              opacity: widget.expandAnimation.value,
              duration: const Duration(milliseconds: 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'art.kubus',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'AR Art Platform',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: widget.onToggleExpand,
            icon: Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              size: 20,
            ),
            tooltip: 'Collapse navigation',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    DesktopNavItem item, 
    int index, 
    ThemeProvider themeProvider,
    AppAnimationTheme animationTheme,
  ) {
    final isSelected = widget.selectedIndex == index;
    final isHovered = _hoveredIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredIndex = index),
        onExit: (_) => setState(() => _hoveredIndex = null),
        child: AnimatedContainer(
          duration: animationTheme.short,
          curve: animationTheme.defaultCurve,
          decoration: BoxDecoration(
            color: isSelected
                ? themeProvider.accentColor.withValues(alpha: 0.12)
                : isHovered
                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => widget.onItemSelected(index),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isExpanded ? 16 : 12,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: widget.isExpanded 
                      ? MainAxisAlignment.start 
                      : MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: animationTheme.short,
                      child: Icon(
                        isSelected ? item.activeIcon : item.icon,
                        key: ValueKey('${item.route}_$isSelected'),
                        color: isSelected
                            ? themeProvider.accentColor
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        size: 24,
                      ),
                    ),
                    if (widget.isExpanded) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: AnimatedOpacity(
                          opacity: widget.expandAnimation.value,
                          duration: const Duration(milliseconds: 150),
                          child: Text(
                            item.label,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected
                                  ? themeProvider.accentColor
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (item.badgeCount > 0)
                      _buildBadge(item.badgeCount, themeProvider),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(int count, ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: themeProvider.accentColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildBottomActions(
    ThemeProvider themeProvider,
    AppAnimationTheme animationTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        children: [
          // Notifications button
          _buildActionButton(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            onTap: widget.onNotificationsTap,
            themeProvider: themeProvider,
            animationTheme: animationTheme,
            showBadge: true,
          ),
          
          const SizedBox(height: 8),
          
          // Settings button
          _buildActionButton(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: widget.onSettingsTap,
            themeProvider: themeProvider,
            animationTheme: animationTheme,
          ),
          
          const SizedBox(height: 16),
          
          // Profile section
          _buildProfileSection(themeProvider),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeProvider themeProvider,
    required AppAnimationTheme animationTheme,
    bool showBadge = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.isExpanded ? 16 : 12,
            vertical: 12,
          ),
          child: Row(
            mainAxisAlignment: widget.isExpanded 
                ? MainAxisAlignment.start 
                : MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  Icon(
                    icon,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    size: 24,
                  ),
                  if (showBadge)
                    Consumer<NotificationProvider>(
                      builder: (context, np, _) {
                        if (np.unreadCount == 0) return const SizedBox.shrink();
                        return Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: themeProvider.accentColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.surface,
                                width: 1.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
              if (widget.isExpanded) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: AnimatedOpacity(
                    opacity: widget.expandAnimation.value,
                    duration: const Duration(milliseconds: 150),
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(ThemeProvider themeProvider) {
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, _) {
        final user = profileProvider.currentUser;
        
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onProfileTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.all(widget.isExpanded ? 12 : 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
                child: Row(
                mainAxisAlignment: widget.isExpanded 
                    ? MainAxisAlignment.start 
                    : MainAxisAlignment.center,
                children: [
                  AvatarWidget(
                    wallet: user?.walletAddress ?? '',
                    avatarUrl: user?.avatar,
                    radius: widget.isExpanded ? 20 : 18,
                    allowFabricatedFallback: true,
                    enableProfileNavigation: false,
                  ),
                  if (widget.isExpanded) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedOpacity(
                        opacity: widget.expandAnimation.value,
                        duration: const Duration(milliseconds: 150),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? 'Art Enthusiast',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (user?.username != null)
                              Text(
                                '@${user!.username}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ),
                    Icon(
                      Icons.more_horiz,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
