import 'dart:io';
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
}
