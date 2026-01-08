import 'package:art_kubus/services/share/share_deep_link_parser.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = ShareDeepLinkParser();

  test('ShareDeepLinkParser parses canonical paths', () {
    expect(parser.parse(Uri.parse('/post/123'))?.type, ShareEntityType.post);
    expect(parser.parse(Uri.parse('/post/123'))?.id, '123');

    expect(parser.parse(Uri.parse('/artwork/abc'))?.type, ShareEntityType.artwork);
    expect(parser.parse(Uri.parse('/marker/m1'))?.type, ShareEntityType.marker);
    expect(parser.parse(Uri.parse('/nft/n1'))?.type, ShareEntityType.nft);
    expect(parser.parse(Uri.parse('/profile/wallet_1'))?.type, ShareEntityType.profile);
    expect(parser.parse(Uri.parse('/event/e1'))?.type, ShareEntityType.event);
    expect(parser.parse(Uri.parse('/exhibition/x1'))?.type, ShareEntityType.exhibition);
    expect(parser.parse(Uri.parse('/collection/c1'))?.type, ShareEntityType.collection);

      // Full canonical URLs should parse the same way as relative paths.
      expect(parser.parse(Uri.parse('https://app.kubus.site/marker/m_full'))?.type, ShareEntityType.marker);
      expect(parser.parse(Uri.parse('https://app.kubus.site/marker/m_full'))?.id, 'm_full');
  });

  test('ShareDeepLinkParser accepts legacy aliases', () {
    expect(parser.parse(Uri.parse('/events/e2'))?.type, ShareEntityType.event);
    expect(parser.parse(Uri.parse('/exhibitions/x2'))?.type, ShareEntityType.exhibition);
    expect(parser.parse(Uri.parse('/user/wallet_2'))?.type, ShareEntityType.profile);
    expect(parser.parse(Uri.parse('/u/wallet_3'))?.type, ShareEntityType.profile);
    expect(parser.parse(Uri.parse('/art-markers/m2'))?.type, ShareEntityType.marker);
    expect(parser.parse(Uri.parse('/markers/m3'))?.type, ShareEntityType.marker);
    expect(parser.parse(Uri.parse('/nfts/n2'))?.type, ShareEntityType.nft);
  });

  test('ShareDeepLinkParser returns null for unsupported paths', () {
    expect(parser.parse(Uri.parse('/')), isNull);
    expect(parser.parse(Uri.parse('/unknown/123')), isNull);
    expect(parser.parse(Uri.parse('/post/')), isNull);
  });
}

