import 'dart:convert';

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

SpatialContent _content(List<SpatialVariant> variants, {String? manifestCid}) =>
    SpatialContent(
      id: 'spatial-1',
      type: 'gaussianSplat',
      artworkId: 'art-1',
      captureId: 'capture-1',
      capturedAt: DateTime.utc(2026, 11, 7),
      variants: variants,
      manifestCid: manifestCid,
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

    test('the plan names the file type only when bytes carry no magic number',
        () {
      final splat = _variant('spatial_preview', 'cidSplat1', 'splat');
      final spz = _variant('spatial_mobile', 'cidSpz2', 'spz');
      final sog = _variant('spatial_mobile', 'cidSog3', 'sog');
      final content = _content([splat, spz, sog], manifestCid: 'bafyManifest');
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
      expect(plan(sog).fileType, isNull);
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
}
