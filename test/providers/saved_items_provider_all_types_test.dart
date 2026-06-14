import 'package:art_kubus/models/saved_item.dart';
import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/models/profile_identity_data.dart';
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
    List<SavedItemRecord> pendingSaves = const <SavedItemRecord>[],
    Set<String> pendingDeleteKeys = const <String>{},
  })  : _cachedItems = List<SavedItemRecord>.from(cachedItems),
        _backendItems = List<SavedItemRecord>.from(backendItems),
        _statusMap = Map<String, bool>.from(statusMap),
        _pendingSaves = List<SavedItemRecord>.from(pendingSaves),
        _pendingDeleteKeys = Set<String>.from(pendingDeleteKeys),
        super(api: BackendApiService());

  List<SavedItemRecord> _cachedItems;
  List<SavedItemRecord> _backendItems;
  Map<String, bool> _statusMap;
  final List<SavedItemRecord> _pendingSaves;
  final Set<String> _pendingDeleteKeys;
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
  Future<SavedItemRecord> save(SavedItemRecord item) async {
    _pendingDeleteKeys.remove('${item.type.storageKey}:${item.id}');
    _backendItems.removeWhere(
      (existing) => existing.type == item.type && existing.id == item.id,
    );
    _backendItems.add(item);
    return item;
  }

  @override
  Future<void> unsave(SavedItemType type, String id) async {
    _backendItems.removeWhere(
      (existing) => existing.type == type && existing.id == id,
    );
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
  Future<List<SavedItemRecord>> loadPendingSaves() async =>
      List<SavedItemRecord>.from(_pendingSaves);

  @override
  Future<Set<String>> loadPendingDeleteKeys() async =>
      Set<String>.from(_pendingDeleteKeys);

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

  test('backend refresh removes stale cached items', () async {
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

    expect(provider.isArtistSaved('artist-1'), isFalse);
    expect(provider.isPostSaved('post-1'), isTrue);
    expect(provider.savedArtistsCount, equals(0));
    expect(provider.savedPostsCount, equals(1));
  });

  test('backend refresh preserves pending offline save', () async {
    final repository = _FakeSavedItemsRepository(
      cachedItems: <SavedItemRecord>[
        SavedItemRecord(
          type: SavedItemType.artist,
          id: 'artist-pending',
          savedAt: DateTime(2025, 1, 1),
          title: 'Pending artist',
        ),
      ],
      pendingSaves: <SavedItemRecord>[
        SavedItemRecord(
          type: SavedItemType.artist,
          id: 'artist-pending',
          savedAt: DateTime(2025, 1, 1),
          title: 'Pending artist',
        ),
      ],
    );

    final provider = SavedItemsProvider(repository: repository);
    await provider.initialize();

    expect(provider.isArtistSaved('artist-pending'), isTrue);
  });

  test('backend refresh does not resurrect pending offline unsave', () async {
    final repository = _FakeSavedItemsRepository(
      backendItems: <SavedItemRecord>[
        SavedItemRecord(
          type: SavedItemType.marker,
          id: 'marker-unsaved',
          savedAt: DateTime(2025, 1, 1),
          title: 'Backend marker',
        ),
      ],
      pendingDeleteKeys: <String>{'marker:marker-unsaved'},
    );

    final provider = SavedItemsProvider(repository: repository);
    await provider.initialize();

    expect(provider.isMarkerSaved('marker-unsaved'), isFalse);
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

  test('batch hydration removes stale visible saved status from backend',
      () async {
    final repository = _FakeSavedItemsRepository(
      cachedItems: <SavedItemRecord>[
        SavedItemRecord(
          type: SavedItemType.communityPost,
          id: 'post-stale',
          savedAt: DateTime(2025, 1, 1),
          title: 'Stale post',
        ),
      ],
      statusMap: <String, bool>{'community_post:post-stale': false},
    );

    final provider = SavedItemsProvider(repository: repository);
    await provider.initialize();
    expect(provider.isPostSaved('post-stale'), isFalse);

    await provider.setPostSaved('post-stale', true);
    expect(provider.isPostSaved('post-stale'), isTrue);

    await provider.hydrateSavedBatchStatus(<SavedItemType, Iterable<String>>{
      SavedItemType.communityPost: ['post-stale'],
    });

    expect(provider.isPostSaved('post-stale'), isFalse);
  });

  test('community feed hydration sets post bookmark state from provider',
      () async {
    final repository = _FakeSavedItemsRepository(
      statusMap: <String, bool>{'community_post:post-42': true},
    );
    final provider = SavedItemsProvider(repository: repository);
    final post = CommunityPost(
      id: 'post-42',
      authorIdentityData: ProfileIdentityData.fromCompactAuthor(
        {
          'id': 'author-1',
          'walletAddress': 'wallet-1',
          'displayName': 'Artist One',
        },
        fallbackLabel: 'Unknown author',
      ),
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
