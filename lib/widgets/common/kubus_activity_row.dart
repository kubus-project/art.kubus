import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';

/// Flat notification/activity row shared by `NotificationTile` and
/// `RecentActivityTile`.
///
/// Unread state is carried by a leading active rule, a dot, a heavier title
/// *and* an explicit "Unread" semantic prefix, never by colour alone. The
/// category icon keeps its data colour; the row itself stays neutral (no
/// glass, gradient or shadow).
class KubusActivityRow extends StatelessWidget {
  const KubusActivityRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.timeLabel,
    required this.isUnread,
    this.onTap,
    this.margin = const EdgeInsets.only(bottom: KubusSpacing.sm),
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String timeLabel;
  final bool isUnread;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final l10n = AppLocalizations.of(context);
    final radius = BorderRadius.circular(KubusRadius.surface);
    final semanticParts = <String>[
      if (isUnread && l10n != null) l10n.activityUnreadSemanticLabel,
      title,
      if (description.isNotEmpty) description,
      timeLabel,
    ];

    return Padding(
      padding: margin,
      child: Semantics(
        container: true,
        button: onTap != null,
        label: semanticParts.join('. '),
        onTap: onTap,
        child: ExcludeSemantics(
          child: Material(
            color: isUnread ? roles.surfaceRaised : roles.surface,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(color: roles.rule, width: KubusSizes.hairline),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              focusColor: roles.focus.withValues(alpha: 0.16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 3,
                      color: isUnread ? roles.active : Colors.transparent,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          KubusSpacing.md - 3,
                          KubusSpacing.sm + KubusSpacing.xs,
                          KubusSpacing.md,
                          KubusSpacing.sm + KubusSpacing.xs,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(icon, size: 20, color: iconColor),
                            ),
                            const SizedBox(width: KubusSpacing.sm + 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: KubusTextStyles.sectionTitle
                                              .copyWith(
                                            color: roles.foreground,
                                            fontWeight: isUnread
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (isUnread)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(
                                            left: KubusSpacing.sm,
                                          ),
                                          decoration: BoxDecoration(
                                            color: roles.active,
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
                                      style:
                                          KubusTextStyles.navMetaLabel.copyWith(
                                        color: roles.foregroundMuted,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: KubusSpacing.xs),
                                  Text(
                                    timeLabel,
                                    style:
                                        KubusTextStyles.compactBadge.copyWith(
                                      color: roles.foregroundSubtle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
  }
}
