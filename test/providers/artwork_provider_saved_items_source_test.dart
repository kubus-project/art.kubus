import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/saved_item.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/saved_items_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSavedItemsRepository extends SavedItemsRepository {
  _FakeSavedItemsRepository() : super(api: BackendApiService());

  final List<SavedItemRecord> saved = <SavedItemRecord>[];
  final List<String> deleted = <String>[];
  List<SavedItemRecord> cached = <SavedItemRecord>[];

  @override
  Future<void> cacheItems(List<SavedItemRecord> items) async {
    cached = List<SavedItemRecord>.from(items);
  }

  @override
  Future<SavedItemRecord> save(SavedItemRecord item) async {
    saved.add(item);
    return item;
  }

  @override
  Future<void> unsave(SavedItemType type, String id) async {
    deleted.add('${type.storageKey}:$id');
  }
}

class _FakeArtworkApi implements ArtworkBackendApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('toggleArtworkSaved uses saved-items as the only write path', () async {
    final repository = _FakeSavedItemsRepository();
    final savedProvider = SavedItemsProvider(repository: repository);
    final api = _FakeArtworkApi();
    final artworkProvider = ArtworkProvider(backendApi: api)
      ..bindSavedItemsProvider(savedProvider)
      ..addOrUpdateArtwork(_artwork());

    await artworkProvider.toggleArtworkSaved('art-1');

    expect(savedProvider.isArtworkSaved('art-1'), isTrue);
    expect(repository.saved.map((item) => item.id), <String>['art-1']);
    expect(repository.deleted, isEmpty);
    expect(
      artworkProvider.getArtworkById('art-1')?.isFavoriteByCurrentUser,
      isTrue,
    );

    await artworkProvider.toggleArtworkSaved('art-1');

    expect(savedProvider.isArtworkSaved('art-1'), isFalse);
    expect(repository.deleted, <String>['artwork:art-1']);
    expect(
      artworkProvider.getArtworkById('art-1')?.isFavoriteByCurrentUser,
      isFalse,
    );
  });
}

Artwork _artwork() {
  return Artwork(
    id: 'art-1',
    title: 'Saved Path',
    artist: 'Artist',
    description: 'Description',
    position: const LatLng(46.0511, 14.5051),
    rewards: 0,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}
