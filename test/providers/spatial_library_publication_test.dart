import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:art_kubus/models/kubus_node_models.dart';
import 'package:art_kubus/providers/spatial_library_provider.dart';
import 'package:art_kubus/services/spatial_capture_store.dart';
import 'package:art_kubus/services/spatial_library_store.dart';
import 'package:flutter_test/flutter_test.dart';

const _spatialId = '11111111-1111-4111-8111-111111111111';
const _artworkId = '22222222-2222-4222-8222-222222222222';
const _manifestCid = 'Qmaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _variantCid = 'Qmbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

class _FakePublicationClient implements SpatialPublicationClient {
  final List<Map<String, dynamic>> requests = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> history = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> publish({
    required Map<String, dynamic> spatial,
    required String artworkId,
    String? markerId,
  }) async {
    requests.add(<String, dynamic>{
      'spatial': spatial,
      'artworkId': artworkId,
      'markerId': markerId,
    });
    final version = history.length + 1;
    final manifest = Map<String, dynamic>.from(spatial['manifest'] as Map);
    final entry = <String, dynamic>{
      'id': manifest['id'],
      'artworkId': artworkId,
      'capturedAt': manifest['capturedAt'],
      'publishedAt': '2026-08-${17 + version}T00:00:00.000Z',
      'version': version,
      'canonicalManifestCid':
          'Qm${List<String>.filled(44, version == 1 ? 'c' : 'd').join()}',
      'canonicalRecordCid':
          'Qm${List<String>.filled(44, version == 1 ? 'e' : 'f').join()}',
      'variants': manifest['variants'],
      'isCurrent': true,
    };
    for (final old in history) {
      old['isCurrent'] = false;
    }
    history.insert(0, entry);
    return <String, dynamic>{
      'publication': <String, dynamic>{
        'id': manifest['id'],
        'latestVersion': version,
        'currentManifestCid': entry['canonicalManifestCid'],
        'currentRecordCid': entry['canonicalRecordCid'],
        'lastPublishedAt': entry['publishedAt'],
        'currentVersion': <String, dynamic>{
          'version': version,
          'manifestCid': entry['canonicalManifestCid'],
          'recordCid': entry['canonicalRecordCid'],
          'publishedAt': entry['publishedAt'],
          'cids': <Map<String, dynamic>>[
            <String, dynamic>{
              'role': 'spatial_mobile',
              'cid': _variantCid,
            },
          ],
        },
      },
    };
  }
}

void main() {
  late Directory captureRoot;
  late Directory libraryRoot;
  late SpatialLibraryStore store;
  late SpatialLibraryProvider provider;
  late _FakePublicationClient publicClient;
  late SpatialLibraryRecord record;

  setUp(() async {
    captureRoot = await Directory.systemTemp.createTemp('publish-capture-');
    libraryRoot = await Directory.systemTemp.createTemp('publish-library-');
    store = SpatialLibraryStore(root: libraryRoot);
    publicClient = _FakePublicationClient();
    final capture = await SpatialCaptureStore.create(
      captureId: 'local-1',
      artworkId: _artworkId,
      root: captureRoot,
    );
    await capture.writeSample(rgb: Uint8List.fromList(<int>[1, 2, 3]));
    record = await store.promoteCapture(capture);
    final folder = await store.recordDirectory(record.localSpatialId);
    final result = Directory('${folder.path}${Platform.pathSeparator}result');
    await result.create(recursive: true);
    final variant = File('${result.path}${Platform.pathSeparator}mobile.spz');
    await variant.writeAsBytes(<int>[4, 5, 6]);
    final manifest =
        File('${result.path}${Platform.pathSeparator}manifest.json');
    await manifest.writeAsString(jsonEncode(<String, dynamic>{
      'schema': 'kubus.spatial/1',
      'id': _spatialId,
      'type': 'gaussianSplat',
      'artworkId': _artworkId,
      'captureId': 'node-capture-1',
      'capturedAt': '2026-08-18T00:00:00.000Z',
      'captureProvenance': <String, dynamic>{
        'source': 'localCapture',
        'captureId': 'node-capture-1',
      },
      'processing': <String, dynamic>{
        'protocol': 'kubus.spatial-job/1',
        'workerVersion': 'worker/1',
        'reconstruction': <String, dynamic>{
          'engine': 'nerfstudio',
          'method': 'splatfacto',
          'iterations': 15000,
          'outputFormat': 'spz',
        },
      },
      'variants': <Map<String, dynamic>>[
        <String, dynamic>{
          'role': 'spatial_mobile',
          'cid': _variantCid,
          'sizeBytes': 3,
          'mimeType': 'application/octet-stream',
          'format': 'spz',
          'storageClass': 'warm',
        },
      ],
    }));
    record = await store.recordResult(
      record.localSpatialId,
      manifestPath: manifest.path,
      manifestCid: _manifestCid,
      variantPaths: <String, String>{'spatial_mobile': variant.path},
      bytes: 3,
      format: 'gaussianSplat',
    );
    provider = SpatialLibraryProvider(
      store: store,
      publicationClient: publicClient,
      legacyCaptureRoot: captureRoot,
    );
    await provider.initialize();
  });

  tearDown(() async {
    if (await captureRoot.exists()) await captureRoot.delete(recursive: true);
    if (await libraryRoot.exists()) await libraryRoot.delete(recursive: true);
  });

  test('private READY_PRIVATE record is not publicly discoverable', () {
    expect(record.processingState, SpatialLibraryProcessingState.readyPrivate);
    expect(publicClient.history, isEmpty);
    expect(publicClient.requests, isEmpty);
  });

  test('publish stores canonical CIDs and exposes public history to client two',
      () async {
    final published = await provider.publish(record.localSpatialId);

    expect(published.processingState, SpatialLibraryProcessingState.published);
    expect(
        published.publicationState, SpatialLibraryPublicationState.published);
    expect(published.publicSpatialId, _spatialId);
    expect(published.version, 1);
    expect(published.canonicalManifestCid, isNotEmpty);
    expect(published.canonicalRecordCid, isNotEmpty);
    expect(published.variantCids['spatial_mobile'], _variantCid);
    final submitted = publicClient.requests.single['spatial'] as Map;
    expect(submitted['manifestCid'], _manifestCid);
    expect(
      submitted['manifestSizeBytes'],
      await File(record.resultManifestPath!).length(),
    );

    final secondClient = ArtworkSpatialHistory.fromJson(
      <String, dynamic>{'history': publicClient.history},
    );
    expect(secondClient.current!.id, _spatialId);
    expect(secondClient.current!.variants.single.cid, _variantCid);
  });

  test('publication payload contains no raw source, paths, or credentials',
      () async {
    await provider.publish(record.localSpatialId);

    final encoded = jsonEncode(publicClient.requests.single);
    expect(encoded, isNot(contains('rawRgb')));
    expect(encoded, isNot(contains('framesPath')));
    expect(encoded, isNot(contains('sourceDirectory')));
    expect(encoded, isNot(contains('localPath')));
    expect(encoded, isNot(contains('bearerCredential')));
    expect(encoded, isNot(contains('pairingSecret')));
    expect(encoded, isNot(contains(record.sourcePath)));
  });

  test('manifest requiring sanitization is rejected before CID publication',
      () async {
    final manifestFile = File(record.resultManifestPath!);
    final unsafe =
        jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>
          ..['rawRgb'] = <String>['private.jpg']
          ..['pairingSecret'] = 'must-not-publish';
    await manifestFile.writeAsString(jsonEncode(unsafe));

    await expectLater(
      provider.publish(record.localSpatialId),
      throwsA(isA<StateError>()),
    );

    expect(publicClient.requests, isEmpty);
    expect(publicClient.history, isEmpty);
  });

  test('publication history is append-only and newest remains current',
      () async {
    await provider.publish(record.localSpatialId);
    final second = await provider.publish(record.localSpatialId);

    expect(second.version, 2);
    expect(publicClient.history, hasLength(2));
    expect(publicClient.history.first['isCurrent'], isTrue);
    expect(publicClient.history.last['isCurrent'], isFalse);
  });
}
