import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../glass_components.dart';

enum KubusStatCardLayout {
  standard,
  centered,
}

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
    this.minHeight = 104,
    this.titleMaxLines = 1,
    this.iconBoxSize = KubusSizes.sidebarActionIconBox - KubusSpacing.sm,
    this.iconSize = KubusSizes.sidebarActionIcon,
    this.borderRadius,
    this.change,
    this.isPositiveChange = true,
    this.layout = KubusStatCardLayout.standard,
    this.showIcon = true,
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
  final KubusStatCardLayout layout;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.maybeOf(context)?.size.width ?? 0;
    final isUltraWide = screenWidth >= 1800;
    final effectiveAccent = accent ?? scheme.primary;
    final shouldShowIcon = showIcon && icon != null;
    final effectiveRadius =
        borderRadius ?? BorderRadius.circular(KubusRadius.md);
    final effectiveMinHeight =
        (layout == KubusStatCardLayout.centered && isUltraWide && minHeight > 0)
            ? (minHeight - 6).clamp(0.0, double.infinity)
            : minHeight;
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
          constraints: BoxConstraints(minHeight: effectiveMinHeight),
          child: layout == KubusStatCardLayout.centered
              ? _buildCenteredContent(
                  context: context,
                  scheme: scheme,
                  effectiveAccent: effectiveAccent,
                  shouldShowIcon: shouldShowIcon,
                )
              : _buildStandardContent(
                  context: context,
                  scheme: scheme,
                  effectiveAccent: effectiveAccent,
                  shouldShowIcon: shouldShowIcon,
                ),
        ),
      ),
    );
  }

  Widget _buildStandardContent({
    required BuildContext context,
    required ColorScheme scheme,
    required Color effectiveAccent,
    required bool shouldShowIcon,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (shouldShowIcon) ...[
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
                  textAlign: TextAlign.center,
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
        const SizedBox(height: KubusSpacing.sm),
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
    );
  }

  Widget _buildCenteredContent({
    required BuildContext context,
    required ColorScheme scheme,
    required Color effectiveAccent,
    required bool shouldShowIcon,
  }) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final screenWidth = mediaQuery?.size.width ?? 0;
    final isUltraWide = screenWidth >= 1800;
    final devicePixelRatio = mediaQuery?.devicePixelRatio ?? 1.0;
    final textScale = mediaQuery?.textScaler.scale(1.0) ?? 1.0;
    final isDesktopLike = screenWidth >= 900;

    final densityScale = devicePixelRatio >= 3.0
        ? 0.92
        : devicePixelRatio <= 1.5
            ? 1.02
            : 0.98;
    final textScaleCompensation =
        textScale > 1.0 ? (1 / textScale.clamp(1.0, 1.25)) : 1.0;
    final watermarkScale = (densityScale * textScaleCompensation).clamp(
      0.94,
      1.06,
    );

    final ultraWideTypeScale = isUltraWide ? 0.96 : 1.0;
    final valueTypeScale = (isDesktopLike ? 0.95 : 0.93) *
        ultraWideTypeScale *
        (textScale > 1.0 ? (1 / textScale.clamp(1.0, 1.20)) : 1.0);
    final titleTypeScale = (isDesktopLike ? 0.93 : 0.90) *
        ultraWideTypeScale *
        (textScale > 1.0 ? (1 / textScale.clamp(1.0, 1.20)) : 1.0);

    final titleTextStyle = titleStyle ??
        KubusTextStyles.statLabel.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.8),
        );
    final valueTextStyle = valueStyle ??
        KubusTextStyles.statValue.copyWith(
          color: scheme.onSurface,
        );

    final effectiveTitleStyle = _scaledTextStyle(
      titleTextStyle,
      factor: titleTypeScale,
    );
    final effectiveValueStyle = _scaledTextStyle(
      valueTextStyle,
      factor: valueTypeScale,
    );

    final valueTitleGap = isUltraWide
        ? KubusSpacing.xxs
        : (devicePixelRatio >= 3.0 ? KubusSpacing.xxs : KubusSpacing.xs);

    return Stack(
      children: [
        if (shouldShowIcon)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRect(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : minHeight;
                    final maxHeight = constraints.maxHeight.isFinite
                        ? constraints.maxHeight
                        : minHeight;

                    final fallbackBase = iconSize + iconBoxSize;
                    final safeWidth = maxWidth > 0 ? maxWidth : fallbackBase;
                    final safeHeight = maxHeight > 0 ? maxHeight : fallbackBase;
                    final widthDrivenSize = safeWidth * 1.32;
                    final minHeightCoverage = safeHeight * 1.34;
                    final maxAllowedSize = safeWidth * 1.56;
                    final iconWatermarkSize = widthDrivenSize.clamp(
                            minHeightCoverage, maxAllowedSize) *
                        watermarkScale;

                    return Align(
                      alignment: Alignment.center,
                      child: Icon(
                        icon,
                        color: effectiveAccent.withValues(alpha: 0.05),
                        size: iconWatermarkSize,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        if (change != null)
          Positioned(
            top: 0,
            right: 0,
            child: _KubusStatChangeChip(
              label: change!,
              isPositive: isPositiveChange,
            ),
          ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  alignment: Alignment.center,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: effectiveValueStyle,
                  ),
                ),
              ),
              SizedBox(height: valueTitleGap),
              Text(
                title,
                style: effectiveTitleStyle,
                textAlign: TextAlign.center,
                maxLines: titleMaxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle _scaledTextStyle(TextStyle style, {required double factor}) {
    final fontSize = style.fontSize;
    if (fontSize == null) {
      return style;
    }
    return style.copyWith(fontSize: fontSize * factor);
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
