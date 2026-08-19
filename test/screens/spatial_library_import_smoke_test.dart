import 'package:art_kubus/features/spatial/spatial_record_actions.dart';
import 'package:art_kubus/screens/spatial/spatial_library_screen.dart';
import 'package:art_kubus/services/spatial_library_store.dart';
import 'package:flutter_test/flutter_test.dart';

SpatialLibraryRecord _captured() {
  final now = DateTime.utc(2026, 8, 18);
  return SpatialLibraryRecord(
    localSpatialId: 'local-1',
    artworkId: 'artwork-1',
    capturedAt: now,
    updatedAt: now,
    sourcePath: 'private/source',
    sampleCount: 3,
    sourceBytes: 300,
    hasDepth: true,
    rawPresent: true,
    processingState: SpatialLibraryProcessingState.capturedPrivate,
  );
}

SpatialLibraryRecord _withResult(SpatialLibraryRecord record) =>
    record.copyWith(
      processingState: SpatialLibraryProcessingState.readyPrivate,
      resultManifestPath: 'result/manifest.json',
      resultVariantPaths: const <String, String>{
        'spatial_mobile': 'result/mobile.spz',
      },
      resultBytes: 120,
      integrityState: SpatialLibraryIntegrityState.valid,
    );

void main() {
  test('screen type loads', () {
    expect(const SpatialLibraryScreen(), isNotNull);
  });

  group('the action model reflects what the record can actually do', () {
    test('a fresh private capture leads with processing', () {
      final actions = SpatialRecordActions.of(_captured());

      expect(actions.primary, SpatialLibraryAction.process);
      // Continuing and re-associating stay available; neither is the headline.
      expect(actions.secondary, contains(SpatialLibraryAction.continueCapture));
      expect(actions.secondary, contains(SpatialLibraryAction.editAssociation));
      expect(actions.secondary, contains(SpatialLibraryAction.editMetadata));
      // Nothing may delete the only copy of the capture.
      expect(actions.overflow, isNot(contains(SpatialLibraryAction.deleteRaw)));
      expect(
          actions.overflow, contains(SpatialLibraryAction.deleteLocalRecord));
    });

    test('a processed private capture leads with publishing', () {
      final actions = SpatialRecordActions.of(_withResult(_captured()));

      expect(actions.primary, SpatialLibraryAction.publish);
      expect(actions.secondary, contains(SpatialLibraryAction.viewResult));
      // Raw may now be reclaimed, because the result can stand in for it.
      expect(actions.overflow, contains(SpatialLibraryAction.deleteRaw));
      expect(actions.overflow, contains(SpatialLibraryAction.deleteProcessed));
    });

    test('a published capture leads with a new revision, never an edit', () {
      final published = _withResult(_captured()).copyWith(
        processingState: SpatialLibraryProcessingState.published,
        publicationState: SpatialLibraryPublicationState.published,
        version: 1,
      );

      final actions = SpatialRecordActions.of(published);

      expect(actions.primary, SpatialLibraryAction.newRevision);
      expect(actions.secondary, contains(SpatialLibraryAction.share));
      expect(
        actions.secondary,
        contains(SpatialLibraryAction.viewPublicArchive),
      );
      // A published archive is immutable: neither its association nor its
      // capture may be altered in place.
      expect(
          actions.all, isNot(contains(SpatialLibraryAction.editAssociation)));
      expect(
          actions.all, isNot(contains(SpatialLibraryAction.continueCapture)));
      expect(actions.all, isNot(contains(SpatialLibraryAction.publish)));
    });

    test('a stale result must be reprocessed before it can be published', () {
      final stale = _withResult(_captured()).copyWith(
        processingState: SpatialLibraryProcessingState.capturedPrivate,
        resultStale: true,
      );

      final actions = SpatialRecordActions.of(stale);

      expect(actions.primary, SpatialLibraryAction.process);
      expect(actions.all, isNot(contains(SpatialLibraryAction.publish)));
    });

    test('an open network request offers cancelling, not a second processor',
        () {
      final requested = _captured().copyWith(
        processingState: SpatialLibraryProcessingState.waitingForProcessor,
        networkRequest: SpatialNetworkRequest(
          state: SpatialNetworkRequestState.searchingProvider,
          requestedAt: DateTime.utc(2026, 8, 18),
        ),
      );

      final actions = SpatialRecordActions.of(requested);

      expect(actions.primary, isNull);
      expect(
        actions.secondary,
        contains(SpatialLibraryAction.cancelProcessingRequest),
      );
      expect(actions.all, isNot(contains(SpatialLibraryAction.process)));
      // Reopening the source mid-request would invalidate the job in flight.
      expect(
          actions.all, isNot(contains(SpatialLibraryAction.continueCapture)));
    });

    test('a failed job offers retry and a different processor', () {
      final failed = _captured().copyWith(
        processingState: SpatialLibraryProcessingState.failedRetryable,
        lastErrorCode: 'processor_unavailable',
      );

      final actions = SpatialRecordActions.of(failed);

      expect(actions.primary, SpatialLibraryAction.retryProcessing);
      expect(
        actions.secondary,
        contains(SpatialLibraryAction.changeProcessor),
      );
    });

    test('nothing destructive is offered while a job owns the record', () {
      final busy = _captured().copyWith(
        processingState: SpatialLibraryProcessingState.uploading,
      );

      final actions = SpatialRecordActions.of(busy);

      expect(actions.primary, isNull);
      expect(actions.overflow, isEmpty);
      expect(
          actions.all, isNot(contains(SpatialLibraryAction.continueCapture)));
    });
  });
}
