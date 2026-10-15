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
    final chip = Ink(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.sm + KubusSpacing.xxs,
        vertical: KubusSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: roles.surfaceRaised,
        borderRadius: radius,
        border: Border.all(color: roles.rule, width: KubusSizes.hairline),
      ),
      child: Text(
        label,
        style: KubusTextStyles.navMetaLabel.copyWith(
          fontWeight: FontWeight.w500,
          color: roles.foreground,
        ),
      ),
    );
    if (onTap == null) return chip;
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
