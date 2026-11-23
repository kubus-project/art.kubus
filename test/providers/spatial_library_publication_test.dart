import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:art_kubus/models/kubus_node_models.dart';
import 'package:art_kubus/providers/spatial_library_provider.dart';
import 'package:art_kubus/services/spatial_capture_store.dart';
import 'package:art_kubus/services/spatial_library_store.dart';
import 'package:art_kubus/services/spatial_web_delivery.dart';
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
  group('publish() with a Node-shaped transform', () {
    // A proper Node placement: rotated 90 degrees about x, scale 2, at (1, 2, 3).
    const nodeMatrix = <double>[
      2, 0, 0, 0, //
      0, 0, 2, 0, //
      0, -2, 0, 0, //
      1, 2, 3, 1,
    ];

    Future<Map<String, dynamic>> rewriteTransform(
      Map<String, dynamic> transform,
    ) async {
      final file = File(record.resultManifestPath!);
      final manifest = jsonDecode(await file.readAsString())
          as Map<String, dynamic>
        ..['transform'] = transform;
      await file.writeAsString(jsonEncode(manifest));
      return manifest;
    }

    test(
        'a manifest still carrying the Node matrix is refused before any '
        'request, and the record is marked failed', () async {
      await rewriteTransform(<String, dynamic>{
        'matrix': nodeMatrix,
        'matrixOrder': 'column-major',
      });

      await expectLater(
        provider.publish(record.localSpatialId),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'local_manifest_not_public_safe',
          ),
        ),
      );

      expect(publicClient.requests, isEmpty);
      final after = await store.get(record.localSpatialId);
      expect(after!.publicationState, SpatialLibraryPublicationState.failed);
    });

    test(
        'the projection of that manifest is what publish() accepts, and the '
        'transform reaches the request as position / rotation / scale',
        () async {
      final nodeManifest = await rewriteTransform(<String, dynamic>{
        'matrix': nodeMatrix,
        'matrixOrder': 'column-major',
      });
      // What a projection step stores at the public CID.
      final projected =
          SpatialLibraryProvider.sanitizePublicationManifest(nodeManifest);
      await File(record.resultManifestPath!)
          .writeAsString(jsonEncode(projected));

      await provider.publish(record.localSpatialId);

      final submitted = publicClient.requests.single['spatial'] as Map;
      final transform =
          (submitted['manifest'] as Map)['transform'] as Map<String, dynamic>;
      expect(transform.keys.toSet(), {'position', 'rotation', 'scale'});
      expect(transform['position'], [1.0, 2.0, 3.0]);
      expect(jsonEncode(submitted), isNot(contains('matrix')));
    });

    test('a manifest already in the public form publishes unchanged', () async {
      await rewriteTransform(<String, dynamic>{
        'position': <double>[1, 2, 3],
        'rotation': <double>[0, 0, 0, 1],
        'scale': 2,
      });

      await provider.publish(record.localSpatialId);

      final submitted = publicClient.requests.single['spatial'] as Map;
      expect((submitted['manifest'] as Map)['transform'], <String, dynamic>{
        'position': <double>[1, 2, 3],
        'rotation': <double>[0, 0, 0, 1],
        'scale': 2,
      });
    });
  });

  group('sanitizePublicationManifest transform', () {
    Map<String, dynamic> manifest(Map<String, dynamic> transform) =>
        <String, dynamic>{
          'schema': 'kubus.spatial/1',
          'type': 'gaussianSplat',
          'id': _spatialId,
          'artworkId': _artworkId,
          'variants': <Object?>[],
          'transform': transform,
        };

    // A proper Node placement: rotated 90 degrees about x (quaternion
    // 0.7071 0 0 0.7071), uniform scale 2, translated (1, 2, 3).
    const upright = <double>[
      2, 0, 0, 0, //
      0, 0, 2, 0, //
      0, -2, 0, 0, //
      1, 2, 3, 1,
    ];

    test('a Node matrix is published as position / rotation / scale', () {
      final out = SpatialLibraryProvider.sanitizePublicationManifest(
        manifest(<String, dynamic>{
          'matrix': upright,
          'matrixOrder': 'column-major',
        }),
      )['transform'] as Map<String, dynamic>;
      expect(out.keys.toSet(), {'position', 'rotation', 'scale'});
      expect(out['position'], [1.0, 2.0, 3.0]);
      expect(out['scale'], [2.0, 2.0, 2.0]);
      final q = (out['rotation'] as List).cast<double>();
      expect(q, hasLength(4));
      expect(q[0], closeTo(0.7071067811865476, 1e-9));
      expect(q[1], closeTo(0, 1e-9));
      expect(q[2], closeTo(0, 1e-9));
      expect(q[3], closeTo(0.7071067811865476, 1e-9));
    });

    test('a matrix the viewer refuses is dropped whole, not mixed', () {
      final sheared = List<double>.of(upright)..[4] = 1;
      final out = SpatialLibraryProvider.sanitizePublicationManifest(
        manifest(<String, dynamic>{
          'matrix': sheared,
          'position': <double>[9, 9, 9],
        }),
      );
      expect(out.containsKey('transform'), isFalse);
    });

    test(
        'an unknown matrixOrder or a non-list matrix is not a matrix: the '
        'fields apply, exactly as the viewer reads it', () {
      for (final transform in <Map<String, dynamic>>[
        <String, dynamic>{
          'matrix': upright,
          'matrixOrder': 'row-major',
          'position': <double>[4, 5, 6],
        },
        <String, dynamic>{
          'matrix': 'not-a-list',
          'position': <double>[4, 5, 6],
        },
      ]) {
        final out = SpatialLibraryProvider.sanitizePublicationManifest(
          manifest(transform),
        )['transform'];
        expect(out, <String, dynamic>{
          'position': <double>[4, 5, 6],
        });
        expect(
          SpatialWebDelivery.transformFromManifest(manifest(transform)),
          <String, dynamic>{
            'position': <double>[4.0, 5.0, 6.0],
          },
        );
      }
    });

    test('accepts and refuses the shared fixture matrices like the viewer', () {
      final fixture = jsonDecode(
        File('test/fixtures/spatial/manifest_transform_vectors.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final base = (fixture['upright'] as List).cast<num>();
      for (final item in (fixture['matrices'] as List).cast<Map>()) {
        final values = base.map((v) => v as Object?).toList();
        final edits = (item['edits'] as Map).cast<String, Object?>();
        edits.forEach((index, value) {
          values[int.parse(index)] = value == 'NaN'
              ? double.nan
              : (value is String ? value : value as num);
        });
        final keep = item['keep'] as int?;
        final matrix = keep == null ? values : values.sublist(0, keep);
        final transform = <String, dynamic>{'matrix': matrix};
        final viewerAccepts = SpatialWebDelivery.transformFromManifest(
              manifest(transform),
            ) !=
            null;
        final published = SpatialLibraryProvider.sanitizePublicationManifest(
          manifest(transform),
        ).containsKey('transform');
        expect(viewerAccepts, item['accepted'], reason: '${item['name']}');
        expect(published, viewerAccepts, reason: '${item['name']}');
      }
    });

    test('the position / rotation / scale form passes through unchanged', () {
      final out = SpatialLibraryProvider.sanitizePublicationManifest(
        manifest(<String, dynamic>{
          'position': <double>[1, 2, 3],
          'rotation': <double>[0, 0, 0, 1],
          'scale': 2,
          'matrixOrder': 'column-major',
        }),
      )['transform'];
      expect(out, <String, dynamic>{
        'position': <double>[1, 2, 3],
        'rotation': <double>[0, 0, 0, 1],
        'scale': 2,
      });
    });
  });
}
