import 'package:art_kubus/utils/institution_navigation.dart';
import 'package:art_kubus/utils/search_suggestions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizeSearchSuggestionsPayload preserves nested map metadata', () {
    final results = normalizeSearchSuggestionsPayload(
      <String, dynamic>{
        'results': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'institution',
            'label': 'City Gallery',
            'institution': <String, dynamic>{
              'id': 'institution-1',
              'latitude': 46.0569,
              'longitude': 14.5058,
              'metadata': <String, dynamic>{
                'markerId': 'marker-9',
                'subjectId': 'institution-1',
                'subjectType': 'institution',
              },
            },
          },
        ],
      },
    );

    expect(results, hasLength(1));
    expect(results.first['id'], 'institution-1');
    expect(results.first['markerId'], 'marker-9');
    expect(results.first['subjectId'], 'institution-1');
    expect(results.first['subjectType'], 'institution');
    expect(results.first['lat'], 46.0569);
    expect(results.first['lng'], 14.5058);
  });

  test('an institution row does not carry its own id as a wallet', () {
    const institutionId = 'c5000000-0000-4000-8000-000000000001';
    final results = normalizeSearchSuggestionsPayload(
      <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'institution',
          'id': institutionId,
          'label': 'SM1 Institution',
          'subtitle': 'Ljubljana',
          'lat': 46.05,
          'lng': 14.5,
        },
      ],
    );

    expect(results, hasLength(1));
    expect(results.first.containsKey('wallet'), isFalse);
    // A venue id or membership owner is never account-link evidence.
    expect(
      InstitutionNavigation.resolveProfileTargetId(
        institutionId: institutionId,
        data: results.first,
      ),
      isNull,
    );
  });

  test('only an explicit verified profile target routes to account profile UX',
      () {
    expect(
      InstitutionNavigation.resolveProfileTargetId(
        institutionId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        data: <String, dynamic>{
          'userId': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
          'walletAddress': 'owner-wallet',
        },
      ),
      isNull,
    );
    expect(
      InstitutionNavigation.resolveProfileTargetId(
        institutionId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        explicitProfileTargetId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      ),
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    );
  });

  test('a profile row keeps its wallet, the id it is found by', () {
    final results = normalizeSearchSuggestionsPayload(
      <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'profile',
          'id': 'wallet_artist_maja',
          'displayName': 'Maja Novak',
          'username': 'majanovak',
        },
      ],
    );

    expect(results.first['wallet'], 'wallet_artist_maja');
  });
}
