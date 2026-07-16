import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../common/kubus_badge.dart';

/// Compact shared row used by every destination provider in navigation sheets.
class KubusNavigationOptionRow extends StatelessWidget {
  const KubusNavigationOptionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.statusLabel,
    this.enabled = true,
    this.trailingIcon = Icons.open_in_new,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? statusLabel;
  final bool enabled;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveEnabled = enabled && onTap != null;
    return Semantics(
      button: true,
      enabled: effectiveEnabled,
      label: label,
      child: Opacity(
        opacity: effectiveEnabled ? 1 : 0.5,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: KubusSizes.navigationOptionRowHeight,
          ),
          child: InkWell(
            onTap: effectiveEnabled ? onTap : null,
            borderRadius: BorderRadius.circular(KubusRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KubusSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: KubusSizes.navigationOptionIcon,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: KubusSpacing.md),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: KubusTypography.textTheme.bodyLarge
                                ?.copyWith(color: scheme.onSurface),
                          ),
                        ),
                        if (statusLabel != null) ...[
                          const SizedBox(width: KubusSpacing.sm),
                          KubusBadge(
                            text: statusLabel!,
                            variant: KubusBadgeVariant.status,
                            accent: scheme.primary,
                            compact: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: KubusSpacing.sm),
                  Icon(
                    trailingIcon,
                    size: KubusSizes.trailingChevron,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
