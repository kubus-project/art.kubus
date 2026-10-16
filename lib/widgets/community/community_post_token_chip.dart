import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';

class CommunityPostTokenChip extends StatelessWidget {
  const CommunityPostTokenChip({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final radius = BorderRadius.circular(KubusRadius.control);
    const padding = EdgeInsets.symmetric(
      horizontal: KubusSpacing.sm + KubusSpacing.xxs,
      vertical: KubusSpacing.xs,
    );
    final decoration = BoxDecoration(
      color: roles.surfaceRaised,
      borderRadius: radius,
      border: Border.all(color: roles.rule, width: KubusSizes.hairline),
    );
    final text = Text(
      label,
      style: KubusTextStyles.navMetaLabel.copyWith(
        fontWeight: FontWeight.w500,
        color: roles.foreground,
      ),
    );
    // A static chip has no Material of its own. Ink would paint on the nearest
    // Material ancestor, which inside a post card sits behind the card's opaque
    // surface and hides the fill and border, so it is an ordinary decorated box.
    if (onTap == null) {
      return Container(padding: padding, decoration: decoration, child: text);
    }
    final chip = Ink(padding: padding, decoration: decoration, child: text);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          hoverColor: roles.active.withValues(alpha: 0.08),
          focusColor: roles.active.withValues(alpha: 0.14),
          borderRadius: radius,
          child: chip,
        ),
      ),
    );
  }
}
