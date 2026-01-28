import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../utils/app_color_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Camera-Relative 3D Cube Marker Painter
//
// Renders a true 3D cube that responds to map camera bearing and pitch.
// All 6 faces are rendered with proper depth sorting based on view angle.
// ─────────────────────────────────────────────────────────────────────────────

/// Design token: Default cube marker size at zoom 15.
/// Reduced by ~12% from the static marker size (46 → 40).
class RotatableCubeTokens {
  RotatableCubeTokens._();

  /// Base cube size at zoom level 15 (logical pixels).
  static const double baseSizeAtZoom15 = 40.0;

  /// Minimum size clamp for very low zoom levels.
  static const double minSize = 24.0;

  /// Maximum size clamp for very high zoom levels.
  static const double maxSize = 64.0;

  /// Scale factor per zoom level delta from 15.
  static const double zoomScaleFactor = 0.15;

  /// Computes cube size based on current zoom level.
  static double sizeForZoom(double zoom) {
    final delta = zoom - 15.0;
    final scale = 1.0 + (delta * zoomScaleFactor);
    return (baseSizeAtZoom15 * scale).clamp(minSize, maxSize);
  }
}

/// Represents the visibility state of each cube face.
@immutable
class CubeFaceVisibility {
  const CubeFaceVisibility({
    required this.top,
    required this.bottom,
    required this.front,
    required this.back,
    required this.left,
    required this.right,
  });

  final bool top;
  final bool bottom;
  final bool front;
  final bool back;
  final bool left;
  final bool right;

  /// Calculate which faces are visible based on camera bearing and pitch.
  ///
  /// [bearing]: Map bearing in degrees (0-360, 0 = north up)
  /// [pitch]: Map pitch/tilt in degrees (0-60, 0 = top-down, 60 = horizon)
  factory CubeFaceVisibility.fromCamera({
    required double bearing,
    required double pitch,
  }) {
    // Normalize bearing to 0-360
    final normalizedBearing = (bearing % 360 + 360) % 360;

    // Convert to radians for trig
    final bearingRad = normalizedBearing * (math.pi / 180);
    final pitchRad = pitch * (math.pi / 180);

    // Camera look direction (unit vector pointing from camera to scene)
    // In our coordinate system:
    // - X points East (right when bearing = 0)
    // - Y points North (up when bearing = 0)
    // - Z points up (out of screen)
    final lookX = math.sin(bearingRad) * math.cos(pitchRad);
    final lookY = math.cos(bearingRad) * math.cos(pitchRad);
    final lookZ = -math.sin(pitchRad); // negative because we look down

    // Face normals in world space (cube is axis-aligned in world)
    // A face is visible if dot(normal, lookDir) < 0 (facing towards camera)
    const epsilon = 0.01;

    return CubeFaceVisibility(
      top: lookZ < -epsilon, // top faces up (+Z), visible when looking down
      bottom: lookZ > epsilon, // bottom faces down (-Z)
      front: lookY > epsilon, // front faces south (-Y in world coords)
      back: lookY < -epsilon, // back faces north (+Y)
      left: lookX > epsilon, // left faces west (-X)
      right: lookX < -epsilon, // right faces east (+X)
    );
  }

  /// Returns the visible face count (for debugging).
  int get visibleCount =>
      (top ? 1 : 0) +
      (bottom ? 1 : 0) +
      (front ? 1 : 0) +
      (back ? 1 : 0) +
      (left ? 1 : 0) +
      (right ? 1 : 0);
}

/// Identifies each face of the cube.
enum CubeFace {
  top,
  bottom,
  front,
  back,
  left,
  right,
}

/// A face with its computed depth for z-sorting.
@immutable
class _FaceWithDepth {
  const _FaceWithDepth(this.face, this.depth);
  final CubeFace face;
  final double depth; // lower = further from camera = draw first
}

/// Color palette for the rotatable cube.
@immutable
class RotatableCubePalette {
  const RotatableCubePalette({
    required this.top,
    required this.bottom,
    required this.front,
    required this.back,
    required this.left,
    required this.right,
    required this.topAccent,
    required this.edge,
  });

  final Color top;
  final Color bottom;
  final Color front;
  final Color back;
  final Color left;
  final Color right;
  final Color topAccent;
  final Color edge;

  /// Creates a palette from a base color with lighting-aware shading.
  ///
  /// [lightBearing]: Direction the light comes from (degrees, 0 = north).
  /// Defaults to 315 (northwest, standard 3D lighting convention).
  factory RotatableCubePalette.fromBase(
    Color baseColor, {
    required Color edgeColor,
    double lightBearing = 315.0,
  }) {
    final hsl = HSLColor.fromColor(baseColor);
    final vibrant =
        hsl.withSaturation((hsl.saturation * 1.15).clamp(0.0, 1.0)).toColor();

    // Light direction affects which faces are bright vs shadowed
    final lightRad = lightBearing * (math.pi / 180);
    final lightX = math.sin(lightRad);
    final lightY = math.cos(lightRad);

    // Dot products for directional lighting
    final frontLight = -lightY; // front faces -Y
    final backLight = lightY; // back faces +Y
    final leftLight = -lightX; // left faces -X
    final rightLight = lightX; // right faces +X

    Color applyLight(double dotProduct, double baseDarken) {
      final lightFactor = (dotProduct + 1) / 2; // normalize to 0-1
      final darken = baseDarken - (lightFactor * 0.15);
      return _adjustLightness(vibrant, -darken);
    }

    return RotatableCubePalette(
      // Top always brightest (overhead light component)
      top: _adjustLightness(vibrant, 0.22),
      // Bottom always darkest
      bottom: _adjustLightness(vibrant, -0.35),
      // Side faces based on light direction
      front: applyLight(frontLight, 0.18),
      back: applyLight(backLight, 0.22),
      left: applyLight(leftLight, 0.08),
      right: applyLight(rightLight, 0.15),
      // Accent for icon on top
      topAccent: _saturate(_adjustLightness(vibrant, 0.12), 0.1),
      // Edge color
      edge: edgeColor.withValues(alpha: 0.35),
    );
  }

  static Color _adjustLightness(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  static Color _saturate(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final saturation = (hsl.saturation + amount).clamp(0.0, 1.0);
    return hsl.withSaturation(saturation).toColor();
  }
}

/// 3D vertex in cube-local coordinates.
/// Cube is centered at origin, extends from -0.5 to +0.5 on each axis.
@immutable
class _Vertex3 {
  const _Vertex3(this.x, this.y, this.z);
  final double x, y, z;

  _Vertex3 operator +(_Vertex3 other) =>
      _Vertex3(x + other.x, y + other.y, z + other.z);

  _Vertex3 operator *(double s) => _Vertex3(x * s, y * s, z * s);
}

/// Projects 3D world coordinates to 2D screen coordinates with camera transform.
class _CubeProjector {
  _CubeProjector({
    required this.bearing,
    required this.pitch,
    required this.size,
  }) {
    // Normalize and convert to radians
    _bearingRad = ((bearing % 360 + 360) % 360) * (math.pi / 180);
    _pitchRad = pitch.clamp(0.0, 85.0) * (math.pi / 180);

    // Pre-compute sin/cos for rotation
    _cosBearing = math.cos(_bearingRad);
    _sinBearing = math.sin(_bearingRad);
    _cosPitch = math.cos(_pitchRad);
    _sinPitch = math.sin(_pitchRad);
  }

  final double bearing;
  final double pitch;
  final double size;

  late final double _bearingRad;
  late final double _pitchRad;
  late final double _cosBearing;
  late final double _sinBearing;
  late final double _cosPitch;
  late final double _sinPitch;

  /// Projects a 3D vertex to 2D screen coordinates.
  ///
  /// The cube rotates *opposite* to bearing so it appears fixed in world space.
  /// Pitch creates a perspective tilt effect.
  Offset project(_Vertex3 v) {
    // Rotate around Z axis (opposite to bearing for world-fixed appearance)
    // When map rotates clockwise (bearing increases), cube appears to rotate counter-clockwise
    final rotX = v.x * _cosBearing + v.y * _sinBearing;
    final rotY = -v.x * _sinBearing + v.y * _cosBearing;
    final rotZ = v.z;

    // Apply pitch: rotate around X axis
    // This makes the cube tilt towards/away from viewer based on camera pitch
    final pitchedY = rotY * _cosPitch - rotZ * _sinPitch;
    final pitchedZ = rotY * _sinPitch + rotZ * _cosPitch;

    // Simple orthographic projection with mild perspective
    // Perspective factor based on depth (objects further away appear smaller)
    const perspectiveStrength = 0.15;
    final perspectiveFactor = 1.0 + (pitchedY * perspectiveStrength);

    // Scale to screen size and center
    final screenX = (rotX * perspectiveFactor * size * 0.7) + (size / 2);
    final screenY = (-pitchedZ * perspectiveFactor * size * 0.7) + (size / 2);

    return Offset(screenX, screenY);
  }

  /// Compute depth value for a face (average Z of projected vertices).
  /// Used for z-sorting: lower depth = further = draw first.
  double faceDepth(List<_Vertex3> vertices) {
    double totalZ = 0;
    for (final v in vertices) {
      // Transform and get depth
      final rotY = -v.x * _sinBearing + v.y * _cosBearing;
      final rotZ = v.z;
      final pitchedY = rotY * _cosPitch - rotZ * _sinPitch;
      totalZ += pitchedY; // depth along view axis
    }
    return totalZ / vertices.length;
  }
}

/// The 8 vertices of a unit cube centered at origin.
class _CubeVertices {
  _CubeVertices._();

  static const _Vertex3 frontBottomLeft = _Vertex3(-0.5, 0.5, -0.5);
  static const _Vertex3 frontBottomRight = _Vertex3(0.5, 0.5, -0.5);
  static const _Vertex3 frontTopLeft = _Vertex3(-0.5, 0.5, 0.5);
  static const _Vertex3 frontTopRight = _Vertex3(0.5, 0.5, 0.5);
  static const _Vertex3 backBottomLeft = _Vertex3(-0.5, -0.5, -0.5);
  static const _Vertex3 backBottomRight = _Vertex3(0.5, -0.5, -0.5);
  static const _Vertex3 backTopLeft = _Vertex3(-0.5, -0.5, 0.5);
  static const _Vertex3 backTopRight = _Vertex3(0.5, -0.5, 0.5);

  /// Returns the 4 vertices for each face (counter-clockwise winding).
  static List<_Vertex3> verticesForFace(CubeFace face) {
    switch (face) {
      case CubeFace.top:
        return const [
          backTopLeft,
          backTopRight,
          frontTopRight,
          frontTopLeft,
        ];
      case CubeFace.bottom:
        return const [
          frontBottomLeft,
          frontBottomRight,
          backBottomRight,
          backBottomLeft,
        ];
      case CubeFace.front:
        return const [
          frontTopLeft,
          frontTopRight,
          frontBottomRight,
          frontBottomLeft,
        ];
      case CubeFace.back:
        return const [
          backTopRight,
          backTopLeft,
          backBottomLeft,
          backBottomRight,
        ];
      case CubeFace.left:
        return const [
          backTopLeft,
          frontTopLeft,
          frontBottomLeft,
          backBottomLeft,
        ];
      case CubeFace.right:
        return const [
          frontTopRight,
          backTopRight,
          backBottomRight,
          frontBottomRight,
        ];
    }
  }
}

/// Style configuration for the rotatable cube.
@immutable
class RotatableCubeStyle {
  const RotatableCubeStyle({
    required this.shadowColor,
    required this.iconBackgroundColor,
    required this.iconShadowColor,
    required this.highlightColor,
    this.edgeWidth = 0.018,
    this.highlightWidth = 0.012,
  });

  final Color shadowColor;
  final Color iconBackgroundColor;
  final Color iconShadowColor;
  final Color highlightColor;
  final double edgeWidth;
  final double highlightWidth;

  factory RotatableCubeStyle.fromScheme({
    required ColorScheme scheme,
    required bool isDark,
    required Color baseColor,
  }) {
    final shadow = scheme.shadow;
    return RotatableCubeStyle(
      shadowColor: shadow,
      iconBackgroundColor:
          scheme.surface.withValues(alpha: isDark ? 0.92 : 0.96),
      iconShadowColor: shadow.withValues(alpha: 0.16),
      highlightColor: AppColorUtils.shiftLightness(
        baseColor,
        isDark ? 0.28 : 0.20,
      ).withValues(alpha: 0.30),
    );
  }
}

/// CustomPainter that renders a 3D cube with camera-relative rotation.
///
/// The cube responds to map camera bearing and pitch:
/// - Bearing rotates the cube around its vertical axis (Z)
/// - Pitch tilts the cube towards/away from the viewer
///
/// All 6 faces are properly depth-sorted and only visible faces are rendered.
class RotatableCubePainter extends CustomPainter {
  const RotatableCubePainter({
    required this.palette,
    required this.style,
    required this.bearing,
    required this.pitch,
    this.icon,
    this.label,
    this.labelStyle,
  });

  final RotatableCubePalette palette;
  final RotatableCubeStyle style;

  /// Map bearing in degrees (0-360, 0 = north up).
  final double bearing;

  /// Map pitch in degrees (0-60, 0 = top-down).
  final double pitch;

  /// Icon to display on top face.
  final IconData? icon;

  /// Label text (for clusters).
  final String? label;

  /// Style for label text.
  final TextStyle? labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final cubeSize = math.min(size.width, size.height);
    final projector = _CubeProjector(
      bearing: bearing,
      pitch: pitch,
      size: cubeSize,
    );

    // Calculate face visibility
    final visibility = CubeFaceVisibility.fromCamera(
      bearing: bearing,
      pitch: pitch,
    );

    // Collect visible faces with their depths
    final visibleFaces = <_FaceWithDepth>[];

    void addIfVisible(CubeFace face, bool isVisible) {
      if (!isVisible) return;
      final vertices = _CubeVertices.verticesForFace(face);
      final depth = projector.faceDepth(vertices);
      visibleFaces.add(_FaceWithDepth(face, depth));
    }

    addIfVisible(CubeFace.top, visibility.top);
    addIfVisible(CubeFace.bottom, visibility.bottom);
    addIfVisible(CubeFace.front, visibility.front);
    addIfVisible(CubeFace.back, visibility.back);
    addIfVisible(CubeFace.left, visibility.left);
    addIfVisible(CubeFace.right, visibility.right);

    // Sort by depth (painter's algorithm: draw furthest first)
    visibleFaces.sort((a, b) => a.depth.compareTo(b.depth));

    // Draw drop shadow
    _drawDropShadow(canvas, size, projector);

    // Draw faces in depth order
    for (final faceData in visibleFaces) {
      _drawFace(canvas, projector, faceData.face);
    }

    // Draw edges for visible faces
    _drawEdges(canvas, projector, visibleFaces);

    // Draw icon/label on top face if visible
    if (visibility.top && (icon != null || label != null)) {
      _drawTopFaceContent(canvas, size, projector);
    }
  }

  Color _colorForFace(CubeFace face) {
    switch (face) {
      case CubeFace.top:
        return palette.top;
      case CubeFace.bottom:
        return palette.bottom;
      case CubeFace.front:
        return palette.front;
      case CubeFace.back:
        return palette.back;
      case CubeFace.left:
        return palette.left;
      case CubeFace.right:
        return palette.right;
    }
  }

  void _drawDropShadow(Canvas canvas, Size size, _CubeProjector projector) {
    // Project bottom face center for shadow position
    final bottomCenter = projector.project(const _Vertex3(0, 0, -0.5));
    final shadowSize = size.width * 0.5;

    // Elliptical shadow
    canvas.save();
    canvas.translate(bottomCenter.dx, bottomCenter.dy + size.height * 0.1);
    canvas.scale(1.0, 0.35);
    canvas.translate(-bottomCenter.dx, -(bottomCenter.dy + size.height * 0.1));

    final shadowRect = Rect.fromCenter(
      center: Offset(bottomCenter.dx, bottomCenter.dy + size.height * 0.1),
      width: shadowSize,
      height: shadowSize,
    );

    final shadowGradient = ui.Gradient.radial(
      shadowRect.center,
      shadowSize / 2,
      [
        style.shadowColor.withValues(alpha: 0.22),
        style.shadowColor.withValues(alpha: 0.08),
        Colors.transparent,
      ],
      const [0.0, 0.6, 1.0],
    );

    canvas.drawOval(shadowRect, Paint()..shader = shadowGradient);
    canvas.restore();
  }

  void _drawFace(Canvas canvas, _CubeProjector projector, CubeFace face) {
    final vertices = _CubeVertices.verticesForFace(face);
    final projected = vertices.map(projector.project).toList();

    final path = Path()
      ..moveTo(projected[0].dx, projected[0].dy)
      ..lineTo(projected[1].dx, projected[1].dy)
      ..lineTo(projected[2].dx, projected[2].dy)
      ..lineTo(projected[3].dx, projected[3].dy)
      ..close();

    final baseColor = _colorForFace(face);

    // Gradient for polish
    final bounds = path.getBounds();
    final gradient = ui.Gradient.linear(
      bounds.topCenter,
      bounds.bottomCenter,
      [baseColor, baseColor.withValues(alpha: 0.88)],
    );

    canvas.drawPath(path, Paint()..shader = gradient);
  }

  void _drawEdges(
    Canvas canvas,
    _CubeProjector projector,
    List<_FaceWithDepth> visibleFaces,
  ) {
    final edgePaint = Paint()
      ..color = palette.edge
      ..strokeWidth = projector.size * style.edgeWidth
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Draw outline for each visible face
    for (final faceData in visibleFaces) {
      final vertices = _CubeVertices.verticesForFace(faceData.face);
      final projected = vertices.map(projector.project).toList();

      final path = Path()
        ..moveTo(projected[0].dx, projected[0].dy)
        ..lineTo(projected[1].dx, projected[1].dy)
        ..lineTo(projected[2].dx, projected[2].dy)
        ..lineTo(projected[3].dx, projected[3].dy)
        ..close();

      canvas.drawPath(path, edgePaint);
    }

    // Draw highlight on top face edges if visible
    if (visibleFaces.any((f) => f.face == CubeFace.top)) {
      final highlightPaint = Paint()
        ..color = style.highlightColor
        ..strokeWidth = projector.size * style.highlightWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final topVertices = _CubeVertices.verticesForFace(CubeFace.top);
      final topProjected = topVertices.map(projector.project).toList();

      // Highlight back-left to front-left edge
      canvas.drawLine(topProjected[0], topProjected[3], highlightPaint);
    }
  }

  void _drawTopFaceContent(
    Canvas canvas,
    Size size,
    _CubeProjector projector,
  ) {
    // Get projected top face vertices
    final topVertices = _CubeVertices.verticesForFace(CubeFace.top);
    final topProjected = topVertices.map(projector.project).toList();

    // Calculate center of projected top face
    final topCenter = Offset(
      (topProjected[0].dx +
              topProjected[1].dx +
              topProjected[2].dx +
              topProjected[3].dx) /
          4,
      (topProjected[0].dy +
              topProjected[1].dy +
              topProjected[2].dy +
              topProjected[3].dy) /
          4,
    );

    // Calculate approximate face size for icon scaling
    final faceWidth = (topProjected[1] - topProjected[0]).distance;
    final iconRadius = faceWidth * 0.35;

    // Draw icon background circle (elliptical to match perspective)
    final circleShadowPaint = Paint()
      ..color = style.iconShadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawOval(
      Rect.fromCenter(
        center: topCenter + const Offset(0, 1.5),
        width: iconRadius * 2,
        height: iconRadius * 1.5,
      ),
      circleShadowPaint,
    );

    final circlePaint = Paint()..color = style.iconBackgroundColor;
    canvas.drawOval(
      Rect.fromCenter(
        center: topCenter,
        width: iconRadius * 2,
        height: iconRadius * 1.5,
      ),
      circlePaint,
    );

    // Border around icon circle
    final borderPaint = Paint()
      ..color = palette.topAccent.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.02;
    canvas.drawOval(
      Rect.fromCenter(
        center: topCenter,
        width: iconRadius * 2,
        height: iconRadius * 1.5,
      ),
      borderPaint,
    );

    // Draw icon or label
    final TextPainter glyphPainter;
    if (icon != null) {
      glyphPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon!.codePoint),
          style: TextStyle(
            fontSize: faceWidth * 0.4,
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
          style: labelStyle?.copyWith(fontSize: faceWidth * 0.35),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
    }
    glyphPainter.layout();

    final glyphOffset = Offset(
      topCenter.dx - glyphPainter.width / 2,
      topCenter.dy - glyphPainter.height / 2 - size.height * 0.01,
    );
    glyphPainter.paint(canvas, glyphOffset);
  }

  @override
  bool shouldRepaint(covariant RotatableCubePainter oldDelegate) {
    return oldDelegate.bearing != bearing ||
        oldDelegate.pitch != pitch ||
        oldDelegate.palette != palette ||
        oldDelegate.style != style ||
        oldDelegate.icon != icon ||
        oldDelegate.label != label;
  }
}

/// A widget that renders a rotatable 3D cube marker.
///
/// This widget is designed to be placed in a Flutter overlay on top of the map,
/// with its position synced to the marker's lat/lng via `toScreenLocation`.
class RotatableCubeMarker extends StatelessWidget {
  const RotatableCubeMarker({
    super.key,
    required this.baseColor,
    required this.icon,
    required this.bearing,
    required this.pitch,
    this.size,
    this.zoom = 15.0,
    this.isSelected = false,
    this.isHovered = false,
  });

  final Color baseColor;
  final IconData icon;

  /// Map bearing in degrees (0-360).
  final double bearing;

  /// Map pitch in degrees (0-60).
  final double pitch;

  /// Override size. If null, computed from [zoom].
  final double? size;

  /// Current map zoom level (used to compute size if [size] is null).
  final double zoom;

  final bool isSelected;
  final bool isHovered;

  static const Duration _animationDuration = Duration(milliseconds: 140);
  static const double _selectedScale = 1.08;
  static const double _hoveredScale = 1.04;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cubeSize = size ?? RotatableCubeTokens.sizeForZoom(zoom);
    final palette = RotatableCubePalette.fromBase(
      baseColor,
      edgeColor: scheme.shadow.withValues(alpha: 0.35),
    );
    final style = RotatableCubeStyle.fromScheme(
      scheme: scheme,
      isDark: isDark,
      baseColor: baseColor,
    );

    final scale = isSelected
        ? _selectedScale
        : isHovered
            ? _hoveredScale
            : 1.0;

    return AnimatedScale(
      scale: scale,
      duration: _animationDuration,
      curve: Curves.easeOutCubic,
      child: SizedBox(
        width: cubeSize,
        height: cubeSize,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: RotatableCubePainter(
              palette: palette,
              style: style,
              bearing: bearing,
              pitch: pitch,
              icon: icon,
            ),
          ),
        ),
      ),
    );
  }
}

/// Extension for computing camera-relative transforms.
extension CameraRotationUtils on double {
  /// Converts degrees to radians.
  double get toRadians => this * (math.pi / 180);

  /// Normalizes bearing to 0-360 range.
  double get normalizedBearing => (this % 360 + 360) % 360;
}
