import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:art_kubus/l10n/app_localizations.dart';

import '../models/recent_activity.dart';
import '../utils/app_color_utils.dart';

/// Shared tile UI for both mobile and desktop notification/activity surfaces.
class RecentActivityTile extends StatelessWidget {
  final RecentActivity activity;
  final Color? accentColor;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  const RecentActivityTile({
    super.key,
    required this.activity,
    this.accentColor,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = activity.description.trim().isNotEmpty
        ? activity.description
        : (activity.metadata['message']?.toString() ?? '');
    final isUnread = !activity.isRead;
    final tileColor = accentColor ??
        AppColorUtils.activityColor(activity.category.name, theme.colorScheme);

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isUnread
                  ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.7)
                  : theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isUnread
                    ? tileColor.withValues(alpha: 0.4)
                    : theme.colorScheme.outline,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tileColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    AppColorUtils.activityIcon(activity.category),
                    color: tileColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              activity.title,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: tileColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        formatActivityTime(context, activity.timestamp),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String formatActivityTime(BuildContext context, DateTime timestamp) {
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now();
  final diff = now.difference(timestamp);
  if (diff.inMinutes < 1) return l10n.commonJustNow;
  if (diff.inMinutes < 60) return l10n.commonTimeAgoMinutes(diff.inMinutes);
  if (diff.inHours < 24) return l10n.commonTimeAgoHours(diff.inHours);
  if (diff.inDays < 7) return l10n.commonTimeAgoDays(diff.inDays);
  return MaterialLocalizations.of(context).formatShortDate(timestamp);
}

