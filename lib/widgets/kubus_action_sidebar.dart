import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';
import '../utils/kubus_color_roles.dart';
import 'common/kubus_stat_card.dart';

enum KubusActionSemantic {
  create,
  publish,
  edit,
  invite,
  delete,
  manage,
  view,
  analytics,
}

extension KubusActionSemanticX on KubusActionSemantic {
  Color accentColor(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final scheme = Theme.of(context).colorScheme;
    switch (this) {
      case KubusActionSemantic.create:
      case KubusActionSemantic.publish:
        return roles.positiveAction;
      case KubusActionSemantic.edit:
      case KubusActionSemantic.manage:
        return scheme.primary;
      case KubusActionSemantic.invite:
        return roles.web3InstitutionAccent;
      case KubusActionSemantic.delete:
        return roles.negativeAction;
      case KubusActionSemantic.analytics:
        return roles.statTeal;
      case KubusActionSemantic.view:
        return scheme.secondary;
    }
  }
}

class KubusActionSidebarTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final KubusActionSemantic semantic;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool selected;
  final bool enabled;

  const KubusActionSidebarTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.semantic,
    required this.onTap,
    this.trailing,
    this.selected = false,
    this.enabled = true,
  });

  @override
  State<KubusActionSidebarTile> createState() => _KubusActionSidebarTileState();
}

class _KubusActionSidebarTileState extends State<KubusActionSidebarTile> {
  bool _isHovered = false;

  // PRODUCT v5: a flat row with a hairline rule. Hover/selection strengthen
  // the rule; the icon is neutral (the semantic accent is no longer painted
  // as a tinted tile). The whole row is one button with a 48 px minimum.
  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final selected = widget.selected;
    final enabled = widget.enabled;
    final radius = BorderRadius.circular(KubusRadius.surface);
    final ruleColor = selected
        ? roles.active
        : (_isHovered && enabled ? roles.ruleStrong : roles.rule);

    final fallbackTrailing = Icon(
      Icons.chevron_right,
      size: KubusSizes.trailingChevron + 4,
      color: enabled ? roles.foregroundMuted : roles.foregroundSubtle,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: selected,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: enabled ? (_) => setState(() => _isHovered = true) : null,
          onExit: enabled ? (_) => setState(() => _isHovered = false) : null,
          child: Material(
            color: selected ? roles.surfaceRaised : roles.surface,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(
                color: ruleColor,
                width: selected ? 1.5 : KubusSizes.hairline,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? widget.onTap : null,
              focusColor: roles.focus.withValues(alpha: 0.12),
              hoverColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KubusSpacing.md,
                    vertical: KubusSpacing.sm + KubusSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          widget.icon,
                          color: enabled
                              ? roles.foreground
                              : roles.foregroundSubtle,
                          size: KubusSizes.sidebarActionIcon,
                        ),
                      ),
                      const SizedBox(width: KubusSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: KubusTextStyles.actionTileTitle.copyWith(
                                color: enabled
                                    ? roles.foreground
                                    : roles.foregroundMuted,
                              ),
                            ),
                            const SizedBox(height: KubusSpacing.xxs),
                            Text(
                              widget.subtitle,
                              style:
                                  KubusTextStyles.actionTileSubtitle.copyWith(
                                color: roles.foregroundMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: KubusSpacing.sm),
                      widget.trailing ?? fallbackTrailing,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact metric for dashboard side panels: the number, then its label, on
/// a flat surface. Replaces the square watermark tile.
class KubusSidebarStatCard extends StatelessWidget {
  const KubusSidebarStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    this.minHeight = 0,
    this.semanticsLabel,
  });

  final String title;
  final String value;
  final IconData icon;

  /// Accepted for compatibility; metrics are not colour-coded.
  final Color accent;
  final double minHeight;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return KubusStatCard(
      title: title,
      value: value,
      icon: icon,
      showIcon: false,
      minHeight: minHeight > 0 ? minHeight : 64,
      titleMaxLines: 2,
      semanticsLabel: semanticsLabel,
      padding: const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xs),
    );
  }
}
