import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';
import '../utils/kubus_color_roles.dart';
import 'glass_components.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final selected = widget.selected;
    final enabled = widget.enabled;

    final accent = widget.semantic.accentColor(context);
    final stateAccent = enabled
        ? accent
        : scheme.onSurface.withValues(alpha: 0.45);
    final tileTint = !enabled
        ? scheme.surface.withValues(alpha: isDark ? 0.10 : 0.08)
        : selected
            ? accent.withValues(alpha: isDark ? 0.22 : 0.14)
            : _isHovered
                ? accent.withValues(alpha: isDark ? 0.18 : 0.12)
                : accent.withValues(alpha: isDark ? 0.14 : 0.08);

    final radius = BorderRadius.circular(KubusRadius.md);
    final iconRadius = BorderRadius.circular(KubusRadius.sm);

    final fallbackTrailing = Icon(
      Icons.arrow_forward_ios,
      size: KubusSizes.trailingChevron,
      color: scheme.onSurface.withValues(alpha: enabled ? 0.4 : 0.28),
    );

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: enabled ? (_) => setState(() => _isHovered = false) : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.72,
        child: Padding(
          padding:
              const EdgeInsets.only(bottom: KubusSpacing.sm + KubusSpacing.xs),
          child: LiquidGlassCard(
            padding: EdgeInsets.zero,
            borderRadius: radius,
            showBorder: false,
            backgroundColor: tileTint,
            onTap: enabled ? widget.onTap : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: stateAccent.withValues(
                    alpha: selected ? 0.32 : (_isHovered ? 0.24 : 0.18),
                  ),
                  width: KubusSizes.hairline,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(KubusSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: KubusSizes.sidebarActionIconBox,
                      height: KubusSizes.sidebarActionIconBox,
                      decoration: BoxDecoration(
                        color: stateAccent.withValues(alpha: 0.15),
                        borderRadius: iconRadius,
                      ),
                      child: Icon(
                        widget.icon,
                        color: stateAccent,
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
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: KubusSpacing.xxs),
                          Text(
                            widget.subtitle,
                            style: KubusTextStyles.actionTileSubtitle.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    widget.trailing ?? fallbackTrailing,
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
