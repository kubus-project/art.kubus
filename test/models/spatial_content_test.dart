import 'package:art_kubus/models/kubus_node_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses renderer-neutral versioned spatial history records', () {
    final content = SpatialContent.fromJson({
      'schema': 'kubus.spatial/1',
      'id': 'spatial-2026-08',
      'type': 'gaussianSplat',
      'artworkId': 'mural-1',
      'markerId': 'marker-1',
      'captureId': 'capture-1',
      'capturedAt': '2026-08-10T12:00:00Z',
      'variants': [
        {
          'role': 'spatial_mobile',
          'cid': 'bafy-mobile',
          'sizeBytes': 4096,
          'mimeType': 'application/x-splat',
          'format': 'ply',
          'storageClass': 'warm',
        }
      ],
    });

    expect(content.type, 'gaussianSplat');
    expect(content.markerId, 'marker-1');
    expect(content.variants.single.storageClass, 'warm');
  });

  test('rejects unknown spatial schema versions', () {
    expect(
      () => SpatialContent.fromJson({'schema': 'kubus.spatial/99'}),
      throwsFormatException,
    );
  });
}
