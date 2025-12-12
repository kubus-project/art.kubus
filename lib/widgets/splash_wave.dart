import 'dart:math';
import 'package:flutter/material.dart';
import 'app_logo.dart';

class SplashWave extends StatefulWidget {
  final Color? color;
  final Duration duration;
  const SplashWave({super.key, this.color, this.duration = const Duration(seconds: 2)});

  @override
  State<SplashWave> createState() => _SplashWaveState();
}

class _SplashWaveState extends State<SplashWave> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
    _logoScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.35, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseBackground = theme.colorScheme.surface;
    final accent = widget.color ?? theme.colorScheme.primary;
    // Compute a lighter highlight color for the wave
    Color highlight;
    try {
      final hsl = HSLColor.fromColor(accent);
      final lighter = hsl.withLightness((hsl.lightness + 0.25).clamp(0.0, 1.0));
      highlight = lighter.toColor();
    } catch (_) {
      highlight = accent.withValues(alpha: 0.85);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.maybeOf(context);
        final mediaSize = mediaQuery?.size ?? const Size(800, 600);
        double sanitizeDimension(double candidate, double fallback) {
          if (candidate.isNaN || !candidate.isFinite || candidate <= 0) {
            return fallback;
          }
          return candidate;
        }

        final fallbackWidth = mediaSize.width.isFinite && mediaSize.width > 0 ? mediaSize.width : 800.0;
        final fallbackHeight = mediaSize.height.isFinite && mediaSize.height > 0 ? mediaSize.height : 600.0;
        final width = sanitizeDimension(
          constraints.hasBoundedWidth ? constraints.maxWidth : mediaSize.width,
          fallbackWidth,
        );
        final height = sanitizeDimension(
          constraints.hasBoundedHeight ? constraints.maxHeight : mediaSize.height,
          fallbackHeight,
        );

        final logoSize = min(width, height) * 0.22;

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return SizedBox(
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    size: Size(width, height),
                    painter: _IsometricGridPainter(
                      progress: _controller.value,
                      accent: accent,
                      highlight: highlight,
                      background: baseBackground,
                    ),
                  ),
                  Center(
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: SizedBox(
                        width: logoSize,
                        height: logoSize,
                        child: const AppLogo(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _IsometricGridPainter extends CustomPainter {
  final double progress; // 0..1
  final Color accent;
  final Color highlight;
  final Color background;
  _IsometricGridPainter({
    required this.progress,
    required this.accent,
    required this.highlight,
    required this.background,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..style = PaintingStyle.fill..color = background;
    canvas.drawRect(Offset.zero & size, bgPaint);

    // --- TRUE ISOMETRIC GRID CONFIG ---
    min(size.width, size.height);
    // Make diamonds even smaller and reduce wave deformation
    final tileSize = (min(size.width, size.height) / 44.0).clamp(6.0, 24.0);

    // True isometric: 2:1 ratio
    final isoW = tileSize;
    final isoH = tileSize * 0.5;

    final cx = size.width * 0.5;
    final cy = size.height * 0.5;

    final maxDist = sqrt(cx * cx + cy * cy) + tileSize * 6.0;
    var steps = (maxDist / isoW).ceil() + 6;
    // Cap steps to avoid huge grids on large screens which cause lag
    const int maxSteps = 80;
    if (steps > maxSteps) steps = maxSteps;

    final wave = progress * 2 * pi;

    List<List<_IsoPoint>> grid = List.generate(
      steps * 2,
      (j) => List.filled(steps * 2, _IsoPoint(Offset.zero, 0)),
    );
    for (int j = -steps; j < steps; j++) {
      for (int i = -steps; i < steps; i++) {
        final x = cx + (i - j) * isoW;
        final y = cy + (i + j) * isoH;

        if (x < -tileSize || x > size.width + tileSize || y < -tileSize || y > size.height + tileSize) {
          continue;
        }

        final dx = x - cx;
        final dy = y - cy;
        final dist = sqrt(dx * dx + dy * dy);

        final t = wave - dist / 40.0;
        final waveEdge = sin(t);

        // Less movement, more color
        double deform = 0.0;
        if (waveEdge > 0.7) {
          deform = 3.0 * (waveEdge - 0.7) / 0.3;
        }
        double px = x, py = y;
        if (deform > 0) {
          final norm = dist == 0 ? Offset.zero : Offset(dx / dist, dy / dist);
          px += norm.dx * deform;
          py += norm.dy * deform;
        }
        // Color factor for this point (for line coloring)
        final colorF = ((waveEdge + 1) / 2).clamp(0.0, 1.0);
        grid[j + steps][i + steps] = _IsoPoint(Offset(px, py), colorF);
      }
    }

    // Draw isometric grid lines: right and down, color lines based on wave
    for (int j = 0; j < steps * 2; j++) {
      for (int i = 0; i < steps * 2; i++) {
        final p = grid[j][i];
        if (p.offset == Offset.zero) continue;
        // Right neighbor (i+1, j)
        if (i + 1 < steps * 2 && grid[j][i + 1].offset != Offset.zero) {
          final pRight = grid[j][i + 1];
          final colorF = max(p.colorF, pRight.colorF);
          final paint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..color = Color.lerp(accent, highlight, colorF)!.withValues(alpha: 0.38 + 0.32 * colorF)
            ..strokeWidth = 0.9 + 0.7 * colorF;
          canvas.drawLine(p.offset, pRight.offset, paint);
        }
        // Down neighbor (i, j+1)
        if (j + 1 < steps * 2 && grid[j + 1][i].offset != Offset.zero) {
          final pDown = grid[j + 1][i];
          final colorF = max(p.colorF, pDown.colorF);
          final paint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..color = Color.lerp(accent, highlight, colorF)!.withValues(alpha: 0.38 + 0.32 * colorF)
            ..strokeWidth = 0.9 + 0.7 * colorF;
          canvas.drawLine(p.offset, pDown.offset, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IsometricGridPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accent != accent ||
        oldDelegate.highlight != highlight ||
        oldDelegate.background != background;
  }
}

class _IsoPoint {
  final Offset offset;
  final double colorF;
  const _IsoPoint(this.offset, this.colorF);
}

class SplashWavePainter extends CustomPainter {
  final Color background;
  final Color highlight;
  final Animation<double> animation;

  SplashWavePainter({
    required this.background,
    required this.highlight,
    required this.animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = background
      ..style = PaintingStyle.fill;

    // Fill the background
    canvas.drawRect(Offset.zero & size, paint);

    // Draw the wave
    final wavePaint = Paint()
      ..color = highlight
      ..style = PaintingStyle.fill;

    final path = Path();
    final waveHeight = size.height * 0.2;
    final waveLength = size.width * 0.5;
    final progress = animation.value * waveLength;

    path.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += waveLength) {
      path.relativeQuadraticBezierTo(
        waveLength / 4, -waveHeight,
        waveLength / 2, 0,
      );
      path.relativeQuadraticBezierTo(
        waveLength / 4, waveHeight,
        waveLength / 2, 0,
      );
    }
    path.lineTo(size.width, size.height);
    path.close();

    canvas.translate(-progress, 0);
    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant SplashWavePainter oldDelegate) {
    return oldDelegate.background != background ||
        oldDelegate.highlight != highlight ||
        oldDelegate.animation != animation;
  }
}
