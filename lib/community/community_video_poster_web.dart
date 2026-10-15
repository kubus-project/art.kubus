import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart' show XFile;
import 'package:web/web.dart' as web;

import 'community_video_poster_core.dart';

/// How long any step of the browser capture may take before giving up.
const Duration _stepTimeout = Duration(seconds: 8);

/// Draws one frame of the picked clip to a JPEG, entirely in the browser.
///
/// The clip is a same-origin blob URL and the element is muted, so the canvas
/// is not tainted and `toDataURL` is allowed. A codec the browser cannot
/// decode (HEVC in Chromium, for example) fails the metadata step and gives no
/// poster. Nothing here is awaited by the publish path.
Future<Uint8List?> captureCommunityVideoPoster(XFile file) async {
  final source = file.path;
  if (source.isEmpty) return null;
  final video = web.HTMLVideoElement()
    ..muted = true
    ..playsInline = true
    ..preload = 'metadata'
    ..src = source;
  try {
    final loaded = await _waitForEvent(
      video,
      const ['loadeddata'],
    );
    if (!loaded) return null;
    final width = video.videoWidth;
    final height = video.videoHeight;
    if (width <= 0 || height <= 0) return null;
    final durationSeconds = video.duration;
    final duration = durationSeconds.isFinite && durationSeconds > 0
        ? Duration(milliseconds: (durationSeconds * 1000).round())
        : null;
    final target = communityVideoPosterSeekTarget(duration);
    if (target > Duration.zero) {
      video.currentTime = target.inMilliseconds / 1000;
      final seeked = await _waitForEvent(video, const ['seeked']);
      if (!seeked) return null;
    }
    final size = communityVideoPosterSize(width, height);
    final canvas = web.HTMLCanvasElement()
      ..width = size.width.toInt()
      ..height = size.height.toInt();
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    context.drawImage(video, 0, 0, size.width, size.height);
    final dataUrl = canvas.toDataURL(
      'image/jpeg',
      (kCommunityVideoPosterQuality / 100).toJS,
    );
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    final bytes = base64Decode(dataUrl.substring(comma + 1));
    return bytes.isEmpty ? null : bytes;
  } catch (_) {
    return null;
  } finally {
    video.removeAttribute('src');
    video.load();
  }
}

/// Completes true when one of [types] fires, false on an error event or after
/// [_stepTimeout]. The listener is removed in every case.
Future<bool> _waitForEvent(web.HTMLVideoElement video, List<String> types) {
  final completer = Completer<bool>();
  late final void Function(bool ok) finish;
  final JSFunction onSuccess = ((web.Event _) => finish(true)).toJS;
  final JSFunction onError = ((web.Event _) => finish(false)).toJS;
  finish = (bool ok) {
    if (completer.isCompleted) return;
    for (final type in types) {
      video.removeEventListener(type, onSuccess);
    }
    video.removeEventListener('error', onError);
    completer.complete(ok);
  };
  for (final type in types) {
    video.addEventListener(type, onSuccess);
  }
  video.addEventListener('error', onError);
  return completer.future.timeout(
    _stepTimeout,
    onTimeout: () {
      finish(false);
      return false;
    },
  );
}
