import 'package:flutter/foundation.dart';

import 'backend_api_service.dart';

/// Service for handling generic (non-AR) art media uploads and storage stats.
class ArtContentService {
  const ArtContentService._();

  /// Uploads binary media (images, audio, documents) to the HTTP backend.
  /// Returns the absolute URL of the stored asset when successful.
  static Future<String?> uploadMedia(
    Uint8List data,
    String filename, {
    Map<String, dynamic>? metadata,
    String targetStorage = 'http',
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
        targetStorage: targetStorage,
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
    return BackendApiService().getStorageStats();
  }
}
