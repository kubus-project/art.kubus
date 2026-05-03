import 'package:art_kubus/models/saved_item.dart';
import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/saved_items_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSavedItemsRepository extends SavedItemsRepository {
  _FakeSavedItemsRepository({
    List<SavedItemRecord> cachedItems = const <SavedItemRecord>[],
    List<SavedItemRecord> backendItems = const <SavedItemRecord>[],
    Map<String, bool> statusMap = const <String, bool>{},
  })  : _cachedItems = List<SavedItemRecord>.from(cachedItems),
        _backendItems = List<SavedItemRecord>.from(backendItems),
        _statusMap = Map<String, bool>.from(statusMap),
        super(api: BackendApiService());

  List<SavedItemRecord> _cachedItems;
  List<SavedItemRecord> _backendItems;
  Map<String, bool> _statusMap;
  bool clearCachedStateCalled = false;

  set backendItems(List<SavedItemRecord> value) {
    _backendItems = List<SavedItemRecord>.from(value);
  }

  set statusMap(Map<String, bool> value) {
    _statusMap = Map<String, bool>.from(value);
  }

  @override
  Future<List<SavedItemRecord>> loadCachedItems() async =>
      List<SavedItemRecord>.from(_cachedItems);

  @override
  Future<void> cacheItems(List<SavedItemRecord> items) async {
    _cachedItems = List<SavedItemRecord>.from(items);
  }

  @override
  Future<SavedItemsPage> loadBackendItems({
    SavedItemType? type,
    int limit = 50,
    String? cursor,
  }) async {
    final items = _backendItems
        .where((item) => type == null || item.type == type)
        .toList(growable: false);
    return SavedItemsPage(items: items);
  }

  @override
  Future<Map<String, bool>> getSavedBatchStatus(
    Iterable<SavedItemRecord> items,
  ) async {
    return {
      for (final item in items)
        '${item.type.storageKey}:${item.id}':
            _statusMap['${item.type.storageKey}:${item.id}'] ?? false,
    };
  }

  @override
  Future<void> migrateLegacyItems(List<SavedItemRecord> items) async {}

  @override
  Future<void> replayPendingMutations() async {}

  @override
  Future<void> clearCachedState() async {
    clearCachedStateCalled = true;
    _cachedItems = const <SavedItemRecord>[];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('saved items provider has all 9 types with getters', () async {
    final provider = SavedItemsProvider();

    // Verify all 9 types have getters
    expect(provider.savedArtworkIds, isA<Set<String>>());
    expect(provider.savedEventIds, isA<Set<String>>());
    expect(provider.savedCollectionIds, isA<Set<String>>());
    expect(provider.savedExhibitionIds, isA<Set<String>>());
    expect(provider.savedPostIds, isA<Set<String>>());
    expect(provider.savedArtistItems, isA<List<SavedItemRecord>>());
    expect(provider.savedInstitutionItems, isA<List<SavedItemRecord>>());
    expect(provider.savedGroupItems, isA<List<SavedItemRecord>>());
    expect(provider.savedMarkerItems, isA<List<SavedItemRecord>>());
  });

  test('saved items provider has count getters for all types', () async {
    final provider = SavedItemsProvider();

    expect(provider.savedArtworksCount, equals(0));
    expect(provider.savedEventsCount, equals(0));
    expect(provider.savedCollectionsCount, equals(0));
    expect(provider.savedExhibitionsCount, equals(0));
    expect(provider.savedPostsCount, equals(0));
    expect(provider.savedArtistsCount, equals(0));
    expect(provider.savedInstitutionsCount, equals(0));
    expect(provider.savedGroupsCount, equals(0));
    expect(provider.savedMarkersCount, equals(0));
  });

  test('artist saved state can be toggled', () async {
    final provider = SavedItemsProvider();

    // Verify initial state
    expect(provider.isArtistSaved('artist-1'), isFalse);

    // Toggle on
    await provider.setArtistSaved('artist-1', true);
    expect(provider.isArtistSaved('artist-1'), isTrue);
    expect(provider.savedArtistsCount, equals(1));

    // Toggle off
    await provider.setArtistSaved('artist-1', false);
    expect(provider.isArtistSaved('artist-1'), isFalse);
    expect(provider.savedArtistsCount, equals(0));
  });

  test('institution saved state can be toggled', () async {
    final provider = SavedItemsProvider();

    expect(provider.isInstitutionSaved('institution-1'), isFalse);

    await provider.setInstitutionSaved('institution-1', true);
    expect(provider.isInstitutionSaved('institution-1'), isTrue);
    expect(provider.savedInstitutionsCount, equals(1));

    await provider.setInstitutionSaved('institution-1', false);
    expect(provider.isInstitutionSaved('institution-1'), isFalse);
    expect(provider.savedInstitutionsCount, equals(0));
  });

  test('group saved state can be toggled', () async {
    final provider = SavedItemsProvider();

    expect(provider.isGroupSaved('group-1'), isFalse);

    await provider.setGroupSaved('group-1', true);
    expect(provider.isGroupSaved('group-1'), isTrue);
    expect(provider.savedGroupsCount, equals(1));

    await provider.setGroupSaved('group-1', false);
    expect(provider.isGroupSaved('group-1'), isFalse);
    expect(provider.savedGroupsCount, equals(0));
  });

  test('marker saved state can be toggled', () async {
    final provider = SavedItemsProvider();

    expect(provider.isMarkerSaved('marker-1'), isFalse);

    await provider.setMarkerSaved('marker-1', true);
    expect(provider.isMarkerSaved('marker-1'), isTrue);
    expect(provider.savedMarkersCount, equals(1));

    await provider.setMarkerSaved('marker-1', false);
    expect(provider.isMarkerSaved('marker-1'), isFalse);
    expect(provider.savedMarkersCount, equals(0));
  });

  test('backend refresh merges saved state without wiping cached types', () async {
    final repository = _FakeSavedItemsRepository(
      cachedItems: <SavedItemRecord>[
        SavedItemRecord(
          type: SavedItemType.artist,
          id: 'artist-1',
          savedAt: DateTime(2025, 1, 1),
          title: 'Cached artist',
        ),
      ],
      backendItems: <SavedItemRecord>[
        SavedItemRecord(
          type: SavedItemType.communityPost,
          id: 'post-1',
          savedAt: DateTime(2025, 1, 2),
          title: 'Backend post',
        ),
      ],
    );

    final provider = SavedItemsProvider(repository: repository);
    await provider.initialize();

    expect(provider.isArtistSaved('artist-1'), isTrue);
    expect(provider.isPostSaved('post-1'), isTrue);
    expect(provider.savedArtistsCount, equals(1));
    expect(provider.savedPostsCount, equals(1));
  });

  test('batch hydration updates visible saved status from backend', () async {
    final repository = _FakeSavedItemsRepository(
      statusMap: <String, bool>{
        'artist:artist-2': true,
        'marker:marker-3': true,
      },
    );

    final provider = SavedItemsProvider(repository: repository);
    await provider.hydrateSavedBatchStatus(<SavedItemType, Iterable<String>>{
      SavedItemType.artist: ['artist-2'],
      SavedItemType.marker: ['marker-3'],
    });

    expect(provider.isArtistSaved('artist-2'), isTrue);
    expect(provider.isMarkerSaved('marker-3'), isTrue);
  });

  test('community feed hydration sets post bookmark state from provider', () async {
    final repository = _FakeSavedItemsRepository(
      statusMap: <String, bool>{'community_post:post-42': true},
    );
    final provider = SavedItemsProvider(repository: repository);
    final post = CommunityPost(
      id: 'post-42',
      authorId: 'author-1',
      authorWallet: 'wallet-1',
      authorName: 'Artist One',
      content: 'A community post',
      timestamp: DateTime(2025, 1, 3),
      tags: const <String>[],
      mentions: const <String>[],
    );

    await CommunityService.loadSavedInteractions(
      [post],
      savedItemsProvider: provider,
    );

    expect(provider.isPostSaved('post-42'), isTrue);
    expect(post.isBookmarked, isTrue);
  });

  test('logout reset clears local saved cache and login refresh restores it',
      () async {
    final repository = _FakeSavedItemsRepository(
      backendItems: <SavedItemRecord>[
        SavedItemRecord(
          type: SavedItemType.group,
          id: 'group-9',
          savedAt: DateTime(2025, 1, 4),
          title: 'Group 9',
        ),
      ],
    );

    final provider = SavedItemsProvider(repository: repository);
    await provider.initialize();
    expect(provider.isGroupSaved('group-9'), isTrue);

    await provider.resetForLogout();
    expect(provider.totalSavedCount, equals(0));
    expect(repository.clearCachedStateCalled, isTrue);

    await provider.initialize();
    expect(provider.isGroupSaved('group-9'), isTrue);
  });
}
