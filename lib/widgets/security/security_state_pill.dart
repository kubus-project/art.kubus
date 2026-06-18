import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';

enum SecurityHubStatus {
  secured,
  available,
  recommended,
  failed,
  disabled,
  destructive,
}

extension SecurityHubStatusStyle on SecurityHubStatus {
  Color color(ColorScheme scheme) {
    return switch (this) {
      SecurityHubStatus.secured => KubusColors.success,
      SecurityHubStatus.available => KubusColors.accentBlue,
      SecurityHubStatus.recommended => KubusColors.warning,
      SecurityHubStatus.failed => KubusColors.error,
      SecurityHubStatus.disabled => scheme.outline,
      SecurityHubStatus.destructive => scheme.error,
    };
  }

  String get defaultLabel {
    return switch (this) {
      SecurityHubStatus.secured => 'Secured',
      SecurityHubStatus.available => 'Available',
      SecurityHubStatus.recommended => 'Recommended',
      SecurityHubStatus.failed => 'Failed',
      SecurityHubStatus.disabled => 'Disabled',
      SecurityHubStatus.destructive => 'Destructive',
    };
  }
}

class SecurityStatePill extends StatelessWidget {
  const SecurityStatePill({
    super.key,
    required this.status,
    this.label,
  });

  final SecurityHubStatus status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = status.color(scheme);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.sm,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: KubusRadius.circular(KubusRadius.xl),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label ?? status.defaultLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
