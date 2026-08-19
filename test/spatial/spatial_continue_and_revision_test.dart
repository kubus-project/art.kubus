import 'dart:io';

import 'package:art_kubus/models/spatial_capture_target.dart';
import 'package:art_kubus/providers/spatial_capture_provider.dart';
import 'package:art_kubus/services/spatial_capture_store.dart';
import 'package:art_kubus/services/spatial_library_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'spatial_test_fixtures.dart';

/// Continuing a capture and branching a revision are the two ways a capture
/// changes after it is saved. Both must add without destroying: the first
/// extends a private draft in place, the second leaves a published archive
/// exactly as it was.
void main() {
  late Directory root;
  late SpatialLibraryStore library;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kubus_spatial_continue_');
    library = SpatialLibraryStore(root: Directory('${root.path}_library'));
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
    final libraryRoot = Directory('${root.path}_library');
    if (await libraryRoot.exists()) await libraryRoot.delete(recursive: true);
  });

  SpatialCaptureProvider buildProvider() => SpatialCaptureProvider(
        policy: eagerPolicy,
        storageRoot: root,
        libraryStore: library,
      );

  Future<SpatialLibraryRecord> captureRecord(
    SpatialCaptureProvider capture, {
    int frames = 26,
    String artworkId = 'artwork-1',
    String? markerId = 'marker-1',
  }) async {
    await capture.begin(
      target: SpatialCaptureTarget(artworkId: artworkId, markerId: markerId),
      capturedBy: 'wallet-1',
    );
    await pushOrbit(capture, count: frames);
    return capture.finish();
  }

  group('continue capture', () {
    test('reopens the same record and keeps everything already on disk',
        () async {
      final capture = buildProvider();
      final saved = await captureRecord(capture, frames: 26);
      final savedSamples = saved.sampleCount;
      expect(savedSamples, greaterThanOrEqualTo(24));

      expect(await capture.continueCapture(saved), isTrue);

      // Sampling starts from what is already there, not from zero.
      expect(capture.frameCount, savedSamples);
      expect(
        capture.coverage,
        greaterThan(0),
        reason: 'coverage is rebuilt from the stored poses',
      );
      expect(capture.viewpointCount, greaterThanOrEqualTo(8));
      expect(capture.state, SpatialCaptureState.paused);
      expect(capture.isContinuingExistingCapture, isTrue);

      // Add more, carrying on around the same orbit.
      capture.resume();
      await pushOrbit(capture, count: 10, from: 26);
      final extendedSamples = capture.frameCount;
      expect(extendedSamples, greaterThan(savedSamples));

      final extended = await capture.finish();

      expect(
        extended.localSpatialId,
        saved.localSpatialId,
        reason: 'continuing must never fork a second, disconnected capture',
      );
      expect(extended.sampleCount, extendedSamples);
      expect(await library.list(), hasLength(1));
    });

    test('a continued capture that is abandoned never deletes the source',
        () async {
      final capture = buildProvider();
      final saved = await captureRecord(capture);

      expect(await capture.continueCapture(saved), isTrue);
      // The user backs out instead of finishing.
      await capture.discard();

      final stillThere = await library.get(saved.localSpatialId);
      expect(stillThere, isNotNull);
      expect(stillThere!.rawPresent, isTrue);
      expect(await Directory(stillThere.sourcePath).exists(), isTrue);
      final reopened =
          await SpatialCaptureStore.open(Directory(stillThere.sourcePath));
      expect(reopened, isNotNull);
      expect(reopened!.sampleCount, saved.sampleCount);
    });

    test('new samples mark an existing processed result stale', () async {
      final capture = buildProvider();
      final saved = await captureRecord(capture);
      final processed = await library.recordResult(
        saved.localSpatialId,
        manifestPath: '${saved.sourcePath}/../result/manifest.json',
        manifestCid: 'bafyresult',
        variantPaths: const <String, String>{'spatial_mobile': 'mobile.spz'},
        bytes: 512,
        format: 'spz',
      );
      expect(processed.hasCurrentResult, isTrue);

      expect(await capture.continueCapture(processed), isTrue);
      capture.resume();
      await pushOrbit(capture, count: 8, from: 26);
      final extended = await capture.finish();

      expect(extended.resultStale, isTrue);
      expect(
        extended.hasCurrentResult,
        isFalse,
        reason: 'a scene that predates the new samples is not current',
      );
      expect(
        extended.hasLocalResult,
        isTrue,
        reason: 'the old result is kept until a replacement succeeds',
      );
      // The node-side copy no longer matches, so it must be re-uploaded.
      expect(extended.nodeCaptureId, isNull);
    });

    test('continuing refuses a record whose raw source is gone', () async {
      final capture = buildProvider();
      final saved = await captureRecord(capture);
      await library.recordResult(
        saved.localSpatialId,
        manifestPath: 'result/manifest.json',
        manifestCid: 'bafyresult',
        variantPaths: const <String, String>{'spatial_mobile': 'mobile.spz'},
        bytes: 512,
        format: 'spz',
      );
      final withoutRaw = await library.deleteRaw(saved.localSpatialId);

      expect(await capture.continueCapture(withoutRaw), isFalse);
      expect(withoutRaw.canContinueCapture, isFalse);
    });
  });

  group('revisions', () {
    test('a published archive branches instead of being modified', () async {
      final capture = buildProvider();
      final v1 = await captureRecord(capture, frames: 26);
      await library.recordResult(
        v1.localSpatialId,
        manifestPath: 'result/manifest.json',
        manifestCid: 'bafyv1',
        variantPaths: const <String, String>{'spatial_mobile': 'v1.spz'},
        bytes: 512,
        format: 'spz',
      );
      final published = await library.recordPublication(
        v1.localSpatialId,
        state: SpatialLibraryPublicationState.published,
        publicSpatialId: 'public-1',
        version: 1,
        publishedAt: DateTime.utc(2026, 8, 1),
      );
      expect(published.isPublished, isTrue);

      final v2 = await library.createRevision(
        v1.localSpatialId,
        newLocalSpatialId: 'capture-revision-2',
      );

      // The branch is a private draft that inherits the association.
      expect(v2.revision, 2);
      expect(v2.parentLocalSpatialId, v1.localSpatialId);
      expect(v2.parentPublicVersion, 1);
      expect(v2.artworkId, v1.artworkId);
      expect(v2.markerId, v1.markerId);
      expect(v2.isPublished, isFalse);
      expect(v2.rawPresent, isTrue);
      expect(v2.hasLocalResult, isFalse);
      // It starts from the parent's capture rather than from nothing.
      expect(v2.sampleCount, v1.sampleCount);

      // v1 is untouched, archive included.
      final stillPublished = await library.get(v1.localSpatialId);
      expect(stillPublished!.isPublished, isTrue);
      expect(stillPublished.version, 1);
      expect(stillPublished.publicSpatialId, 'public-1');
      expect(stillPublished.rawPresent, isTrue);
      expect(stillPublished.hasLocalResult, isTrue);
      expect(await Directory(stillPublished.sourcePath).exists(), isTrue);
    });

    test('a revision can be extended without touching the published parent',
        () async {
      final capture = buildProvider();
      final v1 = await captureRecord(capture, frames: 26);
      await library.recordPublication(
        v1.localSpatialId,
        state: SpatialLibraryPublicationState.published,
        publicSpatialId: 'public-1',
        version: 1,
      );

      final v2 = await library.createRevision(
        v1.localSpatialId,
        newLocalSpatialId: 'capture-revision-2',
      );
      expect(await capture.continueCapture(v2), isTrue);
      capture.resume();
      await pushOrbit(capture, count: 12, from: 26);
      final extended = await capture.finish();

      expect(extended.localSpatialId, v2.localSpatialId);
      expect(extended.sampleCount, greaterThan(v1.sampleCount));

      final parent = await library.get(v1.localSpatialId);
      expect(
        parent!.sampleCount,
        v1.sampleCount,
        reason: 'the published parent keeps the capture it was published from',
      );
    });

    test('a revision branch does not inherit the parent node draft', () async {
      final capture = buildProvider();
      final v1 = await captureRecord(capture);
      await library.recordNodeTransfer(
        v1.localSpatialId,
        nodeId: 'node-1',
        draftId: 'draft-1',
        nodeCaptureId: 'capture-1',
      );

      final v2 = await library.createRevision(
        v1.localSpatialId,
        newLocalSpatialId: 'capture-revision-2',
      );

      expect(v2.draftId, isNull);
      expect(v2.nodeCaptureId, isNull);
      final reopened = await SpatialCaptureStore.open(
        Directory(v2.sourcePath),
      );
      expect(reopened!.draftId, isNull);
    });

    test('a revision refuses to branch from a record with no raw source',
        () async {
      final capture = buildProvider();
      final v1 = await captureRecord(capture);
      await library.recordResult(
        v1.localSpatialId,
        manifestPath: 'result/manifest.json',
        manifestCid: 'bafyv1',
        variantPaths: const <String, String>{'spatial_mobile': 'v1.spz'},
        bytes: 512,
        format: 'spz',
      );
      await library.deleteRaw(v1.localSpatialId);

      await expectLater(
        library.createRevision(
          v1.localSpatialId,
          newLocalSpatialId: 'capture-revision-2',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('local metadata', () {
    test('a display name is editable and never becomes the identity', () async {
      final capture = buildProvider();
      final saved = await captureRecord(capture);

      final named = await library.updateLocalMetadata(
        saved.localSpatialId,
        displayName: 'North facade, evening capture',
        note: 'Repainted since the last scan.',
      );

      expect(named.displayName, 'North facade, evening capture');
      expect(named.note, 'Repainted since the last scan.');
      expect(named.localSpatialId, saved.localSpatialId);
      expect(named.artworkId, saved.artworkId);
      // Immutable technical facts are untouched.
      expect(named.sampleCount, saved.sampleCount);
      expect(named.capturedAt, saved.capturedAt);
      expect(named.sourceBytes, saved.sourceBytes);
    });

    test('an empty name clears it rather than storing whitespace', () async {
      final capture = buildProvider();
      final saved = await captureRecord(capture);
      await library.updateLocalMetadata(
        saved.localSpatialId,
        displayName: 'Temporary',
      );

      final cleared = await library.updateLocalMetadata(
        saved.localSpatialId,
        displayName: '   ',
      );

      expect(cleared.displayName, isNull);
    });
  });
}
