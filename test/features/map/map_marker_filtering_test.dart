import 'package:art_kubus/features/map/filters/map_filter_state.dart';
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

KubusMapFilterContext _context({
  KubusMapFilterState? state,
  String query = '',
  LatLng? basePosition,
  bool strictNearMeWithoutBase = false,
}) {
  return KubusMapFilterContext(
    state: state ?? KubusMapFilterState.defaults(),
    query: query,
    basePosition: basePosition,
    strictNearMeWithoutBase: strictNearMeWithoutBase,
  );
}

List<String> _ids(List<ArtMarker> markers) =>
    markers.map((marker) => marker.id).toList()..sort();

void main() {
  group('filterVisibleMapMarkers', () {
    final near = _marker('near');
    final far = _marker('far', position: const LatLng(47, 15));
    final event = _marker('event', type: ArtMarkerType.event);
    final ar = _marker('ar', type: ArtMarkerType.experience);
    final arModel = _marker('arModel', modelURL: 'https://example.com/m.glb');
    final discovered = _marker('discovered');
    final favorite = _marker('favorite');
    final invalid = _marker('invalid', position: const LatLng(0, 0));
    final all = <ArtMarker>[
      near,
      far,
      event,
      ar,
      arModel,
      discovered,
      favorite,
      invalid,
    ];

    test('defaults keep every valid-position marker', () {
      final result = filterVisibleMapMarkers(
        markers: all,
        context: _context(),
      );

      expect(
        _ids(result),
        _ids([near, far, event, ar, arModel, discovered, favorite]),
      );
    });

    test('content layers are evaluated before other dimensions', () {
      final result = filterVisibleMapMarkers(
        markers: <ArtMarker>[near, event],
        context: _context(
          state: KubusMapFilterState(
            visibleContentLayers: const <ArtMarkerType>{ArtMarkerType.event},
          ),
          query: 'marker',
        ),
      );

      expect(_ids(result), <String>['event']);
    });

    test('query matches name, description, category, subject, and tags', () {
      final named = _marker('named', name: 'Copper Mural');
      final described = _marker('described', description: 'Copper form');
      final categorized = _marker('categorized', category: 'Copperwork');
      final tagged = _marker('tagged', tags: const <String>['copper']);

      final result = filterVisibleMapMarkers(
        markers: <ArtMarker>[named, described, categorized, tagged, near],
        context: _context(query: ' COPPER '),
      );

      expect(_ids(result), _ids([named, described, categorized, tagged]));
    });

    test('current viewport and travel do not apply the near-me radius', () {
      for (final scope in <KubusMapScope>[
        KubusMapScope.currentViewport,
        KubusMapScope.travel,
      ]) {
        final result = filterVisibleMapMarkers(
          markers: <ArtMarker>[near, far],
          context: _context(
            state: KubusMapFilterState(
              scope: scope,
              nearMeRadiusKm: 1,
            ),
            basePosition: near.position,
          ),
        );

        expect(_ids(result), _ids([near, far]), reason: scope.name);
      }
    });

    test('near-me filters around its base position', () {
      final result = filterVisibleMapMarkers(
        markers: <ArtMarker>[near, far],
        context: _context(
          state: KubusMapFilterState(
            scope: KubusMapScope.nearMe,
            nearMeRadiusKm: 1,
          ),
          basePosition: near.position,
        ),
      );

      expect(_ids(result), <String>['near']);
    });

    test('near-me without a base is permissive or strict by request', () {
      final state = KubusMapFilterState(scope: KubusMapScope.nearMe);

      final permissive = filterVisibleMapMarkers(
        markers: <ArtMarker>[near, far],
        context: _context(state: state),
      );
      final strict = filterVisibleMapMarkers(
        markers: <ArtMarker>[near, far],
        context: _context(state: state, strictNearMeWithoutBase: true),
      );

      expect(_ids(permissive), _ids([near, far]));
      expect(strict, isEmpty);
    });

    test('discovery status is exclusive and missing discovery means false', () {
      final source = <ArtMarker>[near, discovered];
      bool resolver(ArtMarker marker) => marker.id == discovered.id;

      final discoveredResult = filterVisibleMapMarkers(
        markers: source,
        context: _context(
          state: KubusMapFilterState(
            discoveryStatus: KubusMapDiscoveryStatus.discovered,
          ),
        ),
        isDiscovered: resolver,
      );
      final undiscoveredResult = filterVisibleMapMarkers(
        markers: source,
        context: _context(
          state: KubusMapFilterState(
            discoveryStatus: KubusMapDiscoveryStatus.undiscovered,
          ),
        ),
        isDiscovered: resolver,
      );

      expect(_ids(discoveredResult), <String>['discovered']);
      expect(_ids(undiscoveredResult), <String>['near']);
      expect(
        filterVisibleMapMarkers(
          markers: source,
          context: _context(
            state: KubusMapFilterState(
              discoveryStatus: KubusMapDiscoveryStatus.discovered,
            ),
          ),
        ),
        isEmpty,
      );
    });

    test('AR-only accepts experience, model content, or caller capability', () {
      final custom = _marker('custom');
      final result = filterVisibleMapMarkers(
        markers: <ArtMarker>[near, ar, arModel, custom],
        context: _context(state: KubusMapFilterState(arOnly: true)),
        isArCapable: (marker) =>
            defaultMarkerIsArCapable(marker) || marker.id == custom.id,
      );

      expect(_ids(result), _ids([ar, arModel, custom]));
    });

    test('favorites-only requires a positive resolver', () {
      final state = KubusMapFilterState(favoritesOnly: true);
      final resolved = filterVisibleMapMarkers(
        markers: <ArtMarker>[near, favorite],
        context: _context(state: state),
        isFavorite: (marker) => marker.id == favorite.id,
      );
      final unresolved = filterVisibleMapMarkers(
        markers: <ArtMarker>[near, favorite],
        context: _context(state: state),
      );

      expect(_ids(resolved), <String>['favorite']);
      expect(unresolved, isEmpty);
    });

    test('all independent dimensions compose simultaneously', () {
      final match = _marker(
        'match',
        name: 'Blue sculpture',
        type: ArtMarkerType.experience,
      );
      final wrongLayer = _marker(
        'wrong-layer',
        name: 'Blue sculpture',
        type: ArtMarkerType.event,
      );
      final wrongQuery = _marker(
        'wrong-query',
        name: 'Red sculpture',
        type: ArtMarkerType.experience,
      );
      final wrongRadius = _marker(
        'wrong-radius',
        name: 'Blue sculpture',
        position: far.position,
        type: ArtMarkerType.experience,
      );
      final wrongDiscovery = _marker(
        'wrong-discovery',
        name: 'Blue sculpture',
        type: ArtMarkerType.experience,
      );
      final wrongFavorite = _marker(
        'wrong-favorite',
        name: 'Blue sculpture',
        type: ArtMarkerType.experience,
      );

      final result = filterVisibleMapMarkers(
        markers: <ArtMarker>[
          match,
          wrongLayer,
          wrongQuery,
          wrongRadius,
          wrongDiscovery,
          wrongFavorite,
        ],
        context: _context(
          state: KubusMapFilterState(
            scope: KubusMapScope.nearMe,
            nearMeRadiusKm: 1,
            discoveryStatus: KubusMapDiscoveryStatus.discovered,
            arOnly: true,
            favoritesOnly: true,
            visibleContentLayers: const <ArtMarkerType>{
              ArtMarkerType.experience,
            },
          ),
          query: 'blue',
          basePosition: match.position,
        ),
        isDiscovered: (marker) => marker.id != wrongDiscovery.id,
        isFavorite: (marker) => marker.id != wrongFavorite.id,
      );

      expect(_ids(result), <String>['match']);
    });

    test('pins bypass filters but never invalid-position eligibility', () {
      final hiddenEvent = _marker('hidden', type: ArtMarkerType.event);
      final result = filterVisibleMapMarkers(
        markers: <ArtMarker>[hiddenEvent, invalid],
        context: _context(
          state: KubusMapFilterState(
            favoritesOnly: true,
            visibleContentLayers: const <ArtMarkerType>{
              ArtMarkerType.artwork,
            },
          ),
          query: 'does-not-match',
        ),
        isFavorite: (_) => false,
        alwaysIncludeMarkerIds: <String>{hiddenEvent.id, invalid.id},
      );

      expect(_ids(result), <String>['hidden']);
    });

    test('defaultMarkerIsArCapable detects experience and model content', () {
      expect(defaultMarkerIsArCapable(ar), isTrue);
      expect(defaultMarkerIsArCapable(arModel), isTrue);
      expect(defaultMarkerIsArCapable(near), isFalse);
    });
  });
}
