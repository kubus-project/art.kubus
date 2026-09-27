import 'package:flutter/material.dart';

import '../models/recent_activity.dart';
import '../utils/app_color_utils.dart';
import 'activity_time_format.dart';
import 'common/kubus_activity_row.dart';

/// Tile UI for notification surfaces (flat PRODUCT v5 row).
class NotificationTile extends StatelessWidget {
  final RecentActivity notification;
  final Color? accentColor;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  const NotificationTile({
    super.key,
    required this.notification,
    this.accentColor,
    this.margin = const EdgeInsets.only(bottom: 8),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final description = notification.description.trim().isNotEmpty
        ? notification.description
        : (notification.metadata['message']?.toString() ?? '');
    return KubusActivityRow(
      icon: AppColorUtils.activityIcon(notification.category),
      // Category colour is data semantics and stays on the icon only.
      iconColor: accentColor ??
          AppColorUtils.activityColor(
            notification.category.name,
            Theme.of(context).colorScheme,
          ),
      title: notification.title,
      description: description,
      timeLabel: formatActivityTime(context, notification.timestamp),
      isUnread: !notification.isRead,
      onTap: onTap,
      margin: margin,
    );
  }
}
