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

class KubusActionSidebarTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final KubusActionSemantic semantic;
  final VoidCallback onTap;
  final Widget? trailing;

  const KubusActionSidebarTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.semantic,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final accent = semantic.accentColor(context);
    final tileTint = accent.withValues(alpha: isDark ? 0.16 : 0.10);

    final radius = BorderRadius.circular(KubusRadius.md);
    final iconRadius = BorderRadius.circular(KubusRadius.sm);

    final fallbackTrailing = Icon(
      Icons.arrow_forward_ios,
      size: KubusSizes.trailingChevron,
      color: scheme.onSurface.withValues(alpha: 0.4),
    );

    return Padding(
      padding:
          const EdgeInsets.only(bottom: KubusSpacing.sm + KubusSpacing.xs),
      child: LiquidGlassCard(
        padding: EdgeInsets.zero,
        borderRadius: radius,
        showBorder: false,
        backgroundColor: tileTint,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: accent.withValues(alpha: 0.20),
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
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: iconRadius,
                  ),
                  child: Icon(
                    icon,
                    color: accent,
                    size: KubusSizes.sidebarActionIcon,
                  ),
                ),
                const SizedBox(width: KubusSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: KubusTextStyles.actionTileTitle.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: KubusSpacing.xxs),
                      Text(
                        subtitle,
                        style: KubusTextStyles.actionTileSubtitle.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ?? fallbackTrailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
