import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';

/// Quiet tonal container for long-form reading content.
///
/// The liquid-glass stack (`GlassSurface` family) is reserved for elevated,
/// floating, or transient chrome. Long descriptions, curatorial text,
/// biographies, and analytics interpretation belong on this calmer surface:
/// an opaque-leaning tonal fill with no backdrop blur, so body text never
/// competes with the animated gradient underneath it.
class KubusReadingSurface extends StatelessWidget {
  const KubusReadingSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.showBorder = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final bool showBorder;

  /// Tint strength of the tonal fill per brightness. High enough that body
  /// text reads against the animated gradient without any blur, low enough
  /// that the surface stays visually quieter than glass panels.
  static const double _tintAlphaDark = 0.42;
  static const double _tintAlphaLight = 0.60;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final radius = borderRadius ?? KubusRadius.circular(KubusRadius.lg);

    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(KubusSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(
          alpha: isDark ? _tintAlphaDark : _tintAlphaLight,
        ),
        borderRadius: radius,
        border: showBorder ? KubusBorders.glass(context) : null,
      ),
      child: child,
    );
  }
}
