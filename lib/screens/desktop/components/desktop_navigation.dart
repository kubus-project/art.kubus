import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/collab_provider.dart';
import '../../../config/config.dart';
import '../../../widgets/avatar_widget.dart';
import '../../../widgets/app_logo.dart';
import '../../../utils/app_animations.dart';

import '../../../utils/design_tokens.dart';

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
  /// Width guidance for the surrounding desktop shell.
  ///
  /// NOTE: The actual width is enforced by `DesktopShell` (animated), but these
  /// constants are used there so changing them keeps everything in sync.
  static const double collapsedWidth = 72.0;
  static const double expandedWidthLarge = 220.0;
  static const double expandedWidthMedium = 180.0;

  final List<DesktopNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final bool isExpanded;
  final Animation<double> expandAnimation;
  final VoidCallback onToggleExpand;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onWalletTap;
  final VoidCallback? onCollabInvitesTap;

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
    required this.onWalletTap,
    this.onCollabInvitesTap,
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

    // When collapsed and thinner, fixed paddings used for the wider rail can
    // cause overflow. These values keep icon-only layouts comfortable.
    final navListHorizontalPadding = widget.isExpanded ? 12.0 : 6.0;
    final bottomHorizontalPadding = widget.isExpanded ? 12.0 : 8.0;

    return Column(
      children: [
        // App logo and branding header
        _buildHeader(themeProvider),

        const SizedBox(height: 8),

        // Navigation items
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(
                horizontal: navListHorizontalPadding, vertical: 8),
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
        _buildBottomActions(
          themeProvider,
          animationTheme,
          horizontalPadding: bottomHorizontalPadding,
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeProvider themeProvider) {
    // When collapsed, use a column layout to prevent overflow
    if (!widget.isExpanded) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(width: 28, height: 28),
            const SizedBox(height: 4),
            IconButton(
              onPressed: widget.onToggleExpand,
              icon: Icon(
                Icons.chevron_left,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
                size: 20,
              ),
              tooltip: 'Expand navigation',
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          const AppLogo(width: 32, height: 32),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedOpacity(
              opacity: widget.expandAnimation.value,
              duration: const Duration(milliseconds: 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'art.kubus',
                    style: KubusTypography.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Art Platform',
                    style: KubusTypography.textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
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
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
              size: 20,
            ),
            tooltip: 'Collapse navigation',
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
    final collapsedItemHorizontalPadding = 6.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
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
                    ? Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.05)
                    : Colors.transparent,
            borderRadius: KubusRadius.circular(KubusRadius.md),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => widget.onItemSelected(index),
              borderRadius: KubusRadius.circular(KubusRadius.md),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal:
                      widget.isExpanded ? 12 : collapsedItemHorizontalPadding,
                  vertical: 9,
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
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                        size: 24,
                      ),
                    ),
                    if (widget.isExpanded) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: AnimatedOpacity(
                          opacity: widget.expandAnimation.value,
                          duration: const Duration(milliseconds: 150),
                          child: Text(
                            item.label,
                            style: KubusTypography.textTheme.bodyMedium?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
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
        style: KubusTypography.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildBottomActions(
      ThemeProvider themeProvider, AppAnimationTheme animationTheme,
      {required double horizontalPadding}) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        children: [
          // Wallet section
          _buildWalletBalanceSection(themeProvider, animationTheme),

          const SizedBox(height: 6),

          // Action buttons row
          if (widget.isExpanded)
            _buildActionButtonsRow(themeProvider, animationTheme)
          else
            _buildActionButtonsColumn(themeProvider, animationTheme),

          const SizedBox(height: 6),

          // Profile section
          _buildProfileSection(themeProvider),
        ],
      ),
    );
  }

  Widget _buildActionButtonsRow(
    ThemeProvider themeProvider,
    AppAnimationTheme animationTheme,
  ) {
    return AnimatedOpacity(
      opacity: widget.expandAnimation.value,
      duration: const Duration(milliseconds: 150),
      child: Row(
        children: [
          // Collab invites (if enabled)
          if (AppConfig.isFeatureEnabled('collabInvites') &&
              widget.onCollabInvitesTap != null)
            Expanded(
              child: Consumer<CollabProvider>(
                builder: (context, collabProvider, _) {
                  final pendingCount = collabProvider.pendingInviteCount;
                  return _buildIconOnlyActionButton(
                    icon: Icons.group_add_outlined,
                    onTap: widget.onCollabInvitesTap!,
                    themeProvider: themeProvider,
                    showBadge: pendingCount > 0,
                    badgeCount: pendingCount,
                  );
                },
              ),
            ),

          // Notifications
          Expanded(
            child: _buildIconOnlyActionButton(
              icon: Icons.notifications_outlined,
              onTap: widget.onNotificationsTap,
              themeProvider: themeProvider,
              showBadge: true,
            ),
          ),

          // Settings
          Expanded(
            child: _buildIconOnlyActionButton(
              icon: Icons.settings_outlined,
              onTap: widget.onSettingsTap,
              themeProvider: themeProvider,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonsColumn(
    ThemeProvider themeProvider,
    AppAnimationTheme animationTheme,
  ) {
    return Column(
      children: [
        // Collab invites (if enabled)
        if (AppConfig.isFeatureEnabled('collabInvites') &&
            widget.onCollabInvitesTap != null)
          Consumer<CollabProvider>(
            builder: (context, collabProvider, _) {
              final pendingCount = collabProvider.pendingInviteCount;
              return _buildCollapsedActionButton(
                icon: Icons.group_add_outlined,
                onTap: widget.onCollabInvitesTap!,
                themeProvider: themeProvider,
                showBadge: pendingCount > 0,
                badgeCount: pendingCount,
              );
            },
          ),

        if (AppConfig.isFeatureEnabled('collabInvites') &&
            widget.onCollabInvitesTap != null)
          const SizedBox(height: 2),

        // Notifications
        _buildCollapsedActionButton(
          icon: Icons.notifications_outlined,
          onTap: widget.onNotificationsTap,
          themeProvider: themeProvider,
          showBadge: true,
        ),

        const SizedBox(height: 2),

        // Settings
        _buildCollapsedActionButton(
          icon: Icons.settings_outlined,
          onTap: widget.onSettingsTap,
          themeProvider: themeProvider,
        ),
      ],
    );
  }

  Widget _buildIconOnlyActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required ThemeProvider themeProvider,
    bool showBadge = false,
    int badgeCount = 0,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                  size: 24,
                ),
                // Generic badge with count (for collab invites, etc.)
                if (showBadge && badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      constraints:
                          const BoxConstraints(minWidth: 14, minHeight: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          badgeCount > 99 ? '99+' : badgeCount.toString(),
                          style: KubusTypography.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onError,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Notification badge (uses NotificationProvider)
                if (showBadge && badgeCount == 0)
                  Consumer<NotificationProvider>(
                    builder: (context, np, _) {
                      if (np.unreadCount == 0) return const SizedBox.shrink();
                      return Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: themeProvider.accentColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 1,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required ThemeProvider themeProvider,
    bool showBadge = false,
    int badgeCount = 0,
  }) {
    final collapsedButtonPadding = 7.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.all(collapsedButtonPadding),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
                size: 24,
              ),
              // Generic badge with count (for collab invites, etc.)
              if (showBadge && badgeCount > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints:
                        const BoxConstraints(minWidth: 14, minHeight: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: KubusTypography.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onError,
                        ),
                      ),
                    ),
                  ),
                ),
              // Notification badge (uses NotificationProvider)
              if (showBadge && badgeCount == 0)
                Consumer<NotificationProvider>(
                  builder: (context, np, _) {
                    if (np.unreadCount == 0) return const SizedBox.shrink();
                    return Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: themeProvider.accentColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletBalanceSection(
    ThemeProvider themeProvider,
    AppAnimationTheme animationTheme,
  ) {
    return Consumer2<WalletProvider, ProfileProvider>(
      builder: (context, walletProvider, profileProvider, _) {
        final tokens = walletProvider.tokens;
        final kub8Balance = tokens
            .where((t) => t.symbol.toUpperCase() == 'KUB8')
            .fold<double>(0.0, (prev, t) => t.balance);
        final solBalance = tokens
            .where((t) => t.symbol.toUpperCase() == 'SOL')
            .fold<double>(0.0, (prev, t) => t.balance);
        final showFullWallet = profileProvider.isSignedIn;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onWalletTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: widget.isExpanded
                  ? const EdgeInsets.all(9)
                  : const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    themeProvider.accentColor,
                    themeProvider.accentColor.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: themeProvider.accentColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: widget.isExpanded
                  ? (showFullWallet
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'My Wallet',
                                  style: KubusTypography.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            AnimatedOpacity(
                              opacity: widget.expandAnimation.value,
                              duration: const Duration(milliseconds: 150),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'KUB8',
                                        style: KubusTypography.textTheme.bodySmall?.copyWith(
                                          fontSize: 10,
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                      Text(
                                        kub8Balance.toStringAsFixed(2),
                                        style: KubusTypography.textTheme.bodySmall?.copyWith(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'SOL',
                                        style: KubusTypography.textTheme.bodySmall?.copyWith(
                                          fontSize: 10,
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                      Text(
                                        solBalance.toStringAsFixed(3),
                                        style: KubusTypography.textTheme.bodySmall?.copyWith(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: Icon(
                            Icons.account_balance_wallet,
                            color: Colors.white,
                            size: 22,
                          ),
                        ))
                  : Center(
                      child: Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
            ),
          ),
        );
      },
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
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: EdgeInsets.all(widget.isExpanded ? 10 : 8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: widget.isExpanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AvatarWidget(
                    wallet: user?.walletAddress ?? '',
                    avatarUrl: user?.avatar,
                    radius: widget.isExpanded ? 17 : 16,
                    allowFabricatedFallback: true,
                    enableProfileNavigation: false,
                  ),
                  if (widget.isExpanded) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: AnimatedOpacity(
                        opacity: widget.expandAnimation.value,
                        duration: const Duration(milliseconds: 150),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user?.displayName ?? 'Art Enthusiast',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            if (user?.username != null)
                              Text(
                                '@${user!.username}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                          ],
                        ),
                      ),
                    ),
                    Icon(
                      Icons.more_horiz,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
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
