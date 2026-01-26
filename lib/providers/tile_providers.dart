import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/map_style_service.dart';
import '../utils/grid_utils.dart';
import 'themeprovider.dart';

/// Lightweight provider kept for backward compatibility with existing map
/// flows (grid snapping + theme-aware map style selection).
///
/// MapLibre handles tile fetching/caching natively, so the previous FlutterMap
/// tile-layer provider is no longer needed.
class TileProviders with WidgetsBindingObserver {
  final ThemeProvider themeProvider;

  TileProviders(this.themeProvider) {
    WidgetsBinding.instance.addObserver(this);
    _updateThemeMode();
    themeProvider.addListener(_updateThemeMode);
  }

  @override
  void didChangePlatformBrightness() {
    _updateThemeMode();
  }

  void _updateThemeMode() {
    final brightness = PlatformDispatcher.instance.platformBrightness;
    if (themeProvider.themeMode == ThemeMode.system) {
      Future.microtask(() {
        themeProvider.setThemeMode(
          brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        );
      });
    }
  }

  /// MapLibre style asset for the current theme.
  String mapStyleAsset({required bool isDarkMode}) {
    return MapStyleService.primaryStyleRef(isDarkMode: isDarkMode);
  }

  /// Snap a map position to the underlying isometric grid for a given grid level.
  LatLng snapToVisibleGrid(LatLng position, double cameraZoom) {
    return GridUtils.snapToVisibleGrid(position, cameraZoom);
  }

  LatLng snapToGrid(LatLng position, double gridLevel) {
    return GridUtils.snapToGrid(position, gridLevel);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    themeProvider.removeListener(_updateThemeMode);
  }
}
