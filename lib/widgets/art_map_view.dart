import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

/// Shared MapLibre layer used by both mobile and desktop map screens.
///
/// UI overlays (filters, marker cards, discovery progress, etc.) remain
/// Flutter widgets layered above this view.
class ArtMapView extends StatelessWidget {
  const ArtMapView({
    super.key,
    required this.initialCenter,
    required this.initialZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.isDarkMode,
    required this.styleAsset,
    required this.onMapCreated,
    this.onStyleLoaded,
    this.onCameraMove,
    this.onCameraIdle,
    this.onMapClick,
    this.onMapLongClick,
    this.rotateGesturesEnabled = true,
    this.scrollGesturesEnabled = true,
    this.zoomGesturesEnabled = true,
    this.tiltGesturesEnabled = true,
    this.compassEnabled = false,
  });

  static final Map<String, Future<String>> _styleCache = <String, Future<String>>{};

  final ll.LatLng initialCenter;
  final double initialZoom;
  final double minZoom;
  final double maxZoom;
  final bool isDarkMode;
  final String styleAsset;

  final void Function(ml.MapLibreMapController controller) onMapCreated;
  final VoidCallback? onStyleLoaded;
  final void Function(ml.CameraPosition position)? onCameraMove;
  final VoidCallback? onCameraIdle;

  final void Function(math.Point<double> point, ll.LatLng latLng)? onMapClick;
  final void Function(math.Point<double> point, ll.LatLng latLng)? onMapLongClick;

  final bool rotateGesturesEnabled;
  final bool scrollGesturesEnabled;
  final bool zoomGesturesEnabled;
  final bool tiltGesturesEnabled;
  final bool compassEnabled;

  @override
  Widget build(BuildContext context) {
    // Force a clean map instance when switching styles; this avoids rare
    // renderer/state bugs on web and ensures dark/light swaps are reliable.
    final mapKey = ValueKey<String>('maplibre-${isDarkMode ? 'dark' : 'light'}-$styleAsset');

    return FutureBuilder<String>(
      future: _resolveStyleString(styleAsset),
      builder: (context, snapshot) {
        final resolved = snapshot.data;

        // MapLibre is a platform view; in a loose Stack it can end up with a 0-size
        // layout. SizedBox.expand guarantees fullscreen rendering for our map screens.
        if (resolved == null) {
          return const SizedBox.expand(child: ColoredBox(color: Colors.transparent));
        }

        return SizedBox.expand(
          child: ml.MapLibreMap(
            key: mapKey,
            styleString: resolved,
            initialCameraPosition: ml.CameraPosition(
              target: ml.LatLng(initialCenter.latitude, initialCenter.longitude),
              zoom: initialZoom,
            ),
            minMaxZoomPreference: ml.MinMaxZoomPreference(minZoom, maxZoom),
            rotateGesturesEnabled: rotateGesturesEnabled,
            scrollGesturesEnabled: scrollGesturesEnabled,
            zoomGesturesEnabled: zoomGesturesEnabled,
            tiltGesturesEnabled: tiltGesturesEnabled,
            compassEnabled: compassEnabled,
            myLocationEnabled: false,
            myLocationTrackingMode: ml.MyLocationTrackingMode.none,
            onMapCreated: onMapCreated,
            onStyleLoadedCallback: onStyleLoaded,
            onCameraMove: onCameraMove,
            onCameraIdle: onCameraIdle,
            onMapClick: onMapClick == null
                ? null
                : (math.Point<double> point, ml.LatLng latLng) {
                    onMapClick!(
                      point,
                      ll.LatLng(latLng.latitude, latLng.longitude),
                    );
                  },
            onMapLongClick: onMapLongClick == null
                ? null
                : (math.Point<double> point, ml.LatLng latLng) {
                    onMapLongClick!(
                      point,
                      ll.LatLng(latLng.latitude, latLng.longitude),
                    );
                  },
            trackCameraPosition: true,
          ),
        );
      },
    );
  }

  static Future<String> _resolveStyleString(String styleString) {
    if (styleString.isEmpty) return Future<String>.value(styleString);

    final trimmed = styleString.trimLeft();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return Future<String>.value(styleString);
    }

    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('file://') ||
        lower.startsWith('asset://') ||
        lower.startsWith('assets://')) {
      return Future<String>.value(styleString);
    }

    return _styleCache.putIfAbsent(styleString, () async {
      try {
        return await rootBundle.loadString(styleString);
      } catch (_) {
        // Fall back to the original string (it may be a valid URL for some platforms).
        return styleString;
      }
    });
  }
}
