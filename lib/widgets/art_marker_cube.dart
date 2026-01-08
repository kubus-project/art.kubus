import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/art_marker.dart';

/// A stylised, responsive isometric cube marker used on the discovery map.
///
/// Renders a polished 3D isometric cube with the subject icon displayed
/// directly on the top face in perspective, colored by subject type.
class ArtMarkerCube extends StatelessWidget {
  const ArtMarkerCube({
    super.key,
    required this.marker,
    required this.baseColor,
    required this.icon,
    this.size = 64,
    this.glow = false,
  });

  final ArtMarker marker;
  final Color baseColor;
  final IconData icon;
  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final _CubePalette palette = _CubePalette.fromBase(baseColor);
    // Cube body occupies 70% height, rest is for shadow/spacing
    final double cubeBodyHeight = size * 0.85;
    final double totalHeight = size * 1.15;

    return SizedBox(
      width: size,
      height: totalHeight,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Ground shadow (ellipse beneath cube)
          Positioned(
            bottom: 0,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..scale(1.0, 0.35),
              child: Container(
                width: size * 0.72,
                height: size * 0.72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.black.withValues(alpha: glow ? 0.35 : 0.22),
                      Colors.black.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // Optional colored glow beneath cube
          if (glow)
            Positioned(
              bottom: size * 0.02,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..scale(1.0, 0.32),
                child: Container(
                  width: size * 0.9,
                  height: size * 0.9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        baseColor.withValues(alpha: 0.45),
                        baseColor.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          // Isometric cube with icon on top
          Positioned(
            bottom: size * 0.12,
            child: CustomPaint(
              size: Size(size * 0.88, cubeBodyHeight),
              painter: _IsometricCubePainter(
                palette: palette,
                icon: icon,
              ),
            ),
          ),
          // Signal tier indicator (subtle ring around base)
          if (marker.signalTier != ArtMarkerSignal.subtle)
            Positioned(
              bottom: size * 0.04,
              child: _SignalIndicator(
                tier: marker.signalTier,
                baseColor: baseColor,
                size: size * 0.68,
              ),
            ),
        ],
      ),
    );
  }
}

class _IsometricCubePainter extends CustomPainter {
  const _IsometricCubePainter({
    required this.palette,
    required this.icon,
  });

  final _CubePalette palette;
  final IconData icon;

  @override
  void paint(Canvas canvas, Size size) {
    final _ProjectedCube cube = _ProjectedCube(size: size);

    // Draw drop shadow beneath the cube
    final Path shadowPath = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(size.width / 2, size.height - size.height * 0.02),
        width: size.width * 0.65,
        height: size.height * 0.12,
      ));
    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Left face (darker)
    final Path leftPath = cube.pathForVertices(const [
      _CubeVertex.backLeftTop,
      _CubeVertex.frontLeftTop,
      _CubeVertex.frontLeftBottom,
      _CubeVertex.backLeftBottom,
    ]);

    canvas.drawPath(
      leftPath,
      Paint()
        ..shader = LinearGradient(
          colors: [palette.left, palette.left.withValues(alpha: 0.85)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(leftPath.getBounds()),
    );

    // Right face (slightly lighter than left)
    final Path rightPath = cube.pathForVertices(const [
      _CubeVertex.frontRightTop,
      _CubeVertex.backRightTop,
      _CubeVertex.backRightBottom,
      _CubeVertex.frontRightBottom,
    ]);

    canvas.drawPath(
      rightPath,
      Paint()
        ..shader = LinearGradient(
          colors: [palette.right, palette.right.withValues(alpha: 0.9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rightPath.getBounds()),
    );

    // Front-left face
    final Path frontLeftPath = cube.pathForProjectedPoints(
      cube.frontMidTop,
      cube.frontMidBottom,
      side: _FrontSide.left,
    );

    canvas.drawPath(
      frontLeftPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            palette.frontLeft,
            palette.frontLeft.withValues(alpha: 0.88)
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(frontLeftPath.getBounds()),
    );

    // Front-right face
    final Path frontRightPath = cube.pathForProjectedPoints(
      cube.frontMidTop,
      cube.frontMidBottom,
      side: _FrontSide.right,
    );

    canvas.drawPath(
      frontRightPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            palette.frontRight,
            palette.frontRight.withValues(alpha: 0.85)
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(frontRightPath.getBounds()),
    );

    // Top face (brightest - icon sits here)
    final Path topPath = cube.pathForVertices(const [
      _CubeVertex.backLeftTop,
      _CubeVertex.backRightTop,
      _CubeVertex.frontRightTop,
      _CubeVertex.frontLeftTop,
    ]);

    // Gradient from center outward for a polished look
    canvas.drawPath(
      topPath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.2),
          radius: 1.2,
          colors: [palette.topAccent, palette.top],
        ).createShader(topPath.getBounds()),
    );

    // Draw edges for definition
    final Paint edgePaint = Paint()
      ..color = palette.edge
      ..strokeWidth = size.width * 0.018
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Top face outline
    canvas.drawPath(
      cube.pathForVertices(const [
        _CubeVertex.backLeftTop,
        _CubeVertex.backRightTop,
        _CubeVertex.frontRightTop,
        _CubeVertex.frontLeftTop,
        _CubeVertex.backLeftTop,
      ]),
      edgePaint,
    );

    // Vertical edges at front corner
    final Paint verticalEdgePaint = Paint()
      ..color = palette.edge.withValues(alpha: 0.6)
      ..strokeWidth = size.width * 0.016
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      cube.vertex(_CubeVertex.frontLeftTop),
      cube.vertex(_CubeVertex.frontLeftBottom),
      verticalEdgePaint,
    );
    canvas.drawLine(
      cube.vertex(_CubeVertex.frontRightTop),
      cube.vertex(_CubeVertex.frontRightBottom),
      verticalEdgePaint,
    );
    canvas.drawLine(cube.frontMidTop, cube.frontMidBottom, verticalEdgePaint);

    // Highlight along top edges for depth
    final Paint highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = size.width * 0.012
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path highlight = Path()
      ..moveTo(cube.vertex(_CubeVertex.backLeftTop).dx,
          cube.vertex(_CubeVertex.backLeftTop).dy)
      ..lineTo(cube.vertex(_CubeVertex.frontLeftTop).dx,
          cube.vertex(_CubeVertex.frontLeftTop).dy)
      ..lineTo(cube.frontMidTop.dx, cube.frontMidTop.dy);
    canvas.drawPath(highlight, highlightPaint);

    // Draw icon on top face in isometric perspective
    _drawIconOnTopFace(canvas, size, cube);
  }

  void _drawIconOnTopFace(Canvas canvas, Size size, _ProjectedCube cube) {
    // Calculate center of top face
    final topCenter = Offset(
      (cube.vertex(_CubeVertex.backLeftTop).dx +
              cube.vertex(_CubeVertex.backRightTop).dx +
              cube.vertex(_CubeVertex.frontRightTop).dx +
              cube.vertex(_CubeVertex.frontLeftTop).dx) /
          4,
      (cube.vertex(_CubeVertex.backLeftTop).dy +
              cube.vertex(_CubeVertex.backRightTop).dy +
              cube.vertex(_CubeVertex.frontRightTop).dy +
              cube.vertex(_CubeVertex.frontLeftTop).dy) /
          4,
    );

    // Icon circle size relative to cube
    final double iconRadius = size.width * 0.24;

    // Draw icon background circle (white with subtle shadow)
    final Paint circleShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawOval(
      Rect.fromCenter(
        center: topCenter + const Offset(0, 1.5),
        width: iconRadius * 2,
        height: iconRadius * 1.3, // Squished for isometric
      ),
      circleShadowPaint,
    );

    // Icon background (white ellipse matching isometric perspective)
    final Paint circlePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95);
    canvas.drawOval(
      Rect.fromCenter(
        center: topCenter,
        width: iconRadius * 2,
        height: iconRadius * 1.3,
      ),
      circlePaint,
    );

    // Border around icon circle
    final Paint borderPaint = Paint()
      ..color = palette.topAccent.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.02;
    canvas.drawOval(
      Rect.fromCenter(
        center: topCenter,
        width: iconRadius * 2,
        height: iconRadius * 1.3,
      ),
      borderPaint,
    );

    // Draw the icon using a TextPainter
    final TextPainter iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size.width * 0.28,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: palette.topAccent,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();

    // Position icon in center of top face
    final iconOffset = Offset(
      topCenter.dx - iconPainter.width / 2,
      topCenter.dy - iconPainter.height / 2 - size.height * 0.015,
    );
    iconPainter.paint(canvas, iconOffset);
  }

  @override
  bool shouldRepaint(covariant _IsometricCubePainter oldDelegate) {
    return oldDelegate.palette != palette || oldDelegate.icon != icon;
  }
}

/// Subtle signal indicator rendered as a glowing ring beneath the cube
class _SignalIndicator extends StatelessWidget {
  const _SignalIndicator({
    required this.tier,
    required this.baseColor,
    required this.size,
  });

  final ArtMarkerSignal tier;
  final Color baseColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color glowColor;
    final double opacity;

    switch (tier) {
      case ArtMarkerSignal.legendary:
        glowColor = Colors.amber;
        opacity = 0.7;
        break;
      case ArtMarkerSignal.featured:
        glowColor = baseColor;
        opacity = 0.55;
        break;
      case ArtMarkerSignal.active:
        glowColor = baseColor;
        opacity = 0.35;
        break;
      case ArtMarkerSignal.subtle:
        return const SizedBox.shrink();
    }

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scale(1.0, 0.35),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: glowColor.withValues(alpha: opacity),
            width: tier == ArtMarkerSignal.legendary ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: opacity * 0.6),
              blurRadius: tier == ArtMarkerSignal.legendary ? 8 : 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _CubePalette {
  const _CubePalette({
    required this.top,
    required this.topAccent,
    required this.left,
    required this.right,
    required this.frontLeft,
    required this.frontRight,
    required this.base,
    required this.edge,
  });

  final Color top;
  final Color topAccent;
  final Color left;
  final Color right;
  final Color frontLeft;
  final Color frontRight;
  final Color base;
  final Color edge;

  factory _CubePalette.fromBase(Color color) {
    final normalized = _normalizeBase(color);
    final hsl = HSLColor.fromColor(normalized);

    // Increase saturation slightly for more vibrant colors
    final vibrant =
        hsl.withSaturation((hsl.saturation * 1.15).clamp(0.0, 1.0)).toColor();

    return _CubePalette(
      // Top face is brightest (light comes from above)
      top: _lighten(vibrant, 0.22),
      topAccent: _saturate(_lighten(vibrant, 0.12), 0.1),
      // Left face catches some light
      left: _darken(vibrant, 0.08),
      // Right face is in shadow
      right: _darken(vibrant, 0.18),
      // Front faces are darker (angled away from light)
      frontLeft: _darken(vibrant, 0.22),
      frontRight: _darken(vibrant, 0.28),
      // Base shadow
      base: normalized.withValues(alpha: 0.4),
      // Edges for definition
      edge: Colors.black.withValues(alpha: 0.35),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is _CubePalette &&
            other.top == top &&
            other.topAccent == topAccent &&
            other.left == left &&
            other.right == right &&
            other.frontLeft == frontLeft &&
            other.frontRight == frontRight &&
            other.base == base &&
            other.edge == edge);
  }

  @override
  int get hashCode => Object.hash(
        top,
        topAccent,
        left,
        right,
        frontLeft,
        frontRight,
        base,
        edge,
      );
}

class _ProjectedCube {
  _ProjectedCube({required Size size}) {
    final Map<_CubeVertex, Offset> projected = _projectVertices();

    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    projected.forEach((_, point) {
      if (point.dx < minX) minX = point.dx;
      if (point.dx > maxX) maxX = point.dx;
      if (point.dy < minY) minY = point.dy;
      if (point.dy > maxY) maxY = point.dy;
    });

    final double width = maxX - minX;
    final double height = maxY - minY;
    final double scale = math.min(
          (size.width) / width,
          (size.height) / height,
        ) *
        0.92;

    final double offsetX = (size.width - width * scale) / 2;
    final double offsetY = size.height - height * scale;

    _vertices = projected.map((key, value) {
      return MapEntry(
        key,
        Offset(
          (value.dx - minX) * scale + offsetX,
          (value.dy - minY) * scale + offsetY,
        ),
      );
    });

    frontMidTop = _lerp(
      _vertices[_CubeVertex.frontLeftTop]!,
      _vertices[_CubeVertex.frontRightTop]!,
      0.5,
    );

    frontMidBottom = _lerp(
      _vertices[_CubeVertex.frontLeftBottom]!,
      _vertices[_CubeVertex.frontRightBottom]!,
      0.5,
    );
  }

  late final Map<_CubeVertex, Offset> _vertices;
  late final Offset frontMidTop;
  late final Offset frontMidBottom;

  Offset vertex(_CubeVertex id) => _vertices[id]!;

  Path pathForVertices(List<_CubeVertex> ids) {
    final Path path = Path()
      ..moveTo(_vertices[ids.first]!.dx, _vertices[ids.first]!.dy);
    for (int i = 1; i < ids.length; i++) {
      final Offset point = _vertices[ids[i]]!;
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    return path;
  }

  Path pathForProjectedPoints(Offset midTop, Offset midBottom,
      {required _FrontSide side}) {
    if (side == _FrontSide.left) {
      return Path()
        ..moveTo(vertex(_CubeVertex.frontLeftTop).dx,
            vertex(_CubeVertex.frontLeftTop).dy)
        ..lineTo(midTop.dx, midTop.dy)
        ..lineTo(midBottom.dx, midBottom.dy)
        ..lineTo(vertex(_CubeVertex.frontLeftBottom).dx,
            vertex(_CubeVertex.frontLeftBottom).dy)
        ..close();
    }

    return Path()
      ..moveTo(midTop.dx, midTop.dy)
      ..lineTo(vertex(_CubeVertex.frontRightTop).dx,
          vertex(_CubeVertex.frontRightTop).dy)
      ..lineTo(vertex(_CubeVertex.frontRightBottom).dx,
          vertex(_CubeVertex.frontRightBottom).dy)
      ..lineTo(midBottom.dx, midBottom.dy)
      ..close();
  }

  Map<_CubeVertex, Offset> _projectVertices() {
    const double size = 1.0;
    return {
      _CubeVertex.frontLeftBottom: _isoProject(0, size, 0),
      _CubeVertex.frontRightBottom: _isoProject(size, size, 0),
      _CubeVertex.backRightBottom: _isoProject(size, 0, 0),
      _CubeVertex.backLeftBottom: _isoProject(0, 0, 0),
      _CubeVertex.frontLeftTop: _isoProject(0, size, size),
      _CubeVertex.frontRightTop: _isoProject(size, size, size),
      _CubeVertex.backRightTop: _isoProject(size, 0, size),
      _CubeVertex.backLeftTop: _isoProject(0, 0, size),
    };
  }

  Offset _isoProject(double x, double y, double z) {
    const double angle = math.pi / 4; // Rotate to show both diagonals
    final double cosA = math.cos(angle);
    final double sinA = math.sin(angle);

    final double rotatedX = x * cosA - y * sinA;
    final double rotatedY = x * sinA + y * cosA;

    const double tilt = math.pi / 6; // 30° tilt towards viewer
    final double cosTilt = math.cos(tilt);
    final double sinTilt = math.sin(tilt);

    final double isoX = rotatedX;
    final double isoY = rotatedY * cosTilt - z * sinTilt;

    return Offset(isoX, isoY);
  }
}

enum _CubeVertex {
  frontLeftBottom,
  frontRightBottom,
  backRightBottom,
  backLeftBottom,
  frontLeftTop,
  frontRightTop,
  backRightTop,
  backLeftTop,
}

enum _FrontSide { left, right }

Offset _lerp(Offset a, Offset b, double t) {
  return Offset(
    a.dx + (b.dx - a.dx) * t,
    a.dy + (b.dy - a.dy) * t,
  );
}

Color _lighten(Color color, double amount) {
  final HSLColor hsl = HSLColor.fromColor(color);
  final double lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
  return hsl.withLightness(lightness).toColor();
}

Color _darken(Color color, double amount) {
  final HSLColor hsl = HSLColor.fromColor(color);
  final double lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
  return hsl.withLightness(lightness).toColor();
}

Color _saturate(Color color, double amount) {
  final HSLColor hsl = HSLColor.fromColor(color);
  final double saturation = (hsl.saturation + amount).clamp(0.0, 1.0);
  return hsl.withSaturation(saturation).toColor();
}

Color _normalizeBase(Color color) {
  final hsl = HSLColor.fromColor(color);
  // Clamp lightness to ensure good contrast on both light and dark maps
  final lightness = hsl.lightness.clamp(0.28, 0.62);
  // Ensure minimum saturation for color visibility
  final saturation = hsl.saturation.clamp(0.35, 1.0);
  return hsl
      .withLightness(lightness.toDouble())
      .withSaturation(saturation.toDouble())
      .toColor();
}
