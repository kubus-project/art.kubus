import 'dart:io';

import 'package:art_kubus/models/spatial_capture_target.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/spatial_capture_provider.dart';
import 'package:art_kubus/services/spatial_library_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'spatial_test_fixtures.dart';

/// The capture target is the association the whole feature hangs off.
///
/// These tests exist because the original defect was invisible in review:
/// `artworks.firstOrNull` reads like a harmless default, and silently files a
/// scan under someone else's work.
void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kubus_spatial_target_');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  SpatialLibraryStore libraryStore() =>
      SpatialLibraryStore(root: Directory('${root.path}_library'));

  SpatialCaptureProvider buildProvider({SpatialLibraryStore? library}) =>
      SpatialCaptureProvider(
        policy: eagerPolicy,
        storageRoot: root,
        libraryStore: library ?? libraryStore(),
      );

  test('a running capture keeps its artwork when the provider is reordered',
      () async {
    final artworks = ArtworkProvider();
    artworks.seedArtworksForTesting(<dynamic>[
      artworkFixture('a', title: 'Artwork A'),
      artworkFixture('b', title: 'Artwork B'),
      artworkFixture('c', title: 'Artwork C'),
    ].cast());

    final capture = buildProvider();
    await capture.begin(
      target: const SpatialCaptureTarget(artworkId: 'b'),
      capturedBy: 'wallet-1',
    );
    await pushOrbit(capture, count: 4);

    expect(capture.artworkId, 'b');

    // The exact churn the old fallback was sensitive to.
    artworks.seedArtworksForTesting(<dynamic>[
      artworkFixture('c', title: 'Artwork C'),
      artworkFixture('a', title: 'Artwork A'),
      artworkFixture('b', title: 'Artwork B'),
    ].cast());

    expect(
      capture.artworkId,
      'b',
      reason: 'a running capture owns its target; provider order is not input',
    );
    expect(artworks.artworks.first.id, 'c', reason: 'the reorder did happen');

    await capture.discard();
  });

  test('a capture started for a marker keeps both ids', () async {
    final capture = buildProvider();
    await capture.begin(
      target: const SpatialCaptureTarget(
        artworkId: 'artwork-7',
        markerId: 'marker-7',
      ),
      capturedBy: 'wallet-1',
    );

    expect(capture.artworkId, 'artwork-7');
    expect(capture.markerId, 'marker-7');
    expect(capture.target?.hasMarker, isTrue);

    await capture.discard();
  });

  test('the target survives pause and resume', () async {
    final capture = buildProvider();
    await capture.begin(
      target: const SpatialCaptureTarget(
        artworkId: 'artwork-3',
        markerId: 'marker-3',
      ),
      capturedBy: 'wallet-1',
    );
    capture.pause(SpatialCapturePauseReason.appBackgrounded);
    capture.resume();

    expect(capture.artworkId, 'artwork-3');
    expect(capture.markerId, 'marker-3');

    await capture.discard();
  });

  test('the saved record carries the exact ids the capture was started with',
      () async {
    final library = libraryStore();
    final capture = buildProvider(library: library);
    await capture.begin(
      target: const SpatialCaptureTarget(
        artworkId: 'artwork-42',
        markerId: 'marker-42',
        artworkTitleSnapshot: 'Untitled Wall #3',
        artistNameSnapshot: 'Maja Novak',
        markerLabelSnapshot: 'Metelkova',
      ),
      capturedBy: 'wallet-1',
    );
    await pushOrbit(capture, count: 26);

    final record = await capture.finish();

    expect(record.artworkId, 'artwork-42');
    expect(record.markerId, 'marker-42');
    // Snapshots are display fallbacks, stored alongside the ids rather than
    // instead of them.
    expect(record.artworkTitleSnapshot, 'Untitled Wall #3');
    expect(record.artistNameSnapshot, 'Maja Novak');
    expect(record.markerLabelSnapshot, 'Metelkova');
  });

  test('an interrupted capture resumes against its own recorded artwork',
      () async {
    final first = buildProvider();
    await first.begin(
      target: const SpatialCaptureTarget(
        artworkId: 'artwork-9',
        markerId: 'marker-9',
      ),
      capturedBy: 'wallet-1',
    );
    await pushOrbit(first, count: 4);

    // A fresh provider, as after a restart: nothing in memory to fall back to.
    final second = buildProvider();
    final interrupted = await second.findRecoverable(capturedBy: 'wallet-1');
    expect(interrupted, hasLength(1));

    expect(await second.resumeInterrupted(interrupted.first), isTrue);
    expect(second.artworkId, 'artwork-9');
    expect(second.markerId, 'marker-9');
  });

  test('a continued capture takes its target from the record, not the app',
      () async {
    final library = libraryStore();
    final capture = buildProvider(library: library);
    await capture.begin(
      target: const SpatialCaptureTarget(
        artworkId: 'artwork-1',
        markerId: 'marker-1',
        artworkTitleSnapshot: 'Untitled Wall',
      ),
      capturedBy: 'wallet-1',
    );
    await pushOrbit(capture, count: 26);
    final record = await capture.finish();

    // The record is later repointed at a different artwork.
    final repointed = await library.updateAssociation(
      record.localSpatialId,
      artworkId: 'artwork-2',
      markerId: 'marker-2',
      artworkTitleSnapshot: 'Corrected Wall',
    );

    expect(await capture.continueCapture(repointed), isTrue);
    expect(
      capture.artworkId,
      'artwork-2',
      reason: 'the record is the authority, not the on-disk capture manifest',
    );
    expect(capture.markerId, 'marker-2');
    expect(capture.target?.artworkTitleSnapshot, 'Corrected Wall');
    expect(capture.continuingLocalSpatialId, record.localSpatialId);
  });

  test('a published record refuses to be repointed in place', () async {
    final library = libraryStore();
    final capture = buildProvider(library: library);
    await capture.begin(
      target: const SpatialCaptureTarget(artworkId: 'artwork-1'),
      capturedBy: 'wallet-1',
    );
    await pushOrbit(capture, count: 26);
    final record = await capture.finish();
    await library.recordPublication(
      record.localSpatialId,
      state: SpatialLibraryPublicationState.published,
      publicSpatialId: 'public-1',
      version: 1,
    );

    await expectLater(
      library.updateAssociation(
        record.localSpatialId,
        artworkId: 'artwork-2',
      ),
      throwsA(isA<StateError>()),
    );

    final unchanged = await library.get(record.localSpatialId);
    expect(unchanged!.artworkId, 'artwork-1');
  });

  test('a target refuses to be built from an empty artwork id', () {
    expect(
      () => SpatialCaptureTarget(artworkId: ''),
      throwsA(isA<AssertionError>()),
    );
    expect(SpatialCaptureTarget.tryFromJson(<String, dynamic>{}), isNull);
    expect(
      SpatialCaptureTarget.tryFromJson(<String, dynamic>{'artworkId': '  '}),
      isNull,
    );
  });

  test('a target round-trips through JSON without losing its marker', () {
    const target = SpatialCaptureTarget(
      artworkId: 'artwork-1',
      markerId: 'marker-1',
      artworkTitleSnapshot: 'Wall',
      artistNameSnapshot: 'Maja',
      markerLabelSnapshot: 'Metelkova',
    );

    expect(SpatialCaptureTarget.tryFromJson(target.toJson()), target);
  });
}
