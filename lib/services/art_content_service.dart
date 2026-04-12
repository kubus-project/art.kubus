import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'backend_api_service.dart';
import 'storage_config.dart';

/// Service for handling generic (non-AR) art media uploads and storage stats.
class ArtContentService {
  const ArtContentService._();

  /// Uploads binary media (images, audio, documents) to the HTTP backend.
  /// Returns the absolute URL of the stored asset when successful.
  static Future<String?> uploadMedia(
    Uint8List data,
    String filename, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final fields = <String, String>{};
      metadata?.forEach((key, value) {
        if (value != null) fields[key] = value.toString();
      });
      final result = await BackendApiService().uploadFile(
        fileBytes: data,
        fileName: filename,
        fileType: fields['fileType'] ?? fields['type'] ?? 'image',
        metadata: fields,
      );
      final fileUrl = result['uploadedUrl'] as String? ??
          result['data']?['url'] as String? ??
          result['data']?['relativeUrl'] as String?;
      if (fileUrl != null && fileUrl.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('ArtContentService: Uploaded media to $fileUrl');
        }
        return fileUrl;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ArtContentService: HTTP upload error: $e');
      }
    }
    return null;
  }

  /// Reads aggregate storage statistics from the backend (if enabled).
  static Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final url = Uri.parse('${StorageConfig.httpBackend}/api/storage/stats');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ArtContentService: Error fetching storage stats: $e');
      }
    }
    return {};
  }
}
