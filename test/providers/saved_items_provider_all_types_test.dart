import 'package:art_kubus/models/saved_item.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
