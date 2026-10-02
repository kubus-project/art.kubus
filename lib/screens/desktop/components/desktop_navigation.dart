import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/collab_provider.dart';
import '../../../config/config.dart';
import '../../../widgets/avatar_widget.dart';
import '../../../widgets/app_logo.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
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

/// Desktop primary navigation rail
class DesktopNavigation extends StatefulWidget {
  /// Width guidance for the surrounding desktop shell.
  ///
  /// NOTE: The actual width is enforced by `DesktopShell` (animated), but these
  /// constants are used there so changing them keeps everything in sync.
  static const double collapsedWidth = 72.0;
  static const double expandedWidthLarge = 220.0;
  static const double expandedWidthMedium = 180.0;

  final List<DesktopNavItem> items;
  final Color activeAccent;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final bool isExpanded;
  final Animation<double> expandAnimation;
  final VoidCallback onToggleExpand;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onWalletTap;
  final bool isProfileSelected;
  final bool isNotificationsSelected;
  final bool isSettingsSelected;
  final bool isCollabInvitesSelected;
  final VoidCallback? onCollabInvitesTap;

  const DesktopNavigation({
    super.key,
    required this.items,
    required this.activeAccent,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.isExpanded,
    required this.expandAnimation,
    required this.onToggleExpand,
    required this.onProfileTap,
    required this.onSettingsTap,
    required this.onNotificationsTap,
    required this.onWalletTap,
    required this.isProfileSelected,
    this.isNotificationsSelected = false,
    this.isSettingsSelected = false,
    this.isCollabInvitesSelected = false,
    this.onCollabInvitesTap,
  });

  @override
  State<DesktopNavigation> createState() => _DesktopNavigationState();
}

class _DesktopNavigationState extends State<DesktopNavigation>
    with SingleTickerProviderStateMixin {
  int? _hoveredIndex;
  bool _isProfileHovered = false;
  final Set<String> _hoveredActionButtons = <String>{};

  void _setActionButtonHover(String key, bool hovered) {
    setState(() {
      if (hovered) {
        _hoveredActionButtons.add(key);
      } else {
        _hoveredActionButtons.remove(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final animationTheme = context.animationTheme;

    // When collapsed and thinner, fixed paddings used for the wider rail can
    // cause overflow. These values keep icon-only layouts comfortable.
    final navListHorizontalPadding = widget.isExpanded ? 12.0 : 6.0;
    final bottomHorizontalPadding = widget.isExpanded ? 12.0 : 8.0;

    return Column(
      children: [
        // App logo and branding header
        _buildHeader(l10n),

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
              animationTheme,
              l10n,
            ),
          ),
        ),

        // Bottom actions (notifications, settings, profile)
        _buildBottomActions(horizontalPadding: bottomHorizontalPadding),
      ],
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
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
                Icons.chevron_right,
                color: widget.activeAccent.withValues(alpha: 0.72),
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
          const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
          Expanded(
            child: AnimatedOpacity(
              opacity: widget.expandAnimation.value,
              duration: const Duration(milliseconds: 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.appTitle,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: KubusTextStyles.sectionTitle.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    l10n.desktopNavigationSubtitle,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
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
              Icons.chevron_left,
              color: widget.activeAccent.withValues(alpha: 0.72),
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

    final roles = KubusColorRoles.of(context);
    final label = item.labelKey.resolve(l10n);
    Widget tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredIndex = index),
        onExit: (_) => setState(() => _hoveredIndex = null),
        child: AnimatedContainer(
          duration: animationTheme.short,
          curve: animationTheme.defaultCurve,
          decoration: BoxDecoration(
            // Neutral selection: a restrained active tint plus a leading
            // active rule, so selection never depends on hue alone.
            color: isSelected
                ? roles.active.withValues(alpha: 0.10)
                : isHovered
                    ? roles.foreground.withValues(alpha: 0.05)
                    : Colors.transparent,
            borderRadius: KubusRadius.circular(KubusRadius.surface),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => widget.onItemSelected(index),
              borderRadius: KubusRadius.circular(KubusRadius.surface),
              focusColor: roles.focus.withValues(alpha: 0.16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isSelected ? roles.active : Colors.transparent,
                        borderRadius: KubusRadius.circular(KubusRadius.control),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: widget.isExpanded
                              ? 9
                              : collapsedItemHorizontalPadding - 3,
                          right: widget.isExpanded
                              ? 12
                              : collapsedItemHorizontalPadding,
                        ),
                        child: Row(
                          mainAxisAlignment: widget.isExpanded
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          children: [
                            SizedBox(
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
                                          ? roles.active
                                          : roles.foregroundMuted,
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
                            if (widget.isExpanded) ...[
                              const SizedBox(
                                  width: KubusSpacing.sm + KubusSpacing.xs),
                              Expanded(
                                child: AnimatedOpacity(
                                  opacity: widget.expandAnimation.value,
                                  duration: const Duration(milliseconds: 150),
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: KubusTextStyles.navLabel.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? roles.foreground
                                          : roles.foregroundMuted,
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
                              _buildBadge(item.badgeCount),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (!widget.isExpanded) {
      tile = Tooltip(message: label, child: tile);
    }
    return Semantics(
      container: true,
      button: true,
      selected: isSelected,
      label: label,
      onTap: () => widget.onItemSelected(index),
      child: ExcludeSemantics(child: tile),
    );
  }

  Widget _buildBadge(int count) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: widget.activeAccent,
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

  Widget _buildBottomActions({required double horizontalPadding}) {
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
          _buildWalletBalanceSection(),

          const SizedBox(height: 6),

          // Action buttons row
          if (widget.isExpanded)
            _buildActionButtonsRow()
          else
            _buildActionButtonsColumn(),

          const SizedBox(height: 6),

          // Profile section
          _buildProfileSection(),
        ],
      ),
    );
  }

  Widget _buildActionButtonsRow() {
    final animationTheme = context.animationTheme;
    return AnimatedOpacity(
      opacity: widget.expandAnimation.value,
      duration: const Duration(milliseconds: 150),
      child: Row(
        children: [
          // Collab invites (if enabled)
          if (AppConfig.isFeatureEnabled('collabInvites') &&
              widget.onCollabInvitesTap != null)
            Expanded(
              child: Selector<CollabProvider, int>(
                selector: (_, collabProvider) =>
                    collabProvider.pendingInviteCount,
                builder: (context, pendingCount, _) {
                  return _buildIconOnlyActionButton(
                    icon: Icons.group_add_outlined,
                    onTap: widget.onCollabInvitesTap!,
                    showBadge: pendingCount > 0,
                    badgeCount: pendingCount,
                    isActive: widget.isCollabInvitesSelected,
                    hoverKey: 'collab_invites',
                    animationTheme: animationTheme,
                  );
                },
              ),
            ),

          // Notifications
          Expanded(
            child: _buildIconOnlyActionButton(
              icon: Icons.notifications_outlined,
              onTap: widget.onNotificationsTap,
              showBadge: true,
              isActive: widget.isNotificationsSelected,
              hoverKey: 'notifications',
              animationTheme: animationTheme,
            ),
          ),

          // Settings
          Expanded(
            child: _buildIconOnlyActionButton(
              icon: Icons.settings_outlined,
              onTap: widget.onSettingsTap,
              isActive: widget.isSettingsSelected,
              hoverKey: 'settings',
              animationTheme: animationTheme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonsColumn() {
    final animationTheme = context.animationTheme;
    return Column(
      children: [
        // Collab invites (if enabled)
        if (AppConfig.isFeatureEnabled('collabInvites') &&
            widget.onCollabInvitesTap != null)
          Selector<CollabProvider, int>(
            selector: (_, collabProvider) => collabProvider.pendingInviteCount,
            builder: (context, pendingCount, _) {
              return _buildCollapsedActionButton(
                icon: Icons.group_add_outlined,
                onTap: widget.onCollabInvitesTap!,
                showBadge: pendingCount > 0,
                badgeCount: pendingCount,
                isActive: widget.isCollabInvitesSelected,
                hoverKey: 'collab_invites',
                animationTheme: animationTheme,
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
          showBadge: true,
          isActive: widget.isNotificationsSelected,
          hoverKey: 'notifications',
          animationTheme: animationTheme,
        ),

        const SizedBox(height: 2),

        // Settings
        _buildCollapsedActionButton(
          icon: Icons.settings_outlined,
          onTap: widget.onSettingsTap,
          isActive: widget.isSettingsSelected,
          hoverKey: 'settings',
          animationTheme: animationTheme,
        ),
      ],
    );
  }

  Widget _buildIconOnlyActionButton({
    required IconData icon,
    required VoidCallback onTap,
    bool showBadge = false,
    int badgeCount = 0,
    bool isActive = false,
    required String hoverKey,
    required AppAnimationTheme animationTheme,
  }) {
    final isHovered = _hoveredActionButtons.contains(hoverKey);
    return MouseRegion(
      onEnter: (_) => _setActionButtonHover(hoverKey, true),
      onExit: (_) => _setActionButtonHover(hoverKey, false),
      child: AnimatedContainer(
        duration: animationTheme.short,
        curve: animationTheme.defaultCurve,
        decoration: BoxDecoration(
          color: isActive
              ? widget.activeAccent.withValues(alpha: 0.16)
              : isHovered
                  ? widget.activeAccent.withValues(alpha: 0.08)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(KubusRadius.sm),
          border: Border.all(
            color: isActive
                ? widget.activeAccent.withValues(alpha: 0.30)
                : isHovered
                    ? widget.activeAccent.withValues(alpha: 0.12)
                    : Colors.transparent,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(KubusRadius.sm),
            child: SizedBox(
              width: KubusHeaderMetrics.actionHitArea,
              height: KubusHeaderMetrics.actionHitArea,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Icon(
                      icon,
                      color: isActive
                          ? widget.activeAccent
                          : Theme.of(context)
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: KubusSpacing.xs,
                          vertical: KubusSpacing.xxs,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: KubusSpacing.sm +
                              KubusSpacing.xs +
                              KubusSpacing.xxs,
                          minHeight: KubusSpacing.sm +
                              KubusSpacing.xs +
                              KubusSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(KubusRadius.sm),
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
                    Selector<NotificationProvider, int>(
                      selector: (_, np) => np.unreadCount,
                      builder: (context, unreadCount, _) {
                        if (unreadCount == 0) return const SizedBox.shrink();
                        return Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: KubusChromeMetrics.navBadgeDot,
                            height: KubusChromeMetrics.navBadgeDot,
                            decoration: BoxDecoration(
                              color: widget.activeAccent,
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
      ),
    );
  }

  Widget _buildCollapsedActionButton({
    required IconData icon,
    required VoidCallback onTap,
    bool showBadge = false,
    int badgeCount = 0,
    bool isActive = false,
    required String hoverKey,
    required AppAnimationTheme animationTheme,
  }) {
    final isHovered = _hoveredActionButtons.contains(hoverKey);
    final collapsedButtonPadding = 7.0;
    return MouseRegion(
      onEnter: (_) => _setActionButtonHover(hoverKey, true),
      onExit: (_) => _setActionButtonHover(hoverKey, false),
      child: AnimatedContainer(
        duration: animationTheme.short,
        curve: animationTheme.defaultCurve,
        decoration: BoxDecoration(
          color: isActive
              ? widget.activeAccent.withValues(alpha: 0.16)
              : isHovered
                  ? widget.activeAccent.withValues(alpha: 0.08)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(KubusRadius.md),
          border: Border.all(
            color: isActive
                ? widget.activeAccent.withValues(alpha: 0.30)
                : isHovered
                    ? widget.activeAccent.withValues(alpha: 0.12)
                    : Colors.transparent,
          ),
        ),
        child: Material(
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
                      color: isActive
                          ? widget.activeAccent
                          : Theme.of(context)
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: KubusSpacing.xs,
                          vertical: KubusSpacing.xxs,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: KubusSpacing.sm +
                              KubusSpacing.xs +
                              KubusSpacing.xxs,
                          minHeight: KubusSpacing.sm +
                              KubusSpacing.xs +
                              KubusSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(KubusRadius.sm),
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
                    Selector<NotificationProvider, int>(
                      selector: (_, np) => np.unreadCount,
                      builder: (context, unreadCount, _) {
                        if (unreadCount == 0) return const SizedBox.shrink();
                        return Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: KubusChromeMetrics.navBadgeDot,
                            height: KubusChromeMetrics.navBadgeDot,
                            decoration: BoxDecoration(
                              color: widget.activeAccent,
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
      ),
    );
  }

  /// Quiet wallet entry. Wallet is infrastructure: the rail links to it but
  /// does not display balances or promote it above cultural destinations.
  Widget _buildWalletBalanceSection() {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final label = l10n.desktopNavWalletEntry;
    Widget entry = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onWalletTap,
        borderRadius: BorderRadius.circular(KubusRadius.surface),
        focusColor: roles.focus.withValues(alpha: 0.16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isExpanded ? KubusSpacing.sm + 4 : 0,
            ),
            child: Row(
              mainAxisAlignment: widget.isExpanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: roles.foregroundMuted,
                  size: KubusChromeMetrics.navIcon,
                ),
                if (widget.isExpanded) ...[
                  const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: widget.expandAnimation.value,
                      duration: const Duration(milliseconds: 150),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KubusTextStyles.navLabel.copyWith(
                          fontWeight: FontWeight.w500,
                          color: roles.foregroundMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (!widget.isExpanded) {
      entry = Tooltip(message: label, child: entry);
    }
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: widget.onWalletTap,
      child: ExcludeSemantics(child: entry),
    );
  }

  Widget _buildProfileSection() {
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, _) {
        final user = profileProvider.currentUser;
        final scheme = Theme.of(context).colorScheme;
        final isSelected = widget.isProfileSelected;
        final isHovered = _isProfileHovered;

        return Material(
          color: Colors.transparent,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isProfileHovered = true),
            onExit: (_) => setState(() => _isProfileHovered = false),
            child: InkWell(
              onTap: widget.onProfileTap,
              borderRadius: BorderRadius.circular(KubusRadius.sm),
              child: Container(
                padding: EdgeInsets.all(widget.isExpanded ? 10 : 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? widget.activeAccent.withValues(alpha: 0.16)
                      : isHovered
                          ? widget.activeAccent.withValues(alpha: 0.08)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                  border: Border.all(
                    color: isSelected
                        ? widget.activeAccent.withValues(alpha: 0.30)
                        : isHovered
                            ? widget.activeAccent.withValues(alpha: 0.12)
                            : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: widget.isExpanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (profileProvider.isSignedIn)
                      AvatarWidget(
                        wallet: user?.walletAddress ?? '',
                        avatarUrl: user?.avatar,
                        radius: widget.isExpanded ? 17 : 16,
                        allowFabricatedFallback: true,
                        enableProfileNavigation: false,
                      )
                    else
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: Icon(
                          Icons.login,
                          size: KubusChromeMetrics.navIcon,
                          color: KubusColorRoles.of(context).foregroundMuted,
                        ),
                      ),
                    if (widget.isExpanded) ...[
                      const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
                      Expanded(
                        child: AnimatedOpacity(
                          opacity: widget.expandAnimation.value,
                          duration: const Duration(milliseconds: 150),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                !profileProvider.isSignedIn
                                    ? AppLocalizations.of(context)!.commonSignIn
                                    : user?.displayName ??
                                        AppLocalizations.of(context)!
                                            .profilePersonaArtEnthusiast,
                                style: KubusTextStyles.profileName.copyWith(
                                  color: isSelected
                                      ? widget.activeAccent
                                      : scheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              if (user?.username != null)
                                Text(
                                  '@${user!.username}',
                                  style: KubusTextStyles.profileHandle.copyWith(
                                    color: isSelected
                                        ? widget.activeAccent
                                            .withValues(alpha: 0.82)
                                        : scheme.onSurface
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
                        color: isSelected
                            ? widget.activeAccent.withValues(alpha: 0.82)
                            : scheme.onSurface.withValues(alpha: 0.6),
                        size: KubusHeaderMetrics.actionIcon,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
