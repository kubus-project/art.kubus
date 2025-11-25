import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/art_marker.dart';
import '../config/api_keys.dart';
import '../config/config.dart';
import '../providers/storage_provider.dart';
import 'backend_api_service.dart';

/// Configuration for storage providers
class StorageConfig {
  // IPFS Gateways (prioritized list)
  static const List<String> ipfsGateways = [
    'https://ipfs.io/ipfs/',
    'https://gateway.pinata.cloud/ipfs/',
    'https://cloudflare-ipfs.com/ipfs/',
    'https://dweb.link/ipfs/',
  ];

  // Default HTTP backend
  static const String defaultHttpBackend = AppConfig.baseApiUrl;

  // Custom backend URL (can be overridden)
  static String? customHttpBackend;

  // IPFS pin service configuration - now using centralized ApiKeys
  static String get pinataApiUrl => ApiKeys.ipfsApiUrl;
  static String get pinataApiKey => ApiKeys.pinataApiKey;
  static String get pinataSecretKey => ApiKeys.pinataSecretKey;
  static String get ipfsGateway => ApiKeys.ipfsGateway;

  /// Get active HTTP backend URL
  static String get httpBackend => customHttpBackend ?? defaultHttpBackend;

  /// Set custom HTTP backend
  static void setHttpBackend(String url) {
    customHttpBackend = url;
  }
}

/// Service for managing AR content with IPFS/HTTP support
class ARContentService {
  static const String _storageProviderKey = 'storage_provider_preference';
  static const String _ipfsGatewayKey = 'preferred_ipfs_gateway';

  /// Get preferred storage provider
  static Future<StorageProvider> getPreferredStorageProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final providerName = prefs.getString(_storageProviderKey) ?? 'hybrid';
    return StorageProvider.values.firstWhere(
      (e) => e.name == providerName,
      orElse: () => StorageProvider.hybrid,
    );
  }

  /// Set preferred storage provider
  static Future<void> setPreferredStorageProvider(
      StorageProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageProviderKey, provider.name);
    debugPrint('ARContentService: Storage provider set to ${provider.name}');
  }

  /// Get preferred IPFS gateway
  static Future<String> getPreferredIPFSGateway() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ipfsGatewayKey) ?? StorageConfig.ipfsGateways.first;
  }

  /// Set preferred IPFS gateway
  static Future<void> setPreferredIPFSGateway(String gateway) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ipfsGatewayKey, gateway);
  }

  /// Test IPFS gateway availability
  static Future<bool> testIPFSGateway(String gateway) async {
    try {
      // Test with a known IPFS CID (IPFS logo)
      const testCID = 'QmPZ9gcCEpqKTo6aq61g2nXGUhM4iCL3ewB6LDXZCtioEB';
      final testUrl = '$gateway$testCID';

      final response = await http.head(Uri.parse(testUrl)).timeout(
            const Duration(seconds: 5),
          );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('IPFS gateway test failed for $gateway: $e');
      return false;
    }
  }

  /// Find best available IPFS gateway
  static Future<String> findBestIPFSGateway() async {
    // Try preferred gateway first
    final preferredGateway = await getPreferredIPFSGateway();
    if (await testIPFSGateway(preferredGateway)) {
      return preferredGateway;
    }

    // Test other gateways
    for (final gateway in StorageConfig.ipfsGateways) {
      if (gateway == preferredGateway) continue;
      if (await testIPFSGateway(gateway)) {
        // Save as new preferred gateway
        await setPreferredIPFSGateway(gateway);
        return gateway;
      }
    }

    // If all fail, return first gateway (will attempt anyway)
    return StorageConfig.ipfsGateways.first;
  }

  /// Load AR content for a marker
  static Future<String?> loadARContent(ArtMarker marker) async {
    final provider = await getPreferredStorageProvider();

    try {
      switch (provider) {
        case StorageProvider.ipfs:
          return await _loadFromIPFS(marker);

        case StorageProvider.http:
          return _loadFromHTTP(marker);

        case StorageProvider.hybrid:
          // Prefer low-latency HTTP served by API, fallback to IPFS backup
          final httpUrl = _loadFromHTTP(marker);
          if (httpUrl != null) return httpUrl;
          return await _loadFromIPFS(marker);
      }
    } catch (e) {
      debugPrint('ARContentService: Error loading content: $e');
      return null;
    }
  }

  /// Load content from IPFS
  static Future<String?> _loadFromIPFS(ArtMarker marker) async {
    if (marker.modelCID == null) return null;

    try {
      final gateway = await findBestIPFSGateway();
      final url = '$gateway${marker.modelCID}';

      // Verify content is accessible
      final response = await http.head(Uri.parse(url)).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        debugPrint('ARContentService: Loaded from IPFS - ${marker.modelCID}');
        return url;
      }

      return null;
    } catch (e) {
      debugPrint('ARContentService: IPFS load failed: $e');
      return null;
    }
  }

  /// Load content from HTTP
  static String? _loadFromHTTP(ArtMarker marker) {
    if (marker.modelURL == null) return null;

    debugPrint('ARContentService: Using HTTP URL - ${marker.modelURL}');
    return marker.modelURL;
  }

  /// Upload content to IPFS (via Pinata)
  static Future<String?> uploadToIPFS(
    Uint8List data,
    String filename, {
    Map<String, dynamic>? metadata,
  }) async {
    // Validate API keys are configured
    if (StorageConfig.pinataApiKey == 'YOUR_PINATA_API_KEY' ||
        StorageConfig.pinataSecretKey == 'YOUR_PINATA_SECRET_KEY') {
      debugPrint(
          'ARContentService: Pinata credentials not configured. Set PINATA_API_KEY and PINATA_SECRET_KEY.');
      return null;
    }

    try {
      final url =
          Uri.parse('${StorageConfig.pinataApiUrl}/pinning/pinFileToIPFS');
      final request = http.MultipartRequest('POST', url);

      // Add headers
      request.headers['pinata_api_key'] = StorageConfig.pinataApiKey;
      request.headers['pinata_secret_api_key'] = StorageConfig.pinataSecretKey;

      // Add file
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        data,
        filename: filename,
      ));

      // Add metadata
      if (metadata != null) {
        request.fields['pinataMetadata'] = jsonEncode({
          'name': filename,
          'keyvalues': metadata,
        });
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final cid = jsonResponse['IpfsHash'] as String;
        debugPrint('ARContentService: Uploaded to IPFS - CID: $cid');
        return cid;
      }

      debugPrint(
          'ARContentService: Upload failed - ${response.statusCode}: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('ARContentService: IPFS upload error: $e');
      return null;
    }
  }

  /// Upload content to HTTP backend
  static Future<String?> uploadToHTTP(
    Uint8List data,
    String filename, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final url = Uri.parse('${StorageConfig.httpBackend}/api/upload');
      final request = http.MultipartRequest('POST', url);

      // Add file
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        data,
        filename: filename,
      ));

      // Add metadata
      if (metadata != null) {
        request.fields['metadata'] = jsonEncode(metadata);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = jsonDecode(response.body);
        final fileUrl = jsonResponse['url'] as String;
        debugPrint('ARContentService: Uploaded to HTTP - URL: $fileUrl');
        return fileUrl;
      }

      debugPrint('ARContentService: Upload failed - ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('ARContentService: HTTP upload error: $e');
      return null;
    }
  }

  /// Upload content using preferred storage provider
  static Future<Map<String, String?>> uploadContent(
    Uint8List data,
    String filename, {
    Map<String, dynamic>? metadata,
    bool uploadToBoth =
        true, // Upload to both IPFS and HTTP for hybrid approach
  }) async {
    final provider = await getPreferredStorageProvider();
    final results = <String, String?>{
      'cid': null,
      'url': null,
    };

    switch (provider) {
      case StorageProvider.ipfs:
        results['cid'] = await uploadToIPFS(data, filename, metadata: metadata);
        break;

      case StorageProvider.http:
        results['url'] = await uploadToHTTP(data, filename, metadata: metadata);
        break;

      case StorageProvider.hybrid:
        if (uploadToBoth) {
          // Upload to both for maximum availability
          final ipfsFuture = uploadToIPFS(data, filename, metadata: metadata);
          final httpFuture = uploadToHTTP(data, filename, metadata: metadata);

          final uploadResults = await Future.wait([ipfsFuture, httpFuture]);
          results['cid'] = uploadResults[0];
          results['url'] = uploadResults[1];
        } else {
          // Try IPFS first, fallback to HTTP
          results['cid'] =
              await uploadToIPFS(data, filename, metadata: metadata);
          if (results['cid'] == null) {
            results['url'] =
                await uploadToHTTP(data, filename, metadata: metadata);
          }
        }
        break;
    }

    return results;
  }

  /// Fetch art markers from backend
  static Future<List<ArtMarker>> fetchARMarkers({
    double? latitude,
    double? longitude,
    double? radiusKm,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (latitude != null) queryParams['lat'] = latitude.toString();
      if (longitude != null) queryParams['lng'] = longitude.toString();
      if (radiusKm != null) queryParams['radius'] = radiusKm.toString();

      final uri = Uri.parse('${StorageConfig.httpBackend}/api/art-markers')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri).timeout(
            const Duration(seconds: 15),
          );

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
          'ARContentService: Failed to fetch markers - ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('ARContentService: Error fetching markers: $e');
      return [];
    }
  }

  /// Save AR marker to backend
  /// Save AR marker to backend
  static Future<ArtMarker?> saveARMarker(ArtMarker marker) async {
    try {
      // Use BackendApiService's createArtMarker method for proper auth
      final backendApi = BackendApiService();
      await backendApi.ensureAuthLoaded();
      // Build a payload that matches the backend's expected shape.
      // The backend enforces marker_type to be one of ('geolocation','image','qr','nfc'),
      // so always use 'geolocation' for spatial map markers. AR-specific config
      // is sent alongside to be stored to the child `ar_markers` table.
      final payload = <String, dynamic>{
        'name': marker.name,
        'description': marker.description,
        'category': marker.category,
        // Backend expects a `type` field which maps to `marker_type` CHECK
        'type': 'geolocation',
        'latitude': marker.position.latitude,
        'longitude': marker.position.longitude,
        'artworkId': marker.artworkId,
        'modelCID': marker.modelCID,
        'modelURL': marker.modelURL,
        'storageProvider': marker.storageProvider.name,
        'scale': marker.scale,
        // Provide rotation as an object — backend will read rotation.x/y/z
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

      final response = await http
          .post(
            Uri.parse('${StorageConfig.httpBackend}/api/art-markers'),
            headers: await _getAuthHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('ARContentService: Marker saved successfully');
        try {
          final body = jsonDecode(response.body);
          final data = body is Map<String, dynamic>
              ? (body['data'] ?? body['marker'] ?? body['artMarker'] ?? body)
              : body;
          if (data is Map<String, dynamic>) {
            return ArtMarker.fromMap(data);
          }
        } catch (e) {
          debugPrint('ARContentService: Failed to parse marker response: $e');
        }
        // Fallback to returning the marker we submitted when parsing fails
        return marker;
      }

      debugPrint(
          'ARContentService: Failed to save marker - ${response.statusCode}: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('ARContentService: Error saving marker: $e');
      return null;
    }
  }

  /// Get auth headers from backend API service
  static Future<Map<String, String>> _getAuthHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final backendApi = BackendApiService();
      await backendApi.ensureAuthLoaded();
      // Try to get the stored token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
        debugPrint('ARContentService: Added auth token to headers');
      } else {
        debugPrint('ARContentService: No auth token available');
      }
    } catch (e) {
      debugPrint('ARContentService: Failed to get auth headers: $e');
    }

    return headers;
  }

  /// Get storage statistics
  static Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final url = Uri.parse('${StorageConfig.httpBackend}/api/storage/stats');
      final response = await http.get(url).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      return {};
    } catch (e) {
      debugPrint('ARContentService: Error fetching stats: $e');
      return {};
    }
  }

  /// Clear cached content
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ipfsGatewayKey);
    debugPrint('ARContentService: Cache cleared');
  }
}
