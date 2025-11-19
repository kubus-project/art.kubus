import 'dart:math';
import 'package:flutter/material.dart';

/// Lightweight isometric pulse indicator, designed to replace inline spinners.
/// Small tiles and capped steps keep painting light-weight; can be sized via parent.
class IsometricPulse extends StatefulWidget {
  final Color? color;
  final Color? highlight;
  final Duration duration;
  final double tileSize; // hint tile size
  final bool animate;
  final double? progress; // optional determinate progress (0..1)
  const IsometricPulse({super.key, this.color, this.highlight, this.duration = const Duration(milliseconds: 800), this.tileSize = 8.0, this.animate = true, this.progress});

  @override
  State<IsometricPulse> createState() => _IsometricPulseState();
}

class _IsometricPulseState extends State<IsometricPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.animate) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final highlight = widget.highlight ?? color.withValues(alpha: 0.8);
    return CustomPaint(
      painter: _IsometricPulsePainter(animation: _controller, tileSize: widget.tileSize, accent: color, highlight: highlight, progress: widget.progress),
      size: Size.infinite,
    );
  }
}

class _IsometricPulsePainter extends CustomPainter {
  final Animation<double> animation;
  final double tileSize;
  final Color accent;
  final Color highlight;
  final double? progress;
  _IsometricPulsePainter({required this.animation, required this.tileSize, required this.accent, required this.highlight, this.progress}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    // Cap grid size to keep it light-weight
    final minDim = min(size.width, size.height);
    final effectiveTile = tileSize.clamp(4.0, 16.0);
    // Use minDim to scale tile for very small widgets
    final scaledTile = effectiveTile * (minDim / (effectiveTile * 8.0)).clamp(0.5, 2.0);
    final isoW = scaledTile;
    final isoH = scaledTile * 0.5;

    final cx = size.width * 0.5;
    final cy = size.height * 0.5;

    // Determine tiling steps across the widget so the grid fills the entire area
    var stepsX = (size.width / isoW).ceil() + 4;
    var stepsY = (size.height / isoH).ceil() + 4;
    const int maxSteps = 48; // allow a slightly larger cap for rectangular coverage
    if (stepsX > maxSteps) stepsX = maxSteps;
    if (stepsY > maxSteps) stepsY = maxSteps;

    final wave = animation.value * 2 * pi;

    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 0.8;

    for (int j = -stepsY; j < stepsY; j++) {
      for (int i = -stepsX; i < stepsX; i++) {
        final x = cx + (i - j) * isoW;
        final y = cy + (i + j) * isoH;
        if (x < -effectiveTile || x > size.width + effectiveTile || y < -effectiveTile || y > size.height + effectiveTile) continue;

        // Use grid-phase-based wave (not centered distance) to avoid circular gaps
        final t = wave + (i * 0.65) + (j * 0.35);
        var intensity = (sin(t) + 1) / 2.0; // 0..1
        if (progress != null) {
          // scale intensity by progress so determinate loads are visually subtle
          intensity *= (progress!.clamp(0.0, 1.0));
        }

        final color = Color.lerp(accent, highlight, intensity)!.withValues(alpha: 0.2 + 0.6 * intensity);
        paint.color = color;
        final s = effectiveTile * (0.6 + intensity * 0.6);
        // Draw a diamond/lozenge (isometric) using 4 lines
        final p1 = Offset(x, y - s * 0.5);
        final p2 = Offset(x + s * 0.5, y);
        final p3 = Offset(x, y + s * 0.5);
        final p4 = Offset(x - s * 0.5, y);
        canvas.drawLine(p1, p2, paint);
        canvas.drawLine(p2, p3, paint);
        canvas.drawLine(p3, p4, paint);
        canvas.drawLine(p4, p1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IsometricPulsePainter oldDelegate) {
    return oldDelegate.animation != animation || oldDelegate.tileSize != tileSize || oldDelegate.accent != accent || oldDelegate.highlight != highlight;
  }
}
