import 'dart:typed_data';

import 'media_upload_optimizer.dart';

class PlatformVideoCompressionResultDto {
  final Uint8List bytes;
  final String fileName;
  final String contentType;

  const PlatformVideoCompressionResultDto({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });
}

class PlatformVideoUploadOptimizer {
  const PlatformVideoUploadOptimizer();

  bool get isSupported => false;

  Future<PlatformVideoCompressionResultDto?> optimize({
    required Uint8List bytes,
    required String fileName,
    required UploadCompressionPolicyDto policy,
    void Function(UploadCompressionProgressDto progress)? onProgress,
  }) async {
    return null;
  }
}
