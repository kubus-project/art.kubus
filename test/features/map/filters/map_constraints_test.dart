import 'package:art_kubus/features/map/filters/map_constraints.dart';
import 'package:art_kubus/features/map/filters/map_filter_state.dart';
import 'package:art_kubus/features/map/shared/map_marker_filtering.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

List<KubusMapConstraintKind> _kinds(List<KubusMapConstraint> constraints) =>
    constraints.map((c) => c.kind).toList();

ArtMarker _marker(String id, ArtMarkerType type, LatLng at, {String? name}) {
  return ArtMarker(
    id: id,
    name: name ?? id,
    description: '',
    position: at,
    type: type,
    createdAt: DateTime.utc(2026, 1, 1),
    createdBy: 'test',
  );
}

void main() {
  group('which constraints are active', () {
    test('nothing restricts the plain browsing state, so nothing is listed',
        () {
      expect(
        resolveMapConstraints(
          filters: KubusMapFilterState.defaults(),
          query: '',
          hasLocation: false,
        ),
        isEmpty,
      );
      expect(
        resolveMapConstraints(
          filters: KubusMapFilterState.defaults(),
          query: '   ',
          hasLocation: true,
        ),
        isEmpty,
      );
    });

    test('a search alone is listed with the map area baseline', () {
      final result = resolveMapConstraints(
        filters: KubusMapFilterState.defaults(),
        query: ' mural ',
        hasLocation: false,
      );
      expect(_kinds(result), <KubusMapConstraintKind>[
        KubusMapConstraintKind.viewport,
        KubusMapConstraintKind.query,
      ]);
      expect(result.last.query, 'mural');
    });

    test('a travel radius replaces the viewport as the area baseline', () {
      final result = resolveMapConstraints(
        filters: KubusMapFilterState.defaults().withNearMeRadiusKm(12.5),
        query: '',
        hasLocation: true,
      );
      expect(_kinds(result), <KubusMapConstraintKind>[
        KubusMapConstraintKind.radius,
      ]);
      expect(result.single.radiusKm, 12.5);
      expect(result.single.locationPending, isFalse);
    });

    test('a radius with no location says it is not narrowing anything yet', () {
      final result = resolveMapConstraints(
        filters: KubusMapFilterState.defaults().withScope(KubusMapScope.nearMe),
        query: '',
        hasLocation: false,
      );
      expect(result.single.kind, KubusMapConstraintKind.radius);
      expect(result.single.locationPending, isTrue);
    });

    test('each filter dimension is its own constraint, in a fixed order', () {
      final filters = KubusMapFilterState.defaults()
          .withScope(KubusMapScope.nearMe)
          .withDiscoveryStatus(KubusMapDiscoveryStatus.undiscovered)
          .withArOnly(true)
          .withFavoritesOnly(true)
          .withContentLayerVisibility(ArtMarkerType.event, visible: false)
          .withContentLayerVisibility(ArtMarkerType.institution,
              visible: false);
      final result = resolveMapConstraints(
        filters: filters,
        query: 'x',
        hasLocation: true,
      );
      expect(_kinds(result), <KubusMapConstraintKind>[
        KubusMapConstraintKind.radius,
        KubusMapConstraintKind.query,
        KubusMapConstraintKind.discovery,
        KubusMapConstraintKind.arOnly,
        KubusMapConstraintKind.favoritesOnly,
        KubusMapConstraintKind.hiddenLayers,
      ]);
      expect(
        result.last.hiddenLayers,
        // Enum declaration order, so presentation never depends on the order
        // the visitor toggled them in.
        <ArtMarkerType>[ArtMarkerType.institution, ArtMarkerType.event],
      );
    });

    test('only the baseline viewport is not clearable', () {
      final result = resolveMapConstraints(
        filters: KubusMapFilterState.defaults().withArOnly(true),
        query: '',
        hasLocation: false,
      );
      expect(result.first.kind, KubusMapConstraintKind.viewport);
      expect(result.first.clearable, isFalse);
      expect(result.skip(1).every((c) => c.clearable), isTrue);
    });
  });

  group('clearing', () {
    test('clearing each constraint removes exactly that restriction', () {
      var filters = KubusMapFilterState.defaults()
          .withNearMeRadiusKm(8)
          .withDiscoveryStatus(KubusMapDiscoveryStatus.discovered)
          .withArOnly(true)
          .withFavoritesOnly(true)
          .withContentLayerVisibility(ArtMarkerType.event, visible: false);
      final all = resolveMapConstraints(
        filters: filters,
        query: '',
        hasLocation: true,
      );

      for (final constraint in all) {
        filters = clearMapConstraint(filters, constraint);
      }

      // The remembered radius value is a preference, not a restriction: with
      // the scope back on the map area nothing narrows the result.
      expect(filters.activeFilterCount, 0);
      expect(
        resolveMapConstraints(filters: filters, query: '', hasLocation: true),
        isEmpty,
      );
    });

    test('clearing the radius returns to the map area, keeping other filters',
        () {
      final filters =
          KubusMapFilterState.defaults().withNearMeRadiusKm(8).withArOnly(true);
      final next = clearMapConstraint(
        filters,
        const KubusMapConstraint.radius(radiusKm: 8, locationPending: false),
      );
      expect(next.scope, KubusMapScope.currentViewport);
      expect(next.arOnly, isTrue);
    });

    test('the query and the viewport are not filter state', () {
      final filters = KubusMapFilterState.defaults().withArOnly(true);
      expect(
        clearMapConstraint(filters, const KubusMapConstraint.query('a')),
        filters,
      );
      expect(
        clearMapConstraint(filters, const KubusMapConstraint.viewport()),
        filters,
      );
    });
  });

  group('the listed constraints match what is actually filtered', () {
    // The strip is only honest if the list is exactly the set of predicates
    // that remove markers. Each dimension below removes a marker if and only
    // if a matching constraint is listed.
    final artwork = _marker('a', ArtMarkerType.artwork, const LatLng(46, 14),
        name: 'Mural on the wall');
    final event = _marker('e', ArtMarkerType.event, const LatLng(46, 14.1));

    List<ArtMarker> shown(KubusMapFilterState filters, String query) {
      return filterVisibleMapMarkers(
        markers: [artwork, event],
        context: KubusMapFilterContext(state: filters, query: query),
      );
    }

    test('unrestricted: nothing removed, nothing listed', () {
      final filters = KubusMapFilterState.defaults();
      expect(shown(filters, ''), hasLength(2));
      expect(
        resolveMapConstraints(filters: filters, query: '', hasLocation: true),
        isEmpty,
      );
    });

    test('a search removes markers and is listed', () {
      final filters = KubusMapFilterState.defaults();
      expect(shown(filters, 'mural').map((m) => m.id), <String>['a']);
      expect(
        _kinds(resolveMapConstraints(
          filters: filters,
          query: 'mural',
          hasLocation: true,
        )),
        contains(KubusMapConstraintKind.query),
      );
    });

    test('a hidden layer removes markers and is listed', () {
      final filters = KubusMapFilterState.defaults()
          .withContentLayerVisibility(ArtMarkerType.event, visible: false);
      expect(shown(filters, '').map((m) => m.id), <String>['a']);
      expect(
        _kinds(resolveMapConstraints(
          filters: filters,
          query: '',
          hasLocation: true,
        )),
        contains(KubusMapConstraintKind.hiddenLayers),
      );
    });

    test('reset leaves nothing listed and everything shown (no ghost chips)',
        () {
      var filters = KubusMapFilterState.defaults()
          .withArOnly(true)
          .withContentLayerVisibility(ArtMarkerType.event, visible: false);
      filters = filters.reset();
      expect(shown(filters, ''), hasLength(2));
      expect(
        resolveMapConstraints(filters: filters, query: '', hasLocation: true),
        isEmpty,
      );
    });
  });
}
