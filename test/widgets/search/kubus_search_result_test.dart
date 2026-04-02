import 'package:art_kubus/widgets/search/kubus_search_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('previewImageUrl falls back to the first non-empty image list entry', () {
    const result = KubusSearchResult(
      label: 'Gallery',
      kind: KubusSearchResultKind.institution,
      data: <String, dynamic>{
        'imageUrls': <String>['', 'https://example.com/cover.png'],
      },
    );

    expect(result.previewImageUrl, 'https://example.com/cover.png');
  });

  test('walletSeed falls back to profile id when wallet fields are absent', () {
    const result = KubusSearchResult(
      label: 'Ada',
      kind: KubusSearchResultKind.profile,
      id: 'wallet-123',
    );

    expect(result.walletSeed, 'wallet-123');
  });

  test('marker and subject getters resolve shared map-selection metadata', () {
    const result = KubusSearchResult(
      label: 'Museum Plaza',
      kind: KubusSearchResultKind.institution,
      id: 'institution-42',
      data: <String, dynamic>{
        'markerId': 'marker-7',
        'subjectId': 'institution-42',
        'subjectType': 'institution',
      },
    );

    expect(result.markerId, 'marker-7');
    expect(result.subjectId, 'institution-42');
    expect(result.subjectType, 'institution');
  });
}
