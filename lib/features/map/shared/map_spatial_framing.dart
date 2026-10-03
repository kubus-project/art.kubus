import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// The one vocabulary the map uses for "how far in are we".
///
/// Both renderers (globe on web, flat Mercator elsewhere) share the Mercator
/// zoom scale, so the same boundaries describe world, region, country, city,
/// neighbourhood, street and artwork everywhere. Nothing here moves the
/// camera: framing levels are read by marker level of detail, copy and
/// telemetry, and by the programmatic targets (search, deep link, cluster).
enum MapFramingLevel {
  world,
  region,
  country,
  city,
  neighbourhood,
  street,
  artwork,
}

abstract final class MapSpatialFraming {
  // Lower bound (inclusive) of each level. Reference values come from the
  // WORLD camera contract (opening 2.55, discover 4.2 EN / 5.6 SL, record
  // 7-9, inspect up to 11.5); the product map tunes the upper levels to the
  // existing street-scale constants (cluster limit 12, spiderfy 15).
  static const double regionMinZoom = 3.5;
  static const double countryMinZoom = 5.5;
  static const double cityMinZoom = 8.5;
  static const double neighbourhoodMinZoom = 12.5;
  static const double streetMinZoom = 15.0;
  static const double artworkMinZoom = 17.0;

  static MapFramingLevel levelForZoom(double zoom) {
    if (!zoom.isFinite) return MapFramingLevel.world;
    if (zoom >= artworkMinZoom) return MapFramingLevel.artwork;
    if (zoom >= streetMinZoom) return MapFramingLevel.street;
    if (zoom >= neighbourhoodMinZoom) return MapFramingLevel.neighbourhood;
    if (zoom >= cityMinZoom) return MapFramingLevel.city;
    if (zoom >= countryMinZoom) return MapFramingLevel.country;
    if (zoom >= regionMinZoom) return MapFramingLevel.region;
    return MapFramingLevel.world;
  }

  /// Flat map minimum zoom (unchanged from the pre-5B map).
  static const double flatMinZoom = 3.0;

  /// Fraction of the shorter viewport side the visible globe disc must cover at
  /// the minimum zoom. Below this the globe would read as a small ball in an
  /// empty field, the "tiny globe" defect the WORLD camera work removed.
  static const double globeFillFraction = 0.92;

  static const double _globeMinZoomFloor = 1.0;
  static const double _globeMinZoomCeiling = 3.2;

  /// MapLibre's default vertical field of view (radians) is 0.6435, which puts
  /// the camera `0.5 / tan(fov / 2) = 1.5` viewport heights from the surface
  /// point under the centre.
  static const double _cameraDistanceInViewportHeights = 1.5;

  /// Smallest zoom at which the visible globe disc still fills
  /// [globeFillFraction] of the shorter side of [viewport].
  ///
  /// The globe is drawn with a perspective camera, so the silhouette is smaller
  /// than the sphere's front-surface diameter `Df = 512 * 2^z / pi` (z being the
  /// zoom at the equator, which is what MapLibre's minimum zoom constrains):
  /// with camera distance `f`, the disc is `S = Df * sqrt(f / (f + Df))`. Solving
  /// for `Df` given the wanted disc `S` gives the closed form used here, so the
  /// result tracks the viewport height as well as its shorter side. Measured in
  /// Chromium at 1440x900: the formula predicts 0.787 and the render shows 0.786.
  static double globeMinZoomFor(Size viewport) {
    final shortSide = math.min(viewport.width, viewport.height);
    if (!shortSide.isFinite ||
        shortSide <= 0 ||
        !viewport.height.isFinite ||
        viewport.height <= 0) {
      return _globeMinZoomFloor;
    }
    final disc = shortSide * globeFillFraction;
    final f = _cameraDistanceInViewportHeights * viewport.height;
    // Df^2 * f = S^2 * (f + Df)  =>  f*Df^2 - S^2*Df - S^2*f = 0
    final surfaceDiameter =
        (disc * disc + disc * math.sqrt(disc * disc + 4 * f * f)) / (2 * f);
    final zoom = math.log(math.pi * surfaceDiameter / 512.0) / math.ln2;
    return zoom.clamp(_globeMinZoomFloor, _globeMinZoomCeiling).toDouble();
  }

  /// Diameter (logical px) of the visible globe disc at equator-zoom [zoom].
  static double globeDiscDiameter(double zoom, Size viewport) {
    final surface = 512.0 * math.pow(2, zoom) / math.pi;
    final f = _cameraDistanceInViewportHeights * viewport.height;
    return surface * math.sqrt(f / (f + surface));
  }

  /// Minimum zoom the map view should enforce for [viewport].
  static double minZoomFor({required bool globe, required Size viewport}) =>
      globe ? globeMinZoomFor(viewport) : flatMinZoom;
}
