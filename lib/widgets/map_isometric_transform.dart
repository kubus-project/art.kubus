import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Applies a lightweight 3D transform to emulate an isometric-like map view.
///
/// `flutter_map` is a 2D map renderer (no native camera tilt). This widget uses
/// a perspective + X-axis rotation to achieve a consistent, token-friendly
/// "isometric" feel without swapping map frameworks.
class MapIsometricTransform extends StatelessWidget {
  const MapIsometricTransform({
    super.key,
    required this.enabled,
    required this.child,
    this.tiltDegrees = 52,
    this.perspective = 0.0012,
    this.verticalScale = 0.92,
  });

  final bool enabled;
  final Widget child;

  /// Visual tilt for the isometric effect. (Approx. 45–60 is a good range.)
  final double tiltDegrees;

  /// Perspective strength. Smaller values are flatter; larger values are more 3D.
  final double perspective;

  /// Additional Y scaling to keep the map readable after tilt.
  final double verticalScale;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    final tiltRadians = tiltDegrees * math.pi / 180.0;

    return ClipRect(
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, perspective)
          ..rotateX(tiltRadians)
          ..scaleByDouble(1.0, verticalScale, 1.0, 1.0),
        child: child,
      ),
    );
  }
}
