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

  group('byte routes', () {
    test('the registry-authorised backend route comes first, then gateways',
        () {
      final urls = SpatialWebDelivery.candidateUrls(
        'bafyCid',
        backendBase: 'https://api.kubus.site/',
        gateways: const [
          'https://gw.example/ipfs/',
          'https://gw2.example/ipfs'
        ],
      );
      expect(urls, [
        'https://api.kubus.site/api/upload/file/bafyCid',
        'https://gw.example/ipfs/bafyCid',
        'https://gw2.example/ipfs/bafyCid',
      ]);
    });

    test('never offers an insecure or LAN route to a secure page', () {
      final urls = SpatialWebDelivery.candidateUrls(
        'bafyCid',
        backendBase: 'http://api.kubus.site',
        gateways: const [
          'http://192.168.1.20:8080/ipfs/',
          'https://gw.example/ipfs/',
        ],
      );
      expect(urls, ['https://gw.example/ipfs/bafyCid']);
    });

    test('a local build may use its own loopback backend', () {
      final urls = SpatialWebDelivery.candidateUrls(
        'bafyCid',
        backendBase: 'http://127.0.0.1:3000',
        gateways: const [],
      );
      expect(urls, ['http://127.0.0.1:3000/api/upload/file/bafyCid']);
    });

    test('the plan names the file type only when bytes carry no magic number',
        () {
      final splat = _variant('spatial_preview', 'c1', 'splat');
      final spz = _variant('spatial_mobile', 'c2', 'spz');
      final sog = _variant('spatial_mobile', 'c3', 'sog');
      final content = _content([splat, spz, sog], manifestCid: 'bafyManifest');
      SpatialWebLoadPlan plan(SpatialVariant v) => SpatialWebDelivery.plan(
            content,
            v,
            backendBase: 'https://api.kubus.site',
            gateways: const [],
          );
      expect(plan(splat).fileType, 'splat');
      expect(plan(splat).manifestUrl,
          'https://api.kubus.site/api/upload/file/bafyManifest');
      expect(plan(splat).isArchiveTier, isFalse);
      expect(plan(spz).fileType, 'spz');
      expect(plan(sog).fileType, isNull);
    });

    test('no manifest CID means no manifest route', () {
      final v = _variant('spatial_mobile', 'c', 'spz');
      expect(
        SpatialWebDelivery.plan(
          _content([v]),
          v,
          backendBase: 'https://api.kubus.site',
          gateways: const [],
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
