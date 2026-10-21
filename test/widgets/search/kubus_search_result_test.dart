import 'package:art_kubus/widgets/search/kubus_search_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('previewImageUrl falls back to the first non-empty image list entry',
      () {
    const result = KubusSearchResult(
      label: 'Gallery',
      kind: KubusSearchResultKind.institution,
      data: <String, dynamic>{
        'imageUrls': <String>['', 'https://example.com/cover.png'],
      },
    );

    expect(result.previewImageUrl, 'https://example.com/cover.png');
  });

  test('a post row reads the roles of its nested author object', () {
    const result = KubusSearchResult(
      label: 'A post',
      kind: KubusSearchResultKind.post,
      id: 'post-1',
      data: <String, dynamic>{
        'author': <String, dynamic>{
          'displayName': 'Ana Artist',
          'roles': <String, dynamic>{'artist': true},
        },
      },
    );

    expect(result.authorRoles.isArtist, isTrue);
    expect(result.authorRoles.isInstitution, isFalse);
    expect(result.authorRoles.isVerified, isFalse);
  });

  test('a post row keeps author-prefixed envelope flags beside a nested author',
      () {
    const result = KubusSearchResult(
      label: 'A post',
      kind: KubusSearchResultKind.post,
      id: 'post-2',
      data: <String, dynamic>{
        'author': <String, dynamic>{'displayName': 'Ben'},
        'authorIsVerified': true,
        'isArtist': true,
      },
    );

    expect(result.authorRoles.isVerified, isTrue);
    // A bare envelope isArtist does not describe the author.
    expect(result.authorRoles.isArtist, isFalse);
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
