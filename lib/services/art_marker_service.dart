import '../models/art_marker.dart';
import '../config/config.dart';
import 'backend_api_service.dart';

/// Service responsible for general (non-AR-specific) art marker persistence.
class ArtMarkerService {
  ArtMarkerService._internal();
  static final ArtMarkerService _instance = ArtMarkerService._internal();
  factory ArtMarkerService() => _instance;

  final BackendApiService _backendApi = BackendApiService();

  /// Fetch markers from the backend using geospatial filters.
  Future<List<ArtMarker>> fetchMarkers({
    double? latitude,
    double? longitude,
    double? radiusKm,
  }) async {
    try {
      // This service is only used with geo queries today; keep behavior safe.
      if (latitude == null || longitude == null) return const <ArtMarker>[];

      final markers = await _backendApi.getNearbyArtMarkers(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm ?? 5,
      );
      return markers;
    } catch (e) {
      AppConfig.debugPrint('ArtMarkerService.fetchMarkers failed: $e');
    }
    return [];
  }

  /// Create or update an art marker record in the backend.
  Future<ArtMarker?> saveMarker(ArtMarker marker) async {
    try {
      final payload = <String, dynamic>{
        'id': marker.id,
        'name': marker.name,
        'description': marker.description,
        'category': marker.category,
        'markerType': marker.type.name,
        'type': 'geolocation',
        'latitude': marker.position.latitude,
        'longitude': marker.position.longitude,
        'artworkId': marker.artworkId,
        'modelCID': marker.modelCID,
        'modelURL': marker.modelURL,
        'storageProvider': marker.storageProvider.name,
        'scale': marker.scale,
        'rotation': marker.rotation,
        'enableAnimation': marker.enableAnimation,
        'enableInteraction': marker.enableInteraction,
        'metadata': marker.metadata ?? {},
        'tags': marker.tags,
        'activationRadius': marker.activationRadius,
        'requiresProximity': marker.requiresProximity,
        'isPublic': marker.isPublic,
        'createdBy': marker.createdBy,
      };

      final hasId = (marker.id).toString().trim().isNotEmpty;
      ArtMarker? saved;
      if (hasId) {
        saved = await _backendApi.updateArtMarkerRecord(marker.id, payload);
      } else {
        saved = await _backendApi.createArtMarkerRecord(payload);
      }
      return saved ?? marker;
    } catch (e) {
      AppConfig.debugPrint('ArtMarkerService.saveMarker failed: $e');
    }

    return null;
  }
}
