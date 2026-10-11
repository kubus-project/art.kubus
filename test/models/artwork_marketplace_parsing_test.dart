import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/utils/profile_showcase_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseArtworkFromBackendJson preserves nft identity and market fields',
      () {
    final artwork = parseArtworkFromBackendJson(<String, dynamic>{
      'id': 'art-1',
      'title': 'Minted Artwork',
      'artist': 'Artist',
      'description': 'Desc',
      'image_url': '/uploads/art-1-cover.png',
      'gallery_urls': ['/uploads/art-1-gallery.png'],
      'gallery_meta': [
        {'url': '/uploads/art-1-gallery.png', 'kind': 'gallery'}
      ],
      'price': 42.5,
      'currency': 'KUB8',
      'is_for_sale': true,
      'nft': <String, dynamic>{
        'mintAddress': 'mint-abc',
        'metadataUri': 'ipfs://meta-abc',
      },
      'created_at': '2025-01-01T00:00:00.000Z',
      'latitude': 46.0,
      'longitude': 14.0,
      'rewards': 3,
    });

    expect(artwork.isNft, isTrue);
    expect(artwork.nftMintAddress, 'mint-abc');
    expect(artwork.nftMetadataUri, 'ipfs://meta-abc');
    expect(artwork.isForSale, isTrue);
    expect(artwork.price, 42.5);
    expect(artwork.currency, 'KUB8');
    expect(artwork.galleryUrls, hasLength(1));
    expect(artwork.galleryMeta, hasLength(1));
    expect(artwork.imageUrl, contains('/uploads/art-1-cover.png'));
  });

  test(
      'parseArtworkFromBackendJson keeps nft-capable artwork out of minted proof without mint address',
      () {
    final artwork = parseArtworkFromBackendJson(<String, dynamic>{
      'id': 'art-2',
      'title': 'NFT Capable Artwork',
      'artist': 'Artist',
      'description': 'Desc',
      'is_nft': true,
      'created_at': '2025-01-02T00:00:00.000Z',
      'latitude': 46.0,
      'longitude': 14.0,
      'rewards': 1,
    });

    expect(artwork.isNft, isTrue);
    expect(artwork.nftMintAddress, isNull);
    expect(artwork.nftMetadataUri, isNull);
  });

  test('profile showcase artwork uses canonical nested stats like count', () {
    final payload = <String, dynamic>{
      'id': 'art-profile-1',
      'title': 'Profile Artwork',
      'description': 'Shown on a profile',
      'imageUrl': '/uploads/profile-art.png',
      'category': 'AR',
      'stats': <String, dynamic>{
        'viewsCount': 12,
        'likesCount': 37,
        'commentsCount': 4,
      },
      'createdAt': '2025-01-03T00:00:00.000Z',
    };

    final parsed = parseArtworkFromBackendJson(payload);
    final showcase = ProfileArtworkShowcaseData.fromMap(
      payload,
      fallbackTitle: 'Untitled',
      fallbackSubtitle: 'Artwork',
    );

    expect(parsed.likesCount, 37);
    expect(showcase.likesCount, 37);
    expect(showcase.title, 'Profile Artwork');
    expect(showcase.subtitle, 'AR');
  });

  group('artwork cover chain (image field, then CID, never raw)', () {
    Map<String, dynamic> artworkJson(Map<String, dynamic> extra) {
      return <String, dynamic>{
        'id': 'art-cover',
        'title': 'Cover Artwork',
        'artist': 'Artist',
        'latitude': 46.0,
        'longitude': 14.0,
        'created_at': '2025-01-01T00:00:00.000Z',
        ...extra,
      };
    }

    const cid = 'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi';

    test('a CID-only artwork gets its cover through the IPFS gateway chain',
        () {
      final artwork = parseArtworkFromBackendJson(
        artworkJson(<String, dynamic>{'image_cid': cid}),
      );
      expect(artwork.imageUrl, startsWith('https://dweb.link/ipfs/$cid'));
    });

    test('a stored image field wins over the CID', () {
      final artwork = parseArtworkFromBackendJson(
        artworkJson(<String, dynamic>{
          'image_url': '/uploads/cover.png',
          'image_cid': cid,
        }),
      );
      expect(artwork.imageUrl, endsWith('/uploads/cover.png'));
    });

    test('an unsafe image field falls through to the CID', () {
      final artwork = parseArtworkFromBackendJson(
        artworkJson(<String, dynamic>{
          'image_url': 'javascript:alert(1)',
          'image_cid': cid,
        }),
      );
      expect(artwork.imageUrl, startsWith('https://dweb.link/ipfs/$cid'));
    });

    test('a file name in the CID field is not read as a CID cover', () {
      final artwork = parseArtworkFromBackendJson(
        artworkJson(<String, dynamic>{'image_cid': 'IMG_1234.jpg'}),
      );
      expect(artwork.imageUrl, isNull);
    });

    test('unsafe gallery entries are dropped, not passed through raw', () {
      final artwork = parseArtworkFromBackendJson(
        artworkJson(<String, dynamic>{
          'gallery_urls': [
            'javascript:alert(1)',
            'http://cdn.example.com/a.jpg',
            '/uploads/ok.png',
          ],
        }),
      );
      expect(artwork.galleryUrls, hasLength(1));
      expect(artwork.galleryUrls.single, endsWith('/uploads/ok.png'));
    });

    test('an unresolvable POAP image is no image', () {
      final artwork = parseArtworkFromBackendJson(
        artworkJson(<String, dynamic>{
          'poap_image_url': 'javascript:alert(1)',
        }),
      );
      expect(artwork.poapImageUrl, isNull);
    });
  });
}
