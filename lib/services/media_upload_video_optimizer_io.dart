import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

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

  bool get isSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  Future<PlatformVideoCompressionResultDto?> optimize({
    required Uint8List bytes,
    required String fileName,
    required UploadCompressionPolicyDto policy,
    void Function(UploadCompressionProgressDto progress)? onProgress,
  }) async {
    if (!isSupported) return null;

    final tempDir = await getTemporaryDirectory();
    final safeBase = path.basenameWithoutExtension(fileName).trim().isEmpty
        ? 'upload_video'
        : path.basenameWithoutExtension(fileName);
    final input = File(path.join(
      tempDir.path,
      'kubus_upload_${DateTime.now().microsecondsSinceEpoch}_$safeBase${path.extension(fileName).isEmpty ? '.mp4' : path.extension(fileName)}',
    ));
    File? output;

    try {
      onProgress?.call(const UploadCompressionProgressDto(
        stage: UploadCompressionStage.processing,
        messageKey: 'uploadCompressionVideoProcessing',
        progress: 0.05,
      ));
      await input.writeAsBytes(bytes, flush: true);

      final info = await VideoCompress.compressVideo(
        input.path,
        quality: VideoQuality.Res1280x720Quality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: policy.videoFrameRate,
      );
      final outputPath = info?.path;
      if (outputPath == null || outputPath.trim().isEmpty) {
        return null;
      }

      output = File(outputPath);
      if (!await output.exists()) return null;
      final compressed = await output.readAsBytes();
      final outputName = '${path.basenameWithoutExtension(fileName)}.mp4';

      onProgress?.call(const UploadCompressionProgressDto(
        stage: UploadCompressionStage.done,
        messageKey: 'uploadCompressionDone',
        progress: 1,
      ));

      return PlatformVideoCompressionResultDto(
        bytes: Uint8List.fromList(compressed),
        fileName: outputName.trim().isEmpty ? 'upload_video.mp4' : outputName,
        contentType: 'video/mp4',
      );
    } finally {
      try {
        if (await input.exists()) {
          await input.delete();
        }
      } catch (_) {}
      try {
        final generated = output;
        if (generated != null &&
            generated.path != input.path &&
            await generated.exists()) {
          await generated.delete();
        }
      } catch (_) {}
    }
  }
}
