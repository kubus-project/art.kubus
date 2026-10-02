import 'package:art_kubus/models/kubus_node_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compute candidate reads backend queue and reliability fields', () {
    final candidate = KubusComputeCandidate.fromJson({
      'nodeId': 'node-1',
      'label': 'Studio node',
      'encryptionPublicKey': 'enc',
      'signingPublicKey': 'sig',
      'gpu': {'totalVramBytes': 12 * 1024 * 1024 * 1024},
      'worker': <String, dynamic>{},
      'queue': {'queued': 3},
      'reliability': {'successfulJobRate': 0.975},
      'rankScore': 10,
    });

    expect(candidate.jobsAhead, 3);
    expect(candidate.successRate, 0.975);
  });

  test('canonical spatial history selects current and preserves chronology',
      () {
    final history = ArtworkSpatialHistory.fromJson({
      'history': [
        {
          'id': 'capture-new',
          'artworkId': 'art-1',
          'capturedAt': '2026-08-11T12:00:00Z',
          'publishedAt': '2026-08-11T13:00:00Z',
          'version': 1,
          'isCurrent': true,
          'variants': [
            {
              'role': 'spatial_mobile',
              'cid': 'bafymobile',
              'sizeBytes': 123,
              'mimeType': 'application/octet-stream',
              'format': 'splat',
              'storageClass': 'warm',
            },
          ],
        },
        {
          'id': 'capture-old',
          'artworkId': 'art-1',
          'capturedAt': '2026-04-04T12:00:00Z',
          'publishedAt': '2026-04-04T13:00:00Z',
          'version': 1,
          'isCurrent': false,
          'variants': <Map<String, dynamic>>[],
        },
      ],
    });

    expect(history.current?.id, 'capture-new');
    expect(history.history.map((capture) => capture.id),
        ['capture-new', 'capture-old']);
    expect(history.current?.content.variants.single.role, 'spatial_mobile');
  });
}
