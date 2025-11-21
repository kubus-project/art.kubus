import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/ar_marker.dart';
import '../config/api_keys.dart';
import '../config/config.dart';

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
  static Future<void> setPreferredStorageProvider(StorageProvider provider) async {
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
  static Future<String?> loadARContent(ARMarker marker) async {
    final provider = await getPreferredStorageProvider();
    
    try {
      switch (provider) {
        case StorageProvider.ipfs:
          return await _loadFromIPFS(marker);
        
        case StorageProvider.http:
          return _loadFromHTTP(marker);
        
        case StorageProvider.hybrid:
          // Try IPFS first, fallback to HTTP
          final ipfsUrl = await _loadFromIPFS(marker);
          if (ipfsUrl != null) return ipfsUrl;
          return _loadFromHTTP(marker);
      }
    } catch (e) {
      debugPrint('ARContentService: Error loading content: $e');
      return null;
    }
  }

  /// Load content from IPFS
  static Future<String?> _loadFromIPFS(ARMarker marker) async {
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
  static String? _loadFromHTTP(ARMarker marker) {
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
      debugPrint('ARContentService: Pinata credentials not configured. Set PINATA_API_KEY and PINATA_SECRET_KEY.');
      return null;
    }

    try {
      final url = Uri.parse('${StorageConfig.pinataApiUrl}/pinning/pinFileToIPFS');
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

      debugPrint('ARContentService: Upload failed - ${response.statusCode}: ${response.body}');
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
    bool uploadToBoth = true,  // Upload to both IPFS and HTTP for hybrid approach
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
          results['cid'] = await uploadToIPFS(data, filename, metadata: metadata);
          if (results['cid'] == null) {
            results['url'] = await uploadToHTTP(data, filename, metadata: metadata);
          }
        }
        break;
    }

    return results;
  }

  /// Fetch AR markers from backend
  static Future<List<ARMarker>> fetchARMarkers({
    double? latitude,
    double? longitude,
    double? radiusKm,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (latitude != null) queryParams['lat'] = latitude.toString();
      if (longitude != null) queryParams['lng'] = longitude.toString();
      if (radiusKm != null) queryParams['radius'] = radiusKm.toString();

      final uri = Uri.parse('${StorageConfig.httpBackend}/api/ar-markers')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as List;
        return jsonData.map((json) => ARMarker.fromMap(json)).toList();
      }

      debugPrint('ARContentService: Failed to fetch markers - ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('ARContentService: Error fetching markers: $e');
      return [];
    }
  }

  /// Save AR marker to backend
  static Future<bool> saveARMarker(ARMarker marker) async {
    try {
      final url = Uri.parse('${StorageConfig.httpBackend}/api/ar-markers');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(marker.toMap()),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('ARContentService: Marker saved successfully');
        return true;
      }

      debugPrint('ARContentService: Failed to save marker - ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('ARContentService: Error saving marker: $e');
      return false;
    }
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
