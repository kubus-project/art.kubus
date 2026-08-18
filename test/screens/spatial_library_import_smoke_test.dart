import 'package:art_kubus/screens/spatial/spatial_library_screen.dart';
import 'package:art_kubus/services/spatial_library_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('screen type loads', () {
    expect(const SpatialLibraryScreen(), isNotNull);
  });

  test('actions only expose valid operations for each lifecycle state', () {
    final now = DateTime.utc(2026, 8, 18);
    final captured = SpatialLibraryRecord(
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

    expect(
      spatialLibraryActionsFor(captured),
      <SpatialLibraryAction>{
        SpatialLibraryAction.process,
        SpatialLibraryAction.deleteRecord,
      },
    );

    final ready = captured.copyWith(
      processingState: SpatialLibraryProcessingState.readyPrivate,
      resultManifestPath: 'result/manifest.json',
      resultVariantPaths: const <String, String>{
        'spatial_mobile': 'result/mobile.spz',
      },
      resultBytes: 120,
      integrityState: SpatialLibraryIntegrityState.valid,
    );
    expect(
      spatialLibraryActionsFor(ready),
      <SpatialLibraryAction>{
        SpatialLibraryAction.publish,
        SpatialLibraryAction.deleteRaw,
        SpatialLibraryAction.deleteProcessed,
        SpatialLibraryAction.deleteRecord,
      },
    );

    final published = ready.copyWith(
      processingState: SpatialLibraryProcessingState.published,
      publicationState: SpatialLibraryPublicationState.published,
    );
    expect(
      spatialLibraryActionsFor(published),
      <SpatialLibraryAction>{
        SpatialLibraryAction.share,
        SpatialLibraryAction.deleteRaw,
        SpatialLibraryAction.deleteProcessed,
        SpatialLibraryAction.deleteRecord,
      },
    );
  });
}
