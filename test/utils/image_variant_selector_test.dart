import 'package:art_kubus/utils/image_variant_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const variants = [
    {'url': '/full.jpg', 'width': 1440, 'height': 1920},
    {'url': '/thumb.jpg', 'width': 240, 'height': 320},
    {'url': '/card.jpg', 'width': 576, 'height': 768},
    {'url': '/detail.jpg', 'width': 960, 'height': 1280},
  ];

  String? select(
    double width,
    double height,
    double dpr, {
    Iterable<dynamic>? input = variants,
  }) =>
      ImageVariantSelector.select(
        variants: input,
        fallbackUrl: '/legacy.jpg',
        logicalWidth: width,
        logicalHeight: height,
        devicePixelRatio: dpr,
      );

  test('uses the smallest sufficient longest edge for the physical size', () {
    expect(select(100, 100, 2), '/thumb.jpg');
    expect(select(300, 180, 2), '/card.jpg');
    expect(select(300, 180, 3), '/detail.jpg');
    expect(select(700, 500, 2), '/full.jpg');
  });

  test('uses largest provided variant when the requested size is greater', () {
    expect(select(1500, 1000, 2), '/full.jpg');
  });

  test(
    'falls back for old records, invalid dimensions and empty manifests',
    () {
      expect(select(100, 100, 2, input: null), '/legacy.jpg');
      expect(select(100, 100, 2, input: const []), '/legacy.jpg');
      expect(select(double.nan, 100, 2), '/legacy.jpg');
      expect(select(100, 100, 0), '/legacy.jpg');
      expect(select(0, 0, 2), '/legacy.jpg');
    },
  );

  test('ignores malformed entries and does not infer or rewrite URLs', () {
    final input = [
      null,
      {'url': '/bad.jpg', 'width': 320, 'height': -1},
      {'url': '/bad2.jpg', 'width': double.infinity, 'height': 320},
      {'url': 1, 'width': 320, 'height': 320},
      {'url': '  ipfs://cid/file  ', 'width': 768, 'height': 500},
    ];
    expect(select(200, 200, 2, input: input), 'ipfs://cid/file');
  });

  test(
    'binds only by explicit source identity, regardless of record order',
    () {
      final records = [
        {
          'sourceUrl': '/two.jpg',
          'variants': [
            {'url': '/two-small.jpg', 'width': 320, 'height': 240},
          ],
        },
        {
          'sourceUrl': '/one.jpg',
          'variants': [
            {'url': '/one-small.jpg', 'width': 320, 'height': 240},
          ],
        },
      ];
      String? forSource(String source, Iterable<dynamic> input) =>
          ImageVariantSelector.selectForSource(
            records: input,
            sourceUrl: source,
            fallbackUrl: source,
            logicalWidth: 100,
            logicalHeight: 100,
            devicePixelRatio: 2,
          );
      expect(forSource('/one.jpg', records), '/one-small.jpg');
      expect(forSource('/missing.jpg', records), '/missing.jpg');
      expect(forSource('/one.jpg', [...records, records.last]), '/one.jpg');
    },
  );

  test('prefetches only bounded identity-matched neighbors', () {
    final records = [
      {
        'sourceUrl': '/a',
        'variants': [
          {'url': '/a-small', 'width': 320, 'height': 240},
        ],
      },
      {
        'sourceUrl': '/b',
        'variants': [
          {'url': '/b-full', 'width': 1920, 'height': 1440},
        ],
      },
      {
        'sourceUrl': '/c',
        'variants': [
          {'url': '/c-small', 'width': 768, 'height': 576},
        ],
      },
    ];
    expect(
      ImageVariantSelector.galleryNeighborPreviews(
        sources: ['/c', '/b', '/a'],
        index: 1,
        records: records,
        logicalWidth: 300,
        logicalHeight: 200,
        devicePixelRatio: 2,
      ),
      ['/c-small', '/a-small'],
    );
    expect(
      ImageVariantSelector.galleryNeighborPreviews(
        sources: ['/a', '/b'],
        index: 0,
        records: records,
        logicalWidth: 300,
        logicalHeight: 200,
        devicePixelRatio: 2,
      ),
      isEmpty,
    );
  });
}
