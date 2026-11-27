import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:art_kubus/models/kubus_node_models.dart';
import 'package:art_kubus/services/spatial_web_delivery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

SpatialVariant _variant(
  String role,
  String cid,
  String format, {
  String mime = 'application/octet-stream',
}) =>
    SpatialVariant(
      role: role,
      cid: cid,
      sizeBytes: 1024,
      mimeType: mime,
      format: format,
      storageClass: 'warm',
    );

SpatialContent _content(
  List<SpatialVariant> variants, {
  String? manifestCid,
  Map<String, dynamic>? transform,
}) =>
    SpatialContent(
      id: 'spatial-1',
      type: 'gaussianSplat',
      artworkId: 'art-1',
      captureId: 'capture-1',
      capturedAt: DateTime.utc(2026, 11, 7),
      variants: variants,
      manifestCid: manifestCid,
      transform: transform,
    );

const List<num> _upright = <num>[
  0,
  1,
  0,
  0,
  -1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  1
];

void main() {
  group('variant choice', () {
    test('optimised opens before preview, the archive never by default', () {
      final content = _content([
        _variant('spatial_archive', 'cid-archive', 'ply'),
        _variant('spatial_preview', 'cid-preview', 'spz'),
        _variant('spatial_mobile', 'cid-mobile', 'spz'),
      ]);
      expect(SpatialWebDelivery.defaultVariant(content)?.cid, 'cid-mobile');
      expect(SpatialWebDelivery.archiveVariant(content)?.cid, 'cid-archive');
    });

    test('an archive-only record opens nothing until the visitor asks', () {
      final content =
          _content([_variant('spatial_archive', 'cid-archive', 'ply')]);
      expect(SpatialWebDelivery.defaultVariant(content), isNull);
      expect(SpatialWebDelivery.archiveVariant(content), isNotNull);
    });

    test('falls back to preview and skips formats the viewer cannot read', () {
      final content = _content([
        _variant('spatial_mobile', 'cid-rad', 'rad'),
        _variant('spatial_preview', 'cid-preview', 'splat'),
      ]);
      expect(SpatialWebDelivery.defaultVariant(content)?.cid, 'cid-preview');
    });

    test('a manifest-only or glb record has no viewable variant', () {
      final content = _content([
        _variant('spatial_manifest', 'cid-manifest', 'json',
            mime: 'application/json'),
        _variant('model3d', 'cid-glb', 'glb', mime: 'model/gltf-binary'),
      ]);
      expect(SpatialWebDelivery.defaultVariant(content), isNull);
      expect(SpatialWebDelivery.archiveVariant(content), isNull);
    });
  });

  group('tiers, fallback, timeouts and the archive size', () {
    test('the default tiers are optimised then preview, never the archive', () {
      final content = _content([
        _variant('spatial_archive', 'cid-archive', 'ply'),
        _variant('spatial_preview', 'cid-preview', 'spz'),
        _variant('spatial_mobile', 'cid-mobile', 'spz'),
      ]);
      expect(
        SpatialWebDelivery.defaultTiers(content).map((v) => v.role),
        ['spatial_mobile', 'spatial_preview'],
      );
      final mobile = SpatialWebDelivery.defaultTiers(content).first;
      expect(SpatialWebDelivery.nextTier(content, mobile)?.cid, 'cid-preview');
      final preview = SpatialWebDelivery.defaultTiers(content).last;
      expect(SpatialWebDelivery.nextTier(content, preview), isNull);
      expect(
        SpatialWebDelivery.nextTier(
            content, SpatialWebDelivery.archiveVariant(content)!),
        isNull,
        reason: 'the archive is an explicit request and never falls back',
      );
    });

    test('the QA harness override replaces every budget and is off by default',
        () {
      final mobile = _variant('spatial_mobile', 'cid-mobile', 'spz');
      final archive = _variant('spatial_archive', 'cid-archive', 'ply');
      expect(SpatialWebDelivery.loadTimeoutOverride, isNull);
      SpatialWebDelivery.loadTimeoutOverride = const Duration(seconds: 2);
      addTearDown(() => SpatialWebDelivery.loadTimeoutOverride = null);
      expect(
          SpatialWebDelivery.loadTimeout(mobile), const Duration(seconds: 2));
      expect(
        SpatialWebDelivery.loadTimeout(archive),
        const Duration(seconds: 2),
      );
    });

    test('the archive gets a longer budget and a size confirmation', () {
      final archive = _variant('spatial_archive', 'cid-archive', 'ply');
      final mobile = _variant('spatial_mobile', 'cid-mobile', 'spz');
      expect(
        SpatialWebDelivery.loadTimeout(archive),
        greaterThan(SpatialWebDelivery.loadTimeout(mobile)),
      );
      SpatialVariant sized(int bytes) => SpatialVariant(
            role: 'spatial_archive',
            cid: 'cid-archive',
            sizeBytes: bytes,
            mimeType: 'application/octet-stream',
            format: 'ply',
            storageClass: 'cold',
          );
      expect(SpatialWebDelivery.archiveNeedsConfirmation(sized(1024)), isFalse);
      // A record that omits the size is the large tier with no stated size.
      expect(SpatialWebDelivery.archiveNeedsConfirmation(sized(0)), isTrue);
      expect(
        SpatialWebDelivery.archiveNeedsConfirmation(
          sized(SpatialWebDelivery.archiveConfirmBytes),
        ),
        isTrue,
      );
    });
  });

  group('byte routes', () {
    test('the registry-authorised backend route is the only route', () {
      final urls = SpatialWebDelivery.candidateUrls(
        'bafyCid',
        backendBase: 'https://api.kubus.site/',
      );
      // No public-gateway fallback: a gateway has no withdrawal gate, so it
      // would keep serving bytes the backend refuses (404/503) to serve.
      expect(urls, ['https://api.kubus.site/api/upload/file/bafyCid']);
      expect(urls.where((u) => !u.contains('/api/upload/file/')), isEmpty);
    });

    test('a withdrawn or failing backend answer never yields another URL', () {
      // The viewer only ever receives plan.urls. Whatever the backend answers,
      // that list has no second entry the viewer could fall through to.
      final variant = _variant('spatial_mobile', 'bafyWithdrawn', 'spz');
      final plan = SpatialWebDelivery.plan(
        _content([variant]),
        variant,
        backendBase: 'https://api.kubus.site',
      );
      expect(plan.urls, hasLength(1));
      expect(plan.urls.single, startsWith('https://api.kubus.site/'));
    });

    test('never offers an insecure or LAN route to a secure page', () {
      expect(
        SpatialWebDelivery.candidateUrls(
          'bafyCid',
          backendBase: 'http://api.kubus.site',
        ),
        isEmpty,
      );
      expect(
        SpatialWebDelivery.candidateUrls(
          'bafyCid',
          backendBase: 'http://192.168.1.20:8080',
        ),
        isEmpty,
      );
    });

    test('a CID that is not CID-shaped never becomes a URL', () {
      for (final bad in <String>[
        '',
        '..',
        '../x',
        'a/b',
        'bafy?x=1',
        'bafy%2e%2e',
        'bafy cid',
        'bafy.cid',
        'x' * 129,
      ]) {
        expect(SpatialWebDelivery.isPlausibleCid(bad), isFalse, reason: bad);
        expect(
          SpatialWebDelivery.candidateUrls(
            bad,
            backendBase: 'https://api.kubus.site',
          ),
          isEmpty,
          reason: bad,
        );
        expect(
          SpatialWebDelivery.isViewable(_variant('spatial_mobile', bad, 'spz')),
          isFalse,
          reason: bad,
        );
      }
      expect(SpatialWebDelivery.isPlausibleCid(null), isFalse);
      expect(
        SpatialWebDelivery.isPlausibleCid(
          'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
        ),
        isTrue,
      );
      expect(
        SpatialWebDelivery.isPlausibleCid(
          'QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG',
        ),
        isTrue,
      );
    });

    test('a manifest CID that is not CID-shaped yields no manifest route', () {
      final v = _variant('spatial_mobile', 'bafyMobile', 'spz');
      expect(
        SpatialWebDelivery.plan(
          _content([v], manifestCid: '../etc'),
          v,
          backendBase: 'https://api.kubus.site',
        ).manifestUrl,
        isNull,
      );
    });

    test('a local build may use its own loopback backend', () {
      final urls = SpatialWebDelivery.candidateUrls(
        'bafyCid',
        backendBase: 'http://127.0.0.1:3000',
      );
      expect(urls, ['http://127.0.0.1:3000/api/upload/file/bafyCid']);
    });

    test('the manifest route follows the byte route https-or-loopback rule',
        () {
      final v = _variant('spatial_mobile', 'bafyMobile', 'spz');
      final content = _content([v], manifestCid: 'bafyManifest');
      String? manifestFor(String base) =>
          SpatialWebDelivery.plan(content, v, backendBase: base).manifestUrl;
      expect(manifestFor('http://192.168.1.20:3000'), isNull);
      expect(manifestFor('http://api.kubus.site'), isNull);
      expect(
        manifestFor('http://127.0.0.1:3000'),
        'http://127.0.0.1:3000/api/upload/file/bafyManifest',
      );
      expect(
        manifestFor('https://api.kubus.site'),
        'https://api.kubus.site/api/upload/file/bafyManifest',
      );
    });

    test('a ksplat mime type is not typed as splat', () {
      final v = _variant(
        'spatial_mobile',
        'cidKs1',
        'compressed',
        mime: 'application/x-ksplat',
      );
      expect(
        SpatialWebDelivery.plan(
          _content([v]),
          v,
          backendBase: 'https://api.kubus.site',
        ).fileType,
        'ksplat',
      );
    });

    test('a .splat or .ksplat format suffix is typed and viewable', () {
      for (final entry in const <String, String>{
        'compressed.splat': 'splat',
        'compressed.ksplat': 'ksplat',
        'Quantised.SPZ': 'spz',
      }.entries) {
        final v = _variant(
          'spatial_mobile',
          'cidSuffix1',
          entry.key,
          mime: 'application/octet-stream',
        );
        expect(SpatialWebDelivery.isViewable(v), isTrue, reason: entry.key);
        expect(
          SpatialWebDelivery.plan(
            _content([v]),
            v,
            backendBase: 'https://api.kubus.site',
          ).fileType,
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('the plan names the file type only when bytes carry no magic number',
        () {
      final splat = _variant('spatial_preview', 'cidSplat1', 'splat');
      final spz = _variant('spatial_mobile', 'cidSpz2', 'spz');
      final content = _content([splat, spz], manifestCid: 'bafyManifest');
      SpatialWebLoadPlan plan(SpatialVariant v) => SpatialWebDelivery.plan(
            content,
            v,
            backendBase: 'https://api.kubus.site',
          );
      expect(plan(splat).fileType, 'splat');
      expect(plan(splat).manifestUrl,
          'https://api.kubus.site/api/upload/file/bafyManifest');
      expect(plan(splat).isArchiveTier, isFalse);
      expect(plan(spz).fileType, 'spz');
    });

    test('sog is not offered until a fixture has proven it loads', () {
      final sog = _variant('spatial_mobile', 'cidSog3', 'sog');
      final content = _content([sog]);
      expect(SpatialWebDelivery.isViewable(sog), isFalse);
      expect(SpatialWebDelivery.defaultVariant(content), isNull);
    });

    test('no manifest CID means no manifest route', () {
      final v = _variant('spatial_mobile', 'cidMobile', 'spz');
      expect(
        SpatialWebDelivery.plan(
          _content([v]),
          v,
          backendBase: 'https://api.kubus.site',
        ).manifestUrl,
        isNull,
      );
    });
  });

  group('manifest transform', () {
    test('accepts the Node column-major matrix', () {
      final transform = SpatialWebDelivery.transformFromManifest({
        'transform': {'matrix': _upright, 'matrixOrder': 'column-major'},
      });
      expect(transform?['matrix'], hasLength(16));
      expect((transform?['matrix'] as List)[1], 1.0);
      expect(transform?['matrixOrder'], 'column-major');
    });

    test('a matrix of the wrong size, order or content is not applied', () {
      Object? read(Map<String, Object?> transform) =>
          SpatialWebDelivery.transformFromManifest({'transform': transform});
      expect(read({'matrix': _upright.take(15).toList()}), isNull);
      expect(read({'matrix': _upright, 'matrixOrder': 'row-major'}), isNull);
      expect(
        read({
          'matrix': [..._upright.take(15), double.nan],
        }),
        isNull,
      );
      expect(
        read({
          'matrix': [..._upright.take(15), 'x'],
        }),
        isNull,
      );
    });

    test('a matrix that is not a plain placement is refused whole', () {
      Object? read(List<num> matrix, [Map<String, Object?> extra = const {}]) =>
          SpatialWebDelivery.transformFromManifest({
            'transform': {'matrix': matrix, ...extra},
          });
      List<num> withEdits(Map<int, num> edits) =>
          [for (var i = 0; i < 16; i++) edits[i] ?? _upright[i]];
      // A projective bottom row.
      expect(read(withEdits({3: 0.5})), isNull);
      expect(read(withEdits({15: 2})), isNull);
      // Shear: the second axis leans onto the first.
      expect(read(withEdits({4: -1, 5: 0.5})), isNull);
      // Mirror: a left-handed basis.
      expect(read(withEdits({10: -1})), isNull);
      // Magnitudes: translation, scale too large and too small.
      expect(read(withEdits({12: 1e9})), isNull);
      expect(read(withEdits({0: 0, 1: 1e9})), isNull);
      expect(read(withEdits({0: 0, 1: 1e-9})), isNull);
      // The fallback fields never rescue a refused matrix.
      expect(read(withEdits({3: 0.5}), {'scale': 2}), isNull);
      // A genuine rotation, scale and translation still passes.
      expect(read(withEdits({0: 0, 1: 2, 4: -2, 10: 3, 12: 5, 13: -4, 14: 1})),
          isNotNull);
    });

    test(
        'matches the shared accept/refuse vectors '
        '(the viewer page tests read the same file)', () {
      final vectors = jsonDecode(
        File('test/fixtures/spatial/manifest_transform_vectors.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final upright = (vectors['upright'] as List).cast<num>();
      final matrices =
          (vectors['matrices'] as List).cast<Map<String, dynamic>>();
      final positions =
          (vectors['positions'] as List).cast<Map<String, dynamic>>();
      final scales = (vectors['scales'] as List).cast<Map<String, dynamic>>();
      expect(matrices.length, greaterThanOrEqualTo(15));
      expect(positions.length, greaterThanOrEqualTo(5));
      expect(scales.length, greaterThanOrEqualTo(8));

      Object? read(Map<String, Object?> transform) =>
          SpatialWebDelivery.transformFromManifest({'transform': transform});

      for (final c in matrices) {
        final edits = (c['edits'] as Map).cast<String, Object?>();
        final values = <Object?>[
          for (var i = 0; i < upright.length; i++)
            edits.containsKey('$i')
                ? (edits['$i'] == 'NaN' ? double.nan : edits['$i'])
                : upright[i],
        ];
        final keep = c['keep'] as int?;
        final matrix = keep == null ? values : values.take(keep).toList();
        expect(
          read({'matrix': matrix}) != null,
          c['accepted'],
          reason: 'matrix: ${c['name']}',
        );
      }
      for (final c in positions) {
        expect(
          read({'position': c['value']}) != null,
          c['accepted'],
          reason: 'position: ${c['name']}',
        );
      }
      for (final c in scales) {
        expect(
          read({'scale': c['value']}) != null,
          c['accepted'],
          reason: 'scale: ${c['name']}',
        );
      }
    });

    group('decomposePlacementMatrix', () {
      // Translation * rotation(quaternion x y z w) * scale, column-major, built
      // independently of the code under test.
      List<double> compose(
        List<double> p,
        List<double> q,
        List<double> sc,
      ) {
        final x = q[0], y = q[1], z = q[2], w = q[3];
        final r = <List<double>>[
          [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
          [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
          [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ];
        return <double>[
          for (var c = 0; c < 3; c++) ...[
            r[0][c] * sc[c],
            r[1][c] * sc[c],
            r[2][c] * sc[c],
            0,
          ],
          p[0],
          p[1],
          p[2],
          1,
        ];
      }

      void expectRoundTrip(List<double> matrix) {
        final parts = SpatialWebDelivery.decomposePlacementMatrix(matrix)!;
        expect(parts.keys.toSet(), {'position', 'rotation', 'scale'});
        final rotation = (parts['rotation'] as List).cast<double>();
        expect(rotation, hasLength(4));
        final back = compose(
          (parts['position'] as List).cast<double>(),
          rotation,
          (parts['scale'] as List).cast<double>(),
        );
        for (var i = 0; i < 16; i++) {
          expect(back[i], closeTo(matrix[i], 1e-9), reason: 'element $i');
        }
      }

      test('the upright Node matrix composes back to itself', () {
        expectRoundTrip(_upright.map((v) => v.toDouble()).toList());
      });

      test('covers every quaternion branch, scaled and translated', () {
        // Rotations by 180 degrees about each axis hit the non-trace branches,
        // the identity hits the trace branch.
        final quaternions = <List<double>>[
          [0, 0, 0, 1],
          [1, 0, 0, 0],
          [0, 1, 0, 0],
          [0, 0, 1, 0],
          [0.5, 0.5, 0.5, 0.5],
          [0.2, -0.4, 0.6, 0.6633249580710799],
        ];
        for (final q in quaternions) {
          final length = math.sqrt(q.fold<double>(0, (a, b) => a + b * b));
          expectRoundTrip(
            compose(
              [1.5, -2.25, 40],
              q.map((v) => v / length).toList(),
              [0.5, 0.5, 0.5],
            ),
          );
          expectRoundTrip(
            compose(
              [0, 0, 0],
              q.map((v) => v / length).toList(),
              [2, 3, 0.25],
            ),
          );
        }
      });

      test('refuses what the viewer refuses and bad input', () {
        final mirrored = _upright.map((v) => v.toDouble()).toList()
          ..[0] = -(_upright[0].toDouble())
          ..[1] = -(_upright[1].toDouble())
          ..[2] = -(_upright[2].toDouble());
        expect(SpatialWebDelivery.decomposePlacementMatrix(mirrored), isNull);
        expect(SpatialWebDelivery.decomposePlacementMatrix(null), isNull);
        expect(
            SpatialWebDelivery.decomposePlacementMatrix(<num>[1, 0]), isNull);
        expect(
          SpatialWebDelivery.decomposePlacementMatrix(
            _upright.map((v) => v.toDouble()).toList()..[3] = double.nan,
          ),
          isNull,
        );
      });
    });

    test('position and scale outside the sane range are dropped', () {
      Object? read(Map<String, Object?> transform) =>
          SpatialWebDelivery.transformFromManifest({'transform': transform});
      expect(
          read({
            'position': [0, 1e12, 0]
          }),
          isNull);
      expect(read({'scale': 1e30}), isNull);
      expect(read({'scale': 1e-12}), isNull);
      expect(
        read({
          'scale': [1, 1, 1e30],
        }),
        isNull,
      );
      expect(
          read({
            'position': [0, 1e6, 0],
            'scale': 1e4
          }),
          isNotNull);
    });

    test('reads the position / rotation / scale form', () {
      final transform = SpatialWebDelivery.transformFromManifest({
        'transform': {
          'position': [0, 1, 0],
          'rotation': [0, 0, 0, 1],
          'scale': 2,
        },
      });
      expect(transform, {
        'position': [0.0, 1.0, 0.0],
        'rotation': [0.0, 0.0, 0.0, 1.0],
        'scale': 2.0,
      });
    });

    test('rejects non-positive scale and malformed shapes', () {
      expect(
        SpatialWebDelivery.transformFromManifest({
          'transform': {'scale': 0},
        }),
        isNull,
      );
      expect(
          SpatialWebDelivery.transformFromManifest({'transform': 'x'}), isNull);
      expect(SpatialWebDelivery.transformFromManifest('x'), isNull);
      expect(SpatialWebDelivery.transformFromManifest(null), isNull);
      expect(SpatialWebDelivery.transformFromManifest({}), isNull);
    });

    test('fetchTransform reads a published manifest and never throws',
        () async {
      final ok = MockClient((request) async {
        expect(
            request.url.toString(), 'https://api.kubus.site/api/upload/file/m');
        return http.Response(
          jsonEncode({
            'transform': {'matrix': _upright},
          }),
          200,
        );
      });
      final transform = await SpatialWebDelivery.fetchTransform(
        'https://api.kubus.site/api/upload/file/m',
        client: ok,
      );
      expect((transform?['matrix'] as List)[4], -1.0);

      expect(
        await SpatialWebDelivery.fetchTransform(
          'https://x/m',
          client: MockClient((_) async => http.Response('', 404)),
        ),
        isNull,
      );
      expect(
        await SpatialWebDelivery.fetchTransform(
          'https://x/m',
          client: MockClient((_) async => http.Response('not json', 200)),
        ),
        isNull,
      );
      expect(
        await SpatialWebDelivery.fetchTransform(
          'https://x/m',
          client:
              MockClient((_) async => throw http.ClientException('offline')),
        ),
        isNull,
      );
      expect(
        await SpatialWebDelivery.fetchTransform(
          'https://x/m',
          client: MockClient(
            (_) async => http.Response(jsonEncode({'pad': 'a' * 300000}), 200),
          ),
        ),
        isNull,
      );
      expect(await SpatialWebDelivery.fetchTransform(null), isNull);
    });

    group('resolveTransform', () {
      final splat = _variant('spatial_preview', 'cidSplat1', 'splat');
      SpatialWebLoadPlan planFor(SpatialContent content) =>
          SpatialWebDelivery.plan(
            content,
            splat,
            backendBase: 'https://api.kubus.site',
          );

      test('local content opens with its own Node placement, no request',
          () async {
        final content = _content(
          [splat],
          transform: {'matrix': _upright, 'matrixOrder': 'column-major'},
        );
        final plan = planFor(content);
        expect(plan.manifestUrl, isNull);
        final client = MockClient((request) async {
          fail('local content must not cause a request: ${request.url}');
        });
        final transform = await SpatialWebDelivery.resolveTransform(
          content,
          plan,
          client: client,
        );
        expect((transform?['matrix'] as List)[4], -1.0);
        expect(transform?['matrixOrder'], 'column-major');
      });

      test('local placement goes through the same validation as published',
          () async {
        final sheared = _upright.map((v) => v.toDouble()).toList()..[4] = 0.5;
        final content = _content([splat], transform: {'matrix': sheared});
        expect(
          await SpatialWebDelivery.resolveTransform(content, planFor(content)),
          isNull,
        );
        final noPlacement = _content([splat]);
        expect(
          await SpatialWebDelivery.resolveTransform(
              noPlacement, planFor(noPlacement)),
          isNull,
        );
      });

      test('a published manifest wins over the content placement', () async {
        final content = _content(
          [splat],
          manifestCid: 'bafyManifest',
          transform: {
            'position': [9, 9, 9]
          },
        );
        final client = MockClient((request) async {
          expect(request.url.toString(),
              'https://api.kubus.site/api/upload/file/bafyManifest');
          return http.Response(
            jsonEncode({
              'transform': {'matrix': _upright},
            }),
            200,
          );
        });
        final transform = await SpatialWebDelivery.resolveTransform(
          content,
          planFor(content),
          client: client,
        );
        expect((transform?['matrix'] as List)[4], -1.0);
        expect(transform?.containsKey('position'), isFalse);
      });
    });

    test('the manifest size cap bounds the download, not only the parsing',
        () async {
      var drained = 0;
      // A declared length above the cap is refused before any body is read.
      final declared = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable(<List<int>>[
            <int>[0x7b],
          ]).map((chunk) {
            drained += chunk.length;
            return chunk;
          }),
          200,
          contentLength: SpatialWebDelivery.manifestMaxBytes + 1,
        );
      });
      expect(
        await SpatialWebDelivery.fetchTransform('https://x/m',
            client: declared),
        isNull,
      );
      expect(drained, 0);

      // No declared length (chunked): the stream is dropped once past the cap.
      var pulled = 0;
      final chunked = MockClient.streaming((request, bodyStream) async {
        Stream<List<int>> endless() async* {
          while (true) {
            pulled += 65536;
            yield List<int>.filled(65536, 0x20);
          }
        }

        return http.StreamedResponse(endless(), 200);
      });
      expect(
        await SpatialWebDelivery.fetchTransform('https://x/m', client: chunked),
        isNull,
      );
      expect(pulled, lessThan(SpatialWebDelivery.manifestMaxBytes * 3));
    });

    test('the timeout is one total deadline, not an idle timeout per chunk',
        () async {
      // A server that drips a small chunk well inside the idle window forever
      // never goes idle, yet the whole read must still end at the deadline.
      var chunksSent = 0;
      final dripping = MockClient.streaming((request, bodyStream) async {
        Stream<List<int>> drip() async* {
          while (true) {
            await Future<void>.delayed(const Duration(milliseconds: 40));
            chunksSent++;
            yield <int>[0x20];
          }
        }

        return http.StreamedResponse(drip(), 200);
      });
      final clock = Stopwatch()..start();
      final result = await SpatialWebDelivery.fetchTransform(
        'https://x/m',
        client: dripping,
        timeout: const Duration(milliseconds: 400),
      );
      clock.stop();
      expect(result, isNull);
      expect(chunksSent, greaterThan(2), reason: 'it was reading, not idle');
      expect(clock.elapsedMilliseconds, lessThan(1500));
    });
  });

  test('a published capture hands its manifest CID to the viewer', () {
    final capture = ArtworkSpatialCapture.fromJson({
      'id': 'spatial-1',
      'artworkId': 'art-1',
      'capturedAt': '2026-11-07T10:00:00Z',
      'publishedAt': '2026-11-22T10:00:00Z',
      'version': 1,
      'isCurrent': true,
      'canonicalManifestCid': 'bafyManifest',
      'variants': [
        {
          'role': 'spatial_manifest',
          'cid': 'bafyManifest',
          'format': 'json',
          'mimeType': 'application/json',
        },
        {
          'role': 'spatial_mobile',
          'cid': 'bafyMobile',
          'format': 'spz',
          'mimeType': 'application/octet-stream',
        },
      ],
    });
    expect(capture.content.manifestCid, 'bafyManifest');
    // The manifest is metadata, not a model the viewer may try to open.
    expect(capture.content.variants.map((v) => v.role), ['spatial_mobile']);
  });

  Map<String, dynamic> captureJson({
    String? canonicalManifestCid,
    String? manifestVariantCid,
  }) =>
      {
        'id': 'spatial-1',
        'artworkId': 'art-1',
        'capturedAt': '2026-11-07T10:00:00Z',
        'publishedAt': '2026-11-22T10:00:00Z',
        'version': 1,
        'isCurrent': true,
        'canonicalManifestCid': canonicalManifestCid,
        'variants': [
          if (manifestVariantCid != null)
            {
              'role': 'spatial_manifest',
              'cid': manifestVariantCid,
              'format': 'json',
              'mimeType': 'application/json',
            },
          {
            'role': 'spatial_mobile',
            'cid': 'bafyMobile',
            'format': 'spz',
            'mimeType': 'application/octet-stream',
          },
        ],
      };

  test('the viewer asks for the manifest variant, never the canonical record',
      () {
    // Staging: the canonical manifest CID is not served by /api/upload/file
    // (404 on every open); the spatial_manifest variant CID is.
    final capture = ArtworkSpatialCapture.fromJson(captureJson(
      canonicalManifestCid: 'bafyCanonical',
      manifestVariantCid: 'bafyManifestVariant',
    ));
    expect(capture.content.manifestCid, 'bafyManifestVariant');
    final plan = SpatialWebDelivery.plan(
      capture.content,
      capture.content.variants.single,
      backendBase: 'https://api.example',
    );
    expect(
        plan.manifestUrl,
        'https://api.example/api/upload/file/'
        'bafyManifestVariant');
    expect(plan.manifestUrl, isNot(contains('bafyCanonical')));
    expect(capture.content.variants.map((v) => v.role), ['spatial_mobile']);
  });

  test('without a manifest variant the canonical CID is the only candidate',
      () {
    final capture = ArtworkSpatialCapture.fromJson(
        captureJson(canonicalManifestCid: 'bafyCanonical'));
    expect(capture.manifestVariantCid, isNull);
    expect(capture.content.manifestCid, 'bafyCanonical');
    final none = ArtworkSpatialCapture.fromJson(captureJson());
    expect(none.content.manifestCid, isNull);
  });
}
