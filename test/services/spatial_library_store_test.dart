import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:art_kubus/services/spatial_capture_store.dart';
import 'package:art_kubus/services/spatial_library_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late Directory libraryRoot;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('capture-temp-');
    libraryRoot = Directory('${root.path}-library');
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
    if (await libraryRoot.exists()) await libraryRoot.delete(recursive: true);
  });

  test('promotes a meaningful private capture before Node transfer', () async {
    final capture = await SpatialCaptureStore.create(
      captureId: 'local-spatial-1',
      artworkId: 'art-1',
      capturedBy: 'owner-1',
      root: root,
    );
    await capture.writeSample(
      rgb: Uint8List.fromList(List<int>.filled(32, 4)),
      metadata: const {'timestampNanos': 1},
    );

    final library = SpatialLibraryStore(root: libraryRoot);
    final record = await library.promoteCapture(capture);
    final afterRestart = await library.list();

    expect(record.localSpatialId, 'local-spatial-1');
    expect(
        record.processingState, SpatialLibraryProcessingState.capturedPrivate);
    expect(record.rawPresent, isTrue);
    expect(await Directory(record.sourcePath).exists(), isTrue);
    expect(afterRestart.single.localSpatialId, record.localSpatialId);
    expect(afterRestart.single.sampleCount, 1);
  });

  test('promotion keeps the original recoverable until record commit',
      () async {
    final capture = await SpatialCaptureStore.create(
      captureId: 'commit-interruption',
      artworkId: 'art-1',
      root: root,
    );
    await capture.writeSample(rgb: Uint8List.fromList(<int>[1, 2, 3]));
    final interrupted = SpatialLibraryStore(
      root: libraryRoot,
      beforeRecordCommit: (_) async => throw FileSystemException('simulated'),
    );

    await expectLater(interrupted.promoteCapture(capture), throwsA(anything));

    expect(await capture.directory.exists(), isTrue);
    expect(await interrupted.get(capture.captureId), isNull);
    final recovered =
        await SpatialLibraryStore(root: libraryRoot).promoteCapture(capture);
    expect(
        await File(
                '${(await SpatialLibraryStore(root: libraryRoot).recordDirectory(recovered.localSpatialId)).path}${Platform.pathSeparator}record.json')
            .exists(),
        isTrue);
    expect(await Directory(recovered.sourcePath).exists(), isTrue);
  });

  test('restart normalizes abandoned processing states to retryable records',
      () async {
    final capture = await SpatialCaptureStore.create(
      captureId: 'interrupted-processing',
      artworkId: 'art-1',
      root: root,
    );
    await capture.writeSample(rgb: Uint8List.fromList(<int>[1, 2, 3]));
    final library = SpatialLibraryStore(root: libraryRoot);
    final record = await library.promoteCapture(capture);
    await library.updateProcessing(
      record.localSpatialId,
      SpatialLibraryProcessingState.processing,
    );

    final recovered = await library.recoverInterruptedProcessing();

    expect(recovered.single.processingState,
        SpatialLibraryProcessingState.failedRetryable);
    expect(recovered.single.lastErrorCode, 'processing_interrupted');
    expect((await library.get(record.localSpatialId))!.rawPresent, isTrue);
  });

  test('migrates legacy capture-temp idempotently without deleting raw data',
      () async {
    final capture = await SpatialCaptureStore.create(
      captureId: 'legacy-1',
      artworkId: 'art-1',
      root: root,
    );
    await capture.writeSample(rgb: Uint8List.fromList([1, 2, 3]));
    final library = SpatialLibraryStore(root: libraryRoot);

    expect(await library.migrateLegacy(root), hasLength(1));
    expect(await library.migrateLegacy(root), isEmpty);
    final record = (await library.list()).single;
    expect(await Directory(record.sourcePath).exists(), isTrue);
    expect(record.rawPresent, isTrue);
  });

  test('migration ignores empty and corrupt folders without deleting them',
      () async {
    final empty = await SpatialCaptureStore.create(
      captureId: 'empty',
      artworkId: 'art-1',
      root: root,
    );
    final corrupt = Directory('${root.path}${Platform.pathSeparator}corrupt');
    await corrupt.create(recursive: true);
    await File('${corrupt.path}${Platform.pathSeparator}metadata.json')
        .writeAsString('{truncated');
    await File('${corrupt.path}${Platform.pathSeparator}rgb.jpg')
        .writeAsBytes(<int>[1, 2, 3]);

    final migrated =
        await SpatialLibraryStore(root: libraryRoot).migrateLegacy(root);

    expect(migrated, isEmpty);
    expect(await empty.directory.exists(), isTrue);
    expect(await corrupt.exists(), isTrue);
  });

  test('migration preserves all valid lines before a truncated frame entry',
      () async {
    final capture = await SpatialCaptureStore.create(
      captureId: 'truncated-index',
      artworkId: 'art-1',
      root: root,
    );
    await capture.writeSample(rgb: Uint8List.fromList(<int>[1, 2, 3]));
    await capture.writeSample(rgb: Uint8List.fromList(<int>[4, 5, 6]));
    await File('${capture.directory.path}${Platform.pathSeparator}frames.jsonl')
        .writeAsString('{"index":', mode: FileMode.writeOnlyAppend);

    final migrated =
        await SpatialLibraryStore(root: libraryRoot).migrateLegacy(root);

    expect(migrated.single.sampleCount, 2);
    expect(await Directory(migrated.single.sourcePath).exists(), isTrue);
  });

  test('existing destination is idempotent and leaves a new source untouched',
      () async {
    final first = await SpatialCaptureStore.create(
      captureId: 'existing',
      artworkId: 'art-1',
      root: root,
    );
    await first.writeSample(rgb: Uint8List.fromList(<int>[1]));
    final library = SpatialLibraryStore(root: libraryRoot);
    await library.migrateLegacy(root);

    final later = await SpatialCaptureStore.create(
      captureId: 'existing',
      artworkId: 'art-1',
      root: root,
    );
    await later.writeSample(rgb: Uint8List.fromList(<int>[2, 3]));

    expect(await library.migrateLegacy(root), isEmpty);
    expect(await later.directory.exists(), isTrue);
    expect((await library.get('existing'))!.sampleCount, 1);
  });

  test('recovers a complete orphan record.json.tmp after interruption',
      () async {
    final capture = await SpatialCaptureStore.create(
      captureId: 'atomic-recovery',
      artworkId: 'art-1',
      root: root,
    );
    await capture.writeSample(rgb: Uint8List.fromList(<int>[1, 2, 3]));
    final library = SpatialLibraryStore(root: libraryRoot);
    final record = await library.promoteCapture(capture);
    final folder = await library.recordDirectory(record.localSpatialId);
    final destination =
        File('${folder.path}${Platform.pathSeparator}record.json');
    final temporary = File('${destination.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(record
          .copyWith(
            processingState: SpatialLibraryProcessingState.processing,
          )
          .toJson()),
      flush: true,
    );
    await destination.delete();

    final recovered = await library.get(record.localSpatialId);

    expect(
        recovered!.processingState, SpatialLibraryProcessingState.processing);
    expect(await destination.exists(), isTrue);
    expect(await temporary.exists(), isFalse);
    expect(await Directory(recovered.sourcePath).exists(), isTrue);
  });

  test('state updates retain raw and never serialize credentials', () async {
    final capture = await SpatialCaptureStore.create(
      captureId: 'retention',
      artworkId: 'art-1',
      root: root,
    );
    await capture.writeSample(rgb: Uint8List.fromList(<int>[1, 2, 3]));
    final library = SpatialLibraryStore(root: libraryRoot);
    final record = await library.promoteCapture(capture);
    await library.recordNodeTransfer(
      record.localSpatialId,
      nodeId: 'node-1',
      draftId: 'draft-1',
      uploadedBytes: 2,
      totalBytes: 3,
    );
    await library.recordJob(
      record.localSpatialId,
      jobId: 'job-1',
      state: SpatialLibraryProcessingState.processing,
    );
    await library.recordFailure(
      record.localSpatialId,
      code: 'node_offline',
      waitingForProcessor: true,
    );

    final current = (await library.get(record.localSpatialId))!;
    final json = jsonEncode(current.toJson());
    expect(current.rawPresent, isTrue);
    expect(await Directory(current.sourcePath).exists(), isTrue);
    expect(json, isNot(contains('bearer')));
    expect(json, isNot(contains('pairingSecret')));
    expect(json, isNot(contains('authToken')));
  });

  test('raw, processed, and local-record deletion have separate semantics',
      () async {
    final capture = await SpatialCaptureStore.create(
      captureId: 'delete-semantics',
      artworkId: 'art-1',
      root: root,
    );
    await capture.writeSample(rgb: Uint8List.fromList(<int>[1, 2, 3]));
    final library = SpatialLibraryStore(root: libraryRoot);
    var record = await library.promoteCapture(capture);
    final folder = await library.recordDirectory(record.localSpatialId);
    final result = Directory('${folder.path}${Platform.pathSeparator}result');
    await result.create(recursive: true);
    final manifest =
        File('${result.path}${Platform.pathSeparator}manifest.json');
    final variant = File('${result.path}${Platform.pathSeparator}mobile.spz');
    await manifest.writeAsString('{}');
    await variant.writeAsBytes(<int>[4, 5, 6]);
    record = await library.recordResult(
      record.localSpatialId,
      manifestPath: manifest.path,
      manifestCid: 'Qmaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      variantPaths: <String, String>{'spatial_mobile': variant.path},
      bytes: 5,
      format: 'gaussianSplat',
    );
    record = await library.recordPublication(
      record.localSpatialId,
      state: SpatialLibraryPublicationState.published,
      publicSpatialId: 'public-1',
      version: 1,
      canonicalManifestCid: 'Qmbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      canonicalRecordCid: 'Qmcccccccccccccccccccccccccccccccccccccccccccc',
      publishedAt: DateTime.utc(2026, 8, 18),
    );

    record = await library.deleteRaw(record.localSpatialId);
    expect(record.rawPresent, isFalse);
    expect(record.hasLocalResult, isTrue);
    expect(record.publicationState, SpatialLibraryPublicationState.published);
    expect(await variant.exists(), isTrue);

    record = await library.deleteProcessed(record.localSpatialId);
    expect(record.rawPresent, isFalse);
    expect(record.hasLocalResult, isFalse);
    expect(record.publicationState, SpatialLibraryPublicationState.published);
    expect(await result.exists(), isFalse);

    await library.deleteRecord(record.localSpatialId);
    expect(await library.get(record.localSpatialId), isNull);
    // No unpublish client exists in the local deletion path.
    expect(record.publicSpatialId, 'public-1');
  });
}
