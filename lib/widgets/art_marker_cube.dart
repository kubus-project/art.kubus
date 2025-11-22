import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/art_marker.dart';

/// A stylised, responsive isometric cube marker used on the discovery map.
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
    final double cubeHeight = size * 1.18;
    final double iconExtent = size * 0.44;

    return SizedBox(
      width: size,
      height: size * 1.35,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          if (glow)
            Positioned(
              bottom: size * -0.04,
              child: Container(
                width: size * 1.35,
                height: size * 0.52,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.1),
                    radius: 0.9,
                    colors: [
                      baseColor.withValues(alpha: 0.32),
                      baseColor.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.58, 1.0],
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: CustomPaint(
                size: Size(size, cubeHeight),
                painter: _IsometricCubePainter(
                  palette: palette,
                ),
              ),
            ),
          ),
          Positioned(
            top: size * 0.2,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateX(-18 * math.pi / 180),
              child: Container(
                width: iconExtent,
                height: iconExtent,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(size * 0.14),
                  border: Border.all(
                    color: palette.topAccent.withValues(alpha: 0.65),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: size * 0.12,
                      offset: Offset(0, size * 0.05),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: palette.topAccent,
                  size: size * 0.26,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: size * 0.2,
            child: _SignalPip(
              tier: marker.signalTier,
              palette: palette,
              size: math.max(16.0, size * 0.22),
            ),
          ),
        ],
      ),
    );
  }
}

class _IsometricCubePainter extends CustomPainter {
  const _IsometricCubePainter({required this.palette});

  final _CubePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final _ProjectedCube cube = _ProjectedCube(size: size);

    final Path basePath = cube.pathForVertices(const [
      _CubeVertex.frontLeftBottom,
      _CubeVertex.frontRightBottom,
      _CubeVertex.backRightBottom,
      _CubeVertex.backLeftBottom,
    ]);

    canvas.drawShadow(
      basePath.shift(const Offset(0, 6)),
      Colors.black.withValues(alpha: 0.3),
      size.width * 0.08,
      false,
    );

    final Paint basePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          palette.base.withValues(alpha: 0.9),
          palette.base.withValues(alpha: 0.45),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(basePath.getBounds());

    canvas.drawPath(basePath, basePaint);

    final Path leftPath = cube.pathForVertices(const [
      _CubeVertex.backLeftTop,
      _CubeVertex.frontLeftTop,
      _CubeVertex.frontLeftBottom,
      _CubeVertex.backLeftBottom,
    ]);

    final Path rightPath = cube.pathForVertices(const [
      _CubeVertex.frontRightTop,
      _CubeVertex.backRightTop,
      _CubeVertex.backRightBottom,
      _CubeVertex.frontRightBottom,
    ]);

    final Path frontLeftPath = cube.pathForProjectedPoints(
      cube.frontMidTop,
      cube.frontMidBottom,
      side: _FrontSide.left,
    );

    final Path frontRightPath = cube.pathForProjectedPoints(
      cube.frontMidTop,
      cube.frontMidBottom,
      side: _FrontSide.right,
    );

    final Path topPath = cube.pathForVertices(const [
      _CubeVertex.backLeftTop,
      _CubeVertex.backRightTop,
      _CubeVertex.frontRightTop,
      _CubeVertex.frontLeftTop,
    ]);

    final Paint leftPaint = Paint()
      ..shader = LinearGradient(
        colors: [palette.left, palette.left.withValues(alpha: 0.82)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(leftPath.getBounds());

    final Paint rightPaint = Paint()
      ..shader = LinearGradient(
        colors: [palette.right.withValues(alpha: 0.95), palette.right],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ).createShader(rightPath.getBounds());

    final Paint frontLeftPaint = Paint()
      ..shader = LinearGradient(
        colors: [palette.frontLeft, palette.frontLeft.withValues(alpha: 0.86)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(frontLeftPath.getBounds());

    final Paint frontRightPaint = Paint()
      ..shader = LinearGradient(
        colors: [palette.frontRight, palette.frontRight.withValues(alpha: 0.84)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(frontRightPath.getBounds());

    final Paint topPaint = Paint()
      ..shader = LinearGradient(
        colors: [palette.top, palette.topAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(topPath.getBounds());

    canvas
      ..drawPath(leftPath, leftPaint)
      ..drawPath(rightPath, rightPaint)
      ..drawPath(frontLeftPath, frontLeftPaint)
      ..drawPath(frontRightPath, frontRightPaint)
      ..drawPath(topPath, topPaint);

    final Paint edgePaint = Paint()
      ..color = palette.edge
      ..strokeWidth = size.width * 0.015
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final Paint frontEdgePaint = Paint()
      ..color = palette.edge.withValues(alpha: 0.75)
      ..strokeWidth = edgePaint.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final Path topOutline = cube.pathForVertices(const [
      _CubeVertex.backLeftTop,
      _CubeVertex.backRightTop,
      _CubeVertex.frontRightTop,
      _CubeVertex.frontLeftTop,
      _CubeVertex.backLeftTop,
    ]);

    final Path frontOutline = Path()
      ..moveTo(cube.vertex(_CubeVertex.frontLeftTop).dx,
          cube.vertex(_CubeVertex.frontLeftTop).dy)
      ..lineTo(cube.vertex(_CubeVertex.frontLeftBottom).dx,
          cube.vertex(_CubeVertex.frontLeftBottom).dy)
      ..moveTo(cube.vertex(_CubeVertex.frontRightTop).dx,
          cube.vertex(_CubeVertex.frontRightTop).dy)
      ..lineTo(cube.vertex(_CubeVertex.frontRightBottom).dx,
          cube.vertex(_CubeVertex.frontRightBottom).dy)
      ..moveTo(cube.frontMidTop.dx, cube.frontMidTop.dy)
      ..lineTo(cube.frontMidBottom.dx, cube.frontMidBottom.dy);

    canvas
      ..drawPath(topOutline, edgePaint)
      ..drawPath(frontOutline, frontEdgePaint);

    final Paint highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = size.width * 0.01
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path highlight = Path()
      ..moveTo(cube.vertex(_CubeVertex.backLeftTop).dx,
          cube.vertex(_CubeVertex.backLeftTop).dy)
      ..lineTo(cube.vertex(_CubeVertex.frontLeftTop).dx,
          cube.vertex(_CubeVertex.frontLeftTop).dy)
      ..lineTo(cube.frontMidTop.dx, cube.frontMidTop.dy);

    canvas.drawPath(highlight, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _IsometricCubePainter oldDelegate) {
    return oldDelegate.palette != palette;
  }
}

class _SignalPip extends StatelessWidget {
  const _SignalPip({
    required this.tier,
    required this.palette,
    required this.size,
  });

  final ArtMarkerSignal tier;
  final _CubePalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color fillColor;
    switch (tier) {
      case ArtMarkerSignal.legendary:
        fillColor = Colors.amberAccent;
        break;
      case ArtMarkerSignal.featured:
        fillColor = palette.topAccent.withValues(alpha: 0.92);
        break;
      case ArtMarkerSignal.active:
        fillColor = Colors.white.withValues(alpha: 0.9);
        break;
      case ArtMarkerSignal.subtle:
        fillColor = Colors.white.withValues(alpha: 0.55);
        break;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: palette.edge.withValues(alpha: 0.4), width: size * 0.12),
        color: fillColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: size * 0.45,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: tier == ArtMarkerSignal.legendary
          ? Icon(
              Icons.auto_awesome,
              size: size * 0.6,
              color: Colors.black.withValues(alpha: 0.78),
            )
          : null,
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
    return _CubePalette(
      top: _lighten(color, 0.24),
      topAccent: _lighten(color, 0.36),
      left: _darken(color, 0.12),
      right: _darken(color, 0.2),
      frontLeft: _darken(color, 0.24),
      frontRight: _darken(color, 0.28),
      base: color.withValues(alpha: 0.45),
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
    ) * 0.92;

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
