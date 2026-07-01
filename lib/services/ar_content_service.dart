import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/art_marker.dart';
import '../providers/storage_provider.dart';
import 'art_content_service.dart';
import 'storage_config.dart';

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
    if (kDebugMode) {
      debugPrint('ARContentService: Storage provider set to ${provider.name}');
    }
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
      if (kDebugMode) {
        debugPrint('IPFS gateway test failed for $gateway: $e');
      }
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
      if (kDebugMode) {
        debugPrint('ARContentService: Error loading content: $e');
      }
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
        if (kDebugMode) {
          debugPrint('ARContentService: Loaded from IPFS - ${marker.modelCID}');
        }
        return url;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ARContentService: IPFS load failed: $e');
      }
      return null;
    }
  }

  /// Load content from HTTP
  static String? _loadFromHTTP(ArtMarker marker) {
    if (marker.modelURL == null) return null;

    if (kDebugMode) {
      debugPrint('ARContentService: Using HTTP URL - ${marker.modelURL}');
    }
    return marker.modelURL;
  }

  static String _targetStorageFor(
    StorageProvider provider, {
    required bool uploadToBoth,
  }) {
    switch (provider) {
      case StorageProvider.ipfs:
        return 'ipfs';
      case StorageProvider.http:
        return 'http';
      case StorageProvider.hybrid:
        return uploadToBoth ? 'hybrid' : 'ipfs';
    }
  }

  static Future<String?> _uploadViaBackendStorage(
    Uint8List data,
    String filename, {
    Map<String, dynamic>? metadata,
    required String targetStorage,
  }) async {
    final uploadMetadata = <String, dynamic>{
      if (metadata != null) ...metadata,
      'fileType': 'model',
      'storageIntent': targetStorage,
    };
    return ArtContentService.uploadMedia(
      data,
      filename,
      metadata: uploadMetadata,
      targetStorage: targetStorage,
    );
  }

  /// Upload content using preferred storage provider
  static Future<Map<String, String?>> uploadContent(
    Uint8List data,
    String filename, {
    Map<String, dynamic>? metadata,
    bool uploadToBoth =
        true, // Ask backend for hybrid storage when supported.
  }) async {
    final provider = await getPreferredStorageProvider();
    final results = <String, String?>{
      'cid': null,
      'url': null,
    };

    // The client never sends Pinata credentials; backend storage owns IPFS pinning.
    switch (provider) {
      case StorageProvider.ipfs:
        results['url'] = await _uploadViaBackendStorage(
          data,
          filename,
          metadata: metadata,
          targetStorage:
              _targetStorageFor(provider, uploadToBoth: uploadToBoth),
        );
        break;

      case StorageProvider.http:
        results['url'] = await _uploadViaBackendStorage(
          data,
          filename,
          metadata: metadata,
          targetStorage:
              _targetStorageFor(provider, uploadToBoth: uploadToBoth),
        );
        break;

      case StorageProvider.hybrid:
        results['url'] = await _uploadViaBackendStorage(
          data,
          filename,
          metadata: metadata,
          targetStorage:
              _targetStorageFor(provider, uploadToBoth: uploadToBoth),
        );
        break;
    }

    return results;
  }

  /// Get storage statistics (AR context convenience wrapper)
  static Future<Map<String, dynamic>> getStorageStats() async {
    return ArtContentService.getStorageStats();
  }

  /// Clear cached content
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ipfsGatewayKey);
    if (kDebugMode) {
      debugPrint('ARContentService: Cache cleared');
    }
  }
}
