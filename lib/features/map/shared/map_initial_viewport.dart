import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

import '../../../utils/geo_bounds.dart';

/// Locale fallback used only when map entry has no stronger camera intent.
class MapInitialViewport {
  const MapInitialViewport({
    required this.initialCenter,
    required this.initialZoom,
    required this.fitBounds,
  });

  final LatLng initialCenter;
  final double initialZoom;
  final GeoBounds fitBounds;

  static const MapInitialViewport slovenia = MapInitialViewport(
    initialCenter: LatLng(46.12, 14.99),
    initialZoom: 7.0,
    fitBounds: GeoBounds(south: 45.42, west: 13.35, north: 46.88, east: 16.61),
  );

  static const MapInitialViewport europe = MapInitialViewport(
    initialCenter: LatLng(53.0, 14.0),
    initialZoom: 4.0,
    fitBounds: GeoBounds(south: 34, west: -12, north: 72, east: 40),
  );

  static MapInitialViewport forLocale(Locale locale) =>
      locale.languageCode.toLowerCase() == 'sl' ? slovenia : europe;

  static bool shouldApplyLocaleFallback({
    required bool hasExplicitTarget,
    required bool hasWalkingIntent,
    required bool autoFollowHasLiveLocation,
  }) =>
      !hasExplicitTarget && !hasWalkingIntent && !autoFollowHasLiveLocation;
}
