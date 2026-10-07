import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/search_service.dart';
import 'package:art_kubus/widgets/search/kubus_search_config.dart';
import 'package:art_kubus/widgets/search/kubus_search_result.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBackendApiService implements BackendApiService {
  _FakeBackendApiService(this.suggestions);

  final List<Map<String, dynamic>> suggestions;
  bool? lastIncludeCollections;

  @override
  Future<List<Map<String, dynamic>>> getSearchSuggestions({
    required String query,
    int limit = 10,
    bool includeCollections = false,
  }) async {
    lastIncludeCollections = includeCollections;
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
  test(
      'home scope filters out unsupported non-art/profile suggestions without coordinates',
      () async {
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

  test(
      'community scope filters out institution suggestions without coordinates',
      () async {
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

  group('collection suggestions', () {
    final payload = <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'collection',
        'id': 'col-1',
        'label': 'Ljubljana fountains',
        'artworkCount': 4,
      },
      <String, dynamic>{
        'type': 'artwork',
        'id': 'art-1',
        'label': 'Robba Fountain',
      },
    ];

    for (final scope in <KubusSearchScope>[
      KubusSearchScope.home,
      KubusSearchScope.community,
      KubusSearchScope.map,
    ]) {
      test('${scope.name} scope asks for collections and keeps them', () async {
        final backend = _FakeBackendApiService(payload);
        final results = await SearchService(backendApi: backend).fetchResults(
          snapshot: const SearchContextSnapshot(),
          query: 'fo',
          config: KubusSearchConfig(scope: scope),
        );

        expect(backend.lastIncludeCollections, isTrue);
        final collection = results.singleWhere(
          (r) => r.kind == KubusSearchResultKind.collection,
        );
        expect(collection.collectionId, 'col-1');
        expect(collection.collectionArtworkCount, 4);
      });
    }

    test('a client that does not list collections never asks for them',
        () async {
      final backend = _FakeBackendApiService(payload);
      await SearchService(backendApi: backend).fetchResults(
        snapshot: const SearchContextSnapshot(),
        query: 'fo',
        config: const KubusSearchConfig(
          scope: KubusSearchScope.home,
          allowedKinds: <KubusSearchResultKind>{KubusSearchResultKind.artwork},
        ),
      );

      expect(backend.lastIncludeCollections, isFalse);
    });

    test('a result type this client does not know is dropped, not an artwork',
        () async {
      final results = await SearchService(
        backendApi: _FakeBackendApiService(<Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'hologram',
            'id': 'x-1',
            'label': 'Unknown kind',
          },
        ]),
      ).fetchResults(
        snapshot: const SearchContextSnapshot(),
        query: 'un',
        config: const KubusSearchConfig(scope: KubusSearchScope.home),
      );

      expect(results, isEmpty);
    });
  });
}
