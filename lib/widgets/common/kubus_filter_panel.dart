import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../glass_components.dart';
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
    this.absorbPointer = false,
    this.cursor = SystemMouseCursors.basic,
    this.titleStyle,
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
  final bool absorbPointer;
  final MouseCursor cursor;
  final TextStyle? titleStyle;

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

    Widget panel = LiquidGlassPanel(
      margin: margin,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(borderRadius),
      blurSigma: surfaceStyle.blurSigma,
      backgroundColor: surfaceStyle.tintColor,
      fallbackMinOpacity: surfaceStyle.fallbackMinOpacity,
      showBorder: true,
      child: Column(
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
          if (expandContent) Expanded(child: content) else content,
          if (footer != null) ...[
            if (showFooterDivider)
              Divider(height: 1, color: scheme.outline.withValues(alpha: 0.14)),
            footer!,
          ],
        ],
      ),
    );

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
