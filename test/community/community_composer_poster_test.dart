import 'dart:async';
import 'dart:typed_data';

import 'package:art_kubus/community/community_composer_media.dart';
import 'package:art_kubus/community/community_post_media.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

final Uint8List _clipBytes = Uint8List.fromList(<int>[0, 0, 0, 24, 102, 116]);
final Uint8List _posterBytes = Uint8List.fromList(<int>[255, 216, 255, 224]);

const String _uploadedVideo = 'https://api.kubus.site/uploads/clip.mp4';
const String _uploadedPoster = 'https://api.kubus.site/uploads/clip-still.jpg';

CommunityComposerPickedMedia _video(String name) =>
    CommunityComposerPickedMedia(
      file: XFile.fromData(
        _clipBytes,
        name: name,
        path: name,
        mimeType: 'video/mp4',
      ),
      kind: CommunityComposerMediaKind.video,
    );

CommunityComposerPickedMedia _image(String name) =>
    CommunityComposerPickedMedia(
      file: XFile.fromData(
        _posterBytes,
        name: name,
        path: '/picked/$name',
        mimeType: 'image/jpeg',
      ),
      kind: CommunityComposerMediaKind.image,
      imageBytes: _posterBytes,
    );

/// Lets the background capture finish on the event loop.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// A recording uploader. The video returns [videoUrl]; the poster returns
/// [posterUrl], or throws when [failPoster] is set.
class _RecordingUploader {
  _RecordingUploader({this.failPoster = false});

  final bool failPoster;
  final List<String> fileTypes = <String>[];
  final List<bool> compressFlags = <bool>[];
  final List<String> fileNames = <String>[];

  Future<Map<String, dynamic>> call({
    required List<int> fileBytes,
    required String fileName,
    required String fileType,
    Map<String, String>? metadata,
    bool compress = true,
  }) async {
    fileTypes.add(fileType);
    compressFlags.add(compress);
    fileNames.add(fileName);
    if (fileType == 'post-video') {
      return <String, dynamic>{'uploadedUrl': _uploadedVideo};
    }
    if (failPoster) throw StateError('poster upload refused');
    return <String, dynamic>{'uploadedUrl': _uploadedPoster};
  }
}

void main() {
  group('capturing the poster', () {
    test('a captured poster is attached to its video item', () async {
      final controller = CommunityComposerMediaController(
        posterCapture: (file) async => _posterBytes,
      );
      controller.add([_video('clip.mp4')]);
      await _settle();
      expect(controller.items.single.posterBytes, _posterBytes);
    });

    test('a null capture leaves the video posterless', () async {
      final controller = CommunityComposerMediaController(
        posterCapture: (file) async => null,
      );
      controller.add([_video('clip.mp4')]);
      await _settle();
      expect(controller.items.single.posterBytes, isNull);
    });

    test('a failing capture never fails adding the clip', () async {
      final controller = CommunityComposerMediaController(
        posterCapture: (file) async => throw StateError('no decoder'),
      );
      expect(() => controller.add([_video('clip.mp4')]), returnsNormally);
      await _settle();
      expect(controller.length, 1);
      expect(controller.items.single.posterBytes, isNull);
    });

    test('images never start a capture', () async {
      var calls = 0;
      final controller = CommunityComposerMediaController(
        posterCapture: (file) async {
          calls++;
          return _posterBytes;
        },
      );
      controller.add([_image('photo.jpg')]);
      await _settle();
      expect(calls, 0);
      expect(controller.items.single.posterBytes, isNull);
    });

    test('a poster that arrives after its clip was removed is dropped',
        () async {
      final gate = Completer<Uint8List?>();
      final controller = CommunityComposerMediaController(
        posterCapture: (file) => gate.future,
      );
      controller.add([_video('clip.mp4')]);
      final id = controller.items.single.id;
      controller.remove(id);
      gate.complete(_posterBytes);
      await _settle();
      expect(controller.isEmpty, isTrue);
    });

    test('a capture that finishes after dispose does not notify', () async {
      final gate = Completer<Uint8List?>();
      final controller = CommunityComposerMediaController(
        posterCapture: (file) => gate.future,
      );
      controller.add([_video('clip.mp4')]);
      controller.dispose();
      gate.complete(_posterBytes);
      await _settle();
    });
  });

  group('posters switched off', () {
    test('selecting a video launches no capture at all', () async {
      var captures = 0;
      final controller = CommunityComposerMediaController(
        postersEnabled: false,
        posterCapture: (file) async {
          captures++;
          return _posterBytes;
        },
      )..add([_video('clip.mp4')]);
      await _settle();
      expect(captures, 0, reason: 'no thumbnail decoding when posters are off');
      expect(controller.items.single.posterBytes, isNull);
    });

    test('a stored poster is never uploaded, and the video goes up alone',
        () async {
      final uploader = _RecordingUploader();
      final controller = CommunityComposerMediaController(postersEnabled: false)
        ..add([_video('clip.mp4')]);
      await _settle();
      final item = controller.items.single;
      item.posterBytes = _posterBytes;

      final reference = await uploadCommunityComposerMediaItemWith(
        item,
        uploadFile: uploader.call,
        postersEnabled: false,
      );

      expect(uploader.fileTypes, <String>['post-video']);
      expect(reference, _uploadedVideo);
      expect(communityMediaPosterReference(reference), isNull);
    });

    test('publish is unchanged apart from the missing poster', () async {
      final uploader = _RecordingUploader();
      var captures = 0;
      final controller = CommunityComposerMediaController(
        postersEnabled: false,
        posterCapture: (file) async {
          captures++;
          return _posterBytes;
        },
      )..add([_video('clip.mp4'), _image('photo.jpg')]);
      await _settle();

      List<String>? submitted;
      await controller.publish(
        upload: (item) => uploadCommunityComposerMediaItemWith(
          item,
          uploadFile: uploader.call,
          postersEnabled: false,
        ),
        submit: (urls) async {
          submitted = urls;
          return 'created';
        },
      );

      expect(captures, 0);
      expect(uploader.fileTypes, <String>['post-video', 'post-image']);
      expect(submitted, <String>[_uploadedVideo, _uploadedPoster]);
      expect(controller.publishError, isNull);
    });
  });

  group('uploading the poster', () {
    test('the video is uploaded first, then the poster as an image', () async {
      final uploader = _RecordingUploader();
      final item = await _withPoster(_video('clip.mp4'));

      final reference = await uploadCommunityComposerMediaItemWith(
        item,
        uploadFile: uploader.call,
      );

      expect(uploader.fileTypes, <String>['post-video', 'post-image']);
      expect(uploader.compressFlags, <bool>[true, false]);
      expect(uploader.fileNames, <String>['clip.mp4', 'clip-poster.jpg']);
      expect(communityMediaUrlIsVideo(reference), isTrue);
      expect(communityMediaPosterReference(reference), _uploadedPoster);
      expect(communityMediaVideoSourceUrl(reference), _uploadedVideo);
    });

    test('a failed poster upload publishes the video without a poster',
        () async {
      final uploader = _RecordingUploader(failPoster: true);
      final item = await _withPoster(_video('clip.mp4'));

      final reference = await uploadCommunityComposerMediaItemWith(
        item,
        uploadFile: uploader.call,
      );

      expect(reference, _uploadedVideo);
      expect(communityMediaPosterReference(reference), isNull);
      expect(item.status, CommunityComposerUploadStatus.pending);
    });

    test('a video without a captured poster is one upload', () async {
      final uploader = _RecordingUploader();
      final controller = CommunityComposerMediaController(
        posterCapture: (file) async => null,
      )..add([_video('clip.mp4')]);
      await _settle();

      final reference = await uploadCommunityComposerMediaItemWith(
        controller.items.single,
        uploadFile: uploader.call,
      );
      expect(uploader.fileTypes, <String>['post-video']);
      expect(reference, _uploadedVideo);
    });

    test('an image is uploaded once and never gets a poster', () async {
      final uploader = _RecordingUploader();
      final controller = CommunityComposerMediaController()
        ..add([_image('photo.jpg')]);
      final reference = await uploadCommunityComposerMediaItemWith(
        controller.items.single,
        uploadFile: uploader.call,
      );
      expect(uploader.fileTypes, <String>['post-image']);
      expect(reference, isNot(contains('#')));
    });

    test('publish submits the video with its poster hint', () async {
      final uploader = _RecordingUploader();
      final controller = CommunityComposerMediaController(
        posterCapture: (file) async => _posterBytes,
      )..add([_video('clip.mp4')]);
      await _settle();

      List<String>? submitted;
      await controller.publish(
        upload: (item) => uploadCommunityComposerMediaItemWith(
          item,
          uploadFile: uploader.call,
        ),
        submit: (urls) async {
          submitted = urls;
          return 'created';
        },
      );

      expect(submitted, isNotNull);
      expect(submitted!.single, contains('#kubus-media=video'));
      expect(communityMediaPosterReference(submitted!.single), _uploadedPoster);
      expect(controller.isEmpty, isTrue);
    });

    test('publish still goes through when the poster upload fails', () async {
      final uploader = _RecordingUploader(failPoster: true);
      final controller = CommunityComposerMediaController(
        posterCapture: (file) async => _posterBytes,
      )..add([_video('clip.mp4')]);
      await _settle();

      List<String>? submitted;
      await controller.publish(
        upload: (item) => uploadCommunityComposerMediaItemWith(
          item,
          uploadFile: uploader.call,
        ),
        submit: (urls) async {
          submitted = urls;
          return 'created';
        },
      );

      expect(submitted, <String>[_uploadedVideo]);
      expect(controller.publishError, isNull);
    });
  });
}

/// A video item with its poster already captured, built through the public
/// composer path.
Future<CommunityComposerMediaItem> _withPoster(
  CommunityComposerPickedMedia picked,
) async {
  final controller = CommunityComposerMediaController(
    posterCapture: (file) async => _posterBytes,
  )..add([picked]);
  await _settle();
  return controller.items.single;
}
