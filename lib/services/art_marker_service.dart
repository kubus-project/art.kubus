import 'dart:convert';

import 'package:http/http.dart' as http;

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
      final queryParams = <String, String>{};
      if (latitude != null) queryParams['lat'] = latitude.toString();
      if (longitude != null) queryParams['lng'] = longitude.toString();
      if (radiusKm != null) queryParams['radius'] = radiusKm.toString();

      final uri = Uri.parse('${_backendApi.baseUrl}/api/art-markers')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> payload;
        if (body is List) {
          payload = body;
        } else if (body is Map<String, dynamic>) {
          payload = (body['data'] ??
              body['markers'] ??
              body['artMarkers'] ??
              body['results'] ??
              []) as List<dynamic>;
        } else {
          payload = const [];
        }

        return payload
            .map((json) => ArtMarker.fromMap(json as Map<String, dynamic>))
            .toList();
      }

      AppConfig.debugPrint(
        'ArtMarkerService: fetchMarkers failed (${response.statusCode})',
      );
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
