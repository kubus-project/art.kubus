import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Applies a lightweight 3D transform to emulate an isometric-like map view.
///
/// `flutter_map` is a 2D map renderer (no native camera tilt). This widget uses
/// a CSS-equivalent perspective + X-axis rotation + scale to achieve a stable,
/// fullscreen "isometric" feel without swapping map frameworks.
///
/// Website reference:
/// `perspective(5000px) rotateX(54.736deg) scale(1.2)`
class MapIsometricTransform extends StatelessWidget {
  static const double defaultTiltDegrees = 54.736;
  static const double defaultPerspectivePx = 5000;
  static const double defaultScale = 1.2;

  const MapIsometricTransform({
    super.key,
    required this.enabled,
    required this.child,
    this.tiltDegrees = defaultTiltDegrees,
    this.perspectivePx = defaultPerspectivePx,
    this.scale = defaultScale,
    this.alignment = Alignment.bottomCenter,
  });

  final bool enabled;
  final Widget child;

  /// Visual tilt for the isometric effect (matches web: `rotateX(54.736deg)`).
  final double tiltDegrees;

  /// Perspective distance in CSS pixels (matches web: `perspective(5000px)`).
  final double perspectivePx;

  /// Uniform scale (matches web: `scale(1.2)`).
  final double scale;

  /// Anchor point for the transform.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    final tiltRadians = tiltDegrees * math.pi / 180.0;
    final perspectiveDistance =
        perspectivePx.isFinite && perspectivePx.abs() > 0 ? perspectivePx.abs() : defaultPerspectivePx;

    // CSS `perspective(d)` maps to m34 = -1/d.
    final m34 = -1.0 / perspectiveDistance;
    final s = scale.isFinite ? scale.clamp(0.4, 3.0).toDouble() : defaultScale;

    return Transform(
      alignment: alignment,
      transform: Matrix4.identity()
        ..setEntry(3, 2, m34)
        ..rotateX(tiltRadians)
        ..scaleByDouble(s, s, 1.0, 1.0),
      child: child,
    );
  }
}

