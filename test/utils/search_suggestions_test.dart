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
    // Opened from search, the institution goes to its own screen, not to a
    // profile fetched by the institution id (which 404s).
    expect(
      InstitutionNavigation.resolveProfileTargetId(
        institutionId: institutionId,
        data: results.first,
      ),
      isNull,
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
