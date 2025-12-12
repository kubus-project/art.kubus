import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/art_marker.dart';
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

      debugPrint(
          'ArtMarkerService: Failed to fetch markers - ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('ArtMarkerService: Error fetching markers: $e');
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

      var response = await _submitMarkerPayload(payload);
      if (_isUnauthorized(response.statusCode)) {
        debugPrint(
            'ArtMarkerService: Unauthorized response, attempting token refresh');
        response = await _submitMarkerPayload(payload, refreshToken: true);
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final body = jsonDecode(response.body);
          final data = body is Map<String, dynamic>
              ? (body['data'] ?? body['marker'] ?? body['artMarker'] ?? body)
              : body;
          if (data is Map<String, dynamic>) {
            return ArtMarker.fromMap(data);
          }
        } catch (e) {
          debugPrint('ArtMarkerService: Failed to parse marker response: $e');
        }
        return marker;
      }

      debugPrint(
          'ArtMarkerService: Failed to save marker - ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('ArtMarkerService: Error saving marker: $e');
  }

    return null;
  }

  Future<http.Response> _submitMarkerPayload(
    Map<String, dynamic> payload, {
    bool refreshToken = false,
  }) async {
    final headers = await _getAuthHeaders(refreshToken: refreshToken);
    final uri = Uri.parse('${_backendApi.baseUrl}/api/art-markers');
    return http
        .post(
          uri,
          headers: headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));
  }

  bool _isUnauthorized(int statusCode) => statusCode == 401 || statusCode == 403;

  Future<Map<String, String>> _getAuthHeaders({bool refreshToken = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final token = await _resolveAuthToken(forceRefresh: refreshToken);
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
        debugPrint('ArtMarkerService: Added auth token to headers');
      } else {
        debugPrint('ArtMarkerService: No auth token available for marker save');
      }
    } catch (e) {
      debugPrint('ArtMarkerService: Failed to get auth headers: $e');
    }

    return headers;
  }

  Future<String?> _resolveAuthToken({bool forceRefresh = false}) async {
    final backendApi = _backendApi;
    String? wallet;
    try {
      if (forceRefresh) {
        wallet = await _getStoredWalletAddress();
        await backendApi.clearAuth();
        await backendApi.ensureAuthLoaded(walletAddress: wallet);
      } else {
        await backendApi.ensureAuthLoaded();
      }
    } catch (e) {
      debugPrint('ArtMarkerService: ensureAuthLoaded failed: $e');
    }

    var token = backendApi.getAuthToken();
    if (token == null || token.isEmpty) {
      wallet ??= await _getStoredWalletAddress();
      if (wallet != null && wallet.isNotEmpty) {
        try {
          await backendApi.ensureAuthLoaded(walletAddress: wallet);
          token = backendApi.getAuthToken();
        } catch (e) {
          debugPrint('ArtMarkerService: ensureAuthLoaded with wallet failed: $e');
        }
      }
    }

    if (token != null && token.isNotEmpty) {
      return token;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('jwt_token') ??
          prefs.getString('token') ??
          prefs.getString('auth_token') ??
          prefs.getString('authToken');
    } catch (e) {
      debugPrint('ArtMarkerService: Failed to read auth token from prefs: $e');
    }

    return token;
  }

  Future<String?> _getStoredWalletAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('wallet_address') ??
          prefs.getString('wallet') ??
          prefs.getString('walletAddress') ??
          prefs.getString('user_id');
    } catch (e) {
      debugPrint('ArtMarkerService: Failed to read stored wallet: $e');
      return null;
    }
  }
}
