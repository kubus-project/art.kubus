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
}
