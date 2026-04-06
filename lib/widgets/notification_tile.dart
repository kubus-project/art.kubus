import 'package:flutter/material.dart';

import '../models/recent_activity.dart';
import '../utils/app_color_utils.dart';
import '../utils/design_tokens.dart';
import 'activity_time_format.dart';
import 'glass_components.dart';

/// Tile UI for notification surfaces.
///
/// This is intentionally close to [RecentActivityTile] (same glass card design),
/// but with one key difference: when a notification is read, the tile becomes
/// visually muted/gray.
class NotificationTile extends StatelessWidget {
  final RecentActivity notification;
  final Color? accentColor;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  const NotificationTile({
    super.key,
    required this.notification,
    this.accentColor,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final description = notification.description.trim().isNotEmpty
        ? notification.description
        : (notification.metadata['message']?.toString() ?? '');

    final isUnread = !notification.isRead;

    final baseAccent = accentColor ??
      AppColorUtils.activityColor(
        notification.category.name,
        theme.colorScheme,
      );

    // Accent usage rule:
    // - Unread: accent influences the whole tile (border/gradient/background).
    // - Read: tile becomes neutral/gray; accent remains ONLY on the icon.
    final decorColor = isUnread
      ? baseAccent
      : scheme.onSurface.withValues(alpha: isDark ? 0.40 : 0.35);
    final iconColor = baseAccent;

    // Keep the same "unread pops" feeling as RecentActivityTile; read items
    // shift onto a more neutral surface.
    final baseSurface =
        isUnread ? scheme.secondaryContainer : scheme.surfaceContainerHighest;

    final style = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.card,
      tintBase: baseSurface,
    );

    final radius = BorderRadius.circular(KubusRadius.md);

    final borderColor = isUnread
      ? decorColor.withValues(alpha: 0.38)
        : scheme.outline.withValues(alpha: isDark ? 0.26 : 0.22);

    final shadowColor = (isUnread ? decorColor : scheme.shadow)
        .withValues(alpha: isDark ? 0.10 : 0.08);

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
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: LiquidGlassCard(
              padding: EdgeInsets.zero,
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
                              decorColor.withValues(
                                alpha: isUnread ? 0.10 : 0.06,
                              ),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(KubusSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: KubusChromeMetrics.heroIconBox,
                          height: KubusChromeMetrics.heroIconBox,
                          decoration: BoxDecoration(
                            color: isUnread
                                ? decorColor.withValues(alpha: 0.12)
                                : scheme.onSurface.withValues(
                                    alpha: isDark ? 0.08 : 0.06,
                                  ),
                            borderRadius: BorderRadius.circular(KubusRadius.sm),
                          ),
                          child: Icon(
                            AppColorUtils.activityIcon(notification.category),
                            color:
                                iconColor.withValues(alpha: isUnread ? 1.0 : 0.90),
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
                                      notification.title,
                                      style: KubusTextStyles.sectionTitle.copyWith(
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
                                        color: decorColor,
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
                                        .withValues(alpha: isUnread ? 0.70 : 0.58),
                                  ),
                                ),
                              ],
                              const SizedBox(height: KubusSpacing.xxs),
                              Text(
                                formatActivityTime(context, notification.timestamp),
                                style: KubusTextStyles.compactBadge.copyWith(
                                  color: scheme.onSurface
                                      .withValues(alpha: isUnread ? 0.50 : 0.42),
                                ),
                              ),
                            ],
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
      ),
    );
  }
}
