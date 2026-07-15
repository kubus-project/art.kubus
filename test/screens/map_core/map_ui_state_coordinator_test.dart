import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/screens/map_core/map_ui_state_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('discovery chrome yields to every competing contextual surface', () {
    expect(mapContextAllowsDiscoveryChrome(MapContextSurface.none), isTrue);
    expect(
      mapContextAllowsDiscoveryChrome(MapContextSurface.discovery),
      isTrue,
    );
    for (final surface in MapContextSurface.values.where(
      (surface) =>
          surface != MapContextSurface.none &&
          surface != MapContextSurface.discovery,
    )) {
      expect(
        mapContextAllowsDiscoveryChrome(surface),
        isFalse,
        reason: '$surface must remain dominant',
      );
    }
  });

  group('MapUiStateCoordinator dominant surfaces', () {
    test('starts with no active or suspended surface', () {
      final coordinator = MapUiStateCoordinator();
      addTearDown(coordinator.dispose);

      expect(coordinator.value.contextSurface, MapContextSurface.none);
      expect(coordinator.value.suspendedSurface, isNull);
      expect(coordinator.value.surfaceRevision, 0);
    });

    test('every surface can exclusively replace the dominant surface', () {
      for (final surface in MapContextSurface.values) {
        if (surface == MapContextSurface.none) continue;
        final coordinator = MapUiStateCoordinator();
        addTearDown(coordinator.dispose);
        _selectMarker(coordinator);

        coordinator.openSurface(surface);
        expect(
          coordinator.value.contextSurface,
          surface,
          reason: '$surface should be the only dominant surface',
        );
        expect(coordinator.value.suspendedSurface, isNull);
      }
    });

    test('marker surfaces cannot open without a renderable selection', () {
      final coordinator = MapUiStateCoordinator();
      addTearDown(coordinator.dispose);
      var notifications = 0;
      coordinator.state.addListener(() => notifications += 1);

      expect(
        coordinator.openSurface(MapContextSurface.markerPreview),
        isFalse,
      );
      expect(
        coordinator.openSurface(MapContextSurface.markerDetails),
        isFalse,
      );

      expect(coordinator.value.contextSurface, MapContextSurface.none);
      expect(notifications, 0);
    });

    test('close only affects the requested active surface', () {
      final coordinator = MapUiStateCoordinator();
      addTearDown(coordinator.dispose);

      coordinator.openSurface(MapContextSurface.filters);
      coordinator.closeSurface(MapContextSurface.nearby);
      expect(coordinator.value.contextSurface, MapContextSurface.filters);

      coordinator.closeSurface(MapContextSurface.filters);
      expect(coordinator.value.contextSurface, MapContextSurface.none);
    });

    test('toggle opens a surface, replaces another, and closes itself', () {
      final coordinator = MapUiStateCoordinator();
      addTearDown(coordinator.dispose);

      coordinator.toggleSurface(MapContextSurface.filters);
      expect(coordinator.value.contextSurface, MapContextSurface.filters);

      coordinator.toggleSurface(MapContextSurface.discovery);
      expect(coordinator.value.contextSurface, MapContextSurface.discovery);

      coordinator.toggleSurface(MapContextSurface.discovery);
      expect(coordinator.value.contextSurface, MapContextSurface.none);
    });

    test('temporary surfaces suspend and explicitly restore one level', () {
      const temporarySurfaces = <MapContextSurface>[
        MapContextSurface.searchResults,
        MapContextSurface.filters,
        MapContextSurface.nearby,
        MapContextSurface.markerDetails,
        MapContextSurface.discovery,
      ];

      for (final surface in temporarySurfaces) {
        final coordinator = MapUiStateCoordinator();
        addTearDown(coordinator.dispose);
        _selectMarker(coordinator);

        expect(
          coordinator.openSurface(
            surface,
            intent: MapSurfaceTransitionIntent.suspendCurrent,
          ),
          isTrue,
        );
        expect(coordinator.value.contextSurface, surface);
        expect(
          coordinator.value.suspendedSurface,
          MapContextSurface.markerPreview,
        );

        expect(coordinator.restoreSuspendedSurface(), isTrue);
        expect(
          coordinator.value.contextSurface,
          MapContextSurface.markerPreview,
        );
        expect(coordinator.value.suspendedSurface, isNull);
      }
    });

    test('a second suspension replaces temporary UI without growing a stack',
        () {
      final coordinator = MapUiStateCoordinator();
      addTearDown(coordinator.dispose);
      _selectMarker(coordinator);

      coordinator.openSurface(
        MapContextSurface.filters,
        intent: MapSurfaceTransitionIntent.suspendCurrent,
      );
      coordinator.openSurface(
        MapContextSurface.searchResults,
        intent: MapSurfaceTransitionIntent.suspendCurrent,
      );

      expect(coordinator.value.contextSurface, MapContextSurface.searchResults);
      expect(
        coordinator.value.suspendedSurface,
        MapContextSurface.markerPreview,
      );

      coordinator.restoreSuspendedSurface();
      expect(
        coordinator.value.contextSurface,
        MapContextSurface.markerPreview,
      );
      expect(coordinator.value.suspendedSurface, isNull);
    });

    test('replacement transitions discard an existing restore point', () {
      final coordinator = MapUiStateCoordinator();
      addTearDown(coordinator.dispose);
      _selectMarker(coordinator);
      coordinator.openSurface(
        MapContextSurface.filters,
        intent: MapSurfaceTransitionIntent.suspendCurrent,
      );

      coordinator.openSurface(MapContextSurface.nearby);

      expect(coordinator.value.contextSurface, MapContextSurface.nearby);
      expect(coordinator.value.suspendedSurface, isNull);
      expect(coordinator.restoreSuspendedSurface(), isFalse);
    });
  });

  group('MapUiStateCoordinator marker selection', () {
    test('a new marker selection becomes the dominant preview', () {
      final coordinator = MapUiStateCoordinator();
      addTearDown(coordinator.dispose);
      coordinator.openSurface(MapContextSurface.filters);

      _selectMarker(coordinator);

      expect(coordinator.value.contextSurface, MapContextSurface.markerPreview);
      expect(coordinator.value.markerSelection.selectedMarkerId, 'marker-1');
    });

    test('non-marker surfaces preserve selection independently', () {
      final coordinator = MapUiStateCoordinator();
      addTearDown(coordinator.dispose);
      _selectMarker(coordinator);

      coordinator.openSurface(MapContextSurface.filters);
      expect(coordinator.value.contextSurface, MapContextSurface.filters);
      expect(coordinator.value.markerSelection.hasSelection, isTrue);

      coordinator.closeSurface(MapContextSurface.filters);
      expect(coordinator.value.contextSurface, MapContextSurface.none);
      expect(coordinator.value.markerSelection.selectedMarkerId, 'marker-1');
    });

    test('dismissing selection closes active marker surfaces', () {
      final coordinator = MapUiStateCoordinator();
      addTearDown(coordinator.dispose);
      _selectMarker(coordinator);
      coordinator.openSurface(MapContextSurface.markerDetails);

      coordinator.dismissMarkerSelection();

      expect(coordinator.value.markerSelection.hasSelection, isFalse);
      expect(coordinator.value.contextSurface, MapContextSurface.none);
    });

    test('dismissing selection preserves an unrelated dominant surface', () {
      final coordinator = MapUiStateCoordinator();
      addTearDown(coordinator.dispose);
      _selectMarker(coordinator);
      coordinator.openSurface(MapContextSurface.nearby);

      coordinator.dismissMarkerSelection();

      expect(coordinator.value.markerSelection.hasSelection, isFalse);
      expect(coordinator.value.contextSurface, MapContextSurface.nearby);
    });

    test('controller-style empty selection closes marker details', () {
      final coordinator = MapUiStateCoordinator();
      addTearDown(coordinator.dispose);
      _selectMarker(coordinator);
      coordinator.openSurface(MapContextSurface.markerDetails);

      coordinator.setMarkerSelection(
        selectionToken: 1,
        selectedMarkerId: null,
        selectedMarker: null,
        stackedMarkers: const <ArtMarker>[],
        stackIndex: 0,
        selectedAt: null,
      );

      expect(coordinator.value.markerSelection.hasSelection, isFalse);
      expect(coordinator.value.contextSurface, MapContextSurface.none);
    });

    test('selection invalidation removes an unusable resume target', () {
      final coordinator = MapUiStateCoordinator();
      addTearDown(coordinator.dispose);
      _selectMarker(coordinator);
      coordinator.openSurface(
        MapContextSurface.filters,
        intent: MapSurfaceTransitionIntent.suspendCurrent,
      );

      coordinator.dismissMarkerSelection();

      expect(coordinator.value.contextSurface, MapContextSurface.filters);
      expect(coordinator.value.suspendedSurface, isNull);
      expect(coordinator.restoreSuspendedSurface(), isFalse);
      expect(coordinator.value.contextSurface, MapContextSurface.filters);
    });

    test('a selected search result wins normal surface arbitration', () {
      final coordinator = MapUiStateCoordinator();
      addTearDown(coordinator.dispose);
      _selectMarker(coordinator);
      coordinator.openSurface(
        MapContextSurface.searchResults,
        intent: MapSurfaceTransitionIntent.suspendCurrent,
      );

      _selectMarker(coordinator, marker: _secondMarker, selectionToken: 2);

      expect(
        coordinator.value.contextSurface,
        MapContextSurface.markerPreview,
      );
      expect(coordinator.value.suspendedSurface, isNull);
      expect(
        coordinator.value.markerSelection.selectedMarkerId,
        _secondMarker.id,
      );
    });

    test('create marker clears and ignores normal marker selection', () {
      final coordinator = MapUiStateCoordinator();
      addTearDown(coordinator.dispose);
      _selectMarker(coordinator);
      coordinator.openSurface(MapContextSurface.createMarker);

      expect(coordinator.value.markerSelection.hasRenderableSelection, isFalse);

      _selectMarker(coordinator, marker: _secondMarker, selectionToken: 2);

      expect(coordinator.value.contextSurface, MapContextSurface.createMarker);
      expect(coordinator.value.markerSelection.hasRenderableSelection, isFalse);
      expect(coordinator.openSurface(MapContextSurface.filters), isFalse);
    });

    test('visible tutorial prevents marker selection replacing a surface', () {
      final coordinator = MapUiStateCoordinator();
      addTearDown(coordinator.dispose);
      coordinator.openSurface(MapContextSurface.discovery);
      coordinator.setTutorial(show: true, index: 0);

      _selectMarker(coordinator);

      expect(coordinator.value.contextSurface, MapContextSurface.discovery);
      expect(coordinator.value.markerSelection.hasRenderableSelection, isTrue);

      coordinator.setTutorial(show: false, index: 0);
      expect(coordinator.value.contextSurface, MapContextSurface.discovery);
    });

    test('rejects incomplete or mismatched marker input', () {
      final coordinator = MapUiStateCoordinator();
      addTearDown(coordinator.dispose);
      var notifications = 0;
      coordinator.state.addListener(() => notifications += 1);

      coordinator.setMarkerSelection(
        selectionToken: 1,
        selectedMarkerId: _marker.id,
        selectedMarker: null,
        stackedMarkers: const <ArtMarker>[],
        stackIndex: 0,
        selectedAt: _selectedAt,
      );
      coordinator.setMarkerSelection(
        selectionToken: 1,
        selectedMarkerId: _marker.id,
        selectedMarker: _secondMarker,
        stackedMarkers: <ArtMarker>[_secondMarker],
        stackIndex: 0,
        selectedAt: _selectedAt,
      );
      coordinator.setMarkerSelection(
        selectionToken: 1,
        selectedMarkerId: null,
        selectedMarker: _marker,
        stackedMarkers: <ArtMarker>[_marker],
        stackIndex: 0,
        selectedAt: _selectedAt,
      );

      expect(coordinator.value.markerSelection.hasRenderableSelection, isFalse);
      expect(coordinator.value.contextSurface, MapContextSurface.none);
      expect(notifications, 0);
    });

    test('sanitizes empty stacks and out-of-range stack indexes', () {
      final coordinator = MapUiStateCoordinator();
      addTearDown(coordinator.dispose);

      coordinator.setMarkerSelection(
        selectionToken: 1,
        selectedMarkerId: _marker.id,
        selectedMarker: _marker,
        stackedMarkers: const <ArtMarker>[],
        stackIndex: 9,
        selectedAt: _selectedAt,
      );

      expect(
        coordinator.value.markerSelection.stackedMarkers,
        <ArtMarker>[_marker],
      );
      expect(coordinator.value.markerSelection.stackIndex, 0);
      expect(coordinator.value.markerSelection.hasRenderableSelection, isTrue);
    });
  });

  group('MapUiStateCoordinator dismissal and marker details', () {
    test('background dismissal clears active, suspended, and marker context',
        () {
      final coordinator = MapUiStateCoordinator();
      addTearDown(coordinator.dispose);
      _selectMarker(coordinator);
      coordinator.openSurface(
        MapContextSurface.filters,
        intent: MapSurfaceTransitionIntent.suspendCurrent,
      );

      coordinator.dismissToMap(nextSelectionToken: 3);

      expect(coordinator.value.contextSurface, MapContextSurface.none);
      expect(coordinator.value.suspendedSurface, isNull);
      expect(coordinator.value.markerSelection.hasSelection, isFalse);
      expect(coordinator.value.markerSelection.selectionToken, 3);
    });

    test('Back from marker details returns to preview and keeps selection', () {
      final coordinator = MapUiStateCoordinator();
      addTearDown(coordinator.dispose);
      _selectMarker(coordinator);

      expect(coordinator.openMarkerDetails(), isTrue);
      expect(
        coordinator.value.suspendedSurface,
        MapContextSurface.markerPreview,
      );

      coordinator.backFromMarkerDetails();

      expect(
        coordinator.value.contextSurface,
        MapContextSurface.markerPreview,
      );
      expect(coordinator.value.suspendedSurface, isNull);
      expect(coordinator.value.markerSelection.hasSelection, isTrue);
    });

    test('Close from marker details clears selection and map context', () {
      final coordinator = MapUiStateCoordinator();
      addTearDown(coordinator.dispose);
      _selectMarker(coordinator);

      expect(coordinator.openMarkerDetails(), isTrue);
      coordinator.closeMarkerDetails(nextSelectionToken: 4);

      expect(coordinator.value.contextSurface, MapContextSurface.none);
      expect(coordinator.value.suspendedSurface, isNull);
      expect(coordinator.value.markerSelection.hasSelection, isFalse);
      expect(coordinator.value.markerSelection.selectionToken, 4);
    });
  });

  test('surface revision changes only with the dominant surface', () {
    final coordinator = MapUiStateCoordinator();
    addTearDown(coordinator.dispose);

    expect(coordinator.value.surfaceRevision, 0);
    expect(coordinator.isSurfaceRevisionCurrent(0), isTrue);

    _selectMarker(coordinator);
    expect(coordinator.value.surfaceRevision, 1);
    expect(coordinator.isSurfaceRevisionCurrent(0), isFalse);

    _selectMarker(coordinator);
    expect(coordinator.value.surfaceRevision, 1);

    coordinator.setTutorial(show: true, index: 0);
    expect(coordinator.value.surfaceRevision, 1);

    coordinator.openSurface(
      MapContextSurface.filters,
      intent: MapSurfaceTransitionIntent.suspendCurrent,
    );
    expect(coordinator.value.surfaceRevision, 2);

    coordinator.dismissMarkerSelection();
    expect(
      coordinator.value.surfaceRevision,
      2,
      reason: 'removing only a suspended marker surface is not dominant',
    );

    coordinator.openSurface(MapContextSurface.filters);
    expect(coordinator.value.surfaceRevision, 2);

    coordinator.dismissToMap();
    expect(coordinator.value.surfaceRevision, 3);

    coordinator.dismissToMap();
    expect(coordinator.value.surfaceRevision, 3);
  });

  test('no-op transitions and identical selection do not notify listeners', () {
    final coordinator = MapUiStateCoordinator();
    addTearDown(coordinator.dispose);
    _selectMarker(coordinator);
    var notifications = 0;
    coordinator.state.addListener(() => notifications += 1);

    _selectMarker(coordinator);
    coordinator.openSurface(MapContextSurface.markerPreview);
    coordinator.closeSurface(MapContextSurface.filters);
    expect(notifications, 0);

    coordinator.openSurface(MapContextSurface.filters);
    expect(notifications, 1);

    coordinator.openSurface(MapContextSurface.filters);
    coordinator.closeSurface(MapContextSurface.nearby);
    expect(notifications, 1);

    coordinator.dismissMarkerSelection();
    expect(notifications, 2);

    coordinator.dismissMarkerSelection();
    expect(notifications, 2);

    coordinator.closeActiveSurface();
    expect(notifications, 3);

    coordinator.closeActiveSurface();
    expect(notifications, 3);
  });
}

final DateTime _selectedAt = DateTime(2026, 7, 15, 10);

final ArtMarker _marker = ArtMarker(
  id: 'marker-1',
  name: 'Marker one',
  description: 'Test marker',
  position: const LatLng(46.0569, 14.5058),
  type: ArtMarkerType.artwork,
  createdAt: DateTime(2026, 7, 1),
  createdBy: 'tester',
);

final ArtMarker _secondMarker = ArtMarker(
  id: 'marker-2',
  name: 'Marker two',
  description: 'Second test marker',
  position: const LatLng(46.0571, 14.5061),
  type: ArtMarkerType.institution,
  createdAt: DateTime(2026, 7, 2),
  createdBy: 'tester',
);

void _selectMarker(
  MapUiStateCoordinator coordinator, {
  ArtMarker? marker,
  int selectionToken = 1,
}) {
  final selectedMarker = marker ?? _marker;
  coordinator.setMarkerSelection(
    selectionToken: selectionToken,
    selectedMarkerId: selectedMarker.id,
    selectedMarker: selectedMarker,
    stackedMarkers: <ArtMarker>[selectedMarker],
    stackIndex: 0,
    selectedAt: _selectedAt,
  );
}
