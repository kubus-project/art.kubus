import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/search_service.dart';
import 'package:art_kubus/widgets/search/kubus_search_config.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBackendApiService implements BackendApiService {
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

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

    final results = await service.fetchResults(
      snapshot: const SearchContextSnapshot(),
      query: 'mu',
      config: const KubusSearchConfig(scope: KubusSearchScope.home),
    );

    expect(results, isEmpty);
  });

  test('community scope filters out institution suggestions without coordinates', () async {
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

    final results = await service.fetchResults(
      snapshot: const SearchContextSnapshot(),
      query: 'mu',
      config: const KubusSearchConfig(scope: KubusSearchScope.community),
    );

    expect(results, isEmpty);
  });
}
