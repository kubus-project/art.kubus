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

  Future<SpatialCaptureStore> openStore([String id = 'cap-1']) =>
      SpatialCaptureStore.create(captureId: id, root: root);

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

      await store.writeManifest(
        artworkId: 'art-1',
        markerId: 'marker-1',
        capturedBy: 'user-1',
        startedAt: DateTime.utc(2026, 1, 1),
      );

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
      final store = await openStore('cap-interrupted');
      await store.writeSample(rgb: bytes(8));
      await store.writeManifest(
        artworkId: 'art-1',
        startedAt: DateTime.utc(2026, 5, 1),
      );

      final found = await SpatialCaptureStore.findInterrupted(root: root);

      expect(found, hasLength(1));
      expect(found.single.captureId, 'cap-interrupted');
      expect(found.single.sampleCount, 1);
      expect(found.single.transferred, isFalse);
    });

    test('a capture without a manifest is ignored', () async {
      await openStore('cap-no-manifest');

      expect(await SpatialCaptureStore.findInterrupted(root: root), isEmpty);
    });

    test('markTransferred flips the recovery flag', () async {
      final store = await openStore('cap-sent');
      await store.writeSample(rgb: bytes(8));
      await store.writeManifest(
        artworkId: 'art-1',
        startedAt: DateTime.utc(2026, 5, 1),
      );

      await store.markTransferred();

      final found = await SpatialCaptureStore.findInterrupted(root: root);
      expect(found.single.transferred, isTrue);
    });
  });

  group('cleanup', () {
    Future<void> seed(String id, DateTime startedAt,
        {required bool transferred}) async {
      final store = await SpatialCaptureStore.create(captureId: id, root: root);
      await store.writeSample(rgb: bytes(8));
      await store.writeManifest(artworkId: 'art-1', startedAt: startedAt);
      if (transferred) await store.markTransferred();
    }

    test('a delivered capture is cleaned up', () async {
      await seed('sent', DateTime.utc(2026, 8, 1), transferred: true);

      final removed = await SpatialCaptureStore.cleanUp(
        root: root,
        now: DateTime.utc(2026, 8, 2),
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

    test('an abandoned capture past retention is reclaimed', () async {
      await seed('stale', DateTime.utc(2026, 1, 1), transferred: false);

      final removed = await SpatialCaptureStore.cleanUp(
        root: root,
        retention: const Duration(days: 7),
        now: DateTime.utc(2026, 8, 2),
      );

      expect(removed, 1);
    });
  });
}
