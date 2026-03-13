import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';

class GeneralBackground extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final bool animate;
  final List<Color>? colors;
  final Duration paletteTransitionDuration;
  final double hueShiftDegrees;
  final double intensity;
  final bool showMapLayer;

  const GeneralBackground({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 8),
    this.animate = true,
    this.colors,
    this.intensity = 0.3,
    this.paletteTransitionDuration = const Duration(milliseconds: 900),
    this.hueShiftDegrees = 10.0,
    this.showMapLayer = true,
  });

  @override
  State<GeneralBackground> createState() => _GeneralBackgroundState();
}

class _GeneralBackgroundState extends State<GeneralBackground>
    with TickerProviderStateMixin {
  late AnimationController _motionController;
  late Animation<double> _motion;

  late AnimationController _paletteController;
  List<Color> _paletteFrom = const <Color>[];
  List<Color> _paletteTo = const <Color>[];

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _motion = CurvedAnimation(
      parent: _motionController,
      curve: Curves.easeInOut,
    );

    _paletteController = AnimationController(
      duration: widget.paletteTransitionDuration,
      vsync: this,
    )..value = 1.0;

    if (widget.animate) {
      _motionController.repeat(reverse: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPaletteIfNeeded();
  }

  @override
  void didUpdateWidget(GeneralBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _motionController.duration = widget.duration;
    }
    if (widget.paletteTransitionDuration !=
        oldWidget.paletteTransitionDuration) {
      _paletteController.duration = widget.paletteTransitionDuration;
    }
    if (widget.animate != oldWidget.animate) {
      if (widget.animate) {
        _motionController.repeat(reverse: true);
      } else {
        _motionController.stop();
      }
    }
    if (!_listEquals(widget.colors, oldWidget.colors)) {
      _syncPaletteIfNeeded(force: true);
    }
  }

  @override
  void dispose() {
    _motionController.dispose();
    _paletteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_motion, _paletteController]),
      builder: (context, child) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final motionT = _motion.value;
        final progress = motionT * widget.intensity;

        final beginOffset = Alignment(
          -1.0 + (progress * 0.5),
          -1.0 + (progress * 0.3),
        );
        final endOffset = Alignment(
          1.0 - (progress * 0.3),
          1.0 - (progress * 0.5),
        );

        final paletteT = Curves.easeInOut.transform(_paletteController.value);
        final basePalette = _lerpColorLists(_paletteFrom, _paletteTo, paletteT);
        final effectivePalette = _applyHueShift(
          basePalette,
          degrees: widget.hueShiftDegrees,
          t: motionT,
          intensity: widget.intensity,
        );

        final isDark = theme.brightness == Brightness.dark;
        final mapAccent = Color.lerp(scheme.primary, scheme.secondary, 0.35) ??
            scheme.primary;
        final arterialColor = Color.lerp(scheme.onSurface, mapAccent, 0.72)!
            .withValues(alpha: isDark ? 0.17 : 0.095);
        final collectorColor = Color.lerp(
          scheme.outlineVariant,
          mapAccent,
          0.38,
        )!
            .withValues(alpha: isDark ? 0.10 : 0.055);
        final gridColor = scheme.onSurface.withValues(
          alpha: isDark ? 0.042 : 0.024,
        );
        final glowColor = mapAccent.withValues(alpha: isDark ? 0.14 : 0.075);
        final hubStrokeColor = Color.lerp(scheme.onSurface, mapAccent, 0.56)!
            .withValues(alpha: isDark ? 0.18 : 0.10);

        return Stack(
          fit: StackFit.expand,
          children: [
            if (widget.showMapLayer)
              IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _GeneralBackgroundMapPainter(
                      motionT: motionT,
                      intensity: widget.intensity,
                      gridColor: gridColor,
                      arterialColor: arterialColor,
                      collectorColor: collectorColor,
                      glowColor: glowColor,
                      hubStrokeColor: hubStrokeColor,
                    ),
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: effectivePalette,
                  begin: beginOffset,
                  end: endOffset,
                  stops: _calculateStops(effectivePalette.length, progress),
                ),
              ),
            ),
            if (child != null) child,
          ],
        );
      },
      child: widget.child,
    );
  }

  List<double> _calculateStops(int count, double progress) {
    if (count <= 1) return const <double>[0.0];
    final List<double> stops = <double>[];
    for (int i = 0; i < count; i++) {
      final baseStop = i / (count - 1);
      final offset = (i.isEven ? progress : -progress) * 0.1;
      stops.add((baseStop + offset).clamp(0.0, 1.0));
    }
    return stops;
  }

  void _syncPaletteIfNeeded({bool force = false}) {
    final desired = _resolveDesiredBasePalette(context);
    if (!force && _listEquals(desired, _paletteTo)) return;

    final current = _paletteFrom.isEmpty
        ? desired
        : _lerpColorLists(
            _paletteFrom,
            _paletteTo,
            Curves.easeInOut.transform(_paletteController.value),
          );

    _paletteFrom = current;
    _paletteTo = desired;
    _paletteController.forward(from: 0.0);
  }

  List<Color> _resolveDesiredBasePalette(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = widget.colors ??
        (isDark
            ? KubusGradients.animatedDarkColors
            : KubusGradients.animatedLightColors);

    if (colors.isEmpty) {
      return isDark
          ? KubusGradients.animatedDarkColors
          : KubusGradients.animatedLightColors;
    }
    return colors;
  }

  static bool _listEquals(List<Color>? a, List<Color>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].toARGB32() != b[i].toARGB32()) return false;
    }
    return true;
  }

  static List<Color> _lerpColorLists(List<Color> a, List<Color> b, double t) {
    if (a.isEmpty && b.isEmpty) return const <Color>[];
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;

    final length = math.max(a.length, b.length);
    final aPad = _padToLength(a, length);
    final bPad = _padToLength(b, length);
    return List<Color>.generate(length, (index) {
      return Color.lerp(aPad[index], bPad[index], t) ?? bPad[index];
    }, growable: false);
  }

  static List<Color> _padToLength(List<Color> colors, int length) {
    if (colors.length == length) return colors;
    if (colors.isEmpty) {
      return List<Color>.filled(length, Colors.transparent, growable: false);
    }
    final last = colors.last;
    return List<Color>.generate(
      length,
      (i) => i < colors.length ? colors[i] : last,
      growable: false,
    );
  }

  static List<Color> _applyHueShift(
    List<Color> colors, {
    required double degrees,
    required double t,
    required double intensity,
  }) {
    if (colors.isEmpty) return colors;
    if (degrees.abs() < 0.001) return colors;
    if (intensity <= 0.0) return colors;

    final shift = (t - 0.5) * 2.0 * degrees * intensity;
    return colors.map((c) => _shiftHue(c, shift)).toList(growable: false);
  }

  static Color _shiftHue(Color color, double degrees) {
    if (color.a <= 0.0) return color;
    final hsl = HSLColor.fromColor(color);
    final newHue = (hsl.hue + degrees) % 360.0;
    return hsl.withHue(newHue < 0 ? newHue + 360.0 : newHue).toColor();
  }
}

class _GeneralBackgroundMapPainter extends CustomPainter {
  final double motionT;
  final double intensity;
  final Color gridColor;
  final Color arterialColor;
  final Color collectorColor;
  final Color glowColor;
  final Color hubStrokeColor;

  const _GeneralBackgroundMapPainter({
    required this.motionT,
    required this.intensity,
    required this.gridColor,
    required this.arterialColor,
    required this.collectorColor,
    required this.glowColor,
    required this.hubStrokeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final drift = Offset(
      (motionT - 0.5) * size.width * 0.035 * intensity.clamp(0.2, 1.0),
      (0.5 - motionT) * size.height * 0.028 * intensity.clamp(0.2, 1.0),
    );
    final shortestSide = math.min(size.width, size.height);
    final density = size.width >= 1400
        ? 1.18
        : size.width >= 900
            ? 1.0
            : 0.84;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(drift.dx, drift.dy);

    _paintMinorGrid(canvas, size, density);
    _paintRoads(canvas, size, shortestSide, density);
    _paintBlocks(canvas, size, density);

    canvas.restore();

    _paintHubs(canvas, size, shortestSide, drift, density);
  }

  void _paintMinorGrid(Canvas canvas, Size size, double density) {
    final verticalCount = size.width >= 1200
        ? 9
        : size.width >= 700
            ? 7
            : 5;
    final horizontalCount = size.height >= 900
        ? 9
        : size.height >= 700
            ? 7
            : 5;
    final paint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * density;

    for (int i = 0; i < verticalCount; i++) {
      final x = size.width * ((i + 0.5) / verticalCount);
      final path = Path()
        ..moveTo(x, -size.height * 0.05)
        ..cubicTo(
          x - (12 * density),
          size.height * 0.24,
          x + (10 * density),
          size.height * 0.66,
          x - (8 * density),
          size.height * 1.05,
        );
      canvas.drawPath(path, paint);
    }

    for (int i = 0; i < horizontalCount; i++) {
      final y = size.height * ((i + 0.5) / horizontalCount);
      final path = Path()
        ..moveTo(-size.width * 0.05, y)
        ..cubicTo(
          size.width * 0.26,
          y - (10 * density),
          size.width * 0.72,
          y + (12 * density),
          size.width * 1.05,
          y - (8 * density),
        );
      canvas.drawPath(path, paint);
    }
  }

  void _paintRoads(
    Canvas canvas,
    Size size,
    double shortestSide,
    double density,
  ) {
    final arterialPaint = Paint()
      ..color = arterialColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, shortestSide * 0.0038) * density
      ..strokeCap = StrokeCap.round;
    final collectorPaint = Paint()
      ..color = collectorColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.1, shortestSide * 0.0026) * density
      ..strokeCap = StrokeCap.round;

    final ring = Rect.fromCenter(
      center: Offset(size.width * 0.58, size.height * 0.52),
      width: size.width * 0.34,
      height: size.height * 0.25,
    );
    canvas.drawOval(ring, collectorPaint);

    canvas.drawPath(_northArc(size), arterialPaint);
    canvas.drawPath(_southArc(size), arterialPaint);
    canvas.drawPath(_verticalSpine(size), arterialPaint);
    canvas.drawPath(_eastDiagonal(size), collectorPaint);
    canvas.drawPath(_westDiagonal(size), collectorPaint);
    canvas.drawPath(_innerConnector(size), collectorPaint);
  }

  void _paintBlocks(Canvas canvas, Size size, double density) {
    final blockPaint = Paint()
      ..color = collectorColor.withValues(alpha: collectorColor.a * 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, density);

    final blocks = <Rect>[
      Rect.fromLTWH(size.width * 0.16, size.height * 0.18, size.width * 0.10,
          size.height * 0.08),
      Rect.fromLTWH(size.width * 0.72, size.height * 0.18, size.width * 0.11,
          size.height * 0.09),
      Rect.fromLTWH(size.width * 0.26, size.height * 0.62, size.width * 0.12,
          size.height * 0.10),
      Rect.fromLTWH(size.width * 0.64, size.height * 0.66, size.width * 0.10,
          size.height * 0.08),
    ];

    for (final block in blocks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(block, Radius.circular(14 * density)),
        blockPaint,
      );
    }
  }

  void _paintHubs(
    Canvas canvas,
    Size size,
    double shortestSide,
    Offset drift,
    double density,
  ) {
    final glowRadius = math.max(22.0, shortestSide * 0.034) * density;
    final glowPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.fill
      ..maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        math.max(12.0, shortestSide * 0.015),
      );
    final hubPaint = Paint()
      ..color = hubStrokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, shortestSide * 0.0024) * density;

    final hubs = <Offset>[
      Offset(size.width * 0.24, size.height * 0.26),
      Offset(size.width * 0.58, size.height * 0.51),
      Offset(size.width * 0.79, size.height * 0.34),
      Offset(size.width * 0.34, size.height * 0.72),
    ];

    final parallax = Offset(-drift.dx * 0.4, -drift.dy * 0.4);
    for (final hub in hubs) {
      final center = hub + parallax;
      canvas.drawCircle(center, glowRadius, glowPaint);
      canvas.drawCircle(center, glowRadius * 0.56, hubPaint);
      canvas.drawCircle(
          center, glowRadius * 0.16, hubPaint..style = PaintingStyle.fill);
      hubPaint.style = PaintingStyle.stroke;
    }
  }

  Path _northArc(Size size) {
    return Path()
      ..moveTo(size.width * 0.02, size.height * 0.18)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.07,
        size.width * 0.34,
        size.height * 0.10,
        size.width * 0.47,
        size.height * 0.18,
      )
      ..cubicTo(
        size.width * 0.66,
        size.height * 0.30,
        size.width * 0.83,
        size.height * 0.18,
        size.width * 1.02,
        size.height * 0.08,
      );
  }

  Path _southArc(Size size) {
    return Path()
      ..moveTo(size.width * -0.02, size.height * 0.78)
      ..cubicTo(
        size.width * 0.16,
        size.height * 0.64,
        size.width * 0.34,
        size.height * 0.60,
        size.width * 0.52,
        size.height * 0.70,
      )
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.82,
        size.width * 0.88,
        size.height * 0.78,
        size.width * 1.04,
        size.height * 0.92,
      );
  }

  Path _verticalSpine(Size size) {
    return Path()
      ..moveTo(size.width * 0.46, size.height * -0.04)
      ..cubicTo(
        size.width * 0.42,
        size.height * 0.18,
        size.width * 0.54,
        size.height * 0.34,
        size.width * 0.50,
        size.height * 0.52,
      )
      ..cubicTo(
        size.width * 0.46,
        size.height * 0.72,
        size.width * 0.54,
        size.height * 0.86,
        size.width * 0.48,
        size.height * 1.04,
      );
  }

  Path _eastDiagonal(Size size) {
    return Path()
      ..moveTo(size.width * 0.58, size.height * 0.14)
      ..cubicTo(
        size.width * 0.68,
        size.height * 0.24,
        size.width * 0.76,
        size.height * 0.40,
        size.width * 0.92,
        size.height * 0.52,
      );
  }

  Path _westDiagonal(Size size) {
    return Path()
      ..moveTo(size.width * 0.14, size.height * 0.56)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.46,
        size.width * 0.34,
        size.height * 0.38,
        size.width * 0.48,
        size.height * 0.34,
      );
  }

  Path _innerConnector(Size size) {
    return Path()
      ..moveTo(size.width * 0.28, size.height * 0.78)
      ..cubicTo(
        size.width * 0.42,
        size.height * 0.60,
        size.width * 0.62,
        size.height * 0.56,
        size.width * 0.78,
        size.height * 0.36,
      );
  }

  @override
  bool shouldRepaint(_GeneralBackgroundMapPainter oldDelegate) {
    return motionT != oldDelegate.motionT ||
        intensity != oldDelegate.intensity ||
        gridColor.toARGB32() != oldDelegate.gridColor.toARGB32() ||
        arterialColor.toARGB32() != oldDelegate.arterialColor.toARGB32() ||
        collectorColor.toARGB32() != oldDelegate.collectorColor.toARGB32() ||
        glowColor.toARGB32() != oldDelegate.glowColor.toARGB32() ||
        hubStrokeColor.toARGB32() != oldDelegate.hubStrokeColor.toARGB32();
  }
}
