import 'dart:async';
import 'dart:typed_data';

import 'package:art_kubus/community/community_composer_media.dart';
import 'package:art_kubus/services/backend_api_service.dart';
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

List<String> _names(CommunityComposerMediaController controller) =>
    controller.items.map((item) => item.name).toList();

void main() {
  group('ordering and kinds', () {
    test('keeps picks in order across images and videos', () {
      final controller = CommunityComposerMediaController();
      controller.add([_image('a.jpg'), _image('b.jpg')]);
      controller.add([_video('c.mp4')]);
      controller.add([_image('d.jpg')]);

      expect(_names(controller), ['a.jpg', 'b.jpg', 'c.mp4', 'd.jpg']);
      expect(controller.hasImages, isTrue);
      expect(controller.hasVideos, isTrue);
      expect(controller.items[2].isVideo, isTrue);
      expect(controller.items[2].imageBytes, isNull);
      expect(controller.items[0].imageBytes, isNotNull);
    });

    test('allows several videos in one post', () {
      final controller = CommunityComposerMediaController();
      controller.add([_video('one.mp4')]);
      controller.add([_video('two.mp4')]);
      expect(controller.length, 2);
      expect(controller.items.every((item) => item.isVideo), isTrue);
    });
  });

  group('ten-item limit', () {
    test('caps the collection at ten items, counting videos too', () {
      final controller = CommunityComposerMediaController();
      final added = controller.add([
        for (var i = 0; i < 8; i++) _image('img$i.jpg'),
        _video('v1.mp4'),
        _video('v2.mp4'),
        _image('overflow.jpg'),
      ]);

      expect(added, 10);
      expect(controller.length, 10);
      expect(controller.isFull, isTrue);
      expect(controller.remainingSlots, 0);
      expect(_names(controller), isNot(contains('overflow.jpg')));
      expect(controller.add([_image('late.jpg')]), 0);
    });

    test('accepts exactly ten picks in one interaction', () {
      final controller = CommunityComposerMediaController();
      final added = controller.add([
        for (var i = 0; i < 10; i++) _image('img$i.jpg'),
      ]);
      expect(added, 10);
      expect(controller.isFull, isTrue);
    });
  });

  group('removal and reordering', () {
    test('removes an item by id and leaves the rest in order', () {
      final controller = CommunityComposerMediaController();
      controller.add([_image('a.jpg'), _image('b.jpg'), _image('c.jpg')]);
      final middleId = controller.items[1].id;

      controller.remove(middleId);

      expect(_names(controller), ['a.jpg', 'c.jpg']);
    });

    test('moves an item to a final index, matching onReorderItem', () {
      final controller = CommunityComposerMediaController();
      controller.add([_image('a'), _image('b'), _image('c'), _image('d')]);

      controller.reorder(0, 2);
      expect(_names(controller), ['b', 'c', 'a', 'd']);

      controller.reorder(3, 0);
      expect(_names(controller), ['d', 'b', 'c', 'a']);
    });

    test('moveBy ignores moves past either end', () {
      final controller = CommunityComposerMediaController();
      controller.add([_image('a'), _image('b')]);
      final firstId = controller.items.first.id;
      final lastId = controller.items.last.id;

      controller.moveBy(firstId, -1);
      controller.moveBy(lastId, 1);
      expect(_names(controller), ['a', 'b']);

      controller.moveBy(firstId, 1);
      expect(_names(controller), ['b', 'a']);
    });

    test('ignores edits while an upload is in progress', () async {
      final controller = CommunityComposerMediaController();
      controller.add([_image('a'), _image('b')]);
      final gate = Completer<String>();
      final pending = controller.uploadPending((_) => gate.future);

      controller
        ..remove(controller.items.first.id)
        ..clear()
        ..reorder(0, 1);
      expect(controller.length, 2);

      gate.complete('/uploads/a.jpg');
      await pending.catchError((_) => <String>[]);
    });
  });

  group('uploads', () {
    test('uploads in order and returns URLs in composer order', () async {
      final controller = CommunityComposerMediaController();
      controller.add([_image('a.jpg'), _video('b.mp4'), _image('c.jpg')]);
      final uploaded = <String>[];

      final urls = await controller.uploadPending((item) async {
        uploaded.add(item.name);
        return '/uploads/${item.name}';
      });

      expect(uploaded, ['a.jpg', 'b.mp4', 'c.jpg']);
      expect(urls, ['/uploads/a.jpg', '/uploads/b.mp4', '/uploads/c.jpg']);
      expect(
          controller.items.every(
            (item) => item.status == CommunityComposerUploadStatus.uploaded,
          ),
          isTrue);
    });

    test('a partial failure keeps completed items and retries only the rest',
        () async {
      final controller = CommunityComposerMediaController();
      controller.add([_image('a.jpg'), _image('b.jpg'), _image('c.jpg')]);
      final attempts = <String>[];
      var failSecond = true;

      Future<String> upload(CommunityComposerMediaItem item) async {
        attempts.add(item.name);
        if (item.name == 'b.jpg' && failSecond) {
          throw StateError('network dropped');
        }
        return '/uploads/${item.name}';
      }

      await expectLater(
        controller.uploadPending(upload),
        throwsA(isA<StateError>()),
      );
      expect(attempts, ['a.jpg', 'b.jpg']);
      expect(
          controller.items[0].status, CommunityComposerUploadStatus.uploaded);
      expect(controller.items[1].status, CommunityComposerUploadStatus.failed);
      expect(controller.items[2].status, CommunityComposerUploadStatus.pending);
      expect(controller.hasFailedUploads, isTrue);
      expect(controller.unuploadedCount, 2);

      failSecond = false;
      attempts.clear();
      final urls = await controller.uploadPending(upload);

      expect(attempts, ['b.jpg', 'c.jpg'],
          reason: 'the completed first item must not be re-uploaded');
      expect(urls, ['/uploads/a.jpg', '/uploads/b.jpg', '/uploads/c.jpg']);
    });

    test('a fully uploaded composer makes no further upload calls', () async {
      final controller = CommunityComposerMediaController();
      controller.add([_image('a.jpg')]);
      await controller.uploadPending((item) async => '/uploads/a.jpg');

      var calls = 0;
      final urls = await controller.uploadPending((item) async {
        calls++;
        return '/uploads/again.jpg';
      });

      expect(calls, 0);
      expect(urls, ['/uploads/a.jpg']);
    });

    test('a rate-limit rejection stops the run and keeps its type', () async {
      final controller = CommunityComposerMediaController();
      controller.add([_image('a.jpg'), _image('b.jpg')]);
      var calls = 0;

      final error = await controller
          .uploadPending((item) async {
            calls++;
            throw UploadRateLimitedException(
              path: '/api/upload',
              retryAfter: const Duration(seconds: 90),
              errorCode: 'UPLOAD_RATE_LIMITED',
            );
          })
          .then<Object?>((_) => null)
          .catchError((Object e) => e);

      expect(error, isA<UploadRateLimitedException>());
      expect((error! as UploadRateLimitedException).retryAfter,
          const Duration(seconds: 90));
      expect(calls, 1, reason: 'the second item must not be attempted');
      expect(controller.items[1].status, CommunityComposerUploadStatus.pending);
    });

    test('an empty upload URL is treated as a failure', () async {
      final controller = CommunityComposerMediaController();
      controller.add([_image('a.jpg')]);

      await expectLater(
        controller.uploadPending((_) async => '   '),
        throwsA(isA<StateError>()),
      );
      expect(
          controller.items.single.status, CommunityComposerUploadStatus.failed);
    });

    test('refuses a second concurrent upload run', () async {
      final controller = CommunityComposerMediaController();
      controller.add([_image('a.jpg')]);
      final gate = Completer<String>();
      final first = controller.uploadPending((_) => gate.future);

      await expectLater(
        controller.uploadPending((_) async => '/uploads/b.jpg'),
        throwsA(isA<StateError>()),
      );

      gate.complete('/uploads/a.jpg');
      expect(await first, ['/uploads/a.jpg']);
    });

    test('notifies listeners as upload state changes', () async {
      final controller = CommunityComposerMediaController();
      controller.add([_image('a.jpg')]);
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.uploadPending((_) async => '/uploads/a.jpg');

      expect(notifications, greaterThanOrEqualTo(3));
    });
  });
}
