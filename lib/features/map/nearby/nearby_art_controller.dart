import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../../models/art_marker.dart';
import '../../../models/artwork.dart';
import '../controller/kubus_map_controller.dart';

/// Adapter interface so Nearby UI can integrate with [KubusMapController]
/// without hard-coding it (helps testing + future map implementations).
abstract interface class NearbyArtMapDelegate {
  KubusMapCameraState get camera;

  Future<void> animateTo(
    LatLng target, {
    double? zoom,
    double? rotation,
    double? tilt,
    Duration duration,
    double? compositionYOffsetPx,
  });

  void selectMarker(
    ArtMarker marker, {
    List<ArtMarker>? stackedMarkers,
    int? stackIndex,
  });
}

class KubusNearbyArtMapDelegate implements NearbyArtMapDelegate {
  KubusNearbyArtMapDelegate(this.controller);

  final KubusMapController controller;

  @override
  KubusMapCameraState get camera => controller.camera;

  @override
  Future<void> animateTo(
    LatLng target, {
    double? zoom,
    double? rotation,
    double? tilt,
    Duration duration = const Duration(milliseconds: 360),
    double? compositionYOffsetPx,
  }) {
    return controller.animateTo(
      target,
      zoom: zoom,
      rotation: rotation,
      tilt: tilt,
      duration: duration,
      compositionYOffsetPx: compositionYOffsetPx,
    );
  }

  @override
  void selectMarker(
    ArtMarker marker, {
    List<ArtMarker>? stackedMarkers,
    int? stackIndex,
  }) {
    controller.selectMarker(
      marker,
      stackedMarkers: stackedMarkers,
      stackIndex: stackIndex,
    );
  }
}

/// Controller for the shared Nearby Art panel.
///
/// Scope:
/// - Maps an [Artwork] tap to marker selection + camera focus.
/// - Provides helper methods for distance and marker lookup.
///
/// Non-scope (intentionally):
/// - fetching markers/artworks
/// - widget layout
/// - provider initialization
class NearbyArtController {
  NearbyArtController({
    required NearbyArtMapDelegate map,
    Distance? distance,
  })  : _map = map,
        _distance = distance ?? const Distance();

  final NearbyArtMapDelegate _map;
  final Distance _distance;

  /// Finds the most relevant marker for [artwork] from the current in-memory
  /// marker list.
  ///
  /// Preference:
  /// 1) explicit `artwork.arMarkerId` match
  /// 2) `marker.artworkId == artwork.id`
  ArtMarker? findMarkerForArtwork(
    Artwork artwork,
    List<ArtMarker> markers,
  ) {
    final byId = artwork.arMarkerId;
    if (byId != null && byId.trim().isNotEmpty) {
      for (final m in markers) {
        if (m.id == byId) return m;
      }
    }

    for (final m in markers) {
      if (m.artworkId == artwork.id) return m;
    }

    return null;
  }

  double distanceMeters({required LatLng from, required LatLng to}) {
    return _distance.as(LengthUnit.Meter, from, to);
  }

  String formatDistance(double meters) {
    if (meters.isNaN || meters.isInfinite) return '';
    if (meters < 1000) {
      return '${meters.round()}m';
    }
    final km = meters / 1000.0;
    if (km < 10) {
      return '${km.toStringAsFixed(1)}km';
    }
    return '${km.round()}km';
  }

  /// Primary interaction: tapping a card in the Nearby panel.
  ///
  /// Behavior:
  /// - selects the corresponding marker (if found)
  /// - animates camera to marker position
  ///
  /// Note: If no marker exists, we still animate to the artwork position.
  /// This avoids opening side info panels (desktop) while still "centering".
  Future<void> handleArtworkTap({
    required Artwork artwork,
    required List<ArtMarker> markers,
    required LatLng fallbackPosition,
    double minZoom = 15.0,
    double? compositionYOffsetPx,
  }) async {
    final marker = findMarkerForArtwork(artwork, markers);

    final target = marker?.position ?? fallbackPosition;
    final desiredZoom = math.max(_map.camera.zoom, minZoom);

    // Selecting first ensures overlays open immediately.
    if (marker != null) {
      _map.selectMarker(marker);
    }

    await _map.animateTo(
      target,
      zoom: desiredZoom,
      rotation: _map.camera.bearing,
      tilt: _map.camera.pitch,
      compositionYOffsetPx: compositionYOffsetPx,
    );
  }
}
