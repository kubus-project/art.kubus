import 'package:flutter/material.dart';

/// InlineProgress
/// Renders a small grid of tiles and reveals tiles progressively from the
/// center outwards according to [progress] (0..1). Useful for discovery
/// progress displays, inlined stats and compact visual indicators.
class InlineProgress extends StatelessWidget {
  final double progress; // 0..1
  final int rows;
  final int cols;
  final double tileSize;
  final double gap;
  final Color color;
  final Color backgroundColor;
  final Duration duration;
  final BorderRadius? borderRadius;
  final BoxShape? shape; // if circle, will clip to circle

  const InlineProgress({
    super.key,
    required this.progress,
    this.rows = 3,
    this.cols = 3,
    this.tileSize = 6.0,
    this.gap = 2.0,
    this.color = Colors.blue,
    this.backgroundColor = Colors.transparent,
    this.duration = const Duration(milliseconds: 360),
    this.borderRadius,
    this.shape,
  });

  @override
  Widget build(BuildContext context) {
    final animated = TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: progress.clamp(0.0, 1.0)),
      duration: duration,
      builder: (context, value, child) {
        final width = cols * tileSize + (cols - 1) * gap;
        final height = rows * tileSize + (rows - 1) * gap;
        Widget inner = CustomPaint(
          size: Size(width, height),
          painter: _InlineProgressPainter(
            rows: rows,
            cols: cols,
            tileSize: tileSize,
            gap: gap,
            progress: value,
            color: color,
            backgroundColor: backgroundColor,
          ),
        );
        if (shape == BoxShape.circle) {
          inner = ClipOval(child: inner);
        } else {
          inner = ClipRRect(borderRadius: borderRadius ?? BorderRadius.circular(6.0), child: inner);
        }
        return inner;
      },
    );
    return animated;
  }
}

class _InlineProgressPainter extends CustomPainter {
  final int rows;
  final int cols;
  final double tileSize;
  final double gap;
  final double progress;
  final Color color;
  final Color backgroundColor;

  _InlineProgressPainter({
    required this.rows,
    required this.cols,
    required this.tileSize,
    required this.gap,
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintBg = Paint()..color = backgroundColor;
    // Fill background
    if (backgroundColor != Colors.transparent) {
      canvas.drawRect(Offset.zero & size, paintBg);
    }

    final center = Offset(size.width / 2.0, size.height / 2.0);
    // compute max distance to a tile center
    double maxDist = 0.0;
    final centers = <Offset>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final x = c * (tileSize + gap) + tileSize / 2.0;
        final y = r * (tileSize + gap) + tileSize / 2.0;
        final pt = Offset(x, y);
        centers.add(pt);
        final d = (pt - center).distance;
        if (d > maxDist) maxDist = d;
      }
    }
    final revealRadius = maxDist * (progress.clamp(0.0, 1.0));

    // Draw tiles: if tile center within revealRadius -> draw fill color, else draw background color or subdued
    for (var i = 0; i < centers.length; i++) {
      final pt = centers[i];
      final d = (pt - center).distance;
      final drawColor = d <= revealRadius ? color : color.withValues(alpha: 0.14);
      final tilePaint = Paint()..color = drawColor;
      final rect = Rect.fromCenter(center: pt, width: tileSize, height: tileSize);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(2.0)), tilePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _InlineProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.backgroundColor != backgroundColor;
  }
}
