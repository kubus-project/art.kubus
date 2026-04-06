import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/recent_activity.dart';
import '../../providers/recent_activity_provider.dart';
import '../../utils/design_tokens.dart';
import '../common/kubus_screen_header.dart';
import '../empty_state_card.dart';
import '../glass_components.dart';
import '../notification_tile.dart';
import '../topbar_icon.dart';

/// Shared notifications bottom sheet (mobile-first).
///
/// Renders actual notifications (backend + in-app), excluding local user-action
/// entries from the unified RecentActivityProvider.
class KubusNotificationsSheet extends StatelessWidget {
  const KubusNotificationsSheet({
    super.key,
    required this.onNotificationSelected,
    this.unreadOnly = false,
    this.visibleLimit,
    this.onRefresh,
  });

  final Future<void> Function(RecentActivity activity) onNotificationSelected;
  final bool unreadOnly;
  final int? visibleLimit;
  final Future<void> Function()? onRefresh;

  static bool isNotificationItem(RecentActivity activity) {
    return !activity.isUserAction;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
      child: BackdropGlassSheet(
        showHandle: false,
        showBorder: false,
        padding: EdgeInsets.zero,
        backgroundColor: scheme.surface,
        child: Column(
          children: [
            KubusSheetHeader(
              title: l10n.commonNotifications,
              trailing: TopBarIcon(
                tooltip: l10n.commonRefresh,
                icon: Icon(
                  Icons.refresh,
                  color: scheme.onSurface,
                ),
                onPressed: () {
                  final provider =
                      Provider.of<RecentActivityProvider>(context, listen: false);
                  unawaited((onRefresh ??
                          () => provider.refresh(force: true))
                      .call());
                },
              ),
            ),
            Expanded(
              child: Consumer<RecentActivityProvider>(
                builder: (context, activityProvider, _) {
                  Iterable<RecentActivity> items =
                      activityProvider.activities.where(isNotificationItem);

                  if (unreadOnly) {
                    items = items.where((activity) => !activity.isRead);
                  }

                  if (visibleLimit != null) {
                    items = items.take(visibleLimit!);
                  }

                  final notifications = items.toList(growable: false);

                  final isLoading =
                      activityProvider.isLoading && notifications.isEmpty;
                  final hasError =
                      activityProvider.error != null && notifications.isEmpty;

                  if (hasError && kDebugMode) {
                    debugPrint(
                      'KubusNotificationsSheet: notifications load failed: ${activityProvider.error}',
                    );
                  }

                  if (isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return RefreshIndicator(
                    onRefresh: () => activityProvider.refresh(force: true),
                    child: notifications.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: KubusSpacing.xl + KubusSpacing.sm,
                              vertical: KubusSpacing.xxl,
                            ),
                            children: [
                              EmptyStateCard(
                                icon: hasError
                                    ? Icons.error_outline
                                    : Icons.notifications_off_outlined,
                                title: hasError
                                    ? l10n.homeUnableToLoadNotificationsTitle
                                    : l10n.homeNoNotificationsTitle,
                                description: hasError
                                    ? l10n.commonSomethingWentWrong
                                    : l10n.homeAllCaughtUpDescription,
                                showAction: hasError,
                                actionLabel: hasError ? l10n.commonRetry : null,
                                onAction: hasError
                                    ? () => activityProvider.refresh(force: true)
                                    : null,
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: KubusSpacing.lg,
                              vertical: KubusSpacing.sm + KubusSpacing.xxs,
                            ),
                            itemCount: notifications.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: KubusSpacing.sm),
                            itemBuilder: (context, index) {
                              final activity = notifications[index];
                              return NotificationTile(
                                notification: activity,
                                onTap: () => unawaited(
                                  onNotificationSelected(activity),
                                ),
                                margin: EdgeInsets.zero,
                              );
                            },
                          ),
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
