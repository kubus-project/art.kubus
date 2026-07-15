import 'package:art_kubus/providers/public_entity_takeover_provider.dart';
import 'package:art_kubus/services/share/share_deep_link_parser.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seeds only an exact localized canonical artwork pathname', () {
    final provider = PublicEntityTakeoverProvider();
    const target = ShareDeepLinkTarget(
      type: ShareEntityType.artwork,
      id: 'art-42',
      localeCode: 'en',
    );

    provider.seed(
      initialUri: Uri.parse('/en/artworks/art-42?ref=search#details'),
      target: target,
    );

    expect(provider.target?.type, 'artwork');
    expect(provider.target?.id, 'art-42');
    expect(provider.target?.path, '/en/artworks/art-42');
    expect(
      provider.returnRouteForArtwork('art-42'),
      '/en/artworks/art-42?ref=search#details',
    );
  });

  test('rejects compact, mismatched, and wallet takeover targets', () {
    final compact = PublicEntityTakeoverProvider();
    compact.seed(
      initialUri: Uri.parse('/a/art-42'),
      target: const ShareDeepLinkTarget(
        type: ShareEntityType.artwork,
        id: 'art-42',
      ),
    );
    expect(compact.target, isNull);

    final mismatch = PublicEntityTakeoverProvider();
    mismatch.seed(
      initialUri: Uri.parse('/en/artworks/different'),
      target: const ShareDeepLinkTarget(
        type: ShareEntityType.artwork,
        id: 'art-42',
        localeCode: 'en',
      ),
    );
    expect(mismatch.target, isNull);

    final profile = PublicEntityTakeoverProvider();
    profile.seed(
      initialUri: Uri.parse('/en/profiles/user-1'),
      target: const ShareDeepLinkTarget(
        type: ShareEntityType.profile,
        id: 'user-1',
        localeCode: 'en',
      ),
    );
    expect(profile.target?.type, 'profile');

    final collectible = PublicEntityTakeoverProvider();
    collectible.seed(
      initialUri: Uri.parse('/en/collectibles/nft-1'),
      target: const ShareDeepLinkTarget(
        type: ShareEntityType.nft,
        id: 'nft-1',
        localeCode: 'en',
      ),
    );
    expect(collectible.target, isNull);
  });

  test('covers the localized public-read entity route matrix', () {
    const cases = <(ShareEntityType, String, String)>[
      (ShareEntityType.profile, 'profiles', 'profili'),
      (ShareEntityType.event, 'events', 'dogodki'),
      (ShareEntityType.exhibition, 'exhibitions', 'razstave'),
      (ShareEntityType.collection, 'collections', 'zbirke'),
      (ShareEntityType.post, 'posts', 'objave'),
      (ShareEntityType.marker, 'map', 'zemljevid'),
    ];

    for (final (type, english, slovenian) in cases) {
      for (final (locale, segment) in <(String, String)>[
        ('en', english),
        ('sl', slovenian),
      ]) {
        final provider = PublicEntityTakeoverProvider();
        provider.seed(
          initialUri: Uri.parse('/$locale/$segment/entity-1'),
          target: ShareDeepLinkTarget(
            type: type,
            id: 'entity-1',
            localeCode: locale,
          ),
        );
        expect(provider.target?.id, 'entity-1');
      }
    }
  });

  testWidgets(
    'readiness waits for the matching artwork and a completed frame',
    (tester) async {
      final provider = PublicEntityTakeoverProvider();
      provider.seed(
        initialUri: Uri.parse('/sl/umetnine/art-42'),
        target: const ShareDeepLinkTarget(
          type: ShareEntityType.artwork,
          id: 'art-42',
          localeCode: 'sl',
        ),
      );

      await provider.markArtworkReady('different');
      expect(provider.isReady, isFalse);

      final ready = provider.markArtworkReady('art-42');
      expect(provider.isReady, isFalse);
      await tester.pump();
      await ready;
      expect(provider.isReady, isTrue);
    },
  );
}
