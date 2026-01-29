import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
      final url = Uri.parse('${StorageConfig.httpBackend}/api/upload');
      final request = http.MultipartRequest('POST', url);

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        data,
        filename: filename,
      ));

      if (metadata != null && metadata.isNotEmpty) {
        request.fields['metadata'] = jsonEncode(metadata);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final fileUrl = jsonResponse['url'] as String?;
        if (fileUrl != null) {
          if (kDebugMode) {
            debugPrint('ArtContentService: Uploaded media to $fileUrl');
          }
          return fileUrl;
        }
      } else {
        if (kDebugMode) {
          debugPrint(
              'ArtContentService: Upload failed - ${response.statusCode}: ${response.body}');
        }
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
