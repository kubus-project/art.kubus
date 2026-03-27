import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

import '../models/recent_activity.dart';
import '../utils/app_color_utils.dart';
import '../utils/design_tokens.dart';
import 'glass_components.dart';

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
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final description = activity.description.trim().isNotEmpty
        ? activity.description
        : (activity.metadata['message']?.toString() ?? '');
    final isUnread = !activity.isRead;
    final tileColor = accentColor ??
        AppColorUtils.activityColor(activity.category.name, theme.colorScheme);
    final baseSurface =
        isUnread ? scheme.secondaryContainer : scheme.primaryContainer;
    final style = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.card,
      tintBase: baseSurface,
    );

    final radius = BorderRadius.circular(KubusRadius.md);

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: isUnread
                    ? tileColor.withValues(alpha: 0.38)
                    : scheme.outline.withValues(alpha: 0.20),
              ),
              boxShadow: [
                BoxShadow(
                  color: tileColor.withValues(alpha: isDark ? 0.10 : 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: LiquidGlassCard(
              padding: const EdgeInsets.all(KubusSpacing.md),
              margin: EdgeInsets.zero,
              borderRadius: radius,
              blurSigma: style.blurSigma,
              showBorder: false,
              backgroundColor: style.tintColor,
              fallbackMinOpacity: style.fallbackMinOpacity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              tileColor.withValues(alpha: 0.10),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: KubusChromeMetrics.heroIconBox,
                        height: KubusChromeMetrics.heroIconBox,
                        decoration: BoxDecoration(
                          color: tileColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(KubusRadius.sm),
                        ),
                        child: Icon(
                          AppColorUtils.activityIcon(activity.category),
                          color: tileColor,
                          size: KubusHeaderMetrics.actionIcon,
                        ),
                      ),
                      const SizedBox(width: KubusSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    activity.title,
                                    style:
                                        KubusTextStyles.sectionTitle.copyWith(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: isUnread
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (isUnread)
                                  Container(
                                    width: KubusSpacing.xs,
                                    height: KubusSpacing.xs,
                                    decoration: BoxDecoration(
                                      color: tileColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: KubusSpacing.xxs),
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: KubusTextStyles.navMetaLabel.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                            const SizedBox(height: KubusSpacing.xxs),
                            Text(
                              formatActivityTime(context, activity.timestamp),
                              style: KubusTextStyles.compactBadge.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
