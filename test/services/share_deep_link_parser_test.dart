import 'package:art_kubus/services/share/share_deep_link_parser.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = ShareDeepLinkParser();

  test('ShareDeepLinkParser parses canonical paths', () {
    expect(parser.parse(Uri.parse('/p/123'))?.type, ShareEntityType.post);
    expect(parser.parse(Uri.parse('/p/123'))?.id, '123');

    expect(parser.parse(Uri.parse('/a/abc'))?.type, ShareEntityType.artwork);
    expect(parser.parse(Uri.parse('/m/m1'))?.type, ShareEntityType.marker);
    expect(parser.parse(Uri.parse('/n/n1'))?.type, ShareEntityType.nft);
    expect(
      parser.parse(Uri.parse('/u/wallet_1'))?.type,
      ShareEntityType.profile,
    );
    expect(parser.parse(Uri.parse('/e/e1'))?.type, ShareEntityType.event);
    expect(parser.parse(Uri.parse('/x/x1'))?.type, ShareEntityType.exhibition);
    expect(parser.parse(Uri.parse('/c/c1'))?.type, ShareEntityType.collection);

    // Full canonical URLs should parse the same way as relative paths.
    expect(
      parser.parse(Uri.parse('https://app.kubus.site/m/m_full'))?.type,
      ShareEntityType.marker,
    );
    expect(
      parser.parse(Uri.parse('https://app.kubus.site/m/m_full'))?.id,
      'm_full',
    );
  });

  test('ShareDeepLinkParser tolerates path prefixes', () {
    expect(parser.parse(Uri.parse('/en/m/m1'))?.type, ShareEntityType.marker);
    expect(parser.parse(Uri.parse('/sl/m/m2'))?.id, 'm2');
    expect(
      parser.parse(Uri.parse('/share/a/a3'))?.type,
      ShareEntityType.artwork,
    );
  });

  test('ShareDeepLinkParser opens every localized public route in the app', () {
    final routes = <String, ShareEntityType>{
      '/app/en/artworks/a1': ShareEntityType.artwork,
      '/app/sl/umetnine/a2': ShareEntityType.artwork,
      '/app/en/profiles/u1': ShareEntityType.profile,
      '/app/sl/profili/u2': ShareEntityType.profile,
      '/app/en/events/e1': ShareEntityType.event,
      '/app/sl/dogodki/e2': ShareEntityType.event,
      '/app/en/exhibitions/x1': ShareEntityType.exhibition,
      '/app/sl/razstave/x2': ShareEntityType.exhibition,
      '/app/en/posts/p1': ShareEntityType.post,
      '/app/sl/objave/p2': ShareEntityType.post,
      '/app/en/collections/c1': ShareEntityType.collection,
      '/app/sl/zbirke/c2': ShareEntityType.collection,
      '/app/en/collectibles/n1': ShareEntityType.nft,
      '/app/sl/zbirateljski-predmeti/n2': ShareEntityType.nft,
      '/app/en/map/m1': ShareEntityType.marker,
      '/app/sl/zemljevid/m2': ShareEntityType.marker,
    };

    for (final entry in routes.entries) {
      final target = parser.parse(Uri.parse(entry.key));
      expect(target?.type, entry.value, reason: entry.key);
      expect(target?.id, entry.key.split('/').last, reason: entry.key);
      expect(target?.localeCode, entry.key.split('/')[2], reason: entry.key);
    }
  });

  test('canonical EN and SL routes parse each supported entity family', () {
    final routes = <String, (ShareEntityType, String)>{
      '/en/artworks/art-1': (ShareEntityType.artwork, 'en'),
      '/sl/umetnine/art-2': (ShareEntityType.artwork, 'sl'),
      '/en/profiles/profile-1': (ShareEntityType.profile, 'en'),
      '/sl/profili/profile-2': (ShareEntityType.profile, 'sl'),
      '/en/events/event-1': (ShareEntityType.event, 'en'),
      '/sl/dogodki/event-2': (ShareEntityType.event, 'sl'),
      '/en/exhibitions/exhibition-1': (ShareEntityType.exhibition, 'en'),
      '/sl/razstave/exhibition-2': (ShareEntityType.exhibition, 'sl'),
      '/en/posts/post-1': (ShareEntityType.post, 'en'),
      '/sl/objave/post-2': (ShareEntityType.post, 'sl'),
      '/en/collections/collection-1': (ShareEntityType.collection, 'en'),
      '/sl/zbirke/collection-2': (ShareEntityType.collection, 'sl'),
      '/en/collectibles/collectible-1': (ShareEntityType.nft, 'en'),
      '/sl/zbirateljski-predmeti/collectible-2': (ShareEntityType.nft, 'sl'),
      '/en/map/marker-1': (ShareEntityType.marker, 'en'),
      '/sl/zemljevid/marker-2': (ShareEntityType.marker, 'sl'),
    };

    for (final entry in routes.entries) {
      final target = parser.parse(Uri.parse(entry.key));
      expect(target?.type, entry.value.$1, reason: entry.key);
      expect(target?.localeCode, entry.value.$2, reason: entry.key);
      expect(target?.id, entry.key.split('/').last, reason: entry.key);
    }
  });

  test('canonical paths reject missing IDs and unsupported extra segments', () {
    const canonicalPaths = <String>[
      '/en/artworks/art-1',
      '/sl/umetnine/art-2',
      '/en/profiles/profile-1',
      '/sl/profili/profile-2',
      '/en/events/event-1',
      '/sl/dogodki/event-2',
      '/en/exhibitions/exhibition-1',
      '/sl/razstave/exhibition-2',
      '/en/posts/post-1',
      '/sl/objave/post-2',
      '/en/collections/collection-1',
      '/sl/zbirke/collection-2',
      '/en/collectibles/collectible-1',
      '/sl/zbirateljski-predmeti/collectible-2',
      '/en/map/marker-1',
      '/sl/zemljevid/marker-2',
    ];

    for (final canonicalPath in canonicalPaths) {
      final segments = canonicalPath.split('/');
      final familyPath = '/${segments[1]}/${segments[2]}';
      expect(parser.parse(Uri.parse(familyPath)), isNull,
          reason: 'missing ID: $familyPath');
      expect(parser.parse(Uri.parse('$familyPath/')), isNull,
          reason: 'empty ID: $familyPath/');
      expect(parser.parse(Uri.parse('$canonicalPath/extra')), isNull,
          reason: 'extra segment: $canonicalPath/extra');
    }
  });

  test('unrecognized entity IDs stay as exact targets for normal not-found UI',
      () {
    final target = parser.parse(
      Uri.parse('/en/events/no-such-public-event'),
    );

    expect(target?.type, ShareEntityType.event);
    expect(target?.id, 'no-such-public-event');
  });

  test(
      'canonical route preserves decoded IDs and ignores query/fragment for identity',
      () {
    final target = parser.parse(Uri.parse(
      'https://app.kubus.site/en/artworks/a%25b?ref=search#details',
    ));

    expect(target?.type, ShareEntityType.artwork);
    expect(target?.id, 'a%b');
    expect(target?.localeCode, 'en');
  });

  test('canonical URL locale overrides a conflicting locale query', () {
    final target = parser.parse(
      Uri.parse('/sl/umetnine/art-1?lang=en'),
    );

    expect(target?.localeCode, 'sl');
  });

  test('claimed legacy long-form prefixes remain parseable', () {
    const routes = <String, ShareEntityType>{
      '/marker/m-1': ShareEntityType.marker,
      '/artwork/a-1': ShareEntityType.artwork,
      '/post/p-1': ShareEntityType.post,
      '/profile/u-1': ShareEntityType.profile,
      '/user/u-2': ShareEntityType.profile,
      '/collection/c-1': ShareEntityType.collection,
      '/event/e-1': ShareEntityType.event,
      '/exhibition/x-1': ShareEntityType.exhibition,
      '/n/n-1': ShareEntityType.nft,
    };

    for (final entry in routes.entries) {
      expect(parser.parse(Uri.parse(entry.key))?.type, entry.value,
          reason: entry.key);
    }
  });

  test('ShareDeepLinkParser accepts supported locale query context only', () {
    expect(parser.parse(Uri.parse('/a/a1?lang=en'))?.localeCode, 'en');
    expect(parser.parse(Uri.parse('/a/a1?locale=sl'))?.localeCode, 'sl');
    expect(parser.parse(Uri.parse('/a/a1?lang=de'))?.localeCode, isNull);
  });

  test('ShareDeepLinkParser parses claim-ready exhibition handoffs', () {
    final target = parser.parse(
      Uri.parse('/x/expo-1?handoff=claim-ready&attendanceMarkerId=marker-1'),
    );

    expect(target?.type, ShareEntityType.exhibition);
    expect(target?.id, 'expo-1');
    expect(target?.isClaimReadyExhibition, isTrue);
    expect(target?.attendanceMarkerId, 'marker-1');
  });

  test('ShareDeepLinkParser returns null for unsupported paths', () {
    expect(parser.parse(Uri.parse('/')), isNull);
    expect(parser.parse(Uri.parse('/unknown/123')), isNull);
    expect(parser.parse(Uri.parse('/p/')), isNull);
  });
}
