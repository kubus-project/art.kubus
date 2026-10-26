import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../services/share/share_deep_link_parser.dart';

/// The camera requested by a direct `/map?lat=…&lng=…&z=…` entry.
///
/// This is only an initial camera value. The mounted map screen and its
/// `KubusMapController` remain the sole owners of live camera state.
@immutable
class MapEntryCamera {
  const MapEntryCamera({required this.center, this.zoom});

  static const double minZoom = 3;
  static const double maxZoom = 24;

  final LatLng center;
  final double? zoom;

  static MapEntryCamera? fromUri(Uri uri) {
    if (uri.path != '/map') return null;

    final intent = const ShareDeepLinkCodec().parseIntent(uri);
    if (intent?.type != AppRouteIntentType.map) return null;

    final latitude = intent?.lat;
    final longitude = intent?.lng;
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    final requestedZoom = intent?.zoom;
    final zoom = requestedZoom == null || !requestedZoom.isFinite
        ? null
        : requestedZoom.clamp(minZoom, maxZoom).toDouble();

    return MapEntryCamera(
      center: LatLng(latitude, longitude),
      zoom: zoom,
    );
  }
}
