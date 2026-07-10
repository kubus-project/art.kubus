import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';

enum KubusBadgeVariant {
  /// Neutral descriptive tag (category, metadata).
  label,

  /// Colored state pill (Draft/Live/Pending...). Pass [KubusBadge.accent].
  status,

  /// Compact numeric counter (unread counts).
  count,
}

/// Canonical pill badge. Replaces `CreatorStatusBadge` clones and ad-hoc
/// count/label pills. Colors must come from roles/scheme via [accent] —
/// this widget never invents hues.
class KubusBadge extends StatelessWidget {
  const KubusBadge({
    super.key,
    required this.text,
    this.variant = KubusBadgeVariant.label,
    this.accent,
    this.icon,
    this.compact = false,
  });

  final String text;
  final KubusBadgeVariant variant;

  /// Contextual accent (from KubusColorRoles / scheme). Defaults to
  /// scheme.primary for status/count and scheme.onSurface for label.
  final Color? accent;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLabel = variant == KubusBadgeVariant.label;
    final color = accent ?? (isLabel ? scheme.onSurface : scheme.primary);

    final background = color.withValues(alpha: isLabel ? 0.08 : 0.14);
    final foreground =
        isLabel ? scheme.onSurface.withValues(alpha: 0.85) : color;

    final style = (variant == KubusBadgeVariant.count
            ? KubusTextStyles.badgeCount
            : KubusTextStyles.navMetaLabel)
        .copyWith(color: foreground, fontWeight: FontWeight.w600);

    final horizontal = compact ? KubusSpacing.sm : KubusSpacing.sm + 2;
    final vertical = compact ? KubusSpacing.xxs : KubusSpacing.xs;

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(KubusRadius.xl),
        border: KubusBorders.accentTint(color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: KubusSizes.trailingChevron, color: foreground),
            const SizedBox(width: KubusSpacing.xs),
          ],
          Text(text, style: style),
        ],
      ),
    );
  }
}
