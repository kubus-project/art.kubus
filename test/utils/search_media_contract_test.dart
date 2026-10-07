import 'package:art_kubus/utils/home_search_destination.dart';
import 'package:art_kubus/utils/search_suggestions.dart';
import 'package:art_kubus/widgets/search/kubus_search_result.dart';
import 'package:flutter_test/flutter_test.dart';

/// Slice B: one media reference per suggestion, chosen by result kind, and a
/// collection that is its own kind. The wire shape is what
/// `/api/search/suggestions` sends: a legacy `icon` plus `avatarUrl` for people
/// and `imageUrl` for everything else.
const _uploaderWallet = 'HcHchGrD9ECWJ7nJaovpEohpdAUfpJPqAFv4z1g6KuMb';

KubusSearchResult _normalize(Map<String, dynamic> raw) =>
    KubusSearchResult.fromMap(normalizeSearchSuggestionsPayload([raw]).single);

void main() {
  group('media by result kind', () {
    test('an artwork shows its own image, from imageUrl', () {
      final result = _normalize({
        'type': 'artwork',
        'id': 'a1',
        'label': 'Robba Fountain',
        'imageUrl': '/uploads/artworks/covers/robba.jpg',
        'icon': '/uploads/artworks/covers/robba.jpg',
      });
      expect(result.previewImageUrl, '/uploads/artworks/covers/robba.jpg');
      expect(result.avatarUrl, isNull);
    });

    test('an artwork from an older backend falls back to the legacy icon', () {
      final result = _normalize({
        'type': 'artwork',
        'id': 'a1',
        'label': 'Robba Fountain',
        'icon': 'uploads/artworks/covers/robba.jpg',
      });
      expect(result.previewImageUrl, 'uploads/artworks/covers/robba.jpg');
      expect(result.avatarUrl, isNull);
    });

    test('a profile shows its avatar, never an artwork-style image', () {
      final result = _normalize({
        'type': 'profile',
        'id': _uploaderWallet,
        'label': 'Rok',
        'avatarUrl': '/uploads/profiles/avatars/rok.jpg',
        'icon': '/uploads/profiles/avatars/rok.jpg',
      });
      expect(result.avatarUrl, '/uploads/profiles/avatars/rok.jpg');
      expect(result.previewImageUrl, isNull);
    });

    test('a profile from an older backend reads the legacy icon as avatar', () {
      final result = _normalize({
        'type': 'profile',
        'id': _uploaderWallet,
        'label': 'Rok',
        'icon': '/uploads/profiles/avatars/rok.jpg',
      });
      expect(result.avatarUrl, '/uploads/profiles/avatars/rok.jpg');
      expect(result.previewImageUrl, isNull);
    });

    test('an institution shows its logo, then its banner', () {
      expect(
        _normalize({
          'type': 'institution',
          'id': 'i1',
          'label': 'Moderna galerija',
          'logoUrl': '/uploads/institutions/logo.png',
          'bannerUrl': '/uploads/institutions/banner.png',
        }).previewImageUrl,
        '/uploads/institutions/logo.png',
      );
      expect(
        _normalize({
          'type': 'institution',
          'id': 'i1',
          'label': 'Moderna galerija',
          'bannerUrl': '/uploads/institutions/banner.png',
        }).previewImageUrl,
        '/uploads/institutions/banner.png',
      );
      expect(
        _normalize({
          'type': 'institution',
          'id': 'i1',
          'label': 'Moderna galerija',
          'icon': '/uploads/institutions/logo.png',
        }).previewImageUrl,
        '/uploads/institutions/logo.png',
      );
    });

    test('a collection shows its cover', () {
      final result = _normalize({
        'type': 'collection',
        'id': 'c1',
        'label': 'Ljubljana fountains',
        'imageUrl': '/uploads/collections/cover.jpg',
        'icon': '/uploads/collections/cover.jpg',
        'artworkCount': 4,
      });
      expect(result.previewImageUrl, '/uploads/collections/cover.jpg');
      expect(result.avatarUrl, isNull);
    });

    test('a collection cover also reads from coverUrl', () {
      final result = _normalize({
        'type': 'collection',
        'id': 'c1',
        'label': 'Ljubljana fountains',
        'coverUrl': '/uploads/collections/cover.jpg',
      });
      expect(result.previewImageUrl, '/uploads/collections/cover.jpg');
    });
  });

  group('collection kind', () {
    test('the wire type collection normalizes to the collection kind', () {
      final result = _normalize({
        'type': 'collection',
        'id': 'c1',
        'label': 'Ljubljana fountains',
        'subtitle': 'City curator',
        'artworkCount': 4,
      });
      expect(result.kind, KubusSearchResultKind.collection);
      expect(result.collectionId, 'c1');
      expect(result.collectionArtworkCount, 4);
      expect(result.detail, 'City curator');
      expect(result.artworkId, isNull);
    });

    test('a collection id is never reported as an artwork id', () {
      final result = _normalize({
        'type': 'collection',
        'id': 'c1',
        'label': 'Ljubljana fountains',
      });
      expect(result.artworkId, isNull);
      expect(result.collectionId, 'c1');
    });

    test('a collection with no recorded owner shows no invented subtitle', () {
      final result = _normalize({
        'type': 'collection',
        'id': 'c1',
        'label': 'Ljubljana fountains',
        'username': 'uploader',
        'walletAddress': _uploaderWallet,
      });
      expect(result.detail, isNull);
    });

    test('a type this client does not know is not guessed into an artwork', () {
      expect(
        KubusSearchResult.tryFromMap({
          'type': 'hologram',
          'id': 'x1',
          'label': 'Unknown kind',
        }),
        isNull,
      );
      expect(
        KubusSearchResult.tryFromMap({
          'type': 'collection',
          'id': 'c1',
          'label': 'Known',
        })?.kind,
        KubusSearchResultKind.collection,
      );
    });
  });

  group('collection destination', () {
    test('opens the collection, never an artwork', () {
      final destination = HomeSearchDestination.fromResult(
        const KubusSearchResult(
          label: 'Ljubljana fountains',
          kind: KubusSearchResultKind.collection,
          id: 'c1',
        ),
      );
      expect(destination.kind, HomeSearchDestinationKind.collection);
      expect(destination.id, 'c1');
    });

    test('a collection without an id has no destination at all', () {
      final destination = HomeSearchDestination.fromResult(
        const KubusSearchResult(
          label: 'Ljubljana fountains',
          kind: KubusSearchResultKind.collection,
        ),
      );
      expect(destination.kind, HomeSearchDestinationKind.none);
    });
  });

  group('authorship survives the media contract', () {
    test('an artwork with no recorded artist stays unknown', () {
      final result = _normalize({
        'type': 'artwork',
        'id': '4e380159-2269-4e02-b206-3a0d2fdecb82',
        'label': 'Cours Julliene',
        'imageUrl': '/uploads/artworks/covers/cours.jpg',
        'icon': '/uploads/artworks/covers/cours.jpg',
        'username': 'uploader',
        'displayName': 'Uploader',
        'walletAddress': _uploaderWallet,
        'imageAuthor': 'Different Photographer',
      });
      expect(result.detail, isNull);
      expect(result.previewImageUrl, '/uploads/artworks/covers/cours.jpg');
    });

    test('a recorded artist is kept next to the cover', () {
      final result = _normalize({
        'type': 'artwork',
        'id': 'work-1',
        'label': 'Robba Fountain',
        'subtitle': 'Francesco Robba',
        'imageUrl': '/uploads/artworks/covers/robba.jpg',
        'walletAddress': _uploaderWallet,
        'username': 'uploader',
      });
      expect(result.detail, 'Francesco Robba');
    });

    test('an artwork id is not turned into a subtitle', () {
      final result = _normalize({
        'type': 'artwork',
        'id': '29b5d1c4-0000-4000-8000-0000000cffb0',
        'label': 'Cours Julliene',
        'subtitle': null,
      });
      expect(result.detail, isNull);
    });
  });
}
