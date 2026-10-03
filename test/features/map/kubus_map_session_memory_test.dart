import 'package:art_kubus/features/map/filters/map_filter_state.dart';
import 'package:art_kubus/features/map/session/kubus_map_session_memory.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

ArtMarker _marker(String id) => ArtMarker(
      id: id,
      name: id,
      description: '',
      position: const LatLng(46.05, 14.5),
      type: ArtMarkerType.artwork,
      createdAt: DateTime.utc(2026, 1, 1),
      createdBy: 'test',
    );

void main() {
  test('starts empty, so a fresh app opens at the locale framing', () {
    final memory = KubusMapSessionMemory();
    expect(memory.hasState, isFalse);
    expect(memory.camera, isNull);
    expect(memory.query, isEmpty);
    expect(memory.selectedMarker, isNull);
    expect(memory.filters.isDefault, isTrue);
  });

  test('remembers where the camera was left', () {
    final memory = KubusMapSessionMemory()
      ..rememberCamera(const LatLng(46.05, 14.5), 14.2);
    expect(memory.hasState, isTrue);
    expect(memory.camera!.center, const LatLng(46.05, 14.5));
    expect(memory.camera!.zoom, 14.2);
  });

  test('a non-finite camera is never remembered', () {
    final memory = KubusMapSessionMemory()
      ..rememberCamera(const LatLng(46.05, 14.5), 10)
      ..rememberCamera(const LatLng(46.05, 14.5), double.nan)
      ..rememberCamera(const LatLng(double.nan, 14.5), 5);
    expect(memory.camera!.zoom, 10);
  });

  test('filters, search text and selection round-trip', () {
    final filters = KubusMapFilterState.defaults().withArOnly(true);
    final memory = KubusMapSessionMemory()
      ..rememberFilters(filters)
      ..rememberQuery('mural')
      ..rememberSelection(_marker('a'));
    expect(memory.filters, filters);
    expect(memory.query, 'mural');
    expect(memory.selectedMarker!.id, 'a');
  });

  test('dismissing the selection is remembered as no selection', () {
    final memory = KubusMapSessionMemory()
      ..rememberSelection(_marker('a'))
      ..rememberSelection(null);
    expect(memory.selectedMarker, isNull);
  });

  test('clear forgets everything', () {
    final memory = KubusMapSessionMemory()
      ..rememberCamera(const LatLng(1, 2), 3)
      ..rememberFilters(KubusMapFilterState.defaults().withArOnly(true))
      ..rememberQuery('x')
      ..rememberSelection(_marker('a'))
      ..clear();
    expect(memory.hasState, isFalse);
    expect(memory.query, isEmpty);
    expect(memory.selectedMarker, isNull);
    expect(memory.filters.isDefault, isTrue);
  });

  group('canRestore: an explicit target always wins over memory', () {
    KubusMapSessionMemory remembered() =>
        KubusMapSessionMemory()..rememberCamera(const LatLng(46.05, 14.5), 14);

    test('nothing explicit: the remembered state is adopted', () {
      expect(
        remembered().canRestore(
          hasExplicitCenterOrZoom: false,
          hasDirectTarget: false,
          hasWalkingIntent: false,
        ),
        isTrue,
      );
    });

    test('an explicit initial centre or zoom wins', () {
      expect(
        remembered().canRestore(
          hasExplicitCenterOrZoom: true,
          hasDirectTarget: false,
          hasWalkingIntent: false,
        ),
        isFalse,
      );
    });

    test('a deep or internal marker target wins', () {
      expect(
        remembered().canRestore(
          hasExplicitCenterOrZoom: false,
          hasDirectTarget: true,
          hasWalkingIntent: false,
        ),
        isFalse,
      );
    });

    test('a walking navigation intent wins', () {
      expect(
        remembered().canRestore(
          hasExplicitCenterOrZoom: false,
          hasDirectTarget: false,
          hasWalkingIntent: true,
        ),
        isFalse,
      );
    });

    test('with nothing remembered there is nothing to adopt', () {
      expect(
        KubusMapSessionMemory().canRestore(
          hasExplicitCenterOrZoom: false,
          hasDirectTarget: false,
          hasWalkingIntent: false,
        ),
        isFalse,
      );
    });
  });
}
