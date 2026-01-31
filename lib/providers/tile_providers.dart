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
    // NOTE: We no longer call _updateThemeMode() or set up a listener that
    // mutates ThemeProvider. This was causing an infinite rebuild loop:
    //   TileProviders listens → setThemeMode → notifyListeners → rebuild → repeat
    //
    // ThemeProvider already handles system brightness changes via its own
    // didChangePlatformBrightness() override and isDarkMode getter. Consumers
    // should query themeProvider.isDarkMode directly instead of relying on
    // TileProviders to force a mode change.
  }

  @override
  void didChangePlatformBrightness() {
    // No-op: ThemeProvider.didChangePlatformBrightness already handles this.
    // We keep the observer registration for potential future use (e.g., tile
    // cache invalidation on brightness change).
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
    // No longer listening to themeProvider (removed to fix circular loop).
  }
}
