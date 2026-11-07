import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/search_service.dart';
import 'package:art_kubus/widgets/search/kubus_search_config.dart';
import 'package:art_kubus/widgets/search/kubus_search_result.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBackendApiService implements BackendApiService {
  _FakeBackendApiService(this.suggestions);

  final List<Map<String, dynamic>> suggestions;
  List<Map<String, dynamic>> posts = const <Map<String, dynamic>>[];
  bool? lastIncludeCollections;

  @override
  Future<Map<String, dynamic>> search({
    required String query,
    String type = 'all',
    int limit = 20,
    int page = 1,
  }) async {
    return <String, dynamic>{
      'data': <String, dynamic>{'posts': posts},
    };
  }

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
  group('community post rows', () {
    const video = 'https://cdn.kubus.site/uploads/clip.mp4';
    const poster = 'https://cdn.kubus.site/uploads/clip-still.jpg';
    final hinted =
        '$video#kubus-media=video&kubus-poster=${Uri.encodeComponent(poster)}';

    Future<Map<String, dynamic>> rowData(Map<String, dynamic> post) async {
      final backend = _FakeBackendApiService(const <Map<String, dynamic>>[])
        ..posts = <Map<String, dynamic>>[
          <String, dynamic>{'id': 'p1', 'content': 'clip', ...post},
        ];
      final results = await SearchService(backendApi: backend).fetchResults(
        snapshot: const SearchContextSnapshot(),
        query: 'cl',
        config: const KubusSearchConfig(
          scope: KubusSearchScope.community,
          allowedKinds: <KubusSearchResultKind>{KubusSearchResultKind.post},
        ),
      );
      return results.single.data;
    }

    test('a video-first row shows the poster, not the clip', () async {
      final data = await rowData(<String, dynamic>{
        'imageUrl': hinted,
        'mediaUrls': <String>[hinted],
      });
      expect(data['imageUrl'], poster);
    });

    test('a video-only row without a poster has no still', () async {
      final data = await rowData(<String, dynamic>{
        'imageUrl': video,
        'mediaUrls': <String>[video],
      });
      expect(data['imageUrl'], isNull);
    });

    test('an image-first row keeps its image', () async {
      final data = await rowData(<String, dynamic>{
        'imageUrl': 'https://cdn.kubus.site/uploads/one.jpg',
        'mediaUrls': <String>[hinted],
      });
      expect(data['imageUrl'], 'https://cdn.kubus.site/uploads/one.jpg');
    });
  });

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
