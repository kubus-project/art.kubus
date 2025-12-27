import 'package:art_kubus/models/collection_record.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UserProfile.fromJson maps cover image key variants', () {
    final base = <String, dynamic>{
      'id': 'p1',
      'walletAddress': '0xabc',
      'username': 'user',
      'displayName': 'User',
      'bio': '',
      'avatar': '',
      'createdAt': '2024-01-01T00:00:00.000Z',
      'updatedAt': '2024-01-01T00:00:00.000Z',
    };

    final cases = <Map<String, dynamic>>[
      {'key': 'coverImage', 'value': '/uploads/a.jpg'},
      {'key': 'coverImageUrl', 'value': '/uploads/b.jpg'},
      {'key': 'cover_image_url', 'value': '/uploads/c.jpg'},
      {'key': 'cover_image', 'value': '/uploads/d.jpg'},
      {'key': 'coverUrl', 'value': '/uploads/e.jpg'},
      {'key': 'cover_url', 'value': '/uploads/f.jpg'},
    ];

    for (final c in cases) {
      final json = <String, dynamic>{...base, c['key'] as String: c['value']};
      final profile = UserProfile.fromJson(json);
      expect(profile.coverImage, c['value']);
    }
  });

  test('CollectionArtworkRecord.fromMap maps cover image key variants', () {
    final topLevel = CollectionArtworkRecord.fromMap(<String, dynamic>{
      'id': 'a1',
      'title': 'Top',
      'imageUrl': '/uploads/top.jpg',
      'imageCid': 'bafyTop',
      'artwork': <String, dynamic>{
        'coverImageUrl': '/uploads/nested.jpg',
        'imageCid': 'bafyNested',
      },
    });

    expect(topLevel.imageUrl, '/uploads/top.jpg');
    expect(topLevel.imageCid, 'bafyTop');

    final nestedOnly = CollectionArtworkRecord.fromMap(<String, dynamic>{
      'artworkId': 'a2',
      'title': 'Nested',
      'artwork': <String, dynamic>{
        'cover_image_url': '/uploads/nested_only.jpg',
        'image_cid': 'bafyNestedOnly',
      },
    });

    expect(nestedOnly.id, 'a2');
    expect(nestedOnly.imageUrl, '/uploads/nested_only.jpg');
    expect(nestedOnly.imageCid, 'bafyNestedOnly');
  });
}

