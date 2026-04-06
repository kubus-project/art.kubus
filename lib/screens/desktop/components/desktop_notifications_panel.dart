import 'dart:async';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/recent_activity.dart';
import '../../../providers/app_mode_provider.dart';
import '../../../providers/recent_activity_provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../utils/design_tokens.dart';
import '../../../widgets/app_mode_unavailable_state.dart';
import '../../../widgets/common/kubus_screen_header.dart';
import '../../../widgets/glass_components.dart';
import '../../../widgets/recent_activity_tile.dart';
import '../../../widgets/topbar_icon.dart';

class DesktopNotificationsPanel extends StatelessWidget {
  final VoidCallback onClose;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onMarkAllRead;
  final Future<void> Function(RecentActivity activity) onActivitySelected;
  final bool unreadOnly;
  final int? visibleLimit;

  const DesktopNotificationsPanel({
    super.key,
    required this.onClose,
    required this.onRefresh,
    required this.onMarkAllRead,
    required this.onActivitySelected,
    this.unreadOnly = false,
    this.visibleLimit,
  });

  static bool shouldShowUnavailableInFallback({
    required bool isIpfsFallbackMode,
    required int activityCount,
  }) {
    return isIpfsFallbackMode && activityCount == 0;
  }

  static bool _isNotificationItem(RecentActivity activity) {
    // The RecentActivityProvider is a *unified* timeline (notifications + local
    // in-app notifications + the user's own actions). This panel is explicitly
    // "Notifications", so exclude local user actions.
    return !activity.isUserAction;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final appModeProvider = context.watch<AppModeProvider?>();
    final l10n = AppLocalizations.of(context)!;
    final isIpfsFallbackMode = appModeProvider?.isIpfsFallbackMode ?? false;
    final glassStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.panelBackground,
      tintBase: scheme.surface,
    );
    final unreadCount = context.select<RecentActivityProvider, int>((p) {
      var count = 0;
      for (final activity in p.activities) {
        if (!_isNotificationItem(activity)) continue;
        if (!activity.isRead) count++;
      }
      return count;
    });
    final hasUnread = unreadCount > 0;
    final headerSummary = hasUnread
        ? '$unreadCount ${l10n.desktopHomeUnreadNotificationsLabel}'
        : l10n.homeAllCaughtUpDescription;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: theme.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.06)
                : scheme.outline.withValues(alpha: 0.10),
          ),
        ),
      ),
      child: LiquidGlassPanel(
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        borderRadius: BorderRadius.zero,
        blurSigma: glassStyle.blurSigma,
        showBorder: false,
        fallbackMinOpacity: glassStyle.fallbackMinOpacity,
        backgroundColor: glassStyle.tintColor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KubusSpacing.lg,
                KubusSpacing.lg,
                KubusSpacing.md,
                KubusSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: KubusHeaderText(
                      title: l10n.commonNotifications,
                      subtitle: headerSummary,
                      kind: KubusHeaderKind.section,
                      titleColor: scheme.onSurface,
                      subtitleColor: scheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(width: KubusSpacing.sm),
                  TopBarIcon(
                    tooltip: l10n.commonRefresh,
                    onPressed: isIpfsFallbackMode
                        ? null
                        : () => unawaited(onRefresh()),
                    icon: Icon(
                      Icons.refresh,
                      color: scheme.onSurface.withValues(alpha: 0.82),
                    ),
                  ),
                  const SizedBox(width: KubusSpacing.xs),
                  TopBarIcon(
                    tooltip: l10n.homeMarkAllReadButton,
                    onPressed: isIpfsFallbackMode
                        ? null
                        : (hasUnread ? () => unawaited(onMarkAllRead()) : null),
                    icon: Icon(
                      Icons.done_all_outlined,
                      color: hasUnread
                          ? themeProvider.accentColor
                          : scheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: KubusSpacing.xs),
                  TopBarIcon(
                    tooltip: l10n.commonClose,
                    onPressed: onClose,
                    icon: Icon(
                      Icons.close,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: scheme.outline.withValues(alpha: 0.20),
            ),
            Expanded(
              child: Consumer<RecentActivityProvider>(
                builder: (context, activityProvider, _) {
                  Iterable<RecentActivity> filtered =
                      activityProvider.activities.where(_isNotificationItem);

                  if (unreadOnly) {
                    filtered = filtered.where((a) => !a.isRead);
                  }

                  if (visibleLimit != null) {
                    filtered = filtered.take(visibleLimit!);
                  } else if (unreadOnly) {
                    filtered = filtered.take(10);
                  }

                  final activities = filtered.toList(growable: false);

                  if (shouldShowUnavailableInFallback(
                    isIpfsFallbackMode: isIpfsFallbackMode,
                    activityCount: activities.length,
                  )) {
                    return const AppModeUnavailableState(
                      featureLabel: 'Notifications',
                      title: 'Notifications unavailable',
                      icon: Icons.notifications_off_outlined,
                      padding: EdgeInsets.all(KubusSpacing.lg),
                    );
                  }

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
                        padding: const EdgeInsets.all(KubusSpacing.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: KubusSpacing.xxl,
                              color: scheme.error,
                            ),
                            const SizedBox(
                              height: KubusSpacing.sm + KubusSpacing.xxs,
                            ),
                            Text(
                              activityProvider.error!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(
                              height: KubusSpacing.sm + KubusSpacing.xxs,
                            ),
                            TextButton(
                              onPressed: () => unawaited(onRefresh()),
                              child: Text(
                                l10n.commonRetry,
                                style: theme.textTheme.labelLarge?.copyWith(
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
                      child: Padding(
                        padding: const EdgeInsets.all(KubusSpacing.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: KubusSpacing.xxl + KubusSpacing.xl,
                              color: scheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: KubusSpacing.md),
                            Text(
                              l10n.homeNoNotificationsTitle,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.72),
                              ),
                            ),
                            const SizedBox(height: KubusSpacing.xxs),
                            Text(
                              l10n.homeAllCaughtUpDescription,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      KubusSpacing.md,
                      KubusSpacing.md,
                      KubusSpacing.md,
                      KubusSpacing.lg,
                    ),
                    itemCount: activities.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: KubusSpacing.sm),
                    itemBuilder: (context, index) {
                      final activity = activities[index];
                      return RecentActivityTile(
                        activity: activity,
                        margin: EdgeInsets.zero,
                        onTap: () => unawaited(onActivitySelected(activity)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
