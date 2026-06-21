import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../glass_components.dart';
import '../map/kubus_map_glass_surface.dart';
import 'kubus_glass_icon_button.dart';

/// Shared glass shell for map filter/sort content.
class KubusFilterPanel extends StatelessWidget {
  const KubusFilterPanel({
    super.key,
    required this.title,
    required this.child,
    this.onClose,
    this.closeTooltip = '',
    this.footer,
    this.margin = EdgeInsets.zero,
    this.headerPadding = const EdgeInsets.fromLTRB(
      KubusSpacing.md,
      KubusSpacing.md,
      KubusSpacing.md,
      KubusSpacing.md,
    ),
    this.contentPadding = const EdgeInsets.all(KubusSpacing.md),
    this.borderRadius = KubusRadius.lg,
    this.showHeaderDivider = true,
    this.showFooterDivider = false,
    this.expandContent = false,
    this.maxHeight,
    this.absorbPointer = false,
    this.cursor = SystemMouseCursors.basic,
    this.titleStyle,
    this.useGlassSurface = true,
    this.useMapGlassSurface = false,
    this.mapBlurPolicy = KubusMapBlurPolicy.forceRealBlur,
    this.overMapPlatformView = true,
    this.backdropRegionId,
    this.enablePlatformBackdropRegion = true,
    this.isWebOverride,
    this.platformBackdropHostAvailableOverride,
  });

  final String title;
  final Widget child;
  final VoidCallback? onClose;
  final String closeTooltip;
  final Widget? footer;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry headerPadding;
  final EdgeInsetsGeometry contentPadding;
  final double borderRadius;
  final bool showHeaderDivider;
  final bool showFooterDivider;
  final bool expandContent;

  /// When set, bounds the panel's height so its scrollable content actually
  /// scrolls instead of overflowing. Use this for overlay placements that have
  /// no bounded parent (e.g. the mobile top-overlay filter panel, which sits in
  /// a `Positioned` with only top/left/right). Leave null when the panel already
  /// has a bounded parent and uses [expandContent] (e.g. the desktop side
  /// panel).
  final double? maxHeight;
  final bool absorbPointer;
  final MouseCursor cursor;
  final TextStyle? titleStyle;
  final bool useGlassSurface;
  final bool useMapGlassSurface;
  final KubusMapBlurPolicy mapBlurPolicy;
  final bool overMapPlatformView;
  final String? backdropRegionId;
  final bool enablePlatformBackdropRegion;
  final bool? isWebOverride;
  final bool? platformBackdropHostAvailableOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surfaceStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.panelBackground,
      tintBase: scheme.surface,
    );

    final content = SingleChildScrollView(
      padding: contentPadding,
      child: child,
    );

    // When the panel is height-bounded (via [maxHeight]) but not [expandContent],
    // the scroll area must be [Flexible] inside a `mainAxisSize.min` Column so it
    // shrink-wraps small content yet scrolls within the bound when content is
    // tall. [expandContent] keeps using [Expanded] (its parent is already
    // bounded). Otherwise the scroll view is placed as-is.
    final Widget contentArea;
    if (expandContent) {
      contentArea = Expanded(child: content);
    } else if (maxHeight != null) {
      contentArea = Flexible(child: content);
    } else {
      contentArea = content;
    }

    final panelBody = Column(
      mainAxisSize: (maxHeight != null && !expandContent)
          ? MainAxisSize.min
          : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: headerPadding,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: titleStyle ??
                      KubusTextStyles.sectionTitle.copyWith(
                        color: scheme.onSurface,
                      ),
                ),
              ),
              if (onClose != null)
                KubusGlassIconButton(
                  icon: Icons.close,
                  tooltip: closeTooltip,
                  borderRadius: 10,
                  onPressed: onClose,
                ),
            ],
          ),
        ),
        if (showHeaderDivider)
          Divider(height: 1, color: scheme.outline.withValues(alpha: 0.14)),
        contentArea,
        if (footer != null) ...[
          if (showFooterDivider)
            Divider(height: 1, color: scheme.outline.withValues(alpha: 0.14)),
          footer!,
        ],
      ],
    );

    Widget panel;
    if (useMapGlassSurface) {
      panel = buildKubusMapGlassSurface(
        context: context,
        kind: KubusMapGlassSurfaceKind.panel,
        margin: margin,
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(borderRadius),
        tintBase: scheme.surface,
        blurPolicy: mapBlurPolicy,
        overlayName: 'filter-panel',
        overMapPlatformView: overMapPlatformView,
        backdropRegionId: backdropRegionId,
        enablePlatformBackdropRegion: enablePlatformBackdropRegion,
        isWebOverride: isWebOverride,
        platformBackdropHostAvailableOverride:
            platformBackdropHostAvailableOverride,
        child: panelBody,
      );
    } else if (useGlassSurface) {
      panel = LiquidGlassPanel(
        margin: margin,
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(borderRadius),
        blurSigma: surfaceStyle.blurSigma,
        backgroundColor: surfaceStyle.tintColor,
        fallbackMinOpacity: surfaceStyle.fallbackMinOpacity,
        showBorder: true,
        child: panelBody,
      );
    } else {
      panel = Padding(
        padding: margin,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: panelBody,
        ),
      );
    }

    if (maxHeight != null) {
      panel = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight!),
        child: panel,
      );
    }

    if (!absorbPointer) return MouseRegion(cursor: cursor, child: panel);

    return MouseRegion(
      cursor: cursor,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {},
        onPointerMove: (_) {},
        onPointerUp: (_) {},
        onPointerSignal: (_) {},
        child: panel,
      ),
    );
  }
}
