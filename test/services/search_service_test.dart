import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/search_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBackendApiService extends BackendApiService {
  _FakeBackendApiService(this.suggestions);

  final List<Map<String, dynamic>> suggestions;

  @override
  Future<List<Map<String, dynamic>>> getSearchSuggestions({
    required String query,
    int limit = 10,
  }) async {
    return suggestions;
  }

  @override
  List<Map<String, dynamic>> normalizeSearchSuggestions(dynamic raw) {
    return List<Map<String, dynamic>>.from(raw as List<dynamic>);
  }
}

void main() {
  test('home scope filters out unsupported non-art/profile suggestions without coordinates', () async {
    final service = SearchService(
      backendApi: _FakeBackendApiService(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'institution',
            'id': 'institution-1',
            'label': 'Museum without coordinates',
          },
        ],
      ),
    );

    final results = await service.fetchSuggestions(
      snapshot: const SearchContextSnapshot(),
      query: 'mu',
      scope: SearchScope.home,
    );

    expect(results, isEmpty);
  });
}
