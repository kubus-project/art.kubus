import 'package:flutter/material.dart';

class MapLibreStyleUtils {
  MapLibreStyleUtils._();

  /// MapLibre-native friendly hex color (no alpha): `#RRGGBB`.
  static String hexRgb(Color color) {
    int clamp255(double value) => value.round().clamp(0, 255);
    final r = clamp255(color.r * 255.0);
    final g = clamp255(color.g * 255.0);
    final b = clamp255(color.b * 255.0);
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
  }
}

