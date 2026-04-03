import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../glass_components.dart';

class KubusStatCard extends StatelessWidget {
  const KubusStatCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.accent,
    this.tintBase,
    this.onTap,
    this.borderColor,
    this.titleStyle,
    this.valueStyle,
    this.padding = const EdgeInsets.all(KubusChromeMetrics.compactCardPadding),
    this.minHeight = 112,
    this.titleMaxLines = 1,
    this.iconBoxSize = KubusSizes.sidebarActionIconBox - KubusSpacing.sm,
    this.iconSize = KubusSizes.sidebarActionIcon,
    this.borderRadius,
    this.change,
    this.isPositiveChange = true,
  });

  final String title;
  final String value;
  final IconData? icon;
  final Color? accent;
  final Color? tintBase;
  final VoidCallback? onTap;
  final Color? borderColor;
  final TextStyle? titleStyle;
  final TextStyle? valueStyle;
  final EdgeInsetsGeometry padding;
  final double minHeight;
  final int titleMaxLines;
  final double iconBoxSize;
  final double iconSize;
  final BorderRadius? borderRadius;
  final String? change;
  final bool isPositiveChange;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveAccent = accent ?? scheme.primary;
    final effectiveRadius =
        borderRadius ?? BorderRadius.circular(KubusRadius.md);
    final glassStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.card,
      tintBase: tintBase ?? effectiveAccent,
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        border: Border.all(
          color: borderColor ?? effectiveAccent.withValues(alpha: 0.22),
          width: KubusSizes.hairline,
        ),
      ),
      child: LiquidGlassCard(
        padding: padding,
        margin: EdgeInsets.zero,
        borderRadius: effectiveRadius,
        showBorder: false,
        blurSigma: glassStyle.blurSigma,
        fallbackMinOpacity: glassStyle.fallbackMinOpacity,
        backgroundColor: glassStyle.tintColor,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Container(
                      width: iconBoxSize,
                      height: iconBoxSize,
                      decoration: BoxDecoration(
                        color: effectiveAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(KubusRadius.sm),
                      ),
                      child: Icon(
                        icon,
                        color: effectiveAccent,
                        size: iconSize,
                      ),
                    ),
                    const SizedBox(width: KubusSpacing.sm),
                  ],
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: change == null ? 0 : KubusSpacing.xs,
                      ),
                      child: Text(
                        title,
                        maxLines: titleMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle ??
                            KubusTextStyles.actionTileTitle.copyWith(
                              fontSize: 15,
                              color: scheme.onSurface,
                            ),
                      ),
                    ),
                  ),
                  if (change != null)
                    _KubusStatChangeChip(
                      label: change!,
                      isPositive: isPositiveChange,
                    ),
                ],
              ),
              const Spacer(),
              const SizedBox(height: KubusSpacing.xs),
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    alignment: Alignment.center,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: valueStyle ??
                          KubusTextStyles.sectionTitle.copyWith(
                            fontSize: KubusHeaderMetrics.sectionTitle + 2,
                            color: scheme.onSurface,
                          ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KubusStatChangeChip extends StatelessWidget {
  const _KubusStatChangeChip({
    required this.label,
    required this.isPositive,
  });

  final String label;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final changeColor =
        isPositive ? roles.positiveAction : roles.negativeAction;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.sm,
        vertical: KubusSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: changeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(KubusRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            size: KubusHeaderMetrics.sectionSubtitle,
            color: changeColor,
          ),
          const SizedBox(width: KubusSpacing.xxs),
          Text(
            label,
            style: KubusTextStyles.statChange.copyWith(
              color: changeColor,
            ),
          ),
        ],
      ),
    );
  }
}
