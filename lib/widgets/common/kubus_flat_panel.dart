import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';

/// PRODUCT v5 content panel: surface fill and a hairline rule. The drop-in
/// replacement for `LiquidGlassCard` on ordinary (non-overlay) content;
/// glass stays reserved for map, AR, media and transient overlays.
class KubusFlatPanel extends StatelessWidget {
  const KubusFlatPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: roles.surface,
        borderRadius:
            borderRadius ?? BorderRadius.circular(KubusRadius.surface),
        border: Border.all(color: roles.rule),
      ),
      child: child,
    );
  }
}

/// Flat, selectable option (duration chips, slot tiles, tiers, dates).
/// Selection is shown by an active-role rule and `selected` semantics,
/// never by an accent-tinted fill; an invalid option (for example an
/// unavailable slot) gets an error rule. Minimum target 44 px.
class KubusFlatSelectable extends StatelessWidget {
  const KubusFlatSelectable({
    super.key,
    required this.child,
    required this.onTap,
    this.selected = false,
    this.invalid = false,
    this.padding = const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xs),
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final bool invalid;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final radius = borderRadius ?? BorderRadius.circular(KubusRadius.surface);
    final side = invalid
        ? BorderSide(color: roles.error, width: selected ? 2 : 1)
        : (selected
            ? BorderSide(color: roles.active, width: 2)
            : BorderSide(color: roles.rule));
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: Material(
        color: selected ? roles.surfaceRaised : roles.surface,
        shape: RoundedRectangleBorder(borderRadius: radius, side: side),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          focusColor: roles.focus.withValues(alpha: 0.12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
