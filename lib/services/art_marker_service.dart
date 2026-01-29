import '../models/art_marker.dart';
import 'map_marker_service.dart';

/// Legacy wrapper for map marker persistence.
@Deprecated('Use MapMarkerService for marker fetch/save operations.')
class ArtMarkerService {
  ArtMarkerService._internal();
  static final ArtMarkerService _instance = ArtMarkerService._internal();
  factory ArtMarkerService() => _instance;

  final MapMarkerService _mapMarkerService = MapMarkerService();

  /// Fetch markers from the backend using geospatial filters.
  Future<List<ArtMarker>> fetchMarkers({
    double? latitude,
    double? longitude,
    double? radiusKm,
  }) async {
    return _mapMarkerService.fetchMarkers(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
    );
  }

  /// Create or update an art marker record in the backend.
  Future<ArtMarker?> saveMarker(ArtMarker marker) async {
    return _mapMarkerService.saveMarker(marker);
  }
}
