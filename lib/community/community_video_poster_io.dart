import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:video_compress/video_compress.dart';

import 'community_video_poster_core.dart';

/// Native capture uses the platform thumbnailer where video_compress has one
/// (Android, iOS, macOS). Windows and Linux have no plugin, so no poster.
Future<Uint8List?> captureCommunityVideoPoster(XFile file) async {
  if (!(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) return null;
  try {
    final path = file.path;
    if (path.isEmpty) return null;
    final info = await VideoCompress.getMediaInfo(path);
    final durationMs = info.duration;
    final target = communityVideoPosterSeekTarget(
      durationMs == null ? null : Duration(milliseconds: durationMs.round()),
    );
    final frame = await VideoCompress.getByteThumbnail(
      path,
      quality: kCommunityVideoPosterQuality,
      position: target.inMilliseconds,
    );
    if (frame == null || frame.isEmpty) return null;
    return await compute(_downscaleToPoster, frame);
  } catch (_) {
    return null;
  }
}

/// Decodes, shrinks to the poster size and re-encodes as JPEG. Runs in a
/// background isolate; a frame that will not decode gives no poster.
Uint8List? _downscaleToPoster(Uint8List frame) {
  final decoded = image_lib.decodeImage(frame);
  if (decoded == null) return null;
  final size = communityVideoPosterSize(decoded.width, decoded.height);
  final resized = size.width.toInt() == decoded.width &&
          size.height.toInt() == decoded.height
      ? decoded
      : image_lib.copyResize(
          decoded,
          width: size.width.toInt(),
          height: size.height.toInt(),
        );
  return image_lib.encodeJpg(resized, quality: kCommunityVideoPosterQuality);
}
