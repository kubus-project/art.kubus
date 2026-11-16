import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'descriptor parser preserves nullable slots and only exposes supplied paths',
      () {
    final descriptor = ArtworkMediaPreviewDescriptor.tryParse(<String, Object?>{
      'auth': 'bearer',
      'cover': '/api/artworks/id/media/cover',
      'gallery': <Object?>[
        '/api/artworks/id/media/gallery-0',
        null,
        '',
        '/api/artworks/id/media/gallery-3',
      ],
      'poap': null,
    });

    expect(descriptor?.auth, 'bearer');
    expect(descriptor?.pathFor('cover'), '/api/artworks/id/media/cover');
    expect(
        descriptor?.pathFor('gallery-0'), '/api/artworks/id/media/gallery-0');
    expect(descriptor?.pathFor('gallery-1'), isNull);
    expect(
        descriptor?.pathFor('gallery-3'), '/api/artworks/id/media/gallery-3');
    expect(descriptor?.pathFor('gallery-100'), isNull);
    expect(descriptor?.pathFor('poap'), isNull);
    expect(ArtworkMediaPreviewDescriptor.tryParse(null), isNull);
  });

  test('detail parser distinguishes an absent descriptor from explicit null',
      () {
    final common = <String, dynamic>{
      'id': 'id',
      'title': 'Artwork',
      'latitude': 0,
      'longitude': 0,
      'isPublic': false,
    };

    expect(parseArtworkFromBackendJson(common).mediaPreviewProvided, isFalse);
    expect(
      parseArtworkFromBackendJson(<String, dynamic>{
        ...common,
        'mediaPreview': null,
      }).mediaPreviewProvided,
      isTrue,
    );
  });
}
