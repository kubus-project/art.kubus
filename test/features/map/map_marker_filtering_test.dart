import 'package:art_kubus/features/map/shared/map_marker_filtering.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

ArtMarker _marker(
  String id, {
  LatLng position = const LatLng(46.05, 14.50),
  ArtMarkerType type = ArtMarkerType.artwork,
  String name = '',
  String description = '',
  String category = 'General',
  List<String> tags = const <String>[],
  String? modelURL,
  String? modelCID,
}) {
  return ArtMarker(
    id: id,
    name: name.isEmpty ? 'marker-$id' : name,
    description: description,
    position: position,
    type: type,
    category: category,
    tags: tags,
    modelURL: modelURL,
    modelCID: modelCID,
    createdAt: DateTime(2024, 1, 1),
    createdBy: 'tester',
  );
}

List<String> _ids(List<ArtMarker> markers) =>
    markers.map((m) => m.id).toList()..sort();

void main() {
  group('filterVisibleMapMarkers', () {
    final near = _marker('near', position: const LatLng(46.0500, 14.5000));
    final far = _marker('far', position: const LatLng(47.0000, 15.0000));
    final ar = _marker('ar', type: ArtMarkerType.experience);
    final arModel = _marker('arModel', modelURL: 'https://example.com/m.glb');
    final discovered = _marker('discovered');
    final favorite = _marker('favorite');
    final nullIsland = _marker('nullIsland', position: const LatLng(0, 0));

    final all = <ArtMarker>[
      near,
      far,
      ar,
      arModel,
      discovered,
      favorite,
      nullIsland,
    ];

    test('all filter returns every eligible (valid-position) marker', () {
      final result = filterVisibleMapMarkers(
        markers: all,
        state: const MapMarkerFilterState(quickFilterKey: 'all'),
      );
      // nullIsland is dropped (invalid position), everything else kept.
      expect(_ids(result),
          _ids([near, far, ar, arModel, discovered, favorite]));
    });

    test('public behaves like all', () {
      final result = filterVisibleMapMarkers(
        markers: all,
        state: const MapMarkerFilterState(quickFilterKey: 'public'),
      );
      expect(result.length, 6);
    });

    test('nearby filters by radius around the base position', () {
      final result = filterVisibleMapMarkers(
        markers: <ArtMarker>[near, far],
        state: const MapMarkerFilterState(
          quickFilterKey: 'nearby',
          basePosition: LatLng(46.0500, 14.5000),
          radiusKm: 1.0,
        ),
      );
      expect(_ids(result), <String>['near']);
    });

    test('nearby without base position is non-strict by default (keeps all)',
        () {
      final result = filterVisibleMapMarkers(
        markers: <ArtMarker>[near, far],
        state: const MapMarkerFilterState(quickFilterKey: 'nearby'),
      );
      expect(_ids(result), _ids([near, far]));
    });

    test('nearby without base position can be strict (empty)', () {
      final result = filterVisibleMapMarkers(
        markers: <ArtMarker>[near, far],
        state: const MapMarkerFilterState(
          quickFilterKey: 'nearby',
          strictNearbyWithoutBase: true,
        ),
      );
      expect(result, isEmpty);
    });

    test('AR filter returns only AR-capable markers (type or model content)',
        () {
      final result = filterVisibleMapMarkers(
        markers: all,
        state: const MapMarkerFilterState(quickFilterKey: 'ar'),
      );
      expect(_ids(result), _ids([ar, arModel]));
    });

    test('favorites filter returns only favorited markers', () {
      final result = filterVisibleMapMarkers(
        markers: all,
        state: const MapMarkerFilterState(quickFilterKey: 'favorites'),
        isFavorite: (m) => m.id == 'favorite',
      );
      expect(_ids(result), <String>['favorite']);
    });

    test('favorites with no resolver returns nothing', () {
      final result = filterVisibleMapMarkers(
        markers: all,
        state: const MapMarkerFilterState(quickFilterKey: 'favorites'),
      );
      expect(result, isEmpty);
    });

    test('discovered filter returns only discovered markers', () {
      final result = filterVisibleMapMarkers(
        markers: all,
        state: const MapMarkerFilterState(quickFilterKey: 'discovered'),
        isDiscovered: (m) => m.id == 'discovered',
      );
      expect(_ids(result), <String>['discovered']);
    });

    test('undiscovered filter returns only not-yet-discovered markers', () {
      final result = filterVisibleMapMarkers(
        markers: <ArtMarker>[near, discovered],
        state: const MapMarkerFilterState(quickFilterKey: 'undiscovered'),
        isDiscovered: (m) => m.id == 'discovered',
      );
      expect(_ids(result), <String>['near']);
    });

    test('category + quick filter compose', () {
      final sculpture = _marker(
        'sculpture',
        type: ArtMarkerType.experience,
        category: 'Sculpture',
      );
      final result = filterVisibleMapMarkers(
        markers: <ArtMarker>[ar, arModel, sculpture],
        state: const MapMarkerFilterState(
          quickFilterKey: 'ar',
          query: 'sculpture',
        ),
      );
      // Only the AR-capable marker whose text matches the query.
      expect(_ids(result), <String>['sculpture']);
    });

    test('search + quick filter compose', () {
      final mural = _marker('mural', name: 'Big Mural', tags: ['streetart']);
      final other = _marker('other', name: 'Quiet Statue');
      final result = filterVisibleMapMarkers(
        markers: <ArtMarker>[mural, other],
        state: const MapMarkerFilterState(
          quickFilterKey: 'all',
          query: 'mural',
        ),
      );
      expect(_ids(result), <String>['mural']);
    });

    test('empty result when nothing matches', () {
      final result = filterVisibleMapMarkers(
        markers: all,
        state: const MapMarkerFilterState(
          quickFilterKey: 'all',
          query: 'no-such-marker-xyz',
        ),
      );
      expect(result, isEmpty);
    });

    test('alwaysIncludeMarkerIds pins a marker through a filter', () {
      // `far` would be excluded by favorites, but is pinned (e.g. selected).
      final result = filterVisibleMapMarkers(
        markers: <ArtMarker>[near, far],
        state: const MapMarkerFilterState(quickFilterKey: 'favorites'),
        isFavorite: (m) => false,
        alwaysIncludeMarkerIds: <String>{'far'},
      );
      expect(_ids(result), <String>['far']);
    });

    test('defaultMarkerIsArCapable detects experience + model content', () {
      expect(defaultMarkerIsArCapable(ar), isTrue);
      expect(defaultMarkerIsArCapable(arModel), isTrue);
      expect(defaultMarkerIsArCapable(near), isFalse);
    });
  });
}
