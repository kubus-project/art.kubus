import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:art_kubus/services/kubus_node_service.dart';
import 'package:art_kubus/services/spatial_capture_store.dart';
import 'package:art_kubus/services/spatial_library_store.dart';
import 'package:art_kubus/services/spatial_result_importer.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const _manifestCid = 'Qmaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _variantCid = 'Qmbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

class _MemoryCredentials implements KubusNodeCredentialStore {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}

class _FakeResultNode extends KubusNodeService {
  _FakeResultNode({required this.manifest, required this.contents})
      : super(credentialStore: _MemoryCredentials(), isWeb: false);

  final Map<String, dynamic> manifest;
  final Map<String, List<int>> contents;

  @override
  Future<Map<String, dynamic>> getSpatial(String id) async => <String, dynamic>{
        'id': id,
        'manifestCid': _manifestCid,
        'manifest': manifest,
      };

  @override
  Future<void> downloadContentToFile(String cid, File destination) async {
    final bytes =
        cid == _manifestCid ? utf8.encode(jsonEncode(manifest)) : contents[cid];
    if (bytes == null) throw StateError('content_missing');
    await destination.parent.create(recursive: true);
    final sink = destination.openWrite();
    for (var offset = 0; offset < bytes.length; offset += 17) {
      final end = offset + 17 < bytes.length ? offset + 17 : bytes.length;
      sink.add(bytes.sublist(offset, end));
    }
    await sink.close();
  }
}

void main() {
  late Directory captureRoot;
  late Directory libraryRoot;
  late SpatialLibraryStore store;
  late SpatialLibraryRecord record;
  late List<int> variantBytes;

  setUp(() async {
    captureRoot = await Directory.systemTemp.createTemp('result-capture-');
    libraryRoot = await Directory.systemTemp.createTemp('result-library-');
    store = SpatialLibraryStore(root: libraryRoot);
    final capture = await SpatialCaptureStore.create(
      captureId: 'local-1',
      artworkId: 'art-1',
      capturedBy: 'owner-1',
      root: captureRoot,
    );
    await capture.writeSample(rgb: Uint8List.fromList(<int>[1, 2, 3]));
    record = await store.promoteCapture(capture);
    record = await store.recordNodeTransfer(
      record.localSpatialId,
      nodeId: 'node-1',
      nodeCaptureId: 'node-capture-1',
    );
    variantBytes = List<int>.generate(2048, (index) => index % 251);
  });

  tearDown(() async {
    if (await captureRoot.exists()) await captureRoot.delete(recursive: true);
    if (await libraryRoot.exists()) await libraryRoot.delete(recursive: true);
  });

  Map<String, dynamic> manifest({int? size, String? hash}) => <String, dynamic>{
        'schema': 'kubus.spatial/1',
        'id': 'spatial-1',
        'type': 'gaussianSplat',
        'artworkId': 'art-1',
        'captureId': 'node-capture-1',
        'capturedAt': '2026-08-18T00:00:00.000Z',
        'variants': <Map<String, dynamic>>[
          <String, dynamic>{
            'role': 'spatial_mobile',
            'cid': _variantCid,
            'sizeBytes': size ?? variantBytes.length,
            'mimeType': 'application/octet-stream',
            'format': 'spz',
            'storageClass': 'warm',
            if (hash != null) 'sha256': hash,
          },
        ],
      };

  test('streams, validates, atomically imports, and opens local result',
      () async {
    final importer = SpatialResultImporter(store: store);
    final node = _FakeResultNode(
      manifest: manifest(hash: sha256.convert(variantBytes).toString()),
      contents: <String, List<int>>{_variantCid: variantBytes},
    );

    final ready = await importer.importFromNode(
      localSpatialId: record.localSpatialId,
      spatialId: 'spatial-1',
      node: node,
    );
    final content = await importer.loadLocalContent(ready);

    expect(ready.processingState, SpatialLibraryProcessingState.readyPrivate);
    expect(ready.integrityState, SpatialLibraryIntegrityState.valid);
    expect(ready.rawPresent, isTrue);
    expect(await File(ready.resultManifestPath!).exists(), isTrue);
    expect(await File(ready.resultVariantPaths['spatial_mobile']!).length(),
        variantBytes.length);
    expect(content.variants.single.localPath,
        ready.resultVariantPaths['spatial_mobile']);
    expect(
      await libraryRoot
          .list(recursive: true)
          .where((entity) => entity.path.endsWith('.partial'))
          .isEmpty,
      isTrue,
    );
  });

  test('failed partial download never becomes ready', () async {
    final importer = SpatialResultImporter(store: store);
    final node = _FakeResultNode(
      manifest: manifest(size: variantBytes.length + 1),
      contents: <String, List<int>>{_variantCid: variantBytes},
    );

    await expectLater(
      importer.importFromNode(
        localSpatialId: record.localSpatialId,
        spatialId: 'spatial-1',
        node: node,
      ),
      throwsA(isA<SpatialResultValidationException>()),
    );

    final failed = await store.get(record.localSpatialId);
    expect(
        failed!.processingState, SpatialLibraryProcessingState.failedRetryable);
    expect(failed.hasLocalResult, isFalse);
    expect(failed.rawPresent, isTrue);
  });

  test('integrity mismatch rejects the result and retains raw source',
      () async {
    final importer = SpatialResultImporter(store: store);
    final node = _FakeResultNode(
      manifest: manifest(hash: List<String>.filled(64, '0').join()),
      contents: <String, List<int>>{_variantCid: variantBytes},
    );

    await expectLater(
      importer.importFromNode(
        localSpatialId: record.localSpatialId,
        spatialId: 'spatial-1',
        node: node,
      ),
      throwsA(
        isA<SpatialResultValidationException>().having(
          (error) => error.code,
          'code',
          'variant_hash_mismatch',
        ),
      ),
    );
    final failed = await store.get(record.localSpatialId);
    expect(failed!.rawPresent, isTrue);
    expect(failed.hasLocalResult, isFalse);
  });

  test('capture and artwork linkage mismatches are rejected before download',
      () async {
    final bad = manifest()..['captureId'] = 'someone-elses-capture';
    final importer = SpatialResultImporter(store: store);
    final node = _FakeResultNode(
      manifest: bad,
      contents: <String, List<int>>{_variantCid: variantBytes},
    );

    await expectLater(
      importer.importFromNode(
        localSpatialId: record.localSpatialId,
        spatialId: 'spatial-1',
        node: node,
      ),
      throwsA(
        isA<SpatialResultValidationException>().having(
          (error) => error.code,
          'code',
          'capture_mismatch',
        ),
      ),
    );
  });
}
