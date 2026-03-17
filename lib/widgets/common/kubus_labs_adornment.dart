import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/kubus_labs_feature.dart';

enum KubusLabsAdornmentMode {
  inlinePill,
  compactOverlay,
}

class KubusLabsAdornment extends StatelessWidget {
  const KubusLabsAdornment.inlinePill({
    super.key,
    required this.feature,
    this.emphasized = false,
  }) : mode = KubusLabsAdornmentMode.inlinePill;

  const KubusLabsAdornment.compactOverlay({
    super.key,
    required this.feature,
    this.emphasized = false,
  }) : mode = KubusLabsAdornmentMode.compactOverlay;

  final KubusLabsFeature feature;
  final KubusLabsAdornmentMode mode;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    if (!feature.showLabsMarker) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final roles = KubusColorRoles.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = feature.accent(roles);
    final label = l10n?.commonLabLabel ?? 'Lab';
    final semanticsLabel = l10n == null ? label : feature.semanticsLabel(l10n);

    switch (mode) {
      case KubusLabsAdornmentMode.inlinePill:
        final background = accent.withValues(
          alpha: emphasized ? (isDark ? 0.24 : 0.16) : (isDark ? 0.18 : 0.12),
        );
        final borderColor = accent.withValues(alpha: emphasized ? 0.70 : 0.45);
        return Semantics(
          label: semanticsLabel,
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KubusSpacing.sm,
                vertical: KubusSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(KubusRadius.xl),
                border: Border.all(
                  color: borderColor,
                  width: KubusSizes.hairline,
                ),
                boxShadow: emphasized
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.14),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.science_outlined,
                    size: 12,
                    color: accent,
                  ),
                  const SizedBox(width: KubusSpacing.xs),
                  Text(
                    label,
                    style: KubusTypography.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      case KubusLabsAdornmentMode.compactOverlay:
        return Semantics(
          label: semanticsLabel,
          child: ExcludeSemantics(
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(KubusRadius.xl),
                border: Border.all(
                  color: accent.withValues(alpha: emphasized ? 0.9 : 0.7),
                  width: KubusSizes.hairline,
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.16),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.science_outlined,
                size: 10,
                color: accent,
              ),
            ),
          ),
        );
    }
  }
}
