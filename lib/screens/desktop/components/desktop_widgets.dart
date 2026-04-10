import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/themeprovider.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/design_tokens.dart';
import '../../../widgets/glass_components.dart';
import '../../../widgets/common/kubus_stat_card.dart';
import '../../../widgets/common/kubus_screen_header.dart';
import '../../../widgets/search/kubus_search_bar.dart';

/// Desktop content card with hover effects and animations
class DesktopCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool enableHover;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final bool showBorder;
  final bool isGlass;

  const DesktopCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.enableHover = true,
    this.width,
    this.height,
    this.borderRadius,
    this.backgroundColor,
    this.showBorder = true,
    this.isGlass = true,
  });

  @override
  State<DesktopCard> createState() => _DesktopCardState();
}

class _DesktopCardState extends State<DesktopCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final animationTheme = context.animationTheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final glassStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.card,
      tintBase: widget.backgroundColor ?? scheme.surface,
    );

    final radius = widget.borderRadius ?? BorderRadius.circular(KubusRadius.lg);
    final glassTint = widget.backgroundColor ?? glassStyle.tintColor;

    Widget content = AnimatedContainer(
      duration: animationTheme.short,
      curve: animationTheme.defaultCurve,
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      transform:
          _isHovered ? Matrix4.translationValues(0, -2, 0) : Matrix4.identity(),
      decoration: BoxDecoration(
        borderRadius: radius,
        border: widget.showBorder
            ? Border.all(
                color: _isHovered
                    ? themeProvider.accentColor.withValues(alpha: 0.22)
                    : scheme.outline.withValues(alpha: 0.14),
                width: _isHovered ? 1.25 : 1,
              )
            : null,
        boxShadow: _isHovered
            ? [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: widget.isGlass
          ? LiquidGlassPanel(
              padding: widget.padding ??
                  const EdgeInsets.all(KubusChromeMetrics.cardPadding),
              margin: EdgeInsets.zero,
              borderRadius: radius,
              blurSigma: glassStyle.blurSigma,
              fallbackMinOpacity: glassStyle.fallbackMinOpacity,
              showBorder: false,
              backgroundColor: glassTint,
              onTap: widget.onTap,
              child: widget.child,
            )
          : Material(
              color: scheme.primaryContainer,
              borderRadius: radius,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: radius,
                child: Padding(
                  padding: widget.padding ??
                      const EdgeInsets.all(KubusChromeMetrics.cardPadding),
                  child: widget.child,
                ),
              ),
            ),
    );

    return MouseRegion(
      onEnter:
          widget.enableHover ? (_) => setState(() => _isHovered = true) : null,
      onExit:
          widget.enableHover ? (_) => setState(() => _isHovered = false) : null,
      child: content,
    );
  }
}

/// Desktop section header with optional actions
class DesktopSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final IconData? icon;
  final EdgeInsetsGeometry? padding;
  final Color? iconColor;

  const DesktopSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.icon,
    this.padding,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final effectiveColor = iconColor ?? themeProvider.accentColor;

    return Padding(
      padding: padding ??
          const EdgeInsets.symmetric(
            vertical: KubusSpacing.sm + KubusSpacing.xxs,
          ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: KubusHeaderMetrics.actionHitArea,
              height: KubusHeaderMetrics.actionHitArea,
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(KubusRadius.sm),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: effectiveColor,
                  size: KubusHeaderMetrics.actionIcon,
                ),
              ),
            ),
            const SizedBox(width: KubusSpacing.sm + KubusSpacing.xxs),
          ],
          Expanded(
            child: KubusHeaderText(
              title: title,
              subtitle: subtitle,
              kind: KubusHeaderKind.section,
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Desktop grid with responsive columns
class DesktopGrid extends StatelessWidget {
  final List<Widget> children;
  final int minCrossAxisCount;
  final int maxCrossAxisCount;
  final double spacing;
  final double childAspectRatio;
  final double breakpointWidth;

  const DesktopGrid({
    super.key,
    required this.children,
    this.minCrossAxisCount = 2,
    this.maxCrossAxisCount = 4,
    this.spacing = 16,
    this.childAspectRatio = 1.0,
    this.breakpointWidth = 300,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columns = (width / breakpointWidth).floor();
        columns = columns.clamp(minCrossAxisCount, maxCrossAxisCount);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

/// Desktop stat card for displaying metrics
class DesktopStatCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final String? change;
  final bool isPositive;
  final VoidCallback? onTap;
  final Alignment? centeredWatermarkAlignment;
  final double centeredWatermarkScale;

  const DesktopStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.change,
    this.isPositive = true,
    this.onTap,
    this.centeredWatermarkAlignment,
    this.centeredWatermarkScale = 1.0,
  });

  @override
  State<DesktopStatCard> createState() => _DesktopStatCardState();
}

class _DesktopStatCardState extends State<DesktopStatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final color = widget.color ?? themeProvider.accentColor;
    final animationTheme = context.animationTheme;

    final radius = BorderRadius.circular(KubusRadius.md);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: _isHovered ? 1.0 : 0.0),
        duration: animationTheme.medium,
        curve: animationTheme.emphasisCurve,
        builder: (context, hoverValue, child) {
          return Transform.translate(
            offset: Offset(0, -4 * hoverValue),
            child: Transform.scale(
              scale: 1 + (0.012 * hoverValue),
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: animationTheme.medium,
                curve: animationTheme.emphasisCurve,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color:
                          color.withValues(alpha: 0.05 + (0.14 * hoverValue)),
                      blurRadius: 10 + (10 * hoverValue),
                      spreadRadius: 0.5 * hoverValue,
                      offset: Offset(0, 3 + (3 * hoverValue)),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          );
        },
        child: KubusStatCard(
          title: widget.label,
          value: widget.value,
          icon: widget.icon,
          layout: KubusStatCardLayout.centered,
          accent: color,
          centeredWatermarkAlignment: widget.centeredWatermarkAlignment,
          centeredWatermarkScale: widget.centeredWatermarkScale,
          centeredWatermarkHovered: _isHovered,
          change: widget.change,
          isPositiveChange: widget.isPositive,
          minHeight: 136,
          titleMaxLines: 2,
          valueStyle: KubusTextStyles.statValue,
          titleStyle: KubusTextStyles.actionTileTitle,
          borderColor: _isHovered
              ? color.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}

/// Desktop action button with icon
class DesktopActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isLoading;

  const DesktopActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
  });

  @override
  State<DesktopActionButton> createState() => _DesktopActionButtonState();
}

class _DesktopActionButtonState extends State<DesktopActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final animationTheme = context.animationTheme;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final glassStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.button,
      tintBase: widget.isPrimary ? themeProvider.accentColor : scheme.surface,
    );

    final radius = BorderRadius.circular(KubusRadius.md);
    final glassTint = glassStyle.tintColor;

    final outlineColor = widget.isPrimary
        ? themeProvider.accentColor.withValues(alpha: _isHovered ? 0.34 : 0.28)
        : scheme.outline.withValues(alpha: _isHovered ? 0.22 : 0.16);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: animationTheme.short,
        curve: animationTheme.defaultCurve,
        transform: _isHovered && !widget.isLoading
            ? Matrix4.translationValues(0, -2, 0)
            : Matrix4.identity(),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: outlineColor,
              width: _isHovered ? 1.25 : 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: (widget.isPrimary
                              ? themeProvider.accentColor
                              : theme.shadowColor)
                          .withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: LiquidGlassPanel(
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            borderRadius: radius,
            blurSigma: glassStyle.blurSigma,
            fallbackMinOpacity: glassStyle.fallbackMinOpacity,
            showBorder: false,
            backgroundColor: glassTint,
            child: ElevatedButton.icon(
              onPressed: widget.isLoading ? null : widget.onPressed,
              icon: widget.isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.isPrimary
                            ? Colors.white
                            : themeProvider.accentColor,
                      ),
                    )
                  : Icon(widget.icon, size: KubusHeaderMetrics.actionIcon),
              label: Text(
                widget.label,
                style: KubusTextStyles.actionTileTitle,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor:
                    widget.isPrimary ? Colors.white : scheme.onSurface,
                shadowColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                disabledForegroundColor: widget.isPrimary
                    ? Colors.white.withValues(alpha: 0.55)
                    : scheme.onSurface.withValues(alpha: 0.55),
                padding: const EdgeInsets.symmetric(
                  horizontal: KubusSpacing.lg,
                  vertical: KubusSpacing.md - KubusSpacing.xxs,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: radius,
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop search bar.
///
/// Note: this is now a thin wrapper around the shared [KubusSearchBar] so all
/// search inputs can share a single implementation while keeping existing
/// call sites stable.
class DesktopSearchBar extends StatelessWidget {
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enableBlur;

  const DesktopSearchBar({
    super.key,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.enableBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final animationTheme = context.animationTheme;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final glassStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.card,
      tintBase: scheme.surface,
    );

    final radius = BorderRadius.circular(KubusRadius.md);
    final glassTint = glassStyle.tintColor;

    return KubusSearchBar(
      hintText: hintText ?? l10n.commonSearchHint,
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enableBlur: enableBlur,
      style: KubusSearchBarStyle(
        borderRadius: radius,
        backgroundColor: glassTint,
        borderColor: scheme.outline.withValues(alpha: 0.18),
        focusedBorderColor: themeProvider.accentColor,
        borderWidth: 1,
        focusedBorderWidth: 2,
        blurSigma: glassStyle.blurSigma,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: KubusSpacing.md,
          vertical: KubusSpacing.sm + KubusSpacing.xs,
        ),
        boxShadow: null,
        focusedBoxShadow: [
          BoxShadow(
            color: themeProvider.accentColor.withValues(alpha: 0.1),
            blurRadius: 8,
          ),
        ],
        prefixIconConstraints: null,
        suffixIconConstraints: null,
        textStyle: KubusTypography.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
        ),
        hintStyle: KubusTypography.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      animationDuration: animationTheme.short,
      animationCurve: animationTheme.defaultCurve,
    );
  }
}

/// Desktop tab bar with hover effects
class DesktopTabBar extends StatefulWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const DesktopTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  State<DesktopTabBar> createState() => _DesktopTabBarState();
}

class _DesktopTabBarState extends State<DesktopTabBar> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final animationTheme = context.animationTheme;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final glassStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.card,
      tintBase: scheme.surface,
    );

    final radius = BorderRadius.circular(KubusRadius.md);
    final glassTint = glassStyle.tintColor;

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.14),
        ),
      ),
      child: LiquidGlassPanel(
        padding: const EdgeInsets.all(4),
        margin: EdgeInsets.zero,
        borderRadius: radius,
        blurSigma: glassStyle.blurSigma,
        fallbackMinOpacity: glassStyle.fallbackMinOpacity,
        showBorder: false,
        backgroundColor: glassTint,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.tabs.length, (index) {
            final isSelected = widget.selectedIndex == index;
            final isHovered = _hoveredIndex == index;

            return MouseRegion(
              onEnter: (_) => setState(() => _hoveredIndex = index),
              onExit: (_) => setState(() => _hoveredIndex = null),
              child: AnimatedContainer(
                duration: animationTheme.short,
                curve: animationTheme.defaultCurve,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => widget.onTabSelected(index),
                    borderRadius: BorderRadius.circular(KubusRadius.sm),
                    child: AnimatedContainer(
                      duration: animationTheme.short,
                      padding: const EdgeInsets.symmetric(
                        horizontal: KubusSpacing.md + KubusSpacing.sm,
                        vertical: KubusSpacing.sm + KubusSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? themeProvider.accentColor.withValues(alpha: 0.90)
                            : isHovered
                                ? scheme.onSurface.withValues(alpha: 0.06)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(KubusRadius.sm),
                      ),
                      child: Text(
                        widget.tabs[index],
                        style: KubusTextStyles.navLabel.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : scheme.onSurface
                                  .withValues(alpha: isHovered ? 1.0 : 0.7),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
