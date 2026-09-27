import 'package:flutter/material.dart';

import '../models/recent_activity.dart';
import '../utils/app_color_utils.dart';
import 'activity_time_format.dart';
import 'common/kubus_activity_row.dart';

/// Shared tile UI for mobile and desktop activity surfaces (flat v5 row).
class RecentActivityTile extends StatelessWidget {
  final RecentActivity activity;
  final Color? accentColor;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  const RecentActivityTile({
    super.key,
    required this.activity,
    this.accentColor,
    this.margin = const EdgeInsets.only(bottom: 8),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final description = activity.description.trim().isNotEmpty
        ? activity.description
        : (activity.metadata['message']?.toString() ?? '');
    return KubusActivityRow(
      icon: AppColorUtils.activityIcon(activity.category),
      iconColor: accentColor ??
          AppColorUtils.activityColor(
            activity.category.name,
            Theme.of(context).colorScheme,
          ),
      title: activity.title,
      description: description,
      timeLabel: formatActivityTime(context, activity.timestamp),
      isUnread: !activity.isRead,
      onTap: onTap,
      margin: margin,
    );
  }
}
