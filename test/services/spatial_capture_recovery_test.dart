import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:art_kubus/services/spatial_capture_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Uint8List bytes([int length = 16]) =>
    Uint8List.fromList(List<int>.filled(length, 7));

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kubus_recovery_');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<SpatialCaptureStore> openCapture({
    String captureId = 'capture-1',
    String artworkId = 'art-1',
    String capturedBy = 'wallet-1',
    DateTime? startedAt,
  }) =>
      SpatialCaptureStore.create(
        captureId: captureId,
        artworkId: artworkId,
        capturedBy: capturedBy,
        startedAt: startedAt,
        root: root,
      );

  group('an interrupted capture is discoverable', () {
    test('a capture is recorded before its first sample', () async {
      await openCapture();

      // No finish, no manifest write — just an opened capture, exactly what a
      // process killed one second in would leave behind.
      final found = await SpatialCaptureStore.findInterrupted(root: root);
      expect(found, hasLength(1));
      expect(found.single.captureId, 'capture-1');
      expect(found.single.artworkId, 'art-1');
      expect(found.single.capturedBy, 'wallet-1');
      expect(found.single.state, SpatialCaptureDirectoryState.capturing);
      expect(found.single.transferred, isFalse);
    });

    test('samples written mid-capture survive without a finish', () async {
      final store = await openCapture();
      for (var i = 0; i < 5; i++) {
        await store.writeSample(
          rgb: bytes(),
          metadata: <String, dynamic>{'timestampNanos': i},
        );
      }

      // The process "dies" here: writeManifest is never called.
      final found = await SpatialCaptureStore.findInterrupted(root: root);
      expect(found.single.sampleCount, 5,
          reason:
              'the append-only index reflects every sample already written');
      expect(found.single.hasRecoverableWork, isTrue);
      expect(found.single.wasCapturing, isTrue);
    });

    test('a reopened capture keeps its samples and can be extended', () async {
      final store = await openCapture();
      for (var i = 0; i < 4; i++) {
        await store.writeSample(
          rgb: bytes(),
          metadata: <String, dynamic>{'timestampNanos': i},
        );
      }

      final found = await SpatialCaptureStore.findInterrupted(root: root);
      final reopened = await SpatialCaptureStore.open(found.single.directory);

      expect(reopened, isNotNull);
      expect(reopened!.sampleCount, 4);
      expect(reopened.artworkId, 'art-1');
      expect(reopened.bytesWritten, greaterThan(0));

      // Continuing appends after the recovered samples rather than overwriting.
      await reopened.writeSample(
        rgb: bytes(),
        metadata: const <String, dynamic>{'timestampNanos': 99},
      );
      expect(reopened.sampleCount, 5);
      expect(await reopened.fileAt('rgb/00004.jpg').exists(), isTrue);
    });

    test('a truncated index line does not lose the samples before it',
        () async {
      final store = await openCapture();
      for (var i = 0; i < 3; i++) {
        await store.writeSample(
          rgb: bytes(),
          metadata: <String, dynamic>{'timestampNanos': i},
        );
      }
      // Simulate a crash midway through appending a fourth entry.
      final index = File(p.join(store.directory.path, 'frames.jsonl'));
      await index.writeAsString(
        '{"index":3,"rgbPath":"rgb/00003.jpg","byt',
        mode: FileMode.writeOnlyAppend,
        flush: true,
      );

      final reopened = await SpatialCaptureStore.open(store.directory);
      expect(reopened!.sampleCount, 3,
          reason: 'the partial trailing line is discarded, not the file');
    });
  });

  group('metadata survives a crash mid-write', () {
    test('the manifest is replaced atomically', () async {
      final store = await openCapture();
      await store.writeSample(rgb: bytes());
      await store.writeManifest();

      final manifest = File(p.join(store.directory.path, 'metadata.json'));
      final decoded =
          jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
      expect(decoded['state'], 'captured');

      // No temporary file is left behind once the rename has landed.
      final leftovers = store.directory
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.tmp'));
      expect(leftovers, isEmpty);
    });

    test('manifest extras survive later writes', () async {
      final store = await openCapture();
      await store.writeSample(rgb: bytes());
      await store.writeManifest(
        extra: const <String, dynamic>{'viewpointCount': 11},
      );

      // Recording a draft id and marking the capture delivered each rewrite
      // the manifest; neither may drop fields an earlier write established.
      await store.recordDraftId('draft-7');
      await store.markTransferred();

      final manifest = jsonDecode(
        await File(p.join(store.directory.path, 'metadata.json'))
            .readAsString(),
      ) as Map<String, dynamic>;
      expect((manifest['metadata'] as Map)['viewpointCount'], 11);
      expect(manifest['transferred'], isTrue);
    });

    test('a recorded draft id survives for transfer resume', () async {
      final store = await openCapture();
      await store.writeSample(rgb: bytes());
      await store.recordDraftId('draft-42');

      final found = await SpatialCaptureStore.findInterrupted(root: root);
      expect(found.single.draftId, 'draft-42');

      final reopened = await SpatialCaptureStore.open(store.directory);
      expect(reopened!.draftId, 'draft-42');
    });

    test('marking transferred keeps the rest of the manifest intact', () async {
      final store = await openCapture();
      await store.writeSample(rgb: bytes());
      await store.writeManifest();
      await store.markTransferred();

      final found = await SpatialCaptureStore.findInterrupted(root: root);
      expect(found.single.transferred, isTrue);
      expect(found.single.artworkId, 'art-1',
          reason: 'the transferred flag is updated in place, not by rewriting '
              'a partial document');
      expect(found.single.capturedBy, 'wallet-1');
    });
  });

  group('cleanup policy', () {
    // The policy, once: transferred captures expire, untransferred user work
    // never does, and only genuinely empty directories are swept.
    test('a delivered capture is reclaimed after the retention window',
        () async {
      final store = await openCapture(
        startedAt: DateTime.utc(2020, 1, 1),
      );
      await store.writeSample(rgb: bytes());
      await store.writeManifest();
      await store.markTransferred();

      final removed = await SpatialCaptureStore.cleanUp(
        root: root,
        retention: const Duration(days: 7),
        now: DateTime.utc(2020, 2, 1),
      );
      expect(removed, 1);
      expect(await store.directory.exists(), isFalse);
    });

    test('a delivered capture inside the retention window is kept', () async {
      final store = await openCapture(startedAt: DateTime.utc(2020, 1, 1));
      await store.writeSample(rgb: bytes());
      await store.writeManifest();
      await store.markTransferred();

      final removed = await SpatialCaptureStore.cleanUp(
        root: root,
        retention: const Duration(days: 7),
        now: DateTime.utc(2020, 1, 3),
      );
      expect(removed, 0);
      expect(await store.directory.exists(), isTrue);
    });

    test(
      'an untransferred capture is never deleted for being old',
      () async {
        final store = await openCapture(startedAt: DateTime.utc(2019, 1, 1));
        for (var i = 0; i < 12; i++) {
          await store.writeSample(rgb: bytes());
        }
        await store.writeManifest();

        final removed = await SpatialCaptureStore.cleanUp(
          root: root,
          retention: const Duration(days: 7),
          // Years later.
          now: DateTime.utc(2026, 1, 1),
        );

        expect(removed, 0);
        expect(
          await store.directory.exists(),
          isTrue,
          reason: 'work that never reached a node is not reclaimable by age',
        );
        final found = await SpatialCaptureStore.findInterrupted(root: root);
        expect(found.single.sampleCount, 12);
      },
    );

    test('a capture killed before its first frame is swept after the grace',
        () async {
      final store = await openCapture(startedAt: DateTime.utc(2020, 1, 1));

      // Still within the grace period: an empty directory could be a capture
      // that opened moments ago.
      var removed = await SpatialCaptureStore.cleanUp(
        root: root,
        now: DateTime.utc(2020, 1, 1, 1),
      );
      expect(removed, 0);
      expect(await store.directory.exists(), isTrue);

      removed = await SpatialCaptureStore.cleanUp(
        root: root,
        now: DateTime.utc(2020, 1, 2),
      );
      expect(removed, 1);
      expect(await store.directory.exists(), isFalse);
    });

    test('cleanup leaves a live capture with work alone', () async {
      final fresh = await openCapture(captureId: 'capture-live');
      await fresh.writeSample(rgb: bytes());

      final removed = await SpatialCaptureStore.cleanUp(root: root);
      expect(removed, 0);
      expect(await fresh.directory.exists(), isTrue);
    });
  });
}
