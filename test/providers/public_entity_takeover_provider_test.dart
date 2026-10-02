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

  test('public presentation requires matching canonical type ID and path', () {
    final provider = PublicEntityTakeoverProvider();
    provider.seed(
      initialUri: Uri.parse('/sl/profili/profile-9?source=qr'),
      target: const ShareDeepLinkTarget(
        type: ShareEntityType.profile,
        id: 'profile-9',
        localeCode: 'sl',
      ),
    );

    expect(
      provider.matchesCanonicalPath(
        type: 'profile',
        id: 'profile-9',
        pathname: '/sl/profili/profile-9',
      ),
      isTrue,
    );
    expect(
      provider.matchesCanonicalPath(
        type: 'event',
        id: 'profile-9',
        pathname: '/sl/profili/profile-9',
      ),
      isFalse,
    );
    expect(
      provider.matchesCanonicalPath(
        type: 'profile',
        id: 'different',
        pathname: '/sl/profili/profile-9',
      ),
      isFalse,
    );
    expect(
      provider.matchesCanonicalPath(
        type: 'profile',
        id: 'profile-9',
        pathname: '/en/profiles/profile-9',
      ),
      isFalse,
    );
  });

  test(
    'readiness accepts only the matching artwork after caller paint',
    () async {
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
      expect(provider.isReady, isTrue);
      await ready;
      expect(provider.isReady, isTrue);
    },
  );

  test(
    'accepts a fresh bootstrap only when identity and canonical path match',
    () {
      final provider = PublicEntityTakeoverProvider();
      const target = ShareDeepLinkTarget(
        type: ShareEntityType.artwork,
        id: 'art-42',
        localeCode: 'en',
      );
      final now = DateTime.utc(2026, 9, 23, 12);
      provider.seed(
        initialUri: Uri.parse('/en/artworks/art-42?from=search#details'),
        target: target,
      );
      final presentation = <String, dynamic>{
        'version': 1,
        'type': 'artwork',
        'id': 'art-42',
        'locale': 'en',
        'canonicalPath': '/en/artworks/art-42',
        'title': 'River Memory',
      };
      final payload = <String, dynamic>{
        'version': 1,
        'identity': <String, dynamic>{
          'type': 'artwork',
          'id': 'art-42',
          'locale': 'en',
          'canonicalPath': '/en/artworks/art-42',
        },
        'revision': List.filled(64, 'a').join(),
        'generatedAt': now.toIso8601String(),
        'expiresAt': now.add(const Duration(minutes: 10)).toIso8601String(),
        'presentation': presentation,
      };

      expect(
        provider.validateBootstrap(
          raw: payload,
          initialUri: Uri.parse('/en/artworks/art-42?from=search#details'),
          target: target,
          now: now,
        )?['presentation']['title'],
        'River Memory',
      );
      expect(
        provider.validateBootstrap(
          raw: payload,
          initialUri: Uri.parse('/en/artworks/other'),
          target: target,
          now: now,
        ),
        isNull,
      );
      expect(provider.bootstrap, isNull);
    },
  );

  test('public place label requires validated exact canonical presentation',
      () {
    final provider = PublicEntityTakeoverProvider();
    const target = ShareDeepLinkTarget(
      type: ShareEntityType.profile,
      id: 'profile-9',
      localeCode: 'en',
    );
    final uri = Uri.parse('/en/profiles/profile-9');
    final now = DateTime.now().toUtc();
    provider.seed(initialUri: uri, target: target);
    provider.validateBootstrap(
      raw: <String, dynamic>{
        'version': 1,
        'identity': <String, dynamic>{
          'type': 'profile',
          'id': 'profile-9',
          'locale': 'en',
          'canonicalPath': uri.path,
        },
        'revision': List.filled(64, 'c').join(),
        'generatedAt': now.toIso8601String(),
        'expiresAt': now.add(const Duration(minutes: 10)).toIso8601String(),
        'presentation': <String, dynamic>{
          'version': 1,
          'type': 'profile',
          'id': 'profile-9',
          'locale': 'en',
          'canonicalPath': uri.path,
          'place': <String, dynamic>{'label': 'Ljubljana'},
        },
      },
      initialUri: uri,
      target: target,
      now: now,
    );

    expect(
      provider.publicPlaceLabelForCanonicalPath(
        type: 'profile',
        id: 'profile-9',
        pathname: uri.path,
      ),
      'Ljubljana',
    );
    expect(
      provider.publicPlaceLabelForCanonicalPath(
        type: 'profile',
        id: 'another-profile',
        pathname: uri.path,
      ),
      isNull,
    );
    expect(
      provider.publicPlaceLabelForCanonicalPath(
        type: 'event',
        id: 'profile-9',
        pathname: uri.path,
      ),
      isNull,
    );
    expect(
      provider.publicPlaceLabelForCanonicalPath(
        type: 'profile',
        id: 'profile-9',
        pathname: '/sl/profili/profile-9',
      ),
      isNull,
    );
  });

  test('artwork context uses the validated public place label', () {
    final provider = PublicEntityTakeoverProvider();
    const target = ShareDeepLinkTarget(
      type: ShareEntityType.artwork,
      id: 'artwork-5',
      localeCode: 'sl',
    );
    final uri = Uri.parse('/sl/umetnine/artwork-5');
    final now = DateTime.now().toUtc();
    provider.seed(initialUri: uri, target: target);
    provider.validateBootstrap(
      raw: <String, dynamic>{
        'version': 1,
        'identity': <String, dynamic>{
          'type': 'artwork',
          'id': 'artwork-5',
          'locale': 'sl',
          'canonicalPath': uri.path,
        },
        'revision': List.filled(64, 'd').join(),
        'generatedAt': now.toIso8601String(),
        'expiresAt': now.add(const Duration(minutes: 10)).toIso8601String(),
        'presentation': <String, dynamic>{
          'version': 1,
          'type': 'artwork',
          'id': 'artwork-5',
          'locale': 'sl',
          'canonicalPath': uri.path,
          'place': <String, dynamic>{'label': 'Ljubljana'},
        },
      },
      initialUri: uri,
      target: target,
      now: now,
    );

    expect(
      provider.publicPlaceLabelForCanonicalPath(
        type: 'artwork',
        id: 'artwork-5',
        pathname: uri.path,
      ),
      'Ljubljana',
    );
    expect(
      provider.publicPlaceLabelForCanonicalPath(
        type: 'artwork',
        id: 'artwork-5',
        pathname: '/en/artworks/artwork-5',
      ),
      isNull,
    );
  });

  test(
    'rejects wrong type, locale, unsupported version, malformed, and expired bootstraps',
    () {
      final provider = PublicEntityTakeoverProvider();
      const target = ShareDeepLinkTarget(
        type: ShareEntityType.event,
        id: 'event-7',
        localeCode: 'sl',
      );
      final uri = Uri.parse('/sl/dogodki/event-7');
      provider.seed(initialUri: uri, target: target);
      final now = DateTime.utc(2026, 9, 23, 12);
      Map<String, dynamic> payload({
        int version = 1,
        String type = 'event',
        String locale = 'sl',
        String id = 'event-7',
        String expires = '2026-09-23T12:10:00Z',
      }) =>
          <String, dynamic>{
            'version': version,
            'identity': <String, dynamic>{
              'type': type,
              'id': id,
              'locale': locale,
              'canonicalPath': '/sl/dogodki/event-7',
            },
            'revision': List.filled(64, 'b').join(),
            'generatedAt': '2026-09-23T12:00:00Z',
            'expiresAt': expires,
            'presentation': <String, dynamic>{
              'version': version,
              'type': type,
              'id': id,
              'locale': locale,
              'canonicalPath': '/sl/dogodki/event-7',
            },
          };
      for (final raw in <Map<String, dynamic>>[
        payload(type: 'artwork'),
        payload(locale: 'en'),
        payload(version: 3),
        payload(expires: '2026-09-23T11:59:00Z'),
        <String, dynamic>{'version': 1},
      ]) {
        expect(
          provider.validateBootstrap(
            raw: raw,
            initialUri: uri,
            target: target,
            now: now,
          ),
          isNull,
        );
      }
      expect(
        provider.validateBootstrap(
          raw: payload(version: 2),
          initialUri: uri,
          target: target,
          now: now,
        ),
        isNotNull,
      );
    },
  );
}
