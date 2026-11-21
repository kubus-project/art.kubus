import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/utils/media_url_resolver.dart';

Artwork fixture(String group) => Artwork(
      id: 'synthetic-artwork',
      title: 'Synthetic',
      artist: 'Artist',
      description: '',
      position: const LatLng(0, 0),
      rewards: 0,
      createdAt: DateTime.utc(2026),
      galleryUrls: const ['/uploads/artworks/gallery/a.jpg'],
      galleryMeta: [
        {'url': '/uploads/artworks/gallery/a.jpg', 'variantGroupId': group},
      ],
    );

void main() {
  test('accepts only server manifest matching the exact gallery source',
      () async {
    final group = 'a' * 64;
    final provider = ArtworkProvider(
        imageVariantLoader: (id) async => {
              'groupId': id,
              'sourceUrl': '/uploads/artworks/gallery/a.jpg',
              'variants': [
                {
                  'url': '/api/upload/derivatives/$id/card',
                  'width': 768,
                  'height': 384
                },
                {
                  'url': 'https://untrusted.example/image.jpg',
                  'width': 768,
                  'height': 384
                },
              ],
            });
    addTearDown(provider.dispose);
    final artwork = fixture(group);
    provider.addOrUpdateArtwork(artwork);
    expect(provider.imageVariantsPending(artwork), isTrue);
    await provider.loadArtworkImageVariants(artwork.id);
    final records = provider.imageVariantsForArtwork(artwork.id);
    expect(provider.imageVariantsPending(artwork), isFalse);
    expect(records.single['sourceUrl'],
        MediaUrlResolver.resolveDisplayUrl('/uploads/artworks/gallery/a.jpg'));
    expect((records.single['variants'] as List).length, 1);
  });

  test('rejects a group belonging to a different source and falls back',
      () async {
    final provider = ArtworkProvider(
        imageVariantLoader: (id) async => {
              'groupId': id,
              'sourceUrl': '/uploads/artworks/gallery/other.jpg',
              'variants': [
                {
                  'url': '/api/upload/derivatives/$id/card',
                  'width': 768,
                  'height': 384
                },
              ],
            });
    addTearDown(provider.dispose);
    final artwork = fixture('b' * 64);
    provider.addOrUpdateArtwork(artwork);
    await provider.loadArtworkImageVariants(artwork.id);
    expect(provider.imageVariantsPending(artwork), isFalse);
    expect(provider.imageVariantsForArtwork(artwork.id), isEmpty);
  });

  test('an artwork change during a fetch cannot attach the stale manifest',
      () async {
    final first = Completer<Map<String, dynamic>?>();
    final oldGroup = 'a' * 64;
    final newGroup = 'b' * 64;
    final provider = ArtworkProvider(imageVariantLoader: (id) async {
      if (id == oldGroup) return first.future;
      return {
        'groupId': id,
        'sourceUrl': '/uploads/artworks/gallery/a.jpg',
        'variants': [
          {
            'url': '/api/upload/derivatives/$id/card',
            'width': 768,
            'height': 384
          },
        ],
      };
    });
    addTearDown(provider.dispose);
    provider.addOrUpdateArtwork(fixture(oldGroup));
    final oldLoad = provider.loadArtworkImageVariants('synthetic-artwork');
    provider.addOrUpdateArtwork(fixture(newGroup));
    first.complete({
      'groupId': oldGroup,
      'sourceUrl': '/uploads/artworks/gallery/a.jpg',
      'variants': [
        {
          'url': '/api/upload/derivatives/$oldGroup/card',
          'width': 768,
          'height': 384
        },
      ],
    });
    await oldLoad;
    await provider.loadArtworkImageVariants('synthetic-artwork');
    final record = provider.imageVariantsForArtwork('synthetic-artwork').single;
    expect((record['variants'] as List).single['url'],
        '/api/upload/derivatives/$newGroup/card');
  });
}
