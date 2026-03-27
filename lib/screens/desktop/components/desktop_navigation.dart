import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
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
import '../../../utils/kubus_labs_feature.dart';
import '../../../widgets/common/kubus_labs_adornment.dart';

/// Navigation item data model
enum DesktopNavLabelKey {
  home,
  explore,
  connect,
  create,
  organize,
  govern,
  trade,
  web3,
}

extension DesktopNavLabelKeyX on DesktopNavLabelKey {
  String resolve(AppLocalizations l10n) {
    switch (this) {
      case DesktopNavLabelKey.home:
        return l10n.desktopShellNavHome;
      case DesktopNavLabelKey.explore:
        return l10n.desktopShellNavExplore;
      case DesktopNavLabelKey.connect:
        return l10n.desktopShellNavConnect;
      case DesktopNavLabelKey.create:
        return l10n.desktopShellNavCreate;
      case DesktopNavLabelKey.organize:
        return l10n.desktopShellNavOrganize;
      case DesktopNavLabelKey.govern:
        return l10n.desktopShellNavGovern;
      case DesktopNavLabelKey.trade:
        return l10n.desktopShellNavTrade;
      case DesktopNavLabelKey.web3:
        return l10n.desktopShellNavWeb3;
    }
  }
}

class DesktopNavItem {
  final IconData icon;
  final IconData activeIcon;
  final DesktopNavLabelKey labelKey;
  final String route;
  final int badgeCount;
  final KubusLabsFeature? labsFeature;

  const DesktopNavItem({
    required this.icon,
    required this.activeIcon,
    required this.labelKey,
    required this.route,
    this.badgeCount = 0,
    this.labsFeature,
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
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final animationTheme = context.animationTheme;

    // When collapsed and thinner, fixed paddings used for the wider rail can
    // cause overflow. These values keep icon-only layouts comfortable.
    final navListHorizontalPadding = widget.isExpanded ? 12.0 : 6.0;
    final bottomHorizontalPadding = widget.isExpanded ? 12.0 : 8.0;

    return Column(
      children: [
        // App logo and branding header
        _buildHeader(themeProvider, l10n),

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
              l10n,
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

  Widget _buildHeader(ThemeProvider themeProvider, AppLocalizations l10n) {
    // When collapsed, use a column layout to prevent overflow
    if (!widget.isExpanded) {
      return Container(
        padding: const EdgeInsets.symmetric(
          vertical: KubusSpacing.md - KubusSpacing.xxs,
          horizontal: KubusSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(
              width: KubusChromeMetrics.railCompactLogo,
              height: KubusChromeMetrics.railCompactLogo,
            ),
            const SizedBox(height: KubusSpacing.xs),
            IconButton(
              onPressed: widget.onToggleExpand,
              icon: Icon(
                Icons.chevron_left,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
                size: KubusChromeMetrics.navCompactIcon,
              ),
              tooltip: l10n.desktopNavigationExpandTooltip,
              constraints: const BoxConstraints(
                minWidth: KubusHeaderMetrics.actionHitArea,
                minHeight: KubusHeaderMetrics.actionHitArea,
              ),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.md - KubusSpacing.xxs,
        vertical: KubusSpacing.md - KubusSpacing.xxs,
      ),
      child: Row(
        children: [
          const AppLogo(
            width: KubusChromeMetrics.railExpandedLogo,
            height: KubusChromeMetrics.railExpandedLogo,
          ),
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
                    style: KubusTextStyles.sectionTitle.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    l10n.desktopNavigationSubtitle,
                    style: KubusTextStyles.navMetaLabel.copyWith(
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
              size: KubusChromeMetrics.navCompactIcon,
            ),
            tooltip: l10n.desktopNavigationCollapseTooltip,
            constraints: const BoxConstraints(
              minWidth: KubusHeaderMetrics.actionHitArea,
              minHeight: KubusHeaderMetrics.actionHitArea,
            ),
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
    AppLocalizations l10n,
  ) {
    final isSelected = widget.selectedIndex == index;
    final isHovered = _hoveredIndex == index;
    final collapsedItemHorizontalPadding = 6.0;
    final labsFeature = item.labsFeature;
    final showInlineLabs =
        widget.isExpanded && (labsFeature?.showLabsMarker ?? false);
    final showCompactLabs =
        !widget.isExpanded && (labsFeature?.showLabsMarker ?? false);

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
                      child: SizedBox(
                        key: ValueKey('${item.route}_$isSelected'),
                        width: KubusChromeMetrics.navIcon,
                        height: KubusChromeMetrics.navIcon,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Align(
                              alignment: Alignment.center,
                              child: Icon(
                                isSelected ? item.activeIcon : item.icon,
                                color: isSelected
                                    ? themeProvider.accentColor
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                size: KubusChromeMetrics.navIcon,
                              ),
                            ),
                            if (showCompactLabs && labsFeature != null)
                              Positioned(
                                top: -KubusSpacing.xs,
                                right: -6,
                                child: KubusLabsAdornment.compactOverlay(
                                  feature: labsFeature,
                                  emphasized: isSelected,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.isExpanded) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: AnimatedOpacity(
                          opacity: widget.expandAnimation.value,
                          duration: const Duration(milliseconds: 150),
                          child: Text(
                            item.labelKey.resolve(l10n),
                            style: KubusTextStyles.navLabel.copyWith(
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
                      if (showInlineLabs && labsFeature != null) ...[
                        const SizedBox(width: KubusSpacing.xs),
                        KubusLabsAdornment.inlinePill(
                          feature: labsFeature,
                          emphasized: isSelected,
                        ),
                      ],
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
        borderRadius: BorderRadius.circular(KubusRadius.md),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: KubusTextStyles.badgeCount.copyWith(
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
        child: SizedBox(
          width: KubusHeaderMetrics.actionHitArea,
          height: KubusHeaderMetrics.actionHitArea,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(
                  icon,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                  size: KubusChromeMetrics.navIcon,
                ),
              ),
              // Generic badge with count (for collab invites, etc.)
              if (showBadge && badgeCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
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
                        style: KubusTextStyles.compactBadge.copyWith(
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
                      right: 0,
                      top: 0,
                      child: Container(
                        width: KubusChromeMetrics.navBadgeDot,
                        height: KubusChromeMetrics.navBadgeDot,
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
        borderRadius: BorderRadius.circular(KubusRadius.md),
        child: SizedBox(
          width: KubusHeaderMetrics.actionHitArea - collapsedButtonPadding,
          height: KubusHeaderMetrics.actionHitArea - collapsedButtonPadding,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(
                  icon,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                  size: KubusChromeMetrics.navIcon,
                ),
              ),
              // Generic badge with count (for collab invites, etc.)
              if (showBadge && badgeCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
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
                        style: KubusTextStyles.compactBadge.copyWith(
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
                      right: 0,
                      top: 0,
                      child: Container(
                        width: KubusChromeMetrics.navBadgeDot,
                        height: KubusChromeMetrics.navBadgeDot,
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
                                  size: KubusSizes.trailingChevron,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  AppLocalizations.of(context)!.walletHomeTitle,
                                  style: KubusTextStyles.navMetaLabel.copyWith(
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
                                        style: KubusTypography
                                            .textTheme.bodySmall
                                            ?.copyWith(
                                          fontSize:
                                              KubusChromeMetrics.navMetaLabel,
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                      Text(
                                        kub8Balance.toStringAsFixed(2),
                                        style: KubusTypography
                                            .textTheme.bodySmall
                                            ?.copyWith(
                                          fontSize:
                                              KubusChromeMetrics.profileHandle,
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
                                        style: KubusTypography
                                            .textTheme.bodySmall
                                            ?.copyWith(
                                          fontSize:
                                              KubusChromeMetrics.navMetaLabel,
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                      Text(
                                        solBalance.toStringAsFixed(3),
                                        style: KubusTypography
                                            .textTheme.bodySmall
                                            ?.copyWith(
                                          fontSize:
                                              KubusChromeMetrics.profileHandle,
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
                            size: KubusHeaderMetrics.actionIcon,
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
                borderRadius: BorderRadius.circular(KubusRadius.md),
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
                              user?.displayName ??
                                  AppLocalizations.of(context)!
                                      .profilePersonaArtEnthusiast,
                              style: KubusTextStyles.profileName.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            if (user?.username != null)
                              Text(
                                '@${user!.username}',
                                style: KubusTextStyles.profileHandle.copyWith(
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
                      size: KubusHeaderMetrics.actionIcon,
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
