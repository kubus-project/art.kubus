import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/services/storage_config.dart';
import 'package:art_kubus/utils/artwork_media_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const _cidV1 = 'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi';
const _gateway = 'https://dweb.link/ipfs/';

Artwork _artwork({String? imageUrl, Map<String, dynamic>? metadata}) {
  return Artwork(
    id: 'art-1',
    title: 'River Light',
    artist: 'Mara Kovac',
    description: 'Description',
    position: const LatLng(46.0511, 14.5051),
    rewards: 0,
    createdAt: DateTime.utc(2026, 1, 1),
    imageUrl: imageUrl,
    metadata: metadata,
  );
}

void main() {
  final originalCustom = StorageConfig.customHttpBackend;

  setUp(() {
    StorageConfig.customHttpBackend = null;
    StorageConfig.setHttpBackend('https://api.example.test');
  });

  tearDown(() {
    StorageConfig.customHttpBackend = originalCustom;
  });

  group('ArtworkMediaResolver.resolveCover chain', () {
    test('the artwork image URL wins over every metadata key', () {
      final cover = ArtworkMediaResolver.resolveCover(
        artwork: _artwork(
          imageUrl: 'https://cdn.example.com/primary.jpg',
          metadata: const {'coverImageUrl': 'https://cdn.example.com/meta.jpg'},
        ),
      );
      expect(cover, equals('https://cdn.example.com/primary.jpg'));
    });

    test('a canonical cover metadata key beats its legacy spelling', () {
      final cover = ArtworkMediaResolver.resolveCover(
        metadata: const {
          'cover_image_url': 'https://cdn.example.com/legacy.jpg',
          'coverImageUrl': 'https://cdn.example.com/canonical.jpg',
        },
      );
      expect(cover, equals('https://cdn.example.com/canonical.jpg'));
    });

    test('a metadata CID resolves through the gateway when no URL exists', () {
      final cover = ArtworkMediaResolver.resolveCover(
        artwork: _artwork(metadata: const {'imageCid': _cidV1}),
      );
      expect(cover, equals('$_gateway$_cidV1'));
    });

    test('an unsafe artwork URL falls through to the next usable reference',
        () {
      final cover = ArtworkMediaResolver.resolveCover(
        artwork: _artwork(
          imageUrl: 'javascript:alert(1)',
          metadata: const {'image': 'https://cdn.example.com/meta.jpg'},
        ),
      );
      expect(cover, equals('https://cdn.example.com/meta.jpg'));
    });

    test('non-string metadata values are never stringified into a URL', () {
      final cover = ArtworkMediaResolver.resolveCover(
        metadata: const {
          'coverImageUrl': {'url': 'https://cdn.example.com/nested.jpg'},
          'image': ['https://cdn.example.com/list.jpg'],
        },
      );
      expect(cover, isNull);
    });

    test('the explicit fallback is used before additional URLs', () {
      final cover = ArtworkMediaResolver.resolveCover(
        fallbackUrl: '/uploads/fallback.jpg',
        additionalUrls: const ['https://cdn.example.com/extra.jpg'],
      );
      expect(cover, equals('https://api.example.test/uploads/fallback.jpg'));
    });

    test('data: additional URLs are rejected, not passed through', () {
      final cover = ArtworkMediaResolver.resolveCover(
        additionalUrls: const [null, 'data:image/png;base64,AAAA'],
      );
      expect(cover, isNull);
    });

    test('a missing cover stays missing', () {
      expect(ArtworkMediaResolver.resolveCover(), isNull);
      expect(ArtworkMediaResolver.resolveCover(artwork: _artwork()), isNull);
    });

    test('maxWidth clamps the width of a direct image URL', () {
      final cover = ArtworkMediaResolver.resolveCover(
        artwork: _artwork(
          imageUrl: 'https://images.example.com/path/photo.jpg?width=4000',
        ),
        maxWidth: 640,
      );
      expect(cover, contains('width=640'));
    });
  });

  group('ArtworkMediaResolver.coverRefsFromMetadata', () {
    test('lists cover keys in chain order and then the CID keys', () {
      final refs = ArtworkMediaResolver.coverRefsFromMetadata(const {
        'imageCid': _cidV1,
        'banner': 'https://cdn.example.com/banner.jpg',
        'coverImageUrl': 'https://cdn.example.com/cover.jpg',
      });
      expect(refs, const [
        'https://cdn.example.com/cover.jpg',
        'https://cdn.example.com/banner.jpg',
        _cidV1,
      ]);
    });

    test('returns nothing for a missing or empty bag', () {
      expect(ArtworkMediaResolver.coverRefsFromMetadata(null), isEmpty);
      expect(ArtworkMediaResolver.coverRefsFromMetadata(const {}), isEmpty);
    });
  });
}
