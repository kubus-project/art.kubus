import 'package:flutter/material.dart';

import '../../utils/app_animations.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/kubus_map_tokens.dart';

/// Credit line for the basemap, shown visibly on the map.
///
/// Mirrors the `attribution` string of the vendored Kubus styles
/// (`assets/map_styles/kubus_*.json`). The native MapLibre attribution control
/// is hidden on web (see `web/index.html`), so this line is the visible credit.
const String kubusMapAttributionCredit =
    '© OpenStreetMap contributors, © CARTO';

/// Flat map chrome: ONE surface level per cluster.
///
/// Every map chrome cluster (search, filter, control rail, attribution,
/// discovery card, prompt and chips) is a near-opaque theme-token surface with a
/// single hairline rule. There is no backdrop blur, no shadow and no sheen, so
/// nothing stacks blur-over-blur or outline-over-outline. Accent colour is
/// reserved for the selected/active state of a control.
///
/// Surfaces and rules come from [KubusColorRoles], so light and dark follow the
/// theme. Map markers are data and are never drawn through this surface.
Widget buildKubusMapChromeSurface({
  required BuildContext context,
  required Widget child,
  BorderRadius? borderRadius,
  EdgeInsetsGeometry padding = EdgeInsets.zero,
  EdgeInsetsGeometry margin = EdgeInsets.zero,
  Color? fill,
  bool showRule = true,
}) {
  final roles = KubusColorRoles.of(context);
  return Container(
    margin: margin,
    decoration: BoxDecoration(
      color: fill ?? roles.surfaceOverlay,
      borderRadius: borderRadius ?? BorderRadius.circular(KubusRadius.surface),
      border: showRule
          ? Border.all(color: roles.rule, width: KubusSizes.hairline)
          : null,
    ),
    child: Padding(padding: padding, child: child),
  );
}

/// Hairline that separates groups inside one chrome cluster.
class KubusMapChromeRule extends StatelessWidget {
  const KubusMapChromeRule({
    super.key,
    this.axis = Axis.vertical,
    required this.length,
  });

  /// [Axis.vertical] draws a divider between buttons in a row; [Axis.horizontal]
  /// draws one between buttons in a column.
  final Axis axis;

  /// Extent of the rule along the cluster direction. Explicit so the rule keeps
  /// its size inside an unbounded column.
  final double length;

  @override
  Widget build(BuildContext context) {
    final rule = KubusColorRoles.of(context).rule;
    final isVertical = axis == Axis.vertical;
    return SizedBox(
      width: isVertical ? KubusSizes.hairline : length,
      height: isVertical ? length : KubusSizes.hairline,
      child: ColoredBox(color: rule),
    );
  }
}

/// Square icon control used inside map chrome clusters.
///
/// Flat: no border, shadow or glass of its own. Hover is a neutral fill, focus
/// is a focus-role ring (2px, about 5:1 on the chrome surface in both themes),
/// and [active] (selected state) is the only place the accent appears. The hit
/// area is at least [size], which defaults to the 48px chrome target.
class KubusMapChromeIconButton extends StatefulWidget {
  const KubusMapChromeIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.active = false,
    this.size = KubusMapMetrics.chromeControlSize,
    this.accentColor,
    this.iconColor,
    this.activeIconColor,
    this.badgeCount,
    this.semanticsLabel,
    this.borderRadius = KubusRadius.surface,
    this.tooltipPreferBelow,
    this.tooltipVerticalOffset,
    this.tooltipMargin,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool active;
  final double size;

  /// Selected-state colour. Falls back to the family active role.
  final Color? accentColor;
  final Color? iconColor;
  final Color? activeIconColor;

  /// Optional count drawn in the top-right corner (values above 99 read `99+`).
  final int? badgeCount;

  /// Full accessible label; defaults to [tooltip].
  final String? semanticsLabel;
  final double borderRadius;
  final bool? tooltipPreferBelow;
  final double? tooltipVerticalOffset;
  final EdgeInsetsGeometry? tooltipMargin;

  @override
  State<KubusMapChromeIconButton> createState() =>
      _KubusMapChromeIconButtonState();
}

class _KubusMapChromeIconButtonState extends State<KubusMapChromeIconButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final roles = KubusColorRoles.of(context);
    final animation = context.animationTheme;
    final enabled = widget.onPressed != null;
    final active = widget.active;
    final accent = widget.accentColor ?? roles.active;
    final radius = BorderRadius.circular(widget.borderRadius);

    final Color fill;
    if (active) {
      fill = accent.withValues(alpha: 0.14);
    } else if (enabled && _hovered) {
      fill = scheme.onSurface.withValues(alpha: 0.06);
    } else {
      fill = Colors.transparent;
    }

    final baseIcon = widget.iconColor ?? scheme.onSurface;
    final iconColor = !enabled
        ? baseIcon.withValues(alpha: 0.38)
        : active
            ? (widget.activeIconColor ?? accent)
            : baseIcon;

    final showRing = _focused && enabled;
    final badgeCount = widget.badgeCount;
    final showBadge = badgeCount != null && badgeCount > 0;

    final hit = SizedBox.square(
      dimension: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              mouseCursor:
                  enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
              borderRadius: radius,
              // Focus, hover and press are drawn by this control alone: the
              // focus ring below and the neutral hover fill. Material's own
              // focus highlight is a low-contrast teal wash, so it is off.
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: widget.onPressed,
              onHover: (value) {
                if (_hovered != value) setState(() => _hovered = value);
              },
              onFocusChange: (value) {
                if (_focused != value) setState(() => _focused = value);
              },
              child: AnimatedContainer(
                duration: animation.short,
                curve: animation.defaultCurve,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: radius,
                  border: Border.all(
                    color: showRing ? roles.focus : Colors.transparent,
                    width: showRing ? 2 : 0,
                  ),
                ),
                child: Center(
                  child: Icon(
                    widget.icon,
                    size: KubusHeaderMetrics.actionIcon,
                    color: iconColor,
                  ),
                ),
              ),
            ),
          ),
          if (showBadge)
            Positioned(
              top: KubusSpacing.xxs,
              right: KubusSpacing.xxs,
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: roles.focus,
                      borderRadius: BorderRadius.circular(KubusRadius.pill),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: roles.onActive,
                        fontSize: 10,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    Widget control = Semantics(
      button: true,
      enabled: enabled,
      selected: active,
      label: widget.semanticsLabel ??
          (widget.tooltip.isEmpty ? null : widget.tooltip),
      child: hit,
    );
    if (widget.tooltip.isNotEmpty) {
      control = Tooltip(
        message: widget.tooltip,
        preferBelow: widget.tooltipPreferBelow,
        verticalOffset: widget.tooltipVerticalOffset,
        margin: widget.tooltipMargin,
        child: control,
      );
    }
    return control;
  }
}

/// Visible basemap credit with the full attribution dialog behind it.
///
/// The credit is drawn as text on the same near-opaque chrome surface as the
/// other clusters, so its contrast comes from theme tokens rather than from
/// whatever map pixels are underneath. The whole row is the tap target (at
/// least [minHeight] high, 48px on desktop and mobile) and opens the attribution
/// sheet.
class KubusMapAttributionControl extends StatelessWidget {
  const KubusMapAttributionControl({
    super.key,
    required this.onPressed,
    required this.semanticsLabel,
    this.credit = kubusMapAttributionCredit,
    this.minHeight = KubusMapMetrics.chromeControlSize,
  });

  final VoidCallback onPressed;
  final String semanticsLabel;
  final String credit;

  /// Minimum tap height. The mobile map passes its 48px touch target.
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roles = KubusColorRoles.of(context);
    final radius = BorderRadius.circular(KubusRadius.surface);
    final creditStyle = KubusTypography.textTheme.labelSmall?.copyWith(
      color: roles.foreground,
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w500,
    );

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: buildKubusMapChromeSurface(
          context: context,
          borderRadius: radius,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: radius,
              onTap: onPressed,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KubusSpacing.sm + KubusSpacing.xs,
                    vertical: KubusSpacing.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          credit,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: creditStyle ??
                              theme.textTheme.labelSmall?.copyWith(
                                color: roles.foreground,
                              ),
                        ),
                      ),
                      const SizedBox(width: KubusSpacing.xs + KubusSpacing.xxs),
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: roles.foreground,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Foreground/background contrast ratio (WCAG 2.x) for two opaque colours.
double kubusMapChromeContrastRatio(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  final hi = a > b ? a : b;
  final lo = a > b ? b : a;
  return (hi + 0.05) / (lo + 0.05);
}
