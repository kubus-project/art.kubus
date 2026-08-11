import 'dart:typed_data';

import 'package:art_kubus/providers/spatial_capture_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tracked capture reports coverage and device depth honestly', () {
    final provider = SpatialCaptureProvider()
      ..begin(artworkId: 'art-1', capturedBy: 'wallet-1');

    for (var index = 0; index < 10; index++) {
      provider.addTrackedFrame({
        'rgb': Uint8List.fromList([1, 2, 3]),
        'timestampNanos': index,
        'poseTranslation': [0, 0, index / 10],
        'intrinsics': {'fx': 100, 'fy': 100},
        'depthAvailable': index == 9,
        if (index == 9) 'depth': Uint8List.fromList([0, 1]),
      });
    }

    expect(provider.frameCount, 10);
    expect(provider.coverage, 0.25);
    expect(provider.depthObserved, isTrue);
    expect(provider.guidance, contains('overlap'));
  });

  test('capture rejects samples without an RGB frame', () {
    final provider = SpatialCaptureProvider()..begin(artworkId: 'art-1');
    expect(
      () => provider.addTrackedFrame({'depthAvailable': false}),
      throwsFormatException,
    );
  });
}
