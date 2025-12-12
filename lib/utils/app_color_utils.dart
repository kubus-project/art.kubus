import 'package:flutter/material.dart';

class AppColorUtils {
  static Color shiftLightness(Color color, double delta) {
    final hsl = HSLColor.fromColor(color);
    final next = (hsl.lightness + delta).clamp(0.0, 1.0).toDouble();
    return hsl.withLightness(next).toColor();
  }
}

