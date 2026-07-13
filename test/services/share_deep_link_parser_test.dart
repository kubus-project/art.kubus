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
    }
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
