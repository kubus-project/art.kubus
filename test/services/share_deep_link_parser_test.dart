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
    expect(parser.parse(Uri.parse('/u/wallet_1'))?.type, ShareEntityType.profile);
    expect(parser.parse(Uri.parse('/e/e1'))?.type, ShareEntityType.event);
    expect(parser.parse(Uri.parse('/x/x1'))?.type, ShareEntityType.exhibition);
    expect(parser.parse(Uri.parse('/c/c1'))?.type, ShareEntityType.collection);

    // Full canonical URLs should parse the same way as relative paths.
    expect(parser.parse(Uri.parse('https://app.kubus.site/m/m_full'))?.type, ShareEntityType.marker);
    expect(parser.parse(Uri.parse('https://app.kubus.site/m/m_full'))?.id, 'm_full');
  });

  test('ShareDeepLinkParser tolerates path prefixes', () {
    expect(parser.parse(Uri.parse('/en/m/m1'))?.type, ShareEntityType.marker);
    expect(parser.parse(Uri.parse('/sl/m/m2'))?.id, 'm2');
    expect(parser.parse(Uri.parse('/share/a/a3'))?.type, ShareEntityType.artwork);
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
