import 'dart:async';
import 'dart:typed_data';

import 'package:art_kubus/community/community_composer_media.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

CommunityComposerPickedMedia _image(String name) =>
    CommunityComposerPickedMedia(
      file: XFile.fromData(
        Uint8List.fromList(<int>[1, 2, 3]),
        path: name,
        mimeType: 'image/jpeg',
      ),
      kind: CommunityComposerMediaKind.image,
      imageBytes: Uint8List.fromList(<int>[1, 2, 3]),
    );

CommunityComposerPickedMedia _video(String name) =>
    CommunityComposerPickedMedia(
      file: XFile.fromData(
        Uint8List.fromList(<int>[9, 9]),
        path: name,
        mimeType: 'video/mp4',
      ),
      kind: CommunityComposerMediaKind.video,
    );

Future<String> _uploadByName(CommunityComposerMediaItem item) async =>
    '/uploads/${item.name}';

void main() {
  group('publish transaction', () {
    test('stays locked from the first upload until the create call settles',
        () async {
      final controller = CommunityComposerMediaController()
        ..add([_image('a.jpg'), _image('b.jpg')]);
      final create = Completer<String>();

      final publishing = controller.publish<String>(
        upload: _uploadByName,
        submit: (urls) => create.future,
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.isLocked, isTrue);
      expect(controller.add([_image('c.jpg')]), 0);
      controller
        ..remove(controller.items.first.id)
        ..clear()
        ..reorder(0, 1);
      expect(controller.length, 2);

      create.complete('post-1');
      expect(await publishing, 'post-1');
      expect(controller.isLocked, isFalse);
    });

    test('clears the draft only after the create call succeeds', () async {
      final controller = CommunityComposerMediaController()
        ..add([_image('a.jpg'), _video('b.mp4')]);

      await controller.publish<String>(
        upload: _uploadByName,
        submit: (urls) async {
          expect(urls, ['/uploads/a.jpg', '/uploads/b.mp4']);
          expect(controller.length, 2, reason: 'draft kept during create');
          return 'post-1';
        },
      );

      expect(controller.isEmpty, isTrue);
    });

    test('a failed create keeps the media, its order and every uploaded URL',
        () async {
      final controller = CommunityComposerMediaController()
        ..add([_image('a.jpg'), _video('b.mp4'), _image('c.jpg')]);
      final uploaded = <String>[];

      await expectLater(
        controller.publish<void>(
          upload: (item) async {
            uploaded.add(item.name);
            return '/uploads/${item.name}';
          },
          submit: (urls) async => throw StateError('create failed'),
        ),
        throwsStateError,
      );

      expect(controller.isLocked, isFalse);
      expect(controller.length, 3);
      expect(
        controller.items.map((item) => item.name).toList(),
        ['a.jpg', 'b.mp4', 'c.jpg'],
      );
      expect(controller.uploadedUrls,
          ['/uploads/a.jpg', '/uploads/b.mp4', '/uploads/c.jpg']);
      expect(uploaded, ['a.jpg', 'b.mp4', 'c.jpg']);
    });

    test('a retry reuses completed uploads and submits the ordered URLs',
        () async {
      final controller = CommunityComposerMediaController()
        ..add([_image('a.jpg'), _video('b.mp4'), _image('c.jpg')]);
      var failFirstAttempt = true;
      final attempts = <String>[];

      Future<String> flakyUpload(CommunityComposerMediaItem item) async {
        attempts.add(item.name);
        if (item.name == 'b.mp4' && failFirstAttempt) {
          throw StateError('network');
        }
        return '/uploads/${item.name}';
      }

      await expectLater(
        controller.publish<void>(
          upload: flakyUpload,
          submit: (urls) async {},
        ),
        throwsStateError,
      );
      failFirstAttempt = false;
      attempts.clear();

      List<String>? submitted;
      await controller.publish<void>(
        upload: flakyUpload,
        submit: (urls) async => submitted = urls,
      );

      expect(attempts, ['b.mp4', 'c.jpg'], reason: 'a.jpg is not re-uploaded');
      expect(submitted, ['/uploads/a.jpg', '/uploads/b.mp4', '/uploads/c.jpg']);
      expect(controller.isEmpty, isTrue);
    });

    test('a second publish is refused while one is in flight', () async {
      final controller = CommunityComposerMediaController()
        ..add([_image('a.jpg')]);
      final create = Completer<String>();
      final first = controller.publish<String>(
        upload: _uploadByName,
        submit: (urls) => create.future,
      );
      await Future<void>.delayed(Duration.zero);

      await expectLater(
        controller.publish<String>(
          upload: _uploadByName,
          submit: (urls) async => 'duplicate',
        ),
        throwsStateError,
      );

      create.complete('post-1');
      expect(await first, 'post-1');
    });

    test(
        'persistent failure feedback retains the submission key until explicit clear',
        () async {
      final controller = CommunityComposerMediaController();
      final key = controller.submissionKey;
      final failure = StateError('create failed');
      await expectLater(
          controller.publish<String>(
              upload: _uploadByName, submit: (_) async => throw failure),
          throwsA(same(failure)));
      expect(controller.publishError, same(failure));
      expect(controller.submissionKey, key);
      expect(controller.isLocked, isFalse);
      controller.clear();
      expect(controller.publishError, isNull);
      expect(controller.submissionKey, isNot(key));
    });

    test('a publish after success starts from an empty, unlocked composer',
        () async {
      final controller = CommunityComposerMediaController()
        ..add([_image('a.jpg')]);
      await controller.publish<String>(
        upload: _uploadByName,
        submit: (urls) async => 'post-1',
      );

      expect(controller.isLocked, isFalse);
      controller.add([_image('next.jpg')]);
      expect(controller.length, 1);
    });
  });
}
