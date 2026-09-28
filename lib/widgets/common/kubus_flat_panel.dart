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
