import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/art_marker.dart';
import '../utils/app_color_utils.dart';
import '../utils/design_tokens.dart';
import '../utils/kubus_color_roles.dart';

@immutable
class CubeMarkerStyle {
  static const double selectedScale = 1.08;
  static const double hoveredScale = 1.04;
  static const Duration animationDuration = Duration(milliseconds: 140);

  const CubeMarkerStyle({
    required this.shadowColor,
    required this.iconBackgroundColor,
    required this.iconShadowColor,
    required this.edgeColor,
    required this.highlightColor,
  });

  final Color shadowColor;
  final Color iconBackgroundColor;
  final Color iconShadowColor;
  final Color edgeColor;
  final Color highlightColor;

  factory CubeMarkerStyle.resolve(
    BuildContext context, {
    required Color baseColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CubeMarkerStyle.fromScheme(
      scheme: scheme,
      isDark: isDark,
      baseColor: baseColor,
    );
  }

  factory CubeMarkerStyle.fromScheme({
    required ColorScheme scheme,
    required bool isDark,
    required Color baseColor,
  }) {
    final shadow = scheme.shadow;

    return CubeMarkerStyle(
      shadowColor: shadow,
      iconBackgroundColor: scheme.surface.withValues(alpha: isDark ? 0.92 : 0.96),
      iconShadowColor: shadow.withValues(alpha: 0.16),
      edgeColor: shadow.withValues(alpha: 0.35),
      highlightColor: AppColorUtils.shiftLightness(
        baseColor,
        isDark ? 0.28 : 0.20,
      ).withValues(alpha: 0.30),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is CubeMarkerStyle &&
            other.shadowColor == shadowColor &&
            other.iconBackgroundColor == iconBackgroundColor &&
            other.iconShadowColor == iconShadowColor &&
            other.edgeColor == edgeColor &&
            other.highlightColor == highlightColor);
  }

  @override
  int get hashCode => Object.hash(
        shadowColor,
        iconBackgroundColor,
        iconShadowColor,
        edgeColor,
        highlightColor,
      );
}

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
    this.isSelected = false,
    this.isHovered = false,
  });

  final ArtMarker marker;
  final Color baseColor;
  final IconData icon;
  final double size;
  final bool glow;
  final bool isSelected;
  final bool isHovered;

  @override
  Widget build(BuildContext context) {
    final style = CubeMarkerStyle.resolve(context, baseColor: baseColor);
    final tier = marker.signalTier;
    final bool showGlow = glow ||
        isSelected ||
        isHovered ||
        tier == ArtMarkerSignal.featured ||
        tier == ArtMarkerSignal.legendary;
    final double scale = isSelected
        ? CubeMarkerStyle.selectedScale
        : isHovered
            ? CubeMarkerStyle.hoveredScale
            : 1.0;

    final _CubePalette palette = _CubePalette.fromBase(
      baseColor,
      edgeColor: style.edgeColor,
    );
    // Cube body occupies 70% height, rest is for shadow/spacing
    final double cubeBodyHeight = size * 0.85;
    final double totalHeight = size * 1.15;

    return AnimatedScale(
      scale: scale,
      duration: CubeMarkerStyle.animationDuration,
      curve: Curves.easeOutCubic,
      child: SizedBox(
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
                transform:
                    Matrix4.identity()..scaleByDouble(1.0, 0.35, 1.0, 1.0),
                child: Container(
                  width: size * 0.72,
                  height: size * 0.72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        style.shadowColor.withValues(
                          alpha: showGlow ? 0.32 : 0.20,
                        ),
                        style.shadowColor.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Optional colored glow beneath cube
            if (showGlow)
              Positioned(
                bottom: size * 0.02,
                child: Transform(
                  alignment: Alignment.center,
                  transform:
                      Matrix4.identity()..scaleByDouble(1.0, 0.32, 1.0, 1.0),
                  child: Container(
                    width: size * 0.9,
                    height: size * 0.9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          baseColor.withValues(alpha: isSelected ? 0.48 : 0.40),
                          baseColor.withValues(alpha: isSelected ? 0.18 : 0.14),
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
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size(size * 0.88, cubeBodyHeight),
                  painter: _IsometricCubePainter(
                    palette: palette,
                    style: style,
                    icon: icon,
                    label: null,
                    labelStyle: null,
                  ),
                ),
              ),
            ),
            // Signal tier indicator (subtle ring around base)
            if (tier != ArtMarkerSignal.subtle)
              Positioned(
                bottom: size * 0.04,
                child: _SignalIndicator(
                  tier: tier,
                  baseColor: baseColor,
                  size: size * 0.68,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A cube marker variant that renders an aggregated cluster count on the top face.
class ArtMarkerClusterCube extends StatelessWidget {
  const ArtMarkerClusterCube({
    super.key,
    required this.count,
    required this.baseColor,
    this.size = 70,
    this.isSelected = false,
    this.isHovered = false,
  });

  final int count;
  final Color baseColor;
  final double size;
  final bool isSelected;
  final bool isHovered;

  @override
  Widget build(BuildContext context) {
    final style = CubeMarkerStyle.resolve(context, baseColor: baseColor);
    final bool showGlow = isSelected || isHovered || count >= 10;
    final double scale = isSelected
        ? CubeMarkerStyle.selectedScale
        : isHovered
            ? CubeMarkerStyle.hoveredScale
            : 1.0;

    final palette = _CubePalette.fromBase(baseColor, edgeColor: style.edgeColor);
    final cubeBodyHeight = size * 0.85;
    final totalHeight = size * 1.15;
    final label = count > 99 ? '99+' : '$count';
    final labelStyle = KubusTextStyles.badgeCount.copyWith(
      color: palette.topAccent,
    );

    return AnimatedScale(
      scale: scale,
      duration: CubeMarkerStyle.animationDuration,
      curve: Curves.easeOutCubic,
      child: SizedBox(
        width: size,
        height: totalHeight,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              bottom: 0,
              child: Transform(
                alignment: Alignment.center,
                transform:
                    Matrix4.identity()..scaleByDouble(1.0, 0.35, 1.0, 1.0),
                child: Container(
                  width: size * 0.72,
                  height: size * 0.72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        style.shadowColor.withValues(alpha: showGlow ? 0.30 : 0.18),
                        style.shadowColor.withValues(alpha: 0.07),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            if (showGlow)
              Positioned(
                bottom: size * 0.02,
                child: Transform(
                  alignment: Alignment.center,
                  transform:
                      Matrix4.identity()..scaleByDouble(1.0, 0.32, 1.0, 1.0),
                  child: Container(
                    width: size * 0.9,
                    height: size * 0.9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          baseColor.withValues(alpha: 0.42),
                          baseColor.withValues(alpha: 0.14),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: size * 0.12,
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size(size * 0.88, cubeBodyHeight),
                  painter: _IsometricCubePainter(
                    palette: palette,
                    style: style,
                    icon: null,
                    label: label,
                    labelStyle: labelStyle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IsometricCubePainter extends CustomPainter {
  const _IsometricCubePainter({
    required this.palette,
    required this.style,
    required this.icon,
    required this.label,
    required this.labelStyle,
  });

  final _CubePalette palette;
  final CubeMarkerStyle style;
  final IconData? icon;
  final String? label;
  final TextStyle? labelStyle;

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
        ..color = style.shadowColor.withValues(alpha: 0.18)
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
      ..color = style.highlightColor
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
    _drawGlyphOnTopFace(canvas, size, cube);
  }

  void _drawGlyphOnTopFace(Canvas canvas, Size size, _ProjectedCube cube) {
    assert(icon != null || (label != null && labelStyle != null));
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
      ..color = style.iconShadowColor
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
      ..color = style.iconBackgroundColor;
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

    final TextPainter glyphPainter;
    if (icon != null) {
      glyphPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon!.codePoint),
          style: TextStyle(
            fontSize: size.width * 0.28,
            fontFamily: icon!.fontFamily,
            package: icon!.fontPackage,
            color: palette.topAccent,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
    } else {
      glyphPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: labelStyle?.copyWith(
            fontSize: size.width * 0.22,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
    }
    glyphPainter.layout();

    // Position glyph in center of top face
    final glyphOffset = Offset(
      topCenter.dx - glyphPainter.width / 2,
      topCenter.dy - glyphPainter.height / 2 - size.height * 0.015,
    );
    glyphPainter.paint(canvas, glyphOffset);
  }

  @override
  bool shouldRepaint(covariant _IsometricCubePainter oldDelegate) {
    return oldDelegate.palette != palette ||
        oldDelegate.icon != icon ||
        oldDelegate.label != label ||
        oldDelegate.style != style;
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
    final roles = KubusColorRoles.of(context);

    switch (tier) {
      case ArtMarkerSignal.legendary:
        glowColor = roles.achievementGold;
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
      transform: Matrix4.identity()..scaleByDouble(1.0, 0.35, 1.0, 1.0),
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

  factory _CubePalette.fromBase(
    Color color, {
    required Color edgeColor,
  }) {
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
      edge: edgeColor.withValues(alpha: 0.35),
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

/// Renders the cube marker visuals into PNG bytes for MapLibre symbol icons.
///
/// This keeps marker rendering native (no Flutter widget markers on top of the
/// map) while preserving the exact Kubus cube styling.
class ArtMarkerCubeIconRenderer {
  static const double markerCubeSizeAtZoom15 = 46;
  static const double markerWidthAtZoom15 = 56;
  static const double markerHeightAtZoom15 = 72;

  static Future<Uint8List> renderMarkerPng({
    required Color baseColor,
    required IconData icon,
    required ArtMarkerSignal tier,
    required ColorScheme scheme,
    required KubusColorRoles roles,
    required bool isDark,
    bool forceGlow = false,
    double pixelRatio = 2.0,
  }) async {
    final style = CubeMarkerStyle.fromScheme(
      scheme: scheme,
      isDark: isDark,
      baseColor: baseColor,
    );

    final showGlow = forceGlow ||
        tier == ArtMarkerSignal.featured ||
        tier == ArtMarkerSignal.legendary;

    return _renderPng(
      width: markerWidthAtZoom15,
      height: markerHeightAtZoom15,
      pixelRatio: pixelRatio,
      paint: (canvas, size) {
        final cubeSize = markerCubeSizeAtZoom15;
        final cubeW = cubeSize;
        final cubeH = cubeSize * 1.15;
        final offset = Offset(
          (size.width - cubeW) / 2,
          (size.height - cubeH) / 2,
        );
        _paintCubeMarker(
          canvas,
          offset: offset,
          cubeSize: cubeSize,
          palette: _CubePalette.fromBase(baseColor, edgeColor: style.edgeColor),
          style: style,
          roles: roles,
          icon: icon,
          label: null,
          labelStyle: null,
          showGlow: showGlow,
          tier: tier,
          baseColor: baseColor,
          isSelected: forceGlow,
        );
      },
    );
  }

  static Future<Uint8List> renderClusterPng({
    required int count,
    required Color baseColor,
    required ColorScheme scheme,
    required bool isDark,
    double cubeSize = 54,
    double pixelRatio = 2.0,
  }) async {
    final style = CubeMarkerStyle.fromScheme(
      scheme: scheme,
      isDark: isDark,
      baseColor: baseColor,
    );
    final showGlow = count >= 10;
    final label = count > 99 ? '99+' : '$count';
    final palette = _CubePalette.fromBase(baseColor, edgeColor: style.edgeColor);
    final labelStyle = KubusTextStyles.badgeCount.copyWith(
      color: palette.topAccent,
    );

    final w = cubeSize;
    final h = cubeSize * 1.15;
    return _renderPng(
      width: w,
      height: h,
      pixelRatio: pixelRatio,
      paint: (canvas, _) {
        _paintCubeMarker(
          canvas,
          offset: Offset.zero,
          cubeSize: cubeSize,
          palette: palette,
          style: style,
          roles: null,
          icon: null,
          label: label,
          labelStyle: labelStyle,
          showGlow: showGlow,
          tier: ArtMarkerSignal.subtle,
          baseColor: baseColor,
          isSelected: false,
        );
      },
    );
  }

  static Future<Uint8List> _renderPng({
    required double width,
    required double height,
    required double pixelRatio,
    required void Function(Canvas canvas, Size logicalSize) paint,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final logicalSize = Size(width, height);

    final pr = pixelRatio.isFinite ? pixelRatio.clamp(1.0, 4.0).toDouble() : 2.0;
    canvas.scale(pr, pr);
    paint(canvas, logicalSize);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (width * pr).round(),
      (height * pr).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  static void _paintCubeMarker(
    Canvas canvas, {
    required Offset offset,
    required double cubeSize,
    required _CubePalette palette,
    required CubeMarkerStyle style,
    required Color baseColor,
    required bool showGlow,
    required ArtMarkerSignal tier,
    required bool isSelected,
    required KubusColorRoles? roles,
    required IconData? icon,
    required String? label,
    required TextStyle? labelStyle,
  }) {
    final width = cubeSize;
    final height = cubeSize * 1.15;

    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    final shadowCenter = Offset(width / 2, height);
    _paintRadialEllipse(
      canvas,
      center: shadowCenter,
      size: cubeSize * 0.72,
      color: style.shadowColor,
      alphaA: showGlow ? 0.32 : 0.20,
      alphaB: 0.08,
    );

    if (showGlow) {
      _paintRadialEllipse(
        canvas,
        center: Offset(width / 2, height - cubeSize * 0.02),
        size: cubeSize * 0.9,
        color: baseColor,
        alphaA: isSelected ? 0.48 : 0.40,
        alphaB: isSelected ? 0.18 : 0.14,
      );
    }

    final cubeBodyHeight = cubeSize * 0.85;
    final cubeW = cubeSize * 0.88;
    final cubeOffset = Offset((width - cubeW) / 2, height - cubeSize * 0.12 - cubeBodyHeight);

    canvas.save();
    canvas.translate(cubeOffset.dx, cubeOffset.dy);
    _IsometricCubePainter(
      palette: palette,
      style: style,
      icon: icon,
      label: label,
      labelStyle: labelStyle,
    ).paint(canvas, Size(cubeW, cubeBodyHeight));
    canvas.restore();

    if (tier != ArtMarkerSignal.subtle && roles != null) {
      final ringSize = cubeSize * 0.68;
      final ringCenter = Offset(width / 2, height - cubeSize * 0.04);
      _paintSignalRing(
        canvas,
        center: ringCenter,
        size: ringSize,
        tier: tier,
        baseColor: baseColor,
        roles: roles,
      );
    }

    canvas.restore();
  }

  static void _paintRadialEllipse(
    Canvas canvas, {
    required Offset center,
    required double size,
    required Color color,
    required double alphaA,
    required double alphaB,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0, 0.35);
    canvas.translate(-center.dx, -center.dy);

    final rect = Rect.fromCenter(center: center, width: size, height: size);
    final shader = ui.Gradient.radial(
      center,
      size / 2,
      [
        color.withValues(alpha: alphaA),
        color.withValues(alpha: alphaB),
        Colors.transparent,
      ],
      const [0.0, 0.55, 1.0],
    );
    canvas.drawOval(rect, Paint()..shader = shader);
    canvas.restore();
  }

  static void _paintSignalRing(
    Canvas canvas, {
    required Offset center,
    required double size,
    required ArtMarkerSignal tier,
    required Color baseColor,
    required KubusColorRoles roles,
  }) {
    Color glowColor;
    double opacity;
    double strokeWidth;
    double blur;

    switch (tier) {
      case ArtMarkerSignal.legendary:
        glowColor = roles.achievementGold;
        opacity = 0.7;
        strokeWidth = 2.5;
        blur = 8;
        break;
      case ArtMarkerSignal.featured:
        glowColor = baseColor;
        opacity = 0.55;
        strokeWidth = 1.5;
        blur = 4;
        break;
      case ArtMarkerSignal.active:
        glowColor = baseColor;
        opacity = 0.35;
        strokeWidth = 1.5;
        blur = 4;
        break;
      case ArtMarkerSignal.subtle:
        return;
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0, 0.35);
    canvas.translate(-center.dx, -center.dy);

    final rect = Rect.fromCenter(center: center, width: size, height: size);
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = glowColor.withValues(alpha: opacity),
    );
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = glowColor.withValues(alpha: opacity * 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );

    canvas.restore();
  }
}
