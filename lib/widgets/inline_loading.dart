import 'package:flutter/material.dart';
import 'isometric_pulse.dart';

/// InlineLoading wraps the IsometricPulse indicator and provides a single
/// point of customization for inlined loading states (avatars, buttons,
/// small progress bars). Use `shape` or `borderRadius` to customize clip.
class InlineLoading extends StatelessWidget {
  final double? width;
  final double? height;
  final double tileSize;
  final double? progress; // 0..1 determinate
  final Color? color;
  final Color? highlight;
  final Duration duration;
  final bool animate;
  final BoxShape? shape; // null -> rounded rect with borderRadius
  final BorderRadius? borderRadius;
  final bool expand; // when true, occupy all available parent space

  const InlineLoading({
    super.key,
    this.width,
    this.height,
    this.tileSize = 6.0,
    this.progress,
    this.color,
    this.highlight,
    this.duration = const Duration(milliseconds: 700),
    this.animate = true,
    this.shape,
    this.borderRadius,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder to honor parent constraints when width/height not provided.
    final widget = LayoutBuilder(builder: (context, constraints) {
      double? finalWidth = width;
      double? finalHeight = height;

      // If width/height not supplied, try to use the incoming constraints
      if (finalWidth == null && constraints.hasBoundedWidth) finalWidth = constraints.maxWidth;
      if (finalHeight == null && constraints.hasBoundedHeight) finalHeight = constraints.maxHeight;

      // As a last resort, provide a reasonable default box size so the painter has bounds.
      final fallback = tileSize * 8.0;
      finalWidth = finalWidth ?? fallback;
      finalHeight = finalHeight ?? fallback;

      if (expand) {
        // Expand to fill available parent space
        return SizedBox.expand(
          child: IsometricPulse(
            color: color,
            highlight: highlight,
            duration: duration,
            tileSize: tileSize,
            animate: animate,
            progress: progress,
          ),
        );
      }

      return SizedBox(
        width: finalWidth,
        height: finalHeight,
        child: IsometricPulse(
          color: color,
          highlight: highlight,
          duration: duration,
          tileSize: tileSize,
          animate: animate,
          progress: progress,
        ),
      );
    });

    // If a circular shape is requested, only apply ClipOval when the
    // final render box will be square — otherwise a circular clip over a
    // rectangular parent would produce the "just a circle" effect.
    return LayoutBuilder(builder: (context, constraints) {
      // Determine the expected paint size (matching the logic above).
      double expectedW =
          expand ? constraints.hasBoundedWidth ? constraints.maxWidth : tileSize * 8.0 : (width ?? (constraints.hasBoundedWidth ? constraints.maxWidth : tileSize * 8.0));
      double expectedH =
          expand ? constraints.hasBoundedHeight ? constraints.maxHeight : tileSize * 8.0 : (height ?? (constraints.hasBoundedHeight ? constraints.maxHeight : tileSize * 8.0));

      if (shape == BoxShape.circle && (expectedW - expectedH).abs() < 0.5) {
        return ClipOval(child: widget);
      }

      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(6.0),
        child: widget,
      );
    });
  }
}
