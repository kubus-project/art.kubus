import 'package:flutter/material.dart';

/// Canonical determinate meter bar (vote shares, upload progress, storage
/// usage). This is a *display* of a fraction — not a loading state; use
/// `InlineLoading` for indeterminate loading.
///
/// Replaces ad-hoc `LinearProgressIndicator(value: ...)` usages so meters
/// share one tokenized look (track + rounded accent fill).
class KubusMeterBar extends StatelessWidget {
  const KubusMeterBar({
    super.key,
    required this.progress,
    this.height = 6.0,
    this.color,
    this.trackColor,
    this.borderRadius,
  });

  /// Fraction 0..1 (values outside the range are clamped).
  final double progress;
  final double height;

  /// Fill color; defaults to the theme primary.
  final Color? color;

  /// Track color; defaults to a subtle surface-container tone.
  final Color? trackColor;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = color ?? scheme.primary;
    final track =
        trackColor ?? scheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final radius = borderRadius ?? BorderRadius.circular(height / 2);
    final clamped = progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: track)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: clamped,
              child: DecoratedBox(
                decoration: BoxDecoration(color: fill, borderRadius: radius),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
