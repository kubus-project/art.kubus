import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:art_kubus/services/spatial_capture_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Uint8List bytes(int length, [int fill = 7]) =>
    Uint8List.fromList(List<int>.filled(length, fill));

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kubus_capture_test_');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<SpatialCaptureStore> openStore([
    String id = 'cap-1',
    DateTime? startedAt,
  ]) =>
      SpatialCaptureStore.create(
        captureId: id,
        artworkId: 'art-1',
        markerId: 'marker-1',
        capturedBy: 'user-1',
        startedAt: startedAt ?? DateTime.utc(2026, 1, 1),
        root: root,
      );

  group('incremental writes', () {
    test('an accepted sample is written to disk under the documented layout',
        () async {
      final store = await openStore();

      final record = await store.writeSample(
        rgb: bytes(128),
        metadata: const {'timestampNanos': 42},
      );

      expect(record.rgbPath, 'rgb/00000.jpg');
      expect(await store.fileAt('rgb/00000.jpg').exists(), isTrue);
      expect(store.sampleCount, 1);
      expect(store.bytesWritten, 128);
    });

    test('depth and confidence are optional', () async {
      final store = await openStore();

      final withDepth = await store.writeSample(
        rgb: bytes(10),
        depth: bytes(20),
        confidence: bytes(5),
      );
      final withoutDepth = await store.writeSample(rgb: bytes(10));

      expect(withDepth.depthPath, 'depth/00000.bin');
      expect(withDepth.confidencePath, 'confidence/00000.bin');
      expect(withDepth.bytes, 35);
      expect(withoutDepth.depthPath, isNull);
      expect(withoutDepth.confidencePath, isNull);
      expect(store.depthObserved, isTrue);
      expect(store.bytesWritten, 45);
    });

    test('samples are indexed in order', () async {
      final store = await openStore();

      for (var i = 0; i < 3; i++) {
        await store.writeSample(rgb: bytes(4));
      }

      expect(
        store.samples.map((s) => s.rgbPath),
        ['rgb/00000.jpg', 'rgb/00001.jpg', 'rgb/00002.jpg'],
      );
    });

    test('the store retains metadata but never image bytes', () async {
      final store = await openStore();

      await store.writeSample(
        rgb: bytes(4096),
        metadata: const {
          'poseTranslation': [1, 2, 3]
        },
      );

      final record = store.samples.single;
      expect(record.metadata['poseTranslation'], [1, 2, 3]);
      // The record exposes paths and a size, never a byte buffer.
      expect(record.toJson().values.whereType<Uint8List>(), isEmpty);
    });

    test('memory stays flat while bytes on disk grow', () async {
      final store = await openStore();

      for (var i = 0; i < 60; i++) {
        await store.writeSample(rgb: bytes(1024));
      }

      expect(store.bytesWritten, 60 * 1024);
      // Retained state is one small record per sample, not the payload.
      expect(store.samples, hasLength(60));
      expect(
        store.samples.fold<int>(0, (n, s) => n + s.metadata.length),
        isZero,
      );
    });
  });

  group('backpressure', () {
    test('pendingWrites is observable and settles back to zero', () async {
      final store = await openStore();
      expect(store.pendingWrites, isZero);

      final write = store.writeSample(rgb: bytes(64));
      await write;

      expect(store.pendingWrites, isZero);
    });
  });

  group('manifest', () {
    test('writeManifest records capture and frame indexes', () async {
      final store = await openStore();
      await store.writeSample(rgb: bytes(8), depth: bytes(8));

      await store.writeManifest();

      final manifest = jsonDecode(
        await File(p.join(store.directory.path, 'metadata.json'))
            .readAsString(),
      ) as Map<String, dynamic>;
      final frames = jsonDecode(
        await File(p.join(store.directory.path, 'frames.json')).readAsString(),
      ) as Map<String, dynamic>;

      expect(manifest['artworkId'], 'art-1');
      expect(manifest['transferred'], isFalse);
      expect((manifest['metadata'] as Map)['frameCount'], 1);
      expect((manifest['metadata'] as Map)['depthAvailable'], isTrue);
      expect((manifest['metadata'] as Map)['private'], isTrue);
      expect(frames['schema'], 'kubus.capture.frames/1');
      expect((frames['frames'] as List).single['rgbPath'], 'rgb/00000.jpg');
    });
  });

  group('lifecycle', () {
    test('discard removes the capture directory', () async {
      final store = await openStore();
      await store.writeSample(rgb: bytes(16));

      await store.discard();

      expect(await store.directory.exists(), isFalse);
      expect(store.isDiscarded, isTrue);
      expect(store.sampleCount, isZero);
    });

    test('writing to a discarded capture is rejected', () async {
      final store = await openStore();
      await store.discard();

      expect(
        () => store.writeSample(rgb: bytes(4)),
        throwsStateError,
      );
    });

    test('creating over an existing id starts clean', () async {
      final first = await openStore();
      await first.writeSample(rgb: bytes(4));

      final second = await openStore();

      expect(second.sampleCount, isZero);
      expect(await second.fileAt('rgb/00000.jpg').exists(), isFalse);
    });
  });

  group('restart recovery', () {
    test('an interrupted capture is discoverable after restart', () async {
      final store =
          await openStore('cap-interrupted', DateTime.utc(2026, 5, 1));
      await store.writeSample(rgb: bytes(8));
      await store.writeManifest();

      final found = await SpatialCaptureStore.findInterrupted(root: root);

      expect(found, hasLength(1));
      expect(found.single.captureId, 'cap-interrupted');
      expect(found.single.sampleCount, 1);
      expect(found.single.transferred, isFalse);
    });

    test('a directory with no manifest at all is ignored', () async {
      // Not something the store produces any more — it records a capture on
      // creation — but foreign debris in the capture root must not be treated
      // as recoverable work.
      await Directory(p.join(root.path, 'not-a-capture')).create();

      expect(await SpatialCaptureStore.findInterrupted(root: root), isEmpty);
    });

    test('markTransferred flips the recovery flag', () async {
      final store = await openStore('cap-sent', DateTime.utc(2026, 5, 1));
      await store.writeSample(rgb: bytes(8));
      await store.writeManifest();

      await store.markTransferred();

      final found = await SpatialCaptureStore.findInterrupted(root: root);
      expect(found.single.transferred, isTrue);
    });
  });

  group('cleanup', () {
    Future<SpatialCaptureStore> seed(
      String id,
      DateTime startedAt, {
      required bool transferred,
      int samples = 1,
    }) async {
      final store = await openStore(id, startedAt);
      for (var i = 0; i < samples; i++) {
        await store.writeSample(rgb: bytes(8));
      }
      await store.writeManifest();
      if (transferred) await store.markTransferred();
      return store;
    }

    test('a delivered capture is cleaned up once retention has passed',
        () async {
      await seed('sent', DateTime.utc(2026, 8, 1), transferred: true);

      // Still inside the window: the node has it, but the local staging copy
      // is kept for a while in case the user comes back to it.
      expect(
        await SpatialCaptureStore.cleanUp(
          root: root,
          now: DateTime.utc(2026, 8, 2),
        ),
        isZero,
      );

      final removed = await SpatialCaptureStore.cleanUp(
        root: root,
        now: DateTime.utc(2026, 9, 1),
      );

      expect(removed, 1);
      expect(await SpatialCaptureStore.findInterrupted(root: root), isEmpty);
    });

    test('an undelivered recent capture is preserved for retry', () async {
      await seed('pending', DateTime.utc(2026, 8, 1), transferred: false);

      final removed = await SpatialCaptureStore.cleanUp(
        root: root,
        now: DateTime.utc(2026, 8, 2),
      );

      expect(removed, isZero,
          reason: 'a valuable scan must not be silently deleted');
      expect(
          await SpatialCaptureStore.findInterrupted(root: root), hasLength(1));
    });

    test(
      'an old undelivered capture is still preserved',
      () async {
        // The previous implementation deleted this while its own comment
        // promised the opposite. The policy is now one thing: work that never
        // reached a node is not reclaimable by age.
        await seed('stale', DateTime.utc(2026, 1, 1), transferred: false);

        final removed = await SpatialCaptureStore.cleanUp(
          root: root,
          retention: const Duration(days: 7),
          now: DateTime.utc(2026, 8, 2),
        );

        expect(removed, isZero);
        expect(
          await SpatialCaptureStore.findInterrupted(root: root),
          hasLength(1),
        );
      },
    );
  });

  group('transfer package validation', () {
    test('a complete capture validates and lists every file in upload order',
        () async {
      final store = await openStore();
      await store.writeSample(
        rgb: bytes(64),
        depth: bytes(32),
        confidence: bytes(16),
        metadata: const {'timestampNanos': 1},
      );
      await store
          .writeSample(rgb: bytes(64), metadata: const {'timestampNanos': 2});
      await store.writeManifest();

      final entries = await store.validateTransferPackage();

      expect(
        entries.map((e) => e.path),
        <String>[
          'rgb/00000.jpg',
          'depth/00000.bin',
          'confidence/00000.bin',
          'rgb/00001.jpg',
          'frames.json',
        ],
      );
    });

    test('a missing image is a typed source failure, never a silent skip',
        () async {
      final store = await openStore();
      await store
          .writeSample(rgb: bytes(64), metadata: const {'timestampNanos': 1});
      await store
          .writeSample(rgb: bytes(64), metadata: const {'timestampNanos': 2});
      await store.writeManifest();
      // Exactly the shape the node reported: the manifest references the
      // frame, the file is gone.
      await store.fileAt('rgb/00000.jpg').delete();

      await expectLater(
        store.validateTransferPackage(),
        throwsA(
          isA<SpatialSourceIncomplete>()
              .having((e) => e.problem, 'problem',
                  SpatialSourceProblem.filesMissing)
              .having((e) => e.missingPaths, 'missingPaths', ['rgb/00000.jpg'])
              .having((e) => e.code, 'code', 'source_incomplete')
              .having((e) => e.availableFiles, 'availableFiles', 2)
              .having((e) => e.expectedFiles, 'expectedFiles', 3),
        ),
      );
    });

    test('an empty file counts as missing', () async {
      final store = await openStore();
      await store
          .writeSample(rgb: bytes(64), metadata: const {'timestampNanos': 1});
      await store.writeManifest();
      await store.fileAt('rgb/00000.jpg').writeAsBytes(const <int>[]);

      await expectLater(
        store.validateTransferPackage(),
        throwsA(isA<SpatialSourceIncomplete>()
            .having((e) => e.missingPaths, 'missingPaths', ['rgb/00000.jpg'])),
      );
    });
  });

  group('legacy captures without a canonical frame document', () {
    /// A capture interrupted before it was finished: samples and their files
    /// are on disk and indexed, `frames.json` was never written.
    Future<SpatialCaptureStore> legacyCapture({int samples = 2}) async {
      final store = await openStore();
      for (var index = 0; index < samples; index++) {
        await store.writeSample(
          rgb: bytes(64),
          depth: bytes(32),
          confidence: bytes(16),
          metadata: {'timestampNanos': index},
        );
      }
      // No writeManifest(): this is what a crash mid-capture leaves.
      await store.fileAt('frames.json').delete().catchError((_) => File(''));
      final reopened = await SpatialCaptureStore.open(store.directory);
      return reopened!;
    }

    test('is repaired from the durable sample index before transfer', () async {
      final store = await legacyCapture();
      expect(await store.fileAt('frames.json').exists(), isFalse);

      final entries = await store.validateTransferPackage();

      expect(await store.fileAt('frames.json').exists(), isTrue);
      final document =
          jsonDecode(await store.fileAt('frames.json').readAsString())
              as Map<String, dynamic>;
      expect(document['schema'], 'kubus.capture.frames/1');
      expect((document['frames'] as List).length, 2);
      expect(entries.map((e) => e.path), contains('frames.json'));
    });

    test('rebuilds only what the index already recorded', () async {
      final store = await legacyCapture(samples: 1);

      await store.ensureCanonicalFrames();

      final frames = (jsonDecode(
        await store.fileAt('frames.json').readAsString(),
      ) as Map<String, dynamic>)['frames'] as List;
      final frame = frames.single as Map<String, dynamic>;
      expect(frame['rgbPath'], 'rgb/00000.jpg');
      expect(frame['depthPath'], 'depth/00000.bin');
      expect(frame['timestampNanos'], 0);
      // Nothing the capture never recorded appears in the rebuilt document.
      expect(frame.containsKey('poseTranslation'), isFalse);
    });

    test('a second repair pass is a no-op', () async {
      final store = await legacyCapture();
      expect(await store.ensureCanonicalFrames(), isTrue);
      final first = await store.fileAt('frames.json').readAsString();

      expect(await store.ensureCanonicalFrames(), isTrue);

      expect(await store.fileAt('frames.json').readAsString(), first);
    });

    test('an unreadable frame document is rebuilt rather than trusted',
        () async {
      final store = await legacyCapture();
      await store.fileAt('frames.json').writeAsString('{truncated');

      expect(await store.ensureCanonicalFrames(), isTrue);

      final document =
          jsonDecode(await store.fileAt('frames.json').readAsString())
              as Map<String, dynamic>;
      expect((document['frames'] as List).length, 2);
    });

    test('a document naming a depth map the index does not have is rebuilt',
        () async {
      final store = await legacyCapture(samples: 1);
      // Parses, names the right image, and still promises a depth map the
      // capture never recorded — which the Node would refuse with a path
      // nobody can resend.
      await store.fileAt('frames.json').writeAsString(jsonEncode({
            'schema': 'kubus.capture.frames/1',
            'frames': [
              {
                'rgbPath': 'rgb/00000.jpg',
                'depthPath': 'depth/00007.bin',
                'depthConfidencePath': 'confidence/00000.bin',
              },
            ],
          }));

      expect(await store.ensureCanonicalFrames(), isTrue);

      final frame = ((jsonDecode(
        await store.fileAt('frames.json').readAsString(),
      ) as Map<String, dynamic>)['frames'] as List)
          .single as Map<String, dynamic>;
      expect(frame['depthPath'], 'depth/00000.bin');
      expect(frame['depthConfidencePath'], 'confidence/00000.bin');
      await store.validateTransferPackage();
    });

    test('a capture with no recorded samples stays unrepairable and intact',
        () async {
      final store = await openStore();

      expect(await store.ensureCanonicalFrames(), isFalse);
      await expectLater(
        store.validateTransferPackage(),
        throwsA(isA<SpatialSourceIncomplete>()
            .having((e) => e.problem, 'problem',
                SpatialSourceProblem.framesUnrepairable)
            .having((e) => e.code, 'code', 'source_frames_unrepairable')),
      );
      // Preserved, not destroyed: an unrepairable capture is still the user's.
      expect(await store.directory.exists(), isTrue);
      expect(await store.fileAt('frames.json').exists(), isFalse);
    });
  });
}
