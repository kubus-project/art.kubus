import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../glass_components.dart';

enum KubusStatCardLayout {
  standard,
  centered,
}

class KubusStatCard extends StatefulWidget {
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
    this.centeredWatermarkAlignment,
    this.centeredWatermarkScale = 1.0,
    this.centeredWatermarkVerticalBias = 0.18,
    this.centeredWatermarkHovered,
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
  final Alignment? centeredWatermarkAlignment;
  final double centeredWatermarkScale;
  final double centeredWatermarkVerticalBias;
  final bool? centeredWatermarkHovered;

  @override
  State<KubusStatCard> createState() => _KubusStatCardState();
}

class _KubusStatCardState extends State<KubusStatCard>
    with SingleTickerProviderStateMixin {
  static const Duration _hoverTransitionDuration = Duration(milliseconds: 280);
  static const Duration _floatDuration = Duration(milliseconds: 2200);

  late final AnimationController _floatController = AnimationController(
    vsync: this,
    duration: _floatDuration,
  );

  bool _isHovered = false;

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant KubusStatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.centeredWatermarkHovered == oldWidget.centeredWatermarkHovered) {
      return;
    }
    final forcedHovered = widget.centeredWatermarkHovered;
    if (forcedHovered == true) {
      _floatController.repeat(reverse: true);
    } else if (forcedHovered == false) {
      _floatController.stop();
      _floatController.value = 0;
    }
  }

  void _setHovered(bool hovered) {
    if (_isHovered == hovered) return;
    setState(() => _isHovered = hovered);
    if (hovered) {
      _floatController.repeat(reverse: true);
    } else {
      _floatController.stop();
      _floatController.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.maybeOf(context)?.size.width ?? 0;
    final isUltraWide = screenWidth >= 1800;
    final effectiveAccent = widget.accent ?? scheme.primary;
    final shouldShowIcon = widget.showIcon && widget.icon != null;
    final watermarkHovered = widget.centeredWatermarkHovered ?? _isHovered;
    final effectiveRadius =
        widget.borderRadius ?? BorderRadius.circular(KubusRadius.md);
    final effectiveMinHeight =
        (widget.layout == KubusStatCardLayout.centered &&
                isUltraWide &&
                widget.minHeight > 0)
            ? (widget.minHeight - 6).clamp(0.0, double.infinity)
            : widget.minHeight;
    final glassStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.card,
      tintBase: widget.tintBase ?? effectiveAccent,
    );
    final content = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        border: Border.all(
          color:
              widget.borderColor ?? effectiveAccent.withValues(alpha: 0.22),
          width: KubusSizes.hairline,
        ),
      ),
      child: LiquidGlassCard(
        padding:
            widget.layout == KubusStatCardLayout.centered
                ? EdgeInsets.zero
                : widget.padding,
        margin: EdgeInsets.zero,
        borderRadius: effectiveRadius,
        showBorder: false,
        blurSigma: glassStyle.blurSigma,
        fallbackMinOpacity: glassStyle.fallbackMinOpacity,
        backgroundColor: glassStyle.tintColor,
        onTap: widget.onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: effectiveMinHeight),
          child: widget.layout == KubusStatCardLayout.centered
              ? _buildCenteredContent(
                  context: context,
                  scheme: scheme,
                  effectiveAccent: effectiveAccent,
                  shouldShowIcon: shouldShowIcon,
                  contentPadding: widget.padding,
                  centeredWatermarkAlignment: widget.centeredWatermarkAlignment,
                  centeredWatermarkScale: widget.centeredWatermarkScale,
                  centeredWatermarkVerticalBias:
                      widget.centeredWatermarkVerticalBias,
                  watermarkHovered: watermarkHovered,
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

    if (widget.layout != KubusStatCardLayout.centered || !shouldShowIcon) {
      return content;
    }

    if (widget.centeredWatermarkHovered != null) {
      return content;
    }

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: content,
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
                width: widget.iconBoxSize,
                height: widget.iconBoxSize,
                decoration: BoxDecoration(
                  color: effectiveAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(KubusRadius.sm),
                ),
                child: Icon(
                  widget.icon,
                  color: effectiveAccent,
                  size: widget.iconSize,
                ),
              ),
              const SizedBox(width: KubusSpacing.sm),
            ],
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: widget.change == null ? 0 : KubusSpacing.xs,
                ),
                child: Text(
                  widget.title,
                  maxLines: widget.titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: widget.titleStyle ??
                      KubusTextStyles.actionTileTitle.copyWith(
                        fontSize: 15,
                        color: scheme.onSurface,
                      ),
                ),
              ),
            ),
            if (widget.change != null)
              _KubusStatChangeChip(
                label: widget.change!,
                isPositive: widget.isPositiveChange,
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
                widget.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: widget.valueStyle ??
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
    required EdgeInsetsGeometry contentPadding,
    required Alignment? centeredWatermarkAlignment,
    required double centeredWatermarkScale,
    required double centeredWatermarkVerticalBias,
    required bool watermarkHovered,
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

    final titleTextStyle = widget.titleStyle ??
        KubusTextStyles.statLabel.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.8),
        );
    final valueTextStyle = widget.valueStyle ??
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
          IgnorePointer(
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : widget.minHeight;
                  final maxHeight = constraints.maxHeight.isFinite
                      ? constraints.maxHeight
                      : widget.minHeight;

                  final fallbackBase = widget.iconSize + widget.iconBoxSize;
                  final safeWidth = maxWidth > 0 ? maxWidth : fallbackBase;
                  final safeHeight = maxHeight > 0 ? maxHeight : fallbackBase;
                  final aspectRatio =
                      safeHeight <= 0 ? 1.0 : (safeWidth / safeHeight);
                  final shortestSide = math.min(safeWidth, safeHeight);
                  final longestSide = math.max(safeWidth, safeHeight);
                  final glyphCompensation =
                      _watermarkGlyphCompensation(widget.icon);
                  final isWideCard = aspectRatio >= 1.45;
                  final baseWatermarkSize = shortestSide *
                      (isWideCard
                          ? 1.36
                          : (aspectRatio <= 0.9 ? 1.56 : 1.48));
                  final minAllowedSize = shortestSide * 1.10;
                  final maxAllowedSize =
                      math.max(shortestSide * 1.34, longestSide * 1.18);

                  final hoverProgress = watermarkHovered ? 1.0 : 0.0;
                  final hoverBias =
                      centeredWatermarkVerticalBias.clamp(0.0, 0.35) *
                          (1.0 - hoverProgress);
                  final baseSizedWatermark = (baseWatermarkSize *
                          glyphCompensation *
                          watermarkScale *
                          centeredWatermarkScale.clamp(0.75, 1.2))
                      .clamp(minAllowedSize, maxAllowedSize);

                  final watermarkAlignment =
                      centeredWatermarkAlignment ?? Alignment.center;

                  return AnimatedBuilder(
                    animation: _floatController,
                    builder: (context, _) {
                      final animatedHoverScale = 1.0 +
                          (0.06 * hoverProgress) +
                          (_floatController.value * 0.015);
                      final animatedIconWatermarkSize = (baseSizedWatermark *
                              animatedHoverScale)
                          .clamp(minAllowedSize, maxAllowedSize);
                      final animatedFloatLift = watermarkHovered
                          ? math.sin(_floatController.value * math.pi * 2) *
                              (baseSizedWatermark * 0.022)
                          : 0.0;

                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          end: hoverBias,
                        ),
                        duration: _hoverTransitionDuration,
                        curve: Curves.easeInOutCubic,
                        builder: (context, animatedBias, child) {
                          return Align(
                            alignment: watermarkAlignment,
                            child: Transform.translate(
                              offset: Offset(
                                0,
                                (animatedIconWatermarkSize * animatedBias) -
                                    animatedFloatLift,
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: Icon(
                          widget.icon,
                          color: effectiveAccent.withValues(
                            alpha: isWideCard ? 0.12 : 0.14,
                          ),
                          size: animatedIconWatermarkSize,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        if (widget.change != null)
          Positioned(
            top: 0,
            right: 0,
            child: _KubusStatChangeChip(
              label: widget.change!,
              isPositive: widget.isPositiveChange,
            ),
          ),
        Center(
          child: Padding(
            padding: contentPadding,
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
                      widget.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: effectiveValueStyle,
                    ),
                  ),
                ),
                SizedBox(height: valueTitleGap),
                Text(
                  widget.title,
                  style: effectiveTitleStyle,
                  textAlign: TextAlign.center,
                  maxLines: widget.titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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

  double _watermarkGlyphCompensation(IconData? glyph) {
    if (glyph == null) {
      return 1.0;
    }

    final codePoint = glyph.codePoint;

    if (codePoint == Icons.account_balance.codePoint ||
        codePoint == Icons.account_balance_wallet.codePoint ||
        codePoint == Icons.account_balance_wallet_outlined.codePoint ||
        codePoint == Icons.token.codePoint ||
        codePoint == Icons.token_outlined.codePoint ||
        codePoint == Icons.home_work_outlined.codePoint) {
      return 0.90;
    }

    if (codePoint == Icons.palette.codePoint ||
        codePoint == Icons.palette_outlined.codePoint ||
        codePoint == Icons.visibility.codePoint ||
        codePoint == Icons.visibility_outlined.codePoint ||
        codePoint == Icons.explore.codePoint ||
        codePoint == Icons.explore_outlined.codePoint ||
        codePoint == Icons.show_chart.codePoint) {
      return 0.96;
    }

    if (codePoint == Icons.people.codePoint ||
        codePoint == Icons.people_outline.codePoint ||
        codePoint == Icons.person_add.codePoint ||
        codePoint == Icons.person_add_outlined.codePoint ||
        codePoint == Icons.groups.codePoint ||
        codePoint == Icons.groups_outlined.codePoint ||
        codePoint == Icons.streetview.codePoint) {
      return 1.04;
    }

    return 1.0;
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
