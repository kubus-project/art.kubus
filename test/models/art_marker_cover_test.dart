import 'package:art_kubus/models/art_marker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cover chain on a marker: legacy payloads nest the cover keys one level down
/// under `metadata` or `meta`, and an unsafe reference must not hide the next.
void main() {
  ArtMarker markerWith(Map<String, dynamic> metadata) {
    return ArtMarker.fromMap(<String, dynamic>{
      'id': 'marker-1',
      'name': 'Marker',
      'description': 'A marker description.',
      'latitude': 46.0569,
      'longitude': 14.5058,
      'createdAt': '2026-07-01T10:00:00.000Z',
      'createdBy': 'tester',
      'metadata': metadata,
    });
  }

  group('ArtMarker.coverImageUrl', () {
    test('reads a cover nested under metadata', () {
      final marker = markerWith(<String, dynamic>{
        'metadata': <String, dynamic>{'coverImageUrl': '/uploads/cover.jpg'},
      });
      expect(marker.coverImageUrl, '/uploads/cover.jpg');
    });

    test('reads a cover nested under meta', () {
      final marker = markerWith(<String, dynamic>{
        'meta': <String, dynamic>{'cover_image_url': '/uploads/meta-cover.jpg'},
      });
      expect(marker.coverImageUrl, '/uploads/meta-cover.jpg');
    });

    test('a typed outer cover wins over a nested one', () {
      final marker = markerWith(<String, dynamic>{
        'coverImageUrl': '/uploads/outer.jpg',
        'metadata': <String, dynamic>{'coverImageUrl': '/uploads/nested.jpg'},
      });
      expect(marker.coverImageUrl, '/uploads/outer.jpg');
    });

    test('an unsafe cover is skipped for the next safe reference', () {
      final marker = markerWith(<String, dynamic>{
        'coverImageUrl': 'javascript:alert(1)',
        'metadata': <String, dynamic>{'imageCid': 'ipfs://bafy-placeholder'},
        'image': '/uploads/image.jpg',
      });
      expect(marker.coverImageUrl, '/uploads/image.jpg');
    });

    test('an IPFS CID counts as a cover reference', () {
      final marker = markerWith(<String, dynamic>{
        'imageCid':
            'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
      });
      expect(
        marker.coverImageUrl,
        'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
      );
    });

    test('no usable cover reads as null', () {
      final marker = markerWith(<String, dynamic>{
        'coverImageUrl': 'placeholder://cover',
        'metadata': <String, dynamic>{'coverImageUrl': '   '},
      });
      expect(marker.coverImageUrl, isNull);
    });
  });
}
